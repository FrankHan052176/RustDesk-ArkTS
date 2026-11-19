import {
  LuminousSearchField,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSurface,
} from 'luminous_neo';
import {
  CloudAddressBook,
  DirectorySnapshot,
  PeerProtocol,
  PeerRecord,
  PeerViewSource,
} from '../RustDeskDirectoryTypes';
import { RustDeskLayoutTokens } from '../RustDeskLayoutTokens';
import { peerProtocolOf } from '../RustDeskPeerDirectoryModel';
import { RustDeskAccountController, rustDeskAccountController } from '../NativeAccountBridge';
import { PeerCard } from './PeerCard';
import { SavedDeviceEditor } from './SavedDeviceEditor';
import {
  CloudPeerDeleteDialog,
  CloudPeerEditorDialog,
  CloudTagsDialog,
} from './CloudAddressBookDialogs';

export interface DeviceDirectoryPanelProps {
  snapshot: DirectorySnapshot;
  wideLayout: boolean;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  recentScroller: Scroller;
  favoriteScroller: Scroller;
  lanScroller: Scroller;
  addressBookScroller: Scroller;
  accountController?: RustDeskAccountController;
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
  onTransferFiles: (peerId: string, rustdeskIdOnly: boolean) => void;
  onSaveDevice: (original: PeerRecord, peer: PeerRecord) => ResourceStr;
  onOpenAccountSettings?: () => void;
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
  @Param accountController: RustDeskAccountController = rustDeskAccountController;
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

  @Local cloudEditorVisible: boolean = false;
  @Local cloudEditorIsNew: boolean = false;
  @Local cloudEditorPeerId: string = '';
  @Local cloudEditorAlias: string = '';
  @Local cloudEditorTags: string = '';
  @Local cloudDeleteVisible: boolean = false;
  @Local cloudDeletePeerId: string = '';
  @Local cloudTagsVisible: boolean = false;
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
  @Event onTransferFiles: (peerId: string, rustdeskIdOnly: boolean) => void =
    (_peerId: string, _rustdeskIdOnly: boolean) => {};
  @Event onSaveDevice: (original: PeerRecord, peer: PeerRecord) => ResourceStr =
    (_original: PeerRecord, _peer: PeerRecord): ResourceStr => $r('app.string.device_editor_save_unavailable');
  @Event onOpenAccountSettings: () => void = () => {};

