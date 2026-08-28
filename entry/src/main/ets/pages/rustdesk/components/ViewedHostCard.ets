import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSurface,
  LuminousTone,
} from 'luminous_neo';
import { ControlledHostState } from '../../../services/controlled/ControlledHostTypes';
import { FloatingActionSurface } from './FloatingSurface';

export interface ViewedHostCardProps {
  state: ControlledHostState;
  surfaceWidth: number;
  onStart: () => void;
  onStop: () => void;
  onAccept: (requestId: string, peerId: string) => void;
  onReject: (requestId: string, peerId: string) => void;
  onRefreshPassword: () => void;
}

@ComponentV2
export struct ViewedHostCard {
  @Param state: ControlledHostState = new ControlledHostState();
  @Param surfaceWidth: number = 520;
  @Local passwordVisible: boolean = false;
  @Local passwordDisplayText: string = '等待生成';
  @Local passwordRevealGeneration: number = 0;
  @Event onStart: () => void = () => {};
  @Event onStop: () => void = () => {};
  @Event onAccept: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onReject: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onRefreshPassword: () => void = () => {};

  aboutToAppear(): void {
    this.hideTemporaryPassword();
  }

  aboutToDisappear(): void {
    this.hideTemporaryPassword();
  }

  @Monitor('state.temporaryPassword')
  private onTemporaryPasswordChanged(_monitor: IMonitor): void {
    this.hideTemporaryPassword();
  }

  private compact(): boolean {
    return this.surfaceWidth < 560;
  }

  private innerWidth(): number {
    return Math.max(240, this.surfaceWidth - (this.compact() ? 32 : 44));
  }

  private running(): boolean {
    return this.state.phase === 'starting' || this.state.phase === 'ready' || this.state.phase === 'incoming' ||
      this.state.phase === 'active' || this.state.phase === 'stopping';
  }

  private actionWidth(): number {
    const shadowPadding: number = LuminousNeoTokens.shadowPaddingFor(48);
    return Math.max(104, (this.innerWidth() - 12 - shadowPadding * 4) / 2);
  }

  private fullActionWidth(): number {
    return Math.max(180,
      this.innerWidth() - LuminousNeoTokens.shadowPaddingFor(LuminousNeoTokens.COMPACT_HEIGHT) * 2);
  }

  private hideTemporaryPassword(): void {
    this.passwordRevealGeneration += 1;
    this.passwordVisible = false;
    this.passwordDisplayText = this.state.temporaryPassword.length > 0 ? '••••••' : '等待生成';
  }

  private revealTemporaryPassword(): void {
    if (this.state.temporaryPassword.length === 0) {
      return;
    }
    this.passwordRevealGeneration += 1;
    const generation: number = this.passwordRevealGeneration;
    this.passwordVisible = true;
    this.passwordDisplayText = this.state.temporaryPassword;
    setTimeout((): void => {
      if (generation === this.passwordRevealGeneration) {
        this.hideTemporaryPassword();
      }
    }, 15000);
  }

  @Builder
  private SectionHeading(icon: Resource, title: ResourceStr, subtitle: ResourceStr) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(26)
        .fontColor([$r('app.color.neu_accent')]);
      Column({ space: 3 }) {
        Text(title)
          .width('100%')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.neu_text_primary'));
        Text(subtitle)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.neu_text_secondary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%');
  }

