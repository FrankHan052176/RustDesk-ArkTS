import { common, Want } from '@kit.AbilityKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { util, url } from '@kit.ArkTS';
import { window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { harmonyShare, systemShare } from '@kit.ShareKit';

export const REMOTE_SESSION_HANDOFF_EVENT = 'rustdesk.remote_session_handoff';
export const REMOTE_SESSION_CONTINUE_STATE_EVENT = 'rustdesk.remote_session_continue_state';
export const REMOTE_SESSION_CONTINUE_HANDOFF_EVENT = 'rustdesk.remote_session_continue_handoff';
export const REMOTE_SESSION_APP_STATE_EVENT = 'rustdesk.remote_session_app_state';

const HANDOFF_VERSION = 1;
const HANDOFF_TTL_MS = 120000;
const MAX_HANDOFF_PAYLOAD_LENGTH = 24576;
const MAX_CONSUMED_NONCES = 64;
const HANDOFF_SCHEME = 'resk:';
const HANDOFF_HOST = 'handoff';
const HANDOFF_PATH = '/remote';
const DOMAIN = 0xFF00;
const TAG = 'RustDeskHandoff';

export type RemoteSessionHandoffSource = 'gesture' | 'knock' | 'continuation';

export class RemoteSessionShareSnapshot {
  target: string = '';
  targetKind: string = 'target';
  connToken: string = '';
  idServer: string = '';
  relayServer: string = '';
  apiServer: string = '';
  key: string = '';
  connectionMode: string = 'remote_control';
  forceRelay: boolean = false;
}

export class RemoteSessionHandoffEnvelope extends RemoteSessionShareSnapshot {
  version: number = HANDOFF_VERSION;
  nonce: string = '';
  issuedAt: number = 0;
  expiresAt: number = 0;
  source: RemoteSessionHandoffSource = 'gesture';
  oneTime: boolean = true;
}

export class RemoteSessionHandoffService {
  private static pendingIncoming: RemoteSessionHandoffEnvelope | undefined = undefined;
  private static outgoingSnapshot: RemoteSessionShareSnapshot | undefined = undefined;
  private static consumedNonces: string[] = [];

  static setOutgoingSnapshot(snapshot: RemoteSessionShareSnapshot | undefined): void {
    RemoteSessionHandoffService.outgoingSnapshot = snapshot === undefined
      ? undefined
      : RemoteSessionHandoffService.copySnapshot(snapshot);
  }

  static createContinuationPayload(): string | undefined {
    const snapshot = RemoteSessionHandoffService.outgoingSnapshot;
    if (snapshot === undefined || !RemoteSessionHandoffService.isShareableSnapshot(snapshot)) {
      return undefined;
    }
    return RemoteSessionHandoffService.buildDeepLink(
      RemoteSessionHandoffService.createEnvelope(snapshot, 'continuation'),
    );
  }

  static handleDeepLinkWant(context: common.UIAbilityContext, want: Want): boolean {
    const parameters = want.parameters;
    const rawParameter = parameters?.data;
    if (typeof rawParameter === 'string' && rawParameter.length > 0) {
      const parameterEnvelope = RemoteSessionHandoffService.parseDeepLink(rawParameter)
        ?? RemoteSessionHandoffService.parseEnvelope(rawParameter);
      if (parameterEnvelope !== undefined) {
        hilog.info(DOMAIN, TAG, 'handoff payload received from Want parameters length=%{public}d', rawParameter.length);
        RemoteSessionHandoffService.bufferIncoming(context, parameterEnvelope);
        return true;
      }
    }
    const uri = want.uri;
    if (uri === undefined || uri.length === 0) {
      hilog.info(DOMAIN, TAG, 'deep link want has no uri');
      return false;
    }
    hilog.info(DOMAIN, TAG, 'deep link want received uriLength=%{public}d', uri.length);
    const envelope = RemoteSessionHandoffService.parseDeepLink(uri);
    if (envelope === undefined) {
      hilog.warn(DOMAIN, TAG, 'deep link want rejected by parser');
      return false;
    }
    RemoteSessionHandoffService.bufferIncoming(context, envelope);
    return true;
  }

  static handleContinuationWant(context: common.UIAbilityContext, want: Want): boolean {
    const parameters = want.parameters;
    if (parameters === undefined) {
      return false;
    }
    const rawPayload = parameters.data;
    if (typeof rawPayload !== 'string' || rawPayload.length === 0) {
      return false;
    }
    const envelope = RemoteSessionHandoffService.parseDeepLink(rawPayload)
      ?? RemoteSessionHandoffService.parseEnvelope(rawPayload);
    if (envelope === undefined || envelope.source !== 'continuation') {
      return false;
    }
    RemoteSessionHandoffService.bufferIncoming(context, envelope);
    return true;
  }

  static takeIncoming(): RemoteSessionHandoffEnvelope | undefined {
    const envelope = RemoteSessionHandoffService.pendingIncoming;
    RemoteSessionHandoffService.pendingIncoming = undefined;
    if (envelope === undefined || RemoteSessionHandoffService.wasConsumed(envelope.nonce)) {
      return undefined;
    }
    if (!RemoteSessionHandoffService.isEnvelopeValid(envelope)) {
      return undefined;
    }
    RemoteSessionHandoffService.markConsumed(envelope.nonce);
    return envelope;
  }

  static buildConnectionTarget(envelope: RemoteSessionHandoffEnvelope): string {
    const target = envelope.target.trim();
    if (envelope.targetKind === 'ip' || target.includes('@') || envelope.idServer.trim().length === 0) {
      return target;
    }
    const key = envelope.key.trim();
    const keySuffix = key.length > 0 ? `?key=${key}` : '';
    return `${target}@${envelope.idServer.trim()}${keySuffix}`;
  }

  static buildSharedData(
    snapshot: RemoteSessionShareSnapshot,
    source: RemoteSessionHandoffSource,
  ): systemShare.SharedData | undefined {
    if (!RemoteSessionHandoffService.isShareableSnapshot(snapshot)) {
      return undefined;
    }
    const envelope = RemoteSessionHandoffService.createEnvelope(snapshot, source);
    const link = RemoteSessionHandoffService.buildDeepLink(envelope);
    if (link === undefined) {
      return undefined;
    }
    return new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: link,
      title: 'RustDesk 一次性远控',
      description: '在另一台设备上继续当前远控会话',
    });
  }

  static copySnapshot(source: RemoteSessionShareSnapshot): RemoteSessionShareSnapshot {
    const snapshot = new RemoteSessionShareSnapshot();
    snapshot.target = source.target;
    snapshot.targetKind = source.targetKind;
    snapshot.connToken = source.connToken;
    snapshot.idServer = source.idServer;
    snapshot.relayServer = source.relayServer;
    snapshot.apiServer = source.apiServer;
    snapshot.key = source.key;
    snapshot.connectionMode = source.connectionMode;
    snapshot.forceRelay = source.forceRelay;
    RemoteSessionHandoffService.normalizeTransportContext(snapshot);
    return snapshot;
  }

  private static createEnvelope(
    snapshot: RemoteSessionShareSnapshot,
    source: RemoteSessionHandoffSource,
  ): RemoteSessionHandoffEnvelope {
    const now = Date.now();
    const envelope = new RemoteSessionHandoffEnvelope();
    envelope.target = snapshot.target.trim();
    envelope.targetKind = snapshot.targetKind;
    envelope.connToken = snapshot.connToken;
    envelope.idServer = snapshot.idServer.trim();
    envelope.relayServer = snapshot.relayServer.trim();
    envelope.apiServer = snapshot.apiServer.trim();
    envelope.key = snapshot.key.trim();
    envelope.connectionMode = snapshot.connectionMode;
    envelope.forceRelay = snapshot.forceRelay;
    envelope.nonce = util.generateRandomUUID().toLowerCase();
    envelope.issuedAt = now;
    envelope.expiresAt = now + HANDOFF_TTL_MS;
    envelope.source = source;
    RemoteSessionHandoffService.normalizeTransportContext(envelope);
    return envelope;
  }

  private static buildDeepLink(envelope: RemoteSessionHandoffEnvelope): string | undefined {
    try {
      const link = url.URL.parseURL('resk://handoff/remote');
      link.params.set('payload', JSON.stringify(envelope));
      return link.toString();
    } catch (_) {
      return undefined;
    }
  }

  private static parseDeepLink(link: string): RemoteSessionHandoffEnvelope | undefined {
    try {
      const parsed = url.URL.parseURL(link);
      if (parsed.protocol !== HANDOFF_SCHEME || parsed.hostname !== HANDOFF_HOST || parsed.pathname !== HANDOFF_PATH) {
        hilog.warn(
          DOMAIN,
          TAG,
          'deep link shape mismatch protocol=%{public}s host=%{public}s path=%{public}s',
          parsed.protocol,
          parsed.hostname,
          parsed.pathname,
        );
        return undefined;
      }
      const payload = parsed.params.get('payload');
      if (payload !== null && payload.length > 0) {
        return RemoteSessionHandoffService.parseEnvelope(payload);
      }
      return RemoteSessionHandoffService.parseQueryEnvelope(parsed.params);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'deep link URL parsing threw: %{public}s', String(error));
      return undefined;
    }
  }

  private static parseQueryEnvelope(params: url.URLParams): RemoteSessionHandoffEnvelope | undefined {
    const version = params.get('v');
    const nonce = params.get('nonce');
    const issuedAt = params.get('issued_at');
    const expiresAt = params.get('expires_at');
    const sourceValue = params.get('source');
    const target = params.get('target');
    const targetKind = params.get('target_kind');
    const connectionMode = params.get('connection_mode');
    const oneTime = params.get('one_time');
    if (version === null || nonce === null || issuedAt === null || expiresAt === null ||
      sourceValue === null || target === null || targetKind === null || connectionMode === null ||
      oneTime === null) {
      return undefined;
    }
    const source = RemoteSessionHandoffService.parseSource(sourceValue);
    if (source === undefined) {
      return undefined;
    }
    const envelope = new RemoteSessionHandoffEnvelope();
    envelope.version = Number(version);
    envelope.nonce = nonce.trim().toLowerCase();
    envelope.issuedAt = Number(issuedAt);
    envelope.expiresAt = Number(expiresAt);
    envelope.source = source;
    envelope.target = target.trim();
    envelope.targetKind = targetKind.trim();
    envelope.connToken = params.get('conn_token') ?? '';
    envelope.idServer = params.get('id_server') ?? '';
    envelope.relayServer = params.get('relay_server') ?? '';
    envelope.apiServer = params.get('api_server') ?? '';
    envelope.key = params.get('key') ?? '';
    envelope.connectionMode = connectionMode.trim();
    envelope.forceRelay = params.get('force_relay') === '1';
    envelope.oneTime = oneTime === '1' || oneTime.toLowerCase() === 'true';
    RemoteSessionHandoffService.normalizeTransportContext(envelope);
    return RemoteSessionHandoffService.isEnvelopeValid(envelope) ? envelope : undefined;
  }

  private static parseEnvelope(payload: string): RemoteSessionHandoffEnvelope | undefined {
    if (payload.length === 0 || payload.length > MAX_HANDOFF_PAYLOAD_LENGTH) {
      return undefined;
    }
    try {
      const value: ESObject = JSON.parse(payload);
      const envelope = new RemoteSessionHandoffEnvelope();
      envelope.version = Number(value.version ?? 0);
      envelope.nonce = String(value.nonce ?? '').trim().toLowerCase();
      envelope.issuedAt = Number(value.issuedAt ?? 0);
      envelope.expiresAt = Number(value.expiresAt ?? 0);
      const source = RemoteSessionHandoffService.parseSource(String(value.source ?? ''));
      if (source === undefined) {
        return undefined;
      }
      envelope.source = source;
      envelope.target = String(value.target ?? '').trim();
      envelope.targetKind = String(value.targetKind ?? '').trim();
      envelope.connToken = String(value.connToken ?? '');
      envelope.idServer = String(value.idServer ?? '').trim();
      envelope.relayServer = String(value.relayServer ?? '').trim();
      envelope.apiServer = String(value.apiServer ?? '').trim();
      envelope.key = String(value.key ?? '').trim();
      envelope.connectionMode = String(value.connectionMode ?? '').trim();
      envelope.forceRelay = Boolean(value.forceRelay);
      envelope.oneTime = Boolean(value.oneTime);
      RemoteSessionHandoffService.normalizeTransportContext(envelope);
      return RemoteSessionHandoffService.isEnvelopeValid(envelope) ? envelope : undefined;
    } catch (_) {
      return undefined;
    }
  }

  private static parseSource(value: string): RemoteSessionHandoffSource | undefined {
    if (value === 'gesture') {
      return 'gesture';
    }
    if (value === 'knock') {
      return 'knock';
    }
    if (value === 'continuation') {
      return 'continuation';
    }
    return undefined;
  }

  private static isEnvelopeValid(envelope: RemoteSessionHandoffEnvelope): boolean {
    const now = Date.now();
    if (envelope.version !== HANDOFF_VERSION || !envelope.oneTime || envelope.nonce.length < 16) {
      return false;
    }
    if (envelope.issuedAt <= 0 || envelope.expiresAt <= now || envelope.expiresAt < envelope.issuedAt) {
      return false;
    }
    if (envelope.expiresAt - envelope.issuedAt > HANDOFF_TTL_MS) {
      return false;
    }
    if (envelope.connectionMode !== 'remote_control') {
      return false;
    }
    return RemoteSessionHandoffService.isShareableSnapshot(envelope)
      && !RemoteSessionHandoffService.wasConsumed(envelope.nonce);
  }

  private static isShareableSnapshot(snapshot: RemoteSessionShareSnapshot | undefined): boolean {
    if (snapshot === undefined) {
      return false;
    }
    if (snapshot.target.trim().length === 0 || snapshot.target.length > 512) {
      return false;
    }
    if (snapshot.connToken.length === 0 || snapshot.connToken.length > 4096) {
      return false;
    }
    if (snapshot.idServer.length > 512 || snapshot.relayServer.length > 512 || snapshot.apiServer.length > 1024) {
      return false;
    }
    if (snapshot.key.length > 4096 || snapshot.key.includes('&')) {
      return false;
    }
    if (snapshot.connectionMode !== 'remote_control') {
      return false;
    }
    if (snapshot.targetKind === 'ip') {
      return snapshot.idServer.length === 0
        && snapshot.relayServer.length === 0
        && snapshot.apiServer.length === 0
        && snapshot.key.length === 0
        && !snapshot.forceRelay;
    }
    return snapshot.targetKind === 'target'
      && (snapshot.target.includes('@') || snapshot.idServer.trim().length > 0);
  }

  private static normalizeTransportContext(snapshot: RemoteSessionShareSnapshot): void {
    if (snapshot.targetKind !== 'ip') {
      return;
    }
    snapshot.idServer = '';
    snapshot.relayServer = '';
    snapshot.apiServer = '';
    snapshot.key = '';
    snapshot.forceRelay = false;
  }

  private static bufferIncoming(context: common.UIAbilityContext, envelope: RemoteSessionHandoffEnvelope): void {
    RemoteSessionHandoffService.pendingIncoming = envelope;
    context.eventHub.emit(REMOTE_SESSION_HANDOFF_EVENT);
  }

  private static wasConsumed(nonce: string): boolean {
    return RemoteSessionHandoffService.consumedNonces.includes(nonce);
  }

  private static markConsumed(nonce: string): void {
    RemoteSessionHandoffService.consumedNonces.push(nonce);
    if (RemoteSessionHandoffService.consumedNonces.length > MAX_CONSUMED_NONCES) {
      RemoteSessionHandoffService.consumedNonces.shift();
    }
  }
}

