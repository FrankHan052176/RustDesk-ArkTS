import { RemoteSessionTab } from '../RemoteSessionTabsController';

@ComponentV2
export struct RemoteSessionTabStrip {
  @Param tabs: Array<RemoteSessionTab> = [];
  @Param activeSessionId: string = '';
  @Param wideLayout: boolean = false;
  @Param canAdd: boolean = true;
  @Event onSelect: (sessionId: string) => void = (_sessionId: string): void => {};
  @Event onClose: (sessionId: string) => void = (_sessionId: string): void => {};
  @Event onAdd: () => void = (): void => {};
  private tabScroller: Scroller = new Scroller();

  private statusColor(tab: RemoteSessionTab): ResourceColor {
    if (tab.needsAttention || tab.phase === 'failed' || tab.phase === 'closed') {
      return $r('app.color.error');
    }
    if (tab.connected) {
      return $r('app.color.success');
    }
    return $r('app.color.warning');
  }

  private tabWidth(): number {
    return this.wideLayout ? 208 : 156;
  }

  private sessionAccessibilityText(tab: RemoteSessionTab): string {
    let text = `${tab.label}，${tab.connected ? '已连接' : tab.phase}`;
    if (tab.unreadCount > 0) {
      text += `，${tab.unreadCount} 条未读消息`;
    }
    if (tab.needsAttention) {
      text += '，需要处理';
    }
    return text;
  }

  @Builder
  private SessionTab(tab: RemoteSessionTab) {
    Row({ space: 2 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 8 }) {
          Stack()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(this.statusColor(tab));

          Column({ space: 1 }) {
            Text(tab.label)
              .fontSize(this.wideLayout ? 13 : 12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            if (this.wideLayout) {
              Text(tab.target)
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          if (tab.needsAttention || tab.unreadCount > 0) {
            Text(tab.unreadCount > 9 ? '9+' : (tab.unreadCount > 0 ? `${tab.unreadCount}` : '!'))
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.white'))
              .textAlign(TextAlign.Center)
              .width(tab.unreadCount > 9 ? 22 : 16)
              .height(16)
              .borderRadius(8)
              .backgroundColor($r('app.color.error'));
          }
        }
        .width('100%')
        .padding({ left: 10, right: 6 });
      }
      .layoutWeight(1)
      .height(48)
      .padding(0)
      .backgroundColor($r('app.color.transparent'))
      .hoverEffect(HoverEffect.Auto)
      .accessibilityText(this.sessionAccessibilityText(tab))
      .accessibilitySelected(tab.sessionId === this.activeSessionId)
      .onClick((): void => this.onSelect(tab.sessionId));

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text($r('app.string.remote_session_tab_close_symbol'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'));
      }
      .width(48)
      .height(48)
      .padding(0)
      .backgroundColor($r('app.color.transparent'))
      .hoverEffect(HoverEffect.Auto)
      .accessibilityText(`${tab.label}，断开并关闭此会话`)
      .onClick((): void => this.onClose(tab.sessionId));
    }
    .width(this.tabWidth())
    .height(52)
    .padding({ left: 2, right: 2 })
    .borderRadius($r('app.float.radius_14'))
    .backgroundColor(tab.sessionId === this.activeSessionId
      ? $r('app.color.brand_primary_soft')
      : $r('app.color.glass_surface'))
    .border({
      width: 1,
      color: tab.sessionId === this.activeSessionId
        ? $r('app.color.brand_primary')
        : $r('app.color.mica_border'),
    });
  }

  build() {
    Row({ space: 8 }) {
      Scroll(this.tabScroller) {
        Row({ space: 6 }) {
          ForEach(this.tabs, (tab: RemoteSessionTab) => {
            this.SessionTab(tab);
          }, (tab: RemoteSessionTab): string => tab.sessionId);
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .layoutWeight(1)
      .height(52);

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text($r('app.string.remote_session_tab_add_symbol'))
          .fontSize(22)
          .fontColor(this.canAdd ? $r('app.color.text_primary') : $r('app.color.text_tertiary'));
      }
      .width(48)
      .height(48)
      .padding(0)
      .enabled(this.canAdd)
      .backgroundColor($r('app.color.glass_surface'))
      .border({ width: 1, color: $r('app.color.mica_border') })
      .hoverEffect(HoverEffect.Auto)
      .accessibilityText($r('app.string.remote_session_tab_add'))
      .onClick((): void => this.onAdd());
    }
    .width('100%')
    .height(60)
    .padding({ left: 4, right: 4 })
    .alignItems(VerticalAlign.Center);
  }
}
