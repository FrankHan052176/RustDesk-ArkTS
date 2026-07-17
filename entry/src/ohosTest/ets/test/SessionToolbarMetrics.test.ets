import { describe, expect, it } from '@ohos/hypium';
import { formatSessionToolbarMetrics } from '../../../main/ets/pages/rustdesk/SessionToolbarMetrics';

export default function sessionToolbarMetricsTest(): void {
  describe('SessionToolbarMetricsTest', () => {
    it('formats structured render and remote telemetry fields', 0, () => {
      const metrics = formatSessionToolbarMetrics(59.8, 120, 16, true, '23ms', 'H264');
      expect(metrics.fps).assertEqual('59.8');
      expect(metrics.frames).assertEqual('120');
      expect(metrics.decode).assertEqual('16ms');
      expect(metrics.delay).assertEqual('23ms');
      expect(metrics.codec).assertEqual('H264');
    });

    it('uses dashes for an unavailable render and empty remote telemetry', 0, () => {
      const metrics = formatSessionToolbarMetrics(0, 0, undefined, false, '', '');
      expect(metrics.fps).assertEqual('--');
      expect(metrics.frames).assertEqual('--');
      expect(metrics.decode).assertEqual('--');
      expect(metrics.delay).assertEqual('--');
      expect(metrics.codec).assertEqual('--');
    });
  });
}
