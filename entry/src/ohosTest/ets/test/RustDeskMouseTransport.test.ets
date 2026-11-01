import { describe, expect, it } from '@ohos/hypium';
import { RustDeskMousePayload } from '../../../main/ets/pages/rustdesk/RustDeskInputMapper';
import { RustDeskMouseSink, sendNativeMouse } from '../../../main/ets/pages/rustdesk/RustDeskMouseTransport';

class MouseTestSink implements RustDeskMouseSink {
  calls: number = 0;
  kind: number = 0;
  button: number = 0;
  marker: number = -1;

  sessionSendMouseEvent(_sessionId: string, kind: number, button: number, _x: number, _y: number,
    marker: number): boolean {
    this.calls += 1;
    this.kind = kind;
    this.button = button;
    this.marker = marker;
    return true;
  }
}

export default function mouseTransportTest(): void {
  describe('RustDeskMouseTransport', (): void => {
    it('keeps_button_codes_and_relative_markers_distinct', 0, (): void => {
      const sink = new MouseTestSink();
      const payload = new RustDeskMousePayload();
      payload.type = 'down';
      payload.buttons = 'forward';
      payload.x = '-100';
      expect(sendNativeMouse(sink, 'session', payload)).assertTrue();
      expect(sink.kind).assertEqual(1);
      expect(sink.button).assertEqual(5);
      expect(sink.marker).assertEqual(-1);
      payload.relative_mouse_mode = '1';
      expect(sendNativeMouse(sink, 'session', payload)).assertFalse();
      expect(sink.calls).assertEqual(1);
    });

    it('rejects_values_that_napi_would_truncate_or_wrap', 0, (): void => {
      const sink = new MouseTestSink();
      const payload = new RustDeskMousePayload();
      payload.x = '2147483648';
      expect(sendNativeMouse(sink, 'session', payload)).assertFalse();
      payload.x = '0.5';
      expect(sendNativeMouse(sink, 'session', payload)).assertFalse();
      payload.x = 'NaN';
      expect(sendNativeMouse(sink, 'session', payload)).assertFalse();
      expect(sink.calls).assertEqual(0);
      payload.x = '-2147483648';
      payload.y = '2147483647';
      expect(sendNativeMouse(sink, 'session', payload)).assertTrue();
    });
  });
}
