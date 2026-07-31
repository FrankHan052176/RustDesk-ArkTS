import { SessionOverlayPanel } from '../SessionOverlayState';
import { SessionToolbarMetrics } from '../SessionToolbarMetrics';

const SOFT_KEYBOARD_TRANSITION_ID = 'rustdesk-session-soft-keyboard';

export interface SessionToolbarProps {
  relativeMouseMode: boolean;
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
  audioAvailable: boolean;
  audioMuted: boolean;
  wideLayout: boolean;
  transformSummary: string;
  transformMode: boolean;
  canResetTransform: boolean;
  panelContentHeight: number;
  onTogglePointerMode: () => void;
  onToggleTransform: () => void;
  onResetTransform: () => void;
  onOpenChat: () => void;
  onOpenDisplay: () => void;
  onOpenQuality: () => void;
  onToggleSoftKeyboard: () => void;
  onToggleAndroidNavigation: () => void;
  onAudioChange: (enabled: boolean) => void;
  onDisconnect: () => void;
  onMinimize: () => void;
  content: () => void;
}

@ComponentV2
export struct SessionToolbar {
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
  @Param chatTransitionId: string = '';
  @Param displayTransitionId: string = '';
  @Param qualityTransitionId: string = '';
  @Param unreadCount: number = 0;
  @Param cameraSession: boolean = false;
  @Param viewOnlySession: boolean = false;
  @Param androidNavigationAvailable: boolean = false;
  @Param androidNavigationVisible: boolean = false;
  @Param softKeyboardAvailable: boolean = false;
  @Param softKeyboardVisible: boolean = false;
  @Param audioAvailable: boolean = false;
  @Param audioMuted: boolean = false;
  @Param wideLayout: boolean = false;
  @Param transformSummary: string = '100%';
  @Param transformMode: boolean = false;
  @Local displayedTransformMode: boolean = false;
  @Param canResetTransform: boolean = false;
  @Param panelContentHeight: number = 360;
  @Event onTogglePointerMode: () => void = () => {};
  @Event onToggleTransform: () => void = () => {};
  @Event onResetTransform: () => void = () => {};
  @Event onOpenChat: () => void = () => {};
  @Event onOpenDisplay: () => void = () => {};
  @Event onOpenQuality: () => void = () => {};
  @Event onToggleSoftKeyboard: () => void = () => {};
  @Event onToggleAndroidNavigation: () => void = () => {};
  @Event onAudioChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  @Event onDisconnect: () => void = () => {};
  @Event onMinimize: () => void = () => {};

  @BuilderParam content: () => void = this.Empty;

  aboutToAppear(): void {
    this.displayedRelativeMouseMode = this.relativeMouseMode;
    this.displayedTransformMode = this.transformMode;
  }

  @Monitor('relativeMouseMode')
  private onRelativeMouseModeChanged(_monitor: IMonitor): void {
    this.displayedRelativeMouseMode = this.relativeMouseMode;
  }

  @Monitor('transformMode')
  private onTransformModeChanged(_monitor: IMonitor): void {
    this.displayedTransformMode = this.transformMode;
  }

  @Builder
  private Empty() {}

  private actionHeight(): number {
    return this.wideLayout ? 46 : 42;
  }

