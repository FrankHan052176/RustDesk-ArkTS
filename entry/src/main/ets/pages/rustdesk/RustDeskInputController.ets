import {
  isLocalPointInsidePaintRect,
  mapHarmonyKeyCodeToUsbHid,
  mapHarmonyKeyCode,
  mapLocalToRemote,
  mapMouseButton,
  mapViewDeltaToBase,
  RemotePointerPosition,
  RustDeskCoordinateSpace,
  RustDeskFlutterKeyPayload,
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
  TOUCH_LONG_PRESS_MS,
} from './RustDeskTouchGestureState';

const TOUCHPAD_MOVE_SENSITIVITY = 1.0;
const TOUCHPAD_SCROLL_SENSITIVITY = 1.6;
const RELATIVE_MOUSE_RAW_SENSITIVITY = 1.0;
const RELATIVE_MOUSE_FLUSH_MS = 16;
const RELATIVE_MOUSE_MAX_DELTA = 10000;
const RELATIVE_MOUSE_BUTTON_SUPPRESS_MS = 120;
const RELATIVE_MOUSE_WARP_MIN_THRESHOLD = 96;
const LOCK_MODE_CAPS = 1 << 1;
const LOCK_MODE_NUM = 1 << 2;
const LOCK_MODE_SCROLL = 1 << 3;

export interface RustDeskInputControllerCallbacks {
  isSessionActive: () => boolean;
  isRelativeMode: () => boolean;
  isPeerMacOS: () => boolean;
  isPeerAndroid: () => boolean;
  twoFingerRightClick: () => boolean;
  getCoordinateSpace: () => RustDeskCoordinateSpace | undefined;
  sendMouse: (payload: RustDeskMousePayload) => void;
  sendFlutterKey: (payload: RustDeskFlutterKeyPayload) => boolean;
  sendKey: (payload: RustDeskKeyPayload) => boolean;
  log: (label: string, payload: string) => void;
  remoteCursorDebugText: () => string;
  overlayCursorDebugText: (label: string) => string;
  // Flutter-mobile local virtual cursor moved to (remoteX, remoteY) in remote coords.
  onVirtualCursorMoved: (remoteX: number, remoteY: number) => void;
}

