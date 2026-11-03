import {
  isLocalPointInsidePaintRect,
  mapHarmonyKeyCodeToKeysym,
  mapLegacyKeyToKeysym,
  unicodeKeysym,
  validInputGeneration,
  vncKeyChord,
  mapHarmonyKeyCode,
  mapLocalToRemote,
  mapMouseButton,
  mapViewDeltaToBase,
  RemotePointerPosition,
  RustDeskCoordinateSpace,
  RustDeskInputBinding,
  RustDeskKeyPayload,
  RustDeskKeyMapping,
  RustDeskModifierKey,
  RustDeskMousePayload,
} from './RustDeskInputMapper';
import {
  RustDeskPressedButtonOwner,
  RustDeskPressedButtonState,
  RustDeskPressedButtonTransition,
  RustDeskPointerMode,
} from './RustDeskPressedButtonState';
import {
  RustDeskTouchAction,
  RustDeskTouchGestureState,
  RustDeskTouchInteractionMode,
  DEFAULT_TOUCH_SCROLL_DIVISOR,
  TOUCH_TRANSFORM_PAN_SLOP,
  TOUCH_TRANSFORM_SCALE_SLOP,
  TOUCH_TWO_FINGER_TAP_MAX_MS,
} from './RustDeskTouchGestureState';
import { RustDeskRightClickGesture } from './RustDeskDirectoryTypes';

const TOUCHPAD_MOVE_SENSITIVITY = 1.0;
const RELATIVE_MOUSE_RAW_SENSITIVITY = 1.0;
const RELATIVE_MOUSE_FLUSH_MS = 16;
const RELATIVE_MOUSE_MAX_DELTA = 10000;
const RELATIVE_MOUSE_BUTTON_SUPPRESS_MS = 120;
const RELATIVE_MOUSE_WARP_MIN_THRESHOLD = 96;

export interface RustDeskInputControllerCallbacks {
  isSessionActive: () => boolean;
  getInputBinding: () => RustDeskInputBinding | undefined;
  usesVncKeysym: () => boolean;
  isMouseMode: () => boolean;
  isPeerMacOS: () => boolean;
  isPeerAndroid: () => boolean;
  isPeerMobile: () => boolean;
  isLocalPhone: () => boolean;
  gesturesEnabled: () => boolean;
  rightClickGesture: () => RustDeskRightClickGesture;
  getCoordinateSpace: () => RustDeskCoordinateSpace | undefined;
  sendMouse: (payload: RustDeskMousePayload, binding: RustDeskInputBinding) => boolean;
  sendKey: (payload: RustDeskKeyPayload, binding: RustDeskInputBinding) => boolean;
  sendKeysym: (keysym: number, down: boolean, binding: RustDeskInputBinding) => boolean;
  sendText: (text: string, binding: RustDeskInputBinding) => boolean;
  releaseInput: (sessionId: string) => void;
  reportInputError: (message: string) => void;
  log: (label: string, payload: string) => void;
  remoteCursorDebugText: () => string;
  overlayCursorDebugText: (label: string) => string;
  // Flutter-mobile local virtual cursor moved to (remoteX, remoteY) in remote coords.
  onVirtualCursorMoved: (remoteX: number, remoteY: number) => void;
  onCanvasTransform: (
    scaleFactor: number,
    panX: number,
    panY: number,
    focalX: number,
    focalY: number,
  ) => void;
}

export class RustDeskInputController {
  /**
   * How long a `MouseEvent` keeps a new pointer-sourced touch sequence from
   * opening. Long enough to cover the gap between a real pointer's mouse and
   * touch deliveries, short enough that an injected pointer still gets through.
   */
  private static readonly POINTER_TOUCH_LATCH_MS = 250;
  private callbacks: RustDeskInputControllerCallbacks;
  private mouseModeActive: boolean;
  /** Set while a pointer-sourced touch sequence is open and owns its own events. */
  private pointerTouchSequence: boolean = false;
  /** Timestamp until which no new pointer-sourced touch sequence may open. */
  private pointerTouchLatchUntil: number = 0;
  private relativeModeActive: boolean;
  private activeModifiers: Set<RustDeskModifierKey> = new Set();
  /** Only keys whose down was actually admitted under this session's generation. */
  private heldKeyCodes: Set<number> = new Set();
  private heldKeyNames: Map<number, string> = new Map();
  private heldKeySyms: Map<number, number> = new Map();
  private heldNamedKeySyms: Map<string, number> = new Map();
  private eventBinding: RustDeskInputBinding | undefined = undefined;
  private eventRejected: boolean = false;
  private inputOwnerSessionId: string = '';
  private touchGestureState: RustDeskTouchGestureState = new RustDeskTouchGestureState();
  private touchPrimaryId: number = -1;
  private touchSecondaryId: number = -1;
  private touchThirdId: number = -1;
  private touchLastX: number = 0;
  private touchLastY: number = 0;
  private touchSecondaryLastX: number = 0;
  private touchSecondaryLastY: number = 0;
  private touchThirdLastX: number = 0;
  private touchThirdLastY: number = 0;
  private touchPrimaryReleased: boolean = false;
  private touchSecondaryReleased: boolean = false;
  private touchSequenceStartedAt: number = 0;
  private touchTwoFingerInitialCenterX: number = 0;
  private touchTwoFingerInitialCenterY: number = 0;
  private touchTwoFingerLastCenterX: number = 0;
  private touchTwoFingerLastCenterY: number = 0;
  private touchTwoFingerInitialDistance: number = 0;
  private touchTwoFingerLastDistance: number = 0;
  private touchTwoFingerMoved: boolean = false;
  private touchTwoFingerTransformActive: boolean = false;
  private touchThreeFingerLastCenterY: number = 0;
  private touchThreeFingerScrollIntegral: number = 0;
  private touchSuppressedIds: Set<number> = new Set();
  private touchLongPressTimer: number = -1;
  private touchTapTimeoutTimer: number = -1;
  private relativeLastX: number = 0;
  private relativeLastY: number = 0;
  private relativeHasLast: boolean = false;
  private relativePendingX: number = 0;
  private relativePendingY: number = 0;
  private relativeFlushTimer: number = -1;
  private relativeSuppressMoveUntil: number = 0;
  private inputSuppressed: boolean = false;
  private pressedButtons: RustDeskPressedButtonState = new RustDeskPressedButtonState();
  // Flutter-mobile style local virtual cursor, in REMOTE coordinates.
  // This is the single source of truth for the cursor overlay position, so a
  // Mac/Windows peer (whose cursor is never embedded in the video and whose
  // cursor_position is echo-excluded for our own moves) still shows a cursor.
  private virtualCursorX: number = 0;
  private virtualCursorY: number = 0;
  private virtualCursorValid: boolean = false;

  constructor(callbacks: RustDeskInputControllerCallbacks) {
    this.callbacks = callbacks;
    this.mouseModeActive = callbacks.isMouseMode();
    this.relativeModeActive = false;
  }

  reset(): void {
    this.releaseCurrentInput();
  }

  /** Native retired the old epoch. Forget local state without emitting any UP. */
  discardInputState(): void {
    this.cancelTouchTimers();
    this.touchGestureState.reset();
    this.clearRelativeMouseState(false);
    this.clearTouchPointerState();
    this.touchSuppressedIds.clear();
    this.pressedButtons.releaseAll();
    this.heldKeyCodes.clear();
    this.heldKeyNames.clear();
    this.heldKeySyms.clear();
    this.heldNamedKeySyms.clear();
    this.activeModifiers.clear();
    this.virtualCursorValid = false;
    this.eventBinding = undefined;
    this.eventRejected = true;
    this.inputOwnerSessionId = '';
  }

