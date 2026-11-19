import { describe, expect, it } from '@ohos/hypium';
import {
  decoderCapabilitiesFromReport,
  resolveCodecPreference,
} from '../../../main/ets/pages/rustdesk/DecoderCapabilityReport';

// The shape the engine's capability query really answers with, as the JSON
// text it arrives as.
const BOTH: string = '{"ok":true,"evidence":"advertised_metadata",' +
  '"h264_decoder":{"ok":true,"codec_name":"OMX.hisi.video.decoder.avc","mime":"video/avc","hardware":true},' +
  '"hevc_decoder":{"ok":true,"codec_name":"OMX.hisi.video.decoder.hevc","mime":"video/hevc","hardware":true}}';
const ONLY_H264: string = '{"ok":true,' +
  '"h264_decoder":{"ok":true,"codec_name":"avc","mime":"video/avc","hardware":true},' +
  '"hevc_decoder":{"ok":false,"error":{"kind":"no_hardware_capability"}}}';

export default function decoderCapabilityReportTest(): void {
  describe('DecoderCapabilityReportTest', () => {
    it('lists exactly the decoders the report names, H.265 first', 0, () => {
      const rows = decoderCapabilitiesFromReport(BOTH);
      expect(rows.length).assertEqual(2);
      expect(rows[0].codec).assertEqual('H265');
      expect(rows[0].hardwareAvailable).assertTrue();
      expect(rows[0].hardwareName).assertEqual('OMX.hisi.video.decoder.hevc');
      expect(rows[1].codec).assertEqual('H264');
    });

    it('does not invent a decoder the platform refused or a report it cannot read', 0, () => {
      const rows = decoderCapabilitiesFromReport(ONLY_H264);
      expect(rows.length).assertEqual(1);
      expect(rows[0].codec).assertEqual('H264');
      expect(decoderCapabilitiesFromReport('').length).assertEqual(0);
      expect(decoderCapabilitiesFromReport('not json').length).assertEqual(0);
      expect(decoderCapabilitiesFromReport('null').length).assertEqual(0);
    });

    it('keeps an explicit codec only when its decoder exists; auto stays auto', 0, () => {
      const both = decoderCapabilitiesFromReport(BOTH);
      const h264Only = decoderCapabilitiesFromReport(ONLY_H264);
      expect(resolveCodecPreference('auto', both)).assertEqual('auto');
      expect(resolveCodecPreference('h265', both)).assertEqual('h265');
      expect(resolveCodecPreference(' H264 ', both)).assertEqual('h264');
      expect(resolveCodecPreference('h265', h264Only)).assertEqual('auto');
      // Nothing is known yet: no explicit request is sent on a guess.
      expect(resolveCodecPreference('h265', [])).assertEqual('auto');
      // No decoder for these exists on this platform.
      expect(resolveCodecPreference('vp9', both)).assertEqual('auto');
      expect(resolveCodecPreference('av1', both)).assertEqual('auto');
    });
  });
}
