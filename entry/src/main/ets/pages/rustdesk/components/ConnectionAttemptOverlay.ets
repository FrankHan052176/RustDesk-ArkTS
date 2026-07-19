import { FloatingDepthOverlay } from './FloatingDepth';
import { FloatingActionSurface } from './FloatingSurface';

export interface ConnectionAttemptOverlayProps {
  visible: boolean;
  phase: string;
  target: string;
  message: string;
  bottomAvoidInset: number;
  onCancel: () => void;
  onRetry: () => void;
  onDismiss: () => void;
}

@ComponentV2
export struct ConnectionAttemptOverlay {
  @Param visible: boolean = false;
  @Param phase: string = 'idle';
  @Param target: string = '';
  @Param message: string = '';
  @Param bottomAvoidInset: number = 0;
  @Local panelContentHeight: number = 0;
  @Event onCancel: () => void = () => {};
  @Event onRetry: () => void = () => {};
  @Event onDismiss: () => void = () => {};

  private isFailed(): boolean {
    return this.phase === 'failed';
  }

  private title(): string {
    if (this.phase === 'awaiting_password') {
      return '等待密码验证';
    }
    if (this.phase === 'authenticating') {
      return '正在验证密码';
    }
    if (this.phase === 'connected') {
      return '连接成功';
    }
    if (this.isFailed()) {
      return '连接未完成';
    }
    return '正在连接';
  }

  private detail(): string {
    if (this.message.trim().length > 0) {
      return this.message.trim();
    }
    if (this.isFailed()) {
      return '请检查设备状态、网络或密码后重试。';
    }
    return '仍停留在当前页面，连接成功后再进入会话。';
  }

  private updatePanelContentHeight(newArea: Area): void {
    const height = Number(newArea.height);
    if (height > 0 && Math.abs(height - this.panelContentHeight) > 0.5) {
      this.panelContentHeight = height;
    }
  }

  @Builder
  private ActionButton(label: string, primary: boolean, onActivate: () => void) {
    Stack() {
      FloatingActionSurface({
        compact: true,
        touchLight: primary,
        onActivate: onActivate,
      }) {
        Row() {
          Text(label)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor(primary ? $r('app.color.white') : $r('app.color.text_primary'));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(primary ? $r('app.color.brand_primary') : $r('app.color.transparent'))
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .layoutWeight(1)
    .height($r('app.float.control_small'));
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Stack() {
          FloatingDepthOverlay({
            radius: $r('app.float.radius_24'),
          })
            .height(this.panelContentHeight);

          Column({ space: $r('app.float.space_16') }) {
            Row({ space: $r('app.float.space_12') }) {
              if (this.isFailed()) {
                Stack({ alignContent: Alignment.Center }) {
                  Text('!')
                    .fontSize($r('app.float.font_body_large'))
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.error'));
                }
                .width($r('app.float.control_small'))
                .height($r('app.float.control_small'))
                .backgroundColor($r('app.color.error_soft'))
                .borderRadius($r('app.float.radius_pill'));
              } else {
                LoadingProgress()
                  .width($r('app.float.control_small'))
                  .height($r('app.float.control_small'))
                  .color($r('app.color.brand_primary'));
              }

              Column({ space: $r('app.float.space_4') }) {
                Text(this.title())
                  .width('100%')
                  .fontSize($r('app.float.font_body_large'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'));

                Text(this.target.length > 0 ? this.target : '远端设备')
                  .width('100%')
                  .fontSize($r('app.float.font_label'))
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
            }
            .width('100%')
            .alignItems(VerticalAlign.Center);

            Text(this.detail())
              .width('100%')
              .fontSize($r('app.float.font_body'))
              .lineHeight(20)
              .fontColor(this.isFailed() ? $r('app.color.error') : $r('app.color.text_secondary'));

            Row({ space: $r('app.float.space_12') }) {
              if (this.isFailed()) {
                this.ActionButton('关闭', false, () => this.onDismiss())
                this.ActionButton('重试', true, () => this.onRetry())
              } else {
                this.ActionButton('取消连接', false, () => this.onCancel())
              }
            }
            .width('100%');
          }
          .width('100%')
          .padding($r('app.float.card_padding'))
          .borderRadius($r('app.float.radius_24'))
          .clip(true)
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            this.updatePanelContentHeight(newArea);
          });
        }
        .width('calc(100% - 32vp)')
        .constraintSize({ maxWidth: 520 })
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 0.48,
        })
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.glass_gradient_high'), 0],
            [$r('app.color.glass_gradient_mid'), 0.48],
            [$r('app.color.glass_gradient_accent'), 1],
          ],
        })
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .borderRadius($r('app.float.radius_24'))
        .clip(true)
        .margin({ bottom: 104 + this.bottomAvoidInset });
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.overlay'))
      .accessibilityGroup(true)
      .accessibilityText(this.title());
    }
  }
}
