import {
  LuminousSegmentedControl,
  LuminousSelectionItem,
} from 'luminous_neo';
import {
  RustDeskInputMode,
  RustDeskRightClickGesture,
} from '../RustDeskDirectoryTypes';

export interface InputModeSheetProps {
  selectedMode: RustDeskInputMode;
  rightClickGesture: RustDeskRightClickGesture;
  relativeModeSupported: boolean;
  onSelectMode: (mode: RustDeskInputMode) => void;
  onSelectRightClick: (gesture: RustDeskRightClickGesture) => void;
}

@ComponentV2
export struct InputModeSheet {
  @Param selectedMode: RustDeskInputMode = 'touch';
  @Local displayedMode: RustDeskInputMode = 'touch';
  @Param rightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  @Local displayedRightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  @Local controlWidth: number = 320;
  @Param relativeModeSupported: boolean = false;
  @Event onSelectMode: (mode: RustDeskInputMode) => void = (_mode: RustDeskInputMode) => {};
  @Event onSelectRightClick: (gesture: RustDeskRightClickGesture) => void = (
    _gesture: RustDeskRightClickGesture,
  ) => {};

  aboutToAppear(): void {
    this.displayedMode = this.selectedMode;
    this.displayedRightClickGesture = this.rightClickGesture;
  }

  @Monitor('selectedMode')
  private onSelectedModeChanged(_monitor: IMonitor): void {
    this.displayedMode = this.selectedMode;
  }

  @Monitor('rightClickGesture')
  private onRightClickGestureChanged(_monitor: IMonitor): void {
    this.displayedRightClickGesture = this.rightClickGesture;
  }

  private rightClickIndex(): number {
    if (this.displayedRightClickGesture === 'double_tap') {
      return 0;
    }
    return this.displayedRightClickGesture === 'two_finger_tap' ? 1 : 2;
  }

  private selectRightClick(index: number): void {
    const gesture: RustDeskRightClickGesture = index === 0
      ? 'double_tap'
      : (index === 1 ? 'two_finger_tap' : 'long_press');
    this.displayedRightClickGesture = gesture;
    this.onSelectRightClick(gesture);
  }

  @Builder
  private ModeOption(
    mode: RustDeskInputMode,
    title: string,
    description: string,
    gestures: string,
    enabled: boolean,
  ) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(title)
            .layoutWeight(1)
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Bold)
            .fontColor(enabled
              ? (this.displayedMode === mode ? $r('app.color.white') : $r('app.color.neu_text_primary'))
              : $r('app.color.neu_text_disabled'));

          if (this.displayedMode === mode) {
            Text('当前')
              .fontSize($r('app.float.font_caption'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.white'));
          }
        }
        .width('100%');

        Text(description)
          .width('100%')
          .fontSize($r('app.float.font_caption'))
          .fontColor(this.displayedMode === mode
            ? $r('app.color.white')
            : (enabled ? $r('app.color.neu_text_secondary') : $r('app.color.neu_text_disabled')))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(`手势：${gestures}`)
          .width('100%')
          .fontSize(11)
          .lineHeight(16)
          .fontColor(this.displayedMode === mode
            ? $r('app.color.white')
            : (enabled ? $r('app.color.neu_text_secondary') : $r('app.color.neu_text_disabled')));
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ minHeight: 104 })
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .enabled(enabled)
    .backgroundColor(this.displayedMode === mode
      ? $r('app.color.brand_primary')
      : $r('app.color.mica_control'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 0.56,
    })
    .border({
      width: 1,
      color: this.displayedMode === mode ? $r('app.color.brand_primary') : $r('app.color.mica_border'),
    })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .hoverEffect(HoverEffect.None)
    .opacity(enabled ? 1 : 0.62)
    .accessibilityText(`${title}。${description}。${gestures}`)
    .accessibilitySelected(this.displayedMode === mode)
    .onClick((): void => {
      if (!enabled) {
        return;
      }
      this.displayedMode = mode;
      this.onSelectMode(mode);
    });
  }

  build(): void {
    Scroll() {
      Column({ space: 10 }) {
        this.ModeOption(
          'mouse',
          '鼠标模式',
          '把屏幕当作触控板，通过虚拟光标精确操作远端。',
          '单指移动光标 · 单击左键 · 双击并移动可拖拽 · 双指移动或捏合调整画面 · 三指纵向滑动滚轮（Android 远端除外）',
          true,
        )
        this.ModeOption(
          'touch',
          '触控模式',
          '触点直接对应远端位置，适合窗口、列表和普通桌面操作。',
          '单击左键 · 单指拖动直接拖拽 · 双指移动或捏合调整画面 · 三指纵向滑动滚轮（Android 远端除外）',
          true,
        )
        this.ModeOption(
          'relative',
          '相对鼠标',
          this.relativeModeSupported
            ? '只发送位移增量，适合游戏、3D 软件和需要无限移动的场景。'
            : '当前远端版本或平台不支持相对鼠标。',
          '单指相对移动 · 单击左键 · 双击并移动可拖拽 · 三指纵向滑动滚轮（Android 远端除外）',
          this.relativeModeSupported,
        )

        Column({ space: 4 }) {
          Text('右键手势')
            .width('100%')
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));

          LuminousSegmentedControl({
            items: [
              new LuminousSelectionItem('double_tap', '双击'),
              new LuminousSelectionItem('two_finger_tap', '双指点击'),
              new LuminousSelectionItem('long_press', '长按'),
            ],
            selectedIndex: this.rightClickIndex(),
            controlWidth: this.controlWidth,
            controlHeight: 48,
            motionEnabled: true,
            onChange: (index: number) => this.selectRightClick(index),
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding({ bottom: 8 });
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.controlWidth = Math.max(260, width);
      }
    });
  }
}
