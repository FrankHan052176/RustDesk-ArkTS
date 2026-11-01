import { describe, expect, it } from '@ohos/hypium';
import { formatSessionToolbarMetrics } from '../../../main/ets/pages/rustdesk/SessionToolbarMetrics';

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
  });
}