export class RustDeskInputController {
  private callbacks: RustDeskInputControllerCallbacks;
  private relativeModeActive: boolean;
  private activeModifiers: Set<RustDeskModifierKey> = new Set();
  private interceptedKeysDown: Set<number> = new Set();
  private touchGestureState: RustDeskTouchGestureState = new RustDeskTouchGestureState();
  private touchPrimaryId: number = -1;
  private touchSecondaryId: number = -1;
  private touchLastX: number = 0;
  private touchLastY: number = 0;
  private touchSecondaryLastX: number = 0;
  private touchSecondaryLastY: number = 0;
  private touchTwoFingerDownAt: number = 0;
  private touchTwoFingerMoved: boolean = false;
  private touchTwoFingerTriggered: boolean = false;
  private touchLongPressTimer: number = -1;
  private touchTapTimeoutTimer: number = -1;
  private relativeLastX: number = 0;
  private relativeLastY: number = 0;
  private relativeHasLast: boolean = false;
  private relativePendingX: number = 0;
  private relativePendingY: number = 0;
  private relativeFlushTimer: number = -1;
  private relativeSuppressMoveUntil: number = 0;
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
    this.relativeModeActive = callbacks.isRelativeMode();
  }

  reset(): void {
    this.cancelTouchTimers();
    this.applyTouchActions(this.touchGestureState.reset());
    this.flushRelativeMouseMove();
    this.clearRelativeMouseState(false);
    this.clearTouchPointerState();
    this.releasePressedButtons();
    this.releaseInterceptedKeys();
    this.activeModifiers.clear();
    this.virtualCursorValid = false;
  }

  setRelativeMode(active: boolean): void {
    this.cancelTouchTimers();
    this.applyTouchActions(this.touchGestureState.reset());
    this.clearTouchPointerState();
    this.releasePressedButtons();
    if (this.relativeModeActive) {
      this.flushRelativeMouseMove();
    }
    this.clearRelativeMouseState(false);
    this.relativeModeActive = active;
    this.callbacks.log(
      'mode',
      `touchpad=${active} absoluteVirtualCursor=true ${this.callbacks.overlayCursorDebugText('overlay')} ${this.callbacks.remoteCursorDebugText()}`,
    );
  }

  handleMouseEvent(event: MouseEvent): void {
    if (!this.callbacks.isSessionActive()) {
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
    if (!this.callbacks.isSessionActive()) {
      return;
    }
    const scrollStepValue = event.scrollStep ?? 1;
    const scrollStep = scrollStepValue > 0 ? scrollStepValue : 1;
    const deltaY = Math.round(-event.getVerticalAxisValue() / scrollStep * 8);
    const deltaX = Math.round(-event.getHorizontalAxisValue() / scrollStep * 8);
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    const payload = new RustDeskMousePayload();
    payload.type = event.sourceTool === SourceTool.TOUCHPAD ? 'trackpad' : 'wheel';
    payload.x = String(deltaX);
    payload.y = String(deltaY);
    this.callbacks.sendMouse(payload);
  }

  handleKeyEvent(event: KeyEvent): boolean {
    if (!this.callbacks.isSessionActive()) {
      this.callbacks.log('keyboard_ignored', `inactive keyCode=${event.keyCode} type=${this.keyEventTypeName(event.type)}`);
      return false;
    }
    const isDown = event.type === KeyType.Down;
    const isUp = event.type === KeyType.Up;
    if (!isDown && !isUp) {
      this.callbacks.log('keyboard_ignored', `unsupported_type keyCode=${event.keyCode} type=${this.keyEventTypeName(event.type)}`);
      return false;
    }
    const mapping = mapHarmonyKeyCode(event.keyCode);
    if (!mapping) {
      this.callbacks.log(
        'keyboard_unmapped',
        `keyCode=${event.keyCode} type=${this.keyEventTypeName(event.type)} keyText=${String(event.keyText ?? '')} unicode=${String(event.unicode ?? '')}`,
      );
      return false;
    }
    if (mapping.modifier && isUp) {
      this.activeModifiers.delete(mapping.modifier);
    }
    let sent = false;
    const flutterPayload = this.buildFlutterKeyPayload(event, isDown);
    if (flutterPayload) {
      sent = this.callbacks.sendFlutterKey(flutterPayload);
      this.callbacks.log(
        'keyboard_flutter',
        `sent=${sent} keyCode=${event.keyCode} type=${this.keyEventTypeName(event.type)} name=${mapping.name} usb=${flutterPayload.usb_hid} charLen=${flutterPayload.character.length}`,
      );
    }
    if (!sent) {
      sent = this.sendLegacyKey(mapping, isDown);
      this.callbacks.log(
        'keyboard_legacy',
        `sent=${sent} keyCode=${event.keyCode} type=${this.keyEventTypeName(event.type)} name=${mapping.name}`,
      );
    }
    if (!sent) {
      return false;
    }
    if (mapping.modifier && isDown) {
      this.activeModifiers.add(mapping.modifier);
    }
    event.stopPropagation();
    return true;
  }

  handleInterceptedKeyEvent(keyCode: number, action: number): boolean {
    if (!this.callbacks.isSessionActive()) {
      this.callbacks.log('keyboard_intercepted_ignored', `inactive keyCode=${keyCode} action=${action}`);
      return false;
    }
    const isDown = action === 1;
    const isUp = action === 0 || action === 2;
    if (!isDown && !isUp) {
      this.callbacks.log('keyboard_intercepted_ignored', `unsupported keyCode=${keyCode} action=${action}`);
      return false;
    }
    const mapping = mapHarmonyKeyCode(keyCode);
    if (!mapping) {
      this.callbacks.log('keyboard_intercepted_unmapped', `keyCode=${keyCode} action=${action}`);
      return false;
    }
    if (mapping.modifier && isUp) {
      this.activeModifiers.delete(mapping.modifier);
    }
    let sent = false;
    const usbHid = mapHarmonyKeyCodeToUsbHid(keyCode);
    if (usbHid !== undefined) {
      const flutterPayload = new RustDeskFlutterKeyPayload('', this.mapUsbHidForPeer(usbHid), 0, isDown);
      sent = this.callbacks.sendFlutterKey(flutterPayload);
      this.callbacks.log(
        'keyboard_intercepted_flutter',
        `sent=${sent} keyCode=${keyCode} action=${action} name=${mapping.name} usb=${flutterPayload.usb_hid}`,
      );
    }
    if (!sent) {
      sent = this.sendLegacyKey(mapping, isDown);
      this.callbacks.log(
        'keyboard_intercepted_legacy',
        `sent=${sent} keyCode=${keyCode} action=${action} name=${mapping.name}`,
      );
    }
    if (sent) {
      if (isDown) {
        this.interceptedKeysDown.add(keyCode);
      } else {
        this.interceptedKeysDown.delete(keyCode);
      }
      if (mapping.modifier && isDown) {
        this.activeModifiers.add(mapping.modifier);
      }
    }
    return sent;
  }

  releaseInterceptedKeys(): void {
    if (this.interceptedKeysDown.size === 0) {
      return;
    }
    const keyCodes: number[] = [];
    this.interceptedKeysDown.forEach((keyCode: number) => keyCodes.push(keyCode));
    for (let index = 0; index < keyCodes.length; index++) {
      this.handleInterceptedKeyEvent(keyCodes[index], 2);
    }
    this.interceptedKeysDown.clear();
    this.activeModifiers.clear();
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

  private sendLegacyKey(mapping: RustDeskKeyMapping, isDown: boolean): boolean {
    const payload = new RustDeskKeyPayload(this.mapLegacyKeyNameForPeer(mapping), isDown);
    payload.alt = this.activeModifiers.has('alt');
    payload.shift = this.activeModifiers.has('shift');
    payload.command = this.activeModifiers.has('command');
    payload.ctrl = this.activeModifiers.has('ctrl');
    if (this.shouldTreatLocalCtrlAsCommand()) {
      payload.command = payload.command || payload.ctrl;
      payload.ctrl = false;
    }
    return this.callbacks.sendKey(payload);
  }

  private buildFlutterKeyPayload(event: KeyEvent, isDown: boolean): RustDeskFlutterKeyPayload | undefined {
    const usbHid = mapHarmonyKeyCodeToUsbHid(event.keyCode);
    if (usbHid === undefined) {
      return undefined;
    }
    return new RustDeskFlutterKeyPayload(
      this.resolveKeyCharacter(event, isDown),
      this.mapUsbHidForPeer(usbHid),
      this.buildLockModes(event),
      isDown,
    );
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

  private mapUsbHidForPeer(usbHid: number): number {
    if (!this.shouldTreatLocalCtrlAsCommand()) {
      return usbHid;
    }
    if (usbHid === 0xE0) {
      return 0xE3;
    }
    if (usbHid === 0xE4) {
      return 0xE7;
    }
    return usbHid;
  }

  private buildLockModes(event: KeyEvent): number {
    let lockModes = 0;
    if (event.isCapsLockOn === true) {
      lockModes |= LOCK_MODE_CAPS;
    }
    if (event.isNumLockOn === true) {
      lockModes |= LOCK_MODE_NUM;
    }
    if (event.isScrollLockOn === true) {
      lockModes |= LOCK_MODE_SCROLL;
    }
    return lockModes;
  }

  private resolveKeyCharacter(event: KeyEvent, isDown: boolean): string {
    if (!isDown) {
      return '';
    }
    const unicode = event.unicode;
    if (unicode !== undefined && this.isPrintableUnicode(unicode)) {
      return this.unicodeToString(unicode);
    }
    const keyText = event.keyText ?? '';
    return this.isPrintableText(keyText) ? keyText : '';
  }

  private isPrintableUnicode(value: number): boolean {
    return value >= 0x20 && value !== 0x7F && value <= 0x10FFFF;
  }

  private unicodeToString(value: number): string {
    if (value <= 0xFFFF) {
      return String.fromCharCode(value);
    }
    const shifted = value - 0x10000;
    return String.fromCharCode(0xD800 + (shifted >> 10), 0xDC00 + (shifted & 0x3FF));
  }

  private isPrintableText(value: string): boolean {
    if (value.length === 0 || value.length > 2) {
      return false;
    }
    for (let index = 0; index < value.length; index++) {
      const code = value.charCodeAt(index);
      if (code < 0x20 || code === 0x7F) {
        return false;
      }
    }
    return true;
  }

  handleTouchEvent(event: TouchEvent): void {
    if (!this.callbacks.isSessionActive()) {
      return;
    }
    event.stopPropagation();
    if (event.sourceTool === SourceTool.MOUSE || event.sourceTool === SourceTool.TOUCHPAD || event.sourceTool === SourceTool.JOYSTICK) {
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

  private handleMouseMove(event: MouseEvent): void {
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
    const button = mapMouseButton(event.button);
    if (!button) {
      return;
    }
    const isPress = event.action === MouseAction.Press;
    const inside = this.isInsideContent(event.x, event.y);
    if (isPress && !inside) {
      return;
    }
    if (!isPress && !this.pressedButtons.hasOwner(button, 'physical_mouse')) {
      return;
    }
    if (this.relativeModeActive) {
      this.rebaseRelativeMouseAt(event.x, event.y, false);
      if (isPress) {
        this.discardRelativeMouseMove();
      } else {
        this.flushRelativeMouseMove();
      }
      this.relativeSuppressMoveUntil = Date.now() + RELATIVE_MOUSE_BUTTON_SUPPRESS_MS;
      this.transitionMouseButton(button, isPress, 'physical_mouse', false);
      return;
    }
    if (inside) {
      this.moveRemoteCursorToLocalPoint(event.x, event.y);
    }
    this.transitionMouseButton(button, isPress, 'physical_mouse');
  }

  private handleTouchDown(event: TouchEvent): void {
    const twoFingerRightClick = this.callbacks.twoFingerRightClick();
    this.touchGestureState.setTwoFingerRightClick(twoFingerRightClick);
    const changedTouches = event.changedTouches;
    for (let index = 0; index < changedTouches.length; index++) {
      const touch = changedTouches[index];
      if (this.touchPrimaryId === -1) {
        if (!this.relativeModeActive && !this.isInsideContent(touch.x, touch.y)) {
          continue;
        }
        if (this.relativeModeActive) {
          this.discardRelativeMouseMove();
        }
        this.touchPrimaryId = touch.id;
        this.touchLastX = touch.x;
        this.touchLastY = touch.y;
        this.touchTwoFingerDownAt = 0;
        this.touchTwoFingerMoved = false;
        this.touchTwoFingerTriggered = false;
        this.applyTouchActions(this.touchGestureState.onDown(touch.x, touch.y, Date.now()));
        this.startLongPressTimer();
        continue;
      }
      if (this.touchSecondaryId === -1 && touch.id !== this.touchPrimaryId) {
        this.touchSecondaryId = touch.id;
        this.touchSecondaryLastX = touch.x;
        this.touchSecondaryLastY = touch.y;
        this.touchTwoFingerDownAt = Date.now();
        this.touchTwoFingerMoved = false;
        this.touchTwoFingerTriggered = false;
        this.cancelTouchTimers();
        this.applyTouchActions(this.touchGestureState.reset());
      }
    }
  }

  private handleTouchMove(event: TouchEvent): void {
    if (this.touchPrimaryId === -1) {
      return;
    }
    const primaryTouch = this.findTouchById(event.touches, this.touchPrimaryId);
    if (!primaryTouch) {
      return;
    }
    if (this.relativeModeActive) {
      this.touchGestureState.onMove(primaryTouch.x, primaryTouch.y);
      if (!this.touchGestureState.isLongPressPending()) {
        this.cancelLongPressTimer();
      }
      if (this.touchSecondaryId !== -1) {
        this.cancelLongPressTimer();
        this.handleTwoFingerScroll(event);
        return;
      }
      const deltaX = primaryTouch.x - this.touchLastX;
      const deltaY = primaryTouch.y - this.touchLastY;
      this.touchLastX = primaryTouch.x;
      this.touchLastY = primaryTouch.y;
      if (deltaX !== 0 || deltaY !== 0) {
        const remoteDelta = this.mapLocalDeltaToRemoteDelta(deltaX, deltaY);
        this.queueRelativeMouseMove(remoteDelta.x * TOUCHPAD_MOVE_SENSITIVITY, remoteDelta.y * TOUCHPAD_MOVE_SENSITIVITY);
      }
      return;
    }
    const isAndroidPeer: boolean = this.callbacks.isPeerAndroid();
    this.applyTouchActions(this.touchGestureState.onMove(primaryTouch.x, primaryTouch.y, isAndroidPeer));
    if (!this.touchGestureState.isLongPressPending()) {
      this.cancelLongPressTimer();
    }
    if (this.touchSecondaryId !== -1) {
      this.handleTwoFingerScroll(event);
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

  private handleTwoFingerScroll(event: TouchEvent): void {
    const primaryTouch = this.findTouchById(event.touches, this.touchPrimaryId);
    const secondaryTouch = this.findTouchById(event.touches, this.touchSecondaryId);
    if (!primaryTouch || !secondaryTouch) {
      return;
    }
    const deltaX = ((primaryTouch.x - this.touchLastX) + (secondaryTouch.x - this.touchSecondaryLastX)) / 2;
    const deltaY = ((primaryTouch.y - this.touchLastY) + (secondaryTouch.y - this.touchSecondaryLastY)) / 2;
    this.touchLastX = primaryTouch.x;
    this.touchLastY = primaryTouch.y;
    this.touchSecondaryLastX = secondaryTouch.x;
    this.touchSecondaryLastY = secondaryTouch.y;
    const x = Math.round(-deltaX * TOUCHPAD_SCROLL_SENSITIVITY);
    const y = Math.round(-deltaY * TOUCHPAD_SCROLL_SENSITIVITY);
    if (x === 0 && y === 0) {
      return;
    }
    const payload = new RustDeskMousePayload();
    payload.type = 'trackpad';
    payload.x = String(x);
    payload.y = String(y);
    this.callbacks.sendMouse(payload);
  }

  private handleTouchRelease(event: TouchEvent): void {
    const changedTouches = event.changedTouches;
    let primaryReleased = false;
    let secondaryReleased = false;
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
    }
    const isTwoFinger = this.touchSecondaryId !== -1 || secondaryReleased;
    if (isTwoFinger && this.callbacks.twoFingerRightClick() && !this.touchTwoFingerMoved
      && this.touchTwoFingerDownAt > 0 && Date.now() - this.touchTwoFingerDownAt <= 350
      && !this.touchTwoFingerTriggered) {
      this.touchTwoFingerTriggered = true;
      if (this.relativeModeActive) {
        this.clickCurrentCursor('right');
      } else {
        this.applyTouchClick(primaryX, primaryY, 'right');
      }
      this.cancelTouchTimers();
      this.applyTouchActions(this.touchGestureState.reset());
      this.clearTouchPointerState();
      return;
    }
    if (primaryReleased) {
      const cancelled = event.type === TouchType.Cancel;
      this.cancelLongPressTimer();
      if (!this.touchTwoFingerTriggered) {
        this.applyTouchActions(this.touchGestureState.onRelease(primaryX, primaryY, Date.now(), cancelled));
      }
      if (cancelled) {
        this.cancelTouchTapTimeout();
        this.applyTouchActions(this.touchGestureState.reset());
      } else if (!this.callbacks.twoFingerRightClick()) {
        this.syncTouchTapTimeout(Date.now());
      }
      this.clearTouchPointerState();
      return;
    }
    if (secondaryReleased) {
      if (this.callbacks.twoFingerRightClick() && !this.touchTwoFingerMoved
        && this.touchTwoFingerDownAt > 0 && Date.now() - this.touchTwoFingerDownAt <= 350
        && !this.touchTwoFingerTriggered) {
        this.touchTwoFingerTriggered = true;
        if (this.relativeModeActive) {
          this.clickCurrentCursor('right');
        } else {
          this.applyTouchClick(primaryX, primaryY, 'right');
        }
        this.cancelTouchTimers();
        this.applyTouchActions(this.touchGestureState.reset());
        this.clearTouchPointerState();
        return;
      }
      this.touchSecondaryId = -1;
      this.touchSecondaryLastX = 0;
      this.touchSecondaryLastY = 0;
    }
    if (event.type === TouchType.Cancel || event.touches.length === 0) {
      this.cancelTouchTimers();
      this.applyTouchActions(this.touchGestureState.reset());
      this.clearTouchPointerState();
    }
  }

  private startLongPressTimer(): void {
    this.cancelLongPressTimer();
    this.touchLongPressTimer = setTimeout(() => {
      this.touchLongPressTimer = -1;
      this.applyTouchActions(this.touchGestureState.onLongPress(Date.now()));
    }, TOUCH_LONG_PRESS_MS) as number;
  }

  private syncTouchTapTimeout(at: number): void {
    this.cancelTouchTapTimeout();
    const delay = this.touchGestureState.getTapTimeoutDelay(at);
    if (delay < 0) {
      return;
    }
    const timeoutDelay = delay === 0 ? 1 : delay;
    this.touchTapTimeoutTimer = setTimeout(() => {
      this.touchTapTimeoutTimer = -1;
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
        this.applyTouchClick(action.x, action.y, 'right');
        return;
      case 'drag_start':
        if (this.relativeModeActive) {
          this.discardRelativeMouseMove();
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
    if (this.relativeModeActive) {
      this.discardRelativeMouseMove();
      this.clickCurrentCursor(button);
      return;
    }
    this.moveRemoteCursorAndClick(localX, localY, button);
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
      return false;
    }
    const position = mapLocalToRemote(space, localX, localY);
    const payload = new RustDeskMousePayload();
    payload.x = String(position.x);
    payload.y = String(position.y);
    this.callbacks.sendMouse(payload);
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
  ): void {
    const mode = this.getPointerMode();
    const transition = isDown
      ? this.pressedButtons.acquire(button, owner, mode)
      : this.pressedButtons.release(button, owner);
    if (transition === undefined) {
      return;
    }
    this.sendPressedButtonTransition(transition, flushPending);
  }

  releasePressedButtons(): void {
    const transitions = this.pressedButtons.releaseAll();
    for (let index = 0; index < transitions.length; index++) {
      this.sendPressedButtonTransition(transitions[index]);
    }
  }

  private clickCurrentCursor(button: string): void {
    this.transitionMouseButton(button, true, 'touch_click', false);
    this.transitionMouseButton(button, false, 'touch_click', false);
  }

  private getPointerMode(): RustDeskPointerMode {
    return this.relativeModeActive ? 'relative' : 'absolute';
  }

  private sendPressedButtonTransition(transition: RustDeskPressedButtonTransition, flushPending: boolean = true): void {
    if (transition.mode === 'relative') {
      this.sendRelativeMouseButton(transition.button, transition.type === 'down', flushPending);
      return;
    }
    this.sendAbsoluteMouseButton(transition.button, transition.type === 'down');
  }

  private sendAbsoluteMouseButton(button: string, isDown: boolean): void {
    const payload = new RustDeskMousePayload();
    payload.type = isDown ? 'down' : 'up';
    payload.buttons = button;
    this.callbacks.sendMouse(payload);
  }

  private sendRelativeMouseButton(button: string, isDown: boolean, flushPending: boolean = true): void {
    if (flushPending) {
      this.flushRelativeMouseMove();
    }
    this.sendVirtualCursorAbsoluteMove();
    const payload = new RustDeskMousePayload();
    payload.type = isDown ? 'down' : 'up';
    payload.buttons = button;
    this.callbacks.sendMouse(payload);
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
    this.relativeFlushTimer = setTimeout(() => {
      this.relativeFlushTimer = -1;
      this.flushRelativeMouseMove();
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
    if (this.advanceVirtualCursorBy(moveX, moveY)) {
      this.sendVirtualCursorAbsoluteMove();
    }
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

  private clearTouchPointerState(): void {
    this.touchPrimaryId = -1;
    this.touchSecondaryId = -1;
    this.touchLastX = 0;
    this.touchLastY = 0;
    this.touchSecondaryLastX = 0;
    this.touchSecondaryLastY = 0;
  }

  private cancelTouchTimers(): void {
    this.cancelLongPressTimer();
    this.cancelTouchTapTimeout();
  }

  private cancelLongPressTimer(): void {
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
    this.callbacks.sendMouse(payload);
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
