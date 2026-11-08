import { nearbyShareService } from './NearbyShareService';
import { nativeShareBridge } from './NativeShareBridge';
import { displaySharePickerStore } from './DisplaySharePickerStore';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ShareStartOptions,
  ShareStartResult,
  ShareStopResult,
  ShareStatusResult,
  ShareState,
  shareReasonText,
} from './ShareTypes';

const POLL_INTERVAL_MS = 1000;

@ObservedV2
export class ShareCoordinatorState {
  @Trace state: ShareState = 'idle';
  @Trace shareEpoch: string = '';
  @Trace sessionId: string = '';
  @Trace display: number = -1;
  @Trace sharedNetworkId: string = '';
  @Trace endpoint: string = '';
  @Trace expiresAtMs: number = 0;
  @Trace viewerConnected: boolean = false;
  @Trace units: number = 0;
  @Trace bytes: number = 0;
  @Trace dropped: number = 0;
  @Trace resyncs: number = 0;
  @Trace keyframeRequests: number = 0;
  @Trace encrypted: boolean = false;
  @Trace peerVerified: boolean = false;
  @Trace terminalReason: string = '';
  @Trace inviteCode: string = '';
  @Trace confirmDialogVisible: boolean = false;
  @Trace inviteDialogVisible: boolean = false;
  @Trace busy: boolean = false;
  @Trace statusMessage: string = '';
}

export class ShareCoordinator {
  readonly state: ShareCoordinatorState = new ShareCoordinatorState();
  private pollTimer: number = -1;
  private onStoppedCallback?: (reason: string) => void;

  setOnStopped(callback?: (reason: string) => void): void {
    this.onStoppedCallback = callback;
  }

  isSharing(): boolean {
    const s = this.state.state;
    return s === 'arming' || s === 'ready' || s === 'listening' || s === 'connected' || s === 'stopping';
  }

  async start(options: ShareStartOptions): Promise<ShareStartResult> {
    if (this.isSharing()) {
      return { ok: false, error: 'share_busy', message: '转分享已在运行中' };
    }
    this.state.busy = true;
    this.state.state = 'arming';
    this.state.sessionId = options.sessionId;
    this.state.display = options.display;
    this.state.sharedNetworkId = '';
    this.state.terminalReason = '';
    this.state.statusMessage = '正在准备屏幕分享…';

    try {
      const res = await nativeShareBridge.start(options);
      if (!res.ok) {
        this.state.state = 'failed';
        this.state.terminalReason = res.reason || res.error || 'start_failed';
        this.state.statusMessage = res.message || res.error || '转分享启动失败';
        this.clearInvite();
        this.hideInviteDialog();
        return res;
      }

      this.state.shareEpoch = res.shareEpoch ?? '';
      this.state.inviteCode = res.inviteCode ?? '';
      this.state.expiresAtMs = res.expiresAtMs ?? 0;
      this.state.endpoint = res.endpoint ?? '';
      this.state.state = 'listening';
      this.state.statusMessage = '转分享已就绪，等待观看端连接';
      this.startPolling();
      return res;
    } catch (err) {
      this.state.state = 'failed';
      this.state.terminalReason = String(err);
      this.state.statusMessage = `转分享异常: ${String(err)}`;
      this.clearInvite();
      this.hideInviteDialog();
      return { ok: false, error: String(err), message: String(err) };
    } finally {
      this.state.busy = false;
    }
  }

  async stop(): Promise<ShareStopResult> {
    const epoch = this.state.shareEpoch;
    nearbyShareService.closeSource(epoch);
    this.state.busy = true;
    this.state.state = 'stopping';
    this.state.statusMessage = '正在停止转分享…';
    this.clearInvite();

    try {
      const res = await nativeShareBridge.stop(epoch);
      if (!res.ok || !res.reclaimed) {
        this.state.state = 'stopping';
        this.state.statusMessage = res.message || '等待原生转发服务确认回收';
        this.startPolling();
        return res;
      }
      this.state.state = 'stopped';
      this.state.sharedNetworkId = '';
      this.state.terminalReason = res.reason || 'user_stop';
      this.state.statusMessage = shareReasonText(this.state.terminalReason);
      this.stopPolling();
      if (this.onStoppedCallback) {
        this.onStoppedCallback(this.state.terminalReason);
      }
      return res;
    } catch (err) {
      this.state.state = 'stopping';
      this.state.statusMessage = `无法确认转发服务回收: ${String(err)}`;
      this.startPolling();
      return { ok: false, message: String(err) };
    } finally {
      this.state.busy = false;
    }
  }

