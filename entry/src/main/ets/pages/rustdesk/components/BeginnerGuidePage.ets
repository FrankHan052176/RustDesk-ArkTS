import { common } from '@kit.AbilityKit';
import {
  LuminousButton,
  LuminousControlSize,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSurface,
  LuminousTone,
} from 'luminous_neo';

const FEEDBACK_GROUP_ID: string = '1072745132';
const FEEDBACK_GROUP_URI: string =
  `mqqapi://card/show_pslcard?src_type=internal&version=1&uin=${FEEDBACK_GROUP_ID}&card_type=group&source=qrcode`;

@ComponentV2
export struct BeginnerGuidePage {
  @Local viewportWidth: number = 390;
  @Local selectedPathIndex: number = 0;

  private contentWidth(): number {
    return Math.max(280, Math.min(this.viewportWidth, 900));
  }

  private surfaceWidth(): number {
    return Math.max(264, this.contentWidth() - 16);
  }

  private pathItems(): LuminousSelectionItem[] {
    return [
      new LuminousSelectionItem('direct', '局域网 / 组网', 'IP 直连'),
      new LuminousSelectionItem('server', '服务器连接', 'ID 连接'),
    ];
  }

  private openFeedbackGroup(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({ uri: FEEDBACK_GROUP_URI }).catch((): void => {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.guide_feedback_group_open_failed'),
        duration: 5000,
      });
    });
  }

  @Builder
  private SectionHeading(index: string, title: ResourceStr, subtitle: ResourceStr) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        LuminousSurface({
          depth: -1,
          surfaceWidth: 42,
          surfaceHeight: 42,
          cornerRadius: 21,
          motionEnabled: true,
        }) {
          Text(index)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.neu_accent'));
        }
      }
      .width(48)
      .height(48)
      .clip(false);

      Column({ space: 3 }) {
        Text(title)
          .width('100%')
          .fontSize(18)
          .lineHeight(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.neu_text_primary'));
        Text(subtitle)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.neu_text_secondary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width(this.surfaceWidth())
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private FeedbackGroupButton() {
    Column({ space: 8 }) {
      LuminousButton({
        label: $r('app.string.guide_feedback_group_action'),
        controlWidth: Math.max(220, this.surfaceWidth() - 36),
        controlSizeMode: LuminousControlSize.Compact,
        tone: LuminousTone.Accent,
        motionEnabled: true,
        onAction: () => this.openFeedbackGroup(),
      })
      Text($r('app.string.guide_feedback_group_number'))
        .fontSize(11)
        .fontColor($r('app.color.neu_text_secondary'));
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private InstallCard() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: 1,
        surfaceWidth: this.surfaceWidth(),
        surfaceHeight: 270,
        cornerRadius: 24,
        motionEnabled: true,
      }) {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.arrow_down_circle'))
              .width(34)
              .fontSize(28)
              .fontColor([$r('app.color.neu_accent')]);
            Text($r('app.string.guide_install_title'))
              .layoutWeight(1)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Text($r('app.string.guide_install_body'))
            .width('100%')
            .fontSize(13)
            .lineHeight(20)
            .fontColor($r('app.color.neu_text_secondary'));

          this.FeedbackGroupButton()
        }
        .width(this.surfaceWidth())
        .height(270)
        .padding({ left: 18, right: 18, top: 18, bottom: 14 })
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width(this.surfaceWidth() + 16)
    .height(286)
    .clip(false);
  }

  @Builder
  private StepCard(number: string, title: ResourceStr, body: ResourceStr, height: number) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: 1,
        surfaceWidth: this.surfaceWidth(),
        surfaceHeight: height,
        cornerRadius: 22,
        motionEnabled: true,
      }) {
        Row({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            LuminousSurface({
              depth: -1,
              surfaceWidth: 38,
              surfaceHeight: 38,
              cornerRadius: 19,
              motionEnabled: true,
            }) {
              Text(number)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.neu_accent'));
            }
          }
          .width(44)
          .height(44)
          .clip(false);

          Column({ space: 5 }) {
            Text(title)
              .width('100%')
              .fontSize(14)
              .lineHeight(19)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));
            Text(body)
              .width('100%')
              .fontSize(12)
              .lineHeight(18)
              .fontColor($r('app.color.neu_text_secondary'));
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width(this.surfaceWidth())
        .height(height)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.surfaceWidth() + 16)
    .height(height + 16)
    .clip(false);
  }

  @Builder
  private ServerHelpCard() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: 1,
        surfaceWidth: this.surfaceWidth(),
        surfaceHeight: 220,
        cornerRadius: 22,
        motionEnabled: true,
      }) {
        Column({ space: 10 }) {
          Row({ space: 14 }) {
            Stack({ alignContent: Alignment.Center }) {
              LuminousSurface({
                depth: -1,
                surfaceWidth: 38,
                surfaceHeight: 38,
                cornerRadius: 19,
                motionEnabled: true,
              }) {
                Text('0')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.warning'));
              }
            }
            .width(44)
            .height(44)
            .clip(false);

            Column({ space: 5 }) {
              Text($r('app.string.guide_server_help_title'))
                .width('100%')
                .fontSize(14)
                .lineHeight(19)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.neu_text_primary'));
              Text($r('app.string.guide_server_help_body'))
                .width('100%')
                .fontSize(12)
                .lineHeight(18)
                .fontColor($r('app.color.neu_text_secondary'));
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          this.FeedbackGroupButton()
        }
        .width(this.surfaceWidth())
        .height(220)
        .padding({ left: 16, right: 16, top: 14, bottom: 10 });
      }
    }
    .width(this.surfaceWidth() + 16)
    .height(236)
    .clip(false);
  }

  @Builder
  private DirectPath() {
    Column({ space: 10 }) {
      Text($r('app.string.guide_direct_description'))
        .width(this.surfaceWidth())
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.neu_text_secondary'));
      this.StepCard('1', $r('app.string.guide_direct_step_1_title'),
        $r('app.string.guide_direct_step_1_body'), 108)
      this.StepCard('2', $r('app.string.guide_direct_step_2_title'),
        $r('app.string.guide_direct_step_2_body'), 116)
      this.StepCard('3', $r('app.string.guide_direct_step_3_title'),
        $r('app.string.guide_direct_step_3_body'), 124)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private ServerPath() {
    Column({ space: 10 }) {
      Text($r('app.string.guide_server_description'))
        .width(this.surfaceWidth())
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.neu_text_secondary'));
      this.ServerHelpCard()
      this.StepCard('1', $r('app.string.guide_server_step_1_title'),
        $r('app.string.guide_server_step_1_body'), 124)
      this.StepCard('2', $r('app.string.guide_server_step_2_title'),
        $r('app.string.guide_server_step_2_body'), 124)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private DefaultsCard() {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: 1,
        surfaceWidth: this.surfaceWidth(),
        surfaceHeight: 124,
        cornerRadius: 22,
        motionEnabled: true,
      }) {
        Row({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            LuminousSurface({
              depth: -1,
              surfaceWidth: 42,
              surfaceHeight: 42,
              cornerRadius: 21,
              motionEnabled: true,
            }) {
              SymbolGlyph($r('sys.symbol.slider_horizontal_2'))
                .fontSize(22)
                .fontColor([$r('app.color.success')]);
            }
          }
          .width(48)
          .height(48)
          .clip(false);

          Column({ space: 5 }) {
            Text($r('app.string.guide_defaults_title'))
              .width('100%')
              .fontSize(14)
              .lineHeight(19)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'));
            Text($r('app.string.guide_defaults_body'))
              .width('100%')
              .fontSize(12)
              .lineHeight(18)
              .fontColor($r('app.color.neu_text_secondary'));
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width(this.surfaceWidth())
        .height(124)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.surfaceWidth() + 16)
    .height(140)
    .clip(false);
  }

  build() {
    Column({ space: 14 }) {
      this.SectionHeading('1', $r('app.string.guide_install_heading'),
        $r('app.string.guide_install_heading_subtitle'))
      this.InstallCard()

      this.SectionHeading('2', $r('app.string.guide_path_heading'),
        $r('app.string.guide_path_heading_subtitle'))

      LuminousSegmentedControl({
        items: this.pathItems(),
        selectedIndex: this.selectedPathIndex,
        controlWidth: this.surfaceWidth(),
        controlHeight: 52,
        motionEnabled: true,
        onChange: (index: number): void => {
          this.selectedPathIndex = index;
        },
      })

      if (this.selectedPathIndex === 0) {
        this.DirectPath()
      } else {
        this.ServerPath()
      }

      this.SectionHeading('3', $r('app.string.guide_defaults_heading'),
        $r('app.string.guide_defaults_heading_subtitle'))
      this.DefaultsCard()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
