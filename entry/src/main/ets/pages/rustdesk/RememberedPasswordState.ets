import { ApprovedServerProfile } from './RustDeskDirectoryTypes';
import { ActionResponse, NativeEvent } from './RustDeskTypes';

/** Identity is the actual wire and frozen approved route, never a settings draft. */
export function rememberedPasswordIdentity(
  kind: string,
  target: string,
  targetKind: string,
  approved: ApprovedServerProfile | undefined,
  ephemeral: boolean,
): string {
  if (kind !== 'remote_control' || ephemeral || target.trim().length === 0) {
    return '';
  }
  if (targetKind === 'ip') {
    return JSON.stringify(['resk-password-v1', 'rustdesk', 'direct', target.trim()]);
  }
  if (targetKind !== 'target' || approved === undefined) {
    return '';
  }
  // Re-saving the same route does not change its identity. Its revision is an
  // approval/CAS token, not a different server. A different server or public key
  // does change the identity, even when the peer ID is the same.
  return JSON.stringify(['resk-password-v1', 'rustdesk', 'id', target.trim(),
    approved.mode, approved.idServer, approved.relayServer, approved.key]);
}

/** Native identities plus the existing UI dial generation captured at add. */
export class RememberedPasswordBinding {
  readonly sessionId: string;
  readonly coreSessionId: string;
  readonly lifecycleEpoch: string;
  readonly dialEpoch: number;
  readonly target: string;

  constructor(sessionId: string, coreSessionId: string, lifecycleEpoch: string,
    dialEpoch: number, target: string) {
    this.sessionId = sessionId;
    this.coreSessionId = coreSessionId;
    this.lifecycleEpoch = lifecycleEpoch;
    this.dialEpoch = dialEpoch;
    this.target = target;
  }
}

class RememberedPasswordAttempt {
  readonly binding: RememberedPasswordBinding;
  readonly identity: string;
  remember: boolean;
  password: string = '';
  authenticated: boolean = false;

  constructor(binding: RememberedPasswordBinding, identity: string, remembered: boolean) {
    this.binding = binding;
    this.identity = identity;
    this.remember = remembered;
  }
}

export class RememberedPasswordEffect {
  readonly kind: 'save' | 'remove';
  readonly identity: string;
  password: string;

  constructor(kind: 'save' | 'remove', identity: string, password: string = '') {
    this.kind = kind;
    this.identity = identity;
    this.password = password;
  }
}

/**
 * Uncommitted secrets are session-owned, not active-tab state. This class has no
 * storage or timers. Only a poll's real authenticated flag can emit a save;
 * queue admission, connection_ready and replayed peer_info cannot do so.
 */
export class RememberedPasswordState {
  private attempts: Map<string, RememberedPasswordAttempt> = new Map();

  begin(binding: RememberedPasswordBinding, identity: string, remembered: boolean): void {
    this.forget(binding.sessionId);
    if (identity.length === 0 || binding.sessionId.length === 0 || binding.coreSessionId.length === 0
      || binding.lifecycleEpoch.length === 0 || binding.target.length === 0
      || !Number.isSafeInteger(binding.dialEpoch) || binding.dialEpoch <= 0) {
      return;
    }
    this.attempts.set(binding.sessionId, new RememberedPasswordAttempt(binding, identity, remembered));
  }

  bindingFor(sessionId: string): RememberedPasswordBinding | undefined {
    return this.attempts.get(sessionId)?.binding;
  }

  canRemember(sessionId: string): boolean {
    return this.attempts.has(sessionId);
  }

  rememberChoice(sessionId: string): boolean {
    return this.attempts.get(sessionId)?.remember ?? false;
  }

  /** An explicit unchecked submission forgets the old asset even if login is refused. */
  choose(binding: RememberedPasswordBinding, remember: boolean): RememberedPasswordEffect | undefined {
    const attempt = this.match(binding);
    if (attempt === undefined) {
      return undefined;
    }
    attempt.remember = remember;
    attempt.password = '';
    return remember ? undefined : new RememberedPasswordEffect('remove', attempt.identity);
  }

  /** Stage only the password the same native authentication actually admitted. */
  queued(binding: RememberedPasswordBinding, password: string, response: ActionResponse): void {
    const attempt = this.match(binding);
    if (attempt === undefined || !attempt.remember || attempt.authenticated
      || !response.ok || response.queued !== true || !this.responseMatches(attempt, response)) {
      return;
    }
    attempt.password = password;
  }

  /** Returns an effect once, consuming its secret before the storage call. No retries. */
  observe(response: ActionResponse): RememberedPasswordEffect | undefined {
    if (response.action !== 'session_poll_events' || response.session === undefined) {
      return undefined;
    }
    const attempt = this.attempts.get(response.session.sessionId);
    if (attempt === undefined || !this.responseMatches(attempt, response)) {
      return undefined;
    }
    const phase = response.session.phase;
    if (!response.ok || response.closed === true || response.closing === true
      || response.closed_externally === true || phase === 'closed' || phase === 'closing' || phase === 'failed'
      || (response.events ?? []).some((event: NativeEvent) => event.name === 'close')) {
      this.forget(attempt.binding.sessionId);
      return undefined;
    }
    // A rejection in this batch invalidates the candidate before any snapshot
    // success is considered. Never automatically resubmit it on the next prompt.
    if ((response.events ?? []).some((event: NativeEvent) =>
      event.name === 'msgbox' && event.type === 're-input-password')) {
      attempt.password = '';
      attempt.authenticated = false;
      return new RememberedPasswordEffect('remove', attempt.identity);
    }
    if (response.authenticated !== true) {
      return undefined;
    }
    attempt.authenticated = true;
    if (!attempt.remember || attempt.password.length === 0) {
      attempt.password = '';
      return undefined;
    }
    const effect = new RememberedPasswordEffect('save', attempt.identity, attempt.password);
    attempt.password = '';
    return effect;
  }

  /** Page/privacy background drops only uncommitted plaintext, not target identities. */
  clearPending(): void {
    for (const attempt of this.attempts.values()) {
      attempt.password = '';
    }
  }

  forget(sessionId: string): void {
    const attempt = this.attempts.get(sessionId);
    if (attempt !== undefined) {
      attempt.password = '';
      this.attempts.delete(sessionId);
    }
  }

  clear(): void {
    this.clearPending();
    this.attempts.clear();
  }

  private match(binding: RememberedPasswordBinding): RememberedPasswordAttempt | undefined {
    const attempt = this.attempts.get(binding.sessionId);
    const current = attempt?.binding;
    return current !== undefined && current.coreSessionId === binding.coreSessionId
      && current.lifecycleEpoch === binding.lifecycleEpoch && current.dialEpoch === binding.dialEpoch
      && current.target === binding.target ? attempt : undefined;
  }

  private responseMatches(attempt: RememberedPasswordAttempt, response: ActionResponse): boolean {
    const session = response.session;
    const binding = attempt.binding;
    return session !== undefined && session.sessionId === binding.sessionId
      && session.coreSessionId === binding.coreSessionId && session.lifecycleEpoch === binding.lifecycleEpoch
      && session.target === binding.target && session.kind === 'rustdesk';
  }
}