  /** Temporary local suppression retires holds, but never changes view-only policy. */
  setInputSuppressed(suppressed: boolean): void {
    if (this.inputSuppressed === suppressed) {
      return;
    }
    if (suppressed) {
      this.releaseCurrentInput();
    }
    this.inputSuppressed = suppressed;
    this.callbacks.log('mode', `input=${suppressed ? 'off' : 'on'}`);
  }

  private releaseCurrentInput(): void {
    const sessionId = this.inputOwnerSessionId;
    this.discardInputState();
    if (sessionId.length > 0) {
      this.callbacks.releaseInput(sessionId);
    }
  }

  private retireInput(binding: RustDeskInputBinding): void {
    this.discardInputState();
    this.callbacks.releaseInput(binding.sessionId);
  }

  isInputSuppressed(): boolean {
    return this.inputSuppressed;
  }

  private inputAllowed(): boolean {
    return !this.inputSuppressed;
  }

  private beginInputEvent(expected?: RustDeskInputBinding): boolean {
    const binding = this.callbacks.getInputBinding();
    if (!this.inputAllowed() || !this.callbacks.isSessionActive() || binding === undefined
      || !validInputGeneration(binding.inputGeneration)
      || (expected !== undefined && (binding.sessionId !== expected.sessionId
        || binding.inputGeneration !== expected.inputGeneration))) {
      this.eventBinding = undefined;
      this.eventRejected = true;
      return false;
    }
    this.eventBinding = { sessionId: binding.sessionId, inputGeneration: binding.inputGeneration };
    this.eventRejected = false;
    this.inputOwnerSessionId = binding.sessionId;
    return true;
  }

  private currentEventBinding(): RustDeskInputBinding | undefined {
    const binding = this.eventBinding;
    const live = this.callbacks.getInputBinding();
    if (!this.inputAllowed() || this.eventRejected || binding === undefined || live === undefined
      || live.sessionId !== binding.sessionId || live.inputGeneration !== binding.inputGeneration) {
      return undefined;
    }
    return binding;
  }

  private sendMouseIfAllowed(payload: RustDeskMousePayload): boolean {
    const binding = this.currentEventBinding();
    const admitted = binding !== undefined && this.callbacks.sendMouse(payload, binding);
    if (!admitted) {
      this.eventRejected = true;
    }
    return admitted;
  }

  private sendKeyIfAllowed(payload: RustDeskKeyPayload): boolean {
    const binding = this.currentEventBinding();
    const admitted = binding !== undefined && this.callbacks.sendKey(payload, binding);
    if (!admitted) {
      this.eventRejected = true;
    }
    return admitted;
  }

  private sendKeysymIfAllowed(keysym: number, down: boolean): boolean {
    const binding = this.currentEventBinding();
    const admitted = binding !== undefined && this.callbacks.sendKeysym(keysym, down, binding);
    if (!admitted) {
      this.eventRejected = true;
    }
    return admitted;
  }

  setMouseMode(active: boolean): void {
    if (this.mouseModeActive === active) {
      return;
    }
    this.cancelTouchTimers();
    this.applyTouchActions(this.touchGestureState.reset());
    this.clearTouchPointerState();
    this.touchSuppressedIds.clear();
    this.releasePressedButtons();
    if (this.relativeModeActive) {
      this.flushRelativeMouseMove();
    }
    this.clearRelativeMouseState(false);
    this.mouseModeActive = active;
    this.callbacks.log(
      'mode',
      `interaction=${active ? 'mouse' : 'touch'} relative=${this.relativeModeActive} ${this.callbacks.overlayCursorDebugText('overlay')} ${this.callbacks.remoteCursorDebugText()}`,
    );
  }

  setRelativeMode(active: boolean): void {
    if (this.relativeModeActive === active) {
      return;
    }
    this.cancelTouchTimers();
    this.applyTouchActions(this.touchGestureState.reset());
    this.clearTouchPointerState();
    this.touchSuppressedIds.clear();
    this.releasePressedButtons();
    if (this.relativeModeActive) {
      this.flushRelativeMouseMove();
    }
    this.clearRelativeMouseState(false);
    this.relativeModeActive = active;
    this.callbacks.log(
      'relative_mode',
      `active=${active} ${this.callbacks.overlayCursorDebugText('overlay')} ${this.callbacks.remoteCursorDebugText()}`,
    );
  }

  handleMouseEvent(event: MouseEvent): void {
    if (!this.beginInputEvent()) {
      return;
    }
    event.stopPropagation();
    if (event.action === MouseAction.Move || event.action === MouseAction.Hover) {
      this.handleMouseMove(event);
      return;
    }
    if (event.action !== MouseAction.Press && event.action !== MouseAction.Release) {
      return;
    }
    this.handleMouseButton(event);
  }

  handleAxisEvent(event: AxisEvent): void {
    if (!this.beginInputEvent()) {
      return;
    }
    const isTrackpad = event.sourceTool === SourceTool.TOUCHPAD;
    let deltaX: number;
    let deltaY: number;
    if (isTrackpad) {
      const scrollStepValue = event.scrollStep ?? 1;
      const scrollStep = scrollStepValue > 0 ? scrollStepValue : 1;
      deltaY = Math.round(-event.getVerticalAxisValue() / scrollStep * 8);
      deltaX = Math.round(-event.getHorizontalAxisValue() / scrollStep * 8);
    } else {
      const rawY = -event.getVerticalAxisValue();
      const rawX = -event.getHorizontalAxisValue();
      // RustDesk's mouse-wheel protocol uses a discrete -1/+1 step per event.
      // Forwarding HarmonyOS axis magnitude (and multiplying it) makes editors
      // interpret one wheel notch as dozens of lines. Match the upstream client
      // by keeping only the dominant axis and normalizing it to one step.
      const horizontalDominant = Math.abs(rawX) > Math.abs(rawY);
      deltaX = horizontalDominant ? Math.sign(rawX) : 0;
      deltaY = horizontalDominant ? 0 : Math.sign(rawY);
    }
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    const payload = new RustDeskMousePayload();
    payload.type = isTrackpad ? 'trackpad' : 'wheel';
    payload.x = String(deltaX);
    payload.y = String(deltaY);
    this.sendMouseIfAllowed(payload);
  }

  /** ArkUI is the physical acquisition owner; never retry a refused key via another route. */
  handleKeyEvent(event: KeyEvent): boolean {
    if (!this.beginInputEvent()) {
      return false;
    }
    const isDown = event.type === KeyType.Down;
    if (!isDown && event.type !== KeyType.Up) {
      return false;
    }
    const mapping: RustDeskKeyMapping | undefined = mapHarmonyKeyCode(event.keyCode)
      ?? (this.callbacks.usesVncKeysym() && event.keyCode === 2102 ? { name: 'VK_NUMLOCK' } : undefined);
    if (mapping === undefined) {
      this.callbacks.reportInputError('当前协议不支持此按键');
      return false;
    }
    // Also stop bubbling on refusal: a root handler must not resend this event
    // after the refusal has adopted a newer native generation.
    event.stopPropagation();
    if (!isDown && !this.heldKeyCodes.has(event.keyCode)) {
      return false;
    }
    const binding = this.currentEventBinding();
    if (binding === undefined) {
      return false;
    }
    const name = this.heldKeyNames.get(event.keyCode) ?? this.mapLegacyKeyNameForPeer(mapping);
    if (!isDown && mapping.modifier !== undefined) {
      // Preserve the legacy contract: a modifier UP must not ask native to
      // press that same modifier again via its accompanying modifier flags.
      this.activeModifiers.delete(mapping.modifier);
    }
    let admitted: boolean;
    let keysym: number | undefined = undefined;
    if (this.callbacks.usesVncKeysym()) {
      keysym = this.heldKeySyms.get(event.keyCode) ?? (name !== mapping.name
        ? mapLegacyKeyToKeysym(name) : mapHarmonyKeyCodeToKeysym(event.keyCode));
      admitted = keysym !== undefined && this.sendKeysymIfAllowed(keysym, isDown);
    } else {
      admitted = this.sendKeyIfAllowed(this.legacyKeyPayload(name, isDown));
    }
    this.callbacks.log('keyboard_send', `queued=${admitted} type=${this.keyEventTypeName(event.type)}`);
    if (!admitted) {
      if (!isDown) {
        this.retireInput(binding);
      }
      return false;
    }
    if (isDown) {
      this.heldKeyCodes.add(event.keyCode);
      this.heldKeyNames.set(event.keyCode, name);
      if (keysym !== undefined) {
        this.heldKeySyms.set(event.keyCode, keysym);
      }
      if (mapping.modifier !== undefined) {
        this.activeModifiers.add(mapping.modifier);
      }
    } else {
      this.heldKeyCodes.delete(event.keyCode);
      this.heldKeyNames.delete(event.keyCode);
      this.heldKeySyms.delete(event.keyCode);
      this.rebuildActiveModifiers();
    }
    return true;
  }

