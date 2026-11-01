import { describe, expect, it } from '@ohos/hypium';
import { IntentionCode } from '@ohos.multimodalInput.intentionCode';
import {
  RustDeskInputController,
  RustDeskInputControllerCallbacks,
} from '../../../main/ets/pages/rustdesk/RustDeskInputController';
import {
  RustDeskCoordinateSpace,
  RustDeskFlutterKeyPayload,
  RustDeskKeyPayload,
  RustDeskMousePayload,
  RustDeskRect,
  resolveCoordinateSpace,
} from '../../../main/ets/pages/rustdesk/RustDeskInputMapper';
import { RustDeskRightClickGesture } from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';

/** The key codes these cases drive, as the mapper names them. */
const KEYCODE_A = 2017;
const KEYCODE_SHIFT = 2047;

/** A hardware key event, built field by field because ArkUI owns the real one. */
class TestKeyEvent implements KeyEvent {
  type: KeyType = KeyType.Down;
  keyCode: number = 0;
  keyText: string = '';
  keySource: KeySource = KeySource.Keyboard;
  deviceId: number = 0;
  metaKey: number = 0;
  timestamp: number = 0;
  intentionCode: IntentionCode = IntentionCode.INTENTION_UNKNOWN;
  stopPropagation: () => void = (): void => {};
}

function keyEvent(keyCode: number, down: boolean): TestKeyEvent {
  const event = new TestKeyEvent();
  event.keyCode = keyCode;
  event.type = down ? KeyType.Down : KeyType.Up;
  return event;
}

/** The target every synthetic event carries; only its presence is read. */
class TestEventTarget implements EventTarget {
  area: Area = {
    width: 0,
    height: 0,
    position: { x: 0, y: 0 },
    globalPosition: { x: 0, y: 0 },
  };
}

/** One touch point, built field by field because ArkUI owns the real one. */
class TestTouchObject implements TouchObject {
  type: TouchType = TouchType.Down;
  id: number = 0;
  displayX: number = 0;
  displayY: number = 0;
  windowX: number = 0;
  windowY: number = 0;
  screenX: number = 0;
  screenY: number = 0;
  x: number = 0;
  y: number = 0;
}

class TestTouchEvent implements TouchEvent {
  type: TouchType = TouchType.Down;
  touches: TouchObject[] = [];
  changedTouches: TouchObject[] = [];
  stopPropagation: () => void = (): void => {};
  preventDefault: () => void = (): void => {};
  target: EventTarget = new TestEventTarget();
  timestamp: number = 0;
  source: SourceType = SourceType.TouchScreen;
  pressure: number = 0;
  tiltX: number = 0;
  tiltY: number = 0;
  sourceTool: SourceTool = SourceTool.Finger;

  getHistoricalPoints(): Array<HistoricalPoint> {
    return [];
  }
}

class TestMouseEvent implements MouseEvent {
  button: MouseButton = MouseButton.Left;
  action: MouseAction = MouseAction.Move;
  displayX: number = 0;
  displayY: number = 0;
  windowX: number = 0;
  windowY: number = 0;
  screenX: number = 0;
  screenY: number = 0;
  x: number = 0;
  y: number = 0;
  stopPropagation: () => void = (): void => {};
  target: EventTarget = new TestEventTarget();
  timestamp: number = 0;
  source: SourceType = SourceType.Mouse;
  pressure: number = 0;
  tiltX: number = 0;
  tiltY: number = 0;
  sourceTool: SourceTool = SourceTool.MOUSE;
}

/**
 * One touch delivery from `sourceTool`, with a single point.
 *
 * An Up or Cancel carries the lifted point in `changedTouches` only, which is how
 * ArkUI reports it: `touches` holds the points still down.
 */
function touchEvent(sourceTool: SourceTool, type: TouchType, x: number, y: number): TouchEvent {
  const event = new TestTouchEvent();
  event.sourceTool = sourceTool;
  event.type = type;
  const touch = new TestTouchObject();
  touch.type = type;
  touch.x = x;
  touch.y = y;
  event.changedTouches = [touch];
  event.touches = [];
  if (type !== TouchType.Up && type !== TouchType.Cancel) {
    event.touches = [touch];
  }
  return event;
}

/** An injected pointer: it arrives as a touch event, not through `onMouse`. */
function pointerTouch(type: TouchType, x: number, y: number): TouchEvent {
  return touchEvent(SourceTool.MOUSE, type, x, y);
}

function fingerTouch(type: TouchType, x: number, y: number): TouchEvent {
  return touchEvent(SourceTool.Finger, type, x, y);
}

function mouseEvent(action: MouseAction, x: number, y: number): MouseEvent {
  const event = new TestMouseEvent();
  event.action = action;
  event.x = x;
  event.y = y;
  return event;
}