  @Builder
  private ToolbarAction(
    _key: string,
    label: string,
    active: boolean,
    transitionId: string,
    onClick: () => void,
  ) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? $r('app.color.white') : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
    .backgroundColor(active ? $r('app.color.brand_primary') : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: active ? $r('app.color.brand_primary') : $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label)
    .geometryTransition(transitionId)
    .transition(TransitionEffect.OPACITY)
    .onClick((): void => {
      onClick();
    });
  }

  @Builder
  private PointerModeAction() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(this.displayedRelativeMouseMode ? '触摸板' : '模拟鼠标')
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.displayedRelativeMouseMode
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .layoutWeight(1)
    .height(this.actionHeight())
    .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_8') })
    .backgroundColor(this.displayedRelativeMouseMode
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: this.displayedRelativeMouseMode
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.None)
    .accessibilityText(this.displayedRelativeMouseMode ? '触摸板' : '模拟鼠标')
    .accessibilitySelected(this.displayedRelativeMouseMode)
    .transition(TransitionEffect.OPACITY)
    .onClick((): void => {
      this.displayedRelativeMouseMode = !this.displayedRelativeMouseMode;
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
    .width(key === 'transform' ? 92 : 68)
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
  private TransformControls() {
    Row({ space: $r('app.float.space_6') }) {
      if (this.wideLayout) {
        Text(this.transformSummary)
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_text_secondary'))
          .maxLines(1);
      }

      this.TransformModeAction()

      if (this.canResetTransform) {
        this.CompactAction('reset-transform', '还原', false, false, true, () => this.onResetTransform())
      }
    }
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private TransformModeAction() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(this.displayedTransformMode ? '完成' : '调整画面')
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.displayedTransformMode
          ? $r('app.color.white')
          : $r('app.color.neu_text_primary'));
    }
    .width(92)
    .height($r('app.float.control_compact'))
    .padding({ left: $r('app.float.space_6'), right: $r('app.float.space_6') })
    .backgroundColor(this.displayedTransformMode
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: this.displayedTransformMode
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_10'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.None)
    .accessibilityText(this.displayedTransformMode ? '完成画面调整' : '调整画面')
    .accessibilitySelected(this.displayedTransformMode)
    .onClick((): void => {
      this.displayedTransformMode = !this.displayedTransformMode;
      this.onToggleTransform();
    });
  }

  @Builder
  private ToolbarUtilityActions() {
    Row({ space: $r('app.float.space_6') }) {
      this.TransformControls()
      this.CompactAction('collapse', '收起', false, false, true, () => this.onMinimize())
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

      this.CompactAction('collapse', '收起', false, false, true, () => this.onMinimize())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private FunctionHome() {
    if (this.cameraSession) {
      Row({ space: $r('app.float.space_8') }) {
        this.ToolbarAction('quality', '画质', this.activeOverlayPanel === 'quality', this.qualityTransitionId,
          () => this.onOpenQuality())
        this.DangerAction('断开连接')
      }
      .width('100%');
    } else if (this.viewOnlySession) {
      Row({ space: $r('app.float.space_8') }) {
        this.ToolbarAction('display', '显示器', this.activeOverlayPanel === 'display', this.displayTransitionId,
          () => this.onOpenDisplay())
        this.ToolbarAction('quality', '画质', this.activeOverlayPanel === 'quality', this.qualityTransitionId,
          () => this.onOpenQuality())
        this.DangerAction('断开')
      }
      .width('100%');
    } else if (this.wideLayout) {
      Row({ space: $r('app.float.space_8') }) {
        this.PointerModeAction()
        if (this.softKeyboardAvailable) {
          this.ToolbarAction('keyboard', this.softKeyboardVisible ? '键盘开' : '键盘', this.softKeyboardVisible, SOFT_KEYBOARD_TRANSITION_ID,
            () => this.onToggleSoftKeyboard())
        }
        this.ToolbarAction('chat', this.unreadCount > 0 ? `聊天 ${this.unreadCount}` : '聊天',
          this.activeOverlayPanel === 'chat', this.chatTransitionId, () => this.onOpenChat())
        this.ToolbarAction('display', '显示器', this.activeOverlayPanel === 'display', this.displayTransitionId,
          () => this.onOpenDisplay())
        this.ToolbarAction('quality', '画质', this.activeOverlayPanel === 'quality', this.qualityTransitionId,
          () => this.onOpenQuality())
        this.AudioToggle()
        this.DangerAction('断开')
      }
      .width('100%');
    } else {
      Column({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_8') }) {
          this.PointerModeAction()
          if (this.softKeyboardAvailable) {
            this.ToolbarAction('keyboard', this.softKeyboardVisible ? '键盘开' : '键盘', this.softKeyboardVisible, SOFT_KEYBOARD_TRANSITION_ID,
              () => this.onToggleSoftKeyboard())
          }
          this.ToolbarAction('chat', this.unreadCount > 0 ? `聊天 ${this.unreadCount}` : '聊天',
            this.activeOverlayPanel === 'chat', this.chatTransitionId, () => this.onOpenChat())
        }
        .width('100%');

        Row({ space: $r('app.float.space_8') }) {
          this.ToolbarAction('display', '显示器', this.activeOverlayPanel === 'display', this.displayTransitionId,
            () => this.onOpenDisplay())
          this.ToolbarAction('quality', '画质', this.activeOverlayPanel === 'quality', this.qualityTransitionId,
            () => this.onOpenQuality())
        }
        .width('100%');

        Row({ space: $r('app.float.space_8') }) {
          this.AudioToggle()
          this.DangerAction('断开连接')
        }
        .width('100%');
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

      if (this.activeOverlayPanel === 'home') {
        Column({ space: $r('app.float.space_8') }) {
          this.FunctionHome();

          if (this.androidNavigationAvailable) {
            Row() {
              this.CompactAction(
                'android-navigation',
                this.androidNavigationVisible ? '隐藏导航' : '显示导航',
                this.androidNavigationVisible,
                false,
                true,
                () => this.onToggleAndroidNavigation(),
              )
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
