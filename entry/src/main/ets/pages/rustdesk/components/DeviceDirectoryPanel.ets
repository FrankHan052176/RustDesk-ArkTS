import {
  LuminousSearchField,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSurface,
} from 'luminous_neo';
import {
  DirectorySnapshot,
  PeerRecord,
  PeerSource,
} from '../RustDeskDirectoryTypes';
import { RustDeskLayoutTokens } from '../RustDeskLayoutTokens';
import { PeerCard } from './PeerCard';

export interface DeviceDirectoryPanelProps {
  snapshot: DirectorySnapshot;
  wideLayout: boolean;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  activeTransferPeerId: string;
  recentScroller: Scroller;
  addressBookScroller: Scroller;
  lanScroller: Scroller;
  onRefresh: () => void;
  onScanLan: () => void;
  onSetFavorite: (peerId: string, favorite: boolean) => void;
  onRemoveRecent: (peerId: string) => void;
  onConnectRemote: (peerId: string) => void;
  onViewOnly: (peerId: string) => void;
  onViewCamera: (peerId: string) => void;
  onOpenTransfer: (peerId: string) => void;
}

@ComponentV2
export struct DeviceDirectoryPanel {
  @Param snapshot: DirectorySnapshot = new DirectorySnapshot();
  @Param wideLayout: boolean = false;
  @Param titleSpacerHeight: number = 56;
  @Param bottomAvoidInset: number = 0;
  @Param activeTransferPeerId: string = '';
  @Param recentScroller: Scroller = new Scroller();
  @Param addressBookScroller: Scroller = new Scroller();
  @Param lanScroller: Scroller = new Scroller();
  @Local activeSource: PeerSource = 'recent';
  @Local query: string = '';
  @Local viewportWidth: number = 390;
  @Local lanRefreshing: boolean = false;
  @Local lanRefreshStatus: RefreshStatus = RefreshStatus.Inactive;
  @Local pressedEmptySource: string = '';
  private swiperController: SwiperController = new SwiperController();
  @Event onRefresh: () => void = () => {};
  @Event onScanLan: () => void = () => {};
  @Event onSetFavorite: (peerId: string, favorite: boolean) => void = (_peerId: string, _favorite: boolean) => {};
  @Event onRemoveRecent: (peerId: string) => void = (_peerId: string) => {};
  @Event onConnectRemote: (peerId: string) => void = (_peerId: string) => {};
  @Event onViewOnly: (peerId: string) => void = (_peerId: string) => {};
  @Event onViewCamera: (peerId: string) => void = (_peerId: string) => {};
  @Event onOpenTransfer: (peerId: string) => void = (_peerId: string) => {};

  aboutToAppear(): void {
    this.lanRefreshing = this.snapshot.lanScanning;
  }

  @Monitor('snapshot')
  private onSnapshotChanged(_monitor: IMonitor): void {
    this.lanRefreshing = this.snapshot.lanScanning;
  }

  private isPhoneLayout(): boolean {
    return this.viewportWidth < 600;
  }

  private useWideContentAnchor(): boolean {
    return RustDeskLayoutTokens.useWideContentAnchor(this.viewportWidth, this.wideLayout);
  }

  private horizontalPadding(): number {
    if (this.viewportWidth >= 1440) {
      return 48;
    }
    if (this.viewportWidth >= 760 || this.wideLayout) {
      return 32;
    }
    return 20;
  }

  private pageFrameWidth(): number {
    return Math.min(this.viewportWidth, 1200);
  }

  private controlWidth(): number {
    return Math.max(280, this.pageFrameWidth() - this.horizontalPadding() * 2);
  }

  private sourceSwitcherTitleBarHeight(): number {
    return 50;
  }

  private sourceSwitcherContentInset(): number {
    return 14;
  }

  private pageContentTopPadding(): number {
    return this.wideLayout ? RustDeskLayoutTokens.PAGE_CONTENT_TOP_PADDING : 8;
  }

  private bottomPadding(): number {
    return (this.wideLayout ? 48 : 120) + this.bottomAvoidInset;
  }

  private columnCount(): number {
    if (this.viewportWidth >= 1240) {
      return 3;
    }
    if (this.viewportWidth >= 760) {
      return 2;
    }
    return 1;
  }

  private cardWidth(): string {
    if (this.columnCount() === 3) {
      return '32.4%';
    }
    if (this.columnCount() === 2) {
      return '49.2%';
    }
    return '100%';
  }

