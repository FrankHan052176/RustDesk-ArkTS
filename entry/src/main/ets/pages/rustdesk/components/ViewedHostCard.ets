import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSurface,
  LuminousTone,
} from 'luminous_neo';
import { pasteboard } from '@kit.BasicServicesKit';
import { ControlledHostState } from '../../../services/controlled/ControlledHostTypes';
import { FloatingActionSurface } from './FloatingSurface';

const INPUT_SIMULATOR_SYSCAP = 'SystemCapability.MultimodalInput.Input.InputSimulator';

export interface ViewedHostCardProps {
  state: ControlledHostState;
  surfaceWidth: number;
  onStart: () => void;
  onStartWithInput: () => void;
  onStop: () => void;
  onAccept: (requestId: string, peerId: string) => void;
  onReject: (requestId: string, peerId: string) => void;
  onRefreshPassword: () => void;
}

@ComponentV2
export struct ViewedHostCard {
  @Param state: ControlledHostState = new ControlledHostState();
  @Param surfaceWidth: number = 520;
  @Local passwordCopied: boolean = false;
  @Event onStart: () => void = () => {};
  @Event onStartWithInput: () => void = () => {};
  @Event onStop: () => void = () => {};
  @Event onAccept: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onReject: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onRefreshPassword: () => void = () => {};

  private compact(): boolean {
    return this.surfaceWidth < 560;
  }

  private innerWidth(): number {
    return Math.max(240, this.surfaceWidth - (this.compact() ? 24 : 36));
  }

  private running(): boolean {
    return this.state.phase === 'starting' || this.state.phase === 'ready' || this.state.phase === 'incoming' ||
      this.state.phase === 'active' || this.state.phase === 'stopping' || this.state.inputEnabled ||
      this.state.teardownUnconfirmed.length > 0;
  }

  private inputSimulatorSupported(): boolean {
    return canIUse(INPUT_SIMULATOR_SYSCAP);
  }

  private actionWidth(): number {
    return Math.max(104, (this.innerWidth() - 12) / 2);
  }

  private fullActionWidth(): number {
    return this.innerWidth();
  }

  private passwordText(): string {
    return this.state.temporaryPassword.length > 0 ? this.state.temporaryPassword : '等待生成';
  }

  /**
   * The password has to be readable and takeable in one tap: it is what the
   * controller types. Nothing here hides it again, so a copied one and a read one
   * are the same value.
   */
  private copyTemporaryPassword(): void {
    const password: string = this.state.temporaryPassword;
    if (password.length === 0) {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, password);
    pasteboard.getSystemPasteboard().setData(data).then((): void => {
      this.passwordCopied = true;
      setTimeout((): void => {
        this.passwordCopied = false;
      }, 1500);
    }).catch((error: Error): void => {
      this.passwordCopied = false;
    });
  }

  @Builder
  private SectionHeading(icon: Resource, title: ResourceStr, subtitle: ResourceStr) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([$r('app.color.neu_accent')]);
      Column({ space: 3 }) {
        Text(title)
          .width('100%')
          .fontSize(18)
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
    .width(this.innerWidth());
  }