  releaseHeldKeys(): void {
    this.releaseCurrentInput();
  }

  private rebuildActiveModifiers(): void {
    this.activeModifiers.clear();
    this.heldKeyCodes.forEach((keyCode: number): void => {
      const mapping = mapHarmonyKeyCode(keyCode);
      if (mapping?.modifier !== undefined) {
        this.activeModifiers.add(mapping.modifier);
      }
    });
  }

  /** Soft keys, functional taps and chords share the physical key's real protocol route. */
  sendKey(payload: RustDeskKeyPayload): boolean {
    return this.beginInputEvent() && this.sendMappedKey(payload);
  }

  sendText(text: string): boolean {
    return this.beginInputEvent() && this.sendTextForCurrentEvent(text);
  }

  /** One IME edit is one event: a rejected backspace prevents the remaining insertion. */
  sendImeDelta(backspaceCount: number, insertedText: string): boolean {
    if (!this.beginInputEvent()) {
      return false;
    }
    for (let index = 0; index < backspaceCount; index++) {
      const backspace = new RustDeskKeyPayload('VK_BACK', false);
      backspace.press = true;
      if (!this.sendMappedKey(backspace)) {
        return false;
      }
    }
    return insertedText.length === 0 || this.sendTextForCurrentEvent(insertedText);
  }

  private sendMappedKey(payload: RustDeskKeyPayload): boolean {
    if (!this.callbacks.usesVncKeysym()) {
      return this.sendKeyIfAllowed(payload);
    }
    if (payload.press || payload.name === 'CTRL_ALT_DEL' || payload.name === 'LOCK_SCREEN') {
      const chord = vncKeyChord(payload);
      if (chord === undefined) {
        this.callbacks.reportInputError('VNC 不支持此按键');
        return false;
      }
      return this.sendVncTap(chord);
    }
    const binding = this.currentEventBinding();
    const held = this.heldNamedKeySyms.get(payload.name);
    const keysym = held ?? mapLegacyKeyToKeysym(payload.name);
    if (binding === undefined || keysym === undefined || (!payload.down && held === undefined)) {
      this.callbacks.reportInputError('VNC 不支持此按键或按键已退役');
      return false;
    }
    const admitted = this.sendKeysymIfAllowed(keysym, payload.down);
    if (admitted) {
      if (payload.down) {
        this.heldNamedKeySyms.set(payload.name, keysym);
      } else {
        this.heldNamedKeySyms.delete(payload.name);
      }
    } else if (!payload.down) {
      this.retireInput(binding);
    }
    return admitted;
  }

  private keysymHeld(keysym: number): boolean {
    let held = false;
    this.heldKeySyms.forEach((value: number): void => { held = held || value === keysym; });
    this.heldNamedKeySyms.forEach((value: number): void => { held = held || value === keysym; });
    return held;
  }

  private modifierKeysymHeld(keysym: number): boolean {
    return this.keysymHeld(keysym) || this.keysymHeld(keysym + 1);
  }

  private sendVncTap(chord: Array<number>): boolean {
    const binding = this.currentEventBinding();
    if (binding === undefined) {
      return false;
    }
    const main = chord[chord.length - 1];
    if (this.keysymHeld(main)) {
      this.callbacks.reportInputError('请先松开仍按住的按键');
      return false;
    }
    const temporary: number[] = [];
    for (let index = 0; index + 1 < chord.length; index++) {
      const modifier = chord[index];
      if (this.modifierKeysymHeld(modifier)) {
        continue;
      }
      if (!this.sendKeysymIfAllowed(modifier, true)) {
        if (temporary.length > 0) {
          this.retireInput(binding);
        }
        return false;
      }
      temporary.push(modifier);
    }
    if (!this.sendKeysymIfAllowed(main, true)) {
      if (temporary.length > 0) {
        this.retireInput(binding);
      }
      return false;
    }
    if (!this.sendKeysymIfAllowed(main, false)) {
      // Down reached the queue but Up did not: retire once, adopt native's new
      // generation via releaseInput, stop this event and never replay its rest.
      this.retireInput(binding);
      return false;
    }
    for (let index = temporary.length - 1; index >= 0; index--) {
      if (!this.sendKeysymIfAllowed(temporary[index], false)) {
        this.retireInput(binding);
        return false;
      }
    }
    return true;
  }

  private sendTextForCurrentEvent(text: string): boolean {
    const binding = this.currentEventBinding();
    if (binding === undefined || text.length === 0) {
      return false;
    }
    if (!this.callbacks.usesVncKeysym()) {
      const admitted = this.callbacks.sendText(text, binding);
      this.eventRejected = !admitted;
      return admitted;
    }
    for (let index = 0; index < text.length; index++) {
      let codePoint = text.charCodeAt(index);
      if (codePoint >= 0xD800 && codePoint <= 0xDBFF) {
        const low = text.charCodeAt(index + 1);
        if (!(low >= 0xDC00 && low <= 0xDFFF)) {
          this.callbacks.reportInputError('文本含无效 Unicode 字符');
          return false;
        }
        codePoint = 0x10000 + (codePoint - 0xD800) * 0x400 + low - 0xDC00;
        index++;
      }
      const keysym = unicodeKeysym(codePoint);
      if (keysym === undefined) {
        this.callbacks.reportInputError('文本含不支持的 Unicode 字符');
        return false;
      }
      if (!this.sendVncTap([keysym])) {
        return false;
      }
    }
    return true;
  }

  private keyEventTypeName(type: KeyType): string {
    switch (type) {
      case KeyType.Down:
        return 'Down';
      case KeyType.Up:
        return 'Up';
      default:
        return String(type);
    }
  }

  private legacyKeyPayload(name: string, isDown: boolean): RustDeskKeyPayload {
    const payload = new RustDeskKeyPayload(name, isDown);
    payload.alt = this.activeModifiers.has('alt');
    payload.shift = this.activeModifiers.has('shift');
    payload.command = this.activeModifiers.has('command');
    payload.ctrl = this.activeModifiers.has('ctrl');
    if (this.shouldTreatLocalCtrlAsCommand()) {
      payload.command = payload.command || payload.ctrl;
      payload.ctrl = false;
    }
    return payload;
  }

  private shouldTreatLocalCtrlAsCommand(): boolean {
    return this.callbacks.isPeerMacOS();
  }

  private mapLegacyKeyNameForPeer(mapping: RustDeskKeyMapping): string {
    if (!this.shouldTreatLocalCtrlAsCommand() || mapping.modifier !== 'ctrl') {
      return mapping.name;
    }
    return mapping.name === 'RControl' ? 'RWin' : 'Meta';
  }

