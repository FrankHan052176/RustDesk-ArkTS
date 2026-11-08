import { SessionOverlayPanel } from '../SessionOverlayState';
import { SessionToolbarMetrics } from '../SessionToolbarMetrics';
import { RemoteSessionTab } from '../RemoteSessionTabsController';
import { RustDeskInputMode, RustDeskRightClickGesture } from '../RustDeskDirectoryTypes';
import { SessionInputControls } from './SessionInputControls';

const SOFT_KEYBOARD_TRANSITION_ID = 'rustdesk-session-soft-keyboard';
const SYSTEM_IME_TRANSITION_ID = 'rustdesk-session-system-ime';
const TOOLBAR_SECTION_GAP = 8;

interface ToolbarActionOptions {
  label: string;
  active: boolean;
  transitionId: string;
  enabled?: boolean;
  onClick: () => void;
}

export interface SessionToolbarProps {
  tabs: Array<RemoteSessionTab>;
  activeSessionId: string;
  canAddSession: boolean;
  inputEnabled: boolean;
  touchMode: boolean;
  relativeMouseMode: boolean;
  relativeModeSupported: boolean;
  rightClickGesture: RustDeskRightClickGesture;
  metrics: SessionToolbarMetrics;
  activeOverlayPanel: SessionOverlayPanel;
  displayTransitionId: string;
  qualityTransitionId: string;
  androidNavigationAvailable: boolean;
  androidNavigationVisible: boolean;
  softKeyboardAvailable: boolean;
  softKeyboardVisible: boolean;
  systemImeAvailable: boolean;
  systemImeActive: boolean;
  audioAvailable: boolean;
  audioMuted: boolean;
  directSession: boolean;
  audioUnavailableText: ResourceStr;
  keyboardUnavailableText: ResourceStr;
  windowUnavailableText: ResourceStr;
  statusMessage: string;
  wideLayout: boolean;
  transformSummary: string;
  canResetTransform: boolean;
  panelContentHeight: number;
  windowControlsAvailable: boolean;
  windowFullscreenAvailable: boolean;
  windowFullscreen: boolean;
  windowControlBusy: boolean;
  refreshDisplayEnabled: boolean;
  onSelectInputMode: (mode: RustDeskInputMode) => void;
  onSelectRightClick: (gesture: RustDeskRightClickGesture) => void;
  onResetTransform: () => void;
  rotationAvailable: boolean;
  rotationBusy: boolean;
  onRotateToCurrent: () => void;
  onRotate90: () => void;
  onOpenDisplay: () => void;
  onOpenQuality: () => void;
  onRefreshDisplay: () => void;
  onToggleSoftKeyboard: () => void;
  onToggleSystemIme: () => void;
  onToggleAndroidNavigation: () => void;
  onAudioChange: (enabled: boolean) => void;
  onDisconnect: () => void;
  onCollapse: () => void;
  onToolbarMoveStart: () => void;
  onToolbarMoveUpdate: (offsetX: number, offsetY: number) => void;
  onChromeHeightChange: (height: number) => void;
  onMinimizeWindow: () => void;
  onToggleWindowFullscreen: () => void;
  onSelectSession: (sessionId: string) => void;
  onCloseSession: (sessionId: string) => void;
  onAddSession: () => void;
  content: () => void;
  isSharedSession?: boolean;
}