  private editDevice(peer: PeerRecord): void {
    if (this.activeSource === 'addressBook') {
      if (!this.accountController.activeBook?.writable) {
        return;
      }
      this.cloudEditorPeerId = peer.id;
      this.cloudEditorAlias = peer.alias;
      this.cloudEditorTags = peer.tags.join(', ');
      this.cloudEditorIsNew = false;
      this.cloudEditorVisible = true;
      return;
    }
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

  private async handleCloudPeerSave(id: string, alias: string, tags: string[]): Promise<void> {
    const ok = await this.accountController.mutate({
      action: 'upsertPeer',
      peer: { id, alias, tags },
    });
    if (ok) {
      this.cloudEditorVisible = false;
    }
  }

  private async handleCloudPeerDelete(): Promise<void> {
    const ok = await this.accountController.mutate({
      action: 'deletePeer',
      id: this.cloudDeletePeerId,
    });
    if (ok) {
      this.cloudDeleteVisible = false;
    }
  }

  private async handleCloudAddTag(name: string): Promise<void> {
    await this.accountController.mutate({ action: 'upsertTag', name });
  }

  private async handleCloudRenameTag(oldName: string, newName: string): Promise<void> {
    await this.accountController.mutate({ action: 'upsertTag', name: oldName, newName });
  }

  private async handleCloudDeleteTag(name: string): Promise<void> {
    await this.accountController.mutate({ action: 'deleteTag', name });
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

  private pageTopClearance(): number {
    return this.wideLayout ? Math.max(this.titleSpacerHeight + 36, 56) : Math.max(this.titleSpacerHeight, 40);
  }

  private pageContentTopPadding(): number {
    return 0;
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
      return this.accountController.toPeerRecords();
    }
    return this.snapshot.recent;
  }

  private sourceItems(): LuminousSelectionItem[] {
    return [
      new LuminousSelectionItem('recent', '最近', '最近连接的设备'),
      new LuminousSelectionItem('favorite', '收藏', '收藏的设备'),
      new LuminousSelectionItem('lan', '局域网', '局域网发现的设备'),
      new LuminousSelectionItem('address-book', '通讯录', '云端同步设备'),
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
    if (source === 'addressBook') {
      return '云端通讯录中暂无设备';
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
    if (source === 'addressBook') {
      return '暂无通讯录设备';
    }
    return '还没有最近设备';
  }

  private emptyActionLabel(source: PeerViewSource): ResourceStr {
    if (this.query.trim().length > 0) {
      return '清除搜索';
    }
    if (source === 'lan') {
      return $r('app.string.device_scan_lan');
    }
    if (source === 'addressBook') {
      return this.accountController.state.loggedIn ? '刷新通讯录' : '前往登录';
    }
    return '刷新设备';
  }

  private showEmptyAction(source: PeerViewSource): boolean {
    if (this.query.trim().length > 0) {
      return true;
    }
    if (source === 'lan') {
      return this.snapshot.lanCanScan && !this.snapshot.lanScanning;
    }
    return true;
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
    if (source === 'addressBook') {
      return $r('sys.symbol.book');
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

  private hasLanFeedback(): boolean {
    return this.snapshot.lanScanning ||
      this.snapshot.lanDisabledReason !== '' ||
      this.snapshot.lanError.length > 0 ||
      this.snapshot.lanTerminal === 'failed';
  }

  @Builder
  private LanActions() {
    if (this.hasLanFeedback()) {
      Column({ space: $r('app.float.space_8') }) {
        if (this.snapshot.lanScanning) {
          Row({ space: $r('app.float.space_8') }) {
            Button($r('app.string.resk_lan_stop'))
              .enabled(this.snapshot.lanState === 'scanning')
              .onClick((): void => this.onStopLan());
          }
          .width('100%');
        }
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
        } else if (this.snapshot.lanTerminal === 'failed') {
          Text($r('app.string.resk_lan_failed'))
            .width('100%')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.error'));
        }
      }
      .width(this.controlWidth())
      .padding({ top: $r('app.float.space_8'), bottom: $r('app.float.space_8') })
      .alignItems(HorizontalAlign.Start);
    }
  }

  private activateEmptyAction(source: PeerViewSource): void {
    if (this.query.trim().length > 0) {
      this.query = '';
      return;
    }
    if (source === 'lan') {
      this.startLanRefresh();
      return;
    }
    if (source === 'addressBook') {
      if (!this.accountController.state.loggedIn) {
        // loadAddressBooks() returns early without a session, so offer the existing login entry instead of a no-op.
        this.onOpenAccountSettings();
        return;
      }
      void this.accountController.loadAddressBooks();
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
    .margin({ bottom: 8 })
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
  private AddressBookActions() {
    Column({ space: 8 }) {
      if (!this.accountController.state.loggedIn) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(24)
            .fontColor([$r('app.color.neu_accent')]);
          Column({ space: 2 }) {
            Text('未登录账户')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));
            Text('登录后即可同步与管理云端通讯录设备')
              .fontSize(11)
              .fontColor($r('app.color.neu_text_secondary'));
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          Button('前往登录', { type: ButtonType.Normal })
            .fontSize(12)
            .height(32)
            .borderRadius(8)
            .backgroundColor($r('app.color.brand_primary'))
            .fontColor(Color.White)
            .onClick((): void => this.onOpenAccountSettings());
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.surface_secondary'))
        .borderRadius(12);
      } else if (this.accountController.booksLoading) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18);
          Text('正在同步云端通讯录…')
            .fontSize(12)
            .fontColor($r('app.color.neu_text_secondary'));
        }
        .width('100%')
        .padding(8)
        .justifyContent(FlexAlign.Center);
      } else if (this.accountController.booksError.length > 0) {
        Row({ space: 10 }) {
          Text(this.accountController.booksError)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor($r('app.color.error'));
          Button('重试', { type: ButtonType.Normal })
            .fontSize(11)
            .height(28)
            .borderRadius(6)
            .onClick((): void => {
              void this.accountController.loadAddressBooks();
            });
        }
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.error_soft'))
        .borderRadius(8);
      } else if (this.accountController.addressBooks.length > 0) {
        Row({ space: 8 }) {
          if (this.accountController.addressBooks.length > 1) {
            ForEach(this.accountController.addressBooks, (book: CloudAddressBook) => {
              Button(book.name, { type: ButtonType.Normal })
                .fontSize(12)
                .height(30)
                .borderRadius(6)
                .backgroundColor(book.id === this.accountController.activeBookId
                  ? $r('app.color.brand_primary') : $r('app.color.surface_secondary'))
                .fontColor(book.id === this.accountController.activeBookId
                  ? Color.White : $r('app.color.neu_text_primary'))
                .onClick((): void => {
                  void this.accountController.loadActiveBook(book.id);
                });
            }, (book: CloudAddressBook) => book.id);
          } else {
            Text(this.accountController.activeBook?.name ?? '云端通讯录')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));
          }

          Text(this.accountController.activeBook?.writable ? '可编辑' : '只读')
            .fontSize(10)
            .fontColor($r('app.color.neu_text_secondary'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(4);

          Blank();

          if (this.accountController.activeBook?.writable) {
            Button('添加设备', { type: ButtonType.Normal })
              .fontSize(11)
              .height(28)
              .borderRadius(6)
              .backgroundColor($r('app.color.brand_primary'))
              .fontColor(Color.White)
              .onClick((): void => {
                this.cloudEditorPeerId = '';
                this.cloudEditorAlias = '';
                this.cloudEditorTags = '';
                this.cloudEditorIsNew = true;
                this.cloudEditorVisible = true;
              });

            Button('标签', { type: ButtonType.Normal })
              .fontSize(11)
              .height(28)
              .borderRadius(6)
              .backgroundColor($r('app.color.surface_secondary'))
              .fontColor($r('app.color.neu_text_primary'))
              .onClick((): void => {
                this.cloudTagsVisible = true;
              });
          }

          Button('刷新', { type: ButtonType.Normal })
            .fontSize(11)
            .height(28)
            .borderRadius(6)
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.neu_text_primary'))
            .onClick((): void => {
              void this.accountController.loadActiveBook(this.accountController.activeBookId);
            });
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }

      if (this.accountController.mutationFeedback.length > 0) {
        Row({ space: 8 }) {
          Text(this.accountController.mutationFeedback)
            .layoutWeight(1)
            .fontSize(11)
            .fontColor($r('app.color.warning'));
          Button('刷新核对', { type: ButtonType.Normal })
            .fontSize(11)
            .height(26)
            .borderRadius(6)
            .onClick((): void => {
              void this.accountController.loadActiveBook(this.accountController.activeBookId);
            });
        }
        .width('100%')
        .padding(8)
        .backgroundColor($r('app.color.warning_soft'))
        .borderRadius(8);
      }
    }
    .width(this.controlWidth())
    .padding({ top: $r('app.float.space_8'), bottom: $r('app.float.space_8') })
    .alignItems(HorizontalAlign.Start);
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
            viewSource: source,
            compact: this.compactPeerCard(),
            removeEnabled: source === 'addressBook'
              ? Boolean(this.accountController.activeBook?.writable)
              : (source !== 'lan' || this.snapshot.lanCanScan),
            onSetFavorite: (target: string, protocol: PeerProtocol, favorite: boolean, idOnly: boolean) =>
              this.onSetFavorite(target, protocol, favorite, idOnly),
            onEditNote: (target: string, protocol: PeerProtocol, note: string, idOnly: boolean) =>
              this.onEditNote(target, protocol, note, idOnly),
            onRemoveRecent: (target: string, protocol: PeerProtocol, idOnly: boolean) => {
              if (source === 'addressBook') {
                if (this.accountController.activeBook?.writable) {
                  this.cloudDeletePeerId = target;
                  this.cloudDeleteVisible = true;
                }
              } else {
                this.onRemoveRecent(target, protocol, idOnly);
              }
            },
            onRemoveLan: (target: string, protocol: PeerProtocol) => this.onRemoveLan(target, protocol),
            onConnectRemote: (peerId: string, idOnly: boolean) => this.onConnectRemote(peerId, idOnly),
            onConnectVnc: (peerId: string) => this.onConnectVnc(peerId),
            onConnectRdp: (peerId: string) => this.onConnectRdp(peerId),
            onTransferFiles: (peerId: string, idOnly: boolean) => this.onTransferFiles(peerId, idOnly),
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
            removeEnabled: source === 'addressBook'
              ? Boolean(this.accountController.activeBook?.writable)
              : (source !== 'lan' || this.snapshot.lanCanScan),
            onSetFavorite: (target: string, protocol: PeerProtocol, favorite: boolean, idOnly: boolean) =>
              this.onSetFavorite(target, protocol, favorite, idOnly),
            onEditNote: (target: string, protocol: PeerProtocol, note: string, idOnly: boolean) =>
              this.onEditNote(target, protocol, note, idOnly),
            onRemoveRecent: (target: string, protocol: PeerProtocol, idOnly: boolean) => {
              if (source === 'addressBook') {
                if (this.accountController.activeBook?.writable) {
                  this.cloudDeletePeerId = target;
                  this.cloudDeleteVisible = true;
                }
              } else {
                this.onRemoveRecent(target, protocol, idOnly);
              }
            },
            onRemoveLan: (target: string, protocol: PeerProtocol) => this.onRemoveLan(target, protocol),
            onConnectRemote: (peerId: string, idOnly: boolean) => this.onConnectRemote(peerId, idOnly),
            onConnectVnc: (peerId: string) => this.onConnectVnc(peerId),
            onConnectRdp: (peerId: string) => this.onConnectRdp(peerId),
            onTransferFiles: (peerId: string, idOnly: boolean) => this.onTransferFiles(peerId, idOnly),
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
            if (source === 'addressBook') {
              this.AddressBookActions();
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
        if (source === 'addressBook') {
          void this.accountController.loadAddressBooks();
        } else {
          this.onRefresh();
        }
        this.lanRefreshing = false;
      });
    }
  }

