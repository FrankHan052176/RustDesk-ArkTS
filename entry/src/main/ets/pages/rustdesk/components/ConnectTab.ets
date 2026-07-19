import { DirectorySnapshot, PeerRecord } from '../RustDeskDirectoryTypes';
import { FloatingActionSurface, FloatingGlassSurface, FloatingSectionHeading } from './FloatingSurface';
import { PeerCard } from './PeerCard';

export interface ConnectTabProps {
  target: string;
  rememberPassword: boolean;
  scroller: Scroller;
  onTargetChange: (value: string) => void;
  onConnectRemote: () => void;
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
  @Local viewportHeight: number = 780;
  @Event onTargetChange: (value: string) => void = (_value: string) => {};
  @Event onConnectRemote: () => void = () => {};
  @Event onViewCamera: () => void = () => {};
  @Event onOpenTransfer: () => void = () => {};
  @Event onDisconnect: () => void = () => {};
  @Event onSetPeerFavorite: (peerId: string, favorite: boolean) => void = (_peerId: string, _favorite: boolean) => {};
  @Event onRemoveRecentPeer: (peerId: string) => void = (_peerId: string) => {};
  @Event onConnectPeerRemote: (peerId: string) => void = (_peerId: string) => {};
  @Event onViewPeerCamera: (peerId: string) => void = (_peerId: string) => {};
  @Event onOpenPeerTransfer: (peerId: string) => void = (_peerId: string) => {};

  private useSplitLayout(): boolean {
    return this.wideLayout;
  }

  private isLowHeightWindow(): boolean {
    return this.viewportWidth > 0 && this.viewportHeight / this.viewportWidth < 0.8;
  }

  private contentMaxWidth(): number {
    return this.useSplitLayout() ? 1200 : 720;
  }

  private contentBottomPadding(): number {
    return (this.wideLayout ? 40 : 112) + this.bottomAvoidInset;
  }

  private sectionSpacing(): Resource {
    return this.isLowHeightWindow() ? $r('app.float.space_24') : $r('app.float.space_32');
  }

  private recentLimit(): number {
    return 1;
  }

  private recentPreview(): PeerRecord[] {
    const peers: PeerRecord[] = [];
    const limit = this.recentLimit();
    for (let index = 0; index < this.directorySnapshot.recent.length && peers.length < limit; index += 1) {
      peers.push(this.directorySnapshot.recent[index]);
    }
    return peers;
  }

  private hasActiveWork(): boolean {
    return this.canDisconnect || this.transferActive;
  }

  private targetReady(): boolean {
    return this.target.trim().length > 0;
  }

  private connectButtonText(): string {
    return this.canDisconnect ? '连接其他设备' : '远程控制';
  }