  @Builder
  private InsetValue(label: ResourceStr, value: ResourceStr, monospace: boolean = false) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: -1,
        surfaceWidth: this.innerWidth(),
        surfaceHeight: 54,
        cornerRadius: 16,
        motionEnabled: true,
      }) {
        Column({ space: 1 }) {
          Text(label)
            .width('100%')
            .fontSize(10)
            .fontColor($r('app.color.neu_text_secondary'));
          Text(value)
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontFamily(monospace ? 'monospace' : '')
            .fontColor($r('app.color.neu_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width(this.innerWidth())
    .height(54)
    .clip(false);
  }

  @Builder
  private PasswordInsetValue() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: -1,
        surfaceWidth: this.innerWidth(),
        surfaceHeight: 54,
        cornerRadius: 16,
        motionEnabled: true,
      }) {
        Row({ space: 6 }) {
          Column({ space: 1 }) {
            Text('临时密码')
              .width('100%')
              .fontSize(10)
              .fontColor($r('app.color.neu_text_secondary'));
            Text(this.passwordDisplayText)
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontFamily('monospace')
              .fontColor($r('app.color.neu_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          Stack() {
            FloatingActionSurface({
              selected: this.passwordVisible,
              compact: true,
              subtleDepth: true,
              actionEnabled: this.state.temporaryPassword.length > 0,
              accessibilityLabel: this.passwordVisible ? '隐藏密码' : '显示密码',
              stopTouchPropagation: true,
              onActivate: (): void => {
                if (this.passwordVisible) {
                  this.hideTemporaryPassword();
                } else {
                  this.revealTemporaryPassword();
                }
              },
            }) {
              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(this.passwordVisible ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
                  .fontSize(18)
                  .fontColor([this.passwordVisible
                    ? $r('app.color.neu_accent')
                    : $r('app.color.neu_text_primary')]);
              }
              .width('100%')
              .height('100%');
            }
          }
          .width(34)
          .height(34);

          Stack() {
            FloatingActionSurface({
              compact: true,
              subtleDepth: true,
              accessibilityLabel: '刷新密码',
              stopTouchPropagation: true,
              onActivate: (): void => {
                this.hideTemporaryPassword();
                this.onRefreshPassword();
              },
            }) {
              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                  .fontSize(18)
                  .fontColor([$r('app.color.neu_text_primary')]);
              }
              .width('100%')
              .height('100%');
            }
          }
          .width(34)
          .height(34);
        }
        .width('100%')
        .height('100%')
        .padding({ left: 14, right: 12 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.innerWidth())
    .height(54)
    .clip(false);
  }

  @Builder
  private IdentitySection() {
    Column({ space: 8 }) {
      this.SectionHeading($r('sys.symbol.display'), '设备身份', '临时密码显示 15 秒后自动隐藏。');
      this.InsetValue('设备 ID', this.state.myId.length > 0 ? this.state.myId : '正在加载', true);
      this.PasswordInsetValue();
    }
    .width('100%')
    .padding({ left: this.compact() ? 4 : 8, right: this.compact() ? 4 : 8 })
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private ServiceSection() {
    Column({ space: 8 }) {
      if (this.state.incoming !== undefined) {
        if (this.state.incomingResolving) {
          LuminousButton({
            label: '正在处理…',
            controlWidth: this.fullActionWidth(),
            controlSizeMode: LuminousControlSize.Regular,
            tone: LuminousTone.Accent,
            onAction: () => {},
          });
        } else {
          this.IncomingConsentActions(this.state.incoming.requestId, this.state.incoming.peerId);
        }
      } else {
        LuminousButton({
          label: this.running() ? '停止服务端' : '启动服务端',
          controlWidth: this.fullActionWidth(),
          controlSizeMode: LuminousControlSize.Compact,
          tone: this.running() ? LuminousTone.Danger : LuminousTone.Accent,
          onAction: () => this.running() ? this.onStop() : this.onStart(),
        });
      }
      if (this.state.lastError.length > 0) {
        Text(this.state.lastError)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.error'));
      }
    }
    .width('100%')
    .padding({ left: this.compact() ? 4 : 8, right: this.compact() ? 4 : 8 })
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private IncomingConsentActions(requestId: string, peerId: string) {
          Row({ space: 12 }) {
            LuminousButton({
              label: '同意观看',
              controlWidth: this.actionWidth(),
              controlSizeMode: LuminousControlSize.Regular,
              tone: LuminousTone.Accent,
              onAction: () => this.onAccept(requestId, peerId),
            });
            LuminousButton({
              label: '拒绝',
              controlWidth: this.actionWidth(),
              controlSizeMode: LuminousControlSize.Regular,
              tone: LuminousTone.Danger,
              onAction: () => this.onReject(requestId, peerId),
            });
          }
          .width('100%')
          .justifyContent(FlexAlign.Center);
  }

  build(): void {
    Column({ space: 8 }) {
      this.IdentitySection();
      Divider()
        .width(this.innerWidth())
        .color($r('app.color.mica_border'));
      this.ServiceSection();
    }
    .width(this.surfaceWidth)
    .alignItems(HorizontalAlign.Center)
    .clip(false);
  }
}
