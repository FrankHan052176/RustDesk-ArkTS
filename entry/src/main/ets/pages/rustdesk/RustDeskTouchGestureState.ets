export type RustDeskTouchActionType = 'click_left' | 'click_right' | 'drag_start' | 'drag_end';

export interface RustDeskTouchAction {
  type: RustDeskTouchActionType;
  x: number;
  y: number;
}

export const TOUCH_TAP_MAX_MS: number = 220;
export const TOUCH_TAP_MAX_DISTANCE: number = 18;
export const TOUCH_LONG_PRESS_MS: number = 500;
export const TOUCH_LONG_PRESS_MAX_DISTANCE: number = 5;
export const TOUCH_DOUBLE_TAP_MAX_MS: number = 260;

export class RustDeskTouchGestureState {
  private downActive: boolean = false;
  private downX: number = 0;
  private downY: number = 0;
  private lastX: number = 0;
  private lastY: number = 0;
  private downAt: number = 0;
  private movedBeyondTapDistance: boolean = false;
  private longPressCancelledByMovement: boolean = false;
  private dragActive: boolean = false;
  private pendingTap: boolean = false;
  private pendingTapX: number = 0;
  private pendingTapY: number = 0;
  private pendingTapAt: number = 0;

  onDown(x: number, y: number, at: number): Array<RustDeskTouchAction> {
    this.downActive = true;
    this.downX = x;
    this.downY = y;
    this.lastX = x;
    this.lastY = y;
    this.downAt = at;
    this.movedBeyondTapDistance = false;
    this.longPressCancelledByMovement = false;
    this.dragActive = false;
    return [];
  }

  onMove(x: number, y: number): Array<RustDeskTouchAction> {
    if (!this.downActive) {
      return [];
    }
    this.lastX = x;
    this.lastY = y;
    if (!this.dragActive) {
      if (this.distanceReachesLongPressRange(x, y, this.downX, this.downY)) {
        this.longPressCancelledByMovement = true;
      }
      if (this.distanceExceedsTapRange(x, y, this.downX, this.downY)) {
        this.movedBeyondTapDistance = true;
      }
    }
    return [];
  }

  onLongPress(at: number): Array<RustDeskTouchAction> {
    if (!this.downActive || this.dragActive || this.longPressCancelledByMovement) {
      return [];
    }
    if (at - this.downAt < TOUCH_LONG_PRESS_MS) {
      return [];
    }
    this.dragActive = true;
    const actions: Array<RustDeskTouchAction> = [];
    actions.push({ type: 'drag_start', x: this.downX, y: this.downY });
    return actions;
  }

  onRelease(x: number, y: number, at: number, cancelled: boolean): Array<RustDeskTouchAction> {
    if (!this.downActive) {
      return [];
    }
    this.lastX = x;
    this.lastY = y;
    const actions: Array<RustDeskTouchAction> = [];
    if (this.dragActive) {
      actions.push({ type: 'drag_end', x: this.lastX, y: this.lastY });
      this.clearDownState();
      return actions;
    }
    const tapCandidate = !cancelled
      && !this.movedBeyondTapDistance
      && at - this.downAt <= TOUCH_TAP_MAX_MS
      && !this.distanceExceedsTapRange(x, y, this.downX, this.downY);
    this.clearDownState();
    if (!tapCandidate) {
      return actions;
    }
    if (this.pendingTap) {
      const isDoubleTap = at - this.pendingTapAt <= TOUCH_DOUBLE_TAP_MAX_MS
        && this.distanceExceedsTapRange(x, y, this.pendingTapX, this.pendingTapY) === false;
      if (isDoubleTap) {
        this.clearPendingTap();
        actions.push({ type: 'click_right', x, y });
        return actions;
      }
      actions.push({ type: 'click_left', x: this.pendingTapX, y: this.pendingTapY });
      this.clearPendingTap();
    }
    this.pendingTap = true;
    this.pendingTapX = x;
    this.pendingTapY = y;
    this.pendingTapAt = at;
    return actions;
  }

  onTapTimeout(at: number): Array<RustDeskTouchAction> {
    if (!this.pendingTap || at - this.pendingTapAt < TOUCH_DOUBLE_TAP_MAX_MS) {
      return [];
    }
    const actions: Array<RustDeskTouchAction> = [];
    actions.push({ type: 'click_left', x: this.pendingTapX, y: this.pendingTapY });
    this.clearPendingTap();
    return actions;
  }

  getTapTimeoutDelay(at: number): number {
    if (!this.pendingTap) {
      return -1;
    }
    return Math.max(TOUCH_DOUBLE_TAP_MAX_MS - (at - this.pendingTapAt), 0);
  }

  isLongPressPending(): boolean {
    return this.downActive && !this.dragActive && !this.longPressCancelledByMovement;
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
    this.longPressCancelledByMovement = false;
    this.dragActive = false;
  }

  private clearPendingTap(): void {
    this.pendingTap = false;
    this.pendingTapX = 0;
    this.pendingTapY = 0;
    this.pendingTapAt = 0;
  }
}