export class RemoteSessionShareController {
  private snapshot: RemoteSessionShareSnapshot | undefined = undefined;
  private registry: harmonyShare.SendCapabilityRegistry | undefined = undefined;
  private gesturesRegistered: boolean = false;
  private knockRegistered: boolean = false;
  private registrationGeneration: number = 0;
  private gesturesCallback: Callback<harmonyShare.SharableTarget> =
    (target: harmonyShare.SharableTarget): void => this.share(target, 'gesture');
  private knockCallback: Callback<harmonyShare.SharableTarget> =
    (target: harmonyShare.SharableTarget): void => this.share(target, 'knock');

  setEnabled(context: common.UIAbilityContext, snapshot: RemoteSessionShareSnapshot | undefined): void {
    this.registrationGeneration += 1;
    this.unregister();
    this.snapshot = snapshot === undefined ? undefined : RemoteSessionHandoffService.copySnapshot(snapshot);
    if (this.snapshot === undefined) {
      return;
    }
    const generation = this.registrationGeneration;
    window.getLastWindow(context).then((currentWindow: window.Window): void => {
      if (generation !== this.registrationGeneration || this.snapshot === undefined) {
        return;
      }
      if (!canIUse('SystemCapability.Collaboration.HarmonyShare')) {
        hilog.info(DOMAIN, TAG, 'HarmonyShare is unavailable on this device');
        return;
      }
      const useWindowScope = RemoteSessionShareController.requiresWindowScope(currentWindow);
      const registry: harmonyShare.SendCapabilityRegistry | undefined = useWindowScope
        ? { windowId: currentWindow.getWindowProperties().id }
        : undefined;
      this.registry = registry;
      try {
        if (registry === undefined) {
          harmonyShare.on('knockShare', this.knockCallback);
        } else {
          harmonyShare.on('knockShare', registry, this.knockCallback);
        }
        this.knockRegistered = true;
        hilog.info(DOMAIN, TAG, 'knockShare listener registered scoped=%{public}s', useWindowScope.toString());
      } catch (error) {
        this.knockRegistered = false;
        hilog.error(DOMAIN, TAG, 'knockShare registration failed: %{public}s', String(error));
      }
      try {
        if (registry === undefined) {
          harmonyShare.on('gesturesShare', this.gesturesCallback);
        } else {
          harmonyShare.on('gesturesShare', registry, this.gesturesCallback);
        }
        this.gesturesRegistered = true;
        hilog.info(DOMAIN, TAG, 'gesturesShare listener registered scoped=%{public}s', useWindowScope.toString());
      } catch (error) {
        this.gesturesRegistered = false;
        hilog.error(DOMAIN, TAG, 'gesturesShare registration failed: %{public}s', String(error));
      }
    }).catch((error: Error): void => {
      if (generation !== this.registrationGeneration) {
        return;
      }
      hilog.error(DOMAIN, TAG, 'share window lookup failed: %{public}s', error.message);
    });
  }

