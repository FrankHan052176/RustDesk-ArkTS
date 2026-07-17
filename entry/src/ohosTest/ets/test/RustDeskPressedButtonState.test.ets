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
  });
}
