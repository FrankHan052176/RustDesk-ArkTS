import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskHostBg';
const AUDIO_RECORDING_BACKGROUND_MODE = 'audioRecording';
const CONTROLLED_HOST_REQUEST_CODE = 27;

export class ControlledHostBackgroundService {
  private readonly context: common.UIAbilityContext;
  private readonly onCancelled: () => void;
  private taskId: number = -1;
  private notificationId: number = -1;
  private cancellationRegistered: boolean = false;
  private startInFlight: boolean = false;
  private generation: number = 0;

  constructor(context: common.UIAbilityContext, onCancelled: () => void) {
    this.context = context;
    this.onCancelled = onCancelled;
  }

  async start(): Promise<boolean> {
    if (this.taskId >= 0) {
      return true;
    }
    if (this.startInFlight) {
      return false;
    }
    const currentGeneration = this.generation;
    this.startInFlight = true;
    try {
      const agent = await this.createWantAgent();
      const modes: string[] = [AUDIO_RECORDING_BACKGROUND_MODE];
      const notification = await backgroundTaskManager.startBackgroundRunning(this.context, modes, agent);
      const taskId = notification.continuousTaskId;
      if (currentGeneration !== this.generation) {
        if (taskId !== undefined && taskId >= 0) {
          await backgroundTaskManager.stopBackgroundRunning(this.context, taskId).catch(() => {});
        }
        return false;
      }
      if (taskId === undefined || taskId < 0) {
        return false;
      }
      this.taskId = taskId;
      this.notificationId = notification.notificationId;
      this.registerCancellation();
      hilog.info(DOMAIN, TAG, 'View-only host background task started id=%{public}d', taskId);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'View-only host background task failed: %{public}s', String(error));
      return false;
    } finally {
      this.startInFlight = false;
    }
  }

  stop(): void {
    this.generation += 1;
    this.startInFlight = false;
    this.unregisterCancellation();
    const taskId = this.taskId;
    this.taskId = -1;
    if (taskId >= 0) {
      backgroundTaskManager.stopBackgroundRunning(this.context, taskId).catch(() => {});
    }
    this.cancelNotification();
  }

  isRunning(): boolean {
    return this.taskId >= 0;
  }

  private async createWantAgent(): Promise<WantAgent> {
    const info: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: this.context.abilityInfo.bundleName,
        abilityName: this.context.abilityInfo.name,
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: CONTROLLED_HOST_REQUEST_CODE,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };
    return wantAgent.getWantAgent(info);
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

  private readonly onContinuousTaskCancel =
    (info: backgroundTaskManager.ContinuousTaskCancelInfo): void => {
      if (this.taskId < 0 || info.id !== this.taskId) {
        return;
      }
      this.taskId = -1;
      this.unregisterCancellation();
      this.cancelNotification();
      this.onCancelled();
    };

  private cancelNotification(): void {
    if (this.notificationId < 0) {
      return;
    }
    const notificationId = this.notificationId;
    this.notificationId = -1;
    notificationManager.cancel(notificationId).catch(() => {});
  }
}
