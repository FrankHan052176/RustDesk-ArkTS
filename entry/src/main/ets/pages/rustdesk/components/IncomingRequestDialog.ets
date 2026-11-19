import { ControlledHostState, ControlledIncomingPeer } from '../../../services/controlled/ControlledHostTypes';

export interface IncomingRequestDialogProps {
  state: ControlledHostState;
  /** False while the host page, which shows the same request inline, is in front. */
  showOverlay: boolean;
  onAccept: (requestId: string, peerId: string) => void;
  onReject: (requestId: string, peerId: string) => void;
  /** The dialog came up or went away. */
  onPresentedChange: () => void;
}

/**
 * Someone is asking to connect to this device, shown wherever the operator is.
 *
 * The request used to be visible only on the host page, so a device that was in
 * a remote session, in settings or on the connect page gave no sign of it and
 * the other side timed out. This is the same request and the same two decisions
 * the host card offers; it adds no state of its own.
 */
@ComponentV2
export struct IncomingRequestDialog {
  @Param state: ControlledHostState = new ControlledHostState();
  @Param showOverlay: boolean = true;
  @Event onAccept: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onReject: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onPresentedChange: () => void = () => {};

  /**
   * While this is up over a remote session, keys belong to the decision here,
   * not to the other device: whoever owns keyboard capture re-decides it.
   */
  @Monitor('state.incoming', 'showOverlay')
  private onPresentedChanged(_monitor: IMonitor): void {
    this.onPresentedChange();
  }

  // Each reader takes the request from the state itself and answers for "no
  // request" too, so nothing in `build` depends on a narrowed type surviving
  // into a child block.
  private peerLabel(): string {
    const peer: ControlledIncomingPeer | undefined = this.state.incoming;
    if (peer === undefined) {
      return '';
    }
    return peer.peerName.length > 0 ? peer.peerName : peer.peerId;
  }

  private peerDetail(): string {
    const peer: ControlledIncomingPeer | undefined = this.state.incoming;
    if (peer === undefined) {
      return '';
    }
    return peer.peerName.length > 0 && peer.peerId.length > 0 ? `ID ${peer.peerId}` : '';
  }

  /** What accepting grants, from the host's own state, not from the request. */
  private grantText(): string {
    return this.state.inputEnabled && this.state.inputAuthorization === 'authorized'
      ? '同意后，对方可以看到并操作这台设备的屏幕。'
      : '同意后，对方只能观看这台设备的屏幕，不能操作。';
  }

  /** The handshake's own evidence; unknown stays unsaid. */
  private securityText(): string {
    const peer: ControlledIncomingPeer | undefined = this.state.incoming;
    if (peer === undefined) {
      return '';
    }
    if (peer.encrypted === false) {
      return '这条连接没有加密，也无法确认对方身份。';
    }
    if (peer.encrypted === true && peer.peerVerified === false) {
      return '连接已加密，但无法确认对方身份。';
    }
    if (peer.encrypted === true) {
      return '连接已加密。';
    }
    return '';
  }

  /** Anything short of an encrypted connection to a proven peer is a warning. */
  private securityIsWarning(): boolean {
    const peer: ControlledIncomingPeer | undefined = this.state.incoming;
    return peer !== undefined && (peer.encrypted === false || peer.peerVerified === false);
  }

  private decide(allow: boolean): void {
    const peer: ControlledIncomingPeer | undefined = this.state.incoming;
    if (peer === undefined) {
      return;
    }
    if (allow) {
      this.onAccept(peer.requestId, peer.peerId);
    } else {
      this.onReject(peer.requestId, peer.peerId);
    }
  }

  private acceptLabel(): string {
    return this.state.inputEnabled && this.state.inputAuthorization === 'authorized' ? '同意控制' : '同意观看';
  }

  @Builder
  private DecisionButton(label: string, accent: boolean, onClick: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor(accent ? $r('app.color.white') : $r('app.color.error'));
    }
    .layoutWeight(1)
    .height(44)
    .backgroundColor(accent ? $r('app.color.brand_primary') : $r('app.color.surface_secondary'))
    .border({ width: 1, color: accent ? $r('app.color.brand_primary') : $r('app.color.outline') })
    .borderRadius($r('app.float.radius_14'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label)
    .onClick((): void => {
      onClick();
    });
  }

  build(): void {
    if (this.showOverlay && this.state.incoming !== undefined) {
      Stack({ alignContent: Alignment.Center }) {
        Column({ space: $r('app.float.space_12') }) {
          Text('有设备请求连接')
            .width('100%')
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));

          Text(this.peerLabel())
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          if (this.peerDetail().length > 0) {
            Text(this.peerDetail())
              .width('100%')
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }

          Text(this.grantText())
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .lineHeight(21)
            .fontColor($r('app.color.text_secondary'));

          if (this.securityText().length > 0) {
            Text(this.securityText())
              .width('100%')
              .fontSize($r('app.float.font_label'))
              .lineHeight(18)
              .fontColor(this.securityIsWarning() ? $r('app.color.error') : $r('app.color.text_secondary'));
          }

          if (this.state.incomingResolving) {
            Row({ space: $r('app.float.space_12') }) {
              LoadingProgress()
                .width($r('app.float.icon_regular'))
                .height($r('app.float.icon_regular'))
                .color($r('app.color.brand_primary'));
              Text('正在处理…')
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.text_secondary'));
            }
            .width('100%')
            .height(44)
            .justifyContent(FlexAlign.Center);
          } else {
            Row({ space: $r('app.float.space_12') }) {
              this.DecisionButton('拒绝', false, (): void => this.decide(false))
              this.DecisionButton(this.acceptLabel(), true, (): void => this.decide(true))
            }
            .width('100%');
          }
        }
        .width('calc(100% - 40vp)')
        .constraintSize({ minWidth: 312, maxWidth: 520 })
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.outline') })
        .borderRadius($r('app.float.radius_24'))
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD);
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.overlay'))
      .accessibilityGroup(true)
      .accessibilityText('有设备请求连接');
    }
  }
}
