import { common } from '@kit.AbilityKit';
import {
  appInit,
  appSetLifecycle,
  lanPeerRemove,
  lanPeersQuery,
  lanScanStart,
  lanScanStop,
  queryDecoderCapabilities,
} from 'rustdesk-ohrs';

interface LifecycleReply {
  ok: boolean;
  ownerGeneration: string;
  ready: boolean;
  discoveryAllowed: boolean;
  error?: string;
}

export interface RustDeskLanPeer {
  id: string;
  username: string;
  hostname: string;
  platform: string;
}

export interface RustDeskLanReply {
  ok: boolean;
  ownerGeneration: string;
  scanId: string;
  revision: string;
  state: string;
  peers: RustDeskLanPeer[];
  error?: string;
  terminal?: string;
}

export interface RustDeskRuntimeState {
  pending: boolean;
  privacyAccepted: boolean;
  foreground: boolean;
  ready: boolean;
  discoveryAllowed: boolean;
  ownerGeneration: string;
  // Undefined only while a start receipt has not disclosed its admitted token.
  // The empty string means this owner has never scanned, not "any scan".
  scanId: string | undefined;
  lanPending: boolean;
  lan: RustDeskLanReply | undefined;
  error: string;
}

export type RustDeskRuntimeObserver = (state: RustDeskRuntimeState) => void;

// JS call identities are independent of the native decimal tokens.
class RuntimeCall {}

class PendingStart {
  cancelled: boolean = false;
  promise: Promise<RustDeskLanReply | undefined> | undefined = undefined;

  constructor(
    readonly lifecycle: RuntimeCall,
    readonly command: RuntimeCall,
    readonly owner: string,
    readonly previousScan: string,
  ) {}
}

function decimal(value: string, allowZero: boolean = false): boolean {
  return typeof value === 'string' && (allowZero ? /^(0|[1-9][0-9]*)$/ : /^[1-9][0-9]*$/).test(value);
}

function olderRevision(value: string, current: string): boolean {
  return value.length < current.length || (value.length === current.length && value < current);
}

function lifecycleReply(raw: string): LifecycleReply {
  const reply = JSON.parse(raw) as LifecycleReply;
  if (typeof reply.ok !== 'boolean' || typeof reply.ready !== 'boolean' ||
    typeof reply.discoveryAllowed !== 'boolean' || typeof reply.ownerGeneration !== 'string' ||
    (reply.ownerGeneration !== '' && !decimal(reply.ownerGeneration)) ||
    (reply.discoveryAllowed && (!reply.ready || reply.ownerGeneration === ''))) {
    throw new Error('Invalid native app lifecycle receipt');
  }
  return reply;
}

function lanReply(raw: string): RustDeskLanReply {
  const reply = JSON.parse(raw) as RustDeskLanReply;
  if (typeof reply.ok !== 'boolean' || !decimal(reply.ownerGeneration) ||
    typeof reply.scanId !== 'string' || (reply.scanId !== '' && !decimal(reply.scanId)) ||
    !decimal(reply.revision, true) || typeof reply.state !== 'string' || !Array.isArray(reply.peers)) {
    throw new Error('Invalid native LAN receipt');
  }
  return reply;
}

/**
 * One module singleton; EntryAbility alone supplies the private root and lifecycle.
 * The main page owns one observer, never another runtime or a session service.
 * No lifecycle call is serialized behind initialization or LAN I/O.
 * App/LAN retirement is not a sessionClose receipt: this owner neither closes
 * viewers nor infers released/settle or permission to destroy a Surface.
 */
class RustDeskRuntimeController {
  private lifecycle: RuntimeCall = new RuntimeCall();
  private command: RuntimeCall = new RuntimeCall();
  private observer: RustDeskRuntimeObserver | undefined = undefined;
  private filesDir: string | undefined = undefined;
  private pending: boolean = false;
  private privacyAccepted: boolean = false;
  private foreground: boolean = false;
  private ready: boolean = false;
  private discoveryAllowed: boolean = false;
  private owner: string = '';
  private scan: string | undefined = '';
  private revision: string = '0';
  private lan: RustDeskLanReply | undefined = undefined;
  private error: string = '';
  private starting: PendingStart | undefined = undefined;
  private mutation: Promise<RustDeskLanReply | undefined> | undefined = undefined;

  state(): RustDeskRuntimeState {
    return {
      pending: this.pending,
      privacyAccepted: this.privacyAccepted,
      foreground: this.foreground,
      ready: this.ready,
      discoveryAllowed: this.discoveryAllowed,
      ownerGeneration: this.owner,
      scanId: this.scan,
      lanPending: this.starting !== undefined || this.mutation !== undefined,
      lan: this.lan,
      error: this.error,
    };
  }

  bind(observer: RustDeskRuntimeObserver): void {
    if (this.observer !== undefined && this.observer !== observer) {
      throw new Error('The main page already owns the runtime observer');
    }
    this.observer = observer;
    this.emit();
  }

