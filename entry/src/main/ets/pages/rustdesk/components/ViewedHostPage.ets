import {
  HdsNavigation,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
  hdsMaterial,
} from '@kit.UIDesignKit';
import { LuminousButton, LuminousControlSize, LuminousSurface, LuminousTone } from 'luminous_neo';
import {
  ControlledHostState,
  ControlledPasswordMode,
  ControlledTrustedDevice,
  ControlledTwoFactorState,
} from '../../../services/controlled/ControlledHostTypes';
import { controlledHostCoordinator } from '../../../services/controlled/ControlledHostCoordinator';
import { HostSecuritySettingsCard } from './HostSecuritySettingsCard';
import { ViewedHostCard } from './ViewedHostCard';

export interface ViewedHostPageProps {
  state: ControlledHostState;
  twoFactorState: ControlledTwoFactorState;
  /** The operator has confirmed a server; sharing cannot start without one. */
  serverConfirmed: boolean;
  serverUsesOfficial: boolean;
  serverSaving: boolean;
  /** Why the last attempt to confirm the server failed; empty when it did not. */
  serverError: string;
  scroller: Scroller;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  wideLayout: boolean;
  onStart: () => void;
  onStartWithInput: () => void;
  onStop: () => void;
  onAccept: (requestId: string, peerId: string) => void;
  onReject: (requestId: string, peerId: string) => void;
  onRefreshPassword: () => void;
  onConfirmServer: () => void;
  onOpenServerSettings: () => void;
}

/**
 * Everything about this device being viewed or controlled, in one place: its ID
 * and password, starting and stopping, and who may get in.
 *
 * The access settings (password kind, two-step verification, trusted devices)
 * used to sit under the app settings as "安全", away from the page they govern.
 * They are this device's own door, so they open from here.
 */
@ComponentV2
export struct ViewedHostPage {
  @Param state: ControlledHostState = new ControlledHostState();
  @Param twoFactorState: ControlledTwoFactorState = new ControlledTwoFactorState();
  @Param serverConfirmed: boolean = true;
  @Param serverUsesOfficial: boolean = true;
  @Param serverSaving: boolean = false;
  @Param serverError: string = '';
  @Param scroller: Scroller = new Scroller();
  @Param titleSpacerHeight: number = 56;
  @Param bottomAvoidInset: number = 0;
  @Param wideLayout: boolean = false;
  @Local viewportWidth: number = 760;
  @Local securitySheetVisible: boolean = false;
  @Local securityEntryPressed: boolean = false;
  @Local sheetViewportHeight: number = 0;
  private sheetScroller: Scroller = new Scroller();
  @Event onStart: () => void = () => {};
  @Event onStartWithInput: () => void = () => {};
  @Event onStop: () => void = () => {};
  @Event onAccept: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onReject: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onRefreshPassword: () => void = () => {};
  @Event onConfirmServer: () => void = () => {};
  @Event onOpenServerSettings: () => void = () => {};

  /**
   * A request to connect is answered on the card behind the security sheet, and
   * the other side is waiting: the sheet gets out of its way.
   */
  @Monitor('state.incoming')
  private onIncomingChanged(_monitor: IMonitor): void {
    if (this.state.incoming !== undefined) {
      this.securitySheetVisible = false;
    }
  }

  private horizontalPadding(): number {
    if (this.viewportWidth >= 1100) {
      return 56;
    }
    if (this.viewportWidth >= 720) {
      return 40;
    }
    return 20;
  }

  private contentWidth(): number {
    return Math.max(280, Math.min(this.viewportWidth - this.horizontalPadding() * 2, this.wideLayout ? 600 : 540));
  }

  private contentTitleSpacerHeight(): number {
    return this.wideLayout ? Math.max(this.titleSpacerHeight + 36, 56) : Math.max(this.titleSpacerHeight, 40);
  }

  private entrySurfaceWidth(): number {
    return Math.max(240, this.contentWidth() - 24);
  }