  refreshStatus(): ShareStatusResult {
    const status = nativeShareBridge.status();
    this.applyStatus(status);
    return status;
  }

  private applyStatus(status: ShareStatusResult): void {
    if (!status) {
      return;
    }
    this.state.state = status.state ?? this.state.state;
    if (status.display !== undefined) {
      this.state.display = status.display.index;
    }
    if (status.endpoint) {
      this.state.endpoint = status.endpoint;
    }
    if (status.expiresAtMs !== undefined) {
      this.state.expiresAtMs = status.expiresAtMs;
    }
    if (status.viewerConnected !== undefined) {
      this.state.viewerConnected = status.viewerConnected;
    }
    if (status.units !== undefined) {
      this.state.units = status.units;
    }
    if (status.bytes !== undefined) {
      this.state.bytes = status.bytes;
    }
    if (status.dropped !== undefined) {
      this.state.dropped = status.dropped;
    }
    if (status.resyncs !== undefined) {
      this.state.resyncs = status.resyncs;
    }
    if (status.keyframeRequests !== undefined) {
      this.state.keyframeRequests = status.keyframeRequests;
    }
    if (status.encrypted !== undefined) {
      this.state.encrypted = status.encrypted;
    }
    if (status.peerVerified !== undefined) {
      this.state.peerVerified = status.peerVerified;
    }

    if (this.state.state === 'stopped' || this.state.state === 'failed') {
      this.state.sharedNetworkId = '';
      this.state.busy = false;
      const reason = status.reason || this.state.terminalReason || (this.state.state === 'failed' ? 'internal' : 'user_stop');
      this.state.terminalReason = reason;
      hilog.info(0xFF00, 'RustDeskShare',
        'share terminal: state=%{public}s reason=%{public}s units=%{public}d resyncs=%{public}d',
        this.state.state, reason, this.state.units, this.state.resyncs);
      this.state.statusMessage = shareReasonText(reason);
      this.clearInvite();
      this.hideInviteDialog();
      this.stopPolling();
      if (this.onStoppedCallback) {
        this.onStoppedCallback(reason);
      }
    } else if (this.state.state === 'connected') {
      this.state.busy = false;
      this.clearInvite();
      this.hideInviteDialog();
      this.state.statusMessage = '观看端已连接';
    } else if (this.state.state === 'arming') {
      this.clearInvite();
      this.state.statusMessage = '正在验证观看端';
    } else if (this.state.state === 'listening') {
      this.state.statusMessage = '等待观看端连接';
    }
  }

  startPolling(): void {
    this.stopPolling();
    this.pollTimer = setInterval((): void => {
      this.refreshStatus();
    }, POLL_INTERVAL_MS) as number;
  }

  stopPolling(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  clearInvite(): void {
    this.state.inviteCode = '';
  }

  showConfirmDialog(): void {
    this.state.confirmDialogVisible = true;
  }

  hideConfirmDialog(): void {
    this.state.confirmDialogVisible = false;
  }

  showInviteDialog(): void {
    this.state.inviteDialogVisible = true;
  }

  hideInviteDialog(): void {
    this.state.inviteDialogVisible = false;
  }

  onSourceClosed(sessionId: string): void {
    displaySharePickerStore.releaseSession(sessionId);
    if (this.state.sessionId === sessionId && this.isSharing()) {
      this.stop();
    }
  }

  onSourceReplaced(sessionId: string): void {
    displaySharePickerStore.releaseSession(sessionId);
    if (this.state.sessionId === sessionId && this.isSharing()) {
      this.stop();
    }
  }
}

export const shareCoordinator: ShareCoordinator = new ShareCoordinator();
