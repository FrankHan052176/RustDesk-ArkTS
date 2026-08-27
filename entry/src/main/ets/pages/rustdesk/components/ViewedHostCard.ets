import { abilityAccessCtrl } from '@kit.AbilityKit';
import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSurface,
  LuminousTone,
} from 'luminous_neo';
import { ControlledHostState } from '../../../services/controlled/ControlledHostTypes';
import { FloatingGlassSurface } from './FloatingSurface';

export interface ViewedHostCardProps {
  state: ControlledHostState;
  surfaceWidth: number;
  onStart: () => void;
  onStop: () => void;
  onReject: () => void;
  onRefreshPassword: () => void;
  onOpenRecordingPermission: () => void;
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
  @Event onOpenRecordingPermission: () => void = () => {};

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

  private recordingGranted(): boolean {
    return this.state.recordingPermission === abilityAccessCtrl.PermissionStatus.GRANTED;
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

  private maskedPassword(): string {
    if (this.state.temporaryPassword.length === 0) {
      return '等待生成';
    }
    if (this.passwordVisible) {
      return this.state.temporaryPassword;
    }
    return '••••••';
  }

  private incomingPeerLabel(): string {
    if (this.state.incoming === undefined) {
      return '';
    }
    const peerName: string = this.state.incoming.peerName.trim();
    return peerName.length > 0 ? peerName : this.state.incoming.peerId;
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
  private CapabilityNotice() {
    FloatingGlassSurface({ surfaceWidth: this.surfaceWidth, radius: $r('app.float.radius_24') }) {
      Column({ space: 14 }) {
        this.SectionHeading($r('sys.symbol.eye'), '仅观看此设备',
          '远端只能接收屏幕画面和系统音频，不提供任何控制通道。');
        Text('屏幕 + 音频')
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.success'));
        Text('禁止键盘、鼠标、触摸、剪贴板和文件控制。观看会话不会接收或执行这些输入。')
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor($r('app.color.neu_text_primary'));
      }
      .width('100%')
      .padding(this.compact() ? 16 : 22)
      .alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private IdentitySection() {
    FloatingGlassSurface({ surfaceWidth: this.surfaceWidth, radius: $r('app.float.radius_24') }) {
      Column({ space: 14 }) {
        this.SectionHeading($r('sys.symbol.display'), '设备身份与临时密码',
          '临时密码仅按需显示，15 秒后自动隐藏；离开页面或密码刷新也会立即隐藏。');
        this.InsetValue('设备 ID', this.state.myId.length > 0 ? this.state.myId : '正在加载', true);
        this.InsetValue('临时密码', this.maskedPassword(), true);
        Row({ space: 12 }) {
          LuminousButton({
            label: this.passwordVisible ? '立即隐藏' : '显示 15 秒',
            controlWidth: this.actionWidth(),
            controlSizeMode: LuminousControlSize.Compact,
            tone: LuminousTone.Neutral,
            isEnabled: this.state.temporaryPassword.length > 0,
            onAction: (): void => {
              if (this.passwordVisible) {
                this.hideTemporaryPassword();
              } else {
                this.revealTemporaryPassword();
              }
            },
          });
          LuminousButton({
            label: '刷新密码',
            controlWidth: this.actionWidth(),
            controlSizeMode: LuminousControlSize.Compact,
            tone: LuminousTone.Neutral,
            onAction: (): void => {
              this.hideTemporaryPassword();
              this.onRefreshPassword();
            },
          });
        }
        .width('100%');
      }
      .width('100%')
      .padding(this.compact() ? 16 : 22)
      .alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private RecordingSection() {
    FloatingGlassSurface({ surfaceWidth: this.surfaceWidth, radius: $r('app.float.radius_24') }) {
      Column({ space: 14 }) {
        this.SectionHeading($r('sys.symbol.record_circle'), '屏幕录制权限',
          '这是签名 Profile/ACL 控制的受限权限；系统设置只能查看或处理已配置的授权。');
        Text(this.recordingGranted() ? '受限权限已授权' : '未获授权或已撤销')
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.recordingGranted() ? $r('app.color.success') : $r('app.color.warning'));
        if (!this.recordingGranted()) {
          LuminousButton({
            label: '查看权限设置',
            controlWidth: this.fullActionWidth(),
            controlSizeMode: LuminousControlSize.Compact,
            tone: LuminousTone.Neutral,
            onAction: () => this.onOpenRecordingPermission(),
          });
        }
      }
      .width('100%')
      .padding(this.compact() ? 16 : 22)
      .alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private ServiceSection() {
    FloatingGlassSurface({
      surfaceWidth: this.surfaceWidth,
      radius: $r('app.float.radius_24'),
      measurementKey: `${this.state.phase}:${String(this.state.incoming !== undefined)}:${this.state.lastError}`,
    }) {
      Column({ space: 14 }) {
        this.SectionHeading($r('sys.symbol.display'), '观看服务',
          '服务仅在系统允许的前台和录屏授权范围内运行。');
        Text(this.state.statusText)
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.running() ? $r('app.color.success') : $r('app.color.neu_text_secondary'));
        if (this.state.incoming !== undefined) {
          Text(`${this.incomingPeerLabel()} 正在进行密码验证`)
            .width('100%')
            .fontSize(14)
            .lineHeight(20)
            .fontColor($r('app.color.neu_text_primary'));
          Text('只有密码通过（以及启用时的 2FA 通过）后才会开始观看；本机不能跳过认证直接放行。')
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.neu_text_secondary'));
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
            isEnabled: this.running() || this.recordingGranted(),
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
      .padding(this.compact() ? 16 : 22)
      .alignItems(HorizontalAlign.Start);
    }
  }

  build(): void {
    Column({ space: 18 }) {
      this.CapabilityNotice();
      this.IdentitySection();
      this.RecordingSection();
      this.ServiceSection();
      Text('安全边界：此页面不提供键盘、鼠标、触摸、剪贴板或文件控制，也不会请求相关权限。')
        .width('100%')
        .fontSize(11)
        .lineHeight(17)
        .fontColor($r('app.color.neu_text_secondary'))
        .padding({ left: this.compact() ? 6 : 10, right: this.compact() ? 6 : 10 });
    }
    .width(this.surfaceWidth)
    .alignItems(HorizontalAlign.Center)
    .clip(false);
  }
}