/** A space whose presented picture fills the pane: 800x600 for a 1600x1200 peer. */
function spaceFor(viewWidth: number, viewHeight: number, remoteWidth: number, remoteHeight: number): RustDeskCoordinateSpace {
  return resolveCoordinateSpace(viewWidth, viewHeight, new RustDeskRect(0, 0, remoteWidth, remoteHeight), 0);
}

/** What the controller emitted, and what the peer accepted. */
class InputRecord {
  keys: RustDeskKeyPayload[] = [];
  flutterKeys: RustDeskFlutterKeyPayload[] = [];
  mouse: RustDeskMousePayload[] = [];
  space: RustDeskCoordinateSpace | undefined = undefined;
  /** A false answer stands for a native refusal, so nothing was admitted. */
  acceptKeySend: boolean = true;
  /** Whether the session takes the Core's raw key route instead of the legacy one. */
  rawRoute: boolean = false;
}

function callbacksFor(record: InputRecord): RustDeskInputControllerCallbacks {
  return {
    isSessionActive: (): boolean => true,
    usesCoreRawKeyRoute: (): boolean => record.rawRoute,
    isMouseMode: (): boolean => true,
    isPeerMacOS: (): boolean => false,
    isPeerAndroid: (): boolean => false,
    isPeerMobile: (): boolean => false,
    isLocalPhone: (): boolean => false,
    gesturesEnabled: (): boolean => false,
    rightClickGesture: (): RustDeskRightClickGesture => 'two_finger_tap',
    getCoordinateSpace: (): RustDeskCoordinateSpace | undefined => record.space,
    sendMouse: (payload: RustDeskMousePayload): void => {
      record.mouse.push(payload);
    },
    sendFlutterKey: (payload: RustDeskFlutterKeyPayload): boolean => {
      record.flutterKeys.push(payload);
      return true;
    },
    sendKey: (payload: RustDeskKeyPayload): boolean => {
      if (!record.acceptKeySend) {
        return false;
      }
      record.keys.push(payload);
      return true;
    },
    log: (_label: string, _payload: string): void => {},
    remoteCursorDebugText: (): string => '',
    overlayCursorDebugText: (_label: string): string => '',
    onVirtualCursorMoved: (_remoteX: number, _remoteY: number): void => {},
    onCanvasTransform: (
      _scaleFactor: number,
      _panX: number,
      _panY: number,
      _focalX: number,
      _focalY: number,
    ): void => {},
  };
}

