import { describe, expect, it } from '@ohos/hypium';
import { SessionDefaults } from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';
import { computeRdpDesktopSize, computeRdpScaleFactor, copySessionDefaults,
  swapDefaultDirectPort } from '../../../main/ets/pages/rustdesk/DirectSessionSettings';

export default function directSessionSettingsTest(): void {
  describe('DirectSessionSettingsTest', () => {
    it('follows the measured preview pane in physical pixels', 0, () => {
      const size = computeRdpDesktopSize(1120, 736, 2.5);
      expect(size.width).assertEqual(2800);
      expect(size.height).assertEqual(1840);
      const split = computeRdpDesktopSize(391.9, 600.6, 2.5);
      expect(split.width).assertEqual(978);
      expect(split.height).assertEqual(1501);
    });

    it('clamps both sides and rounds only width down to even', 0, () => {
      const small = computeRdpDesktopSize(10, 5, 2.5);
      expect(small.width).assertEqual(200);
      expect(small.height).assertEqual(200);
      const large = computeRdpDesktopSize(9000, 9001, 2);
      expect(large.width).assertEqual(8192);
      expect(large.height).assertEqual(8192);
      const odd = computeRdpDesktopSize(201, 203, 1);
      expect(odd.width).assertEqual(200);
      expect(odd.height).assertEqual(203);
    });

    it('fixed desktops are independent of pane density and orientation', 0, () => {
      const size = computeRdpDesktopSize(600, 900, 2.5, '1920x1200');
      expect(size.width).assertEqual(1920);
      expect(size.height).assertEqual(1200);
    });

    it('selects the nearest native whitelisted Windows scale percent', 0, () => {
      expect(computeRdpScaleFactor(2.5)).assertEqual(250);
      expect(computeRdpScaleFactor(1.24)).assertEqual(125);
      expect(computeRdpScaleFactor(1.74)).assertEqual(175);
      expect(computeRdpScaleFactor(0.5)).assertEqual(100);
      expect(computeRdpScaleFactor(8)).assertEqual(500);
      expect(computeRdpScaleFactor(2.5, 150)).assertEqual(150);
    });

    it('swaps only the opposite direct protocol default port on mode change', 0, () => {
      expect(swapDefaultDirectPort('host:3389', 1)).assertEqual('host:5900');
      expect(swapDefaultDirectPort('10.0.0.4:5900', 2)).assertEqual('10.0.0.4:3389');
      expect(swapDefaultDirectPort('[2001:db8::1]:3389', 1)).assertEqual('[2001:db8::1]:5900');
      expect(swapDefaultDirectPort('host:3390', 1)).assertEqual('host:3390');
      expect(swapDefaultDirectPort('host:5901', 2)).assertEqual('host:5901');
      expect(swapDefaultDirectPort('host', 1)).assertEqual('host');
      expect(swapDefaultDirectPort('2001:db8::3389', 1)).assertEqual('2001:db8::3389');
      expect(swapDefaultDirectPort('123456789', 2)).assertEqual('123456789');
      expect(swapDefaultDirectPort('host:3389', 0)).assertEqual('host:3389');
    });

    it('keeps direct settings when copying another session preference', 0, () => {
      const defaults = new SessionDefaults();
      defaults.inputEnabled = false;
      defaults.rdpResolution = '2560x1600';
      defaults.rdpScaleFactor = 200;
      defaults.rdpAudioEnabled = false;
      defaults.vncQuality = 'fast';
      const copied = copySessionDefaults(defaults);
      expect(copied.inputEnabled).assertFalse();
      expect(copied.rdpResolution).assertEqual('2560x1600');
      expect(copied.rdpScaleFactor).assertEqual(200);
      expect(copied.rdpAudioEnabled).assertFalse();
      expect(copied.vncQuality).assertEqual('fast');
    });
  });
}
