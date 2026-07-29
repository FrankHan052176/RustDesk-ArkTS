import { FloatingGlassSurface } from './FloatingSurface';

export const REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT: number = 288;

class RemoteSoftKeySpec {
  label: string;
  name: string;
  weight: number;
  modifier: boolean;

  constructor(label: string, name: string, weight: number = 1, modifier: boolean = false) {
    this.label = label;
    this.name = name;
    this.weight = weight;
    this.modifier = modifier;
  }
}

/**
 * A deliberately small remote keyboard. It never asks for the system IME and
 * never changes the remote surface's layout height: the panel floats above the
 * video and is collapsed by default. Keys are sent as down/up pairs directly
 * through the RustDesk bridge; modifier keys remain latched until released or
 * the panel disappears.
 */
@ComponentV2
export struct RemoteSoftKeyboard {
  @Param keyboardWidth: number = 360;
  @Param dockTop: boolean = false;
  @Event onKey: (name: string, down: boolean, alt: boolean, ctrl: boolean, shift: boolean, command: boolean) => void =
    (_name: string, _down: boolean, _alt: boolean, _ctrl: boolean, _shift: boolean, _command: boolean) => {};
  @Event onMoveDock: () => void = () => {};
  @Event onCollapse: () => void = () => {};

  @Local layer: number = 0;
  @Local altActive: boolean = false;
  @Local ctrlActive: boolean = false;
  @Local shiftActive: boolean = false;
  @Local commandActive: boolean = false;
  @Local pressedKey: string = '';
  @Local touchKeyName: string = '';
  @Local suppressedClickKey: string = '';

  aboutToDisappear(): void {
    this.releaseAllKeys();
  }

  private panelWidth(): number {
    return Math.max(280, Math.min(this.keyboardWidth, 760));
  }

  private keyVisualHeight(): number {
    return this.panelWidth() < 520 ? 36 : 38;
  }

  private layerTitle(): string {
    if (this.layer === 1) {
      return '导航';
    }
    if (this.layer === 2) {
      return '功能';
    }
    return '字母';
  }

  private letterRows(): RemoteSoftKeySpec[][] {
    return [
      [
        new RemoteSoftKeySpec('Esc', 'VK_ESCAPE'),
        new RemoteSoftKeySpec('1', '1'),
        new RemoteSoftKeySpec('2', '2'),
        new RemoteSoftKeySpec('3', '3'),
        new RemoteSoftKeySpec('4', '4'),
        new RemoteSoftKeySpec('5', '5'),
        new RemoteSoftKeySpec('6', '6'),
        new RemoteSoftKeySpec('7', '7'),
        new RemoteSoftKeySpec('8', '8'),
        new RemoteSoftKeySpec('9', '9'),
        new RemoteSoftKeySpec('0', '0'),
        new RemoteSoftKeySpec('⌫', 'VK_BACK', 1.35),
      ],
      [
        new RemoteSoftKeySpec('Q', 'q'),
        new RemoteSoftKeySpec('W', 'w'),
        new RemoteSoftKeySpec('E', 'e'),
        new RemoteSoftKeySpec('R', 'r'),
        new RemoteSoftKeySpec('T', 't'),
        new RemoteSoftKeySpec('Y', 'y'),
        new RemoteSoftKeySpec('U', 'u'),
        new RemoteSoftKeySpec('I', 'i'),
        new RemoteSoftKeySpec('O', 'o'),
        new RemoteSoftKeySpec('P', 'p'),
      ],
      [
        new RemoteSoftKeySpec('A', 'a'),
        new RemoteSoftKeySpec('S', 's'),
        new RemoteSoftKeySpec('D', 'd'),
        new RemoteSoftKeySpec('F', 'f'),
        new RemoteSoftKeySpec('G', 'g'),
        new RemoteSoftKeySpec('H', 'h'),
        new RemoteSoftKeySpec('J', 'j'),
        new RemoteSoftKeySpec('K', 'k'),
        new RemoteSoftKeySpec('L', 'l'),
        new RemoteSoftKeySpec('↵', 'VK_RETURN', 1.35),
      ],
      [
        new RemoteSoftKeySpec('⇧', 'VK_SHIFT', 1.35, true),
        new RemoteSoftKeySpec('Z', 'z'),
        new RemoteSoftKeySpec('X', 'x'),
        new RemoteSoftKeySpec('C', 'c'),
        new RemoteSoftKeySpec('V', 'v'),
        new RemoteSoftKeySpec('B', 'b'),
        new RemoteSoftKeySpec('N', 'n'),
        new RemoteSoftKeySpec('M', 'm'),
        new RemoteSoftKeySpec('←', 'VK_LEFT'),
        new RemoteSoftKeySpec('→', 'VK_RIGHT'),
      ],
      [
        new RemoteSoftKeySpec('Ctrl', 'VK_CONTROL', 1.2, true),
        new RemoteSoftKeySpec('Alt', 'VK_MENU', 1.1, true),
        new RemoteSoftKeySpec('空格', 'VK_SPACE', 3.2),
        new RemoteSoftKeySpec('↑', 'VK_UP'),
        new RemoteSoftKeySpec('↓', 'VK_DOWN'),
        new RemoteSoftKeySpec('⌘', 'Meta', 1.1, true),
      ],
    ];
  }

