import { describe, expect, it } from '@ohos/hypium';
import { IntentionCode } from '@ohos.multimodalInput.intentionCode';
import {
  RustDeskInputController,
  RustDeskInputControllerCallbacks,
} from '../../../main/ets/pages/rustdesk/RustDeskInputController';
import {
  RemotePointerPosition,
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
  rawDeltaX?: number = 0;
  rawDeltaY?: number = 0;
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

function mouseEvent(action: MouseAction, x: number, y: number, rawDeltaX?: number, rawDeltaY?: number): MouseEvent {
  const event = new TestMouseEvent();
  event.action = action;
  event.x = x;
  event.y = y;
  if (rawDeltaX !== undefined) {
    event.rawDeltaX = rawDeltaX;
  }
  if (rawDeltaY !== undefined) {
    event.rawDeltaY = rawDeltaY;
  }
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
  moveRects: RustDeskRect[] | undefined = undefined;
  cursorPositions: RemotePointerPosition[] = [];
  binding: RustDeskInputBinding | undefined = { sessionId: 'session-a', inputGeneration: 7 };
  acceptKeySend: boolean = true;
  acceptMouseSend: boolean = true;
  vnc: boolean = false;
  sharedPointerAuthority: boolean = false;
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
    getCursorMoveRects: (): RustDeskRect[] | undefined => record.moveRects,
    usesSharedPointerAuthority: (): boolean => record.sharedPointerAuthority,
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
    onVirtualCursorMoved: (remoteX: number, remoteY: number): void => {
      record.cursorPositions.push({ x: remoteX, y: remoteY });
    },
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

    it('allows touchpad cursor to move into shared screen and return', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const currentRect = new RustDeskRect(0, 0, 1600, 1200);
      const shareRect = new RustDeskRect(1600, 0, 1920, 1080);
      record.moveRects = [currentRect, shareRect];
      const controller = new RustDeskInputController(callbacksFor(record));

      // Initial center is (800, 600)
      // Finger swipe right: dx = 500 local => 1000 remote
      // Target: 800 + 1000 = 1800 (inside shareRect 1600..3519)
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 600, 100));
      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].x).assertEqual('1800');
      expect(record.mouse[0].y).assertEqual('600');
      expect(controller.getVirtualCursorX()).assertEqual(1800);
      expect(controller.getVirtualCursorY()).assertEqual(600);

      // Continue moving right by dx = 200 local => 400 remote
      // Target: 1800 + 400 = 2200 (still inside shareRect)
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 800, 100));
      expect(record.mouse.length).assertEqual(2);
      expect(record.mouse[1].x).assertEqual('2200');
      expect(record.mouse[1].y).assertEqual('600');
      expect(controller.getVirtualCursorX()).assertEqual(2200);

      // Release first swipe
      controller.handleTouchEvent(fingerTouch(TouchType.Up, 800, 100));

      // Second swipe to move back left: dx = -600 local => -1200 remote
      // Target: 2200 - 1200 = 1000 (back inside currentRect 0..1599)
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 700, 100));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 100, 100));
      const lastMouse = record.mouse[record.mouse.length - 1];
      expect(lastMouse.x).assertEqual('1000');
      expect(lastMouse.y).assertEqual('600');
      expect(controller.getVirtualCursorX()).assertEqual(1000);
      expect(controller.getVirtualCursorY()).assertEqual(600);
    });

    it('clamps touchpad cursor to outer boundary of shared screen', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const currentRect = new RustDeskRect(0, 0, 1600, 1200);
      const shareRect = new RustDeskRect(1600, 0, 1920, 1080);
      record.moveRects = [currentRect, shareRect];
      const controller = new RustDeskInputController(callbacksFor(record));

      // Far right move: shareRect maxX = 1600 + 1920 - 1 = 3519
      // From 800, dx = 2000 local => 4000 remote -> target 4800
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 0, 100));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 2000, 100));
      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].x).assertEqual('3519');
      expect(record.mouse[0].y).assertEqual('600');
      expect(controller.getVirtualCursorX()).assertEqual(3519);
    });

    it('allows touchpad cursor to enter shared screen with negative origin', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const currentRect = new RustDeskRect(0, 0, 1600, 1200);
      const leftShareRect = new RustDeskRect(-1920, 0, 1920, 1080);
      record.moveRects = [currentRect, leftShareRect];
      const controller = new RustDeskInputController(callbacksFor(record));

      // Initial center is (800, 600)
      // Swipe left: dx = -600 local => -1200 remote
      // Target: 800 - 1200 = -400 (inside leftShareRect: -1920..-1)
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 700, 200));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 100, 200));
      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].x).assertEqual('-400');
      expect(record.mouse[0].y).assertEqual('600');
      expect(controller.getVirtualCursorX()).assertEqual(-400);

      // Swipe further left past -1920
      controller.handleTouchEvent(fingerTouch(TouchType.Move, -1000, 200));
      expect(record.mouse.length).assertEqual(2);
      expect(record.mouse[1].x).assertEqual('-1920');
      expect(controller.getVirtualCursorX()).assertEqual(-1920);
    });

    it('clamps to nearest valid screen when target falls in gap/void', 0, () => {
      const record = new InputRecord();
      // remote 1000x1000, view 500x500 (scale 2)
      record.space = spaceFor(500, 500, 1000, 1000);
      const currentRect = new RustDeskRect(0, 0, 1000, 1000);
      const steppedRect = new RustDeskRect(1000, 500, 1000, 1000);
      record.moveRects = [currentRect, steppedRect];
      const controller = new RustDeskInputController(callbacksFor(record));

      // Initial center: (500, 500)
      // Move up to y = 200: dy = -150 local => -300 remote (500 - 300 = 200)
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 250, 250));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 250, 100));
      expect(record.mouse[0].x).assertEqual('500');
      expect(record.mouse[0].y).assertEqual('200');

      // Now move right into void at y = 200: dx = +200 local => +400 remote
      // Target: x = 900, y = 200 (still inside currentRect)
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 450, 100));
      expect(record.mouse[1].x).assertEqual('900');
      expect(record.mouse[1].y).assertEqual('200');

      // Move right further into void: dx = +150 local => +300 remote
      // Target: x = 1200, y = 200
      // CurrentRect: clamped (999, 200), distSq = (1200-999)^2 = 40401
      // SteppedRect: clamped (1200, 500), distSq = (200-500)^2 = 90000
      // CurrentRect is closer, so clamped to (999, 200)!
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 600, 100));
      expect(record.mouse[2].x).assertEqual('999');
      expect(record.mouse[2].y).assertEqual('200');
      expect(controller.getVirtualCursorX()).assertEqual(999);
      expect(controller.getVirtualCursorY()).assertEqual(200);
    });

    it('preserves single display remoteRect clamp when share callback returns undefined or empty', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      record.moveRects = undefined;
      const controller = new RustDeskInputController(callbacksFor(record));

      // Move past right boundary (target: 800 + 1200 = 2000)
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 700, 100));
      expect(record.mouse[0].x).assertEqual('1599');
      expect(record.mouse[0].y).assertEqual('600');
      expect(controller.getVirtualCursorX()).assertEqual(1599);

      // Now with empty array
      record.moveRects = [];
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 800, 100));
      expect(record.mouse[1].x).assertEqual('1599');
      expect(controller.getVirtualCursorX()).assertEqual(1599);
    });

    it('broadcasts unclipped virtual cursor coordinates to onVirtualCursorMoved', 0, () => {
      const record = new InputRecord();
      record.space = spaceFor(800, 600, 1600, 1200);
      const currentRect = new RustDeskRect(0, 0, 1600, 1200);
      const shareRect = new RustDeskRect(1600, 0, 1920, 1080);
      record.moveRects = [currentRect, shareRect];
      const controller = new RustDeskInputController(callbacksFor(record));

      // Move into shared screen at 1800, 600
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 600, 100));

      const lastReported = record.cursorPositions[record.cursorPositions.length - 1];
      expect(lastReported !== undefined).assertTrue();
      expect(lastReported.x).assertEqual(1800);
      expect(lastReported.y).assertEqual(600);
    });

    it('shared pointer mode: physical mouse with rawDelta sends move_relative and does not track virtualCursor', 0, () => {
      const record = new InputRecord();
      record.sharedPointerAuthority = true;
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      // rawDelta (10, 5) in view -> remote delta (20, 10)
      controller.handleMouseEvent(mouseEvent(MouseAction.Move, 100, 100, 10, 5));
      controller.flushRelativeMouseMove();

      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].type).assertEqual('move_relative');
      expect(record.mouse[0].x).assertEqual('20');
      expect(record.mouse[0].y).assertEqual('10');
      expect(controller.hasVirtualCursor()).assertFalse();
      expect(record.cursorPositions.length).assertEqual(0);
    });

    it('shared pointer mode: physical mouse fallback local delta rebases on first move and sends move_relative on second', 0, () => {
      const record = new InputRecord();
      record.sharedPointerAuthority = true;
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      // First move without rawDelta: only rebase, no payload sent
      controller.handleMouseEvent(mouseEvent(MouseAction.Move, 100, 100));
      controller.flushRelativeMouseMove();
      expect(record.mouse.length).assertEqual(0);

      // Second move without rawDelta: localDelta (15, -10) -> remote delta (30, -20)
      controller.handleMouseEvent(mouseEvent(MouseAction.Move, 115, 90));
      controller.flushRelativeMouseMove();
      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].type).assertEqual('move_relative');
      expect(record.mouse[0].x).assertEqual('30');
      expect(record.mouse[0].y).assertEqual('-20');
      expect(controller.hasVirtualCursor()).assertFalse();
    });

    it('shared pointer mode: physical mouse click sends button down and up without absolute move or coordinates', 0, () => {
      const record = new InputRecord();
      record.sharedPointerAuthority = true;
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      // Click at (200, 200) inside content
      controller.handleMouseEvent(mouseEvent(MouseAction.Press, 200, 200));
      controller.handleMouseEvent(mouseEvent(MouseAction.Release, 200, 200));

      expect(record.mouse.length).assertEqual(2);
      expect(record.mouse[0].type).assertEqual('down');
      expect(record.mouse[0].buttons).assertEqual('left');
      expect(record.mouse[0].x).assertUndefined();
      expect(record.mouse[0].y).assertUndefined();
      expect(record.mouse[1].type).assertEqual('up');
      expect(record.mouse[1].buttons).assertEqual('left');
      expect(record.mouse[1].x).assertUndefined();
      expect(record.mouse[1].y).assertUndefined();
      expect(controller.hasVirtualCursor()).assertFalse();
      expect(record.cursorPositions.length).assertEqual(0);
    });

    it('shared pointer mode: touchpad finger swipe sends move_relative without advancing virtual cursor', 0, () => {
      const record = new InputRecord();
      record.sharedPointerAuthority = true;
      record.space = spaceFor(800, 600, 1600, 1200);
      const currentRect = new RustDeskRect(0, 0, 1600, 1200);
      const shareRect = new RustDeskRect(1600, 0, 1920, 1080);
      record.moveRects = [currentRect, shareRect];
      const controller = new RustDeskInputController(callbacksFor(record));

      // Touchpad move: dx = 50 local => 100 remote, dy = 30 local => 60 remote
      controller.handleTouchEvent(fingerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(fingerTouch(TouchType.Move, 150, 130));
      controller.flushRelativeMouseMove();

      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].type).assertEqual('move_relative');
      expect(record.mouse[0].x).assertEqual('100');
      expect(record.mouse[0].y).assertEqual('60');
      // No local virtual cursor integral, no clamping against rects
      expect(controller.hasVirtualCursor()).assertFalse();
      expect(record.cursorPositions.length).assertEqual(0);
    });

    it('shared pointer mode: touch tap sends button click without cursor absolute move', 0, () => {
      const record = new InputRecord();
      record.sharedPointerAuthority = true;
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      // Pointer-sourced touch fallback tap
      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Up, 100, 100));

      expect(record.mouse.length).assertEqual(2);
      expect(record.mouse[0].type).assertEqual('down');
      expect(record.mouse[0].buttons).assertEqual('left');
      expect(record.mouse[0].x).assertUndefined();
      expect(record.mouse[0].y).assertUndefined();
      expect(record.mouse[1].type).assertEqual('up');
      expect(record.mouse[1].buttons).assertEqual('left');
      expect(record.mouse[1].x).assertUndefined();
      expect(record.mouse[1].y).assertUndefined();
      expect(controller.hasVirtualCursor()).assertFalse();
    });

    it('shared pointer mode: pointer-sourced touch move sends move_relative instead of absolute move', 0, () => {
      const record = new InputRecord();
      record.sharedPointerAuthority = true;
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.handleTouchEvent(pointerTouch(TouchType.Down, 100, 100));
      controller.handleTouchEvent(pointerTouch(TouchType.Move, 120, 110));
      controller.flushRelativeMouseMove();

      expect(record.mouse.length).assertEqual(1);
      expect(record.mouse[0].type).assertEqual('move_relative');
      expect(record.mouse[0].x).assertEqual('40');
      expect(record.mouse[0].y).assertEqual('20');
      expect(controller.hasVirtualCursor()).assertFalse();
    });

    it('shared pointer mode: initVirtualCursorToCenter does not fabricate virtual cursor', 0, () => {
      const record = new InputRecord();
      record.sharedPointerAuthority = true;
      record.space = spaceFor(800, 600, 1600, 1200);
      const controller = new RustDeskInputController(callbacksFor(record));

      controller.initVirtualCursorToCenter();
      expect(controller.hasVirtualCursor()).assertFalse();
      expect(record.cursorPositions.length).assertEqual(0);
    });
  });
}
