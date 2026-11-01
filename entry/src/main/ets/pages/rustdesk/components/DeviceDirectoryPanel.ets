import {
  LuminousSearchField,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSurface,
} from 'luminous_neo';
import {
  DirectorySnapshot,
  PeerProtocol,
  PeerRecord,
  PeerViewSource,
} from '../RustDeskDirectoryTypes';
import { RustDeskLayoutTokens } from '../RustDeskLayoutTokens';
import { peerProtocolOf } from '../RustDeskPeerDirectoryModel';
import { PeerCard } from './PeerCard';
import { SavedDeviceEditor } from './SavedDeviceEditor';

export interface DeviceDirectoryPanelProps {
  snapshot: DirectorySnapshot;
  wideLayout: boolean;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  recentScroller: Scroller;
  favoriteScroller: Scroller;
  lanScroller: Scroller;
  addressBookScroller: Scroller;
  onRefresh: () => void;
  onScanLan: () => void;
  onStopLan: () => void;
  onSetFavorite: (target: string, protocol: PeerProtocol, favorite: boolean, rustdeskIdOnly: boolean) => void;
  onEditNote: (target: string, protocol: PeerProtocol, note: string, rustdeskIdOnly: boolean) => void;
  onRemoveRecent: (target: string, protocol: PeerProtocol, rustdeskIdOnly: boolean) => void;
  onRemoveLan: (target: string, protocol: PeerProtocol) => void;
  onConnectRemote: (peerId: string, rustdeskIdOnly: boolean) => void;
  onConnectVnc: (peerId: string) => void;
  onConnectRdp: (peerId: string) => void;
  onSaveDevice: (original: PeerRecord, peer: PeerRecord) => ResourceStr;
}

@ComponentV2
export struct DeviceDirectoryPanel {
  @Param snapshot: DirectorySnapshot = new DirectorySnapshot();
  @Param wideLayout: boolean = false;
  @Param titleSpacerHeight: number = 56;
  @Param bottomAvoidInset: number = 0;
  @Param recentScroller: Scroller = new Scroller();
  @Param favoriteScroller: Scroller = new Scroller();
  @Param lanScroller: Scroller = new Scroller();
  @Param addressBookScroller: Scroller = new Scroller();
  @Local activeSource: PeerViewSource = 'recent';
  @Local query: string = '';
  @Local viewportWidth: number = 390;
  @Local lanRefreshing: boolean = false;
  @Local lanRefreshStatus: RefreshStatus = RefreshStatus.Inactive;
  @Local pressedEmptySource: string = '';
  @Local deviceEditorVisible: boolean = false;
  @Local deviceEditorPeer: PeerRecord = new PeerRecord();
  private deviceEditorOriginal: PeerRecord = new PeerRecord();
  private swiperController: SwiperController = new SwiperController();
  @Event onRefresh: () => void = () => {};
  @Event onScanLan: () => void = () => {};
  @Event onStopLan: () => void = () => {};
  @Event onSetFavorite: (target: string, protocol: PeerProtocol, favorite: boolean, rustdeskIdOnly: boolean) => void =
    (_target: string, _protocol: PeerProtocol, _favorite: boolean, _rustdeskIdOnly: boolean) => {};
  @Event onEditNote: (target: string, protocol: PeerProtocol, note: string, rustdeskIdOnly: boolean) => void =
    (_target: string, _protocol: PeerProtocol, _note: string, _rustdeskIdOnly: boolean) => {};
  @Event onRemoveRecent: (target: string, protocol: PeerProtocol, rustdeskIdOnly: boolean) => void =
    (_target: string, _protocol: PeerProtocol, _rustdeskIdOnly: boolean) => {};
  @Event onRemoveLan: (target: string, protocol: PeerProtocol) => void =
    (_target: string, _protocol: PeerProtocol) => {};
  @Event onConnectRemote: (peerId: string, rustdeskIdOnly: boolean) => void =
    (_peerId: string, _rustdeskIdOnly: boolean) => {};
  @Event onConnectVnc: (peerId: string) => void = (_peerId: string) => {};
  @Event onConnectRdp: (peerId: string) => void = (_peerId: string) => {};
  @Event onSaveDevice: (original: PeerRecord, peer: PeerRecord) => ResourceStr =
    (_original: PeerRecord, _peer: PeerRecord): ResourceStr => $r('app.string.device_editor_save_unavailable');

  private editDevice(peer: PeerRecord): void {
    this.deviceEditorOriginal = peer;
    this.deviceEditorPeer = peer;
    this.deviceEditorVisible = true;
  }

  private saveDevice(peer: PeerRecord): ResourceStr {
    const error = this.onSaveDevice(this.deviceEditorOriginal, peer);
    if (error === '') {
      this.deviceEditorVisible = false;
    }
    return error;
  }

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

