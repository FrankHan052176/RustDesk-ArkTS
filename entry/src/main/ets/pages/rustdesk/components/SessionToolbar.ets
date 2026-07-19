import { SessionOverlayPanel } from '../SessionOverlayState';
import { SessionToolbarMetrics } from '../SessionToolbarMetrics';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { FloatingDepthOverlay, FloatingPressDepthShell } from './FloatingDepth';

export interface SessionToolbarProps {
  relativeMouseMode: boolean;
  metrics: SessionToolbarMetrics;
  activeOverlayPanel: SessionOverlayPanel;
  chatTransitionId: string;
  displayTransitionId: string;
  qualityTransitionId: string;
  unreadCount: number;
  cameraSession: boolean;
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
  onAudioChange: (enabled: boolean) => void;
  onDisconnect: () => void;
  onMinimize: () => void;
  content: () => void;
}

@ComponentV2
export struct SessionToolbar {
  @Param relativeMouseMode: boolean = false;
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
  @Param audioAvailable: boolean = false;
  @Param audioMuted: boolean = false;
  @Param wideLayout: boolean = false;
  @Param transformSummary: string = '100%';
  @Param transformMode: boolean = false;
  @Param canResetTransform: boolean = false;
  @Param panelContentHeight: number = 360;
  @Local pressedControl: string = '';
  @Local adjustingControl: string = '';
  @Event onTogglePointerMode: () => void = () => {};
  @Event onToggleTransform: () => void = () => {};
  @Event onResetTransform: () => void = () => {};
  @Event onOpenChat: () => void = () => {};
  @Event onOpenDisplay: () => void = () => {};
  @Event onOpenQuality: () => void = () => {};
  @Event onAudioChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  @Event onDisconnect: () => void = () => {};
  @Event onMinimize: () => void = () => {};

  @BuilderParam content: () => void = this.Empty;

  @Builder
  private Empty() {}

