import { describe, expect, it } from '@ohos/hypium';
import { formatSessionToolbarMetrics } from '../../../main/ets/pages/rustdesk/SessionToolbarMetrics';

export default function sessionToolbarMetricsTest(): void {
  describe('SessionToolbarMetricsTest', () => {
    it('formats official quality telemetry fields', 0, () => {
      const metrics = formatSessionToolbarMetrics('60', '23', 'H264');
      expect(metrics.fps).assertEqual('60');
      expect(metrics.delay).assertEqual('23');
      expect(metrics.codec).assertEqual('H264');
    });

    it('uses dashes for empty quality telemetry', 0, () => {
      const metrics = formatSessionToolbarMetrics('', '', '');
      expect(metrics.fps).assertEqual('--');
      expect(metrics.delay).assertEqual('--');
      expect(metrics.codec).assertEqual('--');
    });
  });
}
