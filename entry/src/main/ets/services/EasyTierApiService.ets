import { common, Want } from '@kit.AbilityKit';
import { dataShare, preferences } from '@kit.ArkData';
import { JSON, util } from '@kit.ArkTS';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF00;
const TAG = 'EasyTierApi';

export const EASYTIER_API_RESULT_EVENT = 'rustdesk.easytier.api.result';
export const EASYTIER_SNAPSHOT_EVENT = 'rustdesk.easytier.snapshot';

export const EASYTIER_API_SCHEMA_VERSION = 2;
export const EASYTIER_API_REQUEST_ACTION = 'top.frankhan.easytier.action.START_INSTANCE_REQUEST';
export const EASYTIER_API_RESULT_ACTION = 'top.frankhan.easytier.action.START_INSTANCE_RESULT';
export const EASYTIER_API_REQUEST_ID_KEY = 'top.frankhan.easytier.api.requestId';
export const EASYTIER_API_OPERATION_KEY = 'top.frankhan.easytier.api.operation';
export const EASYTIER_API_CALLER_BUNDLE_KEY = 'ohos.aafwk.param.callerBundleName';
export const EASYTIER_API_CALLER_IDENTIFIER_KEY = 'ohos.aafwk.param.callerAppIdentifier';

export const EASYTIER_BUNDLE_NAME = 'top.frankhan.easytier';
export const EASYTIER_MODULE_NAME = 'entry';
export const EASYTIER_ABILITY_NAME = 'EntryAbility';
export const EASYTIER_APP_IDENTIFIER = '6917581172490635834';

export const EASYTIER_API_REQUEST_URI =
  'datashareproxy://top.frankhan.resk/easytier_api/v2/start_request';
export const EASYTIER_API_RESULT_URI =
  'datashareproxy://top.frankhan.easytier/third_party_api/v2/start_result/rustdesk';
export const EASYTIER_SNAPSHOT_URI =
  'datashareproxy://top.frankhan.easytier/third_party_api/v2/instance_snapshot/rustdesk';

export const EASYTIER_OPERATION_START_INSTANCE = 'start_instance';
export const EASYTIER_OPERATION_ENSURE_INSTANCE_RUNNING = 'ensure_instance_running';
export const EASYTIER_RESULT_OK = 'OK';
export const EASYTIER_STATE_STOPPED = 'stopped';
export const EASYTIER_STATE_STARTING = 'starting';
export const EASYTIER_STATE_RUNNING = 'running';

const API_REQUEST_TTL_MS = 5 * 60 * 1000;
const FUTURE_CLOCK_SKEW_MS = 5000;
const MAX_SNAPSHOT_TTL_MS = 60 * 1000;
const MAX_SHARED_VALUE_LENGTH = 4096;
const MAX_INSTANCE_ID_LENGTH = 128;
const MAX_INSTANCE_NAME_LENGTH = 64;
const MAX_INSTANCE_COUNT = 10;
const MAX_TARGET_LENGTH = 256;

const PREFERENCES_NAME = 'rustdesk_easytier_api';
const PENDING_REQUEST_ID_KEY = 'pending_request_id';
const PENDING_OPERATION_KEY = 'pending_operation';
const PENDING_ISSUED_AT_KEY = 'pending_issued_at';
const PENDING_INSTANCE_ID_KEY = 'pending_instance_id';
const INTENT_TARGET_KEY = 'intent_target';
const INTENT_KIND_KEY = 'intent_kind';
const INTENT_ISSUED_AT_KEY = 'intent_issued_at';

export type EasyTierApiOperation = 'start_instance' | 'ensure_instance_running';
export type EasyTierConnectionKind = 'remote_control' | 'view_only' | 'view_camera' | 'file_transfer';

interface EasyTierApiRequestPayload {
  schemaVersion: number;
  requestId: string;
  operation: string;
  issuedAt: number;
  instanceId?: string;
}

interface EasyTierApiInstancePayload {
  instanceId?: string;
  instanceName?: string;
  state?: string;
  virtualIpv4?: string;
  peerCount?: number;
}

interface EasyTierApiResultPayload {
  schemaVersion?: number;
  requestId?: string;
  operation?: string;
  issuedAt?: number;
  ok?: boolean;
  code?: string;
  message?: string;
  instance?: EasyTierApiInstancePayload;
}