  build() {
    Stack() {
    Column() {
      Blank()
        .width('100%')
        .height(this.pageTopClearance())
        .flexShrink(0);

      Row() {
        Column({ space: 8 }) {
          this.DirectorySearch();
          if (this.snapshot.message.length > 0) {
            Text(this.snapshot.message)
              .width('100%')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.error'));
          }
        }
        .width(this.controlWidth())
        .alignItems(HorizontalAlign.Start);
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

    CloudPeerEditorDialog({
      visible: this.cloudEditorVisible,
      isNew: this.cloudEditorIsNew,
      initialPeerId: this.cloudEditorPeerId,
      initialAlias: this.cloudEditorAlias,
      initialTags: this.cloudEditorTags,
      inFlight: this.accountController.mutationInFlight,
      errorText: this.accountController.mutationFeedback,
      onSave: (id: string, alias: string, tags: string[]): void => {
        void this.handleCloudPeerSave(id, alias, tags);
      },
      onCancel: (): void => {
        this.cloudEditorVisible = false;
      },
    })

    CloudPeerDeleteDialog({
      visible: this.cloudDeleteVisible,
      peerId: this.cloudDeletePeerId,
      inFlight: this.accountController.mutationInFlight,
      onConfirm: (): void => {
        void this.handleCloudPeerDelete();
      },
      onCancel: (): void => {
        this.cloudDeleteVisible = false;
      },
    })

    CloudTagsDialog({
      visible: this.cloudTagsVisible,
      tags: this.accountController.activeBookTags,
      inFlight: this.accountController.mutationInFlight,
      onAddTag: (name: string): void => {
        void this.handleCloudAddTag(name);
      },
      onRenameTag: (oldName: string, newName: string): void => {
        void this.handleCloudRenameTag(oldName, newName);
      },
      onDeleteTag: (name: string): void => {
        void this.handleCloudDeleteTag(name);
      },
      onClose: (): void => {
        this.cloudTagsVisible = false;
      },
    })
    }
    .width('100%')
    .height('100%');
  }
}
