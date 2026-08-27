import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSurface,
  LuminousTone,
} from 'luminous_neo';
import { ControlledHostState } from '../../../services/controlled/ControlledHostTypes';

export interface ViewedHostCardProps {
  state: ControlledHostState;
  surfaceWidth: number;
  onStart: () => void;
  onStop: () => void;
  onReject: () => void;
  onRefreshPassword: () => void;
}

@ComponentV2
export struct ViewedHostCard {
  @Param state: ControlledHostState = new ControlledHostState();
  @Param surfaceWidth: number = 520;
  @Local passwordVisible: boolean = false;
  @Local passwordRevealGeneration: number = 0;
  @Event onStart: () => void = () => {};
  @Event onStop: () => void = () => {};
  @Event onReject: () => void = () => {};
  @Event onRefreshPassword: () => void = () => {};

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
    return Math.max(180, this.innerWidth() - LuminousNeoTokens.shadowPaddingFor(52) * 2);
  }

  private hideTemporaryPassword(): void {
    this.passwordRevealGeneration += 1;
    this.passwordVisible = false;
  }

  private revealTemporaryPassword(): void {
    if (this.state.temporaryPassword.length === 0) {
      return;
    }
    this.passwordRevealGeneration += 1;
    const generation: number = this.passwordRevealGeneration;
    this.passwordVisible = true;
    setTimeout((): void => {
      if (generation === this.passwordRevealGeneration) {
        this.passwordVisible = false;
      }
    }, 15000);
  }

  private incomingPeerLabel(): string {
    if (this.state.incoming === undefined) {
      return '';
    }
    const peerName: string = this.state.incoming.peerName.trim();
    return peerName.length > 0 ? peerName : this.state.incoming.peerId;
  }

  @Builder
  private PasswordActionButton(label: ResourceStr, enabled: boolean, onClick: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(enabled ? $r('app.color.neu_text_primary') : $r('app.color.neu_text_secondary'))
        .maxLines(1);
    }
    .width(this.actionWidth())
    .height(48)
    .backgroundColor($r('app.color.mica_control'))
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .hoverEffect(HoverEffect.None)
    .enabled(enabled)
    .onClick((): void => {
      if (enabled) {
        onClick();
      }
    });
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
        surfaceHeight: 60,
        cornerRadius: 18,
        motionEnabled: true,
      }) {
        Column({ space: 3 }) {
          Text(label)
            .width('100%')
            .fontSize(11)
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
        .padding({ left: 18, right: 18, top: 9, bottom: 9 })
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width(this.innerWidth())
    .height(60)
    .clip(false);
  }

  @Builder
  private IdentitySection() {
    Column({ space: 14 }) {
      this.SectionHeading($r('sys.symbol.display'), '设备身份', '临时密码显示 15 秒后自动隐藏。');
      this.InsetValue('设备 ID', this.state.myId.length > 0 ? this.state.myId : '正在加载', true);
      this.InsetValue('临时密码', this.state.temporaryPassword.length === 0 ? '等待生成' :
        (this.passwordVisible ? this.state.temporaryPassword : '••••••'), true);
      Row({ space: 12 }) {
        this.PasswordActionButton(this.passwordVisible ? '隐藏密码' : '显示密码',
          this.state.temporaryPassword.length > 0, (): void => {
            if (this.passwordVisible) {
              this.hideTemporaryPassword();
            } else {
              this.revealTemporaryPassword();
            }
          });
        this.PasswordActionButton('刷新密码', true, (): void => {
          this.hideTemporaryPassword();
          this.onRefreshPassword();
        });
      }
      .width('100%');
    }
    .width('100%')
    .padding({ left: this.compact() ? 4 : 8, right: this.compact() ? 4 : 8 })
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private ServiceSection() {
    Column({ space: 14 }) {
      this.SectionHeading($r('sys.symbol.display'), '观看服务',
        '启动时由系统确认屏幕和设备内音频共享。');
      Text(this.state.incoming !== undefined ? `${this.incomingPeerLabel()} 正在验证` : this.state.statusText)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.running() ? $r('app.color.success') : $r('app.color.neu_text_secondary'));
      if (this.state.incoming !== undefined) {
        LuminousButton({
          label: '拒绝并断开',
          controlWidth: this.fullActionWidth(),
          controlSizeMode: LuminousControlSize.Regular,
          tone: LuminousTone.Danger,
          onAction: () => this.onReject(),
        });
      } else {
        LuminousButton({
          label: this.running() ? '停止观看服务' : '启动观看服务',
          controlWidth: this.fullActionWidth(),
          controlSizeMode: LuminousControlSize.Regular,
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
    .alignItems(HorizontalAlign.Start);
  }

  build(): void {
    Column({ space: 16 }) {
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