  private animateClickBlur(key: string, active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      if (active) {
        this.pressedControl = key;
      } else if (this.pressedControl === key) {
        this.pressedControl = '';
      }
    });
  }

  private animateAdjustmentBlur(key: string, active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      if (active) {
        this.adjustingControl = key;
      } else if (this.adjustingControl === key) {
        this.adjustingControl = '';
      }
    });
  }

  private controlLightIntensity(key: string, selected: boolean, adjustment: boolean): number {
    const active = adjustment ? this.adjustingControl === key : this.pressedControl === key;
    if (active) {
      return 0.62;
    }
    return selected ? 0.14 : 0;
  }

  @Builder
  private ToolbarAction(
    key: string,
    label: string,
    active: boolean,
    transitionId: string,
    onClick: () => void,
  ) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        if (active) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.brand_primary'));
        }

        FloatingDepthOverlay({
          compact: true,
          radius: $r('app.float.radius_14'),
        });

        Row() {
          Text(label)
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor(active ? $r('app.color.white') : $r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.controlLightIntensity(key, active, true) > 0,
          $r('app.color.point_light'),
          this.controlLightIntensity(key, active, true),
        ));
      }
      .width('100%')
      .height('100%')
      .borderRadius($r('app.float.radius_14'))
      .clip(true);
    }
    .layoutWeight(1)
    .height(this.wideLayout ? 46 : 42)
    .padding(0)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.adjustingControl === key ? 0.90 : 0.48,
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .geometryTransition(transitionId)
    .transition(TransitionEffect.OPACITY)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateAdjustmentBlur(key, true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateAdjustmentBlur(key, false);
      }
    })
    .onClick(onClick);
  }

  @Builder
  private PointerModeAction() {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        if (this.relativeMouseMode) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.brand_primary'));
        }

        FloatingDepthOverlay({
          compact: true,
          radius: $r('app.float.radius_14'),
        });

        Row() {
          Text(this.relativeMouseMode ? '触摸板' : '模拟鼠标')
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.relativeMouseMode ? $r('app.color.white') : $r('app.color.text_primary'))
            .maxLines(1);
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.controlLightIntensity('pointer', this.relativeMouseMode, true) > 0,
          $r('app.color.point_light'),
          this.controlLightIntensity('pointer', this.relativeMouseMode, true),
        ));
      }
      .width('100%')
      .height('100%')
      .borderRadius($r('app.float.radius_14'))
      .clip(true);
    }
    .layoutWeight(1)
    .height(this.wideLayout ? 46 : 42)
    .padding(0)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.adjustingControl === 'pointer' ? 0.90 : 0.48,
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateAdjustmentBlur('pointer', true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateAdjustmentBlur('pointer', false);
      }
    })
    .onClick(() => this.onTogglePointerMode());
  }

  @Builder
  private AudioToggle() {
    Stack() {
      if (this.audioAvailable && !this.audioMuted) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.brand_primary_soft'))
          .opacity(0.52);
      }

      FloatingDepthOverlay({
        compact: true,
        radius: $r('app.float.radius_14'),
      });

      Row({ space: $r('app.float.space_8') }) {
        Text(this.audioAvailable ? '音频' : '准备中')
          .layoutWeight(1)
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.audioAvailable ? $r('app.color.text_primary') : $r('app.color.disabled_text'));

        Toggle({
          type: ToggleType.Switch,
          isOn: this.audioAvailable && !this.audioMuted,
        })
          .enabled(this.audioAvailable)
          .selectedColor($r('app.color.brand_primary'))
          .switchPointColor($r('app.color.white'))
          .onTouch((event: TouchEvent) => {
            if (!this.audioAvailable) {
              return;
            }
            if (event.type === TouchType.Down) {
              this.animateAdjustmentBlur('audio', true);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.animateAdjustmentBlur('audio', false);
            }
          })
          .onChange((enabled: boolean) => this.onAudioChange(enabled));
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_8') })
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.interactiveContent(
        this.controlLightIntensity('audio', this.audioAvailable && !this.audioMuted, true) > 0,
        $r('app.color.point_light'),
        this.controlLightIntensity('audio', this.audioAvailable && !this.audioMuted, true),
      ));
    }
    .layoutWeight(1)
    .height(this.wideLayout ? 46 : 42)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.adjustingControl === 'audio' ? 0.90 : 0.48,
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .opacity(this.audioAvailable ? 1 : 0.72);
  }

  @Builder
  private CompactAction(
    key: string,
    label: string,
    selected: boolean,
    adjustment: boolean,
    enabled: boolean,
    onClick: () => void,
  ) {
    Stack() {
      FloatingPressDepthShell({
        pressed: enabled && !adjustment && this.pressedControl === key,
        compact: true,
        radius: $r('app.float.radius_10'),
      }) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack() {
            if (selected) {
              Row()
                .width('100%')
                .height('100%')
                .backgroundColor($r('app.color.brand_primary'));
            }

            FloatingDepthOverlay({
              pressed: enabled && !adjustment && this.pressedControl === key,
              compact: true,
              radius: $r('app.float.radius_10'),
            });

            Row() {
              Text(label)
                .fontSize($r('app.float.font_caption'))
                .fontWeight(FontWeight.Medium)
                .fontColor(enabled
                  ? (selected ? $r('app.color.white') : $r('app.color.text_primary'))
                  : $r('app.color.disabled_text'));
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .borderRadius($r('app.float.radius_10'))
            .clip(true)
            .visualEffect(RustDeskGlassEffect.interactiveContent(
              this.controlLightIntensity(key, selected, adjustment) > 0,
              $r('app.color.point_light'),
              this.controlLightIntensity(key, selected, adjustment),
            ));
          }
          .width('100%')
          .height('100%')
          .borderRadius($r('app.float.radius_10'))
          .clip(true);
        }
        .width('100%')
        .height('100%')
        .padding(0)
        .enabled(enabled)
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: adjustment
            ? (this.adjustingControl === key ? 0.90 : 0.48)
            : (this.pressedControl === key ? 0.18 : 0.48),
        })
        .borderRadius($r('app.float.radius_10'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.featherReceiver())
        .onTouch((event: TouchEvent) => {
          if (!enabled) {
            return;
          }
          if (event.type === TouchType.Down) {
            if (adjustment) {
              this.animateAdjustmentBlur(key, true);
            } else {
              this.animateClickBlur(key, true);
            }
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            if (adjustment) {
              this.animateAdjustmentBlur(key, false);
            } else {
              this.animateClickBlur(key, false);
            }
          }
        })
        .onClick(onClick);
      }
    }
    .width(key === 'transform' ? 92 : 68)
    .height($r('app.float.control_compact'))
    .borderRadius($r('app.float.radius_10'))
    .clip(false);
  }

  @Builder
  private DangerAction(label: string) {
    Stack() {
      FloatingPressDepthShell({
        pressed: this.pressedControl === 'disconnect',
        compact: true,
        radius: $r('app.float.radius_14'),
      }) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack() {
            Row()
              .width('100%')
              .height('100%')
              .backgroundColor($r('app.color.error'));

            FloatingDepthOverlay({
              pressed: this.pressedControl === 'disconnect',
              compact: true,
              radius: $r('app.float.radius_14'),
            });

            Row() {
              Text(label)
                .fontSize($r('app.float.font_label'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.white'))
                .maxLines(1);
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .borderRadius($r('app.float.radius_14'))
            .clip(true)
            .visualEffect(RustDeskGlassEffect.interactiveContent(
              this.pressedControl === 'disconnect',
              $r('app.color.error'),
              0.66,
            ));
          }
          .width('100%')
          .height('100%')
          .borderRadius($r('app.float.radius_14'))
          .clip(true);
        }
        .width('100%')
        .height('100%')
        .padding(0)
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: this.pressedControl === 'disconnect' ? 0.18 : 0.48,
        })
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.featherReceiver())
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.animateClickBlur('disconnect', true);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.animateClickBlur('disconnect', false);
          }
        })
        .onClick(() => this.onDisconnect());
      }
    }
    .layoutWeight(1)
    .height(this.wideLayout ? 46 : 42)
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private TransformControls() {
    Row({ space: $r('app.float.space_6') }) {
      Text(this.transformSummary)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1);

      this.CompactAction('transform', this.transformMode ? '完成' : '调整画面', this.transformMode, true, true,
        () => this.onToggleTransform())

      if (this.canResetTransform) {
        this.CompactAction('reset-transform', '还原', false, false, true, () => this.onResetTransform())
      }
    }
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
    } else if (this.wideLayout) {
      Row({ space: $r('app.float.space_8') }) {
        this.PointerModeAction()
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

  build() {
    Column({ space: $r('app.float.space_8') }) {
      Row({ space: $r('app.float.space_8') }) {
        Text(`${this.metrics.codec}`)
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_primary'))
          .maxLines(1);
        Text(`${this.metrics.fps} FPS`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1);
        Text(`${this.metrics.delay} ms`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1);
        if (this.wideLayout) {
          Text(`解码 ${this.metrics.decode}`)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1);
          Text(`帧 ${this.metrics.frames}`)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1);
          this.TransformControls();
        }
        Blank()
        this.CompactAction('collapse', '收起', false, false, true, () => this.onMinimize())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (!this.wideLayout) {
        Row() {
          this.TransformControls();
        }
        .width('100%')
        .justifyContent(FlexAlign.End);
      }

      if (this.activeOverlayPanel === 'home') {
        Stack() {
          this.FunctionHome();
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
