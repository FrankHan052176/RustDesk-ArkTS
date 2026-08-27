import { SessionOverlayPanel } from '../SessionOverlayState';
import { SessionToolbarMetrics } from '../SessionToolbarMetrics';

const SOFT_KEYBOARD_TRANSITION_ID = 'rustdesk-session-soft-keyboard';
const SYSTEM_IME_TRANSITION_ID = 'rustdesk-session-system-ime';

interface ToolbarActionOptions {
  label: string;
  active: boolean;
  transitionId: string;
  onClick: () => void;
}

export interface SessionToolbarProps {
  touchMode: boolean;
  relativeMouseMode: boolean;
  relativeMouseModeSupported: boolean;
  metrics: SessionToolbarMetrics;
  activeOverlayPanel: SessionOverlayPanel;
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
  windowFullscreen: boolean;
  windowControlBusy: boolean;
  onTogglePointerMode: () => void;
  onResetTransform: () => void;
  onOpenChat: () => void;
  onOpenDisplay: () => void;
  onOpenQuality: () => void;
  onToggleSoftKeyboard: () => void;
  onToggleSystemIme: () => void;
  onToggleAndroidNavigation: () => void;
  onAudioChange: (enabled: boolean) => void;
  onDisconnect: () => void;
  onCollapse: () => void;
  onMinimizeWindow: () => void;
  onToggleWindowFullscreen: () => void;
  content: () => void;
}

@ComponentV2
export struct SessionToolbar {
  @Param touchMode: boolean = true;
  @Local displayedTouchMode: boolean = true;
  @Param relativeMouseMode: boolean = false;
  @Local displayedRelativeMouseMode: boolean = false;
  @Param relativeMouseModeSupported: boolean = false;
  @Param metrics: SessionToolbarMetrics = {
    fps: '--',
    frames: '--',
    decode: '--',
    delay: '--',
    codec: '--',
  };
  @Param activeOverlayPanel: SessionOverlayPanel = 'home';
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
  @Param windowFullscreen: boolean = false;
  @Param windowControlBusy: boolean = false;
  @Event onTogglePointerMode: () => void = () => {};
  @Event onResetTransform: () => void = () => {};
  @Event onOpenChat: () => void = () => {};
  @Event onOpenDisplay: () => void = () => {};
  @Event onOpenQuality: () => void = () => {};
  @Event onToggleSoftKeyboard: () => void = () => {};
  @Event onToggleSystemIme: () => void = () => {};
  @Event onToggleAndroidNavigation: () => void = () => {};
  @Event onAudioChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  @Event onDisconnect: () => void = () => {};
  @Event onCollapse: () => void = () => {};
  @Event onMinimizeWindow: () => void = () => {};
  @Event onToggleWindowFullscreen: () => void = () => {};

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

  @Builder
  private Empty() {}

