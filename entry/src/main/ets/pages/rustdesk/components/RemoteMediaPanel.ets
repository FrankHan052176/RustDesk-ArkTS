import { LuminousSwitch } from 'luminous_neo';
import { RemoteAudioState } from '../RustDeskSessionTypes';
import { FloatingActionSurface, FloatingGlassSurface } from './FloatingSurface';

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
  @Local viewportWidth: number = 320;
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
      Stack() {
        FloatingGlassSurface() {
          Column({ space: $r('app.float.space_12') }) {
            Text(this.statusText())
              .width('100%')
              .fontSize($r('app.float.font_body_large'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.state.errorText.length > 0
                ? $r('app.color.error')
                : $r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            Text('静音将在当前缓冲播放完后生效')
              .width('100%')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_secondary'));

            LuminousSwitch({
              label: '远端音频',
              description: this.state.muted ? '已关闭' : '已开启',
              isOn: this.state.available && !this.state.muted,
              rowWidth: Math.max(260, this.viewportWidth - 32),
              isEnabled: this.state.available,
              motionEnabled: true,
              onChange: (_enabled: boolean): void => {
                this.onToggleMuted();
              },
            })
          }
          .width('100%')
          .padding($r('app.float.space_16'))
          .alignItems(HorizontalAlign.Start);
        }
      }
      .width('100%')
      .borderRadius($r('app.float.radius_14'))
      .clip(false)
      .opacity(this.state.available ? 1 : 0.72);

      Stack() {
        FloatingActionSurface({
          compact: true,
          onActivate: () => this.onClose(),
        }) {
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
          .clip(true);
        }
      }
      .width('100%')
      .height($r('app.float.control_small'))
      .borderRadius($r('app.float.radius_14'))
      .clip(false);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      let width: number = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
