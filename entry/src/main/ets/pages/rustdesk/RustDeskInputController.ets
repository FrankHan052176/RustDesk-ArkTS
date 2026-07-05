import {
  isLocalPointInsidePaintRect,
  mapHarmonyKeyCodeToUsbHid,
  mapHarmonyKeyCode,
  mapLocalToRemote,
  mapMouseButton,
  RemotePointerPosition,
  RustDeskCoordinateSpace,
  RustDeskFlutterKeyPayload,
  RustDeskKeyPayload,
  RustDeskKeyMapping,
  RustDeskModifierKey,
  RustDeskMousePayload,
} from './RustDeskInputMapper';

const TOUCH_TAP_MAX_MS = 220;
const TOUCH_TAP_MAX_DISTANCE = 18;
const TOUCH_LONG_PRESS_MS = 550;
const TOUCH_DOUBLE_TAP_MAX_MS = 260;
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
  private activeModifiers: Set<RustDeskModifierKey> = new Set();
  private touchPrimaryId: number = -1;
  private touchSecondaryId: number = -1;
  private touchDownX: number = 0;
  private touchDownY: number = 0;
  private touchLastX: number = 0;
  private touchLastY: number = 0;
  private touchDownAt: number = 0;
  private touchSecondaryLastX: number = 0;
  private touchSecondaryLastY: number = 0;
  private touchMoved: boolean = false;
  private touchLongPressTriggered: boolean = false;
  private touchLongPressTimer: number = -1;
  private touchDragActive: boolean = false;
  private pendingSingleTapTimer: number = -1;
  private lastTapAt: number = 0;
  private relativeLastX: number = 0;
  private relativeLastY: number = 0;
  private relativeHasLast: boolean = false;
  private relativePendingX: number = 0;
  private relativePendingY: number = 0;
  private relativeFlushTimer: number = -1;
  private relativeSuppressMoveUntil: number = 0;
  private mouseButtonsDown: Set<string> = new Set();
  // Flutter-mobile style local virtual cursor, in REMOTE coordinates.
  // This is the single source of truth for the cursor overlay position, so a
  // Mac/Windows peer (whose cursor is never embedded in the video and whose
  // cursor_position is echo-excluded for our own moves) still shows a cursor.
  private virtualCursorX: number = 0;
  private virtualCursorY: number = 0;
  private virtualCursorValid: boolean = false;

  constructor(callbacks: RustDeskInputControllerCallbacks) {
    this.callbacks = callbacks;
  }

  reset(): void {
    this.flushRelativeMouseMove();
    this.clearRelativeMouseState(false);
    this.resetTouchState();
    this.mouseButtonsDown.clear();
    this.activeModifiers.clear();
    this.lastTapAt = 0;
    this.virtualCursorValid = false;
  }

  setRelativeMode(active: boolean): void {
    if (!active) {
      this.flushRelativeMouseMove();
    }
    this.clearRelativeMouseState(false);
    this.cancelPendingSingleTap();
    this.touchDragActive = false;
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
    if (this.callbacks.isRelativeMode()) {
      if (Date.now() < this.relativeSuppressMoveUntil) {
        this.rebaseRelativeMouseAt(event.x, event.y, true);
        return;
      }
      const previousX = this.relativeLastX;
      const previousY = this.relativeLastY;
      const hadPrevious = this.relativeHasLast;
      this.relativeLastX = event.x;
      this.relativeLastY = event.y;
      this.relativeHasLast = true;
      if (!hadPrevious) {
        return;
      }
      const rawDeltaX = event.rawDeltaX ?? 0;
      const rawDeltaY = event.rawDeltaY ?? 0;
      const hasRawDelta = rawDeltaX !== 0 || rawDeltaY !== 0;
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
    if (this.callbacks.isRelativeMode()) {
      if (isPress && !inside) {
        return;
      }
      if (!isPress && !this.mouseButtonsDown.has(button) && !inside) {
        return;
      }
      this.rebaseRelativeMouseAt(event.x, event.y, false);
      if (isPress) {
        this.discardRelativeMouseMove();
        this.mouseButtonsDown.add(button);
      } else {
        this.flushRelativeMouseMove();
      }
      this.relativeSuppressMoveUntil = Date.now() + RELATIVE_MOUSE_BUTTON_SUPPRESS_MS;
      this.sendRelativeMouseButton(button, isPress, false);
      if (!isPress) {
        this.mouseButtonsDown.delete(button);
      }
      return;
    }
    if (isPress && !inside) {
      return;
    }
    if (inside) {
      this.moveRemoteCursorToLocalPoint(event.x, event.y);
    }
    if (isPress) {
      this.mouseButtonsDown.add(button);
    } else if (!this.mouseButtonsDown.has(button) && !inside) {
      return;
    }
    const payload = new RustDeskMousePayload();
    payload.type = isPress ? 'down' : 'up';
    payload.buttons = button;
    this.callbacks.sendMouse(payload);
    if (!isPress) {
      this.mouseButtonsDown.delete(button);
    }
  }

  private handleTouchDown(event: TouchEvent): void {
    const changedTouches = event.changedTouches;
    for (let index = 0; index < changedTouches.length; index++) {
      const touch = changedTouches[index];
      if (this.touchPrimaryId === -1) {
        if (!this.callbacks.isRelativeMode() && !this.isInsideContent(touch.x, touch.y)) {
          continue;
        }
        if (this.callbacks.isRelativeMode()) {
          this.discardRelativeMouseMove();
        }
        this.touchPrimaryId = touch.id;
        this.touchDownX = touch.x;
        this.touchDownY = touch.y;
        this.touchLastX = touch.x;
        this.touchLastY = touch.y;
        this.touchDownAt = Date.now();
        this.touchMoved = false;
        this.touchLongPressTriggered = false;
        this.startLongPressTimer();
        continue;
      }
      if (this.touchSecondaryId === -1 && touch.id !== this.touchPrimaryId) {
        this.touchSecondaryId = touch.id;
        this.touchSecondaryLastX = touch.x;
        this.touchSecondaryLastY = touch.y;
        this.touchMoved = true;
        this.cancelLongPressTimer();
      }
    }
  }

  private handleTouchMove(event: TouchEvent): void {
    if (this.touchPrimaryId === -1) {
      return;
    }
    if (this.touchSecondaryId !== -1) {
      this.handleTwoFingerScroll(event);
      return;
    }
    const primaryTouch = this.findTouchById(event.touches, this.touchPrimaryId);
    if (!primaryTouch) {
      return;
    }
    const movedX = primaryTouch.x - this.touchDownX;
    const movedY = primaryTouch.y - this.touchDownY;
    const movedDistance = Math.sqrt(movedX * movedX + movedY * movedY);
    if (!this.touchMoved && movedDistance > TOUCH_TAP_MAX_DISTANCE) {
      this.touchMoved = true;
      this.cancelLongPressTimer();
    }
    const deltaX = primaryTouch.x - this.touchLastX;
    const deltaY = primaryTouch.y - this.touchLastY;
    this.touchLastX = primaryTouch.x;
    this.touchLastY = primaryTouch.y;
    if (deltaX === 0 && deltaY === 0) {
      return;
    }
    if (this.callbacks.isRelativeMode()) {
      const remoteDelta = this.mapLocalDeltaToRemoteDelta(deltaX, deltaY);
      this.queueRelativeMouseMove(remoteDelta.x * TOUCHPAD_MOVE_SENSITIVITY, remoteDelta.y * TOUCHPAD_MOVE_SENSITIVITY);
      return;
    }
    if (this.touchMoved) {
      this.moveRemoteCursorToLocalPoint(primaryTouch.x, primaryTouch.y);
    }
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
    this.cancelLongPressTimer();
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
    for (let index = 0; index < changedTouches.length; index++) {
      const touch = changedTouches[index];
      if (touch.id === this.touchPrimaryId) {
        primaryReleased = true;
      }
      if (touch.id === this.touchSecondaryId) {
        secondaryReleased = true;
      }
    }
    if (secondaryReleased) {
      this.touchSecondaryId = -1;
      this.touchSecondaryLastX = 0;
      this.touchSecondaryLastY = 0;
    }
    if (primaryReleased) {
      const elapsed = Date.now() - this.touchDownAt;
      if (this.callbacks.isRelativeMode() && this.touchDragActive) {
        this.sendRelativeMouseButton('left', false);
        this.resetTouchState();
        return;
      }
      if (!this.touchMoved && !this.touchLongPressTriggered && elapsed <= TOUCH_TAP_MAX_MS) {
        if (this.callbacks.isRelativeMode()) {
          this.handleRelativeTap();
        } else {
          this.moveRemoteCursorAndClick(this.touchDownX, this.touchDownY, 'left');
        }
      }
      this.resetTouchState();
      return;
    }
    if (event.type === TouchType.Cancel || event.touches.length === 0) {
      if (this.callbacks.isRelativeMode()) {
        this.discardRelativeMouseMove();
      }
      this.resetTouchState();
    }
  }

  private handleRelativeTap(): void {
    this.discardRelativeMouseMove();
    const isDoubleTap = this.lastTapAt > 0 && Date.now() - this.lastTapAt <= TOUCH_DOUBLE_TAP_MAX_MS;
    if (isDoubleTap) {
      this.cancelPendingSingleTap();
      this.lastTapAt = 0;
      this.clickCurrentCursor('right');
      return;
    }
    this.lastTapAt = Date.now();
    this.cancelPendingSingleTap();
    this.pendingSingleTapTimer = setTimeout(() => {
      this.pendingSingleTapTimer = -1;
      this.discardRelativeMouseMove();
      this.clickCurrentCursor('left');
    }, TOUCH_DOUBLE_TAP_MAX_MS) as number;
  }

  private startLongPressTimer(): void {
    this.cancelLongPressTimer();
    this.touchLongPressTimer = setTimeout(() => {
      this.touchLongPressTimer = -1;
      if (this.touchPrimaryId === -1 || this.touchSecondaryId !== -1 || this.touchMoved) {
        return;
      }
      this.touchLongPressTriggered = true;
      if (this.callbacks.isRelativeMode()) {
        this.discardRelativeMouseMove();
        this.touchDragActive = true;
        this.sendRelativeMouseButton('left', true, false);
      } else {
        this.moveRemoteCursorAndClick(this.touchDownX, this.touchDownY, 'right');
      }
    }, TOUCH_LONG_PRESS_MS) as number;
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
    const downPayload = new RustDeskMousePayload();
    downPayload.type = 'down';
    downPayload.buttons = button;
    this.callbacks.sendMouse(downPayload);
    const upPayload = new RustDeskMousePayload();
    upPayload.type = 'up';
    upPayload.buttons = button;
    this.callbacks.sendMouse(upPayload);
  }

  private clickCurrentCursor(button: string): void {
    this.sendRelativeMouseButton(button, true, false);
    this.sendRelativeMouseButton(button, false, false);
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

  private resetTouchState(): void {
    this.cancelLongPressTimer();
    this.touchPrimaryId = -1;
    this.touchSecondaryId = -1;
    this.touchDownX = 0;
    this.touchDownY = 0;
    this.touchLastX = 0;
    this.touchLastY = 0;
    this.touchDownAt = 0;
    this.touchSecondaryLastX = 0;
    this.touchSecondaryLastY = 0;
    this.touchMoved = false;
    this.touchLongPressTriggered = false;
    this.touchDragActive = false;
  }

  private cancelLongPressTimer(): void {
    if (this.touchLongPressTimer !== -1) {
      clearTimeout(this.touchLongPressTimer);
      this.touchLongPressTimer = -1;
    }
  }

  private cancelPendingSingleTap(): void {
    if (this.pendingSingleTapTimer !== -1) {
      clearTimeout(this.pendingSingleTapTimer);
      this.pendingSingleTapTimer = -1;
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
    const scaleX = space.remoteRect.width / Math.max(space.paintRect.width, 1);
    const scaleY = space.remoteRect.height / Math.max(space.paintRect.height, 1);
    const scaleXRotated = space.remoteRect.width / Math.max(space.paintRect.height, 1);
    const scaleYRotated = space.remoteRect.height / Math.max(space.paintRect.width, 1);
    switch (this.normalizeRotation(space.rotation)) {
      case 90:
        return { x: deltaY * scaleXRotated, y: -deltaX * scaleYRotated };
      case 180:
        return { x: -deltaX * scaleX, y: -deltaY * scaleY };
      case 270:
        return { x: -deltaY * scaleXRotated, y: deltaX * scaleYRotated };
      default:
        return { x: deltaX * scaleX, y: deltaY * scaleY };
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