interface EasyTierSnapshotPayload {
  schemaVersion?: number;
  updatedAt?: number;
  ttlMs?: number;
  instances?: EasyTierApiInstancePayload[];
  truncated?: boolean;
}

export class EasyTierInstanceSummary {
  instanceId: string;
  instanceName: string;
  state: string;
  virtualIpv4: string;
  peerCount: number;

  constructor(instanceId: string = '', instanceName: string = '', state: string = EASYTIER_STATE_STOPPED,
    virtualIpv4: string = '', peerCount: number = 0) {
    this.instanceId = instanceId;
    this.instanceName = instanceName;
    this.state = state;
    this.virtualIpv4 = virtualIpv4;
    this.peerCount = peerCount;
  }
}

export class EasyTierApiPendingRequest {
  requestId: string;
  operation: EasyTierApiOperation;
  issuedAt: number;
  instanceId: string;

  constructor(requestId: string, operation: EasyTierApiOperation, issuedAt: number, instanceId: string = '') {
    this.requestId = requestId;
    this.operation = operation;
    this.issuedAt = issuedAt;
    this.instanceId = instanceId;
  }
}

export class EasyTierConnectionIntent {
  target: string;
  kind: EasyTierConnectionKind;
  issuedAt: number;

  constructor(target: string, kind: EasyTierConnectionKind, issuedAt: number) {
    this.target = target;
    this.kind = kind;
    this.issuedAt = issuedAt;
  }
}

export class EasyTierApiRequestOutcome {
  ok: boolean;
  requestId: string;
  message: string;

  constructor(ok: boolean, requestId: string, message: string) {
    this.ok = ok;
    this.requestId = requestId;
    this.message = message;
  }
}

export class EasyTierApiResultEvent {
  ok: boolean;
  requestId: string;
  operation: EasyTierApiOperation;
  code: string;
  message: string;
  instance: EasyTierInstanceSummary | undefined;
  target: string;
  kind: EasyTierConnectionKind;

  constructor(ok: boolean, requestId: string, operation: EasyTierApiOperation, code: string, message: string) {
    this.ok = ok;
    this.requestId = requestId;
    this.operation = operation;
    this.code = code;
    this.message = message;
    this.instance = undefined;
    this.target = '';
    this.kind = 'remote_control';
  }
}

export class EasyTierSnapshotEvent {
  ok: boolean;
  fresh: boolean;
  message: string;
  updatedAt: number;
  ttlMs: number;
  instances: EasyTierInstanceSummary[];
  truncated: boolean;

  constructor(ok: boolean, fresh: boolean, message: string, updatedAt: number = 0, ttlMs: number = 0) {
    this.ok = ok;
    this.fresh = fresh;
    this.message = message;
    this.updatedAt = updatedAt;
    this.ttlMs = ttlMs;
    this.instances = [];
    this.truncated = false;
  }
}

export class EasyTierApiValidator {
  static isRequestId(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
  }

  static isOperation(value: string): boolean {
    return value === EASYTIER_OPERATION_START_INSTANCE
      || value === EASYTIER_OPERATION_ENSURE_INSTANCE_RUNNING;
  }

  static isConnectionKind(value: string): boolean {
    return value === 'remote_control' || value === 'view_only'
      || value === 'view_camera' || value === 'file_transfer';
  }

  static isInstanceId(value: string): boolean {
    return value.length > 0 && value.length <= MAX_INSTANCE_ID_LENGTH
      && value === value.trim() && /^[A-Za-z0-9._:-]+$/.test(value);
  }

  static isState(value: string): boolean {
    return value === EASYTIER_STATE_STOPPED || value === EASYTIER_STATE_STARTING
      || value === EASYTIER_STATE_RUNNING;
  }

  static isCurrentTimestamp(value: number, now: number): boolean {
    return Number.isSafeInteger(value) && value > 0
      && value - now <= FUTURE_CLOCK_SKEW_MS && now - value <= API_REQUEST_TTL_MS;
  }

  static wantStringParameter(want: Want, key: string): string {
    const value = want.parameters?.[key];
    return typeof value === 'string' ? value : '';
  }

  static isTrustedResultWant(want: Want): boolean {
    return want.action === EASYTIER_API_RESULT_ACTION
      && want.uri === EASYTIER_API_RESULT_URI
      && EasyTierApiValidator.wantStringParameter(want, EASYTIER_API_CALLER_BUNDLE_KEY)
        === EASYTIER_BUNDLE_NAME
      && EasyTierApiValidator.wantStringParameter(want, EASYTIER_API_CALLER_IDENTIFIER_KEY)
        === EASYTIER_APP_IDENTIFIER;
  }
}