  private navigationRows(): RemoteSoftKeySpec[][] {
    return [
      [
        new RemoteSoftKeySpec('Esc', 'VK_ESCAPE'),
        new RemoteSoftKeySpec('Tab', 'VK_TAB'),
        new RemoteSoftKeySpec('Enter', 'VK_RETURN'),
        new RemoteSoftKeySpec('⌫', 'VK_BACK'),
        new RemoteSoftKeySpec('Del', 'VK_DELETE'),
      ],
      [
        new RemoteSoftKeySpec('Home', 'VK_HOME'),
        new RemoteSoftKeySpec('End', 'VK_END'),
        new RemoteSoftKeySpec('PgUp', 'VK_PRIOR'),
        new RemoteSoftKeySpec('PgDn', 'VK_NEXT'),
        new RemoteSoftKeySpec('Ins', 'VK_INSERT'),
      ],
      [
        new RemoteSoftKeySpec('←', 'VK_LEFT'),
        new RemoteSoftKeySpec('↑', 'VK_UP'),
        new RemoteSoftKeySpec('↓', 'VK_DOWN'),
        new RemoteSoftKeySpec('→', 'VK_RIGHT'),
        new RemoteSoftKeySpec('空格', 'VK_SPACE', 1.8),
      ],
      [
        new RemoteSoftKeySpec('Ctrl', 'VK_CONTROL', 1.2, true),
        new RemoteSoftKeySpec('Alt', 'VK_MENU', 1.2, true),
        new RemoteSoftKeySpec('Shift', 'VK_SHIFT', 1.2, true),
        new RemoteSoftKeySpec('⌘', 'Meta', 1.2, true),
        new RemoteSoftKeySpec('释放修饰键', 'release_modifiers', 1.8),
      ],
    ];
  }

  private functionRows(): RemoteSoftKeySpec[][] {
    return [
      [
        new RemoteSoftKeySpec('F1', 'VK_F1'),
        new RemoteSoftKeySpec('F2', 'VK_F2'),
        new RemoteSoftKeySpec('F3', 'VK_F3'),
        new RemoteSoftKeySpec('F4', 'VK_F4'),
        new RemoteSoftKeySpec('F5', 'VK_F5'),
        new RemoteSoftKeySpec('F6', 'VK_F6'),
      ],
      [
        new RemoteSoftKeySpec('F7', 'VK_F7'),
        new RemoteSoftKeySpec('F8', 'VK_F8'),
        new RemoteSoftKeySpec('F9', 'VK_F9'),
        new RemoteSoftKeySpec('F10', 'VK_F10'),
        new RemoteSoftKeySpec('F11', 'VK_F11'),
        new RemoteSoftKeySpec('F12', 'VK_F12'),
      ],
      [
        new RemoteSoftKeySpec('Print', 'VK_SNAPSHOT'),
        new RemoteSoftKeySpec('Pause', 'VK_PAUSE'),
        new RemoteSoftKeySpec('Num', 'VK_NUMLOCK'),
        new RemoteSoftKeySpec('Caps', 'VK_CAPITAL'),
        new RemoteSoftKeySpec('Scroll', 'VK_SCROLL'),
      ],
      [
        new RemoteSoftKeySpec('Ctrl', 'VK_CONTROL', 1.2, true),
        new RemoteSoftKeySpec('Alt', 'VK_MENU', 1.2, true),
        new RemoteSoftKeySpec('Shift', 'VK_SHIFT', 1.2, true),
        new RemoteSoftKeySpec('⌘', 'Meta', 1.2, true),
        new RemoteSoftKeySpec('释放修饰键', 'release_modifiers', 1.8),
      ],
    ];
  }