  @Builder
  private InsetValue(label: ResourceStr, value: ResourceStr, monospace: boolean = false) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: -1,
        surfaceWidth: this.innerWidth(),
        surfaceHeight: 56,
        cornerRadius: 16,
        motionEnabled: true,
      }) {
        Column({ space: 2 }) {
          Text(label)
            .width('100%')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          Text(value)
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontFamily(monospace ? 'monospace' : '')
            .fontColor($r('app.color.neu_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width(this.innerWidth())
    .height(56)
    .clip(false);
  }

  @Builder
  private PasswordInsetValue() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: -1,
        surfaceWidth: this.innerWidth(),
        surfaceHeight: 56,
        cornerRadius: 16,
        motionEnabled: true,
      }) {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('临时密码')
              .width('100%')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_text_secondary'));
            Text(this.passwordText())
              .width('100%')
              .fontSize(16)
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
              selected: this.passwordCopied,
              compact: true,
              subtleDepth: true,
              actionEnabled: this.state.temporaryPassword.length > 0,
              accessibilityLabel: this.passwordCopied ? '已复制临时密码' : '复制临时密码',
              stopTouchPropagation: true,
              onActivate: (): void => {
                this.copyTemporaryPassword();
              },
            }) {
              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph(this.passwordCopied ? $r('sys.symbol.checkmark') : $r('sys.symbol.rectangle_on_rectangle'))
                  .fontSize(18)
                  .fontColor([this.passwordCopied
                    ? $r('app.color.neu_accent')
                    : $r('app.color.neu_text_primary')]);
              }
              .width('100%')
              .height('100%');
            }
          }
          .width(36)
          .height(36);

          Stack() {
            FloatingActionSurface({
              compact: true,
              subtleDepth: true,
              accessibilityLabel: '刷新密码',
              stopTouchPropagation: true,
              onActivate: (): void => {
                this.passwordCopied = false;
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
          .width(36)
          .height(36);
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 12 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.innerWidth())
    .height(56)
    .clip(false);
  }

  @Builder
  private StatusNotice(icon: Resource, text: string, isError: boolean = false) {
    Row({ space: 10 }) {
      SymbolGlyph(icon)
        .fontSize(16)
        .fontColor([isError ? $r('app.color.error') : $r('app.color.neu_accent')]);
      Text(text)
        .layoutWeight(1)
        .fontSize(12)
        .lineHeight(18)
        .fontColor(isError ? $r('app.color.error') : $r('app.color.neu_text_secondary'));
    }
    .width(this.innerWidth())
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.neu_base'))
    .borderRadius(14)
    .border({
      width: 1,
      color: isError ? $r('app.color.error') : $r('app.color.mica_border')
    });
  }

  @Builder
  private IdentitySection() {
    Column({ space: 12 }) {
      this.SectionHeading($r('sys.symbol.display'), '本机 ID 与密码', '把 ID 和密码告诉对方，对方就能连接这台设备。');
      this.InsetValue('设备 ID', this.state.myId.length > 0 ? this.state.myId : '正在加载', true);
      this.PasswordInsetValue();
    }
    .width(this.innerWidth())
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private ServiceSection() {
    Column({ space: 12 }) {
      if (this.state.statusText.length > 0 && this.state.statusText !== this.state.lastError) {
        // Rendered here rather than through a `@Builder`: a builder argument is
        // captured when its branch is created, so this notice kept the idle text
        // while the run was already listening.
        Row({ space: 10 }) {
          SymbolGlyph(this.running() ? $r('sys.symbol.display') : $r('sys.symbol.info_circle'))
            .fontSize(16)
            .fontColor([$r('app.color.neu_accent')]);
          Text(this.state.statusText)
            .layoutWeight(1)
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.neu_text_secondary'));
        }
        .width(this.innerWidth())
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.neu_base'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.mica_border') });
      }
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
      }
      LuminousButton({
        label: this.running() ? '停止共享' : '共享屏幕（对方只能观看）',
        controlWidth: this.fullActionWidth(),
        controlSizeMode: LuminousControlSize.Compact,
        tone: this.running() ? LuminousTone.Danger : LuminousTone.Accent,
        onAction: () => this.running() ? this.onStop() : this.onStart(),
      });
      if (!this.running()) {
        if (this.inputSimulatorSupported()) {
          LuminousButton({
            label: '共享屏幕并允许对方操作',
            controlWidth: this.fullActionWidth(),
            controlSizeMode: LuminousControlSize.Compact,
            tone: LuminousTone.Accent,
            onAction: () => this.onStartWithInput(),
          });
        }
      } else if (!this.state.inputEnabled && this.state.phase !== 'starting' && this.state.phase !== 'stopping' &&
        this.inputSimulatorSupported()) {
        this.StatusNotice($r('sys.symbol.info_circle'), '对方现在只能观看。要允许对方操作，请先停止共享，再选择“共享屏幕并允许对方操作”。', false);
      }
      if (this.state.inputAuthorizationError.length > 0) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(16)
            .fontColor([$r('app.color.error')]);
          Text(this.state.inputAuthorizationError)
            .layoutWeight(1)
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.error'));
        }
        .width(this.innerWidth())
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.neu_base'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.error') });
      }
      if (this.state.lastError.length > 0) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(16)
            .fontColor([$r('app.color.error')]);
          Text(this.state.lastError)
            .layoutWeight(1)
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.error'));
        }
        .width(this.innerWidth())
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.neu_base'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.error') });
      }
    }
    .width(this.innerWidth())
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private IncomingConsentActions(requestId: string, peerId: string) {
    Row({ space: 12 }) {
      LuminousButton({
        label: this.state.inputEnabled && this.state.inputAuthorization === 'authorized'
          ? '同意远程控制' : '同意观看',
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
    .width(this.innerWidth())
    .justifyContent(FlexAlign.Center);
  }

  build(): void {
    Column({ space: 16 }) {
      this.IdentitySection();
      Divider()
        .width(this.innerWidth())
        .color($r('app.color.mica_border'))
        .margin({ top: 4, bottom: 4 });
      this.ServiceSection();
    }
    .width(this.surfaceWidth)
    .alignItems(HorizontalAlign.Center)
    .clip(false);
  }
}