@ComponentV2
export struct SessionToolbar {
  @Param tabs: Array<RemoteSessionTab> = [];
  @Param activeSessionId: string = '';
  @Param canAddSession: boolean = true;
  @Param isSharedSession: boolean = false;
  @Param inputEnabled: boolean = true;
  @Param touchMode: boolean = true;
  @Param relativeMouseMode: boolean = false;
  @Param relativeModeSupported: boolean = false;
  @Param rightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  @Param metrics: SessionToolbarMetrics = {
    fps: '--',
    delay: '--',
    codec: '--',
  };
  @Param activeOverlayPanel: SessionOverlayPanel = 'home';
  @Param displayTransitionId: string = '';
  @Param qualityTransitionId: string = '';
  @Param androidNavigationAvailable: boolean = false;
  @Param androidNavigationVisible: boolean = false;
  @Local displayedAndroidNavigationVisible: boolean = false;
  @Param softKeyboardAvailable: boolean = false;
  @Param softKeyboardVisible: boolean = false;
  @Param systemImeAvailable: boolean = false;
  @Param systemImeActive: boolean = false;
  @Param audioAvailable: boolean = false;
  @Param audioMuted: boolean = false;
  @Param directSession: boolean = false;
  @Param audioUnavailableText: ResourceStr = '';
  @Param keyboardUnavailableText: ResourceStr = '';
  @Param windowUnavailableText: ResourceStr = '';
  @Param statusMessage: string = '';
  @Param wideLayout: boolean = false;
  @Param transformSummary: string = '100%';
  @Param canResetTransform: boolean = false;
  @Param rotationAvailable: boolean = false;
  @Param rotationBusy: boolean = false;
  @Param panelContentHeight: number = 360;
  @Param windowControlsAvailable: boolean = false;
  @Param windowFullscreenAvailable: boolean = false;
  @Param windowFullscreen: boolean = false;
  @Param windowControlBusy: boolean = false;
  @Param refreshDisplayEnabled: boolean = false;
  @Event onSelectInputMode: (mode: RustDeskInputMode) => void = (_mode: RustDeskInputMode) => {};
  @Event onSelectRightClick: (gesture: RustDeskRightClickGesture) => void = (
    _gesture: RustDeskRightClickGesture,
  ) => {};
  @Event onResetTransform: () => void = () => {};
  @Event onRotateToCurrent: () => void = () => {};
  @Event onRotate90: () => void = () => {};
  @Event onOpenDisplay: () => void = () => {};
  @Event onOpenQuality: () => void = () => {};
  @Event onRefreshDisplay: () => void = () => {};
  @Event onToggleSoftKeyboard: () => void = () => {};
  @Event onToggleSystemIme: () => void = () => {};
  @Event onToggleAndroidNavigation: () => void = () => {};
  @Event onAudioChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  @Event onDisconnect: () => void = () => {};
  @Event onCollapse: () => void = () => {};
  @Event onToolbarMoveStart: () => void = () => {};
  @Event onToolbarMoveUpdate: (offsetX: number, offsetY: number) => void = (
    _offsetX: number,
    _offsetY: number,
  ) => {};
  @Event onChromeHeightChange: (height: number) => void = (_height: number) => {};
  @Event onMinimizeWindow: () => void = () => {};
  @Event onToggleWindowFullscreen: () => void = () => {};
  @Event onSelectSession: (sessionId: string) => void = (_sessionId: string) => {};
  @Event onCloseSession: (sessionId: string) => void = (_sessionId: string) => {};
  @Event onAddSession: () => void = () => {};
  @Local toolbarWidth: number = 360;
  @Local sessionTabsViewportWidth: number = 0;
  private toolbarHeaderHeight: number = 0;
  private sessionTabsBarHeight: number = 0;
  private reportedChromeHeight: number = 0;
  private sessionScroller: Scroller = new Scroller();

  @BuilderParam content: () => void = this.Empty;

  aboutToAppear(): void {
    this.displayedAndroidNavigationVisible = this.androidNavigationVisible;
  }

  @Monitor('androidNavigationVisible')
  private onAndroidNavigationVisibleChanged(_monitor: IMonitor): void {
    this.displayedAndroidNavigationVisible = this.androidNavigationVisible;
  }

  @Monitor('activeSessionId')
  private onActiveSessionChanged(_monitor: IMonitor): void {
    this.scheduleRevealActiveSession();
  }

  @Monitor('tabs')
  private onSessionTabsChanged(_monitor: IMonitor): void {
    this.scheduleRevealActiveSession();
  }

  @Builder
  private Empty() {}

  private sessionCardWidth(): number {
    if (this.sessionTabsViewportWidth > 0) {
      if (this.tabs.length <= 1) {
        return this.sessionTabsViewportWidth;
      }
      return Math.min(200, Math.max(140, this.sessionTabsViewportWidth * 0.6));
    }
    return 180;
  }

  private activeSessionIndex(): number {
    for (let index = 0; index < this.tabs.length; index += 1) {
      if (this.tabs[index].sessionId === this.activeSessionId) {
        return index;
      }
    }
    return -1;
  }