  private sourceIndex(source: PeerViewSource): number {
    if (source === 'favorite') {
      return 1;
    }
    if (source === 'lan') {
      return 2;
    }
    if (source === 'addressBook') {
      return 3;
    }
    return 0;
  }

  private sourceFromIndex(index: number): PeerViewSource {
    if (index === 1) {
      return 'favorite';
    }
    if (index === 2) {
      return 'lan';
    }
    if (index === 3) {
      return 'addressBook';
    }
    return 'recent';
  }

  private sourcePeers(source: PeerViewSource): PeerRecord[] {
    if (source === 'favorite') {
      return this.snapshot.favorite;
    }
    if (source === 'lan') {
      return this.snapshot.lan;
    }
    if (source === 'addressBook') {
      return this.snapshot.addressBook;
    }
    return this.snapshot.recent;
  }

  private sourceItems(): LuminousSelectionItem[] {
    return [
      new LuminousSelectionItem('recent', '最近', '最近连接的设备'),
      new LuminousSelectionItem('favorite', '收藏', '收藏的设备'),
      new LuminousSelectionItem('lan', '局域网', '局域网发现的设备'),
      new LuminousSelectionItem('address-book', '通讯录', $r('app.string.device_address_book_unavailable')),
    ];
  }

  private matchesQuery(peer: PeerRecord, query: string, source: PeerViewSource): boolean {
    if (peer.id.toLowerCase().includes(query)
      || peer.alias.toLowerCase().includes(query)
      || peer.hostname.toLowerCase().includes(query)
      || peer.username.toLowerCase().includes(query)) {
      return true;
    }
    return source !== 'addressBook' && peer.note.toLowerCase().includes(query);
  }

  private comparePeerIds(left: PeerRecord, right: PeerRecord): number {
    const leftId = left.id.toLowerCase();
    const rightId = right.id.toLowerCase();
    if (leftId < rightId) {
      return -1;
    }
    return leftId > rightId ? 1 : 0;
  }

  private visiblePeers(source: PeerViewSource): PeerRecord[] {
    const peers = this.sourcePeers(source);
    const query = this.query.trim().toLowerCase();
    const visible: PeerRecord[] = [];
    for (let index = 0; index < peers.length; index += 1) {
      const peer = peers[index];
      if (query.length === 0 || this.matchesQuery(peer, query, source)) {
        visible.push(peer);
      }
    }
    if (source !== 'recent') {
      visible.sort((left: PeerRecord, right: PeerRecord): number => this.comparePeerIds(left, right));
    }
    return visible;
  }

  /**
   * One target-intent tuple per card; LAN additionally retains the raw username.
   *
   * The fields are free-form strings that may contain any joining character —
   * address book `ops` + `lab-vnc-host` and `ops-rustdesk-lab` + `host` spelled
   * the same key when they were joined with hyphens — and ArkUI leaves the
   * rendering of duplicate keys unspecified, so the encoding is a tuple.
   */
  private peerRenderKey(source: PeerViewSource, peer: PeerRecord): string {
    if (source === 'lan') {
      return JSON.stringify([source, peer.addressBookName, peerProtocolOf(peer), peer.id,
        peer.rustdeskIdOnly, peer.username]);
    }
    return JSON.stringify([source, peer.addressBookName, peerProtocolOf(peer), peer.id, peer.rustdeskIdOnly]);
  }


  private emptyText(source: PeerViewSource): ResourceStr {
    if (this.query.trim().length > 0) {
      return $r('app.string.device_empty_search');
    }
    if (source === 'favorite') {
      return '收藏设备后会显示在这里';
    }
    if (source === 'lan') {
      return $r('app.string.device_empty_lan');
    }
    return $r('app.string.device_empty_recent');
  }

  private emptyTitle(source: PeerViewSource): ResourceStr {
    if (this.query.trim().length > 0) {
      return '没有匹配的设备';
    }
    if (source === 'favorite') {
      return '还没有收藏设备';
    }
    if (source === 'lan') {
      return $r('app.string.resk_lan_empty_title');
    }
    return '还没有最近设备';
  }

  private emptyActionLabel(source: PeerViewSource): ResourceStr {
    if (this.query.trim().length > 0) {
      return '清除搜索';
    }
    return '刷新设备';
  }

  private showEmptyAction(source: PeerViewSource): boolean {
    return this.query.trim().length > 0 || source !== 'lan';
  }

