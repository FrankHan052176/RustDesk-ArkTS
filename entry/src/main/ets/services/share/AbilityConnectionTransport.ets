/**
 * AbilityConnectionManager ArrayBuffer near-field transport adapter.
 *
 * Implements the official AbilityConnectionManager data plane for peer-to-peer
 * screen sharing between HarmonyOS devices.
 *
 * Features:
 * - Real lifecycle: createSession -> connect (source) / acceptConnect (sink) -> sendData / receiveData -> disconnect -> destroy.
 * - Raw binary transport: calls abilityConnectionManager.sendData(sessionId, ArrayBuffer).
 *   Does NOT convert to string/base64; does NOT enforce 1024-byte ceiling.
 * - Preserves Promise rejection on sendData failure; never pretends success.
 * - Strict epoch isolation: stale callbacks from older sessions are rejected.
 * - Provides read-only frame dispatch boundary for incoming ArrayBuffer frames.
 * - Provides helper to parse and accept from EntryAbility onCollaborate wantParam.
 */

import { abilityConnectionManager } from '@kit.DistributedServiceKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AbilityTransportRole,
  AbilityTransportState,
  AbilityTransportStats,
  AbilityTransportStatus,
  CollaborateParams,
  DEFAULT_SHARE_SERVICE_NAME,
  DMS_COLLAB_TOKEN_KEY,
  DMS_COLLABORATE_INDEX_KEY,
  DMS_CONNECT_OPTION_KEY,
  DMS_PEER_INFO_KEY,
  FrameReceiveListener,
  StateChangeListener,
} from './AbilityConnectionTypes';

const DOMAIN = 0xFF00;
const TAG = 'AbilityConnectionTransport';

export class AbilityConnectionTransport {
  private state: AbilityTransportState = 'idle';
  private role: AbilityTransportRole | undefined = undefined;
  private currentEpochId: number = 0;
  private activeEpoch: string = '';
  private activeSessionId: number = -1;
  private currentPeerInfo: abilityConnectionManager.PeerInfo | undefined = undefined;
  private stats: AbilityTransportStats = this.createEmptyStats();
  private frameListeners: Set<FrameReceiveListener> = new Set();
  private stateListeners: Set<StateChangeListener> = new Set();

  private createEmptyStats(): AbilityTransportStats {
    return {
      bytesSent: 0,
      framesSent: 0,
      bytesReceived: 0,
      framesReceived: 0,
      lastSendTimestampMs: 0,
      lastReceiveTimestampMs: 0,
      lastSendError: undefined,
      lastReceiveError: undefined,
    };
  }

  private allocateEpoch(role: AbilityTransportRole): string {
    this.currentEpochId += 1;
    this.activeEpoch = `ab-${role}-${Date.now()}-${this.currentEpochId}`;
    return this.activeEpoch;
  }

