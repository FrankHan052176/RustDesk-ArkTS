import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TransferProgress } from '../pages/rustdesk/TransferProgress';
import { TransferItem } from '../pages/rustdesk/RustDeskSessionTypes';
import { DataTransferNotification } from './DataTransferNotification';

const DATA_TRANSFER_REQUEST_CODE = 0;
const DATA_TRANSFER_BACKGROUND_MODE = 'dataTransfer';
const FILE_NOTIFICATION_UPDATE_INTERVAL_MS = 1000;
const SESSION_NOTIFICATION_UPDATE_INTERVAL_MS = 5000;
const SESSION_PROGRESS_STEP = 0.1;
const SESSION_PROGRESS_FLOOR = 12;
const SESSION_PROGRESS_CEILING = 88;
const DOMAIN = 0xFF00;
const TAG = 'RustDeskDataTransfer';

export const DATA_TRANSFER_BACKGROUND_BIND_EVENT = 'rustdesk.data_transfer.bind';
export const DATA_TRANSFER_BACKGROUND_CHANGE_EVENT = 'rustdesk.data_transfer.changed';
export const DATA_TRANSFER_BACKGROUND_UNBIND_EVENT = 'rustdesk.data_transfer.unbind';

export interface DataTransferBackgroundCallbacks {
  isRemoteSessionActive: () => boolean;
  isFileTransferSessionActive: () => boolean;
  getSessionLabel: () => string;
  getTransfers: () => TransferItem[];
  cancelAllNativeTransfers: () => void;
  closeRemoteSession: () => void;
  closeFileTransferSession: () => void;
  reportFailure: (message: string) => void;
}

export class DataTransferBackgroundBinding {
  public callbacks: DataTransferBackgroundCallbacks;

  constructor(callbacks: DataTransferBackgroundCallbacks) {
    this.callbacks = callbacks;
  }
}

export class DataTransferBackgroundService {
  private readonly context: common.UIAbilityContext;
  private callbacks: DataTransferBackgroundCallbacks | undefined = undefined;
  private taskId: number = -1;
  private notificationId: number = -1;
  private notificationTimer: number = -1;
  private lastNotificationAt: number = 0;
  private heartbeatProgress: number = SESSION_PROGRESS_FLOOR;
  private notificationInFlight: boolean = false;
  private cancellationRegistered: boolean = false;
  private taskStartInFlight: boolean = false;
  private cancellationInProgress: boolean = false;
  private lifecycleGeneration: number = 0;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  public bind(callbacks: DataTransferBackgroundCallbacks): void {
    if (this.callbacks === callbacks) {
      return;
    }
    this.stop();
    this.callbacks = callbacks;
    this.ensureRunning();
  }

  public unbind(): void {
    this.stop();
    this.callbacks = undefined;
  }

  public onStateChanged(): void {
    const callbacks = this.callbacks;
    if (!callbacks) {
      return;
    }
    if (this.cancellationInProgress) {
      if (!this.hasActiveSession(callbacks)) {
        this.cancellationInProgress = false;
      }
      return;
    }
    if (!this.hasActiveSession(callbacks)) {
      this.stop();
      return;
    }
    this.ensureRunning();
    this.publishProgress(false);
  }

  public onBackground(): void {
    this.ensureRunning();
    this.publishProgress(true);
  }

  public onForeground(): void {
    this.ensureRunning();
  }

  public stop(): void {
    this.invalidateLifecycle();
    this.stopNotificationTimer();
    this.unregisterCancellation();
    const taskId = this.taskId;
    this.taskId = -1;
    if (taskId >= 0) {
      backgroundTaskManager.stopBackgroundRunning(this.context, taskId)
        .catch(() => {});
    }
    this.cancelNotification();
  }

  public destroy(): void {
    this.stop();
    this.callbacks = undefined;
  }

  private ensureRunning(): void {
    const callbacks = this.callbacks;
    if (!callbacks || this.cancellationInProgress || !this.hasActiveSession(callbacks) ||
      this.taskStartInFlight || this.taskId >= 0) {
      return;
    }
    this.start(callbacks);
  }

  private start(callbacks: DataTransferBackgroundCallbacks): void {
    const generation = this.lifecycleGeneration;
    this.taskStartInFlight = true;
    void this.startContinuousTask(generation, callbacks);
  }