  private securitySummary(): string {
    if (this.twoFactorState.enabled) {
      return '双重验证已开启';
    }
    if (this.state.permanentPasswordSet) {
      return '已设置固定密码，可再开启双重验证';
    }
    return '连接密码、双重验证与信任设备';
  }

  private openSecuritySheet(): void {
    // What the sheet shows is this device's stored state, read when it opens.
    controlledHostCoordinator.refreshPasswordState();
    controlledHostCoordinator.refreshTwoFactorState();
    this.securitySheetVisible = true;
    setTimeout((): void => {
      this.sheetScroller.scrollEdge(Edge.Top);
    }, 0);
  }

  /**
   * Sharing registers this device with a server, and none has been confirmed
   * yet. Said here, with the one action that is missing, instead of as a
   * refusal after the start button is pressed.
   */
  @Builder
  private ServerNotice() {
    Column({ space: 10 }) {
      Text(this.serverUsesOfficial
        ? '开始共享前，需要先确认使用的服务器。可以直接使用 RustDesk 官方服务器。'
        : '开始共享前，需要先确认“设置 > 服务器”里填写的服务器。')
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.neu_text_secondary'));
      if (this.serverError.length > 0 && !this.serverSaving) {
        Text(this.serverError)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.error'));
      }
      if (this.serverUsesOfficial) {
        LuminousButton({
          label: this.serverSaving ? '正在保存…' : '使用官方服务器',
          controlWidth: Math.max(160, this.entrySurfaceWidth() - 32),
          controlSizeMode: LuminousControlSize.Compact,
          tone: LuminousTone.Accent,
          isEnabled: !this.serverSaving,
          onAction: (): void => this.onConfirmServer(),
        });
      }
      Text(this.serverUsesOfficial ? '我有自建服务器' : '去设置服务器')
        .fontSize(12)
        .fontColor($r('app.color.neu_accent'))
        .padding(8)
        .onClick((): void => this.onOpenServerSettings());
    }
    .width(this.entrySurfaceWidth())
    .padding({ left: 16, right: 16, top: 12, bottom: 6 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.neu_base'))
    .borderRadius(14)
    .border({ width: 1, color: $r('app.color.mica_border') });
  }

  @Builder
  private SecurityEntry() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: this.securityEntryPressed ? -1 : 1,
        surfaceWidth: this.entrySurfaceWidth(),
        surfaceHeight: 72,
        cornerRadius: 22,
        motionEnabled: true,
      }) {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.lock_shield'))
            .width(34)
            .fontSize(27)
            .fontColor([$r('app.color.neu_accent')]);

          Column({ space: 4 }) {
            Text('访问安全')
              .width('100%')
              .fontSize(14)
              .lineHeight(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            Text(this.securitySummary())
              .width('100%')
              .fontSize(11)
              .lineHeight(16)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([$r('app.color.neu_text_secondary')]);
        }
        .width(this.entrySurfaceWidth())
        .height(72)
        .padding({ left: 14, right: 12 })
        .alignItems(VerticalAlign.Center);
      }

      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row()
      }
      .width(this.entrySurfaceWidth())
      .height(72)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .hoverEffect(HoverEffect.None)
      .borderRadius(22)
      .accessibilityText('访问安全')
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) {
          this.securityEntryPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.securityEntryPressed = false;
        }
      })
      .onClick((): void => {
        this.securityEntryPressed = false;
        this.openSecuritySheet();
      });
    }
    .width(this.contentWidth())
    .height(88)
    .scale({
      x: this.securityEntryPressed ? 0.98 : 1,
      y: this.securityEntryPressed ? 0.98 : 1,
    })
    .animation({ duration: 120, curve: Curve.FastOutSlowIn })
    .clip(false);
  }

  @Builder
  private SecuritySheet() {
    HdsNavigation() {
      Scroll(this.sheetScroller) {
        Column() {
          Row() {
            Column() {
              HostSecuritySettingsCard({
                hostState: this.state,
                twoFactor: this.twoFactorState,
                onRefresh: (): void => {
                  controlledHostCoordinator.refreshPasswordState();
                  controlledHostCoordinator.refreshTwoFactorState();
                },
                onPasswordModeChange: (mode: ControlledPasswordMode): void =>
                  controlledHostCoordinator.setVerificationMethod(mode),
                onSetPermanentPassword: (password: string, confirmation: string): void =>
                  controlledHostCoordinator.setPermanentPassword(password, confirmation),
                onRemovePermanentPassword: (): void => controlledHostCoordinator.clearPermanentPassword(),
                onBeginTwoFactor: (): void => controlledHostCoordinator.beginTwoFactorSetup(),
                onVerifyTwoFactor: (code: string): void => controlledHostCoordinator.verifyTwoFactorSetup(code),
                onCancelTwoFactor: (): void => controlledHostCoordinator.cancelTwoFactorSetup(),
                onDisableTwoFactor: (): void => controlledHostCoordinator.disableTwoFactor(),
                onTrustedDevicesEnabledChange: (enabled: boolean): void =>
                  controlledHostCoordinator.setTrustedDevicesEnabled(enabled),
                onRemoveTrustedDevice: (device: ControlledTrustedDevice): void =>
                  controlledHostCoordinator.removeTrustedDevice(device),
                onClearTrustedDevices: (): void => controlledHostCoordinator.clearTrustedDevices(),
              })
            }
            .width('100%')
            .constraintSize({ maxWidth: 600 })
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .constraintSize({ minHeight: this.sheetViewportHeight })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Top)
          .padding({
            left: $r('app.float.space_16'),
            right: $r('app.float.space_16'),
            top: $r('app.float.space_24'),
            bottom: $r('app.float.space_24'),
          });
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.neu_base'));
      }
      .width('100%')
      .height('100%')
      .clip(false)
      .scrollBar(BarState.Off)
      .backgroundColor($r('app.color.neu_base'))
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST,
      })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const height: number = Number(newArea.height);
        if (height > 0) {
          this.sheetViewportHeight = height;
        }
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(true)
    .titleBar({
      enableComponentSafeArea: true,
      content: {
        title: {
          mainTitle: '访问安全',
          subTitle: '管理本机的连接密码、双重验证和信任设备',
        },
        menu: {
          value: [{
            content: {
              label: '关闭',
              icon: $r('sys.symbol.xmark'),
              type: IconStyleMode.SMALL,
              action: (): void => {
                this.securitySheetVisible = false;
              },
            },
          }],
        },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
    })
    .bindToScrollable([this.sheetScroller])
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }

  build(): void {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        Blank()
          .width('100%')
          .height(this.contentTitleSpacerHeight())
          .flexShrink(0);
        ViewedHostCard({
          state: this.state,
          surfaceWidth: this.contentWidth(),
          onStart: () => this.onStart(),
          onStartWithInput: () => this.onStartWithInput(),
          onStop: () => this.onStop(),
          onAccept: (requestId: string, peerId: string) => this.onAccept(requestId, peerId),
          onReject: (requestId: string, peerId: string) => this.onReject(requestId, peerId),
          onRefreshPassword: () => this.onRefreshPassword(),
        });
        if (!this.serverConfirmed) {
          this.ServerNotice();
        }
        this.SecurityEntry();
        Blank()
          .width('100%')
          .height((this.wideLayout ? 48 : 120) + this.bottomAvoidInset)
          .flexShrink(0);
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Center)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const width: number = Number(newArea.width);
        if (width > 0) {
          this.viewportWidth = width;
        }
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .bindSheet(this.securitySheetVisible!!, this.SecuritySheet(), {
      height: SheetSize.LARGE,
      preferType: SheetType.CENTER,
      showClose: false,
      dragBar: false,
      enableFloatingDragBar: false,
      backgroundColor: $r('app.color.neu_base'),
    });
  }
}