  /**
   * Source side: creates an AbilityConnection session and initiates connection to remote peer.
   *
   * @param context Host UIAbility or Application context.
   * @param peerInfo Remote peer information (deviceId/networkId, bundleName, abilityName).
   * @param options Connection options (needSendData, startOptions, parameters).
   * @param serviceName Service identifier for collaboration (defaults to 'resk_screen_share').
   * @returns Active session epoch on success.
   * @throws Error on parameter validation failure or connect rejection.
   */
  async connectSource(
    context: common.Context,
    peerInfo: abilityConnectionManager.PeerInfo,
    options?: abilityConnectionManager.ConnectOptions,
    serviceName: string = DEFAULT_SHARE_SERVICE_NAME
  ): Promise<string> {
    if (this.state === 'connected' || this.state === 'connecting') {
      throw new Error(`当前已存在活跃连接 (state=${this.state}, epoch=${this.activeEpoch})，请先断开`);
    }
    if (!context) {
      throw new Error('context 不能为空');
    }
    if (!peerInfo || !peerInfo.deviceId || !peerInfo.bundleName || !peerInfo.moduleName || !peerInfo.abilityName) {
      throw new Error('peerInfo 缺少必要字段 (deviceId, bundleName, abilityName)');
    }

    const epoch = this.allocateEpoch('source');
    this.state = 'connecting';
    this.role = 'source';
    this.currentPeerInfo = peerInfo;
    this.stats = this.createEmptyStats();
    this.notifyStateChanged('connecting', epoch);

    const connectOptions: abilityConnectionManager.ConnectOptions = {
      needSendData: true,
      startOptions: options?.startOptions ?? abilityConnectionManager.StartOptionParams.START_IN_FOREGROUND,
      parameters: options?.parameters ?? {},
    };

    let sessionId = -1;
    try {
      hilog.info(
        DOMAIN,
        TAG,
        '正在创建 Ability 连接会话: service=%{public}s, peer=%{public}s/%{public}s, epoch=%{public}s',
        serviceName,
        peerInfo.bundleName,
        peerInfo.abilityName,
        epoch
      );

      sessionId = abilityConnectionManager.createAbilityConnectionSession(
        serviceName,
        context,
        peerInfo,
        connectOptions
      );
      if (sessionId < 0) {
        throw new Error(`createAbilityConnectionSession 失败，返回 sessionId=${sessionId}`);
      }
      this.activeSessionId = sessionId;

      this.registerEvents(sessionId, epoch);

      hilog.info(DOMAIN, TAG, '正在连接对端 Ability: sessionId=%{public}d, epoch=%{public}s', sessionId, epoch);
      const result = await abilityConnectionManager.connect(sessionId);
      this.requireActive(sessionId, epoch);
      if (!result || !result.isConnected) {
        const errCode = result?.errorCode ?? -1;
        throw new Error(`Ability 连接建立失败 (isConnected=false, errorCode=${errCode})`);
      }

      this.state = 'connected';
      hilog.info(DOMAIN, TAG, 'Ability 连接建立成功: sessionId=%{public}d, epoch=%{public}s', sessionId, epoch);
      this.notifyStateChanged('connected', epoch);
      return epoch;
    } catch (error) {
      const message = `协同连接失败 (${(error as BusinessError).code ?? -1})`;
      hilog.error(
        DOMAIN,
        TAG,
        'connectSource 失败: sessionId=%{public}d, epoch=%{public}s, error=%{public}s',
        sessionId,
        epoch,
        message
      );
      if (this.activeEpoch === epoch) {
        this.teardown(sessionId, epoch);
        this.state = 'failed';
        this.notifyStateChanged('failed', epoch, message);
      }
      const failure = new Error(message) as BusinessError;
      failure.code = (error as BusinessError).code ?? -1;
      throw failure as Error;
    }
  }

  /**
   * Sink side: creates an AbilityConnection session and accepts the incoming connection.
   *
   * @param context Host UIAbility or Application context.
   * @param peerInfo Remote caller peer information.
   * @param collabToken Opaque collaboration token from DMS framework.
   * @param options Connection options.
   * @param serviceName Service identifier for collaboration.
   * @returns Active session epoch on success.
   */
  async acceptSink(
    context: common.Context,
    peerInfo: abilityConnectionManager.PeerInfo,
    collabToken: string,
    options?: abilityConnectionManager.ConnectOptions,
    serviceName: string = DEFAULT_SHARE_SERVICE_NAME
  ): Promise<string> {
    if (this.state === 'connected' || this.state === 'connecting') {
      throw new Error(`当前已存在活跃连接 (state=${this.state}, epoch=${this.activeEpoch})，请先断开`);
    }
    if (!context) {
      throw new Error('context 不能为空');
    }
    if (!collabToken) {
      throw new Error('collabToken 不能为空');
    }
    if (!peerInfo || !peerInfo.deviceId || !peerInfo.bundleName || !peerInfo.moduleName || !peerInfo.abilityName) {
      throw new Error('peerInfo 缺少必要字段 (deviceId, bundleName, abilityName)');
    }

    const epoch = this.allocateEpoch('sink');
    this.state = 'connecting';
    this.role = 'sink';
    this.currentPeerInfo = peerInfo;
    this.stats = this.createEmptyStats();
    this.notifyStateChanged('connecting', epoch);

    const connectOptions: abilityConnectionManager.ConnectOptions = {
      needSendData: true,
      startOptions: options?.startOptions,
      parameters: options?.parameters ?? {},
    };

    let sessionId = -1;
    try {
      hilog.info(
        DOMAIN,
        TAG,
        '正在为协同创建 Ability 会话: service=%{public}s, peer=%{public}s, epoch=%{public}s',
        serviceName,
        peerInfo.bundleName,
        epoch
      );

      sessionId = abilityConnectionManager.createAbilityConnectionSession(
        serviceName,
        context,
        peerInfo,
        connectOptions
      );
      if (sessionId < 0) {
        throw new Error(`createAbilityConnectionSession 失败，返回 sessionId=${sessionId}`);
      }
      this.activeSessionId = sessionId;

      this.registerEvents(sessionId, epoch);

      hilog.info(DOMAIN, TAG, '正在调用 acceptConnect: sessionId=%{public}d, epoch=%{public}s', sessionId, epoch);
      await abilityConnectionManager.acceptConnect(sessionId, collabToken);
      this.requireActive(sessionId, epoch);

      this.state = 'connected';
      hilog.info(DOMAIN, TAG, '协同连接接受成功: sessionId=%{public}d, epoch=%{public}s', sessionId, epoch);
      this.notifyStateChanged('connected', epoch);
      return epoch;
    } catch (error) {
      const message = `协同连接失败 (${(error as BusinessError).code ?? -1})`;
      hilog.error(
        DOMAIN,
        TAG,
        'acceptSink 失败: sessionId=%{public}d, epoch=%{public}s, error=%{public}s',
        sessionId,
        epoch,
        message
      );
      if (this.activeEpoch === epoch) {
        this.teardown(sessionId, epoch);
        this.state = 'failed';
        this.notifyStateChanged('failed', epoch, message);
      }
      const failure = new Error(message) as BusinessError;
      failure.code = (error as BusinessError).code ?? -1;
      throw failure as Error;
    }
  }

