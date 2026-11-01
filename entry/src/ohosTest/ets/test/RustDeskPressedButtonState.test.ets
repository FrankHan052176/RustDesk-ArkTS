import { describe, expect, it } from '@ohos/hypium';
import {
  RustDeskPressedButtonState,
  RustDeskPressedButtonTransition,
} from '../../../main/ets/pages/rustdesk/RustDeskPressedButtonState';

function assertTransition(
  transition: RustDeskPressedButtonTransition | undefined,
  type: 'down' | 'up',
  button: string,
  mode: 'absolute' | 'relative',
): void {
  expect(transition !== undefined).assertTrue();
  if (transition === undefined) {
    return;
  }
  expect(transition.type).assertEqual(type);
  expect(transition.button).assertEqual(button);
  expect(transition.mode).assertEqual(mode);
}

export default function pressedButtonStateTest(): void {
  describe('RustDeskPressedButtonStateTest', () => {
    it('emits down for the first owner and up for the final owner', 0, () => {
      const state = new RustDeskPressedButtonState();

      assertTransition(state.acquire('left', 'physical_mouse', 'absolute'), 'down', 'left', 'absolute');
      expect(state.acquire('left', 'physical_mouse', 'absolute') === undefined).assertTrue();
      expect(state.acquire('left', 'touch_drag', 'relative') === undefined).assertTrue();
      expect(state.release('left', 'physical_mouse') === undefined).assertTrue();
      assertTransition(state.release('left', 'touch_drag'), 'up', 'left', 'absolute');
      expect(state.release('left', 'touch_drag') === undefined).assertTrue();
    });

    it('retains the mode recorded when the button was pressed', 0, () => {
      const state = new RustDeskPressedButtonState();

      assertTransition(state.acquire('right', 'touch_click', 'relative'), 'down', 'right', 'relative');
      // The controller can change its active pointer mode before this release.
      assertTransition(state.release('right', 'touch_click'), 'up', 'right', 'relative');
    });

    it('ignores an unmatched physical mouse release', 0, () => {
      const state = new RustDeskPressedButtonState();

      expect(state.release('left', 'physical_mouse') === undefined).assertTrue();
    });

    it('does not release an unchecked click again at the next boundary', 0, () => {
      const state = new RustDeskPressedButtonState();

      assertTransition(state.acquire('left', 'physical_mouse', 'absolute'), 'down', 'left', 'absolute');
      assertTransition(state.release('left', 'physical_mouse'), 'up', 'left', 'absolute');
      expect(state.releaseAll().length).assertEqual(0);
      assertTransition(state.acquire('left', 'physical_mouse', 'absolute'), 'down', 'left', 'absolute');
    });

    it('does not drain an old release after another owner takes over', 0, () => {
      const state = new RustDeskPressedButtonState();

      state.acquire('left', 'physical_mouse', 'absolute');
      state.confirmHeld('left');
      assertTransition(state.release('left', 'physical_mouse'), 'up', 'left', 'absolute');
      // The engine refused this Up, so no confirmation is committed.
      expect(state.owedButtons().join(',')).assertEqual('left');
      assertTransition(state.acquire('left', 'touch_drag', 'absolute'), 'down', 'left', 'absolute');
      state.confirmHeld('left');
      expect(state.owedButtons().length).assertEqual(0);
      expect(state.hasOwner('left', 'physical_mouse')).assertFalse();
      assertTransition(state.release('left', 'touch_drag'), 'up', 'left', 'absolute');
      state.confirmReleased('left');
      expect(state.releaseOwners().length).assertEqual(0);
    });

    it('keeps old wire debt but not a refused replacement owner', 0, () => {
      const state = new RustDeskPressedButtonState();

      state.acquire('left', 'physical_mouse', 'absolute');
      state.confirmHeld('left');
      state.release('left', 'physical_mouse');
      state.acquire('left', 'touch_drag', 'relative');
      state.abandon('left', 'touch_drag');
      expect(state.hasOwner('left', 'physical_mouse')).assertFalse();
      expect(state.hasOwner('left', 'touch_drag')).assertFalse();
      expect(state.owedButtons().join(',')).assertEqual('left');
      state.confirmReleased('left');
      expect(state.owedButtons().length).assertEqual(0);
    });
  });
}
