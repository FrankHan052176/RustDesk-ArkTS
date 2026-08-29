import {
  LuminousNeoTokens,
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
  wideLayout: boolean;
  onSelectMode: (mode: RustDeskInputMode) => void;
  onSelectRightClick: (gesture: RustDeskRightClickGesture) => void;
}

@ComponentV2
export struct InputModeSheet {
  @Param selectedMode: RustDeskInputMode = 'touch';
  @Local displayedMode: RustDeskInputMode = 'touch';
  @Param rightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  @Local displayedRightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  @Local viewportWidth: number = 280;
  @Param relativeModeSupported: boolean = false;
  @Param wideLayout: boolean = false;
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

  private modeIndex(): number {
    if (this.displayedMode === 'mouse') {
      return 0;
    }
    return this.displayedMode === 'touch' ? 1 : 2;
  }

  private selectMode(index: number): void {
    const mode: RustDeskInputMode = index === 0 ? 'mouse' : (index === 1 ? 'touch' : 'relative');
    if (mode === 'relative' && !this.relativeModeSupported) {
      return;
    }
    this.displayedMode = mode;
    this.onSelectMode(mode);
  }

  private selectRightClick(index: number): void {
    const gesture: RustDeskRightClickGesture = index === 0
      ? 'double_tap'
      : (index === 1 ? 'two_finger_tap' : 'long_press');
    this.displayedRightClickGesture = gesture;
    this.onSelectRightClick(gesture);
  }

  private modeTitle(): string {
    if (this.displayedMode === 'mouse') {
      return '鼠标模式';
    }
    return this.displayedMode === 'touch' ? '触控模式' : '相对鼠标';
  }

  private modeDescription(): string {
    if (this.displayedMode === 'mouse') {
      return '把屏幕当作触控板，通过虚拟光标精确操作远端。';
    }
    if (this.displayedMode === 'touch') {
      return '触点直接对应远端位置，适合窗口、列表和普通桌面操作。';
    }
    return this.relativeModeSupported
      ? '只发送位移增量，适合游戏、3D 软件和需要无限移动的场景。'
      : '当前远端版本或平台不支持相对鼠标。';
  }

  private modeGestures(): string {
    if (this.displayedMode === 'mouse') {
      return '单指移动光标 · 单击左键 · 双击并移动可拖拽 · 双指移动或捏合调整画面 · 三指纵向滑动滚轮（Android 远端除外）';
    }
    if (this.displayedMode === 'touch') {
      return '单击左键 · 单指拖动直接拖拽 · 双指移动或捏合调整画面 · 三指纵向滑动滚轮（Android 远端除外）';
    }
    return '单指相对移动 · 单击左键 · 双击并移动可拖拽 · 三指纵向滑动滚轮（Android 远端除外）';
  }

  private useWideLayout(): boolean {
    return this.wideLayout && this.viewportWidth >= 680;
  }

  private paneWidth(): number {
    return this.useWideLayout()
      ? Math.max(280, (this.viewportWidth - 12) / 2)
      : this.viewportWidth;
  }

  private segmentedControlShadowInset(): number {
    return LuminousNeoTokens.shadowPaddingFor(48) * 2;
  }

  private modeControlWidth(): number {
    const controlWidth = Math.min(620, Math.max(180, this.paneWidth()));
    return Math.max(120, controlWidth - this.segmentedControlShadowInset());
  }

  private rightClickControlWidth(): number {
    const available = this.paneWidth();
    if (this.useWideLayout()) {
      const innerWidth = Math.min(620, Math.max(180, available - 28));
      return Math.max(120, innerWidth - this.segmentedControlShadowInset());
    }
    const controlWidth = available >= 324 ? Math.min(420, available - 84) : Math.max(180, available);
    return Math.max(120, controlWidth - this.segmentedControlShadowInset());
  }

  private rightClickGestureTitle(): string {
    if (this.displayedRightClickGesture === 'double_tap') {
      return '双击';
    }
    return this.displayedRightClickGesture === 'two_finger_tap' ? '双指点击' : '长按';
  }

  @Builder
  private ModeDescription() {
    Column({ space: 7 }) {
      Row() {
        Text(this.modeTitle())
          .layoutWeight(1)
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.white'));
        Text('当前模式')
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.white'));
      }
      .width('100%');

      Text(this.modeDescription())
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.white'));

      Text(`手势：${this.modeGestures()}`)
        .width('100%')
        .fontSize(11)
        .lineHeight(16)
        .fontColor($r('app.color.white'));
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.brand_primary'))
    .border({ width: 1, color: $r('app.color.brand_primary') })
    .borderRadius($r('app.float.radius_14'))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM);
  }

  @Builder
  private RightClickMapping() {
    if (this.useWideLayout()) {
      Column({ space: 10 }) {
        Row() {
          Text('右键映射')
            .layoutWeight(1)
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.neu_text_primary'));
          Text(`当前：${this.rightClickGestureTitle()}`)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
        }
        .width('100%');

        Text('选择在触屏操作中触发远端右键的手势。')
          .width('100%')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.neu_text_secondary'));

        this.RightClickSelector()
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.mica_control'))
      .border({ width: 1, color: $r('app.color.mica_border') })
      .borderRadius($r('app.float.radius_14'))
      .shadow(ShadowStyle.OUTER_DEFAULT_SM);
    } else if (this.paneWidth() >= 324) {
      Row({ space: 12 }) {
        Text('右键映射')
          .width(72)
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_text_secondary'));
        this.RightClickSelector()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center);
    } else {
      Column({ space: 4 }) {
        Text('右键映射')
          .width('100%')
          .fontSize($r('app.float.font_label'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.neu_text_secondary'));
        this.RightClickSelector()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private RightClickSelector() {
    Row() {
      LuminousSegmentedControl({
        items: [
          new LuminousSelectionItem('double_tap', '双击'),
          new LuminousSelectionItem('two_finger_tap', '双指点击'),
          new LuminousSelectionItem('long_press', '长按'),
        ],
        selectedIndex: this.rightClickIndex(),
        controlWidth: this.rightClickControlWidth(),
        controlHeight: 48,
        motionEnabled: true,
        onChange: (index: number) => this.selectRightClick(index),
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .clip(false);
  }

  build(): void {
    Scroll() {
      if (this.useWideLayout()) {
        Row({ space: 12 }) {
          Column({ space: 10 }) {
            this.ModeSelector()
            this.ModeDescription()
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);

          Column({ space: 10 }) {
            this.RightClickMapping()
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      } else {
        Column({ space: 10 }) {
          this.ModeSelector()
          this.ModeDescription()
          this.RightClickMapping()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = Math.max(180, width);
      }
    });
  }

  @Builder
  private ModeSelector() {
    Row() {
      LuminousSegmentedControl({
        items: [
          new LuminousSelectionItem('mouse', '鼠标模式'),
          new LuminousSelectionItem('touch', '触控模式'),
          new LuminousSelectionItem('relative', '相对鼠标', '', this.relativeModeSupported),
        ],
        selectedIndex: this.modeIndex(),
        controlWidth: this.modeControlWidth(),
        controlHeight: 48,
        motionEnabled: true,
        onChange: (index: number) => this.selectMode(index),
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .clip(false);
  }
}