  handleTouchEvent(event: TouchEvent): void {
    if (!this.beginInputEvent()) {
      return;
    }
    event.stopPropagation();
    const isPointerSource =
      event.sourceTool === SourceTool.MOUSE ||
      event.sourceTool === SourceTool.TOUCHPAD ||
      event.sourceTool === SourceTool.JOYSTICK;
    if (isPointerSource && !this.shouldAcceptPointerTouch(event.type)) {
      return;
    }
    switch (event.type) {
      case TouchType.Down:
        this.handleTouchDown(event);
        return;
      case TouchType.Move:
        this.handleTouchMove(event);
        return;
      case TouchType.Up:
      case TouchType.Cancel:
        this.handleTouchRelease(event);
        return;
      default:
        return;
    }
  }

  /**
   * Decide whether a pointer-sourced touch may use the touch path.
   *
   * A real pointer that is delivered through `onMouse` must not be handled here
   * as well, so a recent mouse event latches this arm closed against the *next*
   * sequence. The latch never decides the fate of a sequence that is already
   * open: a sequence's own Move/Up/Cancel belong to it, and refusing its release
   * would leave the touch state, the mouse mode and the gesture state behind. An
   * injected or synthesized pointer that only ever arrives as a touch event is
   * therefore taken over by the touch path once the latch expires, and drives the
   * desktop from the absolute position it reports.
   */
  private shouldAcceptPointerTouch(type: TouchType): boolean {
    if (type !== TouchType.Down) {
      return this.pointerTouchSequence;
    }
    if (Date.now() < this.pointerTouchLatchUntil) {
      return false;
    }
    this.pointerTouchSequence = true;
    return true;
  }

  /**
   * Ends a pointer-sourced sequence and whatever gesture it was driving.
   *
   * A sequence that is superseded rather than released goes through here, so it
   * cannot leave a forced mouse mode, a touch id or a gesture down behind: the
   * next sequence would otherwise be read as a second finger.
   */
  private abandonPointerTouchSequence(): void {
    this.cancelTouchTimers();
    this.applyTouchActions(this.touchGestureState.reset());
    this.clearTouchPointerState();
  }

  /**
   * A delivered mouse event is proof that the pointer has its own path here, so it
   * claims the pointer: a pointer-sourced sequence that had already opened is
   * abandoned without emitting, and no new one may open until the latch expires.
   * A real finger's own gesture is left alone.
   */
  private claimPointerForMouse(): void {
    this.pointerTouchLatchUntil = Date.now() + RustDeskInputController.POINTER_TOUCH_LATCH_MS;
    if (this.pointerTouchSequence) {
      this.abandonPointerTouchSequence();
    }
  }

  private handleMouseMove(event: MouseEvent): void {
    this.claimPointerForMouse();
    if (this.relativeModeActive) {
      const rawDeltaX = event.rawDeltaX ?? 0;
      const rawDeltaY = event.rawDeltaY ?? 0;
      const hasRawDelta = rawDeltaX !== 0 || rawDeltaY !== 0;
      if (Date.now() < this.relativeSuppressMoveUntil && !hasRawDelta) {
        this.rebaseRelativeMouseAt(event.x, event.y, true);
        return;
      }
      const previousX = this.relativeLastX;
      const previousY = this.relativeLastY;
      const hadPrevious = this.relativeHasLast;
      this.relativeLastX = event.x;
      this.relativeLastY = event.y;
      this.relativeHasLast = true;
      if (!hadPrevious && !hasRawDelta) {
        return;
      }
      const localDeltaX = event.x - previousX;
      const localDeltaY = event.y - previousY;
      if (!hasRawDelta && this.isLikelyRelativeWarp(localDeltaX, localDeltaY)) {
        this.callbacks.log(
          'relative_warp',
          `ignored localDelta=(${localDeltaX.toFixed(1)},${localDeltaY.toFixed(1)}) at=(${event.x.toFixed(1)},${event.y.toFixed(1)})`,
        );
        return;
      }
      const localDelta = this.mapLocalDeltaToRemoteDelta(
        hasRawDelta ? rawDeltaX : localDeltaX,
        hasRawDelta ? rawDeltaY : localDeltaY,
      );
      this.queueRelativeMouseMove(
        localDelta.x * RELATIVE_MOUSE_RAW_SENSITIVITY,
        localDelta.y * RELATIVE_MOUSE_RAW_SENSITIVITY,
      );
      return;
    }
    this.relativeHasLast = false;
    this.moveRemoteCursorToLocalPoint(event.x, event.y);
  }

  private isLikelyRelativeWarp(deltaX: number, deltaY: number): boolean {
    const space = this.callbacks.getCoordinateSpace();
    const threshold = space
      ? Math.max(RELATIVE_MOUSE_WARP_MIN_THRESHOLD, Math.min(space.paintRect.width, space.paintRect.height) * 0.35)
      : RELATIVE_MOUSE_WARP_MIN_THRESHOLD;
    return Math.abs(deltaX) > threshold || Math.abs(deltaY) > threshold;
  }

  private handleMouseButton(event: MouseEvent): void {
    this.claimPointerForMouse();
    const button = mapMouseButton(event.button);
    if (!button) {
      return;
    }
    const isPress = event.action === MouseAction.Press;
    const inside = this.isInsideContent(event.x, event.y);
    if (isPress && !inside) {
      this.callbacks.log('mouse_press_skipped', `outside_content x=${event.x} y=${event.y}`);
      return;
    }
    if (!isPress && !this.pressedButtons.hasOwner(button, 'physical_mouse')) {
      return;
    }
    if (this.relativeModeActive) {
      this.rebaseRelativeMouseAt(event.x, event.y, false);
      this.flushRelativeMouseMove();
      this.relativeSuppressMoveUntil = Date.now() + RELATIVE_MOUSE_BUTTON_SUPPRESS_MS;
      this.transitionMouseButton(button, isPress, 'physical_mouse', false, 'relative');
      return;
    }
    if (inside) {
      this.moveRemoteCursorToLocalPoint(event.x, event.y);
    }
    this.transitionMouseButton(button, isPress, 'physical_mouse');
  }

  private handleTouchDown(event: TouchEvent): void {
    if (this.touchSuppressedIds.size > 0) {
      return;
    }
    const now = Date.now();
    const changedTouches = event.changedTouches;
    for (let index = 0; index < changedTouches.length; index++) {
      const touch = changedTouches[index];
      if (this.touchPrimaryId === -1) {
        if (!this.mouseModeActive && !this.isInsideContent(touch.x, touch.y)) {
          this.callbacks.log('touch_dropped', `outside_content x=${touch.x} y=${touch.y}`);
          continue;
        }
        this.touchPrimaryId = touch.id;
        this.touchLastX = touch.x;
        this.touchLastY = touch.y;
        this.touchSequenceStartedAt = now;
        this.touchPrimaryReleased = false;
        this.touchSecondaryReleased = false;
        this.touchTwoFingerMoved = false;
        this.touchTwoFingerTransformActive = false;
        this.applyTouchActions(this.touchGestureState.onDown(touch.x, touch.y, now, this.interactionMode()));
        this.cancelTouchTapTimeout();
        this.startHoldTimer();
        continue;
      }
      if (this.touchSecondaryId === -1 && touch.id !== this.touchPrimaryId) {
        if (!this.callbacks.gesturesEnabled()) {
          this.cancelTouchTimers();
          this.applyTouchActions(this.touchGestureState.reset());
          this.beginTouchSuppression();
          this.clearTouchPointerState();
          return;
        }
        this.touchSecondaryId = touch.id;
        this.touchSecondaryReleased = false;
        this.touchSecondaryLastX = touch.x;
        this.touchSecondaryLastY = touch.y;
        this.touchTwoFingerMoved = false;
        this.touchTwoFingerTransformActive = false;
        this.cancelTouchTimers();
        this.applyTouchActions(this.touchGestureState.reset());
        this.initializeTwoFingerGesture();
        continue;
      }
      if (this.touchThirdId === -1 && touch.id !== this.touchPrimaryId && touch.id !== this.touchSecondaryId) {
        this.touchThirdId = touch.id;
        this.touchThirdLastX = touch.x;
        this.touchThirdLastY = touch.y;
        this.touchTwoFingerMoved = true;
        this.touchTwoFingerTransformActive = false;
        this.touchThreeFingerScrollIntegral = 0;
        this.cancelTouchTimers();
        this.applyTouchActions(this.touchGestureState.reset());
        this.initializeThreeFingerGesture(event);
      }
    }
  }

