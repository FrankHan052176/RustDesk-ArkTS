import { notificationManager } from '@kit.NotificationKit';
import { TransferProgress } from '../pages/rustdesk/TransferProgress';
import { TransferItem } from '../pages/rustdesk/RustDeskSessionTypes';

export interface DataTransferNotificationState {
  remoteSessionActive: boolean;
  fileTransferSessionActive: boolean;
  sessionLabel: string;
  transfers: TransferItem[];
  heartbeatProgress: number;
}

function activeFileName(items: TransferItem[]): string {
  for (let index = 0; index < items.length; index += 1) {
    const item = items[index];
    if (item.state === 'running' || item.state === 'queued' || item.state === 'awaiting_override') {
      return item.fileName;
    }
  }
  return items.length > 0 ? items[0].fileName : 'RustDesk';
}

export class DataTransferNotification {
  public static build(notificationId: number,
    state: DataTransferNotificationState): notificationManager.NotificationRequest {
    const activeTransferCount = TransferProgress.activeCount(state.transfers);
    const transferPercent = TransferProgress.percent(state.transfers);
    const hasActiveTransfer = activeTransferCount > 0;
    const progress = hasActiveTransfer ? (transferPercent ?? 0) : state.heartbeatProgress;
    const title = hasActiveTransfer ? 'RustDesk 文件传输' : 'RustDesk 远程连接';
    const text = DataTransferNotification.textFor(state, activeTransferCount, transferPercent);
    const fileName = hasActiveTransfer ? activeFileName(state.transfers) :
      DataTransferNotification.sessionNameFor(state);
    return {
      id: notificationId,
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
      isOngoing: true,
      tapDismissed: false,
      isAlertOnce: true,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
        systemLiveView: {
          typeCode: 8,
          title,
          text,
          capsule: {
            title: hasActiveTransfer ? `${progress}%` : '连接中',
          },
          progress: {
            maxValue: 100,
            currentValue: progress,
            isPercentage: hasActiveTransfer,
          },
        },
      },
      template: {
        name: 'downloadTemplate',
        data: {
          title,
          fileName,
          progressValue: progress,
        },
      },
    };
  }

  private static textFor(state: DataTransferNotificationState, activeTransferCount: number,
    transferPercent: number | undefined): string {
    if (activeTransferCount > 0) {
      const progress = transferPercent === undefined ? '正在准备' : `${transferPercent}%`;
      return activeTransferCount > 1 ? `${activeTransferCount} 个文件 · ${progress}` : `文件传输 · ${progress}`;
    }
    if (state.remoteSessionActive) {
      return state.fileTransferSessionActive ? '远控与文件数据通道保持连接' : '远程数据通道保持连接';
    }
    return '文件传输会话保持连接';
  }

  private static sessionNameFor(state: DataTransferNotificationState): string {
    const label = state.sessionLabel.trim();
    if (label.length > 0) {
      return label;
    }
    return state.fileTransferSessionActive ? '文件传输会话' : '远程会话';
  }
}
