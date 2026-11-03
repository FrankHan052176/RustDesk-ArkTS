import { describe, expect, it } from '@ohos/hypium';
import { RustDeskMousePayload } from '../../../main/ets/pages/rustdesk/RustDeskInputMapper';
import { RustDeskMouseSink, sendNativeMouse } from '../../../main/ets/pages/rustdesk/RustDeskMouseTransport';

class CanonicalMouseRecord {
  kind: number = -1;
  button: number = -1;
  x?: number;
  y?: number;
  type?: string;
  buttons?: string;
  relative_mouse_mode?: string;
}

class MouseTestSink implements RustDeskMouseSink {
  calls: number = 0;
  sessionId: string = '';
  generation: number = 0;
  event: CanonicalMouseRecord = new CanonicalMouseRecord();
  admitted: boolean = true;

  sessionSendMouse(sessionId: string, canonicalJson: string, inputGeneration: number): string {
    this.calls++;
    this.sessionId = sessionId;
    this.generation = inputGeneration;
    this.event = JSON.parse(canonicalJson) as CanonicalMouseRecord;
    return JSON.stringify({
      ok: this.admitted,
      action: 'session_send_mouse',
      input_generation: this.admitted ? 7 : 9,
    });
  }
}

export default function mouseTransportTest(): void {
  describe('RustDeskMouseTransport', (): void => {
    it('sends canonical button codes without inventing a cursor position', 0, (): void => {
      const sink = new MouseTestSink();
      const payload = new RustDeskMousePayload();
      payload.type = 'down';
      payload.buttons = 'forward';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertTrue();
      expect(sink.sessionId).assertEqual('session');
      expect(sink.generation).assertEqual(7);
      expect(sink.event.kind).assertEqual(1);
      expect(sink.event.button).assertEqual(5);
      expect(sink.event.x).assertUndefined();
      expect(sink.event.y).assertUndefined();
      expect(sink.event.type).assertUndefined();
      expect(sink.event.buttons).assertUndefined();
      expect(sink.event.relative_mouse_mode).assertUndefined();
      payload.type = 'up';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertTrue();
      expect(sink.event.kind).assertEqual(2);
      expect(sink.event.x).assertUndefined();
    });

    it('uses display-local pixels once for absolute moves', 0, (): void => {
      const sink = new MouseTestSink();
      const payload = new RustDeskMousePayload();
      payload.x = '-1819';
      payload.y = '30';
      expect(sendNativeMouse(sink, 'session', payload, 7, -1920, 0).ok).assertTrue();
      expect(sink.event.kind).assertEqual(0);
      expect(sink.event.button).assertEqual(0);
      expect(sink.event.x).assertEqual(101);
      expect(sink.event.y).assertEqual(30);
    });

    it('requires complete absolute coordinates but preserves missing button coordinates', 0, (): void => {
      const sink = new MouseTestSink();
      const payload = new RustDeskMousePayload();
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertFalse();
      payload.type = 'down';
      payload.buttons = 'left';
      payload.x = '10';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertFalse();
      expect(sink.calls).assertEqual(0);
      payload.y = '20';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertTrue();
      expect(sink.event.x).assertEqual(10);
      expect(sink.event.y).assertEqual(20);
    });

    it('maps wheel, trackpad and relative motion to canonical integers', 0, (): void => {
      const sink = new MouseTestSink();
      const payload = new RustDeskMousePayload();
      payload.type = 'wheel';
      payload.y = '-1';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertTrue();
      expect(sink.event.kind).assertEqual(3);
      expect(sink.event.button).assertEqual(0);
      expect(sink.event.x).assertEqual(0);
      expect(sink.event.y).assertEqual(-1);
      payload.type = 'trackpad';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertTrue();
      expect(sink.event.kind).assertEqual(4);
      payload.type = 'move_relative';
      payload.x = '-2147483648';
      payload.y = '2147483647';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertTrue();
      expect(sink.event.kind).assertEqual(5);
      expect(sink.event.x).assertEqual(-2147483648);
      expect(sink.event.y).assertEqual(2147483647);
    });

    it('rejects values NAPI would truncate or wrap', 0, (): void => {
      const sink = new MouseTestSink();
      const payload = new RustDeskMousePayload();
      payload.type = 'move_relative';
      payload.x = '2147483648';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertFalse();
      payload.x = '0.5';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertFalse();
      payload.x = 'NaN';
      expect(sendNativeMouse(sink, 'session', payload, 7).ok).assertFalse();
      expect(sink.calls).assertEqual(0);
    });

    it('requires a positive safe numeric generation before calling native', 0, (): void => {
      const sink = new MouseTestSink();
      const payload = new RustDeskMousePayload();
      payload.type = 'move_relative';
      const invalid: number[] = [0, -1, 1.5, Number.NaN, Number.POSITIVE_INFINITY, 9007199254740992];
      for (let index = 0; index < invalid.length; index++) {
        expect(sendNativeMouse(sink, 'session', payload, invalid[index]).ok).assertFalse();
      }
      expect(sink.calls).assertEqual(0);
    });

    it('returns a refusal generation without resending the event', 0, (): void => {
      const sink = new MouseTestSink();
      sink.admitted = false;
      const payload = new RustDeskMousePayload();
      payload.type = 'move_relative';
      const response = sendNativeMouse(sink, 'session', payload, 7);
      expect(response.ok).assertFalse();
      expect(response.input_generation).assertEqual(9);
      expect(sink.calls).assertEqual(1);
      expect(sink.generation).assertEqual(7);
    });
  });
}
