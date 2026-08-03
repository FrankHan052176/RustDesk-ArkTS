import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskTrayBg';

export default class StatusBarBackgroundAbility extends UIAbility {
  onCreate(_want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Status bar background created reason=%{public}d', launchParam.launchReason);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Status bar background destroyed');
  }
}