  private scheduleRevealActiveSession(): void {
    setTimeout((): void => this.revealActiveSession(), 0);
  }

  private revealActiveSession(): void {
    const activeIndex = this.activeSessionIndex();
    if (activeIndex < 0) {
      return;
    }
    const viewportWidth = this.sessionTabsViewportWidth;
    if (viewportWidth <= 0) {
      return;
    }
    const cardStep = this.sessionCardWidth() + 6;
    const cardStart = activeIndex * cardStep;
    try {
      const currentOffset = this.sessionScroller.currentOffset().xOffset;
      if (cardStart < currentOffset || cardStart + this.sessionCardWidth() > currentOffset + viewportWidth) {
        this.sessionScroller.scrollTo({
          xOffset: Math.max(0, cardStart),
          yOffset: 0,
          animation: true,
        });
      }
    } catch (_) {
    }
  }

  private sessionStatusColor(tab: RemoteSessionTab): ResourceColor {
    if (tab.needsAttention || tab.phase === 'failed' || tab.phase === 'closed') {
      return $r('app.color.error');
    }
    if (tab.connected) {
      return $r('app.color.success');
    }
    return $r('app.color.warning');
  }

  private toolbarChromeHeight(): number {
    const hasTabs = this.tabs.length > 0;
    const gaps = TOOLBAR_SECTION_GAP * (hasTabs ? 2 : 1);
    return this.toolbarHeaderHeight + gaps + (hasTabs ? this.sessionTabsBarHeight : 0);
  }

  private reportToolbarChrome(): void {
    if (this.toolbarHeaderHeight <= 0) {
      return;
    }
    if (this.tabs.length > 0 && this.sessionTabsBarHeight <= 0) {
      return;
    }
    const height = this.toolbarChromeHeight();
    if (height <= 0 || Math.abs(height - this.reportedChromeHeight) <= 0.5) {
      return;
    }
    this.reportedChromeHeight = height;
    this.onChromeHeightChange(height);
  }

  private measureToolbarHeader(height: number): void {
    if (height <= 0 || Math.abs(height - this.toolbarHeaderHeight) <= 0.5) {
      return;
    }
    this.toolbarHeaderHeight = height;
    this.reportToolbarChrome();
  }

  private measureSessionTabsBar(height: number): void {
    if (height <= 0 || Math.abs(height - this.sessionTabsBarHeight) <= 0.5) {
      return;
    }
    this.sessionTabsBarHeight = height;
    this.reportToolbarChrome();
  }