  private compactPeerCard(): boolean {
    return this.viewportWidth < 600 || this.columnCount() > 1;
  }

  private sourceIndex(source: PeerSource): number {
    if (source === 'addressBook') {
      return 1;
    }
    if (source === 'lan') {
      return 2;
    }
    return 0;
  }

  private sourceFromIndex(index: number): PeerSource {
    if (index === 1) {
      return 'addressBook';
    }
    if (index === 2) {
      return 'lan';
    }
    return 'recent';
  }

  private sourcePeers(source: PeerSource): PeerRecord[] {
    if (source === 'addressBook') {
      return this.snapshot.addressBook;
    }
    if (source === 'lan') {
      return this.snapshot.lan;
    }
    return this.snapshot.recent;
  }

  private sourceItems(): LuminousSelectionItem[] {
    return [
      new LuminousSelectionItem('recent', '最近', '最近连接的设备'),
      new LuminousSelectionItem('address-book', '通讯录', '通讯录中的设备'),
      new LuminousSelectionItem('lan', '局域网', '局域网发现的设备'),
    ];
  }

  private matchesQuery(peer: PeerRecord, query: string): boolean {
    if (peer.id.toLowerCase().includes(query)
      || peer.alias.toLowerCase().includes(query)
      || peer.hostname.toLowerCase().includes(query)
      || peer.username.toLowerCase().includes(query)
      || peer.platform.toLowerCase().includes(query)
      || peer.addressBookName.toLowerCase().includes(query)) {
      return true;
    }
    for (let index = 0; index < peer.tags.length; index += 1) {
      if (peer.tags[index].toLowerCase().includes(query)) {
        return true;
      }
    }
    return false;
  }

  private visiblePeers(source: PeerSource): PeerRecord[] {
    const peers = this.sourcePeers(source);
    const query = this.query.trim().toLowerCase();
    const visible: PeerRecord[] = [];
    for (let index = 0; index < peers.length; index += 1) {
      const peer = peers[index];
      if (peer.favorite && (query.length === 0 || this.matchesQuery(peer, query))) {
        visible.push(peer);
      }
    }
    for (let index = 0; index < peers.length; index += 1) {
      const peer = peers[index];
      if (!peer.favorite && (query.length === 0 || this.matchesQuery(peer, query))) {
        visible.push(peer);
      }
    }
    return visible;
  }

  private emptyText(source: PeerSource): ResourceStr {
    if (this.query.trim().length > 0) {
      return $r('app.string.device_empty_search');
    }
    if (source === 'addressBook') {
      return $r('app.string.device_empty_address_book');
    }
    if (source === 'lan') {
      return $r('app.string.device_empty_lan');
    }
    return $r('app.string.device_empty_recent');
  }

  private emptyTitle(source: PeerSource): ResourceStr {
    if (this.query.trim().length > 0) {
      return '没有匹配的设备';
    }
    if (source === 'addressBook') {
      return '通讯录还是空的';
    }
    if (source === 'lan') {
      return '附近暂未发现设备';
    }
    return '还没有最近设备';
  }

  private emptyActionLabel(source: PeerSource): ResourceStr {
    if (this.query.trim().length > 0) {
      return '清除搜索';
    }
    if (source === 'lan') {
      return '扫描局域网';
    }
    return '刷新设备';
  }

  private emptySymbol(source: PeerSource): Resource {
    if (this.query.trim().length > 0) {
      return $r('sys.symbol.magnifyingglass');
    }
    if (source === 'addressBook') {
      return $r('sys.symbol.person_2');
    }
    if (source === 'lan') {
      return $r('sys.symbol.wifi');
    }
    return $r('sys.symbol.clock');
  }

  private changeSource(index: number): void {
    const target = Math.max(0, Math.min(2, index));
    this.activeSource = this.sourceFromIndex(target);
    try {
      this.swiperController.changeIndex(target, true);
    } catch (_) {
    }
  }

  private startLanRefresh(): void {
    if (this.snapshot.lanScanning) {
      return;
    }
    this.lanRefreshing = true;
    this.onScanLan();
  }

  private lanRefreshPrompt(): ResourceStr {
    if (this.snapshot.lanScanning || this.lanRefreshing || this.lanRefreshStatus === RefreshStatus.Refresh) {
      return $r('app.string.device_scanning_lan');
    }
    if (this.lanRefreshStatus === RefreshStatus.OverDrag) {
      return $r('app.string.device_release_scan_lan');
    }
    return $r('app.string.device_pull_scan_lan');
  }