  private emptySymbol(source: PeerViewSource): Resource {
    if (this.query.trim().length > 0) {
      return $r('sys.symbol.magnifyingglass');
    }
    if (source === 'favorite') {
      return $r('sys.symbol.star');
    }
    if (source === 'lan') {
      return $r('sys.symbol.wifi');
    }
    return $r('sys.symbol.clock');
  }

  private changeSource(index: number): void {
    const target = Math.max(0, Math.min(3, index));
    this.activeSource = this.sourceFromIndex(target);
    try {
      this.swiperController.changeIndex(target, true);
    } catch (_) {
    }
  }

  private startLanRefresh(): void {
    this.lanRefreshing = this.snapshot.lanScanning;
    if (!this.snapshot.lanCanScan || this.snapshot.lanScanning) {
      return;
    }
    this.onScanLan();
  }

  private lanRefreshPrompt(): ResourceStr {
    if (this.snapshot.lanScanning) {
      return $r('app.string.device_scanning_lan');
    }
    if (this.lanRefreshStatus === RefreshStatus.OverDrag) {
      return $r('app.string.device_release_scan_lan');
    }
    return $r('app.string.device_pull_scan_lan');
  }

  private lanStatus(): ResourceStr {
    if (this.snapshot.lanState === 'unavailable') {
      return $r('app.string.resk_lan_unavailable');
    }
    if (this.snapshot.lanState === 'loading') {
      return $r('app.string.resk_lan_loading');
    }
    if (this.snapshot.lanState === 'starting') {
      return $r('app.string.resk_lan_starting');
    }
    if (this.snapshot.lanState === 'stopping' || this.snapshot.lanState === 'removing') {
      return $r('app.string.resk_lan_cleaning');
    }
    if (this.snapshot.lanScanning) {
      return $r('app.string.device_scanning_lan');
    }
    if (this.snapshot.lanTerminal === 'inactivity') {
      return $r('app.string.resk_lan_inactivity');
    }
    if (this.snapshot.lanTerminal === 'deadline') {
      return $r('app.string.resk_lan_deadline');
    }
    if (this.snapshot.lanTerminal === 'cancelled') {
      return $r('app.string.resk_lan_cancelled');
    }
    if (this.snapshot.lanTerminal === 'failed') {
      return $r('app.string.resk_lan_failed');
    }
    return $r('app.string.resk_lan_cached');
  }

  @Builder
  private LanActions() {
    Column({ space: $r('app.float.space_8') }) {
      Row({ space: $r('app.float.space_8') }) {
        Button($r('app.string.device_scan_lan'))
          .enabled(this.snapshot.lanCanScan && !this.snapshot.lanScanning)
          .onClick((): void => this.startLanRefresh());
        if (this.snapshot.lanScanning) {
          Button($r('app.string.resk_lan_stop'))
            .enabled(this.snapshot.lanCanScan)
            .onClick((): void => this.onStopLan());
        }
      }
      .width('100%');
      Text(this.lanStatus())
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.neu_text_secondary'));
      Text($r('app.string.resk_lan_untrusted'))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.neu_text_secondary'));
      if (this.snapshot.lanDisabledReason !== '') {
        Text(this.snapshot.lanDisabledReason)
          .width('100%')
          .fontSize($r('app.float.font_label'))
          .fontColor($r('app.color.warning'));
      }
      if (this.snapshot.lanError.length > 0) {
        Text(this.snapshot.lanError)
          .width('100%')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.error'));
      }
    }
    .width(this.controlWidth())
    .padding({ top: $r('app.float.space_8'), bottom: $r('app.float.space_8') })
    .alignItems(HorizontalAlign.Start);
  }