  @Builder
  private TargetField() {
    Stack() {
      FloatingGlassSurface({ compact: true }) {
        Row({ space: $r('app.float.space_12') }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('ID')
              .fontSize($r('app.float.font_label'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand_primary'));
          }
          .width($r('app.float.control_small'))
          .height($r('app.float.control_small'))
          .backgroundColor($r('app.color.brand_primary_soft'))
          .borderRadius($r('app.float.radius_14'))
          .clip(true);

          TextInput({ text: this.target, placeholder: '输入远端设备 ID' })
            .layoutWeight(1)
            .height('100%')
            .padding(0)
            .backgroundColor($r('app.color.transparent'))
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.brand_primary'))
            .borderWidth(0)
            .accessibilityText('远端设备 ID')
            .onChange((value: string) => this.onTargetChange(value));
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_16') })
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private ConnectButton() {
    Stack() {
      FloatingActionSurface({
        actionEnabled: this.targetReady(),
        touchLight: true,
        lightPeakIntensity: 0.66,
        onActivate: () => this.onConnectRemote(),
      }) {
        Row() {
          Text(this.connectButtonText())
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.targetReady()
              ? $r('app.color.white')
              : $r('app.color.disabled_text'));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.targetReady()
          ? $r('app.color.brand_primary')
          : $r('app.color.disabled_background'))
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_regular'))
    .accessibilityText(this.connectButtonText());
  }

  @Builder
  private SecondaryAction(
    icon: string,
    label: string,
    onClick: () => void,
  ) {
    Stack() {
      FloatingActionSurface({
        touchLight: true,
        lightPeakIntensity: 0.62,
        onActivate: onClick,
      }) {
        Row({ space: $r('app.float.space_6') }) {
          Text(icon)
            .fontSize($r('app.float.icon_regular'))
            .fontColor($r('app.color.text_primary'));
          Text(label)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .borderRadius($r('app.float.radius_14'))
          .clip(true);
      }
    }
    .layoutWeight(1)
    .height($r('app.float.control_regular'))
    .accessibilityText(label);
  }

  @Builder
  private QuickConnectSection() {
    Column({ space: $r('app.float.space_16') }) {
      this.TargetField();
      this.ConnectButton();

      Row({ space: $r('app.float.space_12') }) {
        this.SecondaryAction('◉', '摄像头', () => this.onViewCamera());
        this.SecondaryAction('⇄', '文件传输', () => this.onOpenTransfer());
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private RecentSection() {
    Column({ space: $r('app.float.space_12') }) {
      FloatingSectionHeading({
        title: '最近设备',
        description: '仅展示最后一次连接的设备。',
      });

      if (this.recentPreview().length === 0) {
        Row({ space: $r('app.float.space_12') }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize($r('app.float.icon_regular'))
            .fontColor([$r('app.color.text_tertiary')]);
          Text($r('app.string.device_empty_recent'))
            .layoutWeight(1)
            .fontSize($r('app.float.font_body'))
            .lineHeight(20)
            .fontColor($r('app.color.text_secondary'));
        }
        .width('100%')
        .height(64)
        .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
        .backgroundColor($r('app.color.surface_secondary'))
        .borderRadius($r('app.float.radius_14'));
      } else {
        Column({ space: $r('app.float.space_12') }) {
          ForEach(this.recentPreview(), (peer: PeerRecord) => {
            PeerCard({
              peer: peer,
              compact: true,
              transferActive: this.activeTransferPeerId === peer.id,
              onSetFavorite: (peerId: string, favorite: boolean) => this.onSetPeerFavorite(peerId, favorite),
              onRemoveRecent: (peerId: string) => this.onRemoveRecentPeer(peerId),
              onConnectRemote: (peerId: string) => this.onConnectPeerRemote(peerId),
              onViewCamera: (peerId: string) => this.onViewPeerCamera(peerId),
              onOpenTransfer: (peerId: string) => this.onOpenPeerTransfer(peerId),
            });
          }, (peer: PeerRecord) => `recent-${peer.id}`);
        }
        .width('100%');
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private WideContent() {
    Row({ space: $r('app.float.space_24') }) {
      Column() {
        this.QuickConnectSection();
      }
      .layoutWeight(5)
      .alignItems(HorizontalAlign.Start);

      Column() {
        this.RecentSection();
      }
      .layoutWeight(7)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .alignItems(VerticalAlign.Top);
  }

  @Builder
  private CompactContent() {
    Column({ space: this.sectionSpacing() }) {
      this.QuickConnectSection();
      this.RecentSection();
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        Blank()
          .width('100%')
          .height(this.titleSpacerHeight)
          .flexShrink(0);

        Column() {
          if (this.useSplitLayout()) {
            this.WideContent();
          } else {
            this.CompactContent();
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: this.contentMaxWidth() })
        .padding({
          left: $r('app.float.page_horizontal'),
          right: $r('app.float.page_horizontal'),
          top: 0,
          bottom: this.contentBottomPadding(),
        })
        .translate({ y: -10 });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('app.color.transparent'));
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.transparent'))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      const height = Number(newArea.height);
      if (width > 0) {
        this.viewportWidth = width;
      }
      if (height > 0) {
        this.viewportHeight = height;
      }
    });
  }
}