  unbind(observer: RustDeskRuntimeObserver): Promise<RustDeskLanReply | undefined> {
    if (this.observer !== observer) {
      return Promise.resolve(undefined);
    }
    this.observer = undefined;
    return this.stopLanScan();
  }

  updateLifecycle(context: common.UIAbilityContext, privacyAccepted: boolean,
    foreground: boolean): Promise<void> {
    const lifecycle = new RuntimeCall();
    this.lifecycle = lifecycle;
    this.command = new RuntimeCall();
    this.pending = true;
    this.privacyAccepted = privacyAccepted;
    this.foreground = foreground;
    this.ready = false;
    this.discoveryAllowed = false;
    this.owner = '';
    this.scan = '';
    this.revision = '0';
    this.lan = undefined;
    this.error = '';
    this.starting = undefined;
    this.mutation = undefined;
    // Invoke the native export in this method itself, before any async helper,
    // page notification or returned Promise. Same-state true/true also retires.
    let pending: Promise<string>;
    try {
      pending = appSetLifecycle(privacyAccepted, foreground);
    } catch (error) {
      this.pending = false;
      this.error = String(error);
      this.emit();
      return Promise.reject(error);
    }
    // Only the continuation may await the lifecycle ACK and perform appInit.
    const work = this.completeLifecycle(lifecycle, context, privacyAccepted, foreground, pending);
    this.emit();
    return work;
  }

  private async completeLifecycle(lifecycle: RuntimeCall, context: common.UIAbilityContext,
    privacyAccepted: boolean, foreground: boolean, pending: Promise<string>): Promise<void> {
    try {
      const filesDir = context.filesDir;
      if (this.filesDir !== undefined && this.filesDir !== filesDir) {
        // The native root is process-fixed too. Do not leave a changed Ability
        // context with discovery/routing admission enabled.
        const fence = appSetLifecycle(false, false);
        await Promise.all([pending, fence]);
        throw new Error('The private UIAbilityContext root is already fixed');
      }
      this.filesDir = filesDir;
      let reply = lifecycleReply(await pending);
      if (lifecycle !== this.lifecycle) {
        return;
      }
      if (!reply.ok) {
        throw new Error(reply.error ?? 'Native app lifecycle was refused');
      }
      if (privacyAccepted && foreground && !reply.ready) {
        reply = lifecycleReply(await appInit(filesDir));
        if (lifecycle !== this.lifecycle) {
          return;
        }
        if (!reply.ok) {
          throw new Error(reply.error ?? 'Native private initialization failed');
        }
      }
      if ((!privacyAccepted || !foreground) && (reply.discoveryAllowed || reply.ownerGeneration !== '')) {
        throw new Error('Native discovery admission survived a lifecycle fence');
      }
      this.ready = reply.ready;
      this.discoveryAllowed = reply.discoveryAllowed;
      this.owner = reply.ownerGeneration;
      this.pending = false;
      this.emit();
    } catch (error) {
      if (lifecycle !== this.lifecycle) {
        return;
      }
      this.pending = false;
      this.error = String(error);
      this.emit();
      throw error;
    }
  }

  async queryDecoderCapabilityReport(): Promise<string | undefined> {
    const owner = this.requireOwner();
    const lifecycle = this.lifecycle;
    try {
      const raw = await queryDecoderCapabilities();
      return lifecycle === this.lifecycle && owner === this.owner ? raw : undefined;
    } catch (error) {
      if (lifecycle !== this.lifecycle || owner !== this.owner) {
        return undefined;
      }
      throw error;
    }
  }

  async startLanScan(): Promise<RustDeskLanReply | undefined> {
    const owner = this.requireOwner();
    this.requirePage();
    if (this.starting !== undefined || this.mutation !== undefined || this.scan === undefined) {
      throw new Error('A LAN start/stop/removal token is still unconfirmed');
    }
    const command = new RuntimeCall();
    this.command = command;
    const start = new PendingStart(this.lifecycle, command, owner, this.scan);
    this.starting = start;
    this.scan = undefined;
    this.lan = undefined;
    this.error = '';
    const work = this.completeStart(start);
    start.promise = work;
    this.emit();
    return work;
  }

