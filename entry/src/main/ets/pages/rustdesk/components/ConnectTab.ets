import {
  LuminousButton,
  LuminousControlSize,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSurface,
  LuminousTextField,
  LuminousTone,
} from 'luminous_neo';
import { DirectorySnapshot, PeerRecord } from '../RustDeskDirectoryTypes';
import { RustDeskLayoutTokens } from '../RustDeskLayoutTokens';
import { PeerCard } from './PeerCard';

export interface ConnectTabProps {
  target: string;
  rememberPassword: boolean;
  scroller: Scroller;
  onTargetChange: (value: string) => void;
  onConnectRemote: () => void;
  onViewOnly: () => void;
  onViewCamera: () => void;
  onOpenTransfer: () => void;
  onDisconnect: () => void;
  canDisconnect: boolean;
  transferActive: boolean;
  activeTransferPeerId: string;
  wideLayout: boolean;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  directorySnapshot: DirectorySnapshot;
  onSetPeerFavorite: (peerId: string, favorite: boolean) => void;
  onRemoveRecentPeer: (peerId: string) => void;
  onConnectPeerRemote: (peerId: string) => void;
  onViewPeerOnly: (peerId: string) => void;
  onViewPeerCamera: (peerId: string) => void;
  onOpenPeerTransfer: (peerId: string) => void;
}

@ComponentV2
export struct ConnectTab {
  @Param target: string = '';
  @Param rememberPassword: boolean = false;
  @Param canDisconnect: boolean = false;
  @Param transferActive: boolean = false;
  @Param activeTransferPeerId: string = '';
  @Param wideLayout: boolean = false;
  @Param titleSpacerHeight: number = 56;
  @Param bottomAvoidInset: number = 0;
  @Param directorySnapshot: DirectorySnapshot = new DirectorySnapshot();
  @Param scroller: Scroller = new Scroller();
  @Local viewportWidth: number = 390;
  @Local connectionMode: number = 0;
  @Event onTargetChange: (value: string) => void = (_value: string) => {};
  @Event onConnectRemote: () => void = () => {};
  @Event onViewOnly: () => void = () => {};
  @Event onViewCamera: () => void = () => {};
  @Event onOpenTransfer: () => void = () => {};
  @Event onDisconnect: () => void = () => {};
  @Event onSetPeerFavorite: (peerId: string, favorite: boolean) => void = (_peerId: string, _favorite: boolean) => {};
  @Event onRemoveRecentPeer: (peerId: string) => void = (_peerId: string) => {};
  @Event onConnectPeerRemote: (peerId: string) => void = (_peerId: string) => {};
  @Event onViewPeerOnly: (peerId: string) => void = (_peerId: string) => {};
  @Event onViewPeerCamera: (peerId: string) => void = (_peerId: string) => {};
  @Event onOpenPeerTransfer: (peerId: string) => void = (_peerId: string) => {};

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

  private recentFrameWidth(): number {
    if (this.isCompact()) {
      return this.stageFrameWidth();
    }
    return Math.max(430, Math.min(this.viewportWidth - this.stageFrameWidth() - 150, 620));
  }

  private recentContentWidth(): number {
    if (this.isCompact()) {
      return this.controlWidth();
    }
    return Math.max(390, this.recentFrameWidth() - 40);
  }

  private targetReady(): boolean {
    return this.target.trim().length > 0;
  }

  private modeItems(): LuminousSelectionItem[] {
    return [
      new LuminousSelectionItem('control', '远程控制', '控制远端设备'),
      new LuminousSelectionItem('view_only', '只看屏幕', '观看远端屏幕，不发送输入'),
      new LuminousSelectionItem('camera', '查看相机', '查看远端摄像头'),
      new LuminousSelectionItem('files', '文件传输', '浏览并传输文件'),
    ];
  }

  private modeSymbol(): Resource {
    if (this.connectionMode === 1) {
      return $r('sys.symbol.display');
    }
    if (this.connectionMode === 2) {
      return $r('sys.symbol.video');
    }
    if (this.connectionMode === 3) {
      return $r('sys.symbol.folder');
    }
    return $r('sys.symbol.display');
  }

  private modeTitle(): ResourceStr {
    if (this.connectionMode === 1) {
      return '观看远端屏幕';
    }
    if (this.connectionMode === 2) {
      return '查看远端相机';
    }
    if (this.connectionMode === 3) {
      return '打开文件工作区';
    }
    return '建立远程控制';
  }

  private modeDescription(): ResourceStr {
    if (this.connectionMode === 1) {
      return '只查看远端画面，不发送键鼠、触摸或剪贴板输入';
    }
    if (this.connectionMode === 2) {
      return '只查看视频，不发送键鼠输入';
    }
    if (this.connectionMode === 3) {
      return '在本机与远端之间浏览和传输文件';
    }
    return '连接后使用触摸、键鼠或触控板操作远端';
  }

  private primaryActionLabel(): ResourceStr {
    if (this.connectionMode === 1) {
      return '只看屏幕';
    }
    if (this.connectionMode === 2) {
      return '查看相机';
    }
    if (this.connectionMode === 3) {
      return this.transferActive ? '返回文件传输' : '开始文件传输';
    }
    return this.canDisconnect ? '建立新连接' : '开始连接';
  }

  private activatePrimaryAction(): void {
    if (this.connectionMode === 1) {
      this.onViewOnly();
      return;
    }
    if (this.connectionMode === 2) {
      this.onViewCamera();
      return;
    }
    if (this.connectionMode === 3) {
      this.onOpenTransfer();
      return;
    }
    this.onConnectRemote();
  }

