import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
  LuminousSecondaryMenu,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSurface,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';
import { EasyTierInstanceSummary } from '../../../services/EasyTierApiService';
import { DirectorySnapshot, PeerProtocol, PeerRecord } from '../RustDeskDirectoryTypes';
import { TargetFieldIssue, targetFieldIssue, targetFieldIssueText } from '../DirectWireCredentials';
import { RustDeskLayoutTokens } from '../RustDeskLayoutTokens';
import {
  peerDisplaySubtitle,
  peerDisplayTitle,
  peerOnlineState,
  peerReachability,
  peerProtocolName,
  peerProtocolOf,
} from '../RustDeskPeerDirectoryModel';
import { FloatingActionSurface } from './FloatingSurface';
import { deviceConnectionTarget } from '../SavedDeviceModel';

export interface ConnectTabProps {
  target: string;
  rememberPassword: boolean;
  scroller: Scroller;
  onTargetChange: (value: string) => void;
  onConnectRemote: () => void;
  onConnectVnc: () => void;
  onConnectRdp: () => void;
  onOpenTransfer: () => void;
  onDisconnect: () => void;
  canDisconnect: boolean;
  transferActive: boolean;
  easyTierAvailable: boolean;
  easyTierEnabled: boolean;
  easyTierInstances: EasyTierInstanceSummary[];
  easyTierInstanceId: string;
  easyTierBusy: boolean;
  wideLayout: boolean;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  directorySnapshot: DirectorySnapshot;
  onEasyTierModeChange: (instanceId: string) => void;
}

@ComponentV2
export struct ConnectTab {
  @Param target: string = '';
  @Param rememberPassword: boolean = false;
  @Param canDisconnect: boolean = false;
  @Param transferActive: boolean = false;
  @Param easyTierAvailable: boolean = false;
  @Param easyTierEnabled: boolean = false;
  @Param easyTierInstances: EasyTierInstanceSummary[] = [];
  @Param easyTierInstanceId: string = '';
  @Param easyTierBusy: boolean = false;
  @Param wideLayout: boolean = false;
  @Param titleSpacerHeight: number = 56;
  @Param bottomAvoidInset: number = 0;
  @Param directorySnapshot: DirectorySnapshot = new DirectorySnapshot();
  @Param scroller: Scroller = new Scroller();
  @Local viewportWidth: number = 390;
  // The page owns the selected protocol, like the target text, so the choice
  // survives this tab being rebuilt around a session.
  @Param connectionMode: number = 0;
  @Event onConnectionModeChange: (index: number) => void = (_index: number) => {};
  @Event onTargetChange: (value: string) => void = (_value: string) => {};
  @Event onConnectRemote: () => void = () => {};
  @Event onConnectVnc: () => void = () => {};
  @Event onConnectRdp: () => void = () => {};
  @Event onOpenTransfer: () => void = () => {};
  @Event onDisconnect: () => void = () => {};
  @Event onEasyTierModeChange: (instanceId: string) => void = (_instanceId: string) => {};

  private useTwoColumnWorkspace(): boolean {
    return this.wideLayout && this.viewportWidth >= RustDeskLayoutTokens.HOME_TWO_COLUMN_MIN_WIDTH;
  }

  private isCompact(): boolean {
    return !this.useTwoColumnWorkspace();
  }

  private useWideContentAnchor(): boolean {
    return RustDeskLayoutTokens.useWideContentAnchor(this.viewportWidth, this.wideLayout);
  }

  private wideWorkspaceLeftInset(): number {
    return RustDeskLayoutTokens.WIDE_CONTENT_EDGE - (this.stageFrameWidth() - this.controlWidth()) / 2;
  }

  private controlWidth(): number {
    if (this.isCompact()) {
      return Math.max(280, Math.min(this.viewportWidth - 40, 520));
    }
    return 440;
  }

  private stageFrameWidth(): number {
    return this.controlWidth() + 40;
  }

  private compactControlVisualOffsetX(): number {
    return this.isCompact() ? -6 : 0;
  }

  private secondaryMenuFrameOverhead(): number {
    const mainPadding = LuminousNeoTokens.shadowPaddingFor(this.easyTierMenuHeight());
    const handlePadding = LuminousNeoTokens.shadowPaddingFor(40);
    return mainPadding + handlePadding + 50;
  }

  private recentFrameWidth(): number {
    return this.stageFrameWidth();
  }

  private recentContentWidth(): number {
    return this.controlWidth();
  }

