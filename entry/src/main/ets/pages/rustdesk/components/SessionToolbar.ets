import { SessionOverlayPanel } from '../SessionOverlayState';
import { SessionToolbarMetrics } from '../SessionToolbarMetrics';
import { RemoteSessionTab } from '../RemoteSessionTabsController';
import { RustDeskInputMode, RustDeskRightClickGesture } from '../RustDeskDirectoryTypes';
import { SessionInputControls } from './SessionInputControls';

const SOFT_KEYBOARD_TRANSITION_ID = 'rustdesk-session-soft-keyboard';
const SYSTEM_IME_TRANSITION_ID = 'rustdesk-session-system-ime';
/**
 * The gap between the toolbar's stacked sections.
 *
 * The page's body budget subtracts this, so the two have to be the same value.
 */
const TOOLBAR_SECTION_GAP = 6;
/** The header's grab strip. It carries the drag and no control. */
const TOOLBAR_DRAG_GRIP_WIDTH = 32;
/**
 * How much a measured header width may move before the scroll offset is
 * re-applied, in vp. It keeps a telemetry value that re-renders to a slightly
 * different width from pulling a position the operator scrolled to back.
 */
const HEADER_ALIGN_TOLERANCE = 0.5;

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
  /** The middle slot's height budget: the panel body, or the home block's cap. */
  panelContentHeight: number;
  windowControlsAvailable: boolean;
  windowFullscreenAvailable: boolean;
  windowFullscreen: boolean;
  windowControlBusy: boolean;
  refreshDisplayEnabled: boolean;
  onSelectInputMode: (mode: RustDeskInputMode) => void;
  onSelectRightClick: (gesture: RustDeskRightClickGesture) => void;
  onResetTransform: () => void;
  onOpenDisplay: () => void;
  onOpenQuality: () => void;
  onRefreshDisplay: () => void;
  onToggleSoftKeyboard: () => void;
  onToggleSystemIme: () => void;
  onToggleAndroidNavigation: () => void;
  onAudioChange: (enabled: boolean) => void;
  onDisconnect: () => void;
  onCollapse: () => void;
  /** A move of the panel begins on the header's grip; the page owns the anchor. */
  onToolbarMoveStart: () => void;
  onToolbarMoveUpdate: (offsetX: number, offsetY: number) => void;
  /**
   * What the toolbar spends on its own chrome, in vp: the header row, the gaps
   * between sections and the session tab bar. The page turns it into the body
   * budget, so a taller header or a visible tab bar shortens the body.
   */
  onChromeHeightChange: (height: number) => void;
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
  @Local toolbarWidth: number = 280;
  @Local sessionTabsViewportWidth: number = 0;
  /** The measured header row height, and the measured tab bar height. */
  private toolbarHeaderHeight: number = 0;
  private sessionTabsBarHeight: number = 0;
  /** The chrome value already handed to the page, so it is only told changes. */
  private reportedChromeHeight: number = 0;
  /** The header row's content extent, and the width of the scroll showing it. */
  private headerContentWidth: number = 0;
  private headerViewportWidth: number = 0;
  /** The pair the offset was last aligned for, so only real changes re-align. */
  private headerAlignedContentWidth: number = -1;
  private headerAlignedViewportWidth: number = -1;
  /**
   * The header's right end as last observed: the offset the last alignment
   * scrolled to, or the end a later width change revealed while the offset was
   * left where the operator put it. It is what "still at the right end" is
   * measured against.
   */
  private headerAlignedMaxOffset: number = 0;
  private headerScroller: Scroller = new Scroller();
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
        .justifyContent(FlexAlign.End)
        .align(Alignment.End);
      }
      .layoutWeight(1)
      .height(50)
      .align(Alignment.End)
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
    .alignItems(VerticalAlign.Center)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      this.measureSessionTabsBar(Number(newArea.height));
    });
  }

  private actionHeight(): number {
    return 36;
  }

  /**
   * The toolbar's own chrome: everything the middle slot does not get.
   *
   * The header row and the tab bar are measured, and the gaps are the ones the
   * column is actually built with, so the page can size the body from what is
   * left instead of from a constant that drifts whenever a row grows.
   */
  private toolbarChromeHeight(): number {
    const hasTabs = this.tabs.length > 0;
    const gaps = TOOLBAR_SECTION_GAP * (hasTabs ? 2 : 1);
    return this.toolbarHeaderHeight + gaps + (hasTabs ? this.sessionTabsBarHeight : 0);
  }

  private reportToolbarChrome(): void {
    // Both parts have to be known first: reporting the header alone would
    // understate the chrome by the whole tab bar for that frame, and the page
    // would size the body from it.
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

  /**
   * Keeps the header's right end in view, without taking the view away.
   *
   * The header row is at least as wide as the scroll showing it and grows to its
   * own content, so a toolbar too narrow for the whole row scrolls instead of
   * clipping it. Two things re-seat the header at that end: the first
   * measurement, and a real viewport change (a resize, a rotation, a wider
   * panel). A content change alone — the telemetry text gaining a digit — only
   * re-seats it while the header is still sitting at the right end last
   * observed; once the operator has scrolled somewhere else, that position is
   * theirs to keep.
   */
  private scheduleHeaderAlign(): void {
    const contentWidth = this.headerContentWidth;
    const viewportWidth = this.headerViewportWidth;
    if (contentWidth <= 0 || viewportWidth <= 0) {
      return;
    }
    const contentChanged = Math.abs(contentWidth - this.headerAlignedContentWidth)
      > HEADER_ALIGN_TOLERANCE;
    const viewportChanged = Math.abs(viewportWidth - this.headerAlignedViewportWidth)
      > HEADER_ALIGN_TOLERANCE;
    if (!contentChanged && !viewportChanged) {
      return;
    }
    const maxOffset = contentWidth - viewportWidth;
    const firstAlign = this.headerAlignedViewportWidth < 0;
    if (!firstAlign && !viewportChanged && !this.headerSitsAtAlignedEnd()) {
      // The width moved, the viewport did not, and the operator is looking
      // somewhere else: record the new width and where the right end now is,
      // and leave the offset alone.
      this.headerAlignedContentWidth = contentWidth;
      this.headerAlignedMaxOffset = Math.max(0, maxOffset);
      return;
    }
    this.headerAlignedContentWidth = contentWidth;
    this.headerAlignedViewportWidth = viewportWidth;
    if (maxOffset <= 0) {
      this.headerAlignedMaxOffset = 0;
      return;
    }
    this.headerAlignedMaxOffset = maxOffset;
    // The scroller only knows the new content extent after this layout pass.
    setTimeout((): void => {
      try {
        this.headerScroller.scrollTo({ xOffset: maxOffset, yOffset: 0, animation: false });
      } catch (_) {
      }
    }, 0);
  }

  /**
   * Whether the header is still sitting at the right end last observed.
   *
   * An unknown reading counts as still there: the offset is only withheld when
   * the scroller reports a position that is really somewhere else.
   */
  private headerSitsAtAlignedEnd(): boolean {
    if (this.headerAlignedMaxOffset <= 0) {
      return true;
    }
    try {
      return Math.abs(this.headerScroller.currentOffset().xOffset - this.headerAlignedMaxOffset)
        <= HEADER_ALIGN_TOLERANCE;
    } catch (_) {
      return true;
    }
  }

  private measureHeaderContentWidth(width: number): void {
    if (width <= 0 || Math.abs(width - this.headerContentWidth) <= HEADER_ALIGN_TOLERANCE) {
      return;
    }
    this.headerContentWidth = width;
    this.scheduleHeaderAlign();
  }

  private measureHeaderViewportWidth(width: number): void {
    if (width <= 0 || Math.abs(width - this.headerViewportWidth) <= HEADER_ALIGN_TOLERANCE) {
      return;
    }
    this.headerViewportWidth = width;
    this.scheduleHeaderAlign();
  }

  private actionColumnCount(): number {
    if (this.toolbarWidth >= 680) {
      return 6;
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
  private AudioToggle() {
    Row({ space: $r('app.float.space_6') }) {
      Text(this.audioAvailable ? '音频' : (this.directSession ? '音频不可用' : '准备中'))
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
    if (this.actionColumnCount() === 6) {
      Row({ space: $r('app.float.space_8') }) {
        this.SystemImeAction()
        this.SoftKeyboardAction()
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
          this.SystemImeAction()
          this.SoftKeyboardAction()
          this.AudioToggle()
          this.DisplayAction()
        }
        .width(this.actionGridWidth());

        Row({ space: $r('app.float.space_8') }) {
          this.QualityAction()
          this.DangerAction('断开')
        }
        .width(this.actionGridWidth())
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.End);
      }
      .width(this.actionGridWidth());
    } else {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.SystemImeAction()
          this.SoftKeyboardAction()
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

  /**
   * The header's grab strip.
   *
   * It sits in the header's right-hand strip and holds no control, so a drag of
   * the panel never reads a button press or a header scroll as a move. It is a
   * sibling of the header's scroll rather than part of it, so the gesture only
   * ever owns this strip.
   */
  @Builder
  private ToolbarDragGrip() {
    Row() {
      Stack()
        .width(4)
        .height(24)
        .backgroundColor($r('app.color.neu_text_secondary'))
        .borderRadius(2)
        .opacity(0.72);
    }
    .width(TOOLBAR_DRAG_GRIP_WIDTH)
    .height($r('app.float.control_compact'))
    .justifyContent(FlexAlign.Center)
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

  build(): void {
    Column({ space: TOOLBAR_SECTION_GAP }) {
      Row({ space: TOOLBAR_SECTION_GAP }) {
        Scroll(this.headerScroller) {
          Row({ space: $r('app.float.space_8') }) {
            Text(`${this.metrics.codec}`)
              .fontSize($r('app.float.font_caption'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_accent'))
              .maxLines(1);
            Text($r('app.string.remote_session_header_submitted_fps', this.metrics.fps))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1);
            Text($r('app.string.remote_session_header_rtt_ms', this.metrics.delay))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(1);
            this.ToolbarUtilityActions()
            if (this.activeOverlayPanel === 'home' && this.toolbarWidth >= 680) {
              SessionInputControls({
                inputEnabled: this.inputEnabled,
                touchMode: this.touchMode,
                relativeMouseMode: this.relativeMouseMode,
                relativeModeSupported: this.relativeModeSupported,
                rightClickGesture: this.rightClickGesture,
                wideLayout: true,
                onSelectMode: (mode: RustDeskInputMode): void => this.onSelectInputMode(mode),
                onSelectRightClick: (gesture: RustDeskRightClickGesture): void =>
                  this.onSelectRightClick(gesture),
              });
            }
          }
          // At least the viewport, and as wide as the group needs: the header
          // ends at the toolbar's right edge in every panel state, and a row
          // wider than the toolbar stays reachable by scrolling instead of
          // being clipped away.
          .constraintSize({ minWidth: '100%' })
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.End)
          .onAreaChange((_oldArea: Area, newArea: Area): void => {
            this.measureHeaderContentWidth(Number(newArea.width));
          });
        }
        .layoutWeight(1)
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onAreaChange((_oldArea: Area, newArea: Area): void => {
          this.measureHeaderViewportWidth(Number(newArea.width));
        });

        this.ToolbarDragGrip();
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        this.measureToolbarHeader(Number(newArea.height));
      });

      if (this.activeOverlayPanel === 'home') {
        // The home block gets the same budget as a panel body and scrolls past
        // it, so a short viewport shortens the block instead of pushing the
        // session tab bar and the disconnect action off the pane.
        Scroll() {
          Column({ space: $r('app.float.space_8') }) {
            if (this.toolbarWidth < 680) {
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
            }
            this.FunctionHome();
            if (!this.audioAvailable && this.audioUnavailableText !== '') {
              Text(this.audioUnavailableText)
                .width('100%')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.neu_text_secondary'));
            }
            if (this.directSession) {
              Text($r('app.string.direct_toolbar_capabilities'))
                .width('100%')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.neu_text_secondary'));
              if (this.keyboardUnavailableText !== '') {
                Text(this.keyboardUnavailableText)
                  .width('100%')
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.neu_text_secondary'));
              }
              if (this.windowUnavailableText !== '') {
                Text(this.windowUnavailableText)
                  .width('100%')
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.neu_text_secondary'));
              }
              if (this.statusMessage.length > 0) {
                Text(this.statusMessage)
                  .width('100%')
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.neu_text_secondary'));
              }
            }

            if (this.androidNavigationAvailable) {
              Row() {
                this.AndroidNavigationAction();
              }
              .width('100%')
              .justifyContent(FlexAlign.End);
            }
          }
          .width('100%');
        }
        .width('100%')
        .constraintSize({ maxHeight: this.panelContentHeight })
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off);
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

      if (this.tabs.length > 0) {
        this.SessionTabsBar();
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
