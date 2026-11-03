import { describe, expect, it } from '@ohos/hypium';
import { IntentionCode } from '@ohos.multimodalInput.intentionCode';
import {
  RustDeskInputController,
  RustDeskInputControllerCallbacks,
} from '../../../main/ets/pages/rustdesk/RustDeskInputController';
import {
  RustDeskCoordinateSpace,
  RustDeskInputBinding,
  RustDeskKeyPayload,
  RustDeskMousePayload,
  RustDeskRect,
  resolveCoordinateSpace,
} from '../../../main/ets/pages/rustdesk/RustDeskInputMapper';
import { RustDeskRightClickGesture } from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';

const KEYCODE_A = 2017;
const KEYCODE_SHIFT = 2047;

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

class TestEventTarget implements EventTarget {
  area: Area = {
    width: 0,
    height: 0,
    position: { x: 0, y: 0 },
    globalPosition: { x: 0, y: 0 },
  };
}

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

function touchEvent(sourceTool: SourceTool, type: TouchType, x: number, y: number): TouchEvent {
  const event = new TestTouchEvent();
  event.sourceTool = sourceTool;
  event.type = type;
  const touch = new TestTouchObject();
  touch.type = type;
  touch.x = x;
  touch.y = y;
  event.changedTouches = [touch];
  if (type !== TouchType.Up && type !== TouchType.Cancel) {
    event.touches = [touch];
  }
  return event;
}

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

function spaceFor(viewWidth: number, viewHeight: number, remoteWidth: number, remoteHeight: number): RustDeskCoordinateSpace {
  return resolveCoordinateSpace(viewWidth, viewHeight, new RustDeskRect(0, 0, remoteWidth, remoteHeight), 0);
}

class KeysymRecord {
  keysym: number;
  down: boolean;
  sessionId: string;
  generation: number;

  constructor(keysym: number, down: boolean, binding: RustDeskInputBinding) {
    this.keysym = keysym;
    this.down = down;
    this.sessionId = binding.sessionId;
    this.generation = binding.inputGeneration;
  }
}

/** Synthetic native receipts, not peer-delivery or runtime interop evidence. */
class InputRecord {
  keys: RustDeskKeyPayload[] = [];
  keyBindings: RustDeskInputBinding[] = [];
  keyAttempts: number = 0;
  keysyms: KeysymRecord[] = [];
  texts: string[] = [];
  mouse: RustDeskMousePayload[] = [];
  releases: string[] = [];
  errors: string[] = [];
  space: RustDeskCoordinateSpace | undefined = undefined;
  binding: RustDeskInputBinding | undefined = { sessionId: 'session-a', inputGeneration: 7 };
  acceptKeySend: boolean = true;
  acceptMouseSend: boolean = true;
  vnc: boolean = false;
  rejectKeysymAt: number = -1;
  /** A fixture-supplied native refusal/release generation, never a UI counter. */
  refusalGeneration: number | undefined = undefined;
  releaseGeneration: number | undefined = undefined;
}

function adoptFixtureGeneration(record: InputRecord, generation: number | undefined): void {
  const previous = record.binding;
  if (generation !== undefined && previous !== undefined) {
    record.binding = { sessionId: previous.sessionId, inputGeneration: generation };
  }
}