  private recentCardFrameWidth(): number {
    return (this.recentContentWidth() - 8) / 2;
  }

  private recentCardContentWidth(): number {
    return Math.max(120, this.recentCardFrameWidth() - 4);
  }

  /** The session kind the selected mode dials; the file workspace is a RustDesk target. */
  private modeKind(): string {
    if (this.connectionMode === 1) {
      return 'vnc';
    }
    return this.connectionMode === 2 ? 'rdp' : 'remote_control';
  }

  private targetIssue(): TargetFieldIssue {
    return targetFieldIssue(this.modeKind(), this.target);
  }

  private targetReady(): boolean {
    return this.target.trim().length > 0 && this.targetIssue() === '';
  }

  private targetPlaceholder(): string {
    if (this.connectionMode === 1) {
      return '主机或 IP[:端口]，默认 5900';
    }
    if (this.connectionMode === 2) {
      return '主机或 IP[:端口]，默认 3389';
    }
    return '输入设备 ID';
  }

  private modeItems(): LuminousSelectionItem[] {
    return [
      new LuminousSelectionItem('control', '远控', '使用 RustDesk 协议完整控制远端'),
      new LuminousSelectionItem('vnc', 'VNC', '连接标准 VNC 服务端'),
      new LuminousSelectionItem('rdp', 'RDP', '连接 Windows 远程桌面'),
      new LuminousSelectionItem('files', '文件', '浏览并传输文件'),
    ];
  }

  private modeSymbol(): Resource {
    if (this.connectionMode === 1) {
      return $r('sys.symbol.link');
    }
    if (this.connectionMode === 2) {
      return $r('sys.symbol.square');
    }
    if (this.connectionMode === 3) {
      return $r('sys.symbol.folder');
    }
    return $r('sys.symbol.display');
  }

  private modeTitle(): ResourceStr {
    if (this.connectionMode === 1) {
      return '连接 VNC 服务端';
    }
    if (this.connectionMode === 2) {
      return '连接远程桌面';
    }
    if (this.connectionMode === 3) {
      return '打开文件工作区';
    }
    return '建立远程控制';
  }

  private modeDescription(): ResourceStr {
    if (this.connectionMode === 1) {
      return '用标准 RFB 协议连接路由器、开发板或虚拟机上的 VNC 服务端';
    }
    if (this.connectionMode === 2) {
      return '用 RDP 协议连接 Windows 远程桌面，适合企业内网与服务器';
    }
    if (this.connectionMode === 3) {
      return '在本机与远端之间浏览和传输文件';
    }
    return '使用 RustDesk 协议连接，支持触摸、键鼠与剪贴板';
  }

  private primaryActionLabel(): ResourceStr {
    if (this.connectionMode === 1) {
      return this.canDisconnect ? '建立新 VNC 连接' : '连接 VNC';
    }
    if (this.connectionMode === 2) {
      return this.canDisconnect ? '建立新 RDP 连接' : '连接 RDP';
    }
    if (this.connectionMode === 3) {
      return this.transferActive ? '返回文件传输' : '开始文件传输';
    }
    return this.canDisconnect ? '建立新连接' : '开始连接';
  }

  private easyTierMenuSelectedIndex(): number {
    if (!this.easyTierEnabled) {
      return 0;
    }
    for (let index = 0; index < this.easyTierInstances.length; index += 1) {
      if (this.easyTierInstances[index].instanceId === this.easyTierInstanceId) {
        return index + 1;
      }
    }
    return 0;
  }

  private easyTierOptionLabel(instance: EasyTierInstanceSummary): string {
    let state = '已停止';
    if (instance.state === 'running') {
      state = '运行中';
    } else if (instance.state === 'starting') {
      state = '启动中';
    }
    return instance.peerCount > 0
      ? `${instance.instanceName} · ${state} · ${instance.peerCount} 个对端`
      : `${instance.instanceName} · ${state}`;
  }

  private easyTierMenuItems(): LuminousSelectionItem[] {
    const items: LuminousSelectionItem[] = [
      new LuminousSelectionItem('direct', '不组网（RustDesk 直连）', '不使用 EasyTier，直接连接远端设备'),
    ];
    for (let index = 0; index < this.easyTierInstances.length; index += 1) {
      const instance = this.easyTierInstances[index];
      items.push(new LuminousSelectionItem(
        `easytier-${instance.instanceId}`,
        this.easyTierOptionLabel(instance),
        `使用 EasyTier 实例 ${instance.instanceName}`,
      ));
    }
    return items;
  }