export class EasyTierApiService {
  private static bufferedResult: EasyTierApiResultEvent | undefined = undefined;
  private static bufferedSnapshot: EasyTierSnapshotEvent | undefined = undefined;
  private context: common.UIAbilityContext;
  private activeRequestIds: Set<string> = new Set<string>();
  private snapshotHandle: dataShare.DataProxyHandle | undefined = undefined;
  private snapshotStartPromise: Promise<void> | undefined = undefined;
  private snapshotObserverGeneration: number = 0;
  private onSnapshotChanged = (error: BusinessError<void>, changes: dataShare.DataProxyChangeInfo[]): void => {
    if (error) {
      hilog.error(DOMAIN, TAG, 'EasyTier snapshot subscription failed: %{public}s', error.message);
      return;
    }
    for (let index = 0; index < changes.length; index += 1) {
      const change = changes[index];
      if (change.uri !== EASYTIER_SNAPSHOT_URI || typeof change.value !== 'string') {
        continue;
      }
      const snapshot = EasyTierApiService.decodeSnapshot(change.value);
      EasyTierApiService.deliverSnapshot(this.context, snapshot);
    }
  };

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  static isResultWant(want: Want): boolean {
    return want.action === EASYTIER_API_RESULT_ACTION;
  }

  static takeBufferedResult(): EasyTierApiResultEvent | undefined {
    const result = EasyTierApiService.bufferedResult;
    EasyTierApiService.bufferedResult = undefined;
    return result;
  }

  static clearBufferedResult(requestId: string): void {
    const result = EasyTierApiService.bufferedResult;
    if (result !== undefined && result.requestId === requestId) {
      EasyTierApiService.bufferedResult = undefined;
    }
  }

  static takeBufferedSnapshot(): EasyTierSnapshotEvent | undefined {
    const snapshot = EasyTierApiService.bufferedSnapshot;
    EasyTierApiService.bufferedSnapshot = undefined;
    return snapshot;
  }

  async startSnapshotObserver(): Promise<void> {
    if (deviceInfo.sdkApiVersion < 20 || this.snapshotHandle !== undefined) {
      return;
    }
    const pending = this.snapshotStartPromise;
    if (pending !== undefined) {
      await pending;
      return;
    }
    const generation = this.snapshotObserverGeneration;
    const startPromise = this.registerSnapshotObserver(generation);
    this.snapshotStartPromise = startPromise;
    try {
      await startPromise;
    } finally {
      if (this.snapshotStartPromise === startPromise) {
        this.snapshotStartPromise = undefined;
      }
    }
  }

  private async registerSnapshotObserver(generation: number): Promise<void> {
    let handle: dataShare.DataProxyHandle | undefined = undefined;
    let subscribed: boolean = false;
    try {
      handle = await dataShare.createDataProxyHandle();
      if (generation !== this.snapshotObserverGeneration) {
        return;
      }
      const config: dataShare.DataProxyConfig = {
        type: dataShare.DataProxyType.SHARED_CONFIG,
      };
      const results = handle.on('dataChange', [EASYTIER_SNAPSHOT_URI], config, this.onSnapshotChanged);
      if (results.length !== 1 || results[0].uri !== EASYTIER_SNAPSHOT_URI
        || results[0].result !== dataShare.DataProxyErrorCode.SUCCESS) {
        throw new Error('系统拒绝订阅 EasyTier 实例快照');
      }
      subscribed = true;
      if (generation !== this.snapshotObserverGeneration) {
        this.unsubscribeSnapshotHandle(handle);
        return;
      }
      this.snapshotHandle = handle;
      const snapshot = await EasyTierApiService.readSnapshot(this.context, handle);
      if (generation === this.snapshotObserverGeneration) {
        EasyTierApiService.deliverSnapshot(this.context, snapshot);
      }
    } catch (error) {
      if (handle !== undefined && subscribed && this.snapshotHandle !== handle) {
        this.unsubscribeSnapshotHandle(handle);
      }
      if (generation === this.snapshotObserverGeneration) {
        const snapshot = new EasyTierSnapshotEvent(false, false,
          `订阅 EasyTier 实例状态失败：${EasyTierApiService.errorMessage(error as Object)}`);
        EasyTierApiService.deliverSnapshot(this.context, snapshot);
      }
    }
  }