  private handleTouchMove(event: TouchEvent): void {
    if (this.touchPrimaryId === -1) {
      return;
    }
    if (this.touchSecondaryId !== -1 && (this.touchPrimaryReleased || this.touchSecondaryReleased)) {
      const remainingTouch = this.touchPrimaryReleased
        ? this.findTouchById(event.touches, this.touchSecondaryId)
        : this.findTouchById(event.touches, this.touchPrimaryId);
      if (remainingTouch) {
        const previousX = this.touchPrimaryReleased ? this.touchSecondaryLastX : this.touchLastX;
        const previousY = this.touchPrimaryReleased ? this.touchSecondaryLastY : this.touchLastY;
        if (this.touchDistance(previousX, previousY, remainingTouch.x, remainingTouch.y)
          >= TOUCH_TRANSFORM_PAN_SLOP) {
          this.touchTwoFingerMoved = true;
        }
      }
      return;
    }
    const primaryTouch = this.findTouchById(event.touches, this.touchPrimaryId);
    if (!primaryTouch) {
      return;
    }
    if (this.touchThirdId !== -1) {
      this.cancelHoldTimer();
      this.handleThreeFingerScroll(event);
      return;
    }
    if (this.touchSecondaryId !== -1) {
      this.cancelHoldTimer();
      this.handleTwoFingerTransform(event);
      return;
    }
    this.applyTouchActions(
      this.touchGestureState.onMove(primaryTouch.x, primaryTouch.y, !this.relativeModeActive),
    );
    if (!this.touchGestureState.isHoldPending()) {
      this.cancelHoldTimer();
    }
    if (this.isTouchpadGesture() || this.relativeModeActive) {
      const deltaX = primaryTouch.x - this.touchLastX;
      const deltaY = primaryTouch.y - this.touchLastY;
      this.touchLastX = primaryTouch.x;
      this.touchLastY = primaryTouch.y;
      if (deltaX !== 0 || deltaY !== 0) {
        const remoteDelta = this.mapLocalDeltaToRemoteDelta(deltaX, deltaY);
        const scaledDeltaX = remoteDelta.x * TOUCHPAD_MOVE_SENSITIVITY;
        const scaledDeltaY = remoteDelta.y * TOUCHPAD_MOVE_SENSITIVITY;
        if (this.relativeModeActive) {
          this.queueRelativeMouseMove(scaledDeltaX, scaledDeltaY);
        } else if (this.advanceVirtualCursorBy(scaledDeltaX, scaledDeltaY)) {
          this.sendVirtualCursorAbsoluteMove();
        }
      }
      return;
    }
    const deltaX = primaryTouch.x - this.touchLastX;
    const deltaY = primaryTouch.y - this.touchLastY;
    this.touchLastX = primaryTouch.x;
    this.touchLastY = primaryTouch.y;
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    this.moveRemoteCursorToLocalPoint(primaryTouch.x, primaryTouch.y);
  }

  private initializeTwoFingerGesture(): void {
    const centerX = (this.touchLastX + this.touchSecondaryLastX) / 2;
    const centerY = (this.touchLastY + this.touchSecondaryLastY) / 2;
    const distance = this.touchDistance(
      this.touchLastX,
      this.touchLastY,
      this.touchSecondaryLastX,
      this.touchSecondaryLastY,
    );
    this.touchTwoFingerInitialCenterX = centerX;
    this.touchTwoFingerInitialCenterY = centerY;
    this.touchTwoFingerLastCenterX = centerX;
    this.touchTwoFingerLastCenterY = centerY;
    this.touchTwoFingerInitialDistance = Math.max(distance, 1);
    this.touchTwoFingerLastDistance = Math.max(distance, 1);
  }

  private handleTwoFingerTransform(event: TouchEvent): void {
    const primaryTouch = this.findTouchById(event.touches, this.touchPrimaryId);
    const secondaryTouch = this.findTouchById(event.touches, this.touchSecondaryId);
    if (!primaryTouch || !secondaryTouch) {
      return;
    }
    const centerX = (primaryTouch.x + secondaryTouch.x) / 2;
    const centerY = (primaryTouch.y + secondaryTouch.y) / 2;
    const distance = Math.max(
      this.touchDistance(primaryTouch.x, primaryTouch.y, secondaryTouch.x, secondaryTouch.y),
      1,
    );
    const initialPanX = centerX - this.touchTwoFingerInitialCenterX;
    const initialPanY = centerY - this.touchTwoFingerInitialCenterY;
    const initialScale = distance / Math.max(this.touchTwoFingerInitialDistance, 1);
    const panDistanceSquared = initialPanX * initialPanX + initialPanY * initialPanY;
    const scaleChanged = Math.abs(initialScale - 1) >= TOUCH_TRANSFORM_SCALE_SLOP;
    if (!this.touchTwoFingerTransformActive) {
      if (panDistanceSquared < TOUCH_TRANSFORM_PAN_SLOP * TOUCH_TRANSFORM_PAN_SLOP && !scaleChanged) {
        return;
      }
      this.touchTwoFingerTransformActive = true;
      this.touchTwoFingerMoved = true;
      this.callbacks.onCanvasTransform(initialScale, initialPanX, initialPanY, centerX, centerY);
    } else {
      const panX = centerX - this.touchTwoFingerLastCenterX;
      const panY = centerY - this.touchTwoFingerLastCenterY;
      const scaleFactor = distance / Math.max(this.touchTwoFingerLastDistance, 1);
      this.callbacks.onCanvasTransform(scaleFactor, panX, panY, centerX, centerY);
    }
    this.touchLastX = primaryTouch.x;
    this.touchLastY = primaryTouch.y;
    this.touchSecondaryLastX = secondaryTouch.x;
    this.touchSecondaryLastY = secondaryTouch.y;
    this.touchTwoFingerLastCenterX = centerX;
    this.touchTwoFingerLastCenterY = centerY;
    this.touchTwoFingerLastDistance = distance;
  }

  private initializeThreeFingerGesture(event: TouchEvent): void {
    const primaryTouch = this.findTouchById(event.touches, this.touchPrimaryId);
    const secondaryTouch = this.findTouchById(event.touches, this.touchSecondaryId);
    const thirdTouch = this.findTouchById(event.touches, this.touchThirdId);
    if (primaryTouch) {
      this.touchLastX = primaryTouch.x;
      this.touchLastY = primaryTouch.y;
    }
    if (secondaryTouch) {
      this.touchSecondaryLastX = secondaryTouch.x;
      this.touchSecondaryLastY = secondaryTouch.y;
    }
    if (thirdTouch) {
      this.touchThirdLastX = thirdTouch.x;
      this.touchThirdLastY = thirdTouch.y;
    }
    this.touchThreeFingerLastCenterY = (
      this.touchLastY + this.touchSecondaryLastY + this.touchThirdLastY
    ) / 3;
  }