  private easyTierMenuHeight(): number {
    return LuminousNeoTokens.REGULAR_HEIGHT;
  }

  private easyTierMenuControlWidth(): number {
    return Math.max(280, this.stageFrameWidth() - this.secondaryMenuFrameOverhead());
  }

  private easyTierMenuFrameHeight(): number {
    const mainPadding = LuminousNeoTokens.shadowPaddingFor(this.easyTierMenuHeight());
    return this.easyTierMenuHeight() + mainPadding * 2;
  }

  private commitEasyTierMenuIndex(index: number): void {
    if (index === 0) {
      this.onEasyTierModeChange('');
      return;
    }
    const instanceIndex = index - 1;
    if (instanceIndex >= 0 && instanceIndex < this.easyTierInstances.length) {
      this.onEasyTierModeChange(this.easyTierInstances[instanceIndex].instanceId);
    }
  }

  private activatePrimaryAction(): void {
    if (this.connectionMode === 1) {
      this.onConnectVnc();
      return;
    }
    if (this.connectionMode === 2) {
      this.onConnectRdp();
      return;
    }
    if (this.connectionMode === 3) {
      this.onOpenTransfer();
      return;
    }
    this.onConnectRemote();
  }

  /**
   * The mode a record's own protocol selects.
   *
   * The mode indexes the segmented control and picks the primary action
   * (0 RustDesk, 1 VNC, 2 RDP), so a selected record's protocol has to be
   * remembered here: the target field only keeps the bare address, and the
   * address of a VNC or RDP peer may be spelled exactly like a RustDesk one.
   */
  private connectionModeForProtocol(protocol: PeerProtocol): number {
    if (protocol === 'vnc') {
      return 1;
    }
    return protocol === 'rdp' ? 2 : 0;
  }

  private recentPreview(): PeerRecord[] {
    const limit = this.isCompact() ? 4 : 6;
    const result: PeerRecord[] = [];
    for (let index = 0; index < this.directorySnapshot.recent.length && index < limit; index += 1) {
      result.push(this.directorySnapshot.recent[index]);
    }
    return result;
  }

  private recentRowStarts(): number[] {
    const starts: number[] = [];
    const peers = this.recentPreview();
    for (let index = 0; index < peers.length; index += 2) {
      starts.push(index);
    }
    return starts;
  }

  /**
   * One (protocol, target) tuple per card, JSON-encoded.
   *
   * Joining the fields with a character cannot be inverted while the fields may
   * contain that character, so `a-rustdesk-b` + `c` and `a` + `b-rustdesk-c`
   * used to spell the same key. ArkUI leaves the rendering of duplicate keys
   * unspecified, so the encoding has to be unambiguous.
   */
  private recentPeerRenderKey(peer: PeerRecord): string {
    return JSON.stringify([peerProtocolOf(peer), peer.id]);
  }

  /**
   * One rendered row of the recent grid, keyed by its revision and both cards.
   *
   * Rows change identity when the row's own contents change, and the key has to
   * distinguish the two cards of the row for the same reason the cards are
   * tuple-encoded above.
   */
  private recentRowRenderKey(start: number): string {
    const peers = this.recentPreview();
    const first = this.recentPeerRenderKey(peers[start]);
    const second = start + 1 < peers.length ? this.recentPeerRenderKey(peers[start + 1]) : '';
    return JSON.stringify(['recent-row', `${this.directorySnapshot.revision}`, first, second]);
  }

  private recentPeerName(peer: PeerRecord): string {
    return peerDisplayTitle(peer);
  }

  private recentPeerTarget(peer: PeerRecord): string {
    return deviceConnectionTarget(peer);
  }

  private recentPeerSubtitle(peer: PeerRecord): string {
    return peerDisplaySubtitle(peer);
  }

  private recentPeerStatus(peer: PeerRecord): ResourceStr {
    const state = peerOnlineState(peerReachability(peer));
    if (state === 'unknown') {
      return $r('app.string.device_status_checking');
    }
    return state === 'online'
      ? $r('app.string.device_status_online')
      : $r('app.string.device_status_offline');
  }

  private recentPeerStatusColor(peer: PeerRecord): ResourceColor {
    const state = peerOnlineState(peerReachability(peer));
    if (state === 'unknown') {
      return $r('app.color.info');
    }
    return state === 'online'
      ? $r('app.color.success')
      : $r('app.color.neu_text_secondary');
  }

