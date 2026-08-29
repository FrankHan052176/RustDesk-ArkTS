import { describe, expect, it } from '@ohos/hypium';
import {
  RustDeskTouchGestureState,
  TOUCH_DOUBLE_TAP_MAX_MS,
  TOUCH_LONG_PRESS_MS,
} from '../../../main/ets/pages/rustdesk/RustDeskTouchGestureState';

export default function touchGestureStateTest(): void {
  describe('RustDeskTouchGestureStateTest', () => {
    it('delays a single tap until the Flutter double-tap window expires', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0, 'touch');
      expect(state.onRelease(40, 40, 110, false).length).assertEqual(0);

      const actions = state.onTapTimeout(110 + TOUCH_DOUBLE_TAP_MAX_MS);
      expect(actions.length).assertEqual(1);
      expect(actions[0].type).assertEqual('click_left');
      expect(actions[0].x).assertEqual(40);
      expect(actions[0].y).assertEqual(40);
    });

    it('maps a normal double tap to two left clicks instead of right click', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0, 'touch');
      state.onRelease(40, 40, 100, false);
      state.onDown(46, 44, 170, 'touch');

      const actions = state.onRelease(46, 44, 230, false);
      expect(actions.length).assertEqual(1);
      expect(actions[0].type).assertEqual('double_click_left');
    });

    it('starts a direct touch drag after one-finger pan slop', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(20, 20, 0, 'touch');

      const start = state.onMove(42, 20);
      expect(start.length).assertEqual(1);
      expect(start[0].type).assertEqual('drag_start');
      expect(start[0].x).assertEqual(20);

      const end = state.onRelease(60, 20, 180, false);
      expect(end.length).assertEqual(1);
      expect(end[0].type).assertEqual('drag_end');
      expect(end[0].x).assertEqual(60);
    });

    it('keeps ordinary mouse-mode one-finger pan cursor-only', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(20, 20, 0, 'mouse');

      expect(state.onMove(60, 20).length).assertEqual(0);
      expect(state.onRelease(60, 20, 180, false).length).assertEqual(0);
      expect(state.onTapTimeout(600).length).assertEqual(0);
    });

    it('lets relative transport suppress touch-mode direct drag', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(20, 20, 0, 'touch');

      expect(state.onMove(60, 20, false).length).assertEqual(0);
      expect(state.onRelease(60, 20, 180, false).length).assertEqual(0);
    });

    it('starts Flutter mouse-mode hold drag when the second tap moves', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(20, 20, 0, 'mouse');
      state.onRelease(20, 20, 90, false);
      state.onDown(22, 22, 160, 'mouse');

      const start = state.onMove(48, 22);
      expect(start.length).assertEqual(1);
      expect(start[0].type).assertEqual('drag_start');

      const end = state.onRelease(52, 22, 260, false);
      expect(end.length).assertEqual(1);
      expect(end[0].type).assertEqual('drag_end');
    });

    it('starts Flutter mouse-mode hold drag after the second-tap hold timeout', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(20, 20, 0, 'mouse');
      state.onRelease(20, 20, 80, false);
      state.onDown(20, 20, 150, 'mouse');

      const actions = state.onHold(150 + TOUCH_DOUBLE_TAP_MAX_MS, false);
      expect(actions.length).assertEqual(1);
      expect(actions[0].type).assertEqual('drag_start');
    });

    it('maps desktop-peer long press to right click', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(30, 30, 0, 'touch');

      const actions = state.onHold(TOUCH_LONG_PRESS_MS, false);
      expect(actions.length).assertEqual(1);
      expect(actions[0].type).assertEqual('click_right');
      expect(state.onRelease(30, 30, 600, false).length).assertEqual(0);
    });

    it('does not turn a committed desktop long press into a left drag', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(30, 30, 0, 'touch');
      expect(state.onHold(TOUCH_LONG_PRESS_MS, false).length).assertEqual(1);

      expect(state.onMove(60, 30).length).assertEqual(0);
      expect(state.onRelease(60, 30, 700, false).length).assertEqual(0);
    });

    it('starts a phone left-button drag when mouse-mode long press moves', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(30, 30, 0, 'mouse');
      expect(state.onHold(TOUCH_LONG_PRESS_MS, false, true).length).assertEqual(0);

      const start = state.onMove(40, 30);
      expect(start.length).assertEqual(1);
      expect(start[0].type).assertEqual('drag_start');
      expect(start[0].x).assertEqual(30);

      const end = state.onRelease(60, 30, 700, false);
      expect(end.length).assertEqual(1);
      expect(end[0].type).assertEqual('drag_end');
    });

    it('keeps explicit long-press right click instead of arming phone drag', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(30, 30, 0, 'mouse');

      const hold = state.onHold(TOUCH_LONG_PRESS_MS, false, false);
      expect(hold.length).assertEqual(1);
      expect(hold[0].type).assertEqual('click_right');
      expect(state.onMove(40, 30).length).assertEqual(0);
      expect(state.onRelease(40, 30, 700, false).length).assertEqual(0);
    });

    it('uses held left button for a mobile peer long press in touch mode', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(30, 30, 0, 'touch');

      const start = state.onHold(TOUCH_LONG_PRESS_MS, true);
      expect(start.length).assertEqual(1);
      expect(start[0].type).assertEqual('drag_start');

      const end = state.onRelease(32, 32, 650, false);
      expect(end.length).assertEqual(1);
      expect(end[0].type).assertEqual('drag_end');
    });

    it('does not synthesize a right click for mobile peer mouse-mode long press', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(30, 30, 0, 'mouse');

      expect(state.onHold(TOUCH_LONG_PRESS_MS, true).length).assertEqual(0);
      expect(state.onRelease(30, 30, 650, false).length).assertEqual(0);
    });

    it('cancels ordinary long press after small movement reaches five vp', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0, 'touch');
      state.onMove(45, 40);

      expect(state.isHoldPending()).assertFalse();
      expect(state.onHold(TOUCH_LONG_PRESS_MS, false).length).assertEqual(0);
    });

    it('reset releases an active drag exactly once', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0, 'touch');
      state.onMove(40, 10);

      const first = state.reset();
      expect(first.length).assertEqual(1);
      expect(first[0].type).assertEqual('drag_end');
      expect(state.reset().length).assertEqual(0);
    });

    it('does not arm a tap when a touch is cancelled', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0, 'touch');

      expect(state.onRelease(10, 10, 100, true).length).assertEqual(0);
      expect(state.onTapTimeout(500).length).assertEqual(0);
    });
  });
}