  private async startContinuousTask(generation: number, callbacks: DataTransferBackgroundCallbacks): Promise<void> {
    try {
      const agent = await this.createWantAgent();
      if (!this.ownsLifecycle(generation, callbacks)) {
        this.ensureRunning();
        return;
      }
      const modes: string[] = [DATA_TRANSFER_BACKGROUND_MODE];
      const notification = await backgroundTaskManager.startBackgroundRunning(this.context, modes, agent);
      const taskId = notification.continuousTaskId;
      if (!this.ownsLifecycle(generation, callbacks)) {
        if (taskId !== undefined && taskId >= 0) {
          await backgroundTaskManager.stopBackgroundRunning(this.context, taskId).catch(() => {});
        }
        this.ensureRunning();
        return;
      }
      this.taskStartInFlight = false;
      if (taskId === undefined || taskId < 0) {
        this.handleStartFailure(generation, callbacks, '系统未返回数据传输后台任务 ID');
        return;
      }
      if (!this.hasActiveSession(callbacks)) {
        await backgroundTaskManager.stopBackgroundRunning(this.context, taskId).catch(() => {});
        return;
      }
      this.taskId = taskId;
      this.notificationId = notification.notificationId;
      hilog.info(DOMAIN, TAG,
        'Data-transfer keep-alive started taskId=%{public}d notificationId=%{public}d',
        taskId, this.notificationId);
      this.registerCancellation();
      this.startNotificationTimer();
      this.publishProgress(true);
    } catch (error) {
      if (!this.ownsLifecycle(generation, callbacks)) {
        this.ensureRunning();
        return;
      }
      this.taskStartInFlight = false;
      const businessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'startBackgroundRunning dataTransfer failed code=%{public}d message=%{public}s',
        businessError.code, businessError.message);
      this.handleStartFailure(generation, callbacks, '无法启动数据传输后台任务');
    }
  }

  private ownsLifecycle(generation: number, callbacks: DataTransferBackgroundCallbacks): boolean {
    return this.lifecycleGeneration === generation && this.callbacks === callbacks;
  }

  private ownsNotification(generation: number, callbacks: DataTransferBackgroundCallbacks,
    notificationId: number): boolean {
    return this.ownsLifecycle(generation, callbacks) && this.notificationId === notificationId;
  }

  private invalidateLifecycle(): void {
    this.lifecycleGeneration += 1;
    this.taskStartInFlight = false;
    this.notificationInFlight = false;
  }

  private async createWantAgent(): Promise<WantAgent> {
    const info: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: this.context.abilityInfo.bundleName,
        abilityName: this.context.abilityInfo.name,
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: DATA_TRANSFER_REQUEST_CODE,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };
    try {
      return await wantAgent.getWantAgent(info);
    } catch (error) {
      hilog.error(DOMAIN, TAG,
        'WantAgent creation failed error=%{public}s bundle=%{public}s ability=%{public}s',
        String(error),
        this.context.abilityInfo.bundleName, this.context.abilityInfo.name);
      throw new Error(String(error));
    }
  }

  private registerCancellation(): void {
    if (this.cancellationRegistered) {
      return;
    }
    try {
      backgroundTaskManager.on('continuousTaskCancel', this.onContinuousTaskCancel);
      this.cancellationRegistered = true;
    } catch (_) {
      this.cancellationRegistered = false;
    }
  }

  private unregisterCancellation(): void {
    if (!this.cancellationRegistered) {
      return;
    }
    try {
      backgroundTaskManager.off('continuousTaskCancel', this.onContinuousTaskCancel);
    } catch (_) {
    }
    this.cancellationRegistered = false;
  }

  private onContinuousTaskCancel = (info: backgroundTaskManager.ContinuousTaskCancelInfo): void => {
    if (this.taskId < 0 || info.id !== this.taskId) {
      return;
    }
    const callbacks = this.callbacks;
    const taskId = this.taskId;
    hilog.warn(DOMAIN, TAG, 'Data-transfer keep-alive cancelled taskId=%{public}d reason=%{public}s',
      taskId, String(info.reason));
    this.cancellationInProgress = true;
    this.invalidateLifecycle();
    this.taskId = -1;
    this.stopNotificationTimer();
    this.unregisterCancellation();
    this.cancelNotification();
    backgroundTaskManager.stopBackgroundRunning(this.context, taskId)
      .catch(() => {});
    if (callbacks) {
      callbacks.cancelAllNativeTransfers();
      callbacks.closeFileTransferSession();
      callbacks.closeRemoteSession();
    }
  };

  private startNotificationTimer(): void {
    if (this.notificationTimer >= 0) {
      return;
    }
    this.notificationTimer = setInterval(
      () => this.publishProgress(false),
      FILE_NOTIFICATION_UPDATE_INTERVAL_MS,
    ) as number;
  }

  private stopNotificationTimer(): void {
    if (this.notificationTimer < 0) {
      return;
    }
    clearInterval(this.notificationTimer);
    this.notificationTimer = -1;
  }

  private publishProgress(force: boolean): void {
    const notificationId = this.notificationId;
    const callbacks = this.callbacks;
    if (notificationId < 0 || !callbacks || this.notificationInFlight || !this.hasActiveSession(callbacks)) {
      return;
    }
    const transfers = callbacks.getTransfers();
    const hasActiveTransfer = TransferProgress.activeCount(transfers) > 0;
    const interval = hasActiveTransfer ? FILE_NOTIFICATION_UPDATE_INTERVAL_MS : SESSION_NOTIFICATION_UPDATE_INTERVAL_MS;
    const now = Date.now();
    if (!force && now - this.lastNotificationAt < interval) {
      return;
    }
    if (!hasActiveTransfer) {
      this.advanceSessionProgress();
    }
    const generation = this.lifecycleGeneration;
    this.notificationInFlight = true;
    notificationManager.publish(DataTransferNotification.build(notificationId, {
      remoteSessionActive: callbacks.isRemoteSessionActive(),
      fileTransferSessionActive: callbacks.isFileTransferSessionActive(),
      sessionLabel: callbacks.getSessionLabel(),
      transfers,
      heartbeatProgress: this.heartbeatProgress,
    })).then(() => {
      if (!this.ownsNotification(generation, callbacks, notificationId)) {
        this.cancelStaleNotification(notificationId);
        return;
      }
      this.lastNotificationAt = now;
      this.notificationInFlight = false;
      if (force) {
        hilog.info(DOMAIN, TAG, 'Data-transfer live-view notification published id=%{public}d', notificationId);
      }
    }).catch(() => {
      if (!this.ownsNotification(generation, callbacks, notificationId)) {
        this.cancelStaleNotification(notificationId);
        return;
      }
      this.lastNotificationAt = now;
      this.notificationInFlight = false;
      hilog.error(DOMAIN, TAG, 'Data-transfer live-view notification publish failed id=%{public}d', notificationId);
      callbacks.reportFailure('无法更新数据传输实况窗');
    });
  }

  private advanceSessionProgress(): void {
    if (this.heartbeatProgress >= SESSION_PROGRESS_CEILING) {
      this.heartbeatProgress = SESSION_PROGRESS_FLOOR;
      return;
    }
    this.heartbeatProgress = Math.round(
      (this.heartbeatProgress + SESSION_PROGRESS_STEP) * 10,
    ) / 10;
  }

  private cancelNotification(): void {
    if (this.notificationId < 0) {
      return;
    }
    const notificationId = this.notificationId;
    this.notificationId = -1;
    this.cancelNotificationById(notificationId);
  }

  private cancelStaleNotification(notificationId: number): void {
    if (this.notificationId === notificationId) {
      return;
    }
    this.cancelNotificationById(notificationId);
  }

  private cancelNotificationById(notificationId: number): void {
    notificationManager.cancel(notificationId)
      .catch(() => {});
  }

  private handleStartFailure(generation: number, callbacks: DataTransferBackgroundCallbacks, message: string): void {
    if (!this.ownsLifecycle(generation, callbacks)) {
      return;
    }
    this.invalidateLifecycle();
    this.stopNotificationTimer();
    this.unregisterCancellation();
    const taskId = this.taskId;
    this.taskId = -1;
    if (taskId >= 0) {
      backgroundTaskManager.stopBackgroundRunning(this.context, taskId)
        .catch(() => {});
    }
    this.cancelNotification();
    hilog.error(DOMAIN, TAG, '%{public}s', message);
    callbacks.reportFailure(message);
  }

  private hasActiveSession(callbacks: DataTransferBackgroundCallbacks): boolean {
    return this.callbacks === callbacks &&
      (callbacks.isRemoteSessionActive() || callbacks.isFileTransferSessionActive());
  }
}