  private async completeStart(start: PendingStart): Promise<RustDeskLanReply | undefined> {
    try {
      const reply = lanReply(await lanScanStart(start.owner));
      if (start.lifecycle !== this.lifecycle || start.owner !== this.owner) {
        return undefined; // Native lifecycle already retired this owner.
      }
      if (reply.ownerGeneration !== start.owner ||
        (reply.scanId === '' && (reply.ok || start.previousScan !== ''))) {
        throw new Error('LAN start returned a mismatched owner/scan receipt');
      }
      this.scan = reply.scanId;
      if (start.cancelled) {
        // A hidden page may abandon UI results, not a synchronously admitted
        // native scan whose token was still in flight. Stop that exact token.
        if (reply.scanId !== '') {
          const stopped = lanReply(await lanScanStop(start.owner, reply.scanId));
          if (start.lifecycle !== this.lifecycle || start.owner !== this.owner) {
            return undefined;
          }
          if (stopped.ownerGeneration !== start.owner || stopped.scanId !== reply.scanId || !stopped.ok) {
            throw new Error(stopped.error ?? 'LAN stop after page exit was not confirmed');
          }
        } else if (!reply.ok) {
          throw new Error(reply.error ?? 'LAN start was refused');
        }
        return undefined; // Never publish the abandoned page's start/stop rows.
      }
      return this.applyLan(reply, start.lifecycle, start.command, start.owner, reply.scanId);
    } catch (error) {
      if (start.lifecycle !== this.lifecycle || start.owner !== this.owner) {
        return undefined;
      }
      this.error = String(error);
      this.lan = undefined;
      throw error;
    } finally {
      if (this.starting === start) {
        this.starting = undefined;
        this.emit();
      }
    }
  }

  async queryLanPeers(): Promise<RustDeskLanReply | undefined> {
    const owner = this.requireOwner();
    this.requirePage();
    if (this.starting !== undefined || this.mutation !== undefined) {
      return undefined;
    }
    const scan = this.scan;
    if (scan === undefined) {
      throw new Error('The admitted LAN scan token is not available');
    }
    const command = new RuntimeCall();
    this.command = command;
    return this.completeLan(lanPeersQuery(owner, scan), this.lifecycle, command, owner, scan);
  }

  async stopLanScan(): Promise<RustDeskLanReply | undefined> {
    this.command = new RuntimeCall();
    this.lan = undefined;
    if (this.starting !== undefined) {
      this.starting.cancelled = true;
      this.emit();
      return this.starting.promise;
    }
    // Removal already cancels and joins the current scan; double page teardown
    // shares that actual receipt instead of sending a new competing command.
    if (this.mutation !== undefined) {
      return this.mutation;
    }
    if (this.scan === undefined) {
      throw new Error('LAN stop has no confirmed scan token; an Ability lifecycle fence is required');
    }
    if (this.owner === '' || this.scan === '') {
      this.emit();
      return undefined;
    }
    return this.runMutation(lanScanStop(this.owner, this.scan), this.owner, this.scan);
  }

  async removeLanPeer(claimedId: string): Promise<RustDeskLanReply | undefined> {
    const owner = this.requireOwner();
    this.requirePage();
    if (this.starting !== undefined || this.mutation !== undefined || this.scan === undefined) {
      throw new Error('A LAN start/stop/removal receipt is still pending');
    }
    return this.runMutation(lanPeerRemove(owner, this.scan, claimedId), owner, this.scan);
  }

  private async runMutation(raw: Promise<string>, owner: string,
    scan: string): Promise<RustDeskLanReply | undefined> {
    const command = new RuntimeCall();
    this.command = command;
    const work = this.completeLan(raw, this.lifecycle, command, owner, scan);
    this.mutation = work;
    this.emit();
    try {
      return await work;
    } finally {
      if (this.mutation === work) {
        this.mutation = undefined;
        this.emit();
      }
    }
  }

  private async completeLan(raw: Promise<string>, lifecycle: RuntimeCall, command: RuntimeCall,
    owner: string, scan: string): Promise<RustDeskLanReply | undefined> {
    try {
      return this.applyLan(lanReply(await raw), lifecycle, command, owner, scan);
    } catch (error) {
      if (!this.current(lifecycle, command, owner)) {
        return undefined;
      }
      this.error = String(error);
      this.lan = undefined;
      this.emit();
      throw error;
    }
  }

  private applyLan(reply: RustDeskLanReply, lifecycle: RuntimeCall, command: RuntimeCall,
    owner: string, scan: string): RustDeskLanReply | undefined {
    if (!this.current(lifecycle, command, owner)) {
      return undefined;
    }
    if (reply.ownerGeneration !== owner || reply.scanId !== scan) {
      throw new Error('LAN receipt does not match the current owner/scan');
    }
    if (reply.ok && olderRevision(reply.revision, this.revision)) {
      return undefined;
    }
    if (reply.ok) {
      this.revision = reply.revision;
    }
    this.lan = reply;
    this.error = reply.ok ? '' : (reply.error ?? 'Native LAN operation failed');
    this.emit();
    return reply;
  }

  private current(lifecycle: RuntimeCall, command: RuntimeCall, owner: string): boolean {
    return lifecycle === this.lifecycle && command === this.command && owner === this.owner;
  }

  private requireOwner(): string {
    if (!this.discoveryAllowed || !this.ready || this.owner === '') {
      throw new Error(this.error || 'Current foreground consent and a native discovery owner are required');
    }
    return this.owner;
  }

  private requirePage(): void {
    if (this.observer === undefined) {
      throw new Error('The discovery page is not visible');
    }
  }

  private emit(): void {
    this.observer?.(this.state());
  }
}

export const rustDeskRuntimeController = new RustDeskRuntimeController();