  private recentPreview(): PeerRecord[] {
    const limit = 2;
    const result: PeerRecord[] = [];
    for (let index = 0; index < this.directorySnapshot.recent.length && index < limit; index += 1) {
      result.push(this.directorySnapshot.recent[index]);
    }
    return result;
  }

  @Builder
  private StageHeader() {
    Row({ space: 14 }) {
      SymbolGlyph(this.modeSymbol())
        .fontSize(32)
        .fontColor([$r('app.color.neu_accent')]);

      Column({ space: 3 }) {
        Text(this.modeTitle())
          .width('100%')
          .fontSize(20)
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
    Column({ space: 2 }) {
      this.StageHeader();

      LuminousSegmentedControl({
        items: this.modeItems(),
        selectedIndex: this.connectionMode,
        controlWidth: this.controlWidth(),
        controlHeight: 50,
        motionEnabled: true,
        onChange: (index: number): void => {
          this.connectionMode = index;
        },
      })

      LuminousTextField({
        value: this.target,
        placeholder: '输入设备 ID',
        fieldWidth: this.controlWidth(),
        fieldHeight: 54,
        motionEnabled: true,
        onChange: (value: string): void => this.onTargetChange(value),
      })
        .margin({ top: -18 })

      Row({ space: 8 }) {
        Circle()
          .width(7)
          .height(7)
          .fill(this.canDisconnect ? $r('app.color.success') : $r('app.color.neu_text_disabled'));
        Text(this.canDisconnect
          ? '当前会话仍在运行，可同时准备下一台设备'
          : (this.rememberPassword ? '已启用本机会话密码记忆' : '密码会在远端需要时单独请求'))
          .layoutWeight(1)
          .fontSize(11)
          .fontColor($r('app.color.neu_text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width(this.controlWidth())
      .padding({ left: 4, right: 4 })
      .margin({ top: -6 })
      .alignItems(VerticalAlign.Center);

      LuminousButton({
        label: this.primaryActionLabel(),
        controlWidth: this.controlWidth(),
        controlSizeMode: LuminousControlSize.Regular,
        tone: LuminousTone.Accent,
        isEnabled: this.targetReady() || (this.connectionMode === 3 && this.transferActive),
        motionEnabled: true,
        onAction: (): void => this.activatePrimaryAction(),
      })
        .margin({ top: -8 })

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
      }
    }
    .width(this.stageFrameWidth())
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private RecentHeader() {
    Row() {
      Column({ space: 3 }) {
        Text('最近设备')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.neu_text_primary'));
        Text('继续上一次远程工作')
          .fontSize(12)
          .fontColor($r('app.color.neu_text_secondary'));
      }
      .alignItems(HorizontalAlign.Start);
      Blank();
      Text(`${this.directorySnapshot.recent.length}`)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.neu_accent'));
    }
    .width(this.recentContentWidth())
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private EmptyRecent() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: 1,
        surfaceWidth: this.recentContentWidth(),
        surfaceHeight: 96,
        cornerRadius: 24,
        motionEnabled: true,
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
        .height(96)
        .padding({ left: 20, right: 20 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.recentFrameWidth())
    .height(128)
    .clip(false);
  }

  @Builder
  private RecentWorkspace() {
    Column({ space: 16 }) {
      this.RecentHeader();
      if (this.recentPreview().length === 0) {
        this.EmptyRecent();
      } else {
        ForEach(this.recentPreview(), (peer: PeerRecord) => {
          PeerCard({
            peer: peer,
            compact: true,
            cardWidth: this.recentContentWidth(),
            transferActive: this.activeTransferPeerId === peer.id,
            onSetFavorite: (peerId: string, favorite: boolean) => this.onSetPeerFavorite(peerId, favorite),
            onRemoveRecent: (peerId: string) => this.onRemoveRecentPeer(peerId),
            onConnectRemote: (peerId: string) => this.onConnectPeerRemote(peerId),
            onViewOnly: (peerId: string) => this.onViewPeerOnly(peerId),
            onViewCamera: (peerId: string) => this.onViewPeerCamera(peerId),
            onOpenTransfer: (peerId: string) => this.onOpenPeerTransfer(peerId),
          })
            .width(this.recentContentWidth());
        }, (peer: PeerRecord) => `recent-${peer.id}`);
      }
    }
    .width(this.recentFrameWidth())
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private Workspace() {
    if (this.isCompact()) {
      Column({ space: 12 }) {
        this.ConnectionStage();
        this.RecentWorkspace();
      }
      .width('100%')
      .padding({ left: this.useWideContentAnchor() ? this.wideWorkspaceLeftInset() : 0 })
      .alignItems(this.useWideContentAnchor() ? HorizontalAlign.Start : HorizontalAlign.Center);
    } else {
      Row({ space: 44 }) {
        this.ConnectionStage();
        this.RecentWorkspace();
      }
      .width('100%')
      .padding({ left: this.useWideContentAnchor() ? this.wideWorkspaceLeftInset() : 0 })
      .justifyContent(this.useWideContentAnchor() ? FlexAlign.Start : FlexAlign.Center)
      .alignItems(VerticalAlign.Top);
    }
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        Blank()
          .width('100%')
          .height(this.titleSpacerHeight)
          .flexShrink(0);
        this.Workspace();
      }
      .width('100%')
      .padding({
        top: RustDeskLayoutTokens.PAGE_CONTENT_TOP_PADDING,
        bottom: (this.wideLayout ? 52 : 132) + this.bottomAvoidInset,
      })
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .backgroundColor($r('app.color.neu_base'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
