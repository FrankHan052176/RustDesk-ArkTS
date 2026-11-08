import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousTone,
} from 'luminous_neo';

@ComponentV2
export struct ShareConfirmDialog {
  @Param visible: boolean = false;
  @Param needsUnverifiedConfirmation: boolean = false;
  @Param busy: boolean = false;
  @Local viewportWidth: number = 390;
  @Event onConfirm: (acceptUnverified: boolean) => void = (_accept: boolean) => {};
  @Event onCancel: () => void = () => {};

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

  build(): void {
    if (this.visible) {
      Row() {
        Column({ space: $r('app.float.space_16') }) {
          Row({ space: $r('app.float.space_12') }) {
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.share'))
                .fontSize(22)
                .fontColor([this.needsUnverifiedConfirmation ? $r('app.color.error') : $r('app.color.neu_accent')]);
            }
            .width(40)
            .height(40)
            .backgroundColor(this.needsUnverifiedConfirmation ? $r('app.color.error_soft') : $r('app.color.neu_base'))
            .borderRadius(20);

            Column({ space: 4 }) {
              Text(this.needsUnverifiedConfirmation ? '转分享未验证来源第二屏' : '转分享第二屏')
                .width('100%')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.neu_text_primary'));

              if (this.needsUnverifiedConfirmation) {
                Text('连接已加密，但来源身份未验证')
                  .width('100%')
                  .fontSize(12)
                  .fontColor($r('app.color.error'));
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Column({ space: 8 }) {
            Text('• 仅转分享远端主机的第二屏（副屏）画面，无法查看主屏。')
              .fontSize(13)
              .lineHeight(19)
              .fontColor($r('app.color.neu_text_secondary'));

            Text('• 远端观看者 (C) 仅具备观看权限（只读），无键盘鼠标控制或文件传输权限。')
              .fontSize(13)
              .lineHeight(19)
              .fontColor($r('app.color.neu_text_secondary'));

            Text('• 被控端 (A) 不会另外弹出转分享确认提示。')
              .fontSize(13)
              .lineHeight(19)
              .fontColor($r('app.color.neu_text_secondary'));

            if (this.needsUnverifiedConfirmation) {
              Text('• 注意：继续会把此会话的第二屏画面分享给持码者。')
                .fontSize(13)
                .lineHeight(19)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.error'));
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);

          Row({ space: this.buttonRowGap() }) {
            Row() {
              LuminousButton({
                label: '取消',
                controlWidth: this.buttonWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: LuminousTone.Neutral,
                motionEnabled: true,
                isEnabled: !this.busy,
                onAction: (): void => this.onCancel(),
              })
                .translate({ x: this.buttonFrameOffsetX() });
            }
            .width(this.buttonWidth())
            .clip(false);

            Row() {
              LuminousButton({
                label: this.needsUnverifiedConfirmation ? '仍然转分享' : '确认转分享',
                controlWidth: this.buttonWidth(),
                controlSizeMode: LuminousControlSize.Compact,
                tone: this.needsUnverifiedConfirmation ? LuminousTone.Danger : LuminousTone.Accent,
                motionEnabled: true,
                isEnabled: !this.busy,
                onAction: (): void => this.onConfirm(this.needsUnverifiedConfirmation),
              })
                .translate({ x: this.buttonFrameOffsetX() });
            }
            .width(this.buttonWidth())
            .clip(false);
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .clip(false);
        }
        .width(this.panelWidth())
        .padding(24)
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
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const width: number = Number(newArea.width);
        if (width > 0) {
          this.viewportWidth = width;
        }
      });
    }
  }
}
