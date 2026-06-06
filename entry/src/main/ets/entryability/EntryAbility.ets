import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskHMOS';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
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
        mainWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION)
          .then(() => {
            hilog.info(DOMAIN, TAG, 'Window preferred orientation set to auto rotation');
          })
          .catch((orientationError: BusinessError) => {
            hilog.error(DOMAIN, TAG, 'Failed to set preferred orientation: %{public}s', JSON.stringify(orientationError) ?? '');
          });
      });
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
