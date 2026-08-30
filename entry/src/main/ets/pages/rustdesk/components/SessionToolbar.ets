import { SessionOverlayPanel } from '../SessionOverlayState';
import { SessionToolbarMetrics } from '../SessionToolbarMetrics';
import { RemoteSessionTab } from '../RemoteSessionTabsController';

const SOFT_KEYBOARD_TRANSITION_ID = 'rustdesk-session-soft-keyboard';
const SYSTEM_IME_TRANSITION_ID = 'rustdesk-session-system-ime';

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
  touchMode: boolean;
  relativeMouseMode: boolean;
  metrics: SessionToolbarMetrics;
  activeOverlayPanel: SessionOverlayPanel;
  inputTransitionId: string;
  chatTransitionId: string;
  displayTransitionId: string;
  qualityTransitionId: string;
  unreadCount: number;
  cameraSession: boolean;
  viewOnlySession: boolean;
  androidNavigationAvailable: boolean;
  androidNavigationVisible: boolean;
  softKeyboardAvailable: boolean;
  softKeyboardVisible: boolean;
  systemImeAvailable: boolean;
  systemImeActive: boolean;
  audioAvailable: boolean;
  audioMuted: boolean;
  wideLayout: boolean;
  transformSummary: string;
  canResetTransform: boolean;
  panelContentHeight: number;
  windowControlsAvailable: boolean;
  windowFullscreenAvailable: boolean;
  windowFullscreen: boolean;
  windowControlBusy: boolean;
  refreshDisplayEnabled: boolean;
  onOpenInput: () => void;
  onResetTransform: () => void;
  onOpenChat: () => void;
  onOpenDisplay: () => void;
  onOpenQuality: () => void;
  onRefreshDisplay: () => void;
  onToggleSoftKeyboard: () => void;
  onToggleSystemIme: () => void;
  onToggleAndroidNavigation: () => void;
  onAudioChange: (enabled: boolean) => void;
  onDisconnect: () => void;
  onCollapse: () => void;
  onMinimizeWindow: () => void;
  onToggleWindowFullscreen: () => void;
  onSelectSession: (sessionId: string) => void;
  onCloseSession: (sessionId: string) => void;
  onAddSession: () => void;
  content: () => void;
}

@ComponentV2
export struct SessionToolbar {
  @Param tabs: Array<RemoteSessionTab> = [];
  @Param activeSessionId: string = '';
  @Param canAddSession: boolean = true;
  @Param touchMode: boolean = true;
  @Local displayedTouchMode: boolean = true;
  @Param relativeMouseMode: boolean = false;
  @Local displayedRelativeMouseMode: boolean = false;
  @Param metrics: SessionToolbarMetrics = {
    fps: '--',
    frames: '--',
    decode: '--',
    delay: '--',
    codec: '--',
  };
  @Param activeOverlayPanel: SessionOverlayPanel = 'home';
  @Param inputTransitionId: string = '';
  @Param chatTransitionId: string = '';
  @Param displayTransitionId: string = '';
  @Param qualityTransitionId: string = '';
  @Param unreadCount: number = 0;
  @Param cameraSession: boolean = false;
  @Param viewOnlySession: boolean = false;
  @Param androidNavigationAvailable: boolean = false;
  @Param androidNavigationVisible: boolean = false;
  @Local displayedAndroidNavigationVisible: boolean = false;
  @Param softKeyboardAvailable: boolean = false;
  @Param softKeyboardVisible: boolean = false;
  @Param systemImeAvailable: boolean = false;
  @Param systemImeActive: boolean = false;
  @Param audioAvailable: boolean = false;
  @Param audioMuted: boolean = false;
  @Param wideLayout: boolean = false;
  @Param transformSummary: string = '100%';
  @Param canResetTransform: boolean = false;
  @Param panelContentHeight: number = 360;
  @Param windowControlsAvailable: boolean = false;
  @Param windowFullscreenAvailable: boolean = false;
  @Param windowFullscreen: boolean = false;
  @Param windowControlBusy: boolean = false;
  @Param refreshDisplayEnabled: boolean = false;
  @Event onOpenInput: () => void = () => {};
  @Event onResetTransform: () => void = () => {};
  @Event onOpenChat: () => void = () => {};
  @Event onOpenDisplay: () => void = () => {};
  @Event onOpenQuality: () => void = () => {};
  @Event onRefreshDisplay: () => void = () => {};
  @Event onToggleSoftKeyboard: () => void = () => {};
  @Event onToggleSystemIme: () => void = () => {};
  @Event onToggleAndroidNavigation: () => void = () => {};
  @Event onAudioChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  @Event onDisconnect: () => void = () => {};
  @Event onCollapse: () => void = () => {};
  @Event onMinimizeWindow: () => void = () => {};
  @Event onToggleWindowFullscreen: () => void = () => {};
  @Event onSelectSession: (sessionId: string) => void = (_sessionId: string) => {};
  @Event onCloseSession: (sessionId: string) => void = (_sessionId: string) => {};
  @Event onAddSession: () => void = () => {};
  @Local toolbarWidth: number = 280;
  @Local sessionTabsViewportWidth: number = 0;
  private sessionScroller: Scroller = new Scroller();

