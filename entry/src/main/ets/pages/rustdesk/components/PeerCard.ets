import { LuminousButton, LuminousControlSize, LuminousTextField, LuminousTone } from 'luminous_neo';
import { PeerProtocol, PeerRecord, PeerViewSource } from '../RustDeskDirectoryTypes';
import {
  bareTargetAddress,
  peerDisplaySubtitle,
  peerDisplayTitle,
  peerOnlineState,
  peerReachability,
  peerProtocolLabel,
  peerProtocolOf,
} from '../RustDeskPeerDirectoryModel';
import { FloatingActionSurface, FloatingGlassSurface } from './FloatingSurface';
import { deviceConnectionTarget } from '../SavedDeviceModel';

export interface PeerCardProps {
  peer: PeerRecord;
  viewSource: PeerViewSource;
  compact: boolean;
  cardWidth: number;
  removeEnabled: boolean;
  onSetFavorite: (target: string, protocol: PeerProtocol, favorite: boolean, rustdeskIdOnly: boolean) => void;
  onEditNote: (target: string, protocol: PeerProtocol, note: string, rustdeskIdOnly: boolean) => void;
  onRemoveRecent: (target: string, protocol: PeerProtocol, rustdeskIdOnly: boolean) => void;
  onRemoveLan: (target: string, protocol: PeerProtocol) => void;
  onConnectRemote: (peerId: string, rustdeskIdOnly: boolean) => void;
  onConnectVnc: (peerId: string) => void;
  onConnectRdp: (peerId: string) => void;
  onEditDevice: (peer: PeerRecord) => void;
}

@ComponentV2
export struct PeerCard {
  @Param peer: PeerRecord = new PeerRecord();
  @Param viewSource: PeerViewSource = 'recent';
  @Param compact: boolean = false;
  @Param cardWidth: number = 0;
  @Param removeEnabled: boolean = true;
  @Local noteEditing: boolean = false;
  @Local noteDraft: string = '';
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
  @Event onEditDevice: (peer: PeerRecord) => void = (_peer: PeerRecord): void => {};

  private displayName(): string {
    return peerDisplayTitle(this.peer);
  }

  private identityDetail(): string {
    return peerDisplaySubtitle(this.peer);
  }

  private canEditNote(): boolean {
    return this.viewSource !== 'addressBook';
  }

  private noteText(): string {
    return this.peer.note.trim();
  }

  private noteActionLabel(): ResourceStr {
    return this.noteText().length > 0
      ? $r('app.string.device_note_edit')
      : $r('app.string.device_note_add');
  }

  private noteFieldWidth(): number {
    return this.cardWidth > 96 ? Math.max(120, this.cardWidth - 40) : 220;
  }

  private beginNoteEdit(): void {
    this.noteDraft = this.peer.note;
    this.noteEditing = true;
  }

  private cancelNoteEdit(): void {
    this.noteDraft = this.peer.note;
    this.noteEditing = false;
  }

  private commitNoteEdit(): void {
    this.onEditNote(this.connectionTarget(), peerProtocolOf(this.peer), this.noteDraft.trim(), this.peer.rustdeskIdOnly);
    this.noteEditing = false;
  }

  private connectionTarget(): string {
    return deviceConnectionTarget(this.peer);
  }

  /** `VNC` or `RDP` when the peer's protocol names that scheme, otherwise empty. */
  private protocolBadge(): string {
    return peerProtocolLabel(peerProtocolOf(this.peer));
  }

  private protocolAccent(): ResourceColor {
    if (this.protocolBadge() === 'VNC') {
      return $r('app.color.brand_secondary');
    }
    return $r('app.color.brand_primary');
  }

