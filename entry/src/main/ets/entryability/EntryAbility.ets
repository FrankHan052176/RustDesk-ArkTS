import { AbilityConstant, UIAbility, Want, wantConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import {
  DATA_TRANSFER_BACKGROUND_BIND_EVENT,
  DATA_TRANSFER_BACKGROUND_CHANGE_EVENT,
  DATA_TRANSFER_BACKGROUND_UNBIND_EVENT,
  DataTransferBackgroundBinding,
  DataTransferBackgroundService,
} from '../services/DataTransferBackgroundService';
import { EasyTierApiService } from '../services/EasyTierApiService';
import {
  REMOTE_SESSION_APP_STATE_EVENT,
  REMOTE_SESSION_CONTINUE_HANDOFF_EVENT,
  REMOTE_SESSION_CONTINUE_STATE_EVENT,
  RemoteSessionHandoffService,
} from '../services/RemoteSessionHandoffService';
import {
  shouldUseStatusBarKeepAlive,
  StatusBarKeepAliveService,
} from '../services/desktop/StatusBarKeepAliveService';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskHMOS';

export default class EntryAbility extends UIAbility {
  private dataTransferBackgroundService: DataTransferBackgroundService | undefined = undefined;
  private dataTransferBinding: DataTransferBackgroundBinding | undefined = undefined;
  private easyTierApiService: EasyTierApiService | undefined = undefined;
  private statusBarKeepAliveService: StatusBarKeepAliveService | undefined = undefined;
  private mainWindow: window.Window | undefined = undefined;
  private desktopKeepAliveActive: boolean = false;
  private windowWillCloseCallback: (() => Promise<boolean>) | undefined = undefined;
  private windowStageCloseCallback: (() => boolean) | undefined = undefined;
  private onDataTransferBind = (binding: DataTransferBackgroundBinding): void => {
    this.dataTransferBinding = binding;
    this.dataTransferBackgroundService?.bind(binding.callbacks);
  };
  private onDataTransferChanged = (): void => {
    this.dataTransferBackgroundService?.onStateChanged();
  };
  private onDataTransferUnbind = (): void => {
    this.dataTransferBackgroundService?.unbind();
    this.dataTransferBinding = undefined;
  };
  private onRemoteSessionContinueState = (active: boolean): void => {
    this.setContinueState(active);
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    this.statusBarKeepAliveService = new StatusBarKeepAliveService(this.context, () => this.restoreMainWindow());
    this.easyTierApiService = new EasyTierApiService(this.context);
    void this.easyTierApiService.startSnapshotObserver();
    this.context.eventHub.on(DATA_TRANSFER_BACKGROUND_BIND_EVENT, this.onDataTransferBind);
    this.context.eventHub.on(DATA_TRANSFER_BACKGROUND_CHANGE_EVENT, this.onDataTransferChanged);
    this.context.eventHub.on(DATA_TRANSFER_BACKGROUND_UNBIND_EVENT, this.onDataTransferUnbind);
    this.context.eventHub.on(REMOTE_SESSION_CONTINUE_STATE_EVENT, this.onRemoteSessionContinueState);
    this.setContinueState(false);
    this.handleIncomingWant(want, launchParam);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onNewWant');
    this.restoreMainWindow();
    if (this.easyTierApiService === undefined) {
      this.easyTierApiService = new EasyTierApiService(this.context);
      void this.easyTierApiService.startSnapshotObserver();
    }
    this.handleIncomingWant(want, launchParam);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    this.loadMainContent(windowStage);
  }

  onWindowStageRestore(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageRestore');
    if (this.mainWindow !== undefined) {
      hilog.info(DOMAIN, TAG, 'Keeping existing main page for hot continuation');
      return;
    }
    this.loadMainContent(windowStage);
  }

  private loadMainContent(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/RustDeskIndex', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(DOMAIN, TAG, 'Main page loaded');
      windowStage.getMainWindow((windowError: BusinessError, mainWindow: window.Window) => {
        if (windowError.code) {
          hilog.error(DOMAIN, TAG, 'Failed to obtain main window: %{public}s', JSON.stringify(windowError) ?? '');
          this.enableDataTransferKeepAlive();
          return;
        }
        this.mainWindow = mainWindow;
        this.startBackgroundKeepAlive(windowStage, mainWindow);
        mainWindow.setWindowLayoutFullScreen(true).then(() => {
          hilog.info(DOMAIN, TAG, 'Succeeded in setting the initial window layout mode.');
        }).catch((err: BusinessError) => {
          hilog.error(DOMAIN, TAG,
            'Failed to set the initial window layout to immersive mode. Cause:' + JSON.stringify(err));
        });

      });
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
    this.mainWindow = undefined;
    this.windowWillCloseCallback = undefined;
    this.windowStageCloseCallback = undefined;
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
    this.context.eventHub.off(DATA_TRANSFER_BACKGROUND_BIND_EVENT, this.onDataTransferBind);
    this.context.eventHub.off(DATA_TRANSFER_BACKGROUND_CHANGE_EVENT, this.onDataTransferChanged);
    this.context.eventHub.off(DATA_TRANSFER_BACKGROUND_UNBIND_EVENT, this.onDataTransferUnbind);
    this.context.eventHub.off(REMOTE_SESSION_CONTINUE_STATE_EVENT, this.onRemoteSessionContinueState);
    this.dataTransferBackgroundService?.destroy();
    this.dataTransferBackgroundService = undefined;
    this.dataTransferBinding = undefined;
    this.statusBarKeepAliveService?.close();
    this.statusBarKeepAliveService = undefined;
    this.desktopKeepAliveActive = false;
    this.easyTierApiService?.stopSnapshotObserver();
    this.easyTierApiService = undefined;
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
    this.dataTransferBackgroundService?.onForeground();
    void this.easyTierApiService?.startSnapshotObserver();
    this.context.eventHub.emit(REMOTE_SESSION_APP_STATE_EVENT, true);
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
    this.dataTransferBackgroundService?.onBackground();
    this.context.eventHub.emit(REMOTE_SESSION_APP_STATE_EVENT, false);
  }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    const payload = RemoteSessionHandoffService.createContinuationPayload();
    if (payload === undefined) {
      return AbilityConstant.OnContinueResult.REJECT;
    }
    wantParam['data'] = payload;
    wantParam[wantConstant.Params.SUPPORT_CONTINUE_SOURCE_EXIT_KEY] = false;
    wantParam[wantConstant.Params.SUPPORT_CONTINUE_PAGE_STACK_KEY] = false;
    this.context.eventHub.emit(REMOTE_SESSION_CONTINUE_HANDOFF_EVENT);
    return AbilityConstant.OnContinueResult.AGREE;
  }

  private enableDataTransferKeepAlive(): void {
    if (this.dataTransferBackgroundService !== undefined) {
      return;
    }
    this.dataTransferBackgroundService = new DataTransferBackgroundService(this.context);
    const binding = this.dataTransferBinding;
    if (binding !== undefined) {
      this.dataTransferBackgroundService.bind(binding.callbacks);
    }
  }

  private startDesktopKeepAlive(): void {
    const service = this.statusBarKeepAliveService;
    if (service === undefined) {
      return;
    }
    service.start().then((active: boolean): void => {
      this.desktopKeepAliveActive = active;
      if (!active) {
        hilog.warn(DOMAIN, TAG, 'Status bar keep-alive unavailable; falling back to data transfer task');
        this.enableDataTransferKeepAlive();
      }
    }).catch((error: Error): void => {
      this.desktopKeepAliveActive = false;
      hilog.error(DOMAIN, TAG, 'Status bar keep-alive start failed: %{public}s', error.message);
      this.enableDataTransferKeepAlive();
    });
  }

  private startBackgroundKeepAlive(windowStage: window.WindowStage, mainWindow: window.Window): void {
    if (!shouldUseStatusBarKeepAlive(mainWindow)) {
      hilog.info(DOMAIN, TAG, 'Using data-transfer keep-alive for the current window mode');
      this.enableDataTransferKeepAlive();
      return;
    }
    hilog.info(DOMAIN, TAG, 'Using status-bar keep-alive for the current window mode');
    this.registerWindowCloseToBackground(windowStage, mainWindow);
    this.startDesktopKeepAlive();
  }

  private restoreMainWindow(): void {
    if (!this.desktopKeepAliveActive) {
      return;
    }
    this.context.showAbility().catch((error: BusinessError): void => {
      hilog.warn(DOMAIN, TAG, 'showAbility ignored: %{public}d %{public}s', error.code, error.message);
    });
    const currentWindow = this.mainWindow;
    if (currentWindow !== undefined) {
      currentWindow.restore().catch((error: BusinessError): void => {
        hilog.warn(DOMAIN, TAG, 'Window restore ignored: %{public}d %{public}s', error.code, error.message);
      });
    }
  }

  private hideMainWindow(): Promise<boolean> {
    if (!this.desktopKeepAliveActive) {
      return Promise.resolve(false);
    }
    return this.context.hideAbility().then((): boolean => {
      hilog.info(DOMAIN, TAG, 'Main window hidden to status bar');
      return true;
    }).catch((error: BusinessError): boolean => {
      hilog.error(DOMAIN, TAG, 'hideAbility failed: %{public}d %{public}s', error.code, error.message);
      return false;
    });
  }

  private registerWindowCloseToBackground(windowStage: window.WindowStage, mainWindow: window.Window): void {
    this.windowWillCloseCallback = (): Promise<boolean> => this.hideMainWindow();
    try {
      mainWindow.on('windowWillClose', this.windowWillCloseCallback);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'windowWillClose registration ignored: %{public}s', String(error));
    }
    this.windowStageCloseCallback = (): boolean => {
      if (!this.desktopKeepAliveActive) {
        return false;
      }
      void this.hideMainWindow();
      return true;
    };
    try {
      windowStage.on('windowStageClose', this.windowStageCloseCallback);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'windowStageClose registration ignored: %{public}s', String(error));
    }
  }

  private setContinueState(active: boolean): void {
    const state = active ? AbilityConstant.ContinueState.ACTIVE : AbilityConstant.ContinueState.INACTIVE;
    this.context.setMissionContinueState(state).catch((error: BusinessError): void => {
      hilog.warn(DOMAIN, TAG, 'setMissionContinueState ignored: %{public}d %{public}s', error.code, error.message);
    });
  }

  private handleIncomingWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION &&
      RemoteSessionHandoffService.handleContinuationWant(this.context, want)) {
      return;
    }
    if (RemoteSessionHandoffService.handleDeepLinkWant(this.context, want)) {
      return;
    }
    if (EasyTierApiService.isResultWant(want)) {
      void this.easyTierApiService?.handleWant(want);
    }
  }
}
