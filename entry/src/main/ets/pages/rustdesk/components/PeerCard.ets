import { PeerRecord } from '../RustDeskDirectoryTypes';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';

export interface PeerCardProps {
  peer: PeerRecord;
  compact: boolean;
  transferActive: boolean;
  onSetFavorite: (peerId: string, favorite: boolean) => void;
  onRemoveRecent: (peerId: string) => void;
  onConnectRemote: (peerId: string) => void;
  onViewCamera: (peerId: string) => void;
  onOpenTransfer: (peerId: string) => void;
}

@ComponentV2
export struct PeerCard {
  @Param peer: PeerRecord = new PeerRecord();
  @Param compact: boolean = false;
  @Param transferActive: boolean = false;
  @Local pressedControl: string = '';
  @Local favoriteActive: boolean = false;
  @Local favoriteGlowIntensity: number = 0;
  @Event onSetFavorite: (peerId: string, favorite: boolean) => void = (_peerId: string, _favorite: boolean) => {};
  @Event onRemoveRecent: (peerId: string) => void = (_peerId: string) => {};
  @Event onConnectRemote: (peerId: string) => void = (_peerId: string) => {};
  @Event onViewCamera: (peerId: string) => void = (_peerId: string) => {};
  @Event onOpenTransfer: (peerId: string) => void = (_peerId: string) => {};

  aboutToAppear(): void {
    this.favoriteActive = this.peer.favorite;
  }

  @Monitor('peer')
  private onPeerChanged(_monitor: IMonitor): void {
    this.getUIContext().animateTo({
      duration: 280,
      curve: Curve.Friction,
    }, () => {
      this.favoriteActive = this.peer.favorite;
      this.favoriteGlowIntensity = 0;
    });
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
    const username = this.peer.username.trim();
    const hostname = this.peer.hostname.trim();
    if (username.length > 0 && hostname.length > 0 && hostname !== this.displayName()) {
      return `${username} · ${hostname}`;
    }
    if (hostname.length > 0 && hostname !== this.displayName()) {
      return hostname;
    }
    if (username.length > 0 && username !== this.displayName()) {
      return username;
    }
    return this.peer.platform.trim();
  }

