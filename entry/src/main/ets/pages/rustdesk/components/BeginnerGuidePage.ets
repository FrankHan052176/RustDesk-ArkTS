import { common } from '@kit.AbilityKit';
import {
  LuminousButton,
  LuminousControlSize,
  LuminousNeoTokens,
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
    return Math.max(96, Math.min(this.viewportWidth, 900));
  }

  private surfaceWidth(): number {
    return Math.max(80, this.contentWidth() - 16);
  }

  private segmentedControlWidth(): number {
    const shadowInset = LuminousNeoTokens.shadowPaddingFor(52) * 2;
    return Math.max(64, this.surfaceWidth() - shadowInset);
  }

  private adaptiveCardHeight(baseHeight: number): number {
    if (this.surfaceWidth() < 300) {
      return baseHeight + 72;
    }
    if (this.surfaceWidth() < 420) {
      return baseHeight + 36;
    }
    return baseHeight;
  }

  private installCardHeight(): number {
    return this.adaptiveCardHeight(270);
  }

  private pathItems(): LuminousSelectionItem[] {
    return [
      new LuminousSelectionItem('official', '官方服务', 'ID 连接'),
      new LuminousSelectionItem('direct', '局域网', 'IP 直连'),
      new LuminousSelectionItem('custom', '自建服务', '私有节点'),
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
        controlWidth: Math.max(64, this.surfaceWidth() - 36),
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
        surfaceHeight: this.installCardHeight(),
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
        .height(this.installCardHeight())
        .padding({ left: 18, right: 18, top: 18, bottom: 14 })
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width(this.surfaceWidth() + 16)
    .height(this.installCardHeight() + 16)
    .clip(false);
  }

  @Builder
  private StepCard(number: string, title: ResourceStr, body: ResourceStr, height: number) {
    Stack({ alignContent: Alignment.Center }) {
      LuminousSurface({
        depth: 1,
        surfaceWidth: this.surfaceWidth(),
        surfaceHeight: this.adaptiveCardHeight(height),
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
        .height(this.adaptiveCardHeight(height))
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.surfaceWidth() + 16)
    .height(this.adaptiveCardHeight(height) + 16)
    .clip(false);
  }

  @Builder
  private OfficialPath() {
    Column({ space: 10 }) {
      Text($r('app.string.guide_official_description'))
        .width(this.surfaceWidth())
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.neu_text_secondary'));
      this.StepCard('1', $r('app.string.guide_official_step_1_title'),
        $r('app.string.guide_official_step_1_body'), 116)
      this.StepCard('2', $r('app.string.guide_official_step_2_title'),
        $r('app.string.guide_official_step_2_body'), 116)
      this.StepCard('3', $r('app.string.guide_official_step_3_title'),
        $r('app.string.guide_official_step_3_body'), 116)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
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
  private CustomServerPath() {
    Column({ space: 10 }) {
      Text($r('app.string.guide_server_description'))
        .width(this.surfaceWidth())
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.neu_text_secondary'));
      this.StepCard('1', $r('app.string.guide_server_step_1_title'),
        $r('app.string.guide_server_step_1_body'), 124)
      this.StepCard('2', $r('app.string.guide_server_step_2_title'),
        $r('app.string.guide_server_step_2_body'), 124)
      this.StepCard('3', $r('app.string.guide_server_step_3_title'),
        $r('app.string.guide_server_step_3_body'), 124)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private RemoteControlGuide() {
    Column({ space: 10 }) {
      this.StepCard('1', $r('app.string.guide_remote_input_title'),
        $r('app.string.guide_remote_input_body'), 124)
      this.StepCard('2', $r('app.string.guide_remote_tools_title'),
        $r('app.string.guide_remote_tools_body'), 132)
      this.StepCard('3', $r('app.string.guide_remote_sessions_title'),
        $r('app.string.guide_remote_sessions_body'), 132)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private FeatureGuide() {
    Column({ space: 10 }) {
      this.StepCard('1', $r('app.string.guide_devices_title'),
        $r('app.string.guide_devices_body'), 124)
      this.StepCard('2', $r('app.string.guide_transfer_title'),
        $r('app.string.guide_transfer_body'), 124)
      this.StepCard('3', $r('app.string.guide_host_title'),
        $r('app.string.guide_host_body'), 132)
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
        surfaceHeight: this.adaptiveCardHeight(124),
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
        .height(this.adaptiveCardHeight(124))
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center);
      }
    }
    .width(this.surfaceWidth() + 16)
    .height(this.adaptiveCardHeight(124) + 16)
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
        controlWidth: this.segmentedControlWidth(),
        controlHeight: 52,
        motionEnabled: true,
        onChange: (index: number): void => {
          this.selectedPathIndex = index;
        },
      })

      if (this.selectedPathIndex === 0) {
        this.OfficialPath()
      } else if (this.selectedPathIndex === 1) {
        this.DirectPath()
      } else {
        this.CustomServerPath()
      }

      this.SectionHeading('3', $r('app.string.guide_remote_heading'),
        $r('app.string.guide_remote_heading_subtitle'))
      this.RemoteControlGuide()

      this.SectionHeading('4', $r('app.string.guide_features_heading'),
        $r('app.string.guide_features_heading_subtitle'))
      this.FeatureGuide()

      this.SectionHeading('5', $r('app.string.guide_defaults_heading'),
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
