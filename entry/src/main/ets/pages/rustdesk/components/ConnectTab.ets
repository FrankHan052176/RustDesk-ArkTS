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
  peerDisplayTitle,
  peerProtocolName,
  peerProtocolOf,
  peerStatusKind,
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
  /** A recent device was tapped: connect to it with its own protocol. */
  onConnectPeer: (target: string, protocol: PeerProtocol, rustdeskIdOnly: boolean) => void;
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
  @Event onConnectPeer: (target: string, protocol: PeerProtocol, rustdeskIdOnly: boolean) => void =
    (_target: string, _protocol: PeerProtocol, _rustdeskIdOnly: boolean) => {};

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
    return RustDeskLayoutTokens.WIDE_CONTENT_EDGE;
  }

  private controlWidth(): number {
    if (this.isCompact()) {
      return Math.max(0, Math.min(this.viewportWidth - this.homeVisualPadding() * 2, 520));
    }
    // Both column frames include shadows; their sum plus the 36vp gap must
    // fit the content pane, not the full display behind the navigation rail.
    return Math.min(400, (this.viewportWidth - 36) / 2 - this.homeVisualPadding() * 2);
  }

  /**
   * All home content shares one visual frame.  The largest home card is 72vp
   * high, so its shadow safety area is the common horizontal frame; smaller
   * controls remain centered inside it instead of needing a per-control nudge.
   */
  private homeVisualPadding(): number {
    return LuminousNeoTokens.shadowPaddingFor(72);
  }

  private stageFrameWidth(): number {
    return this.controlWidth() + this.homeVisualPadding() * 2;
  }

  private secondaryMenuControlWidth(): number {
    // LuminousSecondaryMenu places a 40vp handle 10vp after the main body.
    // Reserve both within the same body width as the other home controls.
    return this.controlWidth() - 10 - 40;
  }

  private recentFrameWidth(): number {
    return this.stageFrameWidth();
  }

  private recentContentWidth(): number {
    return this.controlWidth();
  }

  private recentColumnCount(): number {
    return this.isCompact() ? 1 : 2;
  }

  private recentCardWidth(): number {
    if (this.recentColumnCount() === 1) {
      return this.controlWidth();
    }
    // Space the bodies, not their shadow frames. Adjacent shadows may overlap;
    // only the whole row needs the outer safety padding in RecentCards.
    return (this.recentContentWidth() - 16) / 2;
  }

  private recentCardContentWidth(): number {
    return this.recentCardWidth();
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
      new LuminousSelectionItem('control', '远控', '查看并操作对方设备'),
      new LuminousSelectionItem('vnc', 'VNC', '连接开启了 VNC 的设备'),
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
      ? `${instance.instanceName} · ${state} · ${instance.peerCount} 个节点`
      : `${instance.instanceName} · ${state}`;
  }

  private easyTierMenuItems(): LuminousSelectionItem[] {
    const items: LuminousSelectionItem[] = [
      new LuminousSelectionItem('direct', '不组网（RustDesk 直连）', '不使用 EasyTier，直接连接对方设备'),
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

  private easyTierMenuFrameX(): number {
    // Align the complete body + handle span with the other control bodies;
    // the component's own left shadow padding is already part of its root.
    return this.homeVisualPadding() - LuminousNeoTokens.shadowPaddingFor(this.easyTierMenuHeight());
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
    const step = this.recentColumnCount();
    for (let index = 0; index < peers.length; index += step) {
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
    return peer.note.trim();
  }

  /** The directory card's claim, in the words of the evidence behind it. */
  private recentPeerStatus(peer: PeerRecord): ResourceStr {
    const kind = peerStatusKind(peer);
    if (kind === 'unknown') {
      return $r('app.string.device_status_checking');
    }
    if (kind === 'online') {
      return $r('app.string.device_status_online');
    }
    if (kind === 'offline') {
      return $r('app.string.device_status_offline');
    }
    return kind === 'reachable'
      ? $r('app.string.device_status_reachable')
      : $r('app.string.device_status_unreachable');
  }

  private recentPeerStatusColor(peer: PeerRecord): ResourceColor {
    const kind = peerStatusKind(peer);
    if (kind === 'unknown') {
      return $r('app.color.info');
    }
    return kind === 'online' || kind === 'reachable'
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
        .margin({ top: -4 })

      LuminousTextField({
        value: this.target,
        placeholder: this.targetPlaceholder(),
        fieldWidth: this.controlWidth(),
        fieldHeight: 54,
        motionEnabled: true,
        onChange: (value: string): void => this.onTargetChange(value),
      })
        .margin({ top: -26 })

      if (this.targetIssue() !== '') {
        Text(targetFieldIssueText(this.modeKind(), this.targetIssue()))
          .width(this.controlWidth())
          .padding({ left: 4, right: 4 })
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.error'))
          .margin({ top: -20, bottom: 20 });
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
        .margin({ top: -26 })

      if (this.easyTierAvailable) {
        Stack({ alignContent: Alignment.TopStart }) {
          LuminousSecondaryMenu({
            items: this.easyTierMenuItems(),
            selectedIndex: this.easyTierMenuSelectedIndex(),
            controlWidth: this.secondaryMenuControlWidth(),
            mainHeight: this.easyTierMenuHeight(),
            itemHeight: 52,
            accessibilityLabel: 'EasyTier 预组网方式',
            handleAccessibilityLabel: '展开 EasyTier 预组网方式',
            isEnabled: !this.easyTierBusy,
            motionEnabled: true,
            onChange: (index: number): void => this.commitEasyTierMenuIndex(index),
          })
            .position({ x: this.easyTierMenuFrameX(), y: 0 });
        }
        .width(this.stageFrameWidth())
        .height(this.easyTierMenuFrameHeight())
        .clip(false)
        .zIndex(200)
        .margin({ top: -24 })
      }

      if (this.canDisconnect) {
        LuminousButton({
          label: '断开当前会话',
          controlWidth: Math.min(200, this.controlWidth()),
          controlSizeMode: LuminousControlSize.Compact,
          tone: LuminousTone.Danger,
          motionEnabled: true,
          onAction: (): void => this.onDisconnect(),
        })
          .margin({ top: -22 });
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
          accessibilityLabel: `连接 ${this.recentPeerName(peer)}`,
          onActivate: (): void => {
            // The same tap on the devices page connects; it does here too. The
            // field and the mode still show what was connected to.
            this.onConnectionModeChange(this.connectionModeForProtocol(peerProtocolOf(peer)));
            this.onTargetChange(this.recentPeerTarget(peer));
            this.onConnectPeer(this.recentPeerTarget(peer), peerProtocolOf(peer), peer.rustdeskIdOnly);
          },
        }) {
          Stack({ alignContent: Alignment.TopStart }) {
            Column({ space: 3 }) {
              Text(this.recentPeerName(peer))
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.neu_text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Row({ space: 6 }) {
                if (this.recentPeerSubtitle(peer).length > 0) {
                  Text(this.recentPeerSubtitle(peer))
                    .layoutWeight(1)
                    .fontSize(12)
                    .fontColor($r('app.color.neu_text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                } else {
                  Blank()
                    .layoutWeight(1);
                }
                Text(this.recentPeerStatus(peer))
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.recentPeerStatusColor(peer))
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
    .width(this.recentCardContentWidth())
    .height(80)
    .clip(false);
  }

  @Builder
  private RecentCards() {
    Column({ space: 6 }) {
      if (this.recentPreview().length === 0) {
        this.EmptyRecent();
      } else {
        ForEach(this.recentRowStarts(), (start: number) => {
          if (this.recentColumnCount() === 1) {
            Row() {
              this.CompactRecentCard(this.recentPreview()[start]);
            }
            .width(this.recentFrameWidth())
            .height(80)
            .justifyContent(FlexAlign.Center)
            .clip(false);
          } else {
            Row({ space: 16 }) {
              this.CompactRecentCard(this.recentPreview()[start]);
              if (start + 1 < this.recentPreview().length) {
                this.CompactRecentCard(this.recentPreview()[start + 1]);
              } else {
                Blank()
                  .width(this.recentCardContentWidth())
                  .height(80);
              }
            }
            .width(this.recentContentWidth())
            .height(80)
            .justifyContent(FlexAlign.Start)
            .clip(false);
          }
        }, (start: number) => this.recentRowRenderKey(start));
      }
    }
    .width(this.recentFrameWidth())
    .padding({ top: 7 })
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private RecentWorkspace() {
    Column() {
      List({ scroller: this.scroller }) {
        ListItem() {
          Column() {
            this.RecentCards();
          }
          .width(this.recentFrameWidth())
          .padding({ bottom: (this.wideLayout ? 52 : 132) + this.bottomAvoidInset });
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
  private WideWorkspace() {
    Row({ space: 36 }) {
      this.ConnectionStage();
      Stack() {
        this.RecentWorkspace();
      }
      .width(this.recentFrameWidth())
      .height('100%')
      .clip(false)
      .zIndex(0);
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Top);
  }

  @Builder
  private CompactWorkspace() {
    Scroll(this.scroller) {
      Column() {
        Blank()
          .width('100%')
          .height(this.pageTopClearance());
        Column({ space: 16 }) {
          this.ConnectionStage();
          this.RecentCards();
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center);
      }
      .width('100%')
      .padding({ bottom: (this.wideLayout ? 52 : 132) + this.bottomAvoidInset })
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
  }

  private pageTopClearance(): number {
    return this.wideLayout ? Math.max(this.titleSpacerHeight + 36, 56) : Math.max(this.titleSpacerHeight, 40);
  }

  build() {
    Column() {
      if (this.isCompact()) {
        this.CompactWorkspace();
      } else {
        Blank()
          .width('100%')
          .height(this.pageTopClearance())
          .flexShrink(0);
        this.WideWorkspace();
      }
    }
    .width('100%')
    .height('100%')
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
