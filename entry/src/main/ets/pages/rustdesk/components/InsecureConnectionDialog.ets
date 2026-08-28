import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousTone,
} from 'luminous_neo';

export interface InsecureConnectionDialogProps {
  visible: boolean;
  message: string;
  onContinue: () => void;
  onDisconnect: () => void;
}

@ComponentV2
export struct InsecureConnectionDialog {
  @Param visible: boolean = false;
  @Param message: string = '';
  @Local viewportWidth: number = 390;
  @Event onContinue: () => void = () => {};
  @Event onDisconnect: () => void = () => {};

  private panelWidth(): number {
    return Math.max(300, Math.min(480, this.viewportWidth - 48));
  }

  private buttonShadowPadding(): number {
    const controlHeight: number = LuminousNeoTokens.controlHeight(LuminousControlSize.Compact);
    return LuminousNeoTokens.shadowPaddingFor(controlHeight);
  }

  private buttonWidth(): number {
    const shadowPadding: number = this.buttonShadowPadding();
    return Math.max(112, (this.panelWidth() - 48 - 12 - shadowPadding * 4) / 2);
  }

  private buttonRowGap(): number {
    return this.buttonShadowPadding() * 2 + 12;
  }

  private buttonFrameOffsetX(): number {
    return -this.buttonShadowPadding();
  }

  private detail(): string {
    if (this.message.trim().length > 0) {
      return this.message.trim();
    }
    return '无法验证端到端加密。远程设备可能仍在准备中；如果此问题持续出现，服务器可能不受信任。仍要继续吗？';
  }

  build(): void {
    if (this.visible) {
      Row() {
        Column({ space: $r('app.float.space_16') }) {
          Row({ space: $r('app.float.space_12') }) {
            Stack({ alignContent: Alignment.Center }) {
              Text('!')
                .fontSize($r('app.float.font_body_large'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.error'));
            }
            .width($r('app.float.control_small'))
            .height($r('app.float.control_small'))
            .backgroundColor($r('app.color.error_soft'))
            .borderRadius($r('app.float.radius_pill'))
            .accessibilityLevel('no');

            Column({ space: $r('app.float.space_4') }) {
              Text('无法验证端到端加密')
                .width('100%')
                .fontSize($r('app.float.font_title'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.neu_text_primary'));

              Text('继续连接会绕过服务器身份验证')
                .width('100%')
                .fontSize($r('app.float.font_label'))
                .fontColor($r('app.color.error'));
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Text(this.detail())
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .lineHeight(22)
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(6)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          Row({ space: this.buttonRowGap() }) {
            Row() {
              LuminousButton({
                label: '继续连接',
                controlWidth: this.buttonWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Neutral,
                motionEnabled: true,
                onAction: (): void => {
                  this.onContinue();
                },
              })
                .translate({ x: this.buttonFrameOffsetX() })
            }
            .width(this.buttonWidth())
            .clip(false);

            Row() {
              LuminousButton({
                label: '断开连接',
                controlWidth: this.buttonWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Danger,
                motionEnabled: true,
                onAction: (): void => {
                  this.onDisconnect();
                },
              })
                .translate({ x: this.buttonFrameOffsetX() })
            }
            .width(this.buttonWidth())
            .clip(false);
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .clip(false);
        }
        .width(this.panelWidth())
        .constraintSize({ minHeight: 300, maxHeight: 420 })
        .padding(24)
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.outline') })
        .borderRadius(28)
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD);
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.overlay'))
      .accessibilityGroup(true)
      .accessibilityText('无法验证端到端加密')
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const width: number = Number(newArea.width);
        if (width > 0) {
          this.viewportWidth = width;
        }
      });
    }
  }
}
