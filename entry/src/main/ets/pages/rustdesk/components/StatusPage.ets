import {
  LuminousButton,
  LuminousControlSize,
  LuminousTone,
} from 'luminous_neo';
import { FloatingGlassSurface } from './FloatingSurface';

export interface StatusPageProps {
  sessionPhase: string;
  connectionSummary: string;
  sessionMessage: string;
  qualitySummary: string;
  renderFpsText: string;
  frameStatus: string;
  buildMarker: string;
  onBack: () => void;
}

@ComponentV2
export struct StatusPage {
  @Param sessionPhase: string = 'idle';
  @Param connectionSummary: string = '未连接';
  @Param sessionMessage: string = '未连接';
  @Param qualitySummary: string = 'Remote fps -- | delay -- | codec --';
  @Param renderFpsText: string = 'FPS --';
  @Param frameStatus: string = 'Surface not ready';
  @Param buildMarker: string = '';
  @Event onBack: () => void = () => {};

  @Builder
  private StatusInfo() {
    Stack() {
      FloatingGlassSurface({
        radius: $r('app.float.radius_24'),
      }) {
        Column({ space: $r('app.float.space_8') }) {
          Text(`状态: ${this.sessionPhase}`)
            .fontSize($r('app.float.font_body_large'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));
          Text(this.connectionSummary)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_primary'));
          Text(this.sessionMessage)
            .fontSize($r('app.float.font_label'))
            .fontColor($r('app.color.text_secondary'));
          Text(this.qualitySummary)
            .fontSize($r('app.float.font_label'))
            .fontColor($r('app.color.text_secondary'));
          Text(this.renderFpsText)
            .fontSize($r('app.float.font_label'))
            .fontColor($r('app.color.text_secondary'));
          Text(this.frameStatus)
            .fontSize($r('app.float.font_label'))
            .fontColor($r('app.color.text_secondary'));
          Text(`Build: ${this.buildMarker || 'unknown'}`)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_tertiary'));
        }
        .width('100%')
        .padding($r('app.float.card_padding'))
        .borderRadius($r('app.float.radius_24'))
        .clip(true);
      }
    }
    .width('100%');
  }

  @Builder
  private BackButton() {
    Row() {
      LuminousButton({
        label: '返回连接页',
        controlWidth: 220,
        controlSizeMode: LuminousControlSize.Regular,
        tone: LuminousTone.Accent,
        onAction: (): void => this.onBack(),
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .clip(false)
    .accessibilityText('返回连接页');
  }

  build() {
    Scroll() {
      Column({ space: $r('app.float.space_16') }) {
        Column({ space: 6 }) {
          Text('会话状态')
            .fontSize($r('app.float.font_display'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));

          Text('连接状态与渲染信息集中展示在这里。')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'));
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%');

        this.StatusInfo()
        this.BackButton()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: $r('app.float.page_horizontal'),
        right: $r('app.float.page_horizontal'),
        top: $r('app.float.page_top'),
        bottom: $r('app.float.page_bottom'),
      });
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.transparent'));
  }
}
