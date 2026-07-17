import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { TransferProgress } from '../pages/rustdesk/TransferProgress';
import { TransferItem } from '../pages/rustdesk/RustDeskSessionTypes';
import { DataTransferNotification } from './DataTransferNotification';

const DATA_TRANSFER_REQUEST_CODE = 6101;
const FILE_NOTIFICATION_UPDATE_INTERVAL_MS = 1000;
const SESSION_NOTIFICATION_UPDATE_INTERVAL_MS = 30000;

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
  private heartbeatProgress: number = 0;
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
    this.createWantAgent().then((agent: WantAgent) => {
      if (!this.ownsLifecycle(generation, callbacks)) {
        this.ensureRunning();
        return;
      }
      const request = new backgroundTaskManager.ContinuousTaskRequest();
      request.backgroundTaskModes = [backgroundTaskManager.BackgroundTaskMode.MODE_DATA_TRANSFER];
      request.wantAgent = agent;
      backgroundTaskManager.startBackgroundRunning(this.context, request)
        .then((notification: backgroundTaskManager.ContinuousTaskNotification) => {
          const taskId = notification.continuousTaskId;
          if (!this.ownsLifecycle(generation, callbacks)) {
            if (taskId !== undefined && taskId >= 0) {
              backgroundTaskManager.stopBackgroundRunning(this.context, taskId)
                .catch(() => {});
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
            backgroundTaskManager.stopBackgroundRunning(this.context, taskId)
              .catch(() => {});
            return;
          }
          this.taskId = taskId;
          this.notificationId = notification.notificationId;
          this.registerCancellation();
          this.startNotificationTimer();
          this.publishProgress(true);
        })
        .catch(() => {
          if (!this.ownsLifecycle(generation, callbacks)) {
            this.ensureRunning();
            return;
          }
          this.taskStartInFlight = false;
          this.handleStartFailure(generation, callbacks, '无法启动数据传输后台任务');
        });
    }).catch(() => {
      if (!this.ownsLifecycle(generation, callbacks)) {
        this.ensureRunning();
        return;
      }
      this.taskStartInFlight = false;
      this.handleStartFailure(generation, callbacks, '无法创建数据传输通知操作');
    });
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
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };
    try {
      return await wantAgent.getWantAgent(info);
    } catch (error) {
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
      this.heartbeatProgress = (this.heartbeatProgress + 1) % 100;
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
    }).catch(() => {
      if (!this.ownsNotification(generation, callbacks, notificationId)) {
        this.cancelStaleNotification(notificationId);
        return;
      }
      this.lastNotificationAt = now;
      this.notificationInFlight = false;
      callbacks.reportFailure('无法更新数据传输实况窗');
    });
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
    callbacks.reportFailure(message);
  }

  private hasActiveSession(callbacks: DataTransferBackgroundCallbacks): boolean {
    return this.callbacks === callbacks &&
      (callbacks.isRemoteSessionActive() || callbacks.isFileTransferSessionActive());
  }
}
