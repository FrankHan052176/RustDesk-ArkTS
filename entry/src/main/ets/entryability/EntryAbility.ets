import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
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

const DOMAIN = 0xFF00;
const TAG = 'RustDeskHMOS';

export default class EntryAbility extends UIAbility {
  private dataTransferBackgroundService: DataTransferBackgroundService | undefined = undefined;
  private onDataTransferBind = (binding: DataTransferBackgroundBinding): void => {
    this.dataTransferBackgroundService?.bind(binding.callbacks);
  };
  private onDataTransferChanged = (): void => {
    this.dataTransferBackgroundService?.onStateChanged();
  };
  private onDataTransferUnbind = (): void => {
    this.dataTransferBackgroundService?.unbind();
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    this.dataTransferBackgroundService = new DataTransferBackgroundService(this.context);
    this.context.eventHub.on(DATA_TRANSFER_BACKGROUND_BIND_EVENT, this.onDataTransferBind);
    this.context.eventHub.on(DATA_TRANSFER_BACKGROUND_CHANGE_EVENT, this.onDataTransferChanged);
    this.context.eventHub.on(DATA_TRANSFER_BACKGROUND_UNBIND_EVENT, this.onDataTransferUnbind);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/RustDeskIndex', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(DOMAIN, TAG, 'Main page loaded');
      windowStage.getMainWindow((windowError: BusinessError, mainWindow: window.Window) => {
        if (windowError.code) {
          hilog.error(DOMAIN, TAG, 'Failed to obtain main window: %{public}s', JSON.stringify(windowError) ?? '');
          return;
        }
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
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
    this.context.eventHub.off(DATA_TRANSFER_BACKGROUND_BIND_EVENT, this.onDataTransferBind);
    this.context.eventHub.off(DATA_TRANSFER_BACKGROUND_CHANGE_EVENT, this.onDataTransferChanged);
    this.context.eventHub.off(DATA_TRANSFER_BACKGROUND_UNBIND_EVENT, this.onDataTransferUnbind);
    this.dataTransferBackgroundService?.destroy();
    this.dataTransferBackgroundService = undefined;
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
    this.dataTransferBackgroundService?.onForeground();
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
    this.dataTransferBackgroundService?.onBackground();
  }
}
