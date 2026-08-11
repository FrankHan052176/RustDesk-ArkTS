import { PeerRecord } from '../RustDeskDirectoryTypes';
import { FloatingActionSurface, FloatingGlassSurface } from './FloatingSurface';

export interface PeerCardProps {
  peer: PeerRecord;
  compact: boolean;
  cardWidth: number;
  transferActive: boolean;
  onSetFavorite: (peerId: string, favorite: boolean) => void;
  onRemoveRecent: (peerId: string) => void;
  onConnectRemote: (peerId: string) => void;
  onViewOnly: (peerId: string) => void;
  onViewCamera: (peerId: string) => void;
  onOpenTransfer: (peerId: string) => void;
}

@ComponentV2
export struct PeerCard {
  @Param peer: PeerRecord = new PeerRecord();
  @Param compact: boolean = false;
  @Param cardWidth: number = 0;
  @Param transferActive: boolean = false;
  @Local favoriteActive: boolean = false;
  @Event onSetFavorite: (peerId: string, favorite: boolean) => void = (_peerId: string, _favorite: boolean) => {};
  @Event onRemoveRecent: (peerId: string) => void = (_peerId: string) => {};
  @Event onConnectRemote: (peerId: string) => void = (_peerId: string) => {};
  @Event onViewOnly: (peerId: string) => void = (_peerId: string) => {};
  @Event onViewCamera: (peerId: string) => void = (_peerId: string) => {};
  @Event onOpenTransfer: (peerId: string) => void = (_peerId: string) => {};

  aboutToAppear(): void {
    this.favoriteActive = this.peer.favorite;
  }

  @Monitor('peer')
  private onPeerChanged(_monitor: IMonitor): void {
    this.favoriteActive = this.peer.favorite;
  }

  private displayName(): string {
    if (this.peer.alias.trim().length > 0) {
      return this.peer.alias.trim();
    }
    if (this.peer.hostname.trim().length > 0) {
      return this.peer.hostname.trim();
    }
    if (this.peer.username.trim().length > 0) {
      return this.peer.username.trim();
    }
    return this.peer.id;
  }

  private identityDetail(): string {
    if (this.peer.source === 'lan' && this.peer.lanIp.trim().length > 0) {
      return this.peer.lanIp.trim();
    }
    return this.peer.id;
  }

  private connectionTarget(): string {
    if (this.peer.source === 'lan') {
      const lanIp = this.peer.lanIp.trim();
      if (lanIp.length > 0) {
        return lanIp;
      }
    }
    return this.peer.id;
  }

  private sourceAccent(): ResourceColor {
    if (this.peer.source === 'lan') {
      return $r('app.color.success');
    }
    if (this.peer.source === 'addressBook') {
      return $r('app.color.brand_secondary');
    }
    return $r('app.color.neu_accent');
  }

  private sourceBackground(): ResourceColor {
    if (this.peer.source === 'lan') {
      return $r('app.color.success_soft');
    }
    if (this.peer.source === 'addressBook') {
      return $r('app.color.brand_secondary_soft');
    }
    return $r('app.color.brand_primary_soft');
  }

  private sourceText(): ResourceStr {
    if (this.peer.source === 'addressBook' && this.peer.addressBookName.trim().length > 0) {
      return this.peer.addressBookName.trim();
    }
    if (this.peer.source === 'addressBook') {
      return $r('app.string.device_source_address_book');
    }
    if (this.peer.source === 'lan') {
      return $r('app.string.device_source_lan');
    }
    return $r('app.string.device_source_recent');
  }

  private toggleFavorite(): void {
    const next = !this.favoriteActive;
    this.favoriteActive = next;
    this.onSetFavorite(this.peer.id, next);
  }

  private cardHeight(): number {
    return this.compact ? 156 : 184;
  }

  private sessionSurfaceWidth(): number {
    return this.cardWidth > 32 ? this.cardWidth - 32 : 0;
  }