  private activateEmptyAction(source: PeerViewSource): void {
    if (this.query.trim().length > 0) {
      this.query = '';
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
  private AddressBookUnavailable() {
    Column({ space: $r('app.float.space_8') }) {
      Text($r('app.string.device_address_book_unavailable'))
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.neu_text_primary'));
      Text($r('app.string.device_empty_address_book'))
        .width('100%')
        .fontSize($r('app.float.font_label'))
        .lineHeight(20)
        .fontColor($r('app.color.neu_text_secondary'));
    }
    .width(this.controlWidth())
    .padding($r('app.float.space_16'))
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.neu_base'))
    .border({ width: 1, color: $r('app.color.outline') })
    .borderRadius($r('app.float.radius_24'));
  }

  @Builder
  private EmptyState(source: PeerViewSource) {
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

            if (this.showEmptyAction(source)) {
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
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width(this.controlWidth())
        .height(106)
        .padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center);
      }

      if (this.showEmptyAction(source)) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Row()
        }
        .width(this.controlWidth())
        .height(106)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .hoverEffect(HoverEffect.None)
        .borderRadius(24)
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
    }
    .width(this.controlWidth())
    .height(122)
    .clip(false);
  }

  @Builder
  private PeerList(source: PeerViewSource) {
    if (source === 'addressBook') {
      this.AddressBookUnavailable();
    } else if (this.visiblePeers(source).length === 0) {
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
            viewSource: source,
            compact: this.compactPeerCard(),
            removeEnabled: source !== 'lan' || this.snapshot.lanCanScan,
            onSetFavorite: (target: string, protocol: PeerProtocol, favorite: boolean, idOnly: boolean) =>
              this.onSetFavorite(target, protocol, favorite, idOnly),
            onEditNote: (target: string, protocol: PeerProtocol, note: string, idOnly: boolean) =>
              this.onEditNote(target, protocol, note, idOnly),
            onRemoveRecent: (target: string, protocol: PeerProtocol, idOnly: boolean) =>
              this.onRemoveRecent(target, protocol, idOnly),
            onRemoveLan: (target: string, protocol: PeerProtocol) => this.onRemoveLan(target, protocol),
            onConnectRemote: (peerId: string, idOnly: boolean) => this.onConnectRemote(peerId, idOnly),
            onConnectVnc: (peerId: string) => this.onConnectVnc(peerId),
            onConnectRdp: (peerId: string) => this.onConnectRdp(peerId),
            onEditDevice: (peer: PeerRecord): void => this.editDevice(peer),
          });
        }, (peer: PeerRecord) => this.peerRenderKey(source, peer));
      }
      .width(this.controlWidth())
      .alignItems(HorizontalAlign.Start);
    } else {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.visiblePeers(source), (peer: PeerRecord) => {
          PeerCard({
            peer: peer,
            viewSource: source,
            compact: this.compactPeerCard(),
            removeEnabled: source !== 'lan' || this.snapshot.lanCanScan,
            onSetFavorite: (target: string, protocol: PeerProtocol, favorite: boolean, idOnly: boolean) =>
              this.onSetFavorite(target, protocol, favorite, idOnly),
            onEditNote: (target: string, protocol: PeerProtocol, note: string, idOnly: boolean) =>
              this.onEditNote(target, protocol, note, idOnly),
            onRemoveRecent: (target: string, protocol: PeerProtocol, idOnly: boolean) =>
              this.onRemoveRecent(target, protocol, idOnly),
            onRemoveLan: (target: string, protocol: PeerProtocol) => this.onRemoveLan(target, protocol),
            onConnectRemote: (peerId: string, idOnly: boolean) => this.onConnectRemote(peerId, idOnly),
            onConnectVnc: (peerId: string) => this.onConnectVnc(peerId),
            onConnectRdp: (peerId: string) => this.onConnectRdp(peerId),
            onEditDevice: (peer: PeerRecord): void => this.editDevice(peer),
          })
            .width(this.cardWidth())
            .margin({ bottom: 18 });
        }, (peer: PeerRecord) => this.peerRenderKey(source, peer));
      }
      .width(this.controlWidth());
    }
  }

  @Builder
  private SourceList(source: PeerViewSource, scroller: Scroller) {
    List({ scroller: scroller }) {
      ListItem() {
        Row() {
          Column() {
            Blank()
              .width('100%')
              .height(this.sourceSwitcherContentInset())
              .flexShrink(0);

            if (source === 'lan') {
              this.LanActions();
            }
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
  private SourcePage(source: PeerViewSource, scroller: Scroller) {
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
      Refresh({ refreshing: this.lanRefreshing!! }) {
        this.SourceList(source, scroller);
      }
      .width('100%')
      .height('100%')
      .onRefreshing((): void => {
        this.onRefresh();
        this.lanRefreshing = false;
      });
    }
  }

  build() {
    Stack() {
    Column() {
      Blank()
        .width('100%')
        .height(this.titleSpacerHeight)
        .flexShrink(0);

      Row() {
        Column() {
          this.DirectorySearch();
          Text($r('app.string.device_liveness_hint'))
            .width('100%')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.neu_text_secondary'))
            .margin({ bottom: 8 });
          if (this.snapshot.message.length > 0) {
            Text(this.snapshot.message)
              .width('100%')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.neu_text_secondary'))
              .maxLines(3);
          }
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
          this.SourcePage('favorite', this.favoriteScroller);
          this.SourcePage('lan', this.lanScroller);
          this.SourcePage('addressBook', this.addressBookScroller);
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
    if (this.deviceEditorVisible) {
      SavedDeviceEditor({
        peer: this.deviceEditorPeer,
        onSave: (peer: PeerRecord): ResourceStr => this.saveDevice(peer),
        onCancel: (): void => { this.deviceEditorVisible = false; },
      })
    }
    }
    .width('100%')
    .height('100%');
  }
}
