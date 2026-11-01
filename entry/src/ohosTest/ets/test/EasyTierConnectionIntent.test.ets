import { describe, expect, it } from '@ohos/hypium';
import { EasyTierConnectionIntent } from '../../../main/ets/services/EasyTierApiService';

export default function easyTierConnectionIntentTest(): void {
  describe('EasyTierConnectionIntentTest', () => {
    it('carries a bare ID and its ID-only intent while waiting for preconnect', 0, () => {
      const intent = new EasyTierConnectionIntent('10.0.0.4', 'remote_control', 123, true);
      expect(intent.target).assertEqual('10.0.0.4');
      expect(intent.rustdeskIdOnly).assertTrue();
      const restored = JSON.parse(JSON.stringify(intent)) as EasyTierConnectionIntent;
      expect(restored.rustdeskIdOnly).assertTrue();
      expect(restored.target).assertEqual('10.0.0.4');
    });

    it('keeps existing direct intents unchanged and restricts ID-only to RustDesk', 0, () => {
      expect(new EasyTierConnectionIntent('10.0.0.4', 'remote_control', 123).rustdeskIdOnly).assertFalse();
      expect(new EasyTierConnectionIntent('10.0.0.4', 'rdp', 123, true).rustdeskIdOnly).assertFalse();
      expect(new EasyTierConnectionIntent('10.0.0.4', 'vnc', 123, true).rustdeskIdOnly).assertFalse();
      expect(new EasyTierConnectionIntent('10.0.0.4', 'file_transfer', 123, true).rustdeskIdOnly).assertFalse();
    });
  });
}