  private actionHeight(): number {
    return this.wideLayout ? 46 : 42;
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
        .fontColor(options.active ? $r('app.color.white') : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
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
    .hoverEffect(HoverEffect.None)
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
      Text(this.pointerModeLabel())
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
    .backgroundColor($r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.None)
    .accessibilityText(`控制模式：${this.pointerModeLabel()}`)
    .transition(TransitionEffect.OPACITY)
    .onClick((): void => {
      if (this.displayedTouchMode) {
        this.displayedTouchMode = false;
        this.displayedRelativeMouseMode = false;
      } else if (!this.displayedRelativeMouseMode && this.relativeMouseModeSupported) {
        this.displayedRelativeMouseMode = true;
      } else {
        this.displayedTouchMode = true;
        this.displayedRelativeMouseMode = false;
      }
      this.onTogglePointerMode();
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
    .layoutWeight(1)
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
      Text(this.displayedAndroidNavigationVisible ? '隐藏导航' : '显示导航')
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
    .hoverEffect(HoverEffect.None)
    .accessibilityText(this.displayedAndroidNavigationVisible ? '隐藏导航' : '显示导航')
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
    .hoverEffect(HoverEffect.None)
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
    .layoutWeight(1)
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
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label)
    .onClick((): void => {
      this.onDisconnect();
    });
  }

  @Builder
  private WindowControlAction(
    label: string,
    selected: boolean,
    textColor: ResourceColor,
    onClick: () => void,
  ) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.windowControlBusy
          ? $r('app.color.neu_text_disabled')
          : textColor)
        .maxLines(1);
    }
    .layoutWeight(1)
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
    .enabled(!this.windowControlBusy)
    .backgroundColor(selected ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: selected ? $r('app.color.brand_primary') : $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label)
    .accessibilitySelected(selected)
    .onClick((): void => {
      if (!this.windowControlBusy) {
        onClick();
      }
    });
  }

  @Builder
  private WindowControlActions() {
    this.WindowControlAction(
      this.windowFullscreen ? '还原窗口' : '全屏',
      this.windowFullscreen,
      $r('app.color.success'),
      () => this.onToggleWindowFullscreen(),
    )
    this.WindowControlAction('最小化', false, $r('app.color.warning'), () => this.onMinimizeWindow())
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
        this.CompactAction('reset-transform', '还原', false, false, true, () => this.onResetTransform())
      }
    }
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private ToolbarUtilityActions() {
    Row({ space: $r('app.float.space_6') }) {
      this.TransformControls()
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
      .layoutWeight(1)
      .clip(true);

      this.CompactAction('collapse', '收起', false, false, true, () => this.onCollapse())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private FunctionHome() {
    if (this.cameraSession) {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.ToolbarAction({
            label: '画质',
            active: this.activeOverlayPanel === 'quality',
            transitionId: this.qualityTransitionId,
            onClick: () => this.onOpenQuality(),
          })
          this.DangerAction('断开连接')
        }
        .width('100%');

        if (this.windowControlsAvailable) {
          Row({ space: $r('app.float.space_8') }) {
            this.WindowControlActions();
          }
          .width('100%')
          .justifyContent(FlexAlign.End);
        }
      }
      .width('100%');
    } else if (this.viewOnlySession) {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.ToolbarAction({
            label: '显示器',
            active: this.activeOverlayPanel === 'display',
            transitionId: this.displayTransitionId,
            onClick: () => this.onOpenDisplay(),
          })
          this.ToolbarAction({
            label: '画质',
            active: this.activeOverlayPanel === 'quality',
            transitionId: this.qualityTransitionId,
            onClick: () => this.onOpenQuality(),
          })
          this.DangerAction('断开')
        }
        .width('100%');

        if (this.windowControlsAvailable) {
          Row({ space: $r('app.float.space_8') }) {
            this.WindowControlActions();
          }
          .width('100%')
          .justifyContent(FlexAlign.End);
        }
      }
      .width('100%');
    } else if (this.wideLayout) {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.PointerModeAction()
          if (this.systemImeAvailable) {
            this.ToolbarAction({
              label: '输入法',
              active: this.systemImeActive,
              transitionId: SYSTEM_IME_TRANSITION_ID,
              onClick: () => this.onToggleSystemIme(),
            })
          }
          if (this.softKeyboardAvailable) {
            this.ToolbarAction({
              label: '虚拟键盘',
              active: this.softKeyboardVisible,
              transitionId: SOFT_KEYBOARD_TRANSITION_ID,
              onClick: () => this.onToggleSoftKeyboard(),
            })
          }
          this.ToolbarAction({
            label: this.unreadCount > 0 ? `聊天 ${this.unreadCount}` : '聊天',
            active: this.activeOverlayPanel === 'chat',
            transitionId: this.chatTransitionId,
            onClick: () => this.onOpenChat(),
          })
          this.AudioToggle()
        }
        .width('100%');

        Row({ space: $r('app.float.space_8') }) {
          this.ToolbarAction({
            label: '显示器',
            active: this.activeOverlayPanel === 'display',
            transitionId: this.displayTransitionId,
            onClick: () => this.onOpenDisplay(),
          })
          this.ToolbarAction({
            label: '画质',
            active: this.activeOverlayPanel === 'quality',
            transitionId: this.qualityTransitionId,
            onClick: () => this.onOpenQuality(),
          })
          if (this.windowControlsAvailable) {
            this.WindowControlActions()
          }
          this.DangerAction('断开')
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
      .width('100%');
    } else {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.PointerModeAction()
          if (this.systemImeAvailable) {
            this.ToolbarAction({
              label: '输入法',
              active: this.systemImeActive,
              transitionId: SYSTEM_IME_TRANSITION_ID,
              onClick: () => this.onToggleSystemIme(),
            })
          }
          if (this.softKeyboardAvailable) {
            this.ToolbarAction({
              label: '虚拟键盘',
              active: this.softKeyboardVisible,
              transitionId: SOFT_KEYBOARD_TRANSITION_ID,
              onClick: () => this.onToggleSoftKeyboard(),
            })
          }
          this.ToolbarAction({
            label: this.unreadCount > 0 ? `聊天 ${this.unreadCount}` : '聊天',
            active: this.activeOverlayPanel === 'chat',
            transitionId: this.chatTransitionId,
            onClick: () => this.onOpenChat(),
          })
        }
        .width('100%');

        Row({ space: $r('app.float.space_8') }) {
          this.ToolbarAction({
            label: '显示器',
            active: this.activeOverlayPanel === 'display',
            transitionId: this.displayTransitionId,
            onClick: () => this.onOpenDisplay(),
          })
          this.ToolbarAction({
            label: '画质',
            active: this.activeOverlayPanel === 'quality',
            transitionId: this.qualityTransitionId,
            onClick: () => this.onOpenQuality(),
          })
        }
        .width('100%');

        Row({ space: $r('app.float.space_8') }) {
          this.AudioToggle()
          this.DangerAction('断开连接')
        }
        .width('100%');

        if (this.windowControlsAvailable) {
          Row({ space: $r('app.float.space_8') }) {
            this.WindowControlActions();
          }
          .width('100%')
          .justifyContent(FlexAlign.End);
        }
      }
      .width('100%');
    }
  }

  build(): void {
    Column({ space: $r('app.float.space_8') }) {
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
        if (this.wideLayout) {
          this.ToolbarUtilityActions()
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (!this.wideLayout) {
        Row() {
          this.NarrowToolbarUtilityActions();
        }
        .width('100%')
        .justifyContent(FlexAlign.End);

      }

      if (this.windowControlsAvailable && this.activeOverlayPanel !== 'home') {
        Row({ space: $r('app.float.space_8') }) {
          this.WindowControlActions();
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
    .clip(false);
  }
}
