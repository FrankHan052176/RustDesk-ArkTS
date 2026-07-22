import { ChatMessage } from '../RustDeskSessionTypes';

export interface ChatDrawerProps {
  messages: ChatMessage[];
  draft: string;
  unreadCount: number;
  onDraftChange: (value: string) => void;
  onSend: (value: string) => void;
  onRetry: (localId: string) => void;
  onClose: () => void;
}

@ComponentV2
export struct ChatDrawer {
  @Param messages: ChatMessage[] = [];
  @Param draft: string = '';
  @Param unreadCount: number = 0;
  @Local draftValue: string = '';
  @Event onDraftChange: (value: string) => void = (_value: string) => {};
  @Event onSend: (value: string) => void = (_value: string) => {};
  @Event onRetry: (localId: string) => void = (_localId: string) => {};
  @Event onClose: () => void = () => {};

  aboutToAppear(): void {
    this.draftValue = this.draft;
  }

  @Monitor('draft')
  private onDraftChanged(_monitor: IMonitor): void {
    if (this.draftValue !== this.draft) {
      this.draftValue = this.draft;
    }
  }

  private updateDraft(value: string): void {
    this.draftValue = value;
    this.onDraftChange(value);
  }

  private submitDraft(): void {
    const value = this.draftValue.trim();
    if (value.length === 0) {
      return;
    }
    this.draftValue = '';
    this.onDraftChange('');
    this.onSend(value);
  }

  private messageMetadata(message: ChatMessage): string {
    const direction = message.outgoing ? '我' : '远端';
    return `${direction} · ${message.sentAt} · ${this.stateText(message.state)}`;
  }

  private stateText(state: string): string {
    if (state === 'pending') {
      return '发送中';
    }
    if (state === 'failed') {
      return '发送失败';
    }
    return '已发送';
  }

  @Builder
  private FloatingButton(_key: string, label: string, emphasized: boolean, onClick: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor(emphasized ? $r('app.color.neu_accent') : $r('app.color.neu_text_primary'));
    }
    .width(72)
    .height(42)
    .padding(0)
    .backgroundColor($r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .hoverEffect(HoverEffect.None)
    .accessibilityText(label)
    .onClick((): void => {
      onClick();
    });
  }

  @Builder
  private MessageItem(message: ChatMessage) {
    Column({ space: $r('app.float.space_6') }) {
      Text(this.messageMetadata(message))
        .fontSize($r('app.float.font_label'))
        .fontColor(message.state === 'failed' ? $r('app.color.error') : $r('app.color.text_tertiary'));

      Text(message.text)
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'));

      if (message.outgoing && message.state === 'failed') {
        this.FloatingButton(`retry-${message.localId}`, '重试', false, () => this.onRetry(message.localId))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('app.float.space_12'))
    .backgroundColor(message.outgoing ? $r('app.color.brand_primary_soft') : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({ width: 1, color: $r('app.color.mica_border') })
    .borderRadius($r('app.float.radius_14'))
    .clip(true);
  }

  build() {
    Column({ space: $r('app.float.space_12') }) {
      Scroll() {
        Column({ space: $r('app.float.space_8') }) {
          ForEach(this.messages, (message: ChatMessage) => {
            this.MessageItem(message);
          }, (message: ChatMessage) => message.localId)

          if (this.messages.length === 0) {
            Text('暂无聊天消息')
              .width('100%')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .padding($r('app.float.space_20'));
          }
        }
        .width('100%');
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .borderRadius($r('app.float.radius_14'))
      .clip(true);

      Row({ space: $r('app.float.space_8') }) {
        TextInput({ text: this.draftValue, placeholder: '输入消息' })
          .layoutWeight(1)
          .height($r('app.float.control_regular'))
          .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
          .backgroundColor($r('app.color.mica_control'))
          .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
            adaptiveColor: AdaptiveColor.DEFAULT,
            scale: 0.56,
          })
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .border({ width: 1, color: $r('app.color.mica_border') })
          .borderRadius($r('app.float.radius_14'))
          .enterKeyType(EnterKeyType.Send)
          .onChange((value: string) => this.updateDraft(value))
          .onSubmit((_enterKey: EnterKeyType) => this.submitDraft());

        this.FloatingButton('send', '发送', true, () => this.submitDraft())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .padding({
      left: $r('app.float.space_8'),
      right: $r('app.float.space_8'),
      top: $r('app.float.space_4'),
      bottom: $r('app.float.space_8'),
    })
    .borderRadius($r('app.float.radius_14'))
    .clip(true);
  }
}