  @Builder
  private HeaderActionButton(
    label: string,
    active: boolean,
    onClick: () => void,
    busy: boolean = false,
    fillWeight?: number,
  ) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Medium)
        .fontColor(busy
          ? $r('app.color.neu_text_disabled')
          : (active ? $r('app.color.white') : $r('app.color.neu_text_primary')))
        .maxLines(1);
    }
    .layoutWeight(fillWeight !== undefined ? fillWeight : 0)
    .height(44)
    .constraintSize({ minWidth: 44 })
    .padding({ left: 8, right: 8 })
    .enabled(!busy)
    .backgroundColor(active ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
    .border({
      width: 1,
      color: active ? $r('app.color.brand_primary') : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(label)
    .onClick(() => onClick());
  }

  @Builder
  private ToolbarDragGrip() {
    Row({ space: 3 }) {
      Stack()
        .width(3)
        .height(18)
        .backgroundColor($r('app.color.neu_text_secondary'))
        .borderRadius(1.5)
        .opacity(0.6);
      Stack()
        .width(3)
        .height(18)
        .backgroundColor($r('app.color.neu_text_secondary'))
        .borderRadius(1.5)
        .opacity(0.6);
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.transparent'))
    .accessibilityText($r('app.string.remote_session_toolbar_drag') as Resource)
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 4 })
        .onActionStart((_event: GestureEvent): void => {
          this.onToolbarMoveStart();
        })
        .onActionUpdate((event: GestureEvent): void => {
          this.onToolbarMoveUpdate(event.offsetX, event.offsetY);
        }),
    );
  }

  @Builder
  private SessionCard(tab: RemoteSessionTab) {
    Row({ space: 2 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 6 }) {
          Stack()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(this.sessionStatusColor(tab));

          Column({ space: 1 }) {
            Text(tab.label)
              .fontSize($r('app.float.font_caption'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            if (tab.target.length > 0 && tab.target !== tab.label) {
              Text(tab.target)
                .fontSize(10)
                .fontColor($r('app.color.neu_text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .padding({ left: 8, right: 4 });
      }
      .layoutWeight(1)
      .height(44)
      .padding(0)
      .backgroundColor($r('app.color.transparent'))
      .hoverEffect(HoverEffect.Auto)
      .accessibilityText(`${tab.label}，${tab.target}，点击切换`)
      .accessibilitySelected(tab.sessionId === this.activeSessionId)
      .onClick((): void => this.onSelectSession(tab.sessionId));

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text($r('app.string.remote_session_tab_close_symbol'))
          .fontSize(14)
          .fontColor($r('app.color.neu_text_secondary'));
      }
      .width(44)
      .height(44)
      .padding(0)
      .backgroundColor($r('app.color.transparent'))
      .hoverEffect(HoverEffect.Auto)
      .accessibilityText(`${tab.label}，断开并关闭此会话`)
      .onClick((): void => this.onCloseSession(tab.sessionId));
    }
    .width(this.sessionCardWidth())
    .height(44)
    .padding({ left: 2, right: 0 })
    .backgroundColor(tab.sessionId === this.activeSessionId
      ? $r('app.color.brand_primary_soft')
      : $r('app.color.mica_control'))
    .border({
      width: 1,
      color: tab.sessionId === this.activeSessionId
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .clip(true);
  }

  @Builder
  private SessionTabsBar() {
    Row({ space: 6 }) {
      Scroll(this.sessionScroller) {
        Row({ space: 6 }) {
          ForEach(this.tabs, (tab: RemoteSessionTab) => {
            this.SessionCard(tab);
          }, (tab: RemoteSessionTab): string => tab.sessionId);
        }
        .alignItems(VerticalAlign.Center);
      }
      .layoutWeight(1)
      .height(44)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, {
        alwaysEnabled: this.tabs.length * (this.sessionCardWidth() + 6) > this.sessionTabsViewportWidth,
      })
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const width = Number(newArea.width);
        if (width > 0 && Math.abs(width - this.sessionTabsViewportWidth) > 0.5) {
          this.sessionTabsViewportWidth = width;
          this.scheduleRevealActiveSession();
        }
      });

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 2 }) {
          Text($r('app.string.remote_session_tab_add_symbol'))
            .fontSize(15)
            .fontColor(this.canAddSession
              ? $r('app.color.neu_text_primary')
              : $r('app.color.neu_text_disabled'));
          Text('新建')
            .fontSize($r('app.float.font_caption'))
            .fontColor(this.canAddSession
              ? $r('app.color.neu_text_secondary')
              : $r('app.color.neu_text_disabled'));
        }
        .alignItems(VerticalAlign.Center);
      }
      .height(44)
      .padding({ left: 10, right: 10 })
      .enabled(this.canAddSession)
      .backgroundColor($r('app.color.mica_control'))
      .border({ width: 1, color: $r('app.color.mica_border') })
      .borderRadius($r('app.float.radius_10'))
      .hoverEffect(HoverEffect.Auto)
      .accessibilityText(this.canAddSession ? '新建远程会话' : '已达到六个会话上限')
      .onClick((): void => this.onAddSession());
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.measureSessionTabsBar(Number(newArea.height));
    });
  }

  @Builder
  private ActionButton(options: ToolbarActionOptions) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(options.label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(options.enabled === false
          ? $r('app.color.neu_text_disabled')
          : (options.active ? $r('app.color.white') : $r('app.color.neu_text_primary')))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(44)
    .padding({ left: 6, right: 6 })
    .enabled(options.enabled !== false)
    .backgroundColor(options.active ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
    .border({
      width: 1,
      color: options.active ? $r('app.color.brand_primary') : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(options.label)
    .accessibilitySelected(options.active)
    .geometryTransition(options.transitionId)
    .transition(TransitionEffect.OPACITY)
    .onClick((): void => {
      options.onClick();
    });
  }

  @Builder
  private AudioToggle() {
    Row({ space: 4 }) {
      Text(this.audioAvailable ? '音频' : (this.directSession ? '音频不可用' : '准备中'))
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.audioAvailable
          ? $r('app.color.neu_text_primary')
          : $r('app.color.neu_text_disabled'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      if (this.audioAvailable) {
        Toggle({
          type: ToggleType.Switch,
          isOn: !this.audioMuted,
        })
          .enabled(this.audioAvailable)
          .selectedColor($r('app.color.brand_primary'))
          .switchPointColor($r('app.color.white'))
          .onChange((enabled: boolean): void => {
            this.onAudioChange(enabled);
          });
      }
    }
    .layoutWeight(1)
    .height(44)
    .padding({ left: 8, right: 6 })
    .backgroundColor($r('app.color.mica_control'))
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_10'))
    .opacity(this.audioAvailable ? 1 : 0.72)
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private DangerButton(label: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_danger'))
        .maxLines(1);
    }
    .layoutWeight(1)
    .height(44)
    .padding({ left: 6, right: 6 })
    .backgroundColor($r('app.color.mica_control'))
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(label)
    .onClick((): void => {
      this.onDisconnect();
    });
  }

  @Builder
  private AndroidNavButton() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(this.displayedAndroidNavigationVisible ? '收起导航' : '安卓导航')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.displayedAndroidNavigationVisible
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'))
        .maxLines(1);
    }
    .layoutWeight(1)
    .height(44)
    .padding({ left: 6, right: 6 })
    .backgroundColor(this.displayedAndroidNavigationVisible
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .border({
      width: 1,
      color: this.displayedAndroidNavigationVisible
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(this.displayedAndroidNavigationVisible ? '收起安卓导航键' : '展开安卓导航键')
    .onClick((): void => {
      this.displayedAndroidNavigationVisible = !this.displayedAndroidNavigationVisible;
      this.onToggleAndroidNavigation();
    });
  }

  private showUtilityRow(): boolean {
    if (this.windowControlsAvailable) {
      return true;
    }
    if (this.refreshDisplayEnabled && this.toolbarWidth < 360) {
      return true;
    }
    return false;
  }

  @Builder
  private FunctionHome() {
    Column({ space: $r('app.float.space_8') }) {
      if (this.rotationAvailable) {
        Row({ space: 8 }) {
          this.HeaderActionButton('旋转至当前方向', false, () => this.onRotateToCurrent(), this.rotationBusy, 1);
          this.HeaderActionButton('旋转90度', false, () => this.onRotate90(), this.rotationBusy, 1);
        }
        .width('100%');
      }
      if (this.isSharedSession) {
        Row({ space: $r('app.float.space_8') }) {
          this.ActionButton({
            label: '画质',
            active: this.activeOverlayPanel === 'quality',
            transitionId: this.qualityTransitionId,
            onClick: () => this.onOpenQuality(),
          });
          this.DangerButton('断开连接');
        }
        .width('100%');
      } else {
        SessionInputControls({
          inputEnabled: this.inputEnabled,
          touchMode: this.touchMode,
          relativeMouseMode: this.relativeMouseMode,
          relativeModeSupported: this.relativeModeSupported,
          rightClickGesture: this.rightClickGesture,
          wideLayout: false,
          onSelectMode: (mode: RustDeskInputMode): void => this.onSelectInputMode(mode),
          onSelectRightClick: (gesture: RustDeskRightClickGesture): void =>
            this.onSelectRightClick(gesture),
        });

        if (this.toolbarWidth >= 360) {
          Row({ space: $r('app.float.space_8') }) {
            this.ActionButton({
              label: '显示器',
              active: this.activeOverlayPanel === 'display',
              transitionId: this.displayTransitionId,
              onClick: () => this.onOpenDisplay(),
            });
            this.ActionButton({
              label: '画质',
              active: this.activeOverlayPanel === 'quality',
              transitionId: this.qualityTransitionId,
              onClick: () => this.onOpenQuality(),
            });
            this.AudioToggle();
          }
          .width('100%');

          Row({ space: $r('app.float.space_8') }) {
            this.ActionButton({
              label: '虚拟键盘',
              active: this.softKeyboardVisible,
              transitionId: SOFT_KEYBOARD_TRANSITION_ID,
              enabled: this.softKeyboardAvailable,
              onClick: () => this.onToggleSoftKeyboard(),
            });
            this.ActionButton({
              label: '输入法',
              active: this.systemImeActive,
              transitionId: SYSTEM_IME_TRANSITION_ID,
              enabled: this.systemImeAvailable,
              onClick: () => this.onToggleSystemIme(),
            });
            this.DangerButton('断开连接');
          }
          .width('100%');
        } else {
          Row({ space: $r('app.float.space_8') }) {
            this.ActionButton({
              label: '显示器',
              active: this.activeOverlayPanel === 'display',
              transitionId: this.displayTransitionId,
              onClick: () => this.onOpenDisplay(),
            });
            this.ActionButton({
              label: '画质',
              active: this.activeOverlayPanel === 'quality',
              transitionId: this.qualityTransitionId,
              onClick: () => this.onOpenQuality(),
            });
          }
          .width('100%');

          Row({ space: $r('app.float.space_8') }) {
            this.ActionButton({
              label: '虚拟键盘',
              active: this.softKeyboardVisible,
              transitionId: SOFT_KEYBOARD_TRANSITION_ID,
              enabled: this.softKeyboardAvailable,
              onClick: () => this.onToggleSoftKeyboard(),
            });
            this.ActionButton({
              label: '输入法',
              active: this.systemImeActive,
              transitionId: SYSTEM_IME_TRANSITION_ID,
              enabled: this.systemImeAvailable,
              onClick: () => this.onToggleSystemIme(),
            });
          }
          .width('100%');

          Row({ space: $r('app.float.space_8') }) {
            this.AudioToggle();
            this.DangerButton('断开连接');
          }
          .width('100%');
        }

        if (this.androidNavigationAvailable) {
          Row() {
            this.AndroidNavButton();
          }
          .width('100%');
        }
      }

      if (!this.audioAvailable && this.audioUnavailableText !== '') {
        Text(this.audioUnavailableText)
          .width('100%')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.neu_text_secondary'))
          .padding({ left: 4, right: 4 });
      }

      if (this.directSession) {
        if (this.keyboardUnavailableText !== '') {
          Text(this.keyboardUnavailableText)
            .width('100%')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.neu_text_secondary'))
            .padding({ left: 4, right: 4 });
        }
        if (this.windowUnavailableText !== '') {
          Text(this.windowUnavailableText)
            .width('100%')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.neu_text_secondary'))
            .padding({ left: 4, right: 4 });
        }
      }
      if ((this.directSession || this.isSharedSession) && this.statusMessage.length > 0) {
        Text(this.statusMessage)
          .width('100%')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.neu_text_secondary'))
          .padding({ left: 4, right: 4 });
      }
    }
    .width('100%');
  }

  @Builder
  private HeaderTelemetry() {
    Row() {
      Row({ space: this.toolbarWidth < 360 ? 8 : 12 }) {
        // 编码格式
        Column({ space: 1 }) {
          Text('编码')
            .fontSize(10)
            .fontWeight(FontWeight.Normal)
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(1);

          Text(this.metrics.codec)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.metrics.codec === '--'
              ? $r('app.color.neu_text_secondary')
              : $r('app.color.neu_accent'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        // 实测提交帧率
        Column({ space: 1 }) {
          Text('提交')
            .fontSize(10)
            .fontWeight(FontWeight.Normal)
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(1);

          Row({ space: 2 }) {
            Text(this.metrics.fps)
              .fontSize($r('app.float.font_caption'))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.metrics.fps === '--'
                ? $r('app.color.neu_text_secondary')
                : $r('app.color.neu_text_primary'))
              .maxLines(1);

            Text('FPS')
              .fontSize(10)
              .fontWeight(FontWeight.Normal)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1);
          }
          .alignItems(VerticalAlign.Bottom);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        // 网络延迟 RTT
        Column({ space: 1 }) {
          Text('RTT')
            .fontSize(10)
            .fontWeight(FontWeight.Normal)
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(1);

          Row({ space: 2 }) {
            Text(this.metrics.delay)
              .fontSize($r('app.float.font_caption'))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.metrics.delay === '--'
                ? $r('app.color.neu_text_secondary')
                : $r('app.color.neu_text_primary'))
              .maxLines(1);

            Text('ms')
              .fontSize(10)
              .fontWeight(FontWeight.Normal)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1);
          }
          .alignItems(VerticalAlign.Bottom);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center);

      if (this.canResetTransform) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text(this.transformSummary.trim() === '100%' ? '居中' : '复位')
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_accent'));
        }
        .height(44)
        .constraintSize({ minWidth: 44 })
        .padding({ left: 6, right: 6 })
        .backgroundColor($r('app.color.transparent'))
        .borderRadius($r('app.float.radius_10'))
        .hoverEffect(HoverEffect.Auto)
        .accessibilityText(this.transformSummary.trim() === '100%' ? '居中画面' : '复位画面')
        .onClick(() => this.onResetTransform());
      }
    }
    .layoutWeight(1)
    .height(44)
    .padding({
      left: this.toolbarWidth < 360 ? 8 : 10,
      right: this.canResetTransform ? 0 : (this.toolbarWidth < 360 ? 8 : 10),
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.mica_control'))
    .borderRadius($r('app.float.radius_10'))
    .border({ width: 1, color: $r('app.color.mica_border') });
  }

  build(): void {
    Column({ space: TOOLBAR_SECTION_GAP }) {
      // Header section: Row 1 + optional Utility Row
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          this.HeaderTelemetry();

          // Utilities + Drag grip
          Row({ space: 4 }) {
            if (!this.showUtilityRow() && this.refreshDisplayEnabled) {
              this.HeaderActionButton('刷新', false, () => this.onRefreshDisplay());
            }

            this.HeaderActionButton('收起', false, () => this.onCollapse());

            this.ToolbarDragGrip();
          }
          .alignItems(VerticalAlign.Center);
        }
        .width('100%')
        .constraintSize({ minHeight: 44 })
        .alignItems(VerticalAlign.Center);

        if (this.showUtilityRow()) {
          Row({ space: 6 }) {
            if (this.refreshDisplayEnabled) {
              this.HeaderActionButton('刷新', false, () => this.onRefreshDisplay(), false, 1);
            }
            if (this.windowControlsAvailable) {
              if (this.windowFullscreenAvailable) {
                this.HeaderActionButton(
                  this.windowFullscreen ? '退出全屏' : '全屏',
                  this.windowFullscreen,
                  () => {
                    if (!this.windowControlBusy) {
                      this.onToggleWindowFullscreen();
                    }
                  },
                  this.windowControlBusy,
                  1,
                );
              }
              this.HeaderActionButton(
                '最小化',
                false,
                () => {
                  if (!this.windowControlBusy) {
                    this.onMinimizeWindow();
                  }
                },
                this.windowControlBusy,
                1,
              );
            }
          }
          .width('100%')
          .height(44)
          .alignItems(VerticalAlign.Center);
        }
      }
      .width('100%')
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.measureToolbarHeader(Number(newArea.height));
      });

      // Session tabs bar (if multi-session or tabs exist)
      if (this.tabs.length > 0) {
        this.SessionTabsBar();
      }

      // Body
      if (this.activeOverlayPanel === 'home') {
        Scroll() {
          this.FunctionHome();
        }
        .width('100%')
        .constraintSize({ maxHeight: this.panelContentHeight })
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off);
      }
      // The submenu subtree stays mounted while the toolbar shows its home, so the
      // native device picker inside it keeps the selected-device state it drew. It is
      // `Visibility.None` rather than an `if`: that only stops it participating in
      // layout, so the toolbar's height is still the home content's own height and the
      // submenu never inflates the panel.
      Stack() {
        this.content();
      }
      .width('100%')
      .height(this.panelContentHeight)
      .padding({
        left: $r('app.float.space_6'),
        right: $r('app.float.space_6'),
        bottom: $r('app.float.space_6'),
      })
      .clip(false)
      .visibility(this.activeOverlayPanel === 'home' ? Visibility.None : Visibility.Visible);
    }
    .width('100%')
    .clip(false)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (width > 0 && Math.abs(width - this.toolbarWidth) > 0.5) {
        this.toolbarWidth = width;
        this.scheduleRevealActiveSession();
      }
    });
  }
}
