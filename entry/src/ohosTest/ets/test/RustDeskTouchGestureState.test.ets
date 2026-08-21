import { describe, expect, it } from '@ohos/hypium';
import { RustDeskTouchGestureState } from '../../../main/ets/pages/rustdesk/RustDeskTouchGestureState';

export default function touchGestureStateTest(): void {
  describe('RustDeskTouchGestureStateTest', () => {
    it('delays a single tap until the double-tap timeout', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0);
      const releaseActions = state.onRelease(40, 40, 110, false);
      expect(releaseActions.length).assertEqual(0);

      const timeoutActions = state.onTapTimeout(371);
      expect(timeoutActions.length).assertEqual(1);
      expect(timeoutActions[0].type).assertEqual('click_left');
      expect(timeoutActions[0].x).assertEqual(40);
      expect(timeoutActions[0].y).assertEqual(40);
    });

    it('emits a right click for a nearby second tap', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0);
      state.onRelease(40, 40, 110, false);
      state.onDown(48, 46, 180);

      const actions = state.onRelease(48, 46, 240, false);
      expect(actions.length).assertEqual(1);
      expect(actions[0].type).assertEqual('click_right');
      expect(actions[0].x).assertEqual(48);
      expect(actions[0].y).assertEqual(46);
    });

    it('starts and ends a drag for a long press within the movement tolerance', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0);
      state.onMove(42, 44);

      const startActions = state.onLongPress(500);
      expect(startActions.length).assertEqual(1);
      expect(startActions[0].type).assertEqual('drag_start');
      expect(startActions[0].x).assertEqual(40);
      expect(startActions[0].y).assertEqual(40);

      state.onMove(52, 54);
      const endActions = state.onRelease(52, 54, 520, false);
      expect(endActions.length).assertEqual(1);
      expect(endActions[0].type).assertEqual('drag_end');
      expect(endActions[0].x).assertEqual(52);
      expect(endActions[0].y).assertEqual(54);
    });

    it('does not start a long press before the hold duration', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0);

      expect(state.onLongPress(499).length).assertEqual(0);
      expect(state.isLongPressPending()).assertTrue();
    });

    it('cancels a pending long press when movement reaches five vp', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0);
      state.onMove(45, 40);

      expect(state.isLongPressPending()).assertFalse();
      expect(state.onLongPress(500).length).assertEqual(0);
    });

    it('cancels a pending long press after cumulative slow movement', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0);
      state.onMove(42, 40);
      expect(state.isLongPressPending()).assertTrue();
      state.onMove(44, 40);
      expect(state.isLongPressPending()).assertTrue();
      state.onMove(45, 40);

      expect(state.isLongPressPending()).assertFalse();
      expect(state.onLongPress(500).length).assertEqual(0);
    });

    it('reset ends an active drag and clears a pending tap', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(20, 20, 0);
      state.onRelease(20, 20, 100, false);
      state.onDown(60, 60, 120);
      state.onLongPress(620);

      const resetActions = state.reset();
      expect(resetActions.length).assertEqual(1);
      expect(resetActions[0].type).assertEqual('drag_end');
      expect(resetActions[0].x).assertEqual(60);
      expect(resetActions[0].y).assertEqual(60);
      expect(state.onTapTimeout(1000).length).assertEqual(0);
    });

    it('emits an out-of-range pending tap before arming a new candidate', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);
      state.onRelease(10, 10, 100, false);
      state.onDown(100, 100, 140);

      const secondReleaseActions = state.onRelease(100, 100, 200, false);
      expect(secondReleaseActions.length).assertEqual(1);
      expect(secondReleaseActions[0].type).assertEqual('click_left');
      expect(secondReleaseActions[0].x).assertEqual(10);
      expect(secondReleaseActions[0].y).assertEqual(10);

      const timeoutActions = state.onTapTimeout(461);
      expect(timeoutActions.length).assertEqual(1);
      expect(timeoutActions[0].type).assertEqual('click_left');
      expect(timeoutActions[0].x).assertEqual(100);
      expect(timeoutActions[0].y).assertEqual(100);
    });

    it('cancels a tap when movement exceeds the maximum distance', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);
      state.onMove(29, 10);
      expect(state.onRelease(29, 10, 100, false).length).assertEqual(0);
      expect(state.onTapTimeout(400).length).assertEqual(0);
    });

    it('starts a Flutter-style left drag for Android when allowPanSwipe is enabled', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);
      const startActions = state.onMove(29, 10, true);
      expect(startActions.length).assertEqual(1);
      expect(startActions[0].type).assertEqual('drag_start');
      expect(startActions[0].x).assertEqual(10);
      expect(startActions[0].y).assertEqual(10);

      const endActions = state.onRelease(29, 10, 100, false);
      expect(endActions.length).assertEqual(1);
      expect(endActions[0].type).assertEqual('drag_end');
      expect(endActions[0].x).assertEqual(29);
      expect(endActions[0].y).assertEqual(10);
      expect(state.onTapTimeout(400).length).assertEqual(0);
    });

    it('commits a pending tap before starting a later one-finger drag when allowPanSwipe is enabled', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);
      state.onRelease(10, 10, 100, false);
      state.onDown(60, 60, 140);

      const actions = state.onMove(80, 60, true);
      expect(actions.length).assertEqual(2);
      expect(actions[0].type).assertEqual('click_left');
      expect(actions[0].x).assertEqual(10);
      expect(actions[0].y).assertEqual(10);
      expect(actions[1].type).assertEqual('drag_start');
      expect(actions[1].x).assertEqual(60);
      expect(actions[1].y).assertEqual(60);
    });

    it('does not start a drag on normal move when allowPanSwipe is false (non-Android desktop mode)', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);
      const moveActions = state.onMove(30, 10, false);
      expect(moveActions.length).assertEqual(0);
      expect(state.onRelease(30, 10, 100, false).length).assertEqual(0);
      expect(state.onTapTimeout(400).length).assertEqual(0);
    });

    it('ends a drag once when a touch is cancelled', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);
      state.onLongPress(500);

      const cancelActions = state.onRelease(10, 10, 510, true);
      expect(cancelActions.length).assertEqual(1);
      expect(cancelActions[0].type).assertEqual('drag_end');
      expect(state.onRelease(10, 10, 320, true).length).assertEqual(0);
    });

    it('does not arm a tap when a touch is cancelled', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);

      expect(state.onRelease(10, 10, 100, true).length).assertEqual(0);
      expect(state.onTapTimeout(400).length).assertEqual(0);
    });

    it('reports the remaining pending-tap timeout', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);
      state.onRelease(10, 10, 100, false);

      expect(state.getTapTimeoutDelay(200)).assertEqual(160);
      expect(state.getTapTimeoutDelay(360)).assertEqual(0);
      state.onTapTimeout(360);
      expect(state.getTapTimeoutDelay(360)).assertEqual(-1);
    });
  });
}
