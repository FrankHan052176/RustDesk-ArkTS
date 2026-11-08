import { describe, expect, it } from '@ohos/hypium';
import { formatSessionToolbarMetrics } from '../../../main/ets/pages/rustdesk/SessionToolbarMetrics';
import { ActionResponse, sessionUiPhase } from '../../../main/ets/pages/rustdesk/RustDeskTypes';

export default function sessionToolbarMetricsTest(): void {
  describe('SessionToolbarMetricsTest', () => {
    it('formats the measured submission rate, network round trip and codec', 0, () => {
      const metrics = formatSessionToolbarMetrics('45', '23', 'H265');
      expect(metrics.fps).assertEqual('45');
      expect(metrics.delay).assertEqual('23');
      expect(metrics.codec).assertEqual('H265');
    });

    it('shows a measured zero as zero and an unmeasured value as dashes', 0, () => {
      // The snapshot's own zero is a reading; an empty field is not.
      const measured = formatSessionToolbarMetrics('0', '0', 'h264');
      expect(measured.fps).assertEqual('0');
      expect(measured.delay).assertEqual('0');
      expect(measured.codec).assertEqual('h264');

      const metrics = formatSessionToolbarMetrics('', '', '');
      expect(metrics.fps).assertEqual('--');
      expect(metrics.delay).assertEqual('--');
      expect(metrics.codec).assertEqual('--');
    });

    it('maps current authentication to UI connected without rewriting engine or input facts', 0, () => {
      const response: ActionResponse = {
        ok: true,
        action: 'session_poll_events',
        session: { sessionId: 'viewer-1', phase: 'streaming' },
        phase: 'streaming',
        authenticated: true,
        closing: false,
        closed: false,
        input_generation: 3,
        peer_verified: false,
        keyboard_allowed: false,
      };
      expect(sessionUiPhase(response)).assertEqual('connected');
      expect(response.session?.phase).assertEqual('streaming');
      expect(response.phase).assertEqual('streaming');
      expect(response.input_generation).assertEqual(3);
      expect(response.peer_verified).assertFalse();
      expect(response.keyboard_allowed).assertFalse();

      response.authenticated = false;
      expect(sessionUiPhase(response)).assertEqual('streaming');
      const unknown: ActionResponse = { ok: true, action: 'session_poll_events', phase: 'authenticating' };
      expect(sessionUiPhase(unknown)).assertEqual('authenticating');
    });

    it('keeps close and failure facts ahead of authentication in the shared UI mapping', 0, () => {
      const response: ActionResponse = {
        ok: true,
        action: 'session_poll_events',
        session: { sessionId: 'viewer-1', phase: 'streaming' },
        phase: 'streaming',
        authenticated: true,
        closing: true,
      };
      expect(sessionUiPhase(response)).assertEqual('closing');
      response.closed = true;
      expect(sessionUiPhase(response)).assertEqual('closed');
      response.closed = false;
      response.closing = false;
      response.phase = 'failed';
      expect(sessionUiPhase(response)).assertEqual('failed');
      const failed: ActionResponse = {
        ok: false,
        action: 'session_poll_events',
        session: { sessionId: 'viewer-1', phase: 'failed' },
        authenticated: true,
      };
      expect(sessionUiPhase(failed)).assertEqual('failed');
    });
  });
}