  disable(): void {
    this.registrationGeneration += 1;
    this.unregister();
    this.snapshot = undefined;
  }

  private unregister(): void {
    const registry = this.registry;
    if (registry !== undefined && this.knockRegistered) {
      try {
        harmonyShare.off('knockShare', registry, this.knockCallback);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'knockShare unregister ignored: %{public}s', String(error));
      }
    } else if (this.knockRegistered) {
      try {
        harmonyShare.off('knockShare', this.knockCallback);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'knockShare unregister ignored: %{public}s', String(error));
      }
    }
    if (registry !== undefined && this.gesturesRegistered) {
      try {
        harmonyShare.off('gesturesShare', registry, this.gesturesCallback);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'gesturesShare unregister ignored: %{public}s', String(error));
      }
    } else if (this.gesturesRegistered) {
      try {
        harmonyShare.off('gesturesShare', this.gesturesCallback);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'gesturesShare unregister ignored: %{public}s', String(error));
      }
    }
    this.registry = undefined;
    this.gesturesRegistered = false;
    this.knockRegistered = false;
  }

  private static requiresWindowScope(currentWindow: window.Window): boolean {
    const deviceType = deviceInfo.deviceType.trim().toLowerCase();
    if (deviceType === 'pc' || deviceType === '2in1') {
      return true;
    }
    if (deviceType !== 'tablet') {
      return false;
    }
    try {
      return currentWindow.getWindowStatus() === window.WindowStatusType.FLOATING;
    } catch (_) {
      return false;
    }
  }

  private share(target: harmonyShare.SharableTarget, source: RemoteSessionHandoffSource): void {
    const snapshot = this.snapshot;
    if (snapshot === undefined) {
      void target.reject(harmonyShare.SharableErrorCode.NO_CONTENT_ERROR);
      return;
    }
    const data = RemoteSessionHandoffService.buildSharedData(snapshot, source);
    if (data === undefined) {
      void target.reject(harmonyShare.SharableErrorCode.NO_CONTENT_ERROR);
      return;
    }
    void target.share(data);
  }
}
