import { DirectorySnapshot, PeerRecord } from '../RustDeskDirectoryTypes';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
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
  @Local pressedControl: string = '';
  @Local targetFocused: boolean = false;
  @Local targetLightIntensity: number = 0;
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

  aboutToAppear(): void {
    this.syncTargetLight(this.target, false);
  }

  @Monitor('target')
  private onTargetChanged(_monitor: IMonitor): void {
    this.syncTargetLight(this.target, true);
  }

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

  private pressBlurScale(controlId: string): number {
    return this.pressedControl === controlId ? 0.18 : 0.72;
  }

  private pressed(controlId: string): boolean {
    return this.pressedControl === controlId;
  }

  private animatePress(controlId: string, active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      if (active) {
        this.pressedControl = controlId;
      } else if (this.pressedControl === controlId) {
        this.pressedControl = '';
      }
    });
  }

  private handleTouch(controlId: string, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.animatePress(controlId, true);
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.animatePress(controlId, false);
    }
  }

  private targetLightFor(value: string): number {
    if (!this.targetFocused) {
      return 0;
    }
    return Math.min(0.62, 0.14 + value.trim().length * 0.035);
  }

  private syncTargetLight(value: string, animated: boolean): void {
    const next = this.targetLightFor(value);
    if (!animated) {
      this.targetLightIntensity = next;
      return;
    }
    this.getUIContext().animateTo({
      duration: next > this.targetLightIntensity ? 180 : 420,
      curve: Curve.Friction,
    }, () => {
      this.targetLightIntensity = next;
    });
  }

  private setTargetFocused(focused: boolean): void {
    this.targetFocused = focused;
    this.syncTargetLight(this.target, true);
  }

  @Builder
  private SectionHeading(title: string, description: string) {
    Column({ space: $r('app.float.space_4') }) {
      Text(title)
        .width('100%')
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'));
      Text(description)
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .lineHeight(20)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private TargetField() {
    Stack() {
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
        .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.targetLightIntensity > 0,
          $r('app.color.point_light'),
          this.targetLightIntensity,
        ));

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
          .accessibilityText('远端设备 ID')
          .onFocus(() => this.setTargetFocused(true))
          .onBlur(() => this.setTargetFocused(false))
          .onChange((value: string) => {
            this.syncTargetLight(value, true);
            this.onTargetChange(value);
          });
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('app.float.space_8'), right: $r('app.float.space_16') })
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.contentReceiver());

      if (this.targetFocused) {
        Row()
          .width('100%')
          .height('100%')
          .border({ width: 2, color: $r('app.color.focus_ring') })
          .borderRadius($r('app.float.radius_14'))
          .hitTestBehavior(HitTestMode.None);
      }
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.72,
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }

  @Builder
  private ConnectButton() {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.connectButtonText())
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.targetReady()
            ? $r('app.color.white')
            : $r('app.color.disabled_text'));
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.targetReady()
        ? (this.pressed('connect')
          ? $r('app.color.brand_primary_pressed')
          : $r('app.color.brand_primary'))
        : $r('app.color.disabled_background'))
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.pressed('connect'),
          $r('app.color.point_light'),
        ));
    }
    .width('100%')
    .height($r('app.float.control_regular'))
    .padding(0)
    .enabled(this.targetReady())
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.pressBlurScale('connect'),
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .accessibilityText(this.connectButtonText())
    .onTouch((event: TouchEvent) => this.handleTouch('connect', event))
    .onClick(() => this.onConnectRemote());
  }

  @Builder
  private SecondaryAction(
    controlId: string,
    icon: string,
    label: string,
    onClick: () => void,
  ) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
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
      .backgroundColor($r('app.color.transparent'))
      .borderRadius($r('app.float.radius_14'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.interactiveContent(
        this.pressed(controlId),
        $r('app.color.point_light'),
      ));
    }
    .layoutWeight(1)
    .height($r('app.float.control_regular'))
    .padding(0)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.pressBlurScale(controlId),
    })
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .accessibilityText(label)
    .onTouch((event: TouchEvent) => this.handleTouch(controlId, event))
    .onClick(onClick);
  }

  @Builder
  private QuickConnectSection() {
    Column() {
      Stack() {
        Column({ space: $r('app.float.space_16') }) {
          this.TargetField();
          this.ConnectButton();

          Row({ space: $r('app.float.space_12') }) {
            this.SecondaryAction('camera', '◉', '摄像头', () => this.onViewCamera());
            this.SecondaryAction('transfer', '⇄', '文件传输', () => this.onOpenTransfer());
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);
        }
        .width('100%')
        .padding($r('app.float.space_20'))
        .borderRadius($r('app.float.radius_18'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.contentReceiver());
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
      .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      .borderRadius($r('app.float.radius_18'))
      .clip(true)
      .visualEffect(RustDeskGlassEffect.featherReceiver());
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private RecentSection() {
    Column({ space: $r('app.float.space_12') }) {
      this.SectionHeading('最近设备', '仅展示最后一次连接的设备。');

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
      .backgroundColor($r('app.color.background'));
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.background'))
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