  /** The action a tap on the primary button takes, following the peer's protocol. */
  private activateDefaultProtocol(): void {
    const protocol = peerProtocolOf(this.peer);
    if (protocol === 'vnc') {
      this.onConnectVnc(bareTargetAddress(this.connectionTarget()));
      return;
    }
    if (protocol === 'rdp') {
      this.onConnectRdp(bareTargetAddress(this.connectionTarget()));
      return;
    }
    this.onConnectRemote(this.connectionTarget(), this.peer.rustdeskIdOnly);
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

  private avatarAccent(): ResourceColor {
    return peerReachability(this.peer) === true
      ? this.sourceAccent()
      : $r('app.color.neu_text_disabled');
  }

  private avatarBackground(): ResourceColor {
    return peerReachability(this.peer) === true
      ? this.sourceBackground()
      : $r('app.color.surface_tertiary');
  }

  /**
   * A peer the runtime has not observed reads as `device_status_checking`, not
   * as offline: after a restart an unobserved peer is unknown, and claiming it
   * is offline would be a reachability claim nobody made.
   */
  private onlineStatusText(): ResourceStr {
    const state = peerOnlineState(peerReachability(this.peer));
    if (state === 'unknown') {
      return $r('app.string.device_status_checking');
    }
    return state === 'online'
      ? $r('app.string.device_status_online')
      : $r('app.string.device_status_offline');
  }

  private onlineStatusColor(): ResourceColor {
    return peerReachability(this.peer) === true
      ? $r('app.color.success')
      : $r('app.color.neu_text_secondary');
  }

  private onlineStatusDotColor(): ResourceColor {
    const state = peerOnlineState(peerReachability(this.peer));
    if (state === 'unknown') {
      return $r('app.color.info');
    }
    return state === 'online' ? $r('app.color.success') : $r('app.color.neu_text_disabled');
  }

  private toggleFavorite(): void {
    this.onSetFavorite(this.connectionTarget(), peerProtocolOf(this.peer), !this.peer.favorite, this.peer.rustdeskIdOnly);
  }

  private canRemoveFromCurrentView(): boolean {
    return this.viewSource === 'recent' || this.viewSource === 'lan';
  }

  private removeFromCurrentView(): void {
    if (this.viewSource === 'lan') {
      this.onRemoveLan(this.connectionTarget(), peerProtocolOf(this.peer));
    } else if (this.viewSource === 'recent') {
      this.onRemoveRecent(this.connectionTarget(), peerProtocolOf(this.peer), this.peer.rustdeskIdOnly);
    }
  }


  private sessionSurfaceWidth(): number {
    return this.cardWidth > 32 ? this.cardWidth - 32 : 0;
  }

  @Builder
  private FavoriteButton() {
    Stack({ alignContent: Alignment.Center }) {
      Stack() {
        FloatingActionSurface({
          compact: true,
          subtleDepth: true,
          actionEnabled: false,
          accessibilityLabel: this.peer.favorite ? '取消收藏设备' : '收藏设备',
          onActivate: (): void => {},
        }) {
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph(this.peer.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
              .fontSize(18)
              .fontColor([this.peer.favorite
                ? $r('app.color.warning')
                : $r('app.color.neu_text_secondary')]);
          }
          .width('100%')
          .height('100%');
        }
      }
      .width(38)
      .height(38)
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no');

      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row()
      }
        .width(48)
        .height(48)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .hoverEffect(HoverEffect.None)
        .borderRadius(0)
        .hitTestBehavior(HitTestMode.Block)
        .zIndex(10)
        .accessibilityText(this.peer.favorite ? '取消收藏设备' : '收藏设备')
        .onClick((): void => this.toggleFavorite());
    }
    .width(48)
    .height(48)
    .clip(false);
  }