  private handleThreeFingerScroll(event: TouchEvent): void {
    const center = this.threeFingerCenter(event.touches);
    if (!center) {
      return;
    }
    const deltaY = center.y - this.touchThreeFingerLastCenterY;
    this.touchThreeFingerLastCenterY = center.y;
    if (this.callbacks.isPeerAndroid()) {
      return;
    }
    this.touchThreeFingerScrollIntegral += deltaY / DEFAULT_TOUCH_SCROLL_DIVISOR;
    if (this.touchThreeFingerScrollIntegral > 1) {
      this.sendTouchWheelStep(1);
      this.touchThreeFingerScrollIntegral = 0;
    } else if (this.touchThreeFingerScrollIntegral < -1) {
      this.sendTouchWheelStep(-1);
      this.touchThreeFingerScrollIntegral = 0;
    }
  }

  private interactionMode(): RustDeskTouchInteractionMode {
    return this.isTouchpadGesture() ? 'mouse' : 'touch';
  }

  /**
   * Whether the open touch gesture is a touchpad drag: its movement is sent as
   * relative deltas and its tap lands on the local virtual cursor.
   *
   * A pointer-sourced sequence is excluded even while mouse mode is on, because
   * the positions it reports are absolute: its tap and drag belong to the point
   * it names, not to the cursor the touchpad would be nudging.
   */
  private isTouchpadGesture(): boolean {
    return this.mouseModeActive && !this.pointerTouchSequence;
  }

  private touchDistance(firstX: number, firstY: number, secondX: number, secondY: number): number {
    const deltaX = secondX - firstX;
    const deltaY = secondY - firstY;
    return Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }

  private threeFingerCenter(touches: Array<TouchObject>): RemotePointerPosition | undefined {
    const primaryTouch = this.findTouchById(touches, this.touchPrimaryId);
    const secondaryTouch = this.findTouchById(touches, this.touchSecondaryId);
    const thirdTouch = this.findTouchById(touches, this.touchThirdId);
    if (!primaryTouch || !secondaryTouch || !thirdTouch) {
      return undefined;
    }
    this.touchLastX = primaryTouch.x;
    this.touchLastY = primaryTouch.y;
    this.touchSecondaryLastX = secondaryTouch.x;
    this.touchSecondaryLastY = secondaryTouch.y;
    this.touchThirdLastX = thirdTouch.x;
    this.touchThirdLastY = thirdTouch.y;
    return {
      x: (primaryTouch.x + secondaryTouch.x + thirdTouch.x) / 3,
      y: (primaryTouch.y + secondaryTouch.y + thirdTouch.y) / 3,
    };
  }

  private sendTouchWheelStep(step: number): void {
    const payload = new RustDeskMousePayload();
    payload.type = 'wheel';
    payload.y = String(step);
    this.sendMouseIfAllowed(payload);
  }

  private beginTouchSuppression(): void {
    this.touchSuppressedIds.clear();
    if (this.touchPrimaryId !== -1) {
      this.touchSuppressedIds.add(this.touchPrimaryId);
    }
    if (this.touchSecondaryId !== -1) {
      this.touchSuppressedIds.add(this.touchSecondaryId);
    }
    if (this.touchThirdId !== -1) {
      this.touchSuppressedIds.add(this.touchThirdId);
    }
  }

  private releaseSuppressedTouches(touches: Array<TouchObject>): void {
    for (let index = 0; index < touches.length; index++) {
      this.touchSuppressedIds.delete(touches[index].id);
    }
  }

  private handleTouchRelease(event: TouchEvent): void {
    if (this.touchSuppressedIds.size > 0) {
      if (event.type === TouchType.Cancel) {
        this.touchSuppressedIds.clear();
      } else {
        this.releaseSuppressedTouches(event.changedTouches);
      }
      if (this.touchSuppressedIds.size === 0) {
        this.clearTouchPointerState();
      }
      return;
    }
    if (event.type === TouchType.Cancel) {
      this.cancelTouchTimers();
      this.applyTouchActions(this.touchGestureState.reset());
      this.clearTouchPointerState();
      return;
    }
    const changedTouches = event.changedTouches;
    let primaryReleased = false;
    let secondaryReleased = false;
    let thirdReleased = false;
    let primaryX = this.touchLastX;
    let primaryY = this.touchLastY;
    for (let index = 0; index < changedTouches.length; index++) {
      const touch = changedTouches[index];
      if (touch.id === this.touchPrimaryId) {
        primaryReleased = true;
        primaryX = touch.x;
        primaryY = touch.y;
      }
      if (touch.id === this.touchSecondaryId) {
        secondaryReleased = true;
      }
      if (touch.id === this.touchThirdId) {
        thirdReleased = true;
      }
    }
    const multiFingerSequence = this.touchSecondaryId !== -1 || this.touchThirdId !== -1
      || secondaryReleased || thirdReleased;
    if (multiFingerSequence) {
      if (this.touchThirdId !== -1 || thirdReleased) {
        this.cancelTouchTimers();
        this.applyTouchActions(this.touchGestureState.reset());
        this.beginTouchSuppression();
        this.releaseSuppressedTouches(changedTouches);
        this.clearTouchPointerState();
        return;
      }
      if (primaryReleased) {
        this.touchPrimaryReleased = true;
      }
      if (secondaryReleased) {
        this.touchSecondaryReleased = true;
      }
      if (event.touches.length === 0) {
        this.touchPrimaryReleased = true;
        this.touchSecondaryReleased = true;
      }
      if (!this.touchPrimaryReleased || !this.touchSecondaryReleased) {
        return;
      }
      const shouldRightClick = this.callbacks.rightClickGesture() === 'two_finger_tap'
        && !this.touchTwoFingerMoved
        && Date.now() - this.touchSequenceStartedAt <= TOUCH_TWO_FINGER_TAP_MAX_MS;
      this.cancelTouchTimers();
      this.applyTouchActions(this.touchGestureState.reset());
      if (shouldRightClick) {
        this.applyTouchClick(primaryX, primaryY, 'right');
      }
      this.clearTouchPointerState();
      return;
    }
    if (primaryReleased) {
      this.cancelHoldTimer();
      this.applyTouchActions(this.touchGestureState.onRelease(primaryX, primaryY, Date.now(), false));
      if (this.pointerTouchSequence) {
        // A synthetic pointer's tap has no second tap of its own to be merged
        // with, so it is resolved here rather than left pending: the click is
        // emitted while this sequence still owns the absolute mapping.
        this.applyTouchActions(this.touchGestureState.resolvePendingTap());
      } else {
        this.syncTouchTapTimeout(Date.now());
      }
      this.clearTouchPointerState();
      return;
    }
    if (event.touches.length === 0) {
      this.cancelTouchTimers();
      this.applyTouchActions(this.touchGestureState.reset());
      this.clearTouchPointerState();
    }
  }

  private startHoldTimer(): void {
    this.cancelHoldTimer();
    const delay = this.touchGestureState.getHoldTimeoutDelay(Date.now());
    if (delay < 0) {
      return;
    }
    const binding = this.currentEventBinding();
    if (binding === undefined) {
      return;
    }
    this.touchLongPressTimer = setTimeout(() => {
      this.touchLongPressTimer = -1;
      if (!this.beginInputEvent(binding)) {
        return;
      }
      const preserveMobileLongPress = this.callbacks.isPeerMobile()
        && this.callbacks.rightClickGesture() !== 'long_press';
      const allowLongPressDrag = this.callbacks.isLocalPhone()
        && this.callbacks.rightClickGesture() !== 'long_press';
      this.applyTouchActions(
        this.touchGestureState.onHold(Date.now(), preserveMobileLongPress, allowLongPressDrag),
      );
    }, delay === 0 ? 1 : delay) as number;
  }

