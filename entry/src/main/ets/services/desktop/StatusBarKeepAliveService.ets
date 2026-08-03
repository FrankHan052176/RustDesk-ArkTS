import { common, contextConstant, StartOptions, Want } from '@kit.AbilityKit';
import { BusinessError, deviceInfo, emitter } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { statusBarManager } from '@kit.StatusBarExtensionKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskTray';
const ENTRY_MODULE_NAME = 'entry';
const ENTRY_ABILITY_NAME = 'EntryAbility';
const STATUS_BAR_BACKGROUND_ABILITY_NAME = 'StatusBarBackgroundAbility';
const STATUS_BAR_MENU_CODE_OPEN = 'rustdesk_status_bar_open';
const STATUS_BAR_MANAGER_SYSCAP = 'SystemCapability.PCService.StatusBarManager';

export function shouldUseStatusBarKeepAlive(mainWindow: window.Window): boolean {
  const deviceType = deviceInfo.deviceType.trim().toLowerCase();
  if (deviceType === '2in1' || deviceType === 'pc') {
    return true;
  }
  if (deviceType !== 'tablet' || deviceInfo.sdkApiVersion < 12) {
    return false;
  }
  try {
    return mainWindow.getWindowStatus() === window.WindowStatusType.FLOATING;
  } catch (error) {
    hilog.warn(DOMAIN, TAG, 'Tablet window status check failed: %{public}s', String(error));
    return false;
  }
}

export class StatusBarKeepAliveService {
  private readonly context: common.UIAbilityContext;
  private readonly openMainWindow: () => void;
  private registered: boolean = false;
  private backgroundStarted: boolean = false;
  private startInFlight: Promise<boolean> | undefined = undefined;
  private readonly iconClickCallback: Callback<emitter.EventData> = (eventData: emitter.EventData): void => {
    const clickType = eventData.data?.['iconClickType'] as string | undefined;
    if (clickType === 'leftClick') {
      this.openMainWindow();
    }
  };
  private readonly rightMenuClickCallback: Callback<emitter.EventData> = (eventData: emitter.EventData): void => {
    const menuCode = eventData.data?.['menuCode'] as string | undefined;
    if (menuCode === STATUS_BAR_MENU_CODE_OPEN) {
      this.openMainWindow();
    }
  };

  constructor(context: common.UIAbilityContext, openMainWindow: () => void) {
    this.context = context;
    this.openMainWindow = openMainWindow;
  }

  public start(): Promise<boolean> {
    if (this.registered) {
      return Promise.resolve(true);
    }
    const currentStart = this.startInFlight;
    if (currentStart !== undefined) {
      return currentStart;
    }
    const startPromise = this.startInternal();
    this.startInFlight = startPromise;
    startPromise.finally((): void => {
      if (this.startInFlight === startPromise) {
        this.startInFlight = undefined;
      }
    });
    return startPromise;
  }

  public isActive(): boolean {
    return this.registered;
  }

  public close(): void {
    if (!this.registered) {
      return;
    }
    try {
      statusBarManager.off('statusBarIconClick', this.iconClickCallback);
      statusBarManager.off('rightMenuClick', this.rightMenuClickCallback);
      statusBarManager.removeFromStatusBar(this.context);
      hilog.info(DOMAIN, TAG, 'Status bar keep-alive removed');
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Status bar cleanup ignored: %{public}s', String(error));
    }
    this.registered = false;
    this.backgroundStarted = false;
  }

  private async startInternal(): Promise<boolean> {
    if (!canIUse(STATUS_BAR_MANAGER_SYSCAP)) {
      return false;
    }
    try {
      const icon = await this.createStatusBarIcon();
      const item: statusBarManager.StatusBarItem = {
        icons: icon,
        quickOperation: {
          abilityName: '',
          moduleName: ENTRY_MODULE_NAME,
          title: 'RustDesk',
          height: 1,
        },
        statusBarGroupMenu: [[{
          title: '打开 RustDesk',
          menuAction: {
            abilityName: ENTRY_ABILITY_NAME,
            moduleName: ENTRY_MODULE_NAME,
            menuCode: STATUS_BAR_MENU_CODE_OPEN,
            notifyOnly: true,
          },
        }]],
        hoverTips: 'RustDesk 远程连接',
      };
      statusBarManager.addToStatusBar(this.context, item);
      statusBarManager.on('statusBarIconClick', this.iconClickCallback);
      statusBarManager.on('rightMenuClick', this.rightMenuClickCallback);
      this.registered = true;
      hilog.info(DOMAIN, TAG, 'Status bar keep-alive registered');
      setTimeout((): void => this.startBackgroundAbility(), 300);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Status bar keep-alive registration failed: %{public}s', String(error));
      return false;
    }
  }

  private startBackgroundAbility(): void {
    if (!this.registered || this.backgroundStarted) {
      return;
    }
    const want: Want = {
      bundleName: this.context.abilityInfo.bundleName,
      moduleName: ENTRY_MODULE_NAME,
      abilityName: STATUS_BAR_BACKGROUND_ABILITY_NAME,
    };
    const options: StartOptions = {
      processMode: contextConstant.ProcessMode.NEW_PROCESS_ATTACH_TO_STATUS_BAR_ITEM,
      startupVisibility: contextConstant.StartupVisibility.STARTUP_HIDE,
    };
    try {
      this.context.startAbility(want, options, (error: BusinessError): void => {
        if (error.code) {
          hilog.warn(DOMAIN, TAG, 'Status bar background attach ignored: %{public}d %{public}s',
            error.code, error.message);
          return;
        }
        this.backgroundStarted = true;
        hilog.info(DOMAIN, TAG, 'Status bar background attached');
      });
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Status bar background attach error ignored: %{public}s', String(error));
    }
  }

  private async createStatusBarIcon(): Promise<statusBarManager.StatusBarIcon> {
    const whiteData = this.context.resourceManager.getMediaContentSync(
      $r('app.media.rustdesk_status_bar_white').id,
    );
    const whiteSource = image.createImageSource(whiteData.buffer.slice(0, whiteData.buffer.byteLength));
    const white = await whiteSource.createPixelMap();
    const blackData = this.context.resourceManager.getMediaContentSync(
      $r('app.media.rustdesk_status_bar_black').id,
    );
    const blackSource = image.createImageSource(blackData.buffer.slice(0, blackData.buffer.byteLength));
    const black = await blackSource.createPixelMap();
    return { white, black };
  }
}
