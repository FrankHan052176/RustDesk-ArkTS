import { RustDeskInputMode, RustDeskRightClickGesture } from '../RustDeskDirectoryTypes';
import { ToolbarTripleSelector } from './ToolbarTripleSelector';

export interface SessionInputControlsProps {
  inputEnabled: boolean;
  touchMode: boolean;
  relativeMouseMode: boolean;
  relativeModeSupported: boolean;
  rightClickGesture: RustDeskRightClickGesture;
  wideLayout: boolean;
  onSelectMode: (mode: RustDeskInputMode) => void;
  onSelectRightClick: (gesture: RustDeskRightClickGesture) => void;
}

@ComponentV2
export struct SessionInputControls {
  @Param inputEnabled: boolean = true;
  @Param touchMode: boolean = true;
  @Param relativeMouseMode: boolean = false;
  @Param relativeModeSupported: boolean = false;
  @Param rightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  @Param wideLayout: boolean = false;
  @Local selectedModeIndex: number = 0;
  @Local selectedRightClickIndex: number = 1;
  @Event onSelectMode: (mode: RustDeskInputMode) => void = (_mode: RustDeskInputMode) => {};
  @Event onSelectRightClick: (gesture: RustDeskRightClickGesture) => void = (
    _gesture: RustDeskRightClickGesture,
  ) => {};

  aboutToAppear(): void {
    this.syncModeIndex();
    this.syncRightClickIndex();
  }

  @Monitor('inputEnabled')
  private onInputEnabledChanged(_monitor: IMonitor): void {
    this.syncModeIndex();
  }

  @Monitor('touchMode')
  private onTouchModeChanged(_monitor: IMonitor): void {
    this.syncModeIndex();
  }

  @Monitor('relativeMouseMode')
  private onRelativeMouseModeChanged(_monitor: IMonitor): void {
    this.syncModeIndex();
  }

  @Monitor('rightClickGesture')
  private onRightClickGestureChanged(_monitor: IMonitor): void {
    this.syncRightClickIndex();
  }

  private syncModeIndex(): void {
    if (!this.inputEnabled) {
      this.selectedModeIndex = 0;
      return;
    }
    // Relative mouse remains reachable from the input sheet; the compact
    // toolbar selector trades it for an explicit off switch.
    this.selectedModeIndex = this.touchMode ? 1 : 2;
  }

  private syncRightClickIndex(): void {
    this.selectedRightClickIndex = this.rightClickGesture === 'double_tap'
      ? 0
      : (this.rightClickGesture === 'two_finger_tap' ? 1 : 2);
  }

  private selectMode(index: number): void {
    this.selectedModeIndex = index;
    const mode: RustDeskInputMode = index === 0 ? 'off' : (index === 1 ? 'touch' : 'mouse');
    this.onSelectMode(mode);
  }

  private selectRightClick(index: number): void {
    this.selectedRightClickIndex = index;
    const gesture: RustDeskRightClickGesture = index === 0
      ? 'double_tap'
      : (index === 1 ? 'two_finger_tap' : 'long_press');
    this.onSelectRightClick(gesture);
  }

  build(): void {
    if (this.wideLayout) {
      Row({ space: $r('app.float.space_8') }) {
        Row({ space: $r('app.float.space_6') }) {
          Text('输入')
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          ToolbarTripleSelector({
            labels: ['关闭', '触控', '鼠标'],
            selectedIndex: this.selectedModeIndex,
            controlWidth: 0,
            controlHeight: 44,
            accessibilityLabel: '输入模式',
            onChange: (index: number): void => this.selectMode(index),
          })
            .layoutWeight(1);
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center);

        Row({ space: $r('app.float.space_6') }) {
          Text('右键')
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          ToolbarTripleSelector({
            labels: ['双击', '双指', '长按'],
            selectedIndex: this.selectedRightClickIndex,
            controlWidth: 0,
            controlHeight: 44,
            accessibilityLabel: '右键映射',
            onChange: (index: number): void => this.selectRightClick(index),
          })
            .layoutWeight(1);
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center);
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.mica_control'))
      .border({ width: 1, color: $r('app.color.mica_border') })
      .borderRadius($r('app.float.radius_14'))
      .alignItems(VerticalAlign.Center);
    } else {
      Column({ space: $r('app.float.space_6') }) {
        Row({ space: $r('app.float.space_6') }) {
          Text('输入')
            .width(32)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          ToolbarTripleSelector({
            labels: ['关闭', '触控', '鼠标'],
            selectedIndex: this.selectedModeIndex,
            controlWidth: 0,
            controlHeight: 44,
            accessibilityLabel: '输入模式',
            onChange: (index: number): void => this.selectMode(index),
          })
            .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Row({ space: $r('app.float.space_6') }) {
          Text('右键')
            .width(32)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          ToolbarTripleSelector({
            labels: ['双击', '双指', '长按'],
            selectedIndex: this.selectedRightClickIndex,
            controlWidth: 0,
            controlHeight: 44,
            accessibilityLabel: '右键映射',
            onChange: (index: number): void => this.selectRightClick(index),
          })
            .layoutWeight(1);
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.mica_control'))
      .border({ width: 1, color: $r('app.color.mica_border') })
      .borderRadius($r('app.float.radius_14'));
    }
  }
}
