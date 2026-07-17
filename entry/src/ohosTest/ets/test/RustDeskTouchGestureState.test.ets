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

    it('starts and ends a drag for an unmoved long press', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(40, 40, 0);

      const startActions = state.onLongPress(300);
      expect(startActions.length).assertEqual(1);
      expect(startActions[0].type).assertEqual('drag_start');
      expect(startActions[0].x).assertEqual(40);
      expect(startActions[0].y).assertEqual(40);

      const endActions = state.onRelease(52, 54, 320, false);
      expect(endActions.length).assertEqual(1);
      expect(endActions[0].type).assertEqual('drag_end');
      expect(endActions[0].x).assertEqual(52);
      expect(endActions[0].y).assertEqual(54);
    });

    it('reset ends an active drag and clears a pending tap', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(20, 20, 0);
      state.onRelease(20, 20, 100, false);
      state.onDown(60, 60, 120);
      state.onLongPress(420);

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

    it('ends a drag once when a touch is cancelled', 0, () => {
      const state = new RustDeskTouchGestureState();
      state.onDown(10, 10, 0);
      state.onLongPress(300);

      const cancelActions = state.onRelease(10, 10, 310, true);
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