  private unsubscribeSnapshotHandle(handle: dataShare.DataProxyHandle): void {
    const config: dataShare.DataProxyConfig = {
      type: dataShare.DataProxyType.SHARED_CONFIG,
    };
    try {
      handle.off('dataChange', [EASYTIER_SNAPSHOT_URI], config, this.onSnapshotChanged);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Failed to unsubscribe EasyTier snapshot: %{public}s',
        EasyTierApiService.errorMessage(error as Object));
    }
  }

  stopSnapshotObserver(): void {
    this.snapshotObserverGeneration += 1;
    this.snapshotStartPromise = undefined;
    const handle = this.snapshotHandle;
    this.snapshotHandle = undefined;
    if (handle === undefined) {
      return;
    }
    this.unsubscribeSnapshotHandle(handle);
  }

  static async readSnapshot(context: common.UIAbilityContext,
    existingHandle: dataShare.DataProxyHandle | undefined = undefined): Promise<EasyTierSnapshotEvent> {
    if (deviceInfo.sdkApiVersion < 20) {
      return new EasyTierSnapshotEvent(false, false, '当前系统版本不支持 EasyTier 实例状态共享');
    }
    const config: dataShare.DataProxyConfig = {
      type: dataShare.DataProxyType.SHARED_CONFIG,
    };
    try {
      let handle = existingHandle;
      if (handle === undefined) {
        handle = await dataShare.createDataProxyHandle();
      }
      const results = await handle.get([EASYTIER_SNAPSHOT_URI], config);
      if (results.length !== 1 || results[0].uri !== EASYTIER_SNAPSHOT_URI) {
        return new EasyTierSnapshotEvent(false, false, '未找到 EasyTier 实例快照');
      }
      const result = results[0];
      if (result.result === dataShare.DataProxyErrorCode.NO_PERMISSION) {
        return new EasyTierSnapshotEvent(false, false, 'EasyTier 未允许 RustDesk 读取实例状态');
      }
      if (result.result !== dataShare.DataProxyErrorCode.SUCCESS) {
        return new EasyTierSnapshotEvent(false, false, `读取 EasyTier 实例状态失败（${result.result}）`);
      }
      if (typeof result.value !== 'string') {
        return new EasyTierSnapshotEvent(false, false, 'EasyTier 实例快照不是文本');
      }
      return EasyTierApiService.decodeSnapshot(result.value);
    } catch (error) {
      return new EasyTierSnapshotEvent(false, false,
        `读取 EasyTier 实例状态失败：${EasyTierApiService.errorMessage(error as Object)}`);
    }
  }

  static saveConnectionIntent(context: common.UIAbilityContext, target: string,
    kind: EasyTierConnectionKind): boolean {
    const normalizedTarget = target.trim();
    if (normalizedTarget.length === 0 || normalizedTarget.length > MAX_TARGET_LENGTH
      || !EasyTierApiValidator.isConnectionKind(kind)) {
      return false;
    }
    try {
      const store = EasyTierApiService.getStore(context);
      store.putSync(INTENT_TARGET_KEY, normalizedTarget);
      store.putSync(INTENT_KIND_KEY, kind);
      store.putSync(INTENT_ISSUED_AT_KEY, Date.now());
      store.flushSync();
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save EasyTier connection intent: %{public}s',
        EasyTierApiService.errorMessage(error as Object));
      return false;
    }
  }

  static loadConnectionIntent(context: common.UIAbilityContext): EasyTierConnectionIntent | undefined {
    try {
      const store = EasyTierApiService.getStore(context);
      const target = (store.getSync(INTENT_TARGET_KEY, '') as string).trim();
      const kind = store.getSync(INTENT_KIND_KEY, '') as string;
      const issuedAt = store.getSync(INTENT_ISSUED_AT_KEY, 0) as number;
      if (target.length === 0 || target.length > MAX_TARGET_LENGTH
        || !EasyTierApiValidator.isConnectionKind(kind)
        || !EasyTierApiValidator.isCurrentTimestamp(issuedAt, Date.now())) {
        EasyTierApiService.clearConnectionIntent(context);
        return undefined;
      }
      return new EasyTierConnectionIntent(target, kind as EasyTierConnectionKind, issuedAt);
    } catch (_) {
      return undefined;
    }
  }

  static clearConnectionIntent(context: common.UIAbilityContext): void {
    try {
      const store = EasyTierApiService.getStore(context);
      EasyTierApiService.deleteKeys(store, [INTENT_TARGET_KEY, INTENT_KIND_KEY, INTENT_ISSUED_AT_KEY]);
      store.flushSync();
    } catch (_) {
    }
  }

  static cancelPending(context: common.UIAbilityContext): void {
    EasyTierApiService.clearPendingRequest(context);
    EasyTierApiService.clearConnectionIntent(context);
    EasyTierApiService.bufferedResult = undefined;
  }

  static async request(context: common.UIAbilityContext, operation: EasyTierApiOperation,
    instanceId: string = ''): Promise<EasyTierApiRequestOutcome> {
    if (deviceInfo.sdkApiVersion < 20) {
      return new EasyTierApiRequestOutcome(false, '', '当前系统版本不支持 EasyTier 跨应用预组网');
    }
    if (!EasyTierApiValidator.isOperation(operation)) {
      return new EasyTierApiRequestOutcome(false, '', 'EasyTier 操作不受支持');
    }
    const normalizedInstanceId = instanceId.trim();
    if (!EasyTierApiValidator.isInstanceId(normalizedInstanceId)) {
      return new EasyTierApiRequestOutcome(false, '', 'EasyTier 实例 ID 无效');
    }
    const existing = EasyTierApiService.loadPendingRequest(context);
    if (existing !== undefined) {
      return new EasyTierApiRequestOutcome(false, existing.requestId, '已有 EasyTier 请求正在等待结果');
    }

    const requestId = util.generateRandomUUID().toLowerCase();
    const issuedAt = Date.now();
    const pending = new EasyTierApiPendingRequest(requestId, operation, issuedAt, normalizedInstanceId);
    if (!EasyTierApiService.savePendingRequest(context, pending)) {
      return new EasyTierApiRequestOutcome(false, requestId, '无法保存 EasyTier 请求');
    }

    const payload: EasyTierApiRequestPayload = {
      schemaVersion: EASYTIER_API_SCHEMA_VERSION,
      requestId,
      operation,
      issuedAt,
    };
    payload.instanceId = normalizedInstanceId;

    try {
      const handle = await dataShare.createDataProxyHandle();
      const config: dataShare.DataProxyConfig = {
        type: dataShare.DataProxyType.SHARED_CONFIG,
      };
      const proxyData: dataShare.ProxyData[] = [{
        uri: EASYTIER_API_REQUEST_URI,
        value: JSON.stringify(payload),
        allowList: [EASYTIER_APP_IDENTIFIER],
      }];
      const results = await handle.publish(proxyData, config);
      if (results.length !== 1 || results[0].uri !== EASYTIER_API_REQUEST_URI
        || results[0].result !== dataShare.DataProxyErrorCode.SUCCESS) {
        throw new Error('系统拒绝发布 EasyTier 请求');
      }
    } catch (error) {
      EasyTierApiService.clearPendingRequest(context, requestId);
      return new EasyTierApiRequestOutcome(false, requestId,
        `发布 EasyTier 请求失败：${EasyTierApiService.errorMessage(error as Object)}`);
    }

    const want: Want = {
      bundleName: EASYTIER_BUNDLE_NAME,
      moduleName: EASYTIER_MODULE_NAME,
      abilityName: EASYTIER_ABILITY_NAME,
      action: EASYTIER_API_REQUEST_ACTION,
      uri: EASYTIER_API_REQUEST_URI,
      parameters: {
        'top.frankhan.easytier.api.requestId': requestId,
      },
    };
    try {
      await context.startAbility(want);
      return new EasyTierApiRequestOutcome(true, requestId, 'EasyTier 实例启动请求已发送');
    } catch (error) {
      EasyTierApiService.clearPendingRequest(context, requestId);
      return new EasyTierApiRequestOutcome(false, requestId,
        `无法打开 EasyTier：${EasyTierApiService.errorMessage(error as Object)}`);
    }
  }

  async handleWant(want: Want): Promise<void> {
    if (!EasyTierApiService.isResultWant(want)) {
      return;
    }
    if (!EasyTierApiValidator.isTrustedResultWant(want)) {
      hilog.warn(DOMAIN, TAG, 'Ignored untrusted EasyTier API result Want');
      return;
    }
    const requestId = EasyTierApiValidator.wantStringParameter(want, EASYTIER_API_REQUEST_ID_KEY);
    const operation = EasyTierApiValidator.wantStringParameter(want, EASYTIER_API_OPERATION_KEY);
    if (!EasyTierApiValidator.isRequestId(requestId) || !EasyTierApiValidator.isOperation(operation)) {
      hilog.warn(DOMAIN, TAG, 'Ignored malformed EasyTier API result Want');
      return;
    }
    const pending = EasyTierApiService.loadPendingRequest(this.context);
    if (pending === undefined || pending.requestId !== requestId || pending.operation !== operation) {
      hilog.warn(DOMAIN, TAG, 'Ignored stale EasyTier API result requestId=%{public}s', requestId);
      return;
    }
    if (this.activeRequestIds.has(requestId)) {
      return;
    }
    this.activeRequestIds.add(requestId);
    try {
      const payload = await this.readResult();
      const event = this.validateResult(payload, pending);
      this.finishPending(event, pending);
      this.deliver(event);
    } catch (error) {
      const message = EasyTierApiService.errorMessage(error as Object);
      const event = new EasyTierApiResultEvent(
        false,
        requestId,
        pending.operation,
        'INTERNAL_ERROR',
        message,
      );
      this.finishPending(event, pending);
      this.deliver(event);
    } finally {
      this.activeRequestIds.delete(requestId);
    }
  }

  private async readResult(): Promise<EasyTierApiResultPayload> {
    const config: dataShare.DataProxyConfig = {
      type: dataShare.DataProxyType.SHARED_CONFIG,
    };
    let results: dataShare.DataProxyGetResult[] = [];
    try {
      const handle = await dataShare.createDataProxyHandle();
      results = await handle.get([EASYTIER_API_RESULT_URI], config);
    } catch (error) {
      throw new Error(`读取 EasyTier 结果失败：${EasyTierApiService.errorMessage(error as Object)}`);
    }
    if (results.length !== 1 || results[0].uri !== EASYTIER_API_RESULT_URI) {
      throw new Error('未找到 EasyTier 结果');
    }
    const result = results[0];
    if (result.result === dataShare.DataProxyErrorCode.NO_PERMISSION) {
      throw new Error('EasyTier 未允许 RustDesk 读取结果');
    }
    if (result.result !== dataShare.DataProxyErrorCode.SUCCESS) {
      throw new Error(`读取 EasyTier 结果失败（${result.result}）`);
    }
    if (typeof result.value !== 'string' || result.value.length === 0
      || result.value.length > MAX_SHARED_VALUE_LENGTH) {
      throw new Error('EasyTier 结果为空或超过 4096 字节');
    }
    try {
      const payload = JSON.parse(result.value) as EasyTierApiResultPayload;
      if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
        throw new Error('EasyTier 结果不是对象');
      }
      return payload;
    } catch (error) {
      throw new Error(`EasyTier 结果 JSON 无效：${EasyTierApiService.errorMessage(error as Object)}`);
    }
  }

  private validateResult(payload: EasyTierApiResultPayload,
    pending: EasyTierApiPendingRequest): EasyTierApiResultEvent {
    if (payload.schemaVersion !== EASYTIER_API_SCHEMA_VERSION
      || payload.requestId !== pending.requestId || payload.operation !== pending.operation) {
      return this.invalidEvent(pending, 'EasyTier 结果与当前请求不匹配');
    }
    if (typeof payload.issuedAt !== 'number'
      || !EasyTierApiValidator.isCurrentTimestamp(payload.issuedAt, Date.now())
      || payload.issuedAt + FUTURE_CLOCK_SKEW_MS < pending.issuedAt) {
      return this.invalidEvent(pending, 'EasyTier 结果时间无效或已过期');
    }
    const code = typeof payload.code === 'string' ? payload.code.trim() : '';
    const message = typeof payload.message === 'string' && payload.message.trim().length > 0
      ? payload.message.trim().substring(0, 512) : 'EasyTier 未返回结果说明';
    if (payload.ok !== true || code !== EASYTIER_RESULT_OK) {
      return new EasyTierApiResultEvent(false, pending.requestId, pending.operation,
        code.length > 0 ? code : 'INVALID_RESULT', message);
    }

    const event = new EasyTierApiResultEvent(true, pending.requestId, pending.operation, code, message);
    const instance = EasyTierApiService.copyInstance(payload.instance);
    if (instance === undefined || instance.instanceId !== pending.instanceId) {
      return this.invalidEvent(pending, 'EasyTier 实例结果无效或与请求不匹配');
    }
    if (instance.state !== EASYTIER_STATE_RUNNING) {
      return this.invalidEvent(pending, 'EasyTier 未确认实例处于运行状态');
    }
    event.instance = instance;
    return event;
  }

  private static copyInstance(payload: EasyTierApiInstancePayload | undefined): EasyTierInstanceSummary | undefined {
    if (payload === undefined) {
      return undefined;
    }
    const instanceId = typeof payload.instanceId === 'string' ? payload.instanceId : '';
    const instanceName = typeof payload.instanceName === 'string' ? payload.instanceName.trim() : '';
    const state = typeof payload.state === 'string' ? payload.state : '';
    if (!EasyTierApiValidator.isInstanceId(instanceId) || instanceName.length === 0
      || instanceName.length > MAX_INSTANCE_NAME_LENGTH || !EasyTierApiValidator.isState(state)
      || /[\u0000-\u001f\u007f]/.test(instanceName)) {
      return undefined;
    }
    const virtualIpv4 = typeof payload.virtualIpv4 === 'string'
      ? payload.virtualIpv4.trim().substring(0, 64) : '';
    const peerCount = typeof payload.peerCount === 'number' && Number.isSafeInteger(payload.peerCount)
      && payload.peerCount >= 0 ? payload.peerCount : 0;
    return new EasyTierInstanceSummary(instanceId, instanceName, state, virtualIpv4, peerCount);
  }

  private invalidEvent(pending: EasyTierApiPendingRequest, message: string): EasyTierApiResultEvent {
    return new EasyTierApiResultEvent(false, pending.requestId, pending.operation, 'INVALID_RESULT', message);
  }

  private finishPending(event: EasyTierApiResultEvent, pending: EasyTierApiPendingRequest): void {
    const intent = EasyTierApiService.loadConnectionIntent(this.context);
    if (intent !== undefined) {
      event.target = intent.target;
      event.kind = intent.kind;
    }
    EasyTierApiService.clearPendingRequest(this.context, pending.requestId);
    EasyTierApiService.clearConnectionIntent(this.context);
    if (intent === undefined) {
      event.ok = false;
      event.code = 'MISSING_CONNECTION_INTENT';
      event.message = 'RustDesk 待恢复连接已丢失或过期';
    }
  }

  private deliver(event: EasyTierApiResultEvent): void {
    EasyTierApiService.bufferedResult = event;
    try {
      this.context.eventHub.emit(EASYTIER_API_RESULT_EVENT, event);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to deliver EasyTier API result: %{public}s',
        EasyTierApiService.errorMessage(error as Object));
    }
  }

  private static decodeSnapshot(value: string): EasyTierSnapshotEvent {
    if (value.length === 0 || value.length > MAX_SHARED_VALUE_LENGTH) {
      return new EasyTierSnapshotEvent(false, false, 'EasyTier 实例快照为空或超过 4096 字节');
    }
    let payload: EasyTierSnapshotPayload;
    try {
      payload = JSON.parse(value) as EasyTierSnapshotPayload;
      if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
        return new EasyTierSnapshotEvent(false, false, 'EasyTier 实例快照不是对象');
      }
    } catch (error) {
      return new EasyTierSnapshotEvent(false, false,
        `EasyTier 实例快照 JSON 无效：${EasyTierApiService.errorMessage(error as Object)}`);
    }
    if (payload.schemaVersion !== EASYTIER_API_SCHEMA_VERSION
      || typeof payload.updatedAt !== 'number' || !Number.isSafeInteger(payload.updatedAt)
      || typeof payload.ttlMs !== 'number' || !Number.isSafeInteger(payload.ttlMs)
      || payload.ttlMs <= 0 || payload.ttlMs > MAX_SNAPSHOT_TTL_MS
      || !Array.isArray(payload.instances) || payload.instances.length > MAX_INSTANCE_COUNT) {
      return new EasyTierSnapshotEvent(false, false, 'EasyTier 实例快照字段无效');
    }
    const now = Date.now();
    const fresh = payload.updatedAt > 0 && payload.updatedAt - now <= FUTURE_CLOCK_SKEW_MS
      && now - payload.updatedAt <= payload.ttlMs;
    const event = new EasyTierSnapshotEvent(true, fresh,
      fresh ? 'EasyTier 实例状态已同步' : 'EasyTier 实例状态已过期', payload.updatedAt, payload.ttlMs);
    for (let index = 0; index < payload.instances.length; index += 1) {
      const instance = EasyTierApiService.copyInstance(payload.instances[index]);
      if (instance === undefined) {
        return new EasyTierSnapshotEvent(false, false, 'EasyTier 实例快照包含无效项目');
      }
      event.instances.push(instance);
    }
    event.truncated = payload.truncated === true;
    return event;
  }

  private static deliverSnapshot(context: common.UIAbilityContext, snapshot: EasyTierSnapshotEvent): void {
    EasyTierApiService.bufferedSnapshot = snapshot;
    try {
      context.eventHub.emit(EASYTIER_SNAPSHOT_EVENT, snapshot);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to deliver EasyTier snapshot: %{public}s',
        EasyTierApiService.errorMessage(error as Object));
    }
  }

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    try {
      return preferences.getPreferencesSync(context, { name: PREFERENCES_NAME });
    } catch (error) {
      throw new Error(`无法访问 EasyTier 请求状态：${EasyTierApiService.errorMessage(error as Object)}`);
    }
  }

  private static savePendingRequest(context: common.UIAbilityContext,
    pending: EasyTierApiPendingRequest): boolean {
    try {
      const store = EasyTierApiService.getStore(context);
      store.putSync(PENDING_REQUEST_ID_KEY, pending.requestId);
      store.putSync(PENDING_OPERATION_KEY, pending.operation);
      store.putSync(PENDING_ISSUED_AT_KEY, pending.issuedAt);
      store.putSync(PENDING_INSTANCE_ID_KEY, pending.instanceId);
      store.flushSync();
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save EasyTier request: %{public}s',
        EasyTierApiService.errorMessage(error as Object));
      return false;
    }
  }

  private static loadPendingRequest(context: common.UIAbilityContext): EasyTierApiPendingRequest | undefined {
    try {
      const store = EasyTierApiService.getStore(context);
      const requestId = store.getSync(PENDING_REQUEST_ID_KEY, '') as string;
      const operation = store.getSync(PENDING_OPERATION_KEY, '') as string;
      const issuedAt = store.getSync(PENDING_ISSUED_AT_KEY, 0) as number;
      const instanceId = store.getSync(PENDING_INSTANCE_ID_KEY, '') as string;
      if (!EasyTierApiValidator.isRequestId(requestId) || !EasyTierApiValidator.isOperation(operation)
        || !EasyTierApiValidator.isCurrentTimestamp(issuedAt, Date.now())
        || !EasyTierApiValidator.isInstanceId(instanceId)) {
        EasyTierApiService.clearPendingRequest(context);
        return undefined;
      }
      return new EasyTierApiPendingRequest(
        requestId,
        operation as EasyTierApiOperation,
        issuedAt,
        instanceId,
      );
    } catch (_) {
      return undefined;
    }
  }

  private static clearPendingRequest(context: common.UIAbilityContext, requestId: string = ''): void {
    try {
      const store = EasyTierApiService.getStore(context);
      if (requestId.length > 0
        && (store.getSync(PENDING_REQUEST_ID_KEY, '') as string) !== requestId) {
        return;
      }
      EasyTierApiService.deleteKeys(store, [
        PENDING_REQUEST_ID_KEY,
        PENDING_OPERATION_KEY,
        PENDING_ISSUED_AT_KEY,
        PENDING_INSTANCE_ID_KEY,
      ]);
      store.flushSync();
    } catch (_) {
    }
  }

  private static deleteKeys(store: preferences.Preferences, keys: string[]): void {
    try {
      for (let index = 0; index < keys.length; index += 1) {
        if (store.hasSync(keys[index])) {
          store.deleteSync(keys[index]);
        }
      }
    } catch (error) {
      throw new Error(`无法清理 EasyTier 请求状态：${EasyTierApiService.errorMessage(error as Object)}`);
    }
  }

  private static errorMessage(error: Object): string {
    const businessError = error as BusinessError;
    if (typeof businessError.message === 'string' && businessError.message.trim().length > 0) {
      return businessError.message.trim();
    }
    const fallback = `${error}`.trim();
    return fallback.length > 0 ? fallback : '未知错误';
  }
}
