import { RemoteAudioState } from '../RustDeskSessionTypes';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { FloatingDepthOverlay, FloatingPressDepthShell } from './FloatingDepth';

export interface RemoteMediaPanelProps {
  state: RemoteAudioState;
  onToggleMuted: () => void;
  onClose: () => void;
}

@ComponentV2
export struct RemoteMediaPanel {
  @Param state: RemoteAudioState = {
    available: false,
    muted: false,
    rendererActive: false,
    errorText: '',
  };
  @Local audioPressed: boolean = false;
  @Local closePressed: boolean = false;
  @Event onToggleMuted: () => void = () => {};
  @Event onClose: () => void = () => {};

  private statusText(): string {
    if (this.state.errorText.length > 0) {
      return this.state.errorText;
    }
    if (this.state.muted) {
      return '远端音频已静音';
    }
    if (this.state.rendererActive) {
      return '正在播放远端音频';
    }
    return '远端音频已就绪';
  }

  private animateAudioBlur(active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      this.audioPressed = active;
    });
  }

  private animateCloseBlur(active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      this.closePressed = active;
    });
  }

  build() {
    Column({ space: $r('app.float.space_16') }) {
      Text(this.statusText())
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.state.errorText.length > 0 ? $r('app.color.error') : $r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Text('静音将在当前缓冲播放完后生效')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'));

      Stack() {
        if (this.state.available && !this.state.muted) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.brand_primary_soft'))
            .opacity(0.56);
        }

        FloatingDepthOverlay({
          radius: $r('app.float.radius_14'),
        });

        Row({ space: $r('app.float.space_12') }) {
          Column({ space: $r('app.float.space_2') }) {
            Text('远端音频')
              .fontSize($r('app.float.font_body'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.state.available ? $r('app.color.text_primary') : $r('app.color.disabled_text'));
            Text(this.state.muted ? '已关闭' : '已开启')
              .fontSize($r('app.float.font_caption'))
              .fontColor(this.state.available ? $r('app.color.text_secondary') : $r('app.color.disabled_text'));
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          Toggle({ type: ToggleType.Switch, isOn: this.state.available && !this.state.muted })
            .enabled(this.state.available)
            .selectedColor($r('app.color.brand_primary'))
            .switchPointColor($r('app.color.white'))
            .onTouch((event: TouchEvent) => {
              if (!this.state.available) {
                return;
              }
              if (event.type === TouchType.Down) {
                this.animateAudioBlur(true);
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.animateAudioBlur(false);
              }
            })
            .onChange((_enabled: boolean) => this.onToggleMuted());
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_8') })
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.audioPressed,
          $r('app.color.point_light'),
          0.42,
        ));
      }
      .width('100%')
      .height($r('app.float.control_large'))
      .backgroundColor($r('app.color.glass_surface'))
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: this.audioPressed ? 0.90 : 0.48,
      })
      .linearGradient({
        angle: 142,
        colors: [
          [$r('app.color.glass_gradient_high'), 0],
          [$r('app.color.glass_gradient_mid'), 0.48],
          [$r('app.color.glass_gradient_accent'), 1],
        ],
      })
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      .visualEffect(RustDeskGlassEffect.featherReceiver())
      .opacity(this.state.available ? 1 : 0.72);

      Stack() {
        FloatingPressDepthShell({
          pressed: this.closePressed,
          compact: true,
          radius: $r('app.float.radius_14'),
        }) {
          Button({ type: ButtonType.Normal, stateEffect: false }) {
            Stack() {
              FloatingDepthOverlay({
                pressed: this.closePressed,
                compact: true,
                radius: $r('app.float.radius_14'),
              });

              Row() {
                Text('关闭')
                  .fontSize($r('app.float.font_body'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'));
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius($r('app.float.radius_14'))
              .clip(true)
              .visualEffect(RustDeskGlassEffect.interactiveContent(
                this.closePressed,
                $r('app.color.point_light'),
                0.52,
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
            scale: this.closePressed ? 0.18 : 0.48,
          })
          .linearGradient({
            angle: 142,
            colors: [
              [$r('app.color.glass_gradient_high'), 0],
              [$r('app.color.glass_gradient_mid'), 0.48],
              [$r('app.color.glass_gradient_accent'), 1],
            ],
          })
          .borderRadius($r('app.float.radius_14'))
          .clip(true)
          .visualEffect(RustDeskGlassEffect.featherReceiver())
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.animateCloseBlur(true);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.animateCloseBlur(false);
            }
          })
          .onClick(() => this.onClose());
        }
      }
      .width('100%')
      .height($r('app.float.control_small'))
      .borderRadius($r('app.float.radius_14'))
      .clip(false);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }
}