  private rows(): RemoteSoftKeySpec[][] {
    if (this.layer === 1) {
      return this.navigationRows();
    }
    if (this.layer === 2) {
      return this.functionRows();
    }
    return this.letterRows();
  }

  private modifierActive(name: string): boolean {
    if (name === 'VK_CONTROL') {
      return this.ctrlActive;
    }
    if (name === 'VK_MENU') {
      return this.altActive;
    }
    if (name === 'VK_SHIFT') {
      return this.shiftActive;
    }
    if (name === 'Meta') {
      return this.commandActive;
    }
    return false;
  }

  private setModifier(name: string, active: boolean): void {
    if (name === 'VK_CONTROL') {
      this.ctrlActive = active;
    } else if (name === 'VK_MENU') {
      this.altActive = active;
    } else if (name === 'VK_SHIFT') {
      this.shiftActive = active;
    } else if (name === 'Meta') {
      this.commandActive = active;
    }
  }

  private emitKey(name: string, down: boolean): void {
    this.onKey(name, down, this.altActive, this.ctrlActive, this.shiftActive, this.commandActive);
  }

  private toggleModifier(name: string): void {
    const active = this.modifierActive(name);
    if (active) {
      this.onKey(name, false, this.altActive, this.ctrlActive, this.shiftActive, this.commandActive);
      this.setModifier(name, false);
      return;
    }
    this.onKey(name, true, this.altActive, this.ctrlActive, this.shiftActive, this.commandActive);
    this.setModifier(name, true);
  }

  private releaseModifiers(): void {
    if (this.ctrlActive) {
      this.onKey('VK_CONTROL', false, this.altActive, true, this.shiftActive, this.commandActive);
      this.ctrlActive = false;
    }
    if (this.altActive) {
      this.onKey('VK_MENU', false, this.altActive, this.ctrlActive, this.shiftActive, this.commandActive);
      this.altActive = false;
    }
    if (this.shiftActive) {
      this.onKey('VK_SHIFT', false, this.altActive, this.ctrlActive, this.shiftActive, this.commandActive);
      this.shiftActive = false;
    }
    if (this.commandActive) {
      this.onKey('Meta', false, this.altActive, this.ctrlActive, this.shiftActive, this.commandActive);
      this.commandActive = false;
    }
  }

  private releasePressedKey(): void {
    if (this.pressedKey.length === 0) {
      return;
    }
    this.emitKey(this.pressedKey, false);
    this.pressedKey = '';
  }

  private releaseAllKeys(): void {
    this.releasePressedKey();
    this.releaseModifiers();
    this.touchKeyName = '';
    this.suppressedClickKey = '';
  }

  private changeLayer(index: number): void {
    if (this.layer === index) {
      return;
    }
    this.releaseAllKeys();
    this.layer = index;
  }

  private collapse(): void {
    this.releaseAllKeys();
    this.onCollapse();
  }

  private activateKey(spec: RemoteSoftKeySpec): void {
    if (spec.modifier) {
      this.toggleModifier(spec.name);
      return;
    }
    if (spec.name === 'release_modifiers') {
      this.releaseModifiers();
      return;
    }
    this.emitKey(spec.name, true);
    this.emitKey(spec.name, false);
  }

  private keyAccessibilityText(spec: RemoteSoftKeySpec): string {
    if (spec.modifier && this.modifierActive(spec.name)) {
      return `${spec.label}，已锁定`;
    }
    return spec.label;
  }