  /**
   * Helper to parse collaboration parameters from EntryAbility onCollaborate wantParam.
   */
  static parseCollaborateParam(wantParam: Record<string, Object>): CollaborateParams | undefined {
    if (!wantParam) {
      return undefined;
    }
    const collabIndex = wantParam[DMS_COLLABORATE_INDEX_KEY] as Record<string, Object> | undefined;
    if (collabIndex === undefined) {
      return undefined;
    }
    const target = collabIndex;
    const collabToken = target[DMS_COLLAB_TOKEN_KEY] as string | undefined;
    const peerInfo = target[DMS_PEER_INFO_KEY] as abilityConnectionManager.PeerInfo | undefined;
    const connectOptions = target[DMS_CONNECT_OPTION_KEY] as abilityConnectionManager.ConnectOptions | undefined;

    if (!collabToken || !peerInfo) {
      return undefined;
    }
    return {
      collabToken,
      peerInfo,
      connectOptions,
      customParameters: connectOptions?.parameters,
    };
  }

  /**
   * Helper for EntryAbility onCollaborate: parses wantParam and accepts connection in one call.
   */
  async acceptFromCollaborate(
    context: common.Context,
    wantParam: Record<string, Object>,
    serviceName: string = DEFAULT_SHARE_SERVICE_NAME
  ): Promise<string> {
    const parsed = AbilityConnectionTransport.parseCollaborateParam(wantParam);
    if (!parsed) {
      throw new Error('wantParam 中未包含合法的协同参数 (缺少 collabToken 或 PeerInfo)');
    }
    return this.acceptSink(
      context,
      parsed.peerInfo,
      parsed.collabToken,
      parsed.connectOptions,
      serviceName
    );
  }

  /**
   * Sends one binary frame over the active AbilityConnection.
   *
   * Constraints enforced:
   * 1. Direct ArrayBuffer pass-through: NO conversion to string/base64.
   * 2. NO artificial 1024-byte limit.
   * 3. Retains Promise rejection: failures are never swallowed.
   * 4. Epoch verification: prevents sending to a stale or reconnected session.
   *
   * @param data Raw ArrayBuffer payload (video/audio packet or control frame).
   * @param epoch Optional expected epoch. If specified, must match current active epoch.
   */
  async sendFrame(data: ArrayBuffer, epoch?: string): Promise<void> {
    const sessionId = this.activeSessionId;
    const currentEpoch = this.activeEpoch;

    if (sessionId < 0 || this.state !== 'connected' || !currentEpoch) {
      throw new Error(`无法发送数据：连接未就绪 (state=${this.state}, sessionId=${sessionId})`);
    }
    if (epoch !== undefined && epoch !== currentEpoch) {
      throw new Error(`代际不匹配：frame 属于已失效代际 (${epoch})，当前代际为 (${currentEpoch})`);
    }
    if (!data || !(data instanceof ArrayBuffer)) {
      throw new Error('入参必须为有效的 ArrayBuffer');
    }

    try {
      await abilityConnectionManager.sendData(sessionId, data);
      this.requireActive(sessionId, currentEpoch);
      this.stats.bytesSent += data.byteLength;
      this.stats.framesSent += 1;
      this.stats.lastSendTimestampMs = Date.now();
    } catch (error) {
      const err = error as BusinessError;
      if (this.activeEpoch === currentEpoch) {
        this.stats.lastSendError = `send_failed:${err.code ?? -1}`;
      }
      hilog.error(
        DOMAIN,
        TAG,
        'sendData 失败: sessionId=%{public}d, epoch=%{public}s, bytes=%{public}d, code=%{public}d, err=%{public}s',
        sessionId,
        currentEpoch,
        data.byteLength,
        err?.code ?? -1,
        'send_failed'
      );
      // Retain rejection: callers must receive real failure
      const failure = new Error(`近场数据发送失败 (${err.code ?? -1})`) as BusinessError;
      failure.code = err.code ?? -1;
      throw failure as Error;
    }
  }