  @Builder
  private FavoriteButton() {
    Stack() {
      FloatingActionSurface({
        compact: true,
        subtleDepth: true,
        accessibilityLabel: this.favoriteActive ? '取消收藏设备' : '收藏设备',
        onActivate: (): void => this.toggleFavorite(),
      }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph(this.favoriteActive ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
            .fontSize(18)
            .fontColor([this.favoriteActive
              ? $r('app.color.warning')
              : $r('app.color.neu_text_secondary')]);
        }
        .width('100%')
        .height('100%');
      }
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .clip(false);
  }

  @Builder
  private RemoveButton() {
    Stack() {
      FloatingActionSurface({
        compact: true,
        subtleDepth: true,
        accessibilityLabel: '从最近设备中移除',
        onActivate: (): void => this.onRemoveRecent(this.peer.id),
      }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(18)
            .fontColor([$r('app.color.error')]);
        }
        .width('100%')
        .height('100%');
      }
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .clip(false);
  }

  @Builder
  private IdentityRow() {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(22)
          .fontColor([this.sourceAccent()]);
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(this.sourceBackground());

      Column({ space: 3 }) {
        Text(this.displayName())
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(this.identityDetail())
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.neu_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Row({ space: 16 }) {
        this.FavoriteButton();

        if (this.peer.source === 'recent') {
          this.RemoveButton();
        }
      }
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private StatusRow() {
    Row({ space: 8 }) {
      Circle()
        .width(8)
        .height(8)
        .fill(this.peer.online ? $r('app.color.success') : $r('app.color.neu_text_disabled'));
      Text(this.peer.online ? '在线' : '离线')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.peer.online ? $r('app.color.success') : $r('app.color.neu_text_secondary'));
      Text(this.sourceText())
        .fontSize(11)
        .fontColor(this.sourceAccent());
      Text(`ID ${this.peer.id}`)
        .layoutWeight(1)
        .fontSize(11)
        .fontColor($r('app.color.neu_text_secondary'))
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private SessionAction(label: ResourceStr, accent: boolean, onClick: () => void) {
    Stack() {
      FloatingActionSurface({
        compact: true,
        subtleDepth: true,
        accessibilityLabel: label,
        onActivate: (): void => onClick(),
      }) {
        Row() {
          Text(label)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(accent ? $r('app.color.neu_accent') : $r('app.color.neu_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center);
      }
    }
    .layoutWeight(1)
    .height(44)
    .clip(false);
  }

  @Builder
  private SessionActions() {
    Stack() {
      FloatingGlassSurface({
        inset: true,
        subtleDepth: true,
        radius: $r('app.float.radius_18'),
        surfaceWidth: this.sessionSurfaceWidth(),
        surfaceHeight: 72,
      }) {
        Stack({ alignContent: Alignment.Center }) {
          Row({ space: 8 }) {
            this.SessionAction('远控', true, (): void => this.onConnectRemote(this.connectionTarget()));
            this.SessionAction('观看', false, (): void => this.onViewOnly(this.connectionTarget()));
            this.SessionAction('相机', false, (): void => this.onViewCamera(this.connectionTarget()));
            this.SessionAction(
              this.transferActive ? '传输中' : '文件',
              this.transferActive,
              (): void => this.onOpenTransfer(this.connectionTarget()),
            );
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .alignItems(VerticalAlign.Center)
          .clip(false);
        }
        .width('100%')
        .height(72);
      }
    }
    .width('100%')
    .height(72)
    .borderRadius($r('app.float.radius_18'))
    .clip(false);
  }

  build() {
    Stack() {
      FloatingGlassSurface({
        subtleDepth: true,
        radius: $r('app.float.radius_18'),
        surfaceWidth: this.cardWidth,
        surfaceHeight: this.cardHeight(),
      }) {
        Column({ space: this.compact ? 10 : 12 }) {
          this.IdentityRow();
          if (!this.compact) {
            this.StatusRow();
          }
          this.SessionActions();
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width('100%')
    .borderRadius($r('app.float.radius_18'))
    .clip(false);
  }
}