export default function rustDeskInputControllerTest(): void {
  describe('RustDeskInputControllerTest', () => {
    it('releases a direct hardware key hold when input is turned off', 0, () => {
      const record = new InputRecord();
      const controller = new RustDeskInputController(callbacksFor(record));

      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(record.keys.length).assertEqual(1);
      expect(record.keys[0].name).assertEqual('a');
      expect(record.keys[0].down).assertTrue();

      controller.setInputSuppressed(true);
      expect(record.keys.length).assertEqual(2);
      expect(record.keys[1].name).assertEqual('a');
      expect(record.keys[1].down).assertFalse();

      // The key-up that follows is refused by the gate, so the hold cannot be
      // released twice and cannot be released later.
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, false))).assertFalse();
      expect(record.keys.length).assertEqual(2);
    });

    it('releases a held modifier and forgets its state', 0, () => {
      const record = new InputRecord();
      const controller = new RustDeskInputController(callbacksFor(record));

      expect(controller.handleKeyEvent(keyEvent(KEYCODE_SHIFT, true))).assertTrue();
      expect(record.keys.length).assertEqual(1);
      expect(record.keys[0].name).assertEqual('VK_SHIFT');
      expect(record.keys[0].down).assertTrue();

      controller.setInputSuppressed(true);
      expect(record.keys.length).assertEqual(2);
      expect(record.keys[1].name).assertEqual('VK_SHIFT');
      expect(record.keys[1].down).assertFalse();

      // A key pressed after input comes back carries no modifier the release
      // already took back.
      controller.setInputSuppressed(false);
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(record.keys.length).assertEqual(3);
      expect(record.keys[2].name).assertEqual('a');
      expect(record.keys[2].shift).assertFalse();
    });

    it('does not release a key the peer never accepted', 0, () => {
      const record = new InputRecord();
      const controller = new RustDeskInputController(callbacksFor(record));
      record.acceptKeySend = false;

      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertFalse();
      expect(record.keys.length).assertEqual(0);
      record.acceptKeySend = true;

      controller.setInputSuppressed(true);
      expect(record.keys.length).assertEqual(0);
    });

    it('owes one release however many downs were sent', 0, () => {
      const record = new InputRecord();
      const controller = new RustDeskInputController(callbacksFor(record));

      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(record.keys.length).assertEqual(2);

      controller.setInputSuppressed(true);
      expect(record.keys.length).assertEqual(3);
      expect(record.keys[2].name).assertEqual('a');
      expect(record.keys[2].down).assertFalse();
    });

    it('owes nothing for a key whose own up was sent', 0, () => {
      const record = new InputRecord();
      const controller = new RustDeskInputController(callbacksFor(record));

      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, false))).assertTrue();
      expect(record.keys.length).assertEqual(2);
      expect(record.keys[1].down).assertFalse();

      controller.setInputSuppressed(true);
      expect(record.keys.length).assertEqual(2);
    });

    it('leaves the Core raw key route owned by the interceptor', 0, () => {
      const record = new InputRecord();
      record.rawRoute = true;
      const controller = new RustDeskInputController(callbacksFor(record));

      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(record.flutterKeys.length).assertEqual(1);
      expect(record.keys.length).assertEqual(0);

      controller.setInputSuppressed(true);
      expect(record.keys.length).assertEqual(0);
      expect(record.flutterKeys.length).assertEqual(1);
    });

    it('keeps an injected pointer sequence through its own release', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 100, 100));

      // The click lands on the point the pointer named, not on the touchpad's
      // virtual cursor, whose position is the display centre.
      expect(record.mouse.length).assertEqual(3);
      expect(record.mouse[0].x).assertEqual('200');
      expect(record.mouse[0].y).assertEqual('200');
      expect(record.mouse[1].type).assertEqual('down');
      expect(record.mouse[1].buttons).assertEqual('left');
      expect(record.mouse[2].type).assertEqual('up');
      expect(record.mouse[2].buttons).assertEqual('left');
    });

    it('drives a repeated injected pointer sequence the same way', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 100, 100));
      expect(record.mouse.length).assertEqual(3);

      controller.handleTouchEvent(pointerTouch(TouchType.Down, 300, 200));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 300, 200));

      // The first sequence left nothing behind, so the second is its own sequence
      // and lands on its own point instead of being read as a second finger.
      expect(record.mouse.length).assertEqual(6);
      expect(record.mouse[3].x).assertEqual('600');
      expect(record.mouse[3].y).assertEqual('400');
      expect(record.mouse[4].type).assertEqual('down');
      expect(record.mouse[5].type).assertEqual('up');
    });

    it('presses, moves and releases an injected pointer sequence absolutely', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Move, 300, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 300, 100));

      // The press is at the point the drag started from, the movement follows the
      // point, and the release ends it.
      expect(record.mouse.length).assertEqual(4);
      expect(record.mouse[0].x).assertEqual('200');
      expect(record.mouse[0].y).assertEqual('200');
      expect(record.mouse[1].type).assertEqual('down');
      expect(record.mouse[1].buttons).assertEqual('left');
      expect(record.mouse[2].x).assertEqual('600');
      expect(record.mouse[2].y).assertEqual('200');
      expect(record.mouse[3].type).assertEqual('up');
      expect(record.mouse[3].buttons).assertEqual('left');
    });

    it('releases an injected pointer drag that is cancelled', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Move, 300, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Cancel, 300, 100));

      expect(record.mouse.length).assertEqual(4);
      expect(record.mouse[3].type).assertEqual('up');
      expect(record.mouse[3].buttons).assertEqual('left');

      // The cancelled sequence is fully cleared, so the next one is a plain tap.
      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 100, 100));
      expect(record.mouse.length).assertEqual(7);
      expect(record.mouse[4].x).assertEqual('200');
      expect(record.mouse[4].y).assertEqual('200');
      expect(record.mouse[5].type).assertEqual('down');
      expect(record.mouse[6].type).assertEqual('up');
    });

    it('lets a physical mouse keep the pointer from the touches it duplicates', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.handleMouseEvent(mouseEvent(MouseAction.Move, 400, 300));
      controller.handleMouseEvent(mouseEvent(MouseAction.Press, 400, 300));

      expect(record.mouse.length).assertEqual(3);
      expect(record.mouse[2].type).assertEqual('down');
      expect(record.mouse[2].buttons).assertEqual('left');

      // The same gesture delivered as a touch is not handled a second time.
      controller.handleTouchEvent(pointerTouch(TouchType.Down, 400, 300));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 400, 300));
      expect(record.mouse.length).assertEqual(3);
    });

    it('abandons an open injected pointer sequence when the mouse takes over', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      expect(record.mouse.length).assertEqual(0);

      controller.handleMouseEvent(mouseEvent(MouseAction.Move, 400, 300));
      expect(record.mouse.length).assertEqual(1);

      // The abandoned sequence emits no click of its own, and its release is not
      // taken as a gesture either.
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 100, 100));
      expect(record.mouse.length).assertEqual(1);
    });

    it('keeps a real finger driving the touchpad cursor', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.handleTouchEvent(fingerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 300, 100));

      // A finger in mouse mode is a touchpad: the cursor is nudged by the mapped
      // delta from the display centre, never placed at the finger's own point.
      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].x).assertEqual('1200');
      expect(record.mouse[0].y).assertEqual('600');
    });
  });
}