  private requireActive(sessionId: number, epoch: string): void {
    if (this.activeSessionId !== sessionId || this.activeEpoch !== epoch) {
      throw new Error('近场连接已撤销');
    }
  }

  private registerEvents(sessionId: number, boundEpoch: string): void {
    abilityConnectionManager.on('connect', sessionId, (info: abilityConnectionManager.EventCallbackInfo) => {
      if (this.activeEpoch !== boundEpoch) {
        return;
      }
      hilog.info(DOMAIN, TAG, '底层 connect 回调: sessionId=%{public}d, epoch=%{public}s', info.sessionId, boundEpoch);
      if (this.state !== 'connected') {
        this.state = 'connected';
        this.notifyStateChanged('connected', boundEpoch);
      }
    });

    abilityConnectionManager.on('disconnect', sessionId, (info: abilityConnectionManager.EventCallbackInfo) => {
      if (this.activeEpoch !== boundEpoch) {
        return;
      }
      hilog.info(DOMAIN, TAG, '底层 disconnect 回调: sessionId=%{public}d, epoch=%{public}s', info.sessionId, boundEpoch);
      this.teardown(sessionId, boundEpoch);
      this.state = 'disconnected';
      this.notifyStateChanged('disconnected', boundEpoch, 'peer_disconnected');
    });

    abilityConnectionManager.on('receiveData', sessionId, (info: abilityConnectionManager.EventCallbackInfo) => {
      this.handleReceiveData(info, boundEpoch);
    });
  }

