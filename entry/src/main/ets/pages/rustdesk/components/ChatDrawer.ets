import { ChatMessage } from '../RustDeskSessionTypes';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';
import { FloatingDepthOverlay, FloatingPressDepthShell } from './FloatingDepth';

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
  @Local pressedControl: string = '';
  @Local draftValue: string = '';
  @Local inputFocused: boolean = false;
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

  private blurScale(key: string): number {
    return this.pressedControl === key ? 0.18 : 0.48;
  }

  private animateBlur(key: string, active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      if (active) {
        this.pressedControl = key;
      } else if (this.pressedControl === key) {
        this.pressedControl = '';
      }
    });
  }

  private buttonLightIntensity(key: string, emphasized: boolean): number {
    if (this.pressedControl === key) {
      return 0.62;
    }
    return emphasized ? 0.14 : 0;
  }

  @Builder
  private FloatingButton(key: string, label: string, emphasized: boolean, onClick: () => void) {
    Stack() {
      FloatingPressDepthShell({
        pressed: this.pressedControl === key,
        compact: true,
        radius: $r('app.float.radius_14'),
      }) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack({ alignContent: Alignment.Center }) {
            if (emphasized) {
              Row()
                .width('100%')
                .height('100%')
                .backgroundColor($r('app.color.brand_primary'));
            }

            FloatingDepthOverlay({
              pressed: this.pressedControl === key,
              compact: true,
              radius: $r('app.float.radius_14'),
            });

            Text(label)
              .fontSize($r('app.float.font_body'))
              .fontWeight(FontWeight.Medium)
              .fontColor(emphasized ? $r('app.color.white') : $r('app.color.text_primary'));
          }
          .width('100%')
          .height('100%')
          .borderRadius($r('app.float.radius_14'))
          .clip(true)
          .visualEffect(RustDeskGlassEffect.interactiveContent(
            this.buttonLightIntensity(key, emphasized) > 0,
            emphasized ? $r('app.color.point_light') : $r('app.color.brand_primary'),
            this.buttonLightIntensity(key, emphasized),
          ));
        }
        .width('100%')
        .height('100%')
        .padding(0)
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: this.blurScale(key),
        })
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.glass_gradient_high'), 0],
            [$r('app.color.glass_gradient_mid'), 0.48],
            [$r('app.color.glass_gradient_accent'), 1],
          ],
        })
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.featherReceiver())
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.animateBlur(key, true);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.animateBlur(key, false);
          }
        })
        .onClick(onClick);
      }
    }
    .width(72)
    .height(42)
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
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
    .backgroundColor(message.outgoing ? $r('app.color.brand_primary_soft') : $r('app.color.surface_secondary'))
    .borderRadius($r('app.float.radius_14'));
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
      .clip(false);

      Row({ space: $r('app.float.space_8') }) {
        Stack() {
          FloatingDepthOverlay({
            radius: $r('app.float.radius_14'),
          });

          Stack() {
            TextInput({ text: this.draftValue, placeholder: '输入消息' })
              .width('100%')
              .height('100%')
              .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
              .backgroundColor($r('app.color.transparent'))
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .borderWidth(0)
              .enterKeyType(EnterKeyType.Send)
              .onFocus(() => this.inputFocused = true)
              .onBlur(() => this.inputFocused = false)
              .onChange((value: string) => this.updateDraft(value))
              .onSubmit((_enterKey: EnterKeyType) => this.submitDraft());
          }
          .width('100%')
          .height('100%')
          .borderRadius($r('app.float.radius_14'))
          .clip(true)
          .visualEffect(RustDeskGlassEffect.contentReceiver());

        }
        .layoutWeight(1)
        .height($r('app.float.control_regular'))
        .backgroundColor($r('app.color.glass_surface'))
        .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: this.inputFocused ? 0.90 : 0.48,
        })
        .linearGradient({
          angle: 142,
          colors: [
            [$r('app.color.glass_gradient_high'), 0],
            [$r('app.color.glass_gradient_mid'), 0.48],
            [$r('app.color.glass_gradient_accent'), 1],
          ],
        })
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_SM)
        .visualEffect(RustDeskGlassEffect.featherReceiver());

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
      bottom: $r('app.float.space_8'),
    })
    .clip(false);
  }
}