function callbacksFor(record: InputRecord): RustDeskInputControllerCallbacks {
  return {
    isSessionActive: (): boolean => true,
    getInputBinding: (): RustDeskInputBinding | undefined => record.binding,
    usesVncKeysym: (): boolean => record.vnc,
    isMouseMode: (): boolean => true,
    isPeerMacOS: (): boolean => false,
    isPeerAndroid: (): boolean => false,
    isPeerMobile: (): boolean => false,
    isLocalPhone: (): boolean => false,
    gesturesEnabled: (): boolean => false,
    rightClickGesture: (): RustDeskRightClickGesture => 'two_finger_tap',
    getCoordinateSpace: (): RustDeskCoordinateSpace | undefined => record.space,
    sendMouse: (payload: RustDeskMousePayload, _binding: RustDeskInputBinding): boolean => {
      record.mouse.push(payload);
      if (!record.acceptMouseSend) {
        adoptFixtureGeneration(record, record.refusalGeneration);
      }
      return record.acceptMouseSend;
    },
    sendKey: (payload: RustDeskKeyPayload, binding: RustDeskInputBinding): boolean => {
      record.keyAttempts++;
      record.keyBindings.push(binding);
      if (!record.acceptKeySend) {
        adoptFixtureGeneration(record, record.refusalGeneration);
        return false;
      }
      record.keys.push(payload);
      return true;
    },
    sendKeysym: (keysym: number, down: boolean, binding: RustDeskInputBinding): boolean => {
      record.keysyms.push(new KeysymRecord(keysym, down, binding));
      const admitted = record.keysyms.length !== record.rejectKeysymAt;
      if (!admitted) {
        adoptFixtureGeneration(record, record.refusalGeneration);
      }
      return admitted;
    },
    sendText: (text: string, _binding: RustDeskInputBinding): boolean => {
      record.texts.push(text);
      return true;
    },
    releaseInput: (sessionId: string): void => {
      record.releases.push(sessionId);
      if (record.binding?.sessionId === sessionId) {
        adoptFixtureGeneration(record, record.releaseGeneration);
      }
    },
    reportInputError: (message: string): void => { record.errors.push(message); },
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
    it('retires a RustDesk hardware hold on focus loss instead of synthesizing UP', 0, () => {
      const record = new InputRecord();
      record.releaseGeneration = 8;
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(record.keys[0].name).assertEqual('a');
      expect(record.keyBindings[0].inputGeneration).assertEqual(7);

      controller.setInputSuppressed(true);
      expect(record.releases.length).assertEqual(1);
      expect(record.releases[0]).assertEqual('session-a');
      expect(record.keys.length).assertEqual(1);
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, false))).assertFalse();
      controller.setInputSuppressed(false);
      // The old physical UP belongs to the retired hold, not the new epoch.
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, false))).assertFalse();
      expect(record.keys.length).assertEqual(1);
    });

    it('forgets held modifiers locally after native retirement', 0, () => {
      const record = new InputRecord();
      record.releaseGeneration = 8;
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_SHIFT, true))).assertTrue();
      controller.setInputSuppressed(true);
      controller.setInputSuppressed(false);
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(record.keys.length).assertEqual(2);
      expect(record.keys[1].shift).assertFalse();
      expect(record.keyBindings[1].inputGeneration).assertEqual(8);
    });

    it('retires repeated hardware downs through one native release', 0, () => {
      const record = new InputRecord();
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      controller.setInputSuppressed(true);
      controller.setInputSuppressed(true);
      expect(record.keys.length).assertEqual(2);
      expect(record.releases.length).assertEqual(1);
    });

    it('does not synthesize another UP after the keys own UP was admitted', 0, () => {
      const record = new InputRecord();
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_SHIFT, true))).assertTrue();
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_SHIFT, false))).assertTrue();
      expect(record.keys[1].down).assertFalse();
      expect(record.keys[1].shift).assertFalse();
      controller.setInputSuppressed(true);
      expect(record.keys.length).assertEqual(2);
    });

    it('does not send without a numeric native generation', 0, () => {
      const record = new InputRecord();
      record.binding = undefined;
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertFalse();
      expect(controller.sendText('a')).assertFalse();
      controller.handleMouseEvent(mouseEvent(MouseAction.Move, 100, 100));
      expect(record.keyAttempts).assertEqual(0);
      expect(record.mouse.length).assertEqual(0);
      expect(record.texts.length).assertEqual(0);
    });

    it('adopts a refusal only for the next event, with no legacy retry', 0, () => {
      const record = new InputRecord();
      record.acceptKeySend = false;
      record.refusalGeneration = 9;
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertFalse();
      expect(record.keyAttempts).assertEqual(1);
      expect(record.keyBindings[0].inputGeneration).assertEqual(7);
      record.acceptKeySend = true;
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      expect(record.keyAttempts).assertEqual(2);
      expect(record.keyBindings[1].inputGeneration).assertEqual(9);
    });

    it('does not send insertion after an IME backspace was refused', 0, () => {
      const record = new InputRecord();
      record.acceptKeySend = false;
      record.refusalGeneration = 9;
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.sendImeDelta(3, 'new')).assertFalse();
      expect(record.keyAttempts).assertEqual(1);
      expect(record.texts.length).assertEqual(0);
    });

    it('releases the original session even after active callbacks point to another tab', 0, () => {
      const record = new InputRecord();
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(KEYCODE_A, true))).assertTrue();
      record.binding = { sessionId: 'session-b', inputGeneration: 2 };
      controller.reset();
      expect(record.releases.length).assertEqual(1);
      expect(record.releases[0]).assertEqual('session-a');
      expect(record.keys.length).assertEqual(1);
    });

    it('reuses the exact physical VNC keysym on UP', 0, () => {
      const record = new InputRecord();
      record.vnc = true;
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(2119, true))).assertTrue();
      const up = keyEvent(2119, false);
      up.keyText = 'different';
      expect(controller.handleKeyEvent(up)).assertTrue();
      expect(record.keysyms.length).assertEqual(2);
      expect(record.keysyms[0].keysym).assertEqual(0xFF8D);
      expect(record.keysyms[1].keysym).assertEqual(0xFF8D);
      expect(record.keysyms[0].down).assertTrue();
      expect(record.keysyms[1].down).assertFalse();
      expect(record.keys.length).assertEqual(0);
    });

    it('sends VNC Latin-1, CJK and supplementary characters as code-point pairs', 0, () => {
      const record = new InputRecord();
      record.vnc = true;
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.sendText('é中😀')).assertTrue();
      expect(record.keysyms.length).assertEqual(6);
      expect(record.keysyms[0].keysym).assertEqual(0xE9);
      expect(record.keysyms[2].keysym).assertEqual(0x01004E2D);
      expect(record.keysyms[4].keysym).assertEqual(0x0101F600);
      for (let index = 0; index < record.keysyms.length; index += 2) {
        expect(record.keysyms[index].down).assertTrue();
        expect(record.keysyms[index + 1].down).assertFalse();
        expect(record.keysyms[index].keysym).assertEqual(record.keysyms[index + 1].keysym);
        expect(record.keysyms[index + 1].generation).assertEqual(7);
      }
      expect(record.texts.length).assertEqual(0);
    });

    it('retires once when a VNC text DOWN queued but its UP was refused', 0, () => {
      const record = new InputRecord();
      record.vnc = true;
      record.rejectKeysymAt = 2;
      record.refusalGeneration = 9;
      record.releaseGeneration = 10;
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.sendText('ab')).assertFalse();
      expect(record.keysyms.length).assertEqual(2);
      expect(record.keysyms[0].generation).assertEqual(7);
      expect(record.keysyms[1].generation).assertEqual(7);
      expect(record.releases.length).assertEqual(1);
      expect(record.releases[0]).assertEqual('session-a');
      expect(record.binding?.inputGeneration).assertEqual(10);
      // Only a separately requested event may use the release receipt's epoch.
      expect(controller.sendText('c')).assertTrue();
      expect(record.keysyms.length).assertEqual(4);
      expect(record.keysyms[2].keysym).assertEqual(0x63);
      expect(record.keysyms[2].generation).assertEqual(10);
    });

    it('sends VNC chords in order without releasing an already held modifier', 0, () => {
      const record = new InputRecord();
      record.vnc = true;
      const controller = new RustDeskInputController(callbacksFor(record));
      expect(controller.handleKeyEvent(keyEvent(2072, true))).assertTrue();
      const tap = new RustDeskKeyPayload('VK_A', false);
      tap.press = true;
      tap.ctrl = true;
      expect(controller.sendKey(tap)).assertTrue();
      expect(record.keysyms.length).assertEqual(3);
      expect(record.keysyms[0].keysym).assertEqual(0xFFE3);
      expect(record.keysyms[1].keysym).assertEqual(0x61);
      expect(record.keysyms[2].keysym).assertEqual(0x61);
      expect(controller.handleKeyEvent(keyEvent(2072, false))).assertTrue();
      expect(record.keysyms[3].keysym).assertEqual(0xFFE3);
      expect(record.keysyms[3].down).assertFalse();
    });

    it('does not continue a pointer click after its position was refused', 0, () => {
      const record = new InputRecord();
      record.acceptMouseSend = false;
      record.refusalGeneration = 9;
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));
      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 100, 100));
      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].type).assertUndefined();
    });

    it('keeps an injected pointer sequence through its own release', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));
      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 100, 100));
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
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 100, 100));
      expect(record.mouse.length).assertEqual(1);
    });

    it('keeps a real finger driving the touchpad cursor', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 300, 100));
      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].x).assertEqual('1200');
      expect(record.mouse[0].y).assertEqual('600');
    });
  });
}