  private touchKey(spec: RemoteSoftKeySpec, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.suppressedClickKey = '';
      this.touchKeyName = spec.name;
      if (spec.modifier) {
        this.toggleModifier(spec.name);
        return;
      }
      if (spec.name === 'release_modifiers') {
        this.releaseModifiers();
        return;
      }
      if (this.pressedKey.length === 0) {
        this.pressedKey = spec.name;
        this.emitKey(spec.name, true);
      }
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (!spec.modifier && spec.name === this.pressedKey) {
        this.emitKey(spec.name, false);
        this.pressedKey = '';
      }
      if (event.type === TouchType.Up && this.touchKeyName === spec.name) {
        this.suppressedClickKey = spec.name;
      }
      this.touchKeyName = '';
    }
  }

  @Builder
  private LayerButton(label: string, index: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(label)
        .fontSize(12)
        .fontWeight(this.layer === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.layer === index ? $r('app.color.neu_accent') : $r('app.color.neu_text_secondary'));
    }
    .height(34)
    .layoutWeight(1)
    .padding(0)
    .backgroundColor(this.layer === index ? $r('app.color.brand_primary_soft') : $r('app.color.mica_control'))
    .border({ width: 1, color: this.layer === index ? $r('app.color.brand_primary') : $r('app.color.mica_border') })
    .borderRadius(10)
    .responseRegion({ x: 0, y: -5, width: '100%', height: 44 })
    .accessibilityText(label)
    .accessibilitySelected(this.layer === index)
    .onClick((): void => {
      this.changeLayer(index);
    });
  }

  @Builder
  private KeyButton(spec: RemoteSoftKeySpec) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text(spec.label)
        .fontSize(spec.label.length > 3 ? 11 : 14)
        .fontWeight(spec.modifier && this.modifierActive(spec.name) ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(spec.modifier && this.modifierActive(spec.name) ?
          $r('app.color.white') : $r('app.color.neu_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .height(this.keyVisualHeight())
    .layoutWeight(spec.weight)
    .padding({ left: 2, right: 2 })
    .backgroundColor(spec.modifier && this.modifierActive(spec.name) ?
      $r('app.color.brand_primary') : $r('app.color.mica_control'))
    .border({
      width: 1,
      color: spec.modifier && this.modifierActive(spec.name) ?
        $r('app.color.brand_primary') : $r('app.color.mica_border')
    })
    .borderRadius(10)
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .responseRegion({
      x: 0,
      y: -(44 - this.keyVisualHeight()) / 2,
      width: '100%',
      height: 44,
    })
    .accessibilityText(this.keyAccessibilityText(spec))
    .onTouch((event: TouchEvent): void => this.touchKey(spec, event))
    .onClick((): void => {
      if (this.suppressedClickKey === spec.name) {
        this.suppressedClickKey = '';
        return;
      }
      this.activateKey(spec);
    });
  }

  @Builder
  private KeyRows() {
    Column() {
      ForEach(this.rows(), (row: RemoteSoftKeySpec[]) => {
        Row({ space: 4 }) {
          ForEach(row, (spec: RemoteSoftKeySpec) => {
            this.KeyButton(spec);
          }, (spec: RemoteSoftKeySpec) => `${this.layer}-${spec.name}-${spec.label}`);
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center);
      }, (_row: RemoteSoftKeySpec[], index: number) => `${this.layer}-row-${index}`);
    }
    .width('100%');
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      FloatingGlassSurface({
        surfaceWidth: this.panelWidth(),
        surfaceHeight: REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT,
        radius: $r('app.float.radius_18'),
      }) {
        Column({ space: 7 }) {
          Row({ space: 6 }) {
            Text(`远端键盘 · ${this.layerTitle()}`)
              .layoutWeight(1)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.neu_text_primary'))
              .maxLines(1);
            this.LayerButton('字母', 0);
            this.LayerButton('导航', 1);
            this.LayerButton('功能', 2);
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Text(this.dockTop ? '下移' : '上移')
                .fontSize(11)
                .fontColor($r('app.color.neu_text_secondary'));
            }
              .height(34)
              .width(44)
              .padding(0)
              .backgroundColor($r('app.color.mica_control'))
              .border({ width: 1, color: $r('app.color.mica_border') })
              .borderRadius(10)
              .responseRegion({ x: 0, y: -5, width: '100%', height: 44 })
              .accessibilityText(this.dockTop ? '键盘移到底部' : '键盘移到顶部')
              .onClick((): void => {
                this.releasePressedKey();
                this.onMoveDock();
              });
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Text('×')
                .fontSize(20)
                .fontColor($r('app.color.neu_text_secondary'));
            }
              .height(34)
              .width(40)
              .padding(0)
              .backgroundColor($r('app.color.mica_control'))
              .border({ width: 1, color: $r('app.color.mica_border') })
              .borderRadius(10)
              .responseRegion({ x: 0, y: -5, width: '100%', height: 44 })
              .accessibilityText('收起远端键盘')
              .onClick((): void => this.collapse());
          }
          .width('100%')
          .height(44)
          .alignItems(VerticalAlign.Center);

          this.KeyRows();
        }
        .width('100%')
        .height('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: 8 });
      }
    }
    .width(this.panelWidth())
    .height(REMOTE_SOFT_KEYBOARD_PANEL_HEIGHT)
    .position({ x: 0, y: 0 });
  }
}
