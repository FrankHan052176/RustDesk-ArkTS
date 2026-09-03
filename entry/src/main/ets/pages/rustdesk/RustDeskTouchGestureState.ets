export type RustDeskTouchInteractionMode = 'touch' | 'mouse';

export type RustDeskTouchActionType =
  'click_left'
  | 'double_click_left'
  | 'click_right'
  | 'drag_start'
  | 'drag_end';

export interface RustDeskTouchAction {
  type: RustDeskTouchActionType;
  x: number;
  y: number;
}

export const TOUCH_TAP_MAX_MS: number = 220;
export const TOUCH_TAP_MAX_DISTANCE: number = 18;
export const TOUCH_LONG_PRESS_MS: number = 500;
export const TOUCH_LONG_PRESS_MAX_DISTANCE: number = 5;
export const TOUCH_DOUBLE_TAP_MAX_MS: number = 300;
// Flutter's between-tap kDoubleTapSlop is wider than its 18 px per-tap movement slop.
export const TOUCH_DOUBLE_TAP_SLOP: number = 100;
export const TOUCH_TWO_FINGER_TAP_MAX_MS: number = 350;
export const TOUCH_TRANSFORM_PAN_SLOP: number = 8;
export const TOUCH_TRANSFORM_SCALE_SLOP: number = 0.02;
export const TOUCH_THREE_FINGER_SCROLL_DIVISOR: number = 4;

/**
 * Flutter-mobile compatible one-finger gesture state.
 *
 * Multi-finger canvas and wheel gestures are coordinated by RustDeskInputController,
 * while this class owns tap/double-tap/long-press and drag disambiguation.
 */
export class RustDeskTouchGestureState {
  private mode: RustDeskTouchInteractionMode = 'touch';
  private downActive: boolean = false;
  private downX: number = 0;
  private downY: number = 0;
  private lastX: number = 0;
  private lastY: number = 0;
  private downAt: number = 0;
  private movedBeyondTapDistance: boolean = false;
  private holdCancelledByMovement: boolean = false;
  private dragActive: boolean = false;
  private holdConsumed: boolean = false;
  private longPressDragArmed: boolean = false;
  private secondTapDown: boolean = false;

  private pendingTap: boolean = false;
  private pendingTapX: number = 0;
  private pendingTapY: number = 0;
  private pendingTapDownX: number = 0;
  private pendingTapDownY: number = 0;
  private pendingTapAt: number = 0;

  onDown(
    x: number,
    y: number,
    at: number,
    mode: RustDeskTouchInteractionMode,
  ): Array<RustDeskTouchAction> {
    const actions: Array<RustDeskTouchAction> = [];
    if (this.pendingTap && at - this.pendingTapAt > TOUCH_DOUBLE_TAP_MAX_MS) {
      actions.push({ type: 'click_left', x: this.pendingTapX, y: this.pendingTapY });
      this.clearPendingTap();
    }
    this.mode = mode;
    this.downActive = true;
    this.downX = x;
    this.downY = y;
    this.lastX = x;
    this.lastY = y;
    this.downAt = at;
    this.movedBeyondTapDistance = false;
    this.holdCancelledByMovement = false;
    this.dragActive = false;
    this.holdConsumed = false;
    this.longPressDragArmed = false;
    this.secondTapDown = this.pendingTap
      && at - this.pendingTapAt <= TOUCH_DOUBLE_TAP_MAX_MS
      && !this.distanceExceedsDoubleTapRange(x, y, this.pendingTapDownX, this.pendingTapDownY);
    if (this.pendingTap && !this.secondTapDown) {
      actions.push({ type: 'click_left', x: this.pendingTapX, y: this.pendingTapY });
      this.clearPendingTap();
    }
    return actions;
  }

  onMove(x: number, y: number, allowDirectTouchDrag: boolean = true): Array<RustDeskTouchAction> {
    if (!this.downActive) {
      return [];
    }
    this.lastX = x;
    this.lastY = y;
    const actions: Array<RustDeskTouchAction> = [];
    const reachesLongPressRange = this.distanceReachesLongPressRange(x, y, this.downX, this.downY);
    if (this.holdConsumed && this.longPressDragArmed && !this.dragActive && reachesLongPressRange) {
      this.dragActive = true;
      actions.push({ type: 'drag_start', x: this.downX, y: this.downY });
      return actions;
    }
    if (this.holdConsumed) {
      return actions;
    }
    if (!this.dragActive && reachesLongPressRange) {
      this.holdCancelledByMovement = true;
    }
    if (!this.movedBeyondTapDistance && this.distanceExceedsTapRange(x, y, this.downX, this.downY)) {
      this.movedBeyondTapDistance = true;
      if (this.mode === 'touch') {
        if (this.pendingTap) {
          actions.push({ type: 'click_left', x: this.pendingTapX, y: this.pendingTapY });
          this.clearPendingTap();
        }
        if (allowDirectTouchDrag) {
          this.dragActive = true;
          actions.push({ type: 'drag_start', x: this.downX, y: this.downY });
        }
      } else if (this.secondTapDown) {
        this.clearPendingTap();
        this.dragActive = true;
        actions.push({ type: 'drag_start', x: this.downX, y: this.downY });
      }
    }
    return actions;
  }