  @BuilderParam content: () => void = this.Empty;

  aboutToAppear(): void {
    this.displayedTouchMode = this.touchMode;
    this.displayedRelativeMouseMode = this.relativeMouseMode;
    this.displayedAndroidNavigationVisible = this.androidNavigationVisible;
  }

  @Monitor('touchMode')
  private onTouchModeChanged(_monitor: IMonitor): void {
    this.displayedTouchMode = this.touchMode;
  }

  @Monitor('relativeMouseMode')
  private onRelativeMouseModeChanged(_monitor: IMonitor): void {
    this.displayedRelativeMouseMode = this.relativeMouseMode;
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
      return Math.min(220, Math.max(96, this.sessionTabsViewportWidth));
    }
    return 220;
  }

  private addSessionButtonWidth(): number {
    return 64;
  }

  private sessionContentWidth(): number {
    const contentWidth = this.tabs.length * this.sessionCardWidth() + Math.max(0, this.tabs.length - 1) * 6;
    return Math.max(this.sessionTabsViewportWidth, contentWidth);
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
    const cardEnd = cardStart + this.sessionCardWidth();
    try {
      const currentOffset = this.sessionScroller.currentOffset().xOffset;
      let targetOffset = currentOffset;
      if (cardStart < currentOffset) {
        targetOffset = cardStart;
      } else if (cardEnd > currentOffset + viewportWidth) {
        targetOffset = cardStart;
      }
      if (Math.abs(targetOffset - currentOffset) > 0.5) {
        this.sessionScroller.scrollTo({
          xOffset: Math.max(0, targetOffset),
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

  @Builder
  private SessionCard(tab: RemoteSessionTab) {
    Row({ space: 2 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 7 }) {
          Stack()
            .width(9)
            .height(9)
            .borderRadius(5)
            .backgroundColor(this.sessionStatusColor(tab));

          Column({ space: 1 }) {
            Text(tab.label)
              .fontSize($r('app.float.font_label'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(tab.target)
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_4') });
      }
      .layoutWeight(1)
      .height(46)
      .padding(0)
      .backgroundColor($r('app.color.transparent'))
      .hoverEffect(HoverEffect.Auto)
      .accessibilityText(`${tab.label}，${tab.target}，点击切换`)
      .accessibilitySelected(tab.sessionId === this.activeSessionId)
      .onClick((): void => this.onSelectSession(tab.sessionId));

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text($r('app.string.remote_session_tab_close_symbol'))
          .fontSize(13)
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
    .height(48)
    .padding({ left: 2, right: 2 })
    .backgroundColor(tab.sessionId === this.activeSessionId
      ? $r('app.color.brand_primary_soft')
      : $r('app.color.mica_control'))
    .border({
      width: 1,
      color: tab.sessionId === this.activeSessionId
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_14'))
    .clip(true);
  }

  @Builder
  private SessionTabsBar() {
    Row({ space: $r('app.float.space_6') }) {
      Scroll(this.sessionScroller) {
        Row({ space: $r('app.float.space_6') }) {
          ForEach(this.tabs, (tab: RemoteSessionTab) => {
            this.SessionCard(tab);
          }, (tab: RemoteSessionTab): string => tab.sessionId);
        }
        .width(this.sessionContentWidth())
        .justifyContent(FlexAlign.Start)
        .align(Alignment.Start);
      }
      .layoutWeight(1)
      .height(50)
      .align(Alignment.Start)
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
        Column({ space: 1 }) {
          Text($r('app.string.remote_session_tab_add_symbol'))
            .fontSize(18)
            .fontColor(this.canAddSession
              ? $r('app.color.neu_text_primary')
              : $r('app.color.neu_text_disabled'));
          Text('新建')
            .fontSize($r('app.float.font_caption'))
            .fontColor(this.canAddSession
              ? $r('app.color.neu_text_secondary')
              : $r('app.color.neu_text_disabled'));
        }
      }
      .width(this.addSessionButtonWidth())
      .height(48)
      .padding(0)
      .enabled(this.canAddSession)
      .backgroundColor($r('app.color.mica_control'))
      .border({ width: 1, color: $r('app.color.mica_border') })
      .borderRadius($r('app.float.radius_14'))
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .hoverEffect(HoverEffect.Auto)
      .accessibilityText(this.canAddSession ? '新建远程会话' : '已达到六个会话上限')
      .onClick((): void => this.onAddSession());
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  private actionHeight(): number {
    return 38;
  }

  private actionColumnCount(): number {
    if (this.toolbarWidth >= 1000) {
      return 8;
    }
    return this.toolbarWidth >= 620 ? 4 : 2;
  }

  private actionGridWidth(): number {
    return this.toolbarWidth;
  }

  private actionButtonWidth(): number {
    const columns = this.actionColumnCount();
    return (this.actionGridWidth() - (columns - 1) * 8) / columns;
  }

  private toolbarActionEnabled(options: ToolbarActionOptions): boolean {
    return options.enabled !== false;
  }

  private pointerModeLabel(): string {
    if (this.displayedTouchMode) {
      return '触控模式';
    }
    return this.displayedRelativeMouseMode ? '相对鼠标' : '鼠标模式';
  }

  @Builder
  private ToolbarAction(options: ToolbarActionOptions) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(options.label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(!this.toolbarActionEnabled(options)
          ? $r('app.color.neu_text_disabled')
          : (options.active ? $r('app.color.white') : $r('app.color.neu_text_primary')))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width(this.actionButtonWidth())
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
    .enabled(this.toolbarActionEnabled(options))
    .backgroundColor(options.active ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: options.active ? $r('app.color.brand_primary') : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
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
  private PointerModeAction() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(`输入 · ${this.pointerModeLabel()}`)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.activeOverlayPanel === 'input'
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width(this.actionButtonWidth())
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
    .backgroundColor(this.activeOverlayPanel === 'input'
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: this.activeOverlayPanel === 'input'
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(`打开输入模式设置，当前${this.pointerModeLabel()}`)
    .accessibilitySelected(this.activeOverlayPanel === 'input')
    .geometryTransition(this.inputTransitionId)
    .transition(TransitionEffect.OPACITY)
    .onClick((): void => {
      this.onOpenInput();
    });
  }

  @Builder
  private AudioToggle() {
    Row({ space: $r('app.float.space_6') }) {
      Text(this.audioAvailable ? '音频' : '准备中')
        .layoutWeight(1)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.audioAvailable
          ? $r('app.color.neu_text_primary')
          : $r('app.color.neu_text_disabled'))
        .maxLines(1);

      Toggle({
        type: ToggleType.Switch,
        isOn: this.audioAvailable && !this.audioMuted,
      })
        .enabled(this.audioAvailable)
        .selectedColor($r('app.color.brand_primary'))
        .switchPointColor($r('app.color.white'))
        .onChange((enabled: boolean): void => {
          this.onAudioChange(enabled);
        });
    }
    .width(this.actionButtonWidth())
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_8') })
    .backgroundColor($r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .opacity(this.audioAvailable ? 1 : 0.72)
    .clip(true);
  }

  @Builder
  private AndroidNavigationAction() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(this.displayedAndroidNavigationVisible ? '收起导航' : '展开导航')
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.displayedAndroidNavigationVisible
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width(84)
    .height($r('app.float.control_compact'))
    .padding({ left: $r('app.float.space_6'), right: $r('app.float.space_6') })
    .backgroundColor(this.displayedAndroidNavigationVisible
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: this.displayedAndroidNavigationVisible
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(this.displayedAndroidNavigationVisible ? '收起安卓导航键' : '展开安卓导航键')
    .accessibilitySelected(this.displayedAndroidNavigationVisible)
    .transition(TransitionEffect.OPACITY)
    .onClick((): void => {
      this.displayedAndroidNavigationVisible = !this.displayedAndroidNavigationVisible;
      this.onToggleAndroidNavigation();
    });
  }

  @Builder
  private CompactAction(
    key: string,
    label: string,
    selected: boolean,
    _adjustment: boolean,
    enabled: boolean,
    onClick: () => void,
  ) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Medium)
        .fontColor(enabled
          ? (selected ? $r('app.color.white') : $r('app.color.neu_text_primary'))
          : $r('app.color.neu_text_disabled'));
    }
    .width(key === 'transform' ? 92 : (key === 'android-navigation' ? 84 : 68))
    .height($r('app.float.control_compact'))
    .padding({ left: $r('app.float.space_6'), right: $r('app.float.space_6') })
    .enabled(enabled)
    .backgroundColor(selected ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: selected ? $r('app.color.brand_primary') : $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_10'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(label)
    .onClick((): void => {
      if (enabled) {
        onClick();
      }
    });
  }

  @Builder
  private DangerAction(label: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_danger'))
        .maxLines(1);
    }
    .width(this.actionButtonWidth())
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
    .backgroundColor($r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(label)
    .onClick((): void => {
      this.onDisconnect();
    });
  }

  private transformResetLabel(): string {
    return this.transformSummary.trim() === '100%' ? '居中' : '复位';
  }

  private windowUtilityLabel(kind: string): string {
    if (kind === 'fullscreen') {
      return this.windowFullscreen ? '退出全屏' : '全屏';
    }
    return '最小化';
  }

  @Builder
  private WindowUtilityAction(kind: string) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(this.windowUtilityLabel(kind))
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.windowControlBusy
          ? $r('app.color.neu_text_disabled')
          : $r('app.color.neu_text_primary'))
        .maxLines(1);
    }
    .width(kind === 'fullscreen' ? 88 : 68)
    .height($r('app.float.control_compact'))
    .padding({ left: $r('app.float.space_6'), right: $r('app.float.space_6') })
    .enabled(!this.windowControlBusy)
    .backgroundColor($r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: kind === 'fullscreen' && this.windowFullscreen
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.Auto)
    .accessibilityText(this.windowUtilityLabel(kind))
    .accessibilitySelected(kind === 'fullscreen' && this.windowFullscreen)
    .onClick((): void => {
      if (this.windowControlBusy) {
        return;
      }
      if (kind === 'fullscreen') {
        this.onToggleWindowFullscreen();
      } else {
        this.onMinimizeWindow();
      }
    });
  }

  @Builder
  private TransformControls() {
    Row({ space: $r('app.float.space_6') }) {
      Text(this.transformSummary)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_secondary'))
        .maxLines(1);

      if (this.canResetTransform) {
        this.CompactAction(
          'reset-transform',
          this.transformResetLabel(),
          false,
          false,
          true,
          () => this.onResetTransform(),
        )
      }
    }
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private ToolbarUtilityActions() {
    Row({ space: $r('app.float.space_6') }) {
      this.TransformControls()
      this.CompactAction('refresh-display', '刷新画面', false, false, this.refreshDisplayEnabled,
        () => this.onRefreshDisplay())
      if (this.windowControlsAvailable) {
        if (this.windowFullscreenAvailable) {
          this.WindowUtilityAction('fullscreen')
        }
        this.WindowUtilityAction('minimize')
      }
      this.CompactAction('collapse', '收起', false, false, true, () => this.onCollapse())
    }
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private NarrowToolbarUtilityActions() {
    Row({ space: $r('app.float.space_6') }) {
      Row() {
        this.TransformControls()
      }
      .layoutWeight(1);

      this.CompactAction('refresh-display', '刷新画面', false, false, this.refreshDisplayEnabled,
        () => this.onRefreshDisplay())
      if (this.windowControlsAvailable) {
        if (this.windowFullscreenAvailable) {
          this.WindowUtilityAction('fullscreen')
        }
        this.WindowUtilityAction('minimize')
      }
      this.CompactAction('collapse', '收起', false, false, true, () => this.onCollapse())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  private useNarrowUtilityLayout(): boolean {
    return !this.wideLayout || this.toolbarWidth < 920;
  }

  @Builder
  private SystemImeAction() {
    this.ToolbarAction({
      label: '输入法',
      active: this.systemImeActive,
      transitionId: SYSTEM_IME_TRANSITION_ID,
      enabled: this.systemImeAvailable,
      onClick: () => this.onToggleSystemIme(),
    })
  }

  @Builder
  private SoftKeyboardAction() {
    this.ToolbarAction({
      label: '虚拟键盘',
      active: this.softKeyboardVisible,
      transitionId: SOFT_KEYBOARD_TRANSITION_ID,
      enabled: this.softKeyboardAvailable,
      onClick: () => this.onToggleSoftKeyboard(),
    })
  }

  @Builder
  private ChatAction() {
    this.ToolbarAction({
      label: this.unreadCount > 0 ? `聊天 ${this.unreadCount}` : '聊天',
      active: this.activeOverlayPanel === 'chat',
      transitionId: this.chatTransitionId,
      onClick: () => this.onOpenChat(),
    })
  }

  @Builder
  private DisplayAction() {
    this.ToolbarAction({
      label: '显示器',
      active: this.activeOverlayPanel === 'display',
      transitionId: this.displayTransitionId,
      onClick: () => this.onOpenDisplay(),
    })
  }

  @Builder
  private QualityAction() {
    this.ToolbarAction({
      label: '画质',
      active: this.activeOverlayPanel === 'quality',
      transitionId: this.qualityTransitionId,
      onClick: () => this.onOpenQuality(),
    })
  }

  @Builder
  private FunctionHome() {
    if (this.cameraSession) {
      Row({ space: $r('app.float.space_8') }) {
        this.QualityAction()
        this.DangerAction('断开')
      }
      .width(this.actionGridWidth())
      .justifyContent(FlexAlign.Center);
    } else if (this.viewOnlySession && this.actionColumnCount() === 2) {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.DisplayAction()
          this.QualityAction()
        }
        .width(this.actionGridWidth());

        Row() {
          this.DangerAction('断开')
        }
        .width(this.actionGridWidth())
        .justifyContent(FlexAlign.Center);
      }
      .width(this.actionGridWidth());
    } else if (this.viewOnlySession) {
      Row({ space: $r('app.float.space_8') }) {
        this.DisplayAction()
        this.QualityAction()
        this.DangerAction('断开')
      }
      .width(this.actionGridWidth())
      .justifyContent(FlexAlign.Center);
    } else if (this.actionColumnCount() === 8) {
      Row({ space: $r('app.float.space_8') }) {
        this.PointerModeAction()
        this.SystemImeAction()
        this.SoftKeyboardAction()
        this.ChatAction()
        this.AudioToggle()
        this.DisplayAction()
        this.QualityAction()
        this.DangerAction('断开')
      }
      .width(this.actionGridWidth())
      .alignItems(VerticalAlign.Center);
    } else if (this.actionColumnCount() === 4) {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.PointerModeAction()
          this.SystemImeAction()
          this.SoftKeyboardAction()
          this.ChatAction()
        }
        .width(this.actionGridWidth());

        Row({ space: $r('app.float.space_8') }) {
          this.AudioToggle()
          this.DisplayAction()
          this.QualityAction()
          this.DangerAction('断开')
        }
        .width(this.actionGridWidth())
        .alignItems(VerticalAlign.Center);
      }
      .width(this.actionGridWidth());
    } else {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.PointerModeAction()
          this.SystemImeAction()
        }
        .width(this.actionGridWidth());

        Row({ space: $r('app.float.space_8') }) {
          this.SoftKeyboardAction()
          this.ChatAction()
        }
        .width(this.actionGridWidth());

        Row({ space: $r('app.float.space_8') }) {
          this.AudioToggle()
          this.DisplayAction()
        }
        .width(this.actionGridWidth());

        Row({ space: $r('app.float.space_8') }) {
          this.QualityAction()
          this.DangerAction('断开')
        }
        .width(this.actionGridWidth());
      }
      .width(this.actionGridWidth());
    }
  }

  build(): void {
    Column({ space: $r('app.float.space_8') }) {
      if (this.tabs.length > 0) {
        this.SessionTabsBar();
      }

      Row({ space: $r('app.float.space_8') }) {
        Text(`${this.metrics.codec}`)
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_accent'))
          .maxLines(1);
        Text(`${this.metrics.fps} FPS`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.neu_text_secondary'))
          .maxLines(1);
        Text(`${this.metrics.delay} ms`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.neu_text_secondary'))
          .maxLines(1);
        if (this.wideLayout) {
          Text(`解码 ${this.metrics.decode}`)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(1);
          Text(`帧 ${this.metrics.frames}`)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(1);
        }
        Blank()
        if (!this.useNarrowUtilityLayout()) {
          this.ToolbarUtilityActions()
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (this.useNarrowUtilityLayout()) {
        Row() {
          this.NarrowToolbarUtilityActions();
        }
        .width('100%')
        .justifyContent(FlexAlign.End);

      }

      if (this.activeOverlayPanel === 'home') {
        Column({ space: $r('app.float.space_8') }) {
          this.FunctionHome();

          if (this.androidNavigationAvailable) {
            Row() {
              this.AndroidNavigationAction();
            }
            .width('100%')
            .justifyContent(FlexAlign.End);
          }
        }
        .width('100%');
      } else {
        Stack() {
          this.content();
        }
        .width('100%')
        .height(this.panelContentHeight)
        .padding({
          left: $r('app.float.space_8'),
          right: $r('app.float.space_8'),
          bottom: $r('app.float.space_8'),
        })
        .clip(false);
      }
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