  private handleReceiveData(info: abilityConnectionManager.EventCallbackInfo, boundEpoch: string): void {
    if (this.activeEpoch !== boundEpoch || this.state !== 'connected') {
      hilog.warn(
        DOMAIN,
        TAG,
        '丢弃非活跃代际数据包: boundEpoch=%{public}s, currentEpoch=%{public}s, state=%{public}s',
        boundEpoch,
        this.activeEpoch,
        this.state
      );
      return;
    }
    const buffer = info?.data;
    if (!buffer || !(buffer instanceof ArrayBuffer)) {
      hilog.warn(DOMAIN, TAG, 'receiveData 回调数据为空或非 ArrayBuffer');
      return;
    }

    this.stats.bytesReceived += buffer.byteLength;
    this.stats.framesReceived += 1;
    this.stats.lastReceiveTimestampMs = Date.now();

    // Read-only boundary: dispatch buffer directly without modification
    const listeners = Array.from(this.frameListeners);
    for (const listener of listeners) {
      try {
        listener(buffer, boundEpoch);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'frameListener 执行异常: %{public}d', (err as BusinessError).code ?? -1);
      }
    }
  }

  private unregisterEvents(sessionId: number): void {
    try {
      abilityConnectionManager.off('connect', sessionId);
      abilityConnectionManager.off('disconnect', sessionId);
      abilityConnectionManager.off('receiveData', sessionId);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '注销事件监听异常: sessionId=%{public}d, code=%{public}d', sessionId, (error as BusinessError).code ?? -1);
    }
  }

  private teardown(sessionId: number, targetEpoch: string): void {
    if (this.activeEpoch !== targetEpoch && targetEpoch !== '') {
      return;
    }
    this.activeEpoch = '';
    this.activeSessionId = -1;
    this.currentPeerInfo = undefined;
    this.role = undefined;

    if (sessionId >= 0) {
      this.unregisterEvents(sessionId);
      try {
        abilityConnectionManager.disconnect(sessionId);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'disconnect 失败: sessionId=%{public}d, code=%{public}d', sessionId, (err as BusinessError).code ?? -1);
      }
      try {
        abilityConnectionManager.destroyAbilityConnectionSession(sessionId);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'destroyAbilityConnectionSession 失败: sessionId=%{public}d, code=%{public}d', sessionId, (err as BusinessError).code ?? -1);
      }
    }
  }

  /**
   * Disconnects the active session and cleans up resources.
   *
   * @param expectedEpoch Optional epoch check.
   */
  async disconnect(expectedEpoch?: string): Promise<void> {
    const currentEpoch = this.activeEpoch;
    if (expectedEpoch !== undefined && expectedEpoch !== currentEpoch) {
      hilog.warn(
        DOMAIN,
        TAG,
        'disconnect 传入过期代际: expected=%{public}s, current=%{public}s',
        expectedEpoch,
        currentEpoch
      );
      return;
    }
    const sessionId = this.activeSessionId;
    if (sessionId < 0 && this.state === 'idle') {
      return;
    }
    this.state = 'disconnecting';
    this.notifyStateChanged('disconnecting', currentEpoch);
    this.teardown(sessionId, currentEpoch);
    this.state = 'disconnected';
    this.notifyStateChanged('disconnected', currentEpoch, 'user_disconnect');
  }

  /**
   * Unconditionally tears down active session and clears all listeners.
   */
  destroy(): void {
    const sessionId = this.activeSessionId;
    const epoch = this.activeEpoch;
    this.teardown(sessionId, epoch);
    this.frameListeners.clear();
    this.stateListeners.clear();
    this.state = 'idle';
  }

  /**
   * Registers a listener for incoming binary frames.
   *
   * @param listener Callback receiving (data: ArrayBuffer, epoch: string).
   * @returns Unsubscribe function.
   */
  onFrameReceived(listener: FrameReceiveListener): () => void {
    this.frameListeners.add(listener);
    return (): void => {
      this.frameListeners.delete(listener);
    };
  }

  /**
   * Registers a listener for lifecycle state changes.
   *
   * @param listener Callback receiving (state, epoch, reason?).
   * @returns Unsubscribe function.
   */
  onStateChanged(listener: StateChangeListener): () => void {
    this.stateListeners.add(listener);
    return (): void => {
      this.stateListeners.delete(listener);
    };
  }

  private notifyStateChanged(state: AbilityTransportState, epoch: string, reason?: string): void {
    const listeners = Array.from(this.stateListeners);
    for (const listener of listeners) {
      try {
        listener(state, epoch, reason);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'stateListener 执行异常: %{public}d', (err as BusinessError).code ?? -1);
      }
    }
  }

  getState(): AbilityTransportState {
    return this.state;
  }

  getEpoch(): string {
    return this.activeEpoch;
  }

  getSessionId(): number {
    return this.activeSessionId;
  }

  getRole(): AbilityTransportRole | undefined {
    return this.role;
  }

  getPeerInfo(): abilityConnectionManager.PeerInfo | undefined {
    return this.currentPeerInfo;
  }

  getStats(): AbilityTransportStats {
    return {
      bytesSent: this.stats.bytesSent,
      framesSent: this.stats.framesSent,
      bytesReceived: this.stats.bytesReceived,
      framesReceived: this.stats.framesReceived,
      lastSendTimestampMs: this.stats.lastSendTimestampMs,
      lastReceiveTimestampMs: this.stats.lastReceiveTimestampMs,
      lastSendError: this.stats.lastSendError,
      lastReceiveError: this.stats.lastReceiveError,
    };
  }

  getStatus(): AbilityTransportStatus {
    return {
      state: this.state,
      role: this.role,
      epoch: this.activeEpoch,
      sessionId: this.activeSessionId,
      peerInfo: this.currentPeerInfo,
      stats: this.getStats(),
    };
  }

  isConnected(): boolean {
    return this.state === 'connected' && this.activeSessionId >= 0 && this.activeEpoch.length > 0;
  }
}

export const abilityConnectionTransport: AbilityConnectionTransport = new AbilityConnectionTransport();
