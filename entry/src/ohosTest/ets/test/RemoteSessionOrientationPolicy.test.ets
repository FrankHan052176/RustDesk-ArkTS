import { describe, expect, it } from '@ohos/hypium';
import {
  RemoteSessionOrientationMode,
  RemoteSessionOrientationPolicy,
} from '../../../main/ets/pages/rustdesk/RemoteSessionOrientationPolicy';

export default function remoteSessionOrientationPolicyTest(): void {
  describe('RemoteSessionOrientationPolicyTest', () => {
    it('uses the remote display aspect ratio on phones', 0, () => {
      expect(RemoteSessionOrientationPolicy.resolve('phone', 1080, 2400))
        .assertEqual(RemoteSessionOrientationMode.PORTRAIT);
      expect(RemoteSessionOrientationPolicy.resolve('phone', 2400, 1080))
        .assertEqual(RemoteSessionOrientationMode.LANDSCAPE);
    });

    it('lets tablets follow the device rotation', 0, () => {
      expect(RemoteSessionOrientationPolicy.resolve('tablet', 1080, 2400))
        .assertEqual(RemoteSessionOrientationMode.FOLLOW_DESKTOP);
      expect(RemoteSessionOrientationPolicy.resolve('tablet', 2400, 1080))
        .assertEqual(RemoteSessionOrientationMode.FOLLOW_DESKTOP);
    });

    it('keeps 2in1 sessions landscape for contained rendering', 0, () => {
      expect(RemoteSessionOrientationPolicy.resolve('2in1', 1080, 2400))
        .assertEqual(RemoteSessionOrientationMode.LANDSCAPE);
    });

    it('falls back to the desktop policy without a valid remote display', 0, () => {
      expect(RemoteSessionOrientationPolicy.resolve('phone', 0, 0))
        .assertEqual(RemoteSessionOrientationMode.FOLLOW_DESKTOP);
      expect(RemoteSessionOrientationPolicy.resolve('unknown', 1920, 1080))
        .assertEqual(RemoteSessionOrientationMode.FOLLOW_DESKTOP);
    });
  });
}
