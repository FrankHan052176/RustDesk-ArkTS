import { describe, expect, it } from '@ohos/hypium';
import { SessionDefaults } from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';
import { copySessionDefaults } from '../../../main/ets/pages/rustdesk/DirectSessionSettings';
import {
  RemoteSessionOrientationMode as Mode,
  RemoteSessionOrientationPolicy as Policy,
} from '../../../main/ets/pages/rustdesk/RemoteSessionOrientationPolicy';

export default function remoteSessionOrientationPolicyTest(): void {
  describe('RemoteSessionOrientationPolicyTest', () => {
    it('preserves the remote display aspect ratio as the initial phone default', 0, () => {
      expect(Policy.resolve('phone', 1080, 2400)).assertEqual(Mode.PORTRAIT);
      expect(Policy.resolve('phone', 2400, 1080)).assertEqual(Mode.LANDSCAPE);
    });

    it('locks the current direction when phone or tablet keeps it', 0, () => {
      expect(Policy.resolve('phone', 1080, 2400, true)).assertEqual(Mode.LOCKED);
      expect(Policy.resolve('phone', 2400, 1080, true)).assertEqual(Mode.LOCKED);
      expect(Policy.resolve('tablet', 1080, 2400, true)).assertEqual(Mode.LOCKED);
      expect(Policy.resolve('tablet', 2400, 1080, true)).assertEqual(Mode.LOCKED);
    });

    it('offers the keep-direction switch on phones and tablets', 0, () => {
      expect(Policy.offersKeepScreenOrientation('phone')).assertTrue();
      expect(Policy.offersKeepScreenOrientation(' TABLET ')).assertTrue();
      expect(Policy.offersKeepScreenOrientation('2in1')).assertFalse();
      expect(Policy.offersKeepScreenOrientation('pc')).assertFalse();
    });

    it('preserves the tablet connection direction without following later rotations', 0, () => {
      expect(Policy.resolve('tablet', 1080, 2400)).assertEqual(Mode.LOCKED);
      expect(Policy.resolve('tablet', 2400, 1080)).assertEqual(Mode.LOCKED);
      expect(Policy.resolve('2in1', 1080, 2400)).assertEqual(Mode.LANDSCAPE);
    });

    it('does not enable automatic rotation before remote geometry arrives', 0, () => {
      expect(Policy.resolve('phone', 0, 0)).assertEqual(Mode.LOCKED);
      expect(Policy.resolve('unknown', 1920, 1080)).assertEqual(Mode.FOLLOW_DESKTOP);
    });

    it('retains the stored keep-direction preference', 0, () => {
      const defaults = new SessionDefaults();
      expect(defaults.keepScreenOrientation).assertFalse();
      defaults.keepScreenOrientation = true;
      const copied = copySessionDefaults(defaults);
      expect(copied.keepScreenOrientation).assertTrue();
      expect(Policy.resolve('tablet', 1080, 2400, copied.keepScreenOrientation)).assertEqual(Mode.LOCKED);
    });

    it('rotates by positive 90 degrees through all four directions', 0, () => {
      let mode = Mode.PORTRAIT;
      mode = Policy.rotateClockwise(mode);
      expect(mode).assertEqual(Mode.LANDSCAPE_INVERTED);
      mode = Policy.rotateClockwise(mode);
      expect(mode).assertEqual(Mode.PORTRAIT_INVERTED);
      mode = Policy.rotateClockwise(mode);
      expect(mode).assertEqual(Mode.LANDSCAPE);
      expect(Policy.rotateClockwise(mode)).assertEqual(Mode.PORTRAIT);
    });

    it('samples physical direction only when it is defined', 0, () => {
      expect(Policy.fromGravity(0, 9.8)).assertEqual(Mode.PORTRAIT);
      expect(Policy.fromGravity(9.8, 0)).assertEqual(Mode.LANDSCAPE);
      expect(Policy.fromGravity(0, -9.8)).assertEqual(Mode.PORTRAIT_INVERTED);
      expect(Policy.fromGravity(-9.8, 0)).assertEqual(Mode.LANDSCAPE_INVERTED);
      expect(Policy.fromGravity(0, 0)).assertUndefined();
    });
  });
}