  private syncTouchTapTimeout(at: number): void {
    this.cancelTouchTapTimeout();
    const delay = this.touchGestureState.getTapTimeoutDelay(at);
    if (delay < 0) {
      return;
    }
    const timeoutDelay = delay === 0 ? 1 : delay;
    const binding = this.currentEventBinding();
    if (binding === undefined) {
      return;
    }
    this.touchTapTimeoutTimer = setTimeout(() => {
      this.touchTapTimeoutTimer = -1;
      if (!this.beginInputEvent(binding)) {
        return;
      }
      const timeoutAt = Date.now();
      this.applyTouchActions(this.touchGestureState.onTapTimeout(timeoutAt));
      this.syncTouchTapTimeout(timeoutAt);
    }, timeoutDelay) as number;
  }

  private applyTouchActions(actions: Array<RustDeskTouchAction>): void {
    for (let index = 0; index < actions.length; index++) {
      this.applyTouchAction(actions[index]);
    }
  }

  private applyTouchAction(action: RustDeskTouchAction): void {
    switch (action.type) {
      case 'click_left':
        this.applyTouchClick(action.x, action.y, 'left');
        return;
      case 'click_right':
        if (this.callbacks.rightClickGesture() === 'long_press') {
          this.applyTouchClick(action.x, action.y, 'right');
        }
        return;
      case 'double_click_left':
        if (this.callbacks.rightClickGesture() === 'double_tap') {
          this.applyTouchClick(action.x, action.y, 'right');
        } else {
          this.applyTouchDoubleClick(action.x, action.y);
        }
        return;
      case 'drag_start':
        if (this.isTouchpadGesture()) {
          if (this.relativeModeActive) {
            this.flushRelativeMouseMove();
          } else {
            this.sendVirtualCursorAbsoluteMove();
          }
          this.transitionMouseButton('left', true, 'touch_drag', false);
          return;
        }
        if (this.moveRemoteCursorToLocalPoint(action.x, action.y)) {
          this.transitionMouseButton('left', true, 'touch_drag');
        }
        return;
      case 'drag_end':
        this.transitionMouseButton('left', false, 'touch_drag');
        return;
    }
  }

  private applyTouchClick(localX: number, localY: number, button: string): void {
    if (this.isTouchpadGesture()) {
      if (!this.relativeModeActive) {
        this.sendVirtualCursorAbsoluteMove();
      }
      this.clickCurrentCursor(button);
      return;
    }
    this.moveRemoteCursorAndClick(localX, localY, button);
  }

  private applyTouchDoubleClick(localX: number, localY: number): void {
    if (this.isTouchpadGesture()) {
      if (!this.relativeModeActive) {
        this.sendVirtualCursorAbsoluteMove();
      }
    } else if (!this.moveRemoteCursorToLocalPoint(localX, localY)) {
      return;
    }
    this.sendMouseClick('left');
    this.sendMouseClick('left');
  }

  private moveRemoteCursorAndClick(localX: number, localY: number, button: string): void {
    if (!this.moveRemoteCursorToLocalPoint(localX, localY)) {
      return;
    }
    this.sendMouseClick(button);
  }

  private moveRemoteCursorToLocalPoint(localX: number, localY: number): boolean {
    const space = this.callbacks.getCoordinateSpace();
    if (!space || !isLocalPointInsidePaintRect(space, localX, localY)) {
      this.callbacks.log('cursor_move_skipped', `space=${space !== undefined} x=${localX} y=${localY}`);
      return false;
    }
    const position = mapLocalToRemote(space, localX, localY);
    const payload = new RustDeskMousePayload();
    payload.x = String(position.x);
    payload.y = String(position.y);
    if (!this.sendMouseIfAllowed(payload)) {
      return false;
    }
    this.setVirtualCursorRemote(position.x, position.y);
    return true;
  }

  private sendMouseClick(button: string): void {
    this.transitionMouseButton(button, true, 'touch_click');
    this.transitionMouseButton(button, false, 'touch_click');
  }

  private transitionMouseButton(
    button: string,
    isDown: boolean,
    owner: RustDeskPressedButtonOwner,
    flushPending: boolean = true,
    modeOverride?: RustDeskPointerMode,
  ): void {
    const mode = modeOverride ?? this.getPointerMode();
    const transition = isDown
      ? this.pressedButtons.acquire(button, owner, mode)
      : this.pressedButtons.release(button, owner);
    if (transition === undefined) {
      return;
    }
    this.sendPressedButtonTransition(transition, flushPending);
  }

  releasePressedButtons(): void {
    this.releaseCurrentInput();
  }

  private clickCurrentCursor(button: string): void {
    if (this.relativeModeActive) {
      this.flushRelativeMouseMove();
    }
    this.transitionMouseButton(button, true, 'touch_click', false);
    this.transitionMouseButton(button, false, 'touch_click', false);
  }

  private getPointerMode(): RustDeskPointerMode {
    return this.relativeModeActive ? 'relative' : 'absolute';
  }

  private sendPressedButtonTransition(transition: RustDeskPressedButtonTransition, flushPending: boolean = true): void {
    const binding = this.currentEventBinding();
    if (transition.mode === 'relative' && flushPending) {
      this.flushRelativeMouseMove();
    }
    const payload = new RustDeskMousePayload();
    payload.type = transition.type;
    payload.buttons = transition.button;
    if (!this.sendMouseIfAllowed(payload)) {
      // If Up was refused after an admitted Down, retire the original session;
      // the writer knows which position and holds actually reached its wire.
      if (transition.type === 'up' && binding !== undefined) {
        this.retireInput(binding);
      } else {
        this.discardInputState();
      }
    }
  }

  private queueRelativeMouseMove(deltaX: number, deltaY: number): void {
    if (Math.abs(deltaX) < 0.01 && Math.abs(deltaY) < 0.01) {
      return;
    }
    this.relativePendingX = this.clampRelativeDelta(this.relativePendingX + deltaX);
    this.relativePendingY = this.clampRelativeDelta(this.relativePendingY + deltaY);
    this.scheduleRelativeMouseFlush();
  }

  private scheduleRelativeMouseFlush(): void {
    if (this.relativeFlushTimer !== -1) {
      return;
    }
    const binding = this.currentEventBinding();
    if (binding === undefined) {
      return;
    }
    this.relativeFlushTimer = setTimeout(() => {
      this.relativeFlushTimer = -1;
      if (this.beginInputEvent(binding)) {
        this.flushRelativeMouseMove();
      }
    }, RELATIVE_MOUSE_FLUSH_MS) as number;
  }

  private flushRelativeMouseMove(): void {
    if (this.relativeFlushTimer !== -1) {
      clearTimeout(this.relativeFlushTimer);
      this.relativeFlushTimer = -1;
    }
    const moveX = this.truncateDelta(this.clampRelativeDelta(this.relativePendingX));
    const moveY = this.truncateDelta(this.clampRelativeDelta(this.relativePendingY));
    if (moveX === 0 && moveY === 0) {
      return;
    }
    this.relativePendingX -= moveX;
    this.relativePendingY -= moveY;
    this.advanceVirtualCursorBy(moveX, moveY);
    const payload = new RustDeskMousePayload();
    payload.type = 'move_relative';
    payload.x = String(moveX);
    payload.y = String(moveY);
    this.sendMouseIfAllowed(payload);
    if (Math.abs(this.relativePendingX) >= 1 || Math.abs(this.relativePendingY) >= 1) {
      this.scheduleRelativeMouseFlush();
    }
  }

  private rebaseRelativeMouseAt(localX: number, localY: number, discardPending: boolean): void {
    if (discardPending) {
      this.discardRelativeMouseMove();
    }
    this.relativeLastX = localX;
    this.relativeLastY = localY;
    this.relativeHasLast = true;
  }

  private discardRelativeMouseMove(): void {
    if (this.relativeFlushTimer !== -1) {
      clearTimeout(this.relativeFlushTimer);
      this.relativeFlushTimer = -1;
    }
    this.relativePendingX = 0;
    this.relativePendingY = 0;
  }

