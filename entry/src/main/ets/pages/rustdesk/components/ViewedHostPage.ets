import { ControlledHostState } from '../../../services/controlled/ControlledHostTypes';
import { ViewedHostCard } from './ViewedHostCard';

export interface ViewedHostPageProps {
  state: ControlledHostState;
  scroller: Scroller;
  titleSpacerHeight: number;
  bottomAvoidInset: number;
  wideLayout: boolean;
  onStart: () => void;
  onStop: () => void;
  onAccept: (requestId: string, peerId: string) => void;
  onReject: (requestId: string, peerId: string) => void;
  onRefreshPassword: () => void;
}

@ComponentV2
export struct ViewedHostPage {
  @Param state: ControlledHostState = new ControlledHostState();
  @Param scroller: Scroller = new Scroller();
  @Param titleSpacerHeight: number = 56;
  @Param bottomAvoidInset: number = 0;
  @Param wideLayout: boolean = false;
  @Local viewportWidth: number = 760;
  @Event onStart: () => void = () => {};
  @Event onStop: () => void = () => {};
  @Event onAccept: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onReject: (requestId: string, peerId: string) => void = (_requestId: string, _peerId: string) => {};
  @Event onRefreshPassword: () => void = () => {};

  private horizontalPadding(): number {
    if (this.viewportWidth >= 1100) {
      return 48;
    }
    if (this.viewportWidth >= 720) {
      return 32;
    }
    return 20;
  }

  private contentWidth(): number {
    return Math.max(280, Math.min(this.viewportWidth - this.horizontalPadding() * 2, 760));
  }

  build(): void {
    Scroll(this.scroller) {
      Column({ space: 20 }) {
        Blank()
          .width('100%')
          .height(this.titleSpacerHeight)
          .flexShrink(0);
        Column({ space: 6 }) {
          Text('观看此设备')
            .width('100%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.neu_text_primary'));
          Text('仅共享本机屏幕和系统音频，远端不能控制此设备。')
            .width('100%')
            .fontSize(13)
            .lineHeight(20)
            .fontColor($r('app.color.neu_text_secondary'));
        }
        .width(this.contentWidth())
        .alignItems(HorizontalAlign.Start);
        ViewedHostCard({
          state: this.state,
          surfaceWidth: this.contentWidth(),
          onStart: () => this.onStart(),
          onStop: () => this.onStop(),
          onAccept: (requestId: string, peerId: string) => this.onAccept(requestId, peerId),
          onReject: (requestId: string, peerId: string) => this.onReject(requestId, peerId),
          onRefreshPassword: () => this.onRefreshPassword(),
        });
        Blank()
          .width('100%')
          .height((this.wideLayout ? 48 : 120) + this.bottomAvoidInset)
          .flexShrink(0);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .onAreaChange((_oldArea: Area, newArea: Area): void => {
        const width: number = Number(newArea.width);
        if (width > 0) {
          this.viewportWidth = width;
        }
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
  }
}
