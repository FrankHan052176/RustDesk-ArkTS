import { RustDeskInputMode, RustDeskRightClickGesture } from '../RustDeskDirectoryTypes';
import { ToolbarTripleSelector } from './ToolbarTripleSelector';

export interface SessionInputControlsProps {
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
    this.selectedModeIndex = this.touchMode ? 0 : (this.relativeMouseMode ? 2 : 1);
  }

  private syncRightClickIndex(): void {
    this.selectedRightClickIndex = this.rightClickGesture === 'double_tap'
      ? 0
      : (this.rightClickGesture === 'two_finger_tap' ? 1 : 2);
  }

  private selectorWidth(): number {
    return this.wideLayout ? 150 : 204;
  }

  private selectMode(index: number): void {
    if (index === 2 && !this.relativeModeSupported) {
      return;
    }
    this.selectedModeIndex = index;
    const mode: RustDeskInputMode = index === 0 ? 'touch' : (index === 1 ? 'mouse' : 'relative');
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
      Row({ space: $r('app.float.space_12') }) {
        Row({ space: $r('app.float.space_4') }) {
          Text('输入')
            .width(32)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          ToolbarTripleSelector({
            labels: ['触控', '鼠标', '相对'],
            enabledItems: [true, true, this.relativeModeSupported],
            selectedIndex: this.selectedModeIndex,
            controlWidth: this.selectorWidth(),
            controlHeight: 36,
            accessibilityLabel: '输入模式',
            onChange: (index: number): void => this.selectMode(index),
          });
        }
        .alignItems(VerticalAlign.Center);

        Row({ space: $r('app.float.space_4') }) {
          Text('右键')
            .width(32)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          ToolbarTripleSelector({
            labels: ['双击', '双指', '长按'],
            selectedIndex: this.selectedRightClickIndex,
            controlWidth: this.selectorWidth(),
            controlHeight: 36,
            accessibilityLabel: '右键映射',
            onChange: (index: number): void => this.selectRightClick(index),
          });
        }
        .alignItems(VerticalAlign.Center);
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center);
    } else {
      Column({ space: $r('app.float.space_4') }) {
        Row({ space: $r('app.float.space_4') }) {
          Text('输入')
            .width(38)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          ToolbarTripleSelector({
            labels: ['触控', '鼠标', '相对'],
            enabledItems: [true, true, this.relativeModeSupported],
            selectedIndex: this.selectedModeIndex,
            controlWidth: this.selectorWidth(),
            controlHeight: 36,
            accessibilityLabel: '输入模式',
            onChange: (index: number): void => this.selectMode(index),
          });
        }
        .alignItems(VerticalAlign.Center);

        Row({ space: $r('app.float.space_4') }) {
          Text('右键')
            .width(38)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));
          ToolbarTripleSelector({
            labels: ['双击', '双指', '长按'],
            selectedIndex: this.selectedRightClickIndex,
            controlWidth: this.selectorWidth(),
            controlHeight: 36,
            accessibilityLabel: '右键映射',
            onChange: (index: number): void => this.selectRightClick(index),
          });
        }
        .alignItems(VerticalAlign.Center);
      }
      .width('100%');
    }
  }
}