  private clearRelativeMouseState(flushPending: boolean): void {
    if (flushPending) {
      this.flushRelativeMouseMove();
    }
    this.discardRelativeMouseMove();
    this.relativeLastX = 0;
    this.relativeLastY = 0;
    this.relativeHasLast = false;
    this.relativeSuppressMoveUntil = 0;
  }

  /**
   * Ends the touch pointer state, and with it any pointer-sourced sequence: every
   * path that finishes a sequence reaches this, so the ownership flag cannot
   * outlive the state it protects.
   */
  private clearTouchPointerState(): void {
    this.pointerTouchSequence = false;
    this.touchPrimaryId = -1;
    this.touchSecondaryId = -1;
    this.touchThirdId = -1;
    this.touchLastX = 0;
    this.touchLastY = 0;
    this.touchSecondaryLastX = 0;
    this.touchSecondaryLastY = 0;
    this.touchThirdLastX = 0;
    this.touchThirdLastY = 0;
    this.touchPrimaryReleased = false;
    this.touchSecondaryReleased = false;
    this.touchSequenceStartedAt = 0;
    this.touchTwoFingerInitialCenterX = 0;
    this.touchTwoFingerInitialCenterY = 0;
    this.touchTwoFingerLastCenterX = 0;
    this.touchTwoFingerLastCenterY = 0;
    this.touchTwoFingerInitialDistance = 0;
    this.touchTwoFingerLastDistance = 0;
    this.touchTwoFingerMoved = false;
    this.touchTwoFingerTransformActive = false;
    this.touchThreeFingerLastCenterY = 0;
    this.touchThreeFingerScrollIntegral = 0;
  }

  private cancelTouchTimers(): void {
    this.cancelHoldTimer();
    this.cancelTouchTapTimeout();
  }

  private cancelHoldTimer(): void {
    if (this.touchLongPressTimer !== -1) {
      clearTimeout(this.touchLongPressTimer);
      this.touchLongPressTimer = -1;
    }
  }

  private cancelTouchTapTimeout(): void {
    if (this.touchTapTimeoutTimer !== -1) {
      clearTimeout(this.touchTapTimeoutTimer);
      this.touchTapTimeoutTimer = -1;
    }
  }

  private findTouchById(touches: Array<TouchObject>, id: number): TouchObject | undefined {
    for (let index = 0; index < touches.length; index++) {
      if (touches[index].id === id) {
        return touches[index];
      }
    }
    return undefined;
  }

  private isInsideContent(localX: number, localY: number): boolean {
    const space = this.callbacks.getCoordinateSpace();
    return !!space && isLocalPointInsidePaintRect(space, localX, localY);
  }

  private clampRelativeDelta(delta: number): number {
    return Math.min(Math.max(delta, -RELATIVE_MOUSE_MAX_DELTA), RELATIVE_MOUSE_MAX_DELTA);
  }

  private truncateDelta(delta: number): number {
    return delta < 0 ? Math.ceil(delta) : Math.floor(delta);
  }

  private normalizeRotation(rotation: number): number {
    const normalized = rotation % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  private mapLocalDeltaToRemoteDelta(deltaX: number, deltaY: number): RemotePointerPosition {
    const space = this.callbacks.getCoordinateSpace();
    if (!space) {
      return { x: deltaX, y: deltaY };
    }
    const baseDelta = mapViewDeltaToBase(space, deltaX, deltaY);
    const baseDeltaX = baseDelta.x;
    const baseDeltaY = baseDelta.y;
    const scaleX = space.remoteRect.width / Math.max(space.paintRect.width, 1);
    const scaleY = space.remoteRect.height / Math.max(space.paintRect.height, 1);
    const scaleXRotated = space.remoteRect.width / Math.max(space.paintRect.height, 1);
    const scaleYRotated = space.remoteRect.height / Math.max(space.paintRect.width, 1);
    switch (this.normalizeRotation(space.rotation)) {
      case 90:
        return { x: baseDeltaY * scaleXRotated, y: -baseDeltaX * scaleYRotated };
      case 180:
        return { x: -baseDeltaX * scaleX, y: -baseDeltaY * scaleY };
      case 270:
        return { x: -baseDeltaY * scaleXRotated, y: baseDeltaX * scaleYRotated };
      default:
        return { x: baseDeltaX * scaleX, y: baseDeltaY * scaleY };
    }
  }

  // ---- Flutter-mobile local virtual cursor ----

  hasVirtualCursor(): boolean {
    return this.virtualCursorValid;
  }

  getVirtualCursorX(): number {
    return this.virtualCursorX;
  }

  getVirtualCursorY(): number {
    return this.virtualCursorY;
  }

  invalidateVirtualCursor(): void {
    this.virtualCursorValid = false;
  }

  // Seed the virtual cursor from an authoritative remote cursor_position, but only
  // before local input has established it (Flutter mobile syncCursorPosition).
  syncVirtualCursorToRemote(remoteX: number, remoteY: number): void {
    if (this.virtualCursorValid) {
      return;
    }
    this.setVirtualCursorRemote(remoteX, remoteY);
  }

  // Place the virtual cursor at the center of the current remote display.
  // Used when a session/preview becomes ready so the cursor is visible at once.
  initVirtualCursorToCenter(): void {
    const space = this.callbacks.getCoordinateSpace();
    if (!space) {
      return;
    }
    const rect = space.remoteRect;
    this.virtualCursorX = rect.left + rect.width / 2;
    this.virtualCursorY = rect.top + rect.height / 2;
    this.virtualCursorValid = true;
    this.callbacks.onVirtualCursorMoved(this.virtualCursorX, this.virtualCursorY);
  }

  // Absolute placement (already in remote coords), clamped to the display.
  private setVirtualCursorRemote(remoteX: number, remoteY: number): void {
    const space = this.callbacks.getCoordinateSpace();
    if (!space) {
      return;
    }
    const rect = space.remoteRect;
    const maxX = rect.left + Math.max(rect.width - 1, 0);
    const maxY = rect.top + Math.max(rect.height - 1, 0);
    this.virtualCursorX = Math.min(Math.max(remoteX, rect.left), maxX);
    this.virtualCursorY = Math.min(Math.max(remoteY, rect.top), maxY);
    this.virtualCursorValid = true;
    this.callbacks.onVirtualCursorMoved(this.virtualCursorX, this.virtualCursorY);
  }

  private sendVirtualCursorAbsoluteMove(): void {
    if (!this.virtualCursorValid) {
      this.initVirtualCursorToCenter();
    }
    if (!this.virtualCursorValid) {
      return;
    }
    const payload = new RustDeskMousePayload();
    payload.x = String(Math.round(this.virtualCursorX));
    payload.y = String(Math.round(this.virtualCursorY));
    this.sendMouseIfAllowed(payload);
  }

  // Move by a remote-space delta, clamped to the display (Flutter's maxCursorCanMove).
  private advanceVirtualCursorBy(deltaX: number, deltaY: number): boolean {
    const space = this.callbacks.getCoordinateSpace();
    if (!space) {
      return false;
    }
    const rect = space.remoteRect;
    const maxX = rect.left + Math.max(rect.width - 1, 0);
    const maxY = rect.top + Math.max(rect.height - 1, 0);
    if (!this.virtualCursorValid) {
      this.virtualCursorX = rect.left + rect.width / 2;
      this.virtualCursorY = rect.top + rect.height / 2;
      this.virtualCursorValid = true;
    }
    this.virtualCursorX = Math.min(Math.max(this.virtualCursorX + deltaX, rect.left), maxX);
    this.virtualCursorY = Math.min(Math.max(this.virtualCursorY + deltaY, rect.top), maxY);
    this.callbacks.onVirtualCursorMoved(this.virtualCursorX, this.virtualCursorY);
    return true;
  }
}