  @Builder
  private RemoveButton() {
    Stack({ alignContent: Alignment.Center }) {
      Stack() {
        FloatingActionSurface({
          compact: true,
          subtleDepth: true,
          actionEnabled: false,
          accessibilityLabel: this.viewSource === 'lan' ? '从局域网设备中移除' : '从最近设备中移除',
          onActivate: (): void => {},
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
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no');

      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row()
      }
        .width(48)
        .height(48)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .hoverEffect(HoverEffect.None)
        .borderRadius(0)
        .hitTestBehavior(HitTestMode.Block)
        .zIndex(10)
        .enabled(this.removeEnabled)
        .accessibilityText(this.viewSource === 'lan' ? '从局域网设备中移除' : '从最近设备中移除')
        .onClick((): void => this.removeFromCurrentView());
    }
    .width(48)
    .height(48)
    .clip(false);
  }

  @Builder
  private IdentityRow() {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('sys.symbol.display'))
          .fontSize(22)
          .fontColor([this.avatarAccent()]);
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(this.avatarBackground());

      Column({ space: 3 }) {
        Text(this.displayName())
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Row({ space: 6 }) {
          Text(this.identityDetail())
            .layoutWeight(1)
            .fontSize(12)
            .fontColor($r('app.color.neu_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          if (this.protocolBadge().length > 0) {
            Text(this.protocolBadge())
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.protocolAccent())
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .borderRadius($r('app.float.radius_6'))
              .backgroundColor($r('app.color.mica_control'));
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Row({ space: 16 }) {
        this.FavoriteButton();

        if (this.canRemoveFromCurrentView()) {
          this.RemoveButton();
        }
      }
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private NoteRow() {
    if (this.canEditNote()) {
      if (this.noteEditing) {
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text($r('app.string.device_note_label'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_text_secondary'))
              .layoutWeight(1);
            Button({ type: ButtonType.Normal, stateEffect: false }) {
              Text($r('app.string.device_note_cancel'))
                .fontSize(11)
                .fontColor($r('app.color.neu_text_secondary'));
            }
              .height(28)
              .padding({ left: 8, right: 8 })
              .backgroundColor(Color.Transparent)
              .hoverEffect(HoverEffect.None)
              .accessibilityText('取消编辑本机备注')
              .onClick((): void => this.cancelNoteEdit());
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Row() {
            LuminousTextField({
              value: this.noteDraft,
              placeholder: $r('app.string.device_note_placeholder'),
              fieldWidth: this.noteFieldWidth(),
              fieldHeight: 42,
              motionEnabled: true,
              onChange: (value: string): void => {
                this.noteDraft = value;
              },
            });
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .clip(false);

          Row() {
            LuminousButton({
              label: $r('app.string.device_note_save'),
              controlWidth: 112,
              controlSizeMode: LuminousControlSize.Compact,
              tone: LuminousTone.Accent,
              motionEnabled: true,
              onAction: (): void => this.commitNoteEdit(),
            });
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .clip(false);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      } else {
        Row({ space: 8 }) {
          Text($r('app.string.device_note_label'))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          Text(this.noteText().length > 0
            ? this.noteText()
            : $r('app.string.device_note_placeholder'))
            .layoutWeight(1)
            .fontSize(11)
            .fontColor(this.noteText().length > 0
              ? $r('app.color.neu_text_primary')
              : $r('app.color.neu_text_disabled'))
            .maxLines(2)
            .lineHeight(16)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Button({ type: ButtonType.Normal, stateEffect: false }) {
            Text(this.noteActionLabel())
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.neu_accent'));
          }
            .height(30)
            .padding({ left: 8, right: 8 })
            .backgroundColor($r('app.color.mica_control'))
            .hoverEffect(HoverEffect.None)
            .borderRadius($r('app.float.radius_6'))
            .accessibilityText('编辑本机备注')
            .onClick((): void => this.beginNoteEdit());
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
    }
  }

  @Builder
  private StatusRow() {
    Row({ space: 8 }) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(this.onlineStatusDotColor());
      Text(this.onlineStatusText())
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.onlineStatusColor());
      Text(this.peer.platform.trim())
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
            this.SessionAction(
              this.peer.rustdeskIdOnly ? $r('app.string.resk_connect_claimed_id') :
                (this.protocolBadge().length > 0 ? this.protocolBadge() : $r('app.string.resk_connect')),
              true,
              (): void => this.activateDefaultProtocol(),
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
        measurementKey: this.noteEditing ? 'note-editing' : 'note-display',
      }) {
        Column({ space: this.compact ? 8 : 12 }) {
          this.IdentityRow();
          this.NoteRow();
          if (this.viewSource !== 'addressBook') {
            Button($r('app.string.device_editor_edit'), { type: ButtonType.Normal })
              .height(44)
              .backgroundColor($r('app.color.mica_control'))
              .fontColor($r('app.color.neu_accent'))
              .onClick((): void => this.onEditDevice(this.peer));
          }
          this.StatusRow();
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