  private activateEmptyAction(source: PeerSource): void {
    if (this.query.trim().length > 0) {
      this.query = '';
      return;
    }
    if (source === 'lan') {
      this.startLanRefresh();
      return;
    }
    this.onRefresh();
  }

  @Builder
  private DirectorySearch() {
    Column() {
      LuminousSearchField({
        value: this.query,
        placeholder: $r('app.string.device_search_placeholder'),
        fieldWidth: this.controlWidth(),
        fieldHeight: 48,
        motionEnabled: true,
        onChange: (value: string): void => {
          this.query = value;
        },
      });
    }
    .width(this.controlWidth())
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private DirectorySourceSwitcherTitleBar() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        LuminousSegmentedControl({
          items: this.sourceItems(),
          selectedIndex: this.sourceIndex(this.activeSource),
          controlWidth: this.controlWidth(),
          controlHeight: this.sourceSwitcherTitleBarHeight(),
          motionEnabled: true,
          onChange: (index: number): void => this.changeSource(index),
        });
      }
      .width(this.controlWidth())
      .height(this.sourceSwitcherTitleBarHeight())
      .clip(false);
    }
    .width('100%')
    .height(this.sourceSwitcherTitleBarHeight())
    .padding({ left: this.useWideContentAnchor() ? RustDeskLayoutTokens.WIDE_CONTENT_EDGE : 0 })
    .justifyContent(this.useWideContentAnchor() ? FlexAlign.Start : FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .clip(false)
    .zIndex(2);
  }

  @Builder
  private EmptyState(source: PeerSource) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: this.pressedEmptySource === source ? -1 : 1,
        surfaceWidth: this.controlWidth(),
        surfaceHeight: 106,
        cornerRadius: 24,
        motionEnabled: true,
      }) {
        Row({ space: 14 }) {
          SymbolGlyph(this.emptySymbol(source))
            .width(38)
            .fontSize(30)
            .fontColor([$r('app.color.neu_accent')]);

          Column({ space: 3 }) {
            Text(this.emptyTitle(source))
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            Text(this.emptyText(source))
              .width('100%')
              .fontSize(11)
              .lineHeight(17)
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            Row({ space: 4 }) {
              Text(this.emptyActionLabel(source))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.neu_accent'));
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(11)
                .fontColor([$r('app.color.neu_accent')]);
            }
            .alignItems(VerticalAlign.Center);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width(this.controlWidth())
        .height(106)
        .padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center);
      }

      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row()
      }
      .width(this.controlWidth())
      .height(106)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .hoverEffect(HoverEffect.None)
      .borderRadius(24)
      .enabled(!(source === 'lan' && this.snapshot.lanScanning && this.query.trim().length === 0))
      .accessibilityText(this.emptyActionLabel(source) as Resource)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedEmptySource = source;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedEmptySource = '';
        }
      })
      .onClick(() => {
        this.pressedEmptySource = '';
        this.activateEmptyAction(source);
      });
    }
    .width(this.controlWidth())
    .height(122)
    .clip(false);
  }

  @Builder
  private PeerList(source: PeerSource) {
    if (this.visiblePeers(source).length === 0) {
      Row() {
        Column() {
          this.EmptyState(source);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center);
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);
    } else if (this.columnCount() === 1) {
      Column({ space: 18 }) {
        ForEach(this.visiblePeers(source), (peer: PeerRecord) => {
          PeerCard({
            peer: peer,
            compact: this.compactPeerCard(),
            transferActive: this.activeTransferPeerId === peer.id,
            onSetFavorite: (peerId: string, favorite: boolean) => this.onSetFavorite(peerId, favorite),
            onRemoveRecent: (peerId: string) => this.onRemoveRecent(peerId),
            onConnectRemote: (peerId: string) => this.onConnectRemote(peerId),
            onViewOnly: (peerId: string) => this.onViewOnly(peerId),
            onViewCamera: (peerId: string) => this.onViewCamera(peerId),
            onOpenTransfer: (peerId: string) => this.onOpenTransfer(peerId),
          });
        }, (peer: PeerRecord) => `${peer.source}-${peer.addressBookName}-${peer.id}-${peer.source === 'lan'
          ? peer.lanIp
          : ''}`);
      }
      .width(this.controlWidth())
      .alignItems(HorizontalAlign.Start);
    } else {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.visiblePeers(source), (peer: PeerRecord) => {
          PeerCard({
            peer: peer,
            compact: this.compactPeerCard(),
            transferActive: this.activeTransferPeerId === peer.id,
            onSetFavorite: (peerId: string, favorite: boolean) => this.onSetFavorite(peerId, favorite),
            onRemoveRecent: (peerId: string) => this.onRemoveRecent(peerId),
            onConnectRemote: (peerId: string) => this.onConnectRemote(peerId),
            onViewOnly: (peerId: string) => this.onViewOnly(peerId),
            onViewCamera: (peerId: string) => this.onViewCamera(peerId),
            onOpenTransfer: (peerId: string) => this.onOpenTransfer(peerId),
          })
            .width(this.cardWidth())
            .margin({ bottom: 18 });
        }, (peer: PeerRecord) => `${peer.source}-${peer.addressBookName}-${peer.id}-${peer.source === 'lan'
          ? peer.lanIp
          : ''}`);
      }
      .width(this.controlWidth());
    }
  }

  @Builder
  private SourceList(source: PeerSource, scroller: Scroller) {
    List({ scroller: scroller }) {
      ListItem() {
        Row() {
          Column() {
            Blank()
              .width('100%')
              .height(this.sourceSwitcherContentInset())
              .flexShrink(0);

            this.PeerList(source);
          }
          .width(this.controlWidth())
          .padding({
            bottom: this.bottomPadding(),
          })
          .alignItems(HorizontalAlign.Center)
          .clip(false);
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: this.useWideContentAnchor() ? RustDeskLayoutTokens.WIDE_CONTENT_EDGE : 0 })
        .justifyContent(this.useWideContentAnchor() ? FlexAlign.Start : FlexAlign.Center)
        .alignItems(VerticalAlign.Top)
        .clip(false);
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(false);
  }

  @Builder
  private LanRefreshIndicator() {
    Row({ space: 8 }) {
      LoadingProgress()
        .width(18)
        .height(18)
        .color($r('app.color.neu_accent'))
        .visibility(this.snapshot.lanScanning || this.lanRefreshing ? Visibility.Visible : Visibility.Hidden);
      Text(this.lanRefreshPrompt())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.lanRefreshStatus === RefreshStatus.OverDrag
          ? $r('app.color.neu_accent')
          : $r('app.color.neu_text_secondary'));
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private SourcePage(source: PeerSource, scroller: Scroller) {
    if (source === 'lan') {
      Refresh({
        refreshing: this.lanRefreshing!!,
        builder: this.LanRefreshIndicator(),
      }) {
        this.SourceList(source, scroller);
      }
      .width('100%')
      .height('100%')
      .refreshOffset(72)
      .pullDownRatio(0.72)
      .onStateChange((status: RefreshStatus) => this.lanRefreshStatus = status)
      .onRefreshing(() => this.startLanRefresh());
    } else {
      this.SourceList(source, scroller);
    }
  }

  build() {
    Column() {
      Blank()
        .width('100%')
        .height(this.titleSpacerHeight)
        .flexShrink(0);

      Row() {
        Column() {
          this.DirectorySearch();
        }
        .width(this.controlWidth())
        .alignItems(HorizontalAlign.Center);
      }
      .width('100%')
      .padding({
        left: this.useWideContentAnchor() ? RustDeskLayoutTokens.WIDE_CONTENT_EDGE : 0,
        top: this.pageContentTopPadding(),
        bottom: 0,
      })
      .justifyContent(this.useWideContentAnchor() ? FlexAlign.Start : FlexAlign.Center)
      .alignItems(VerticalAlign.Top);

      Column() {
        this.DirectorySourceSwitcherTitleBar();

        Swiper(this.swiperController) {
          this.SourcePage('recent', this.recentScroller);
          this.SourcePage('addressBook', this.addressBookScroller);
          this.SourcePage('lan', this.lanScroller);
        }
        .layoutWeight(1)
        .width('100%')
        .indicator(false)
        .loop(false)
        .duration(280)
        .onChange((index: number) => {
          this.activeSource = this.sourceFromIndex(index);
        });
      }
      .layoutWeight(1)
      .width('100%')
      .clip(false);
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