  /**
   * Resolve either Flutter's double-tap-hold drag or its ordinary long press.
   */
  onHold(at: number, peerMobile: boolean, allowLongPressDrag: boolean = false): Array<RustDeskTouchAction> {
    if (!this.downActive || this.dragActive || this.holdConsumed) {
      return [];
    }
    if (this.mode === 'mouse' && this.secondTapDown) {
      if (at - this.downAt < TOUCH_DOUBLE_TAP_MAX_MS) {
        return [];
      }
      this.clearPendingTap();
      this.dragActive = true;
      return [{ type: 'drag_start', x: this.downX, y: this.downY }];
    }
    if (this.holdCancelledByMovement || at - this.downAt < TOUCH_LONG_PRESS_MS) {
      return [];
    }
    this.clearPendingTap();
    this.holdConsumed = true;
    if (peerMobile) {
      if (this.mode === 'touch') {
        this.dragActive = true;
        return [{ type: 'drag_start', x: this.downX, y: this.downY }];
      }
      this.longPressDragArmed = allowLongPressDrag;
      return [];
    }
    this.longPressDragArmed = allowLongPressDrag;
    if (this.longPressDragArmed) {
      return [];
    }
    return [{ type: 'click_right', x: this.downX, y: this.downY }];
  }

  onRelease(x: number, y: number, at: number, cancelled: boolean): Array<RustDeskTouchAction> {
    if (!this.downActive) {
      return [];
    }
    this.lastX = x;
    this.lastY = y;
    const actions: Array<RustDeskTouchAction> = [];
    if (this.dragActive) {
      actions.push({ type: 'drag_end', x: x, y: y });
      this.clearDownState();
      return actions;
    }
    if (cancelled) {
      this.clearDownState();
      return actions;
    }
    if (this.holdConsumed) {
      if (this.longPressDragArmed) {
        actions.push({ type: 'click_right', x: x, y: y });
      }
      this.clearDownState();
      return actions;
    }
    const tapCandidate = !this.movedBeyondTapDistance
      && at - this.downAt <= TOUCH_TAP_MAX_MS
      && !this.distanceExceedsTapRange(x, y, this.downX, this.downY);
    if (!tapCandidate) {
      this.clearDownState();
      return actions;
    }
    if (this.secondTapDown) {
      this.clearPendingTap();
      actions.push({ type: 'double_click_left', x: x, y: y });
      this.clearDownState();
      return actions;
    }
    this.pendingTap = true;
    this.pendingTapX = x;
    this.pendingTapY = y;
    this.pendingTapDownX = this.downX;
    this.pendingTapDownY = this.downY;
    this.pendingTapAt = at;
    this.clearDownState();
    return actions;
  }

  onTapTimeout(at: number): Array<RustDeskTouchAction> {
    if (!this.pendingTap || at - this.pendingTapAt < TOUCH_DOUBLE_TAP_MAX_MS) {
      return [];
    }
    const actions: Array<RustDeskTouchAction> = [
      { type: 'click_left', x: this.pendingTapX, y: this.pendingTapY },
    ];
    this.clearPendingTap();
    return actions;
  }

  getTapTimeoutDelay(at: number): number {
    if (!this.pendingTap || this.downActive) {
      return -1;
    }
    return Math.max(TOUCH_DOUBLE_TAP_MAX_MS - (at - this.pendingTapAt), 0);
  }

  getHoldTimeoutDelay(at: number): number {
    if (!this.isHoldPending()) {
      return -1;
    }
    const timeout = this.mode === 'mouse' && this.secondTapDown
      ? TOUCH_DOUBLE_TAP_MAX_MS
      : TOUCH_LONG_PRESS_MS;
    return Math.max(timeout - (at - this.downAt), 0);
  }

  isHoldPending(): boolean {
    return this.downActive && !this.dragActive && !this.holdConsumed
      && (!this.holdCancelledByMovement || (this.mode === 'mouse' && this.secondTapDown));
  }

  reset(): Array<RustDeskTouchAction> {
    const actions: Array<RustDeskTouchAction> = [];
    if (this.dragActive) {
      actions.push({ type: 'drag_end', x: this.lastX, y: this.lastY });
    }
    this.clearDownState();
    this.clearPendingTap();
    return actions;
  }

  private distanceExceedsTapRange(x: number, y: number, referenceX: number, referenceY: number): boolean {
    const deltaX = x - referenceX;
    const deltaY = y - referenceY;
    return deltaX * deltaX + deltaY * deltaY > TOUCH_TAP_MAX_DISTANCE * TOUCH_TAP_MAX_DISTANCE;
  }

  private distanceExceedsDoubleTapRange(x: number, y: number, referenceX: number, referenceY: number): boolean {
    const deltaX = x - referenceX;
    const deltaY = y - referenceY;
    return deltaX * deltaX + deltaY * deltaY
      > TOUCH_DOUBLE_TAP_SLOP * TOUCH_DOUBLE_TAP_SLOP;
  }

  private distanceReachesLongPressRange(x: number, y: number, referenceX: number, referenceY: number): boolean {
    const deltaX = x - referenceX;
    const deltaY = y - referenceY;
    return deltaX * deltaX + deltaY * deltaY
      >= TOUCH_LONG_PRESS_MAX_DISTANCE * TOUCH_LONG_PRESS_MAX_DISTANCE;
  }

  private clearDownState(): void {
    this.downActive = false;
    this.downX = 0;
    this.downY = 0;
    this.lastX = 0;
    this.lastY = 0;
    this.downAt = 0;
    this.movedBeyondTapDistance = false;
    this.holdCancelledByMovement = false;
    this.dragActive = false;
    this.holdConsumed = false;
    this.longPressDragArmed = false;
    this.secondTapDown = false;
  }

  private clearPendingTap(): void {
    this.pendingTap = false;
    this.pendingTapX = 0;
    this.pendingTapY = 0;
    this.pendingTapDownX = 0;
    this.pendingTapDownY = 0;
    this.pendingTapAt = 0;
  }
}
