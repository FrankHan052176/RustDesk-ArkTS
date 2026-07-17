import {
  DirectorySnapshot,
  PeerRecord,
  PeerSource,
} from '../RustDeskDirectoryTypes';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { FloatingSegmentedControl } from './FloatingSegmentedControl';
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
  @Local selectorProgress: number = 0;
  @Local selectorDragging: boolean = false;
  @Local selectorSettling: boolean = false;
  @Local lanRefreshing: boolean = false;
  @Local lanRefreshStatus: RefreshStatus = RefreshStatus.Inactive;
  @Local pressedControl: string = '';
  @Local queryFocused: boolean = false;
  private swiperController: SwiperController = new SwiperController();
  @Event onRefresh: () => void = () => {};
  @Event onScanLan: () => void = () => {};
  @Event onSetFavorite: (peerId: string, favorite: boolean) => void = (_peerId: string, _favorite: boolean) => {};
  @Event onRemoveRecent: (peerId: string) => void = (_peerId: string) => {};
  @Event onConnectRemote: (peerId: string) => void = (_peerId: string) => {};
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

  private horizontalPadding(): Resource {
    if (this.viewportWidth >= 1440) {
      return $r('app.float.space_48');
    }
    if (this.viewportWidth >= 760 || this.wideLayout) {
      return $r('app.float.space_32');
    }
    return $r('app.float.space_20');
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

  private sourceCount(source: PeerSource): number {
    return this.sourcePeers(source).length;
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

  private emptyText(source: PeerSource): Resource {
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

  private emptyGlyph(source: PeerSource): string {
    if (this.query.trim().length > 0) {
      return '⌕';
    }
    if (source === 'addressBook') {
      return '▤';
    }
    if (source === 'lan') {
      return '⌁';
    }
    return '◷';
  }

  private pressBlurScale(controlId: string): number {
    return this.pressedControl === controlId ? 0.18 : 0.72;
  }

  private animateControl(controlId: string, active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 180 : 420,
      curve: Curve.Friction,
    }, () => {
      if (active) {
        this.pressedControl = controlId;
      } else if (this.pressedControl === controlId) {
        this.pressedControl = '';
      }
    });
  }

  private clampSelectorProgress(value: number): number {
    return Math.max(0, Math.min(2, value));
  }

  private changeSwiperIndex(index: number): void {
    try {
      this.swiperController.changeIndex(index, true);
    } catch (_) {
    }
  }

  private commitSourceIndex(index: number): void {
    const target = Math.max(0, Math.min(2, index));
    const current = this.sourceIndex(this.activeSource);
    this.activeSource = this.sourceFromIndex(target);
    this.selectorProgress = target;
    if (current === target) {
      this.selectorSettling = false;
      return;
    }
    this.selectorSettling = true;
    this.changeSwiperIndex(target);
  }

  private startLanRefresh(): void {
    if (this.snapshot.lanScanning) {
      return;
    }
    this.lanRefreshing = true;
    this.onScanLan();
  }

  private lanRefreshPrompt(): Resource {
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
    this.onRefresh();
  }

  @Builder
  private SourceSelector() {
    FloatingSegmentedControl({
      labels: [
        $r('app.string.device_source_recent'),
        $r('app.string.device_source_address_book'),
        $r('app.string.device_source_lan'),
      ],
      badges: [
        `${this.sourceCount('recent')}`,
        `${this.sourceCount('addressBook')}`,
        `${this.sourceCount('lan')}`,
      ],
      selectedIndex: this.sourceIndex(this.activeSource),
      progress: this.selectorProgress,
      controlId: 'device-source',
      compact: this.isPhoneLayout(),
      onPreviewIndex: (_index: number) => {},
      onProgressChange: (progress: number) => this.selectorProgress = this.clampSelectorProgress(progress),
      onDragStateChange: (dragging: boolean) => this.selectorDragging = dragging,
      onChange: (index: number) => this.commitSourceIndex(index),
    })
    .width('100%')
    .constraintSize({ maxWidth: 520 });
  }

  @Builder
  private SearchField() {
    Stack() {
      Row({ space: $r('app.float.space_12') }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize($r('app.float.icon_regular'))
          .fontColor([$r('app.color.text_secondary')]);

        TextInput({
          text: this.query!!,
          placeholder: $r('app.string.device_search_placeholder'),
        })
          .layoutWeight(1)
          .height('100%')
          .padding(0)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .caretColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.transparent'))
          .onFocus(() => this.queryFocused = true)
          .onBlur(() => this.queryFocused = false);

        if (this.query.length > 0) {
          Button({ type: ButtonType.Normal, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize($r('app.float.icon_small'))
              .fontColor([$r('app.color.text_primary')])
              .visualEffect(RustDeskGlassEffect.interactiveContent(
                this.pressedControl === 'search-clear',
                $r('app.color.point_light'),
                0.52,
              ));
          }
          .width($r('app.float.control_regular'))
          .height($r('app.float.control_regular'))
          .padding(0)
          .backgroundColor($r('app.color.transparent'))
          .borderRadius($r('app.float.radius_10'))
          .accessibilityText('清除搜索')
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.animateControl('search-clear', true);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.animateControl('search-clear', false);
            }
          })
          .onClick(() => this.query = '');
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_4') })
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.contentReceiver());

      if (this.queryFocused) {
        Row()
          .width('100%')
          .height('100%')
          .border({ width: 2, color: $r('app.color.brand_primary') })
          .borderRadius($r('app.float.radius_14'))
          .hitTestBehavior(HitTestMode.None);
      }
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.pressBlurScale('search-clear'),
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }

  @Builder
  private MessageBanner() {
    if (this.snapshot.message.trim().length > 0) {
      Row({ space: $r('app.float.space_12') }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize($r('app.float.icon_regular'))
          .fontColor([$r('app.color.info')]);
        Text(this.snapshot.message)
          .layoutWeight(1)
          .fontSize($r('app.float.font_label'))
          .lineHeight(18)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .padding({ top: $r('app.float.space_4'), bottom: $r('app.float.space_4') });
    }
  }

  @Builder
  private EmptyActionButton(source: PeerSource) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row({ space: $r('app.float.space_8') }) {
        Text(this.query.trim().length > 0 ? '×' : (source === 'lan' ? '⌁' : '↻'))
          .fontSize($r('app.float.icon_regular'))
          .fontColor($r('app.color.white'));
        Text(this.query.trim().length > 0
          ? '清除搜索'
          : (source === 'lan' ? '扫描局域网' : '刷新设备'))
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.white'));
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .visualEffect(RustDeskGlassEffect.interactiveContent(
        this.pressedControl === `empty-${source}`,
        $r('app.color.point_light'),
      ));
    }
    .width('100%')
    .height($r('app.float.control_regular'))
    .padding(0)
    .backgroundColor($r('app.color.brand_primary'))
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .enabled(!(source === 'lan' && this.snapshot.lanScanning && this.query.trim().length === 0))
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateControl(`empty-${source}`, true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateControl(`empty-${source}`, false);
      }
    })
    .onClick(() => this.activateEmptyAction(source));
  }

  @Builder
  private EmptyState(source: PeerSource) {
    Column({ space: $r('app.float.space_16') }) {
      Text(this.emptyGlyph(source))
        .fontSize(44)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_primary'));
      Text(this.emptyText(source))
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .lineHeight(21)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center);
      if (source === 'lan' && this.query.trim().length === 0) {
        Text($r('app.string.device_pull_scan_lan_hint'))
          .width('100%')
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_primary'))
          .textAlign(TextAlign.Center);
      } else {
        this.EmptyActionButton(source);
      }
    }
    .width('100%')
    .padding({ top: 0, bottom: $r('app.float.space_24') })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private PeerList(source: PeerSource) {
    if (this.visiblePeers(source).length === 0) {
      this.EmptyState(source);
    } else if (this.columnCount() === 1) {
      Column({ space: $r('app.float.space_12') }) {
        ForEach(this.visiblePeers(source), (peer: PeerRecord) => {
          PeerCard({
            peer: peer,
            compact: this.compactPeerCard(),
            transferActive: this.activeTransferPeerId === peer.id,
            onSetFavorite: (peerId: string, favorite: boolean) => this.onSetFavorite(peerId, favorite),
            onRemoveRecent: (peerId: string) => this.onRemoveRecent(peerId),
            onConnectRemote: (peerId: string) => this.onConnectRemote(peerId),
            onViewCamera: (peerId: string) => this.onViewCamera(peerId),
            onOpenTransfer: (peerId: string) => this.onOpenTransfer(peerId),
          });
        }, (peer: PeerRecord) => `${peer.source}-${peer.addressBookName}-${peer.id}`);
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
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
            onViewCamera: (peerId: string) => this.onViewCamera(peerId),
            onOpenTransfer: (peerId: string) => this.onOpenTransfer(peerId),
          })
            .width(this.cardWidth())
            .margin({ bottom: $r('app.float.space_12') });
        }, (peer: PeerRecord) => `${peer.source}-${peer.addressBookName}-${peer.id}`);
      }
      .width('100%');
    }
  }

  @Builder
  private SourceScroll(source: PeerSource, scroller: Scroller) {
    Scroll(scroller) {
      Row() {
        Column() {
          this.PeerList(source);
        }
        .width('100%')
        .constraintSize({ maxWidth: 1520 })
        .padding({
          left: this.horizontalPadding(),
          right: this.horizontalPadding(),
          top: $r('app.float.space_16'),
          bottom: this.bottomPadding(),
        })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Top);
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
  }

  @Builder
  private LanRefreshIndicator() {
    Row({ space: $r('app.float.space_8') }) {
      LoadingProgress()
        .width($r('app.float.icon_small'))
        .height($r('app.float.icon_small'))
        .color($r('app.color.brand_primary'))
        .visibility(this.snapshot.lanScanning || this.lanRefreshing ? Visibility.Visible : Visibility.Hidden);
      Text(this.lanRefreshPrompt())
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.lanRefreshStatus === RefreshStatus.OverDrag
          ? $r('app.color.brand_primary')
          : $r('app.color.text_secondary'));
    }
    .width('100%')
    .constraintSize({ minHeight: $r('app.float.control_regular') })
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
        this.SourceScroll(source, scroller);
      }
      .width('100%')
      .height('100%')
      .refreshOffset(72)
      .pullDownRatio(0.72)
      .onStateChange((status: RefreshStatus) => this.lanRefreshStatus = status)
      .onRefreshing(() => this.startLanRefresh());
    } else {
      this.SourceScroll(source, scroller);
    }
  }

  build() {
    Column() {
      Blank()
        .width('100%')
        .height(this.titleSpacerHeight)
        .flexShrink(0);

      Row() {
        Column({ space: $r('app.float.space_16') }) {
          this.SearchField();
          this.SourceSelector();
          this.MessageBanner();
        }
        .width('100%')
        .constraintSize({ maxWidth: 1520 })
        .padding({
          left: this.horizontalPadding(),
          right: this.horizontalPadding(),
          top: $r('app.float.space_16'),
        })
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);

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
      .onContentDidScroll((selectedIndex: number, index: number, position: number, _mainAxisLength: number) => {
        if (!this.selectorDragging && !this.selectorSettling && index === selectedIndex) {
          this.selectorProgress = this.clampSelectorProgress(index - position);
        }
      })
      .onChange((index: number) => {
        this.activeSource = this.sourceFromIndex(index);
      })
      .onAnimationEnd((index: number, _extraInfo: SwiperAnimationEvent) => {
        this.selectorSettling = false;
        if (!this.selectorDragging) {
          this.selectorProgress = index;
        }
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.transparent'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