  private sourceAccent(): ResourceColor {
    if (this.peer.source === 'lan') {
      return $r('app.color.success');
    }
    if (this.peer.source === 'addressBook') {
      return $r('app.color.brand_secondary');
    }
    return $r('app.color.brand_primary');
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

  private compactMetadata(): string {
    const detail = this.identityDetail();
    return detail.length > 0 ? `${detail} · ID ${this.peer.id}` : `ID ${this.peer.id}`;
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

  private pressBlurScale(controlId: string): number {
    return this.pressedControl === controlId ? 0.18 : 0.72;
  }

  private toggleFavorite(): void {
    const next = !this.favoriteActive;
    this.getUIContext().animateTo({
      duration: 260,
      curve: Curve.Friction,
      onFinish: () => {
        if (next && this.favoriteActive) {
          this.getUIContext().animateTo({
            duration: 420,
            curve: Curve.Friction,
          }, () => {
            this.favoriteGlowIntensity = 0;
          });
        }
      },
    }, () => {
      this.favoriteActive = next;
      this.favoriteGlowIntensity = next ? 0.54 : 0;
    });
    this.onSetFavorite(this.peer.id, next);
  }

  private favoriteLightIntensity(): number {
    if (this.pressedControl === 'favorite') {
      return 0.68;
    }
    return this.favoriteGlowIntensity;
  }

  private actionHighlighted(controlId: string): boolean {
    return controlId === 'files' && this.transferActive;
  }

  private actionLightIntensity(controlId: string): number {
    if (this.pressedControl === controlId) {
      return 0.62;
    }
    return 0;
  }

  private actionAccessibilityText(controlId: string): string {
    if (controlId === 'camera') {
      return '查看摄像头';
    }
    if (controlId === 'files') {
      return '打开文件传输';
    }
    return '开始远程控制';
  }

  @Builder
  private FavoriteSymbols(size: Resource) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.star'))
        .fontSize(size)
        .fontColor([$r('app.color.text_secondary')])
        .opacity(this.favoriteActive ? 0 : 1)
        .scale({ x: this.favoriteActive ? 0.72 : 1, y: this.favoriteActive ? 0.72 : 1 });

      SymbolGlyph($r('sys.symbol.star_fill'))
        .fontSize(size)
        .fontColor([$r('app.color.warning')])
        .opacity(this.favoriteActive ? 1 : 0)
        .scale({ x: this.favoriteActive ? 1 : 0.72, y: this.favoriteActive ? 1 : 0.72 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.favoriteActive
      ? $r('app.color.warning_soft')
      : $r('app.color.transparent'))
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.interactiveContent(
      this.favoriteLightIntensity() > 0,
      $r('app.color.warning'),
      this.favoriteLightIntensity(),
    ));
  }

  @Builder
  private FavoriteButton(compact: boolean) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      this.FavoriteSymbols(compact ? $r('app.float.icon_small') : $r('app.float.icon_regular'));
    }
    .width(compact ? $r('app.float.control_small') : $r('app.float.control_regular'))
    .height(compact ? $r('app.float.control_small') : $r('app.float.control_regular'))
    .padding(0)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.pressBlurScale('favorite'),
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .accessibilityText(this.favoriteActive ? '取消收藏设备' : '收藏设备')
    .accessibilityChecked(this.favoriteActive)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateControl('favorite', true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateControl('favorite', false);
      }
    })
    .onClick(() => this.toggleFavorite());
  }

  @Builder
  private RemoveButton(compact: boolean) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(compact ? $r('app.float.icon_small') : $r('app.float.icon_regular'))
          .fontColor([$r('app.color.white')]);
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.error'))
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.pressedControl === 'remove',
          $r('app.color.error'),
          0.66,
        ));
    }
    .width(compact ? $r('app.float.control_small') : $r('app.float.control_regular'))
    .height(compact ? $r('app.float.control_small') : $r('app.float.control_regular'))
    .padding(0)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.pressBlurScale('remove'),
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .accessibilityText('从最近设备中移除')
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateControl('remove', true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateControl('remove', false);
      }
    })
    .onClick(() => this.onRemoveRecent(this.peer.id));
  }

  @Builder
  private SessionAction(
    icon: string,
    label: ResourceStr,
    controlId: string,
    compact: boolean,
    onClick: () => void,
  ) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row({ space: $r('app.float.space_6') }) {
        Text(icon)
          .fontSize(compact ? $r('app.float.icon_small') : $r('app.float.icon_regular'))
          .fontColor(this.actionHighlighted(controlId)
            ? $r('app.color.white')
            : $r('app.color.text_primary'));
        Text(label)
          .fontSize(compact ? $r('app.float.font_label') : $r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.actionHighlighted(controlId)
            ? $r('app.color.white')
            : $r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.actionHighlighted(controlId)
        ? $r('app.color.brand_primary')
        : $r('app.color.transparent'))
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.interactiveContent(
        this.actionLightIntensity(controlId) > 0,
        $r('app.color.point_light'),
        this.actionLightIntensity(controlId),
      ));
    }
    .layoutWeight(1)
    .height(compact ? $r('app.float.control_small') : $r('app.float.control_regular'))
    .padding(0)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.pressBlurScale(controlId),
    })
    .shadow(this.actionHighlighted(controlId) ? {
      radius: 12,
      color: $r('app.color.point_light'),
      offsetX: 0,
      offsetY: 0,
    } : ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .scale({
      x: this.actionHighlighted(controlId) ? 1.018 : 1,
      y: this.actionHighlighted(controlId) ? 1.018 : 1,
    })
    .animation({
      duration: 1100,
      curve: Curve.Smooth,
      iterations: this.actionHighlighted(controlId) ? -1 : 1,
      playMode: PlayMode.Alternate,
    })
    .accessibilityText(this.actionAccessibilityText(controlId))
    .accessibilitySelected(this.actionHighlighted(controlId))
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateControl(controlId, true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateControl(controlId, false);
      }
    })
    .onClick(onClick);
  }

  @Builder
  private DeviceIdentity(compact: boolean) {
    Row({ space: compact ? $r('app.float.space_8') : $r('app.float.space_12') }) {
      Stack({ alignContent: Alignment.Center }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(compact ? $r('app.float.icon_regular') : $r('app.float.icon_large'))
            .fontColor([this.sourceAccent()]);
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.sourceBackground())
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.contentReceiver());
      }
      .width(compact ? $r('app.float.control_small') : $r('app.float.control_regular'))
      .height(compact ? $r('app.float.control_small') : $r('app.float.control_regular'))
      .backgroundColor($r('app.color.glass_surface'))
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 0.72,
      })
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.featherReceiver());

      Column({ space: $r('app.float.space_2') }) {
        Text(this.displayName())
          .width('100%')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(compact ? this.compactMetadata() : this.identityDetail())
          .width('100%')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      this.FavoriteButton(compact);
      if (this.peer.source === 'recent') {
        this.RemoveButton(compact);
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top);
  }

  @Builder
  private PeerStatus() {
    Row({ space: $r('app.float.space_8') }) {
      Circle()
        .width($r('app.float.space_8'))
        .height($r('app.float.space_8'))
        .fill(this.peer.online ? $r('app.color.success') : $r('app.color.text_tertiary'));
      Text(this.peer.online ? '在线' : '离线')
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.peer.online ? $r('app.color.success') : $r('app.color.text_tertiary'));
      Text(this.sourceText())
        .fontSize($r('app.float.font_caption'))
        .fontColor(this.sourceAccent())
        .maxLines(1);
      Text(`ID ${this.peer.id}`)
        .layoutWeight(1)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private SessionActions(compact: boolean) {
    Row({ space: $r('app.float.space_8') }) {
      this.SessionAction(
        '⌑',
        $r('app.string.device_action_remote'),
        'remote',
        compact,
        () => this.onConnectRemote(this.peer.id),
      );
      this.SessionAction(
        '◉',
        $r('app.string.device_action_camera'),
        'camera',
        compact,
        () => this.onViewCamera(this.peer.id),
      );
      this.SessionAction(
        '⇄',
        $r('app.string.device_action_files'),
        'files',
        compact,
        () => this.onOpenTransfer(this.peer.id),
      );
    }
    .width('100%');
  }

  @Builder
  private CardContent(compact: boolean) {
    Column({ space: compact ? $r('app.float.space_8') : $r('app.float.space_12') }) {
      this.DeviceIdentity(compact);
      if (!compact) {
        this.PeerStatus();
      }
      this.SessionActions(compact);
    }
    .width('100%')
    .padding(compact ? $r('app.float.space_12') : $r('app.float.space_20'))
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .borderRadius($r('app.float.radius_18'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.contentReceiver());
  }

  build() {
    Stack() {
      this.CardContent(this.compact);
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.72,
    })
    .linearGradient({
      angle: 142,
      colors: [
        [$r('app.color.glass_gradient_high'), 0],
        [$r('app.color.glass_gradient_mid'), 0.48],
        [$r('app.color.glass_gradient_accent'), 1],
      ],
    })
    .shadow(this.compact ? ShadowStyle.OUTER_DEFAULT_SM : ShadowStyle.OUTER_DEFAULT_MD)
    .borderRadius($r('app.float.radius_18'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }
}