  @Builder
  private StageHeader() {
    Row({ space: 12 }) {
      SymbolGlyph(this.modeSymbol())
        .fontSize(30)
        .fontColor([$r('app.color.neu_accent')]);

      Column({ space: 2 }) {
        Text(this.modeTitle())
          .width('100%')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.neu_text_primary'));
        Text(this.modeDescription())
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.neu_text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width(this.controlWidth())
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private ConnectionStage() {
    Column() {
      this.StageHeader();

      LuminousSegmentedControl({
        items: this.modeItems(),
        selectedIndex: this.connectionMode,
        controlWidth: this.controlWidth(),
        controlHeight: 50,
        motionEnabled: true,
        onChange: (index: number): void => {
          this.onConnectionModeChange(index);
        },
      })
        .margin({ top: -6 })
        .translate({ x: this.compactControlVisualOffsetX() })

      LuminousTextField({
        value: this.target,
        placeholder: this.targetPlaceholder(),
        fieldWidth: this.controlWidth(),
        fieldHeight: 54,
        motionEnabled: true,
        onChange: (value: string): void => this.onTargetChange(value),
      })
        .margin({ top: -26 })
        .translate({ x: this.compactControlVisualOffsetX() })

      if (this.targetIssue() !== '') {
        Text(targetFieldIssueText(this.modeKind(), this.targetIssue()))
          .width(this.controlWidth())
          .padding({ left: 4, right: 4 })
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.error'))
          .margin({ top: -20, bottom: 20 })
          .translate({ x: this.compactControlVisualOffsetX() })
      }

      LuminousButton({
        label: this.primaryActionLabel(),
        controlWidth: this.controlWidth(),
        controlSizeMode: LuminousControlSize.Regular,
        tone: LuminousTone.Accent,
        isEnabled: (!this.easyTierBusy || !this.easyTierAvailable || !this.easyTierEnabled)
          && (this.targetReady() || (this.connectionMode === 3 && this.transferActive)),
        motionEnabled: true,
        onAction: (): void => this.activatePrimaryAction(),
      })
        .margin({ top: -28 })
        .translate({ x: this.compactControlVisualOffsetX() })

      if (this.easyTierAvailable) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.link'))
            .fontSize(13)
            .fontColor([$r('app.color.neu_accent')]);
          Text('联动 EasyTier 预组网；实例未运行时将先请求启动')
            .layoutWeight(1)
            .fontSize(11)
            .lineHeight(17)
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width(this.controlWidth())
        .padding({ left: 4, right: 4 })
        .alignItems(VerticalAlign.Center)
        .margin({ top: -16 })

        Row() {
          LuminousSecondaryMenu({
            items: this.easyTierMenuItems(),
            selectedIndex: this.easyTierMenuSelectedIndex(),
            controlWidth: this.easyTierMenuControlWidth(),
            mainHeight: this.easyTierMenuHeight(),
            itemHeight: 52,
            accessibilityLabel: 'EasyTier 预组网方式',
            handleAccessibilityLabel: '展开 EasyTier 预组网方式',
            isEnabled: !this.easyTierBusy,
            motionEnabled: true,
            onChange: (index: number): void => this.commitEasyTierMenuIndex(index),
          })
        }
        .width(this.stageFrameWidth())
        .height(this.easyTierMenuFrameHeight())
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .clip(false)
        .zIndex(200)
        .margin({ top: -22 })
        .translate({ x: this.compactControlVisualOffsetX() })
      }

      if (this.canDisconnect) {
        LuminousButton({
          label: '断开当前会话',
          controlWidth: Math.min(180, this.controlWidth()),
          controlSizeMode: LuminousControlSize.Compact,
          tone: LuminousTone.Danger,
          motionEnabled: true,
          onAction: (): void => this.onDisconnect(),
        })
          .margin({ top: -22 })
          .translate({ x: this.compactControlVisualOffsetX() })
      }
    }
    .width(this.stageFrameWidth())
    .flexShrink(0)
    .zIndex(200)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private EmptyRecent() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: 0.3,
        surfaceWidth: this.recentContentWidth(),
        surfaceHeight: 72,
        cornerRadius: 20,
        motionEnabled: false,
      }) {
        Row({ space: 14 }) {
          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(26)
            .fontColor([$r('app.color.neu_accent')]);
          Column({ space: 4 }) {
            Text('这里还没有设备')
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_text_primary'));
            Text('首次连接完成后，会在这里保留最近使用的设备。')
              .width('100%')
              .fontSize(11)
              .lineHeight(17)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(2);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width(this.recentContentWidth())
        .height(72)
        .padding({ left: 20, right: 20 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.recentFrameWidth())
    .height(80)
    .clip(false);
  }

  @Builder
  private CompactRecentCard(peer: PeerRecord) {
    Stack({ alignContent: Alignment.Center }) {
      Stack() {
        FloatingActionSurface({
          subtleDepth: true,
          actionEnabled: this.recentPeerTarget(peer).length > 0,
          accessibilityLabel: `选择设备 ${this.recentPeerName(peer)}，填入 ${this.recentPeerTarget(peer)}`,
          onActivate: (): void => {
            this.onConnectionModeChange(this.connectionModeForProtocol(peerProtocolOf(peer)));
            this.onTargetChange(this.recentPeerTarget(peer));
          },
        }) {
          Stack({ alignContent: Alignment.TopStart }) {
            Text(this.recentPeerStatus(peer))
              .width('100%')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.recentPeerStatusColor(peer))
              .opacity(0.16)
              .textAlign(TextAlign.End)
              .maxLines(1)
              .translate({ x: 10, y: -10 })
              .zIndex(0);

            Column({ space: 3 }) {
              Text(this.recentPeerName(peer))
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.neu_text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Row({ space: 6 }) {
                Text(this.recentPeerSubtitle(peer))
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontColor($r('app.color.neu_text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
                Text(peerProtocolName(peerProtocolOf(peer)))
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(peerProtocolOf(peer) === 'vnc'
                    ? $r('app.color.brand_secondary') : $r('app.color.brand_primary'))
                  .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                  .borderRadius($r('app.float.radius_6'))
                  .backgroundColor($r('app.color.mica_control'));
              }
              .width('100%')
              .alignItems(VerticalAlign.Center);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .zIndex(1);
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 14 })
          .clip(true);
        }
      }
      .width(this.recentCardContentWidth())
      .height(72)
      .clip(false);
    }
    .width(this.recentCardFrameWidth())
    .height(80)
    .clip(false);
  }

  @Builder
  private RecentWorkspace() {
    Column() {
      List({ scroller: this.scroller }) {
        ListItem() {
          Column({ space: 6 }) {
            if (this.recentPreview().length === 0) {
              this.EmptyRecent();
            } else {
              ForEach(this.recentRowStarts(), (start: number) => {
                Row({ space: 8 }) {
                  this.CompactRecentCard(this.recentPreview()[start]);
                  if (start + 1 < this.recentPreview().length) {
                    this.CompactRecentCard(this.recentPreview()[start + 1]);
                  } else {
                    Blank()
                      .width(this.recentCardFrameWidth())
                      .height(80);
                  }
                }
                .width(this.recentFrameWidth())
                .height(80)
                .justifyContent(FlexAlign.Center)
                .clip(false);
              }, (start: number) => this.recentRowRenderKey(start));
            }
          }
          .width(this.recentFrameWidth())
          .padding({
            top: 7,
            bottom: (this.wideLayout ? 52 : 132) + this.bottomAvoidInset,
          })
          .alignItems(HorizontalAlign.Center);
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .clip(true)
      .zIndex(0);
    }
    .width('100%')
    .height('100%')
    .clip(true);
  }

  @Builder
  private Workspace() {
    if (this.isCompact()) {
      Column({ space: 4 }) {
        this.ConnectionStage();
        Stack() {
          this.RecentWorkspace();
        }
        .layoutWeight(1)
        .width(this.recentFrameWidth())
        .clip(false)
        .zIndex(0)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: this.useWideContentAnchor() ? this.wideWorkspaceLeftInset() : 0 })
      .alignItems(this.useWideContentAnchor() ? HorizontalAlign.Start : HorizontalAlign.Center);
    } else {
      Row({ space: 44 }) {
        this.ConnectionStage();
        Stack() {
          this.RecentWorkspace();
        }
        .width(this.recentFrameWidth())
        .height('100%')
        .clip(false)
        .zIndex(0)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: this.useWideContentAnchor() ? this.wideWorkspaceLeftInset() : 0 })
      .justifyContent(this.useWideContentAnchor() ? FlexAlign.Start : FlexAlign.Center)
      .alignItems(VerticalAlign.Top);
    }
  }

  build() {
    Column() {
      Blank()
        .width('100%')
        .height(this.titleSpacerHeight)
        .flexShrink(0);
      this.Workspace();
    }
    .width('100%')
    .height('100%')
    .padding({ top: RustDeskLayoutTokens.PAGE_CONTENT_TOP_PADDING })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.neu_base'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
