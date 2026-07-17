import { describe, expect, it } from '@ohos/hypium';
import { SessionOverlayState } from '../../../main/ets/pages/rustdesk/SessionOverlayState';

export default function sessionOverlayStateTest(): void {
  describe('SessionOverlayStateTest', () => {
    it('keeps exactly one detail panel active', 0, () => {
      const state = new SessionOverlayState();
      expect(state.getActivePanel()).assertEqual('home');
      expect(state.open('chat')).assertTrue();
      expect(state.isOpen('chat')).assertTrue();
      expect(state.open('quality')).assertTrue();
      expect(state.isOpen('chat')).assertFalse();
      expect(state.isOpen('quality')).assertTrue();
    });

    it('does not reopen or reclose the same state', 0, () => {
      const state = new SessionOverlayState();
      expect(state.open('display')).assertTrue();
      expect(state.open('display')).assertFalse();
      expect(state.close()).assertTrue();
      expect(state.close()).assertFalse();
    });
  });
}
