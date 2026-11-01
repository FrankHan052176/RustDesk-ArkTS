import { describe, expect, it } from '@ohos/hypium';
import { projectDecoderCandidateSnapshot } from '../../../main/ets/services/DecoderCandidateSnapshot';

const H264 = '{"codec":"H264","recommendedAvailable":true,"recommendedIsHardware":false,"hardwareAvailable":true}';
const H265 = '{"codec":"H265","recommendedAvailable":false,"recommendedIsHardware":false,"hardwareAvailable":false}';

export default function decoderCandidateSnapshotTest(): void {
  describe('DecoderCandidateSnapshot', (): void => {
    it('projects_only_safe_fields_and_preserves_recommended_software', 0, (): void => {
      const hostile = H264.replace('"codec":', '"recommendedName":"secret\\n0x123","hardwareName":"identity","zeroCopyProven":true,"codec":');
      const snapshot = projectDecoderCandidateSnapshot('{"source":"secret","surfaceBindingVerified":true,' +
        '"zeroCopyProven":true,"capabilities":[' + H265 + ',' + hostile + ',{"codec":"AV1","name":"secret"}]}');
      expect(JSON.stringify(snapshot)).assertEqual('{"state":"observed","scope":"runtime_capability_only",' +
        '"surfaceBindingVerified":false,"zeroCopyProven":false,"candidates":[' + H264 + ',' + H265 + ']}');
      const valid = '{"capabilities":[' + H264 + ',' + H265 + ']}';
      expect(projectDecoderCandidateSnapshot(valid + ' '.repeat(65536 - valid.length)).state).assertEqual('observed');
      const rows: string[] = [H264, H265];
      for (let i = 0; i < 14; i++) {
        rows.push('{"codec":"VP9"}');
      }
      expect(projectDecoderCandidateSnapshot('{"capabilities":[' + rows.join(',') + ']}').state).assertEqual('observed');
    });

    it('rejects_missing_ambiguous_invalid_and_oversized_metadata', 0, (): void => {
      const invalid: string[] = ['{', 'null', '[]', '{}', '{"capabilities":{}}',
        '{"capabilities":[' + H264 + ']}',
        '{"capabilities":[' + H264 + ',' + H265 + ',' + H264 + ']}',
        '{"capabilities":[' + H264 + ',' + H265 + ',' + H265 + ']}',
        '{"capabilities":[null,' + H264 + ',' + H265 + ']}',
        '{"capabilities":[' + H264.replace('"recommendedAvailable":true,', '') + ',' + H265 + ']}',
        '{"capabilities":[' + H264.replace('"recommendedAvailable":true', '"recommendedAvailable":"true"') + ',' + H265 + ']}',
        '{"capabilities":[' + H264.replace('"recommendedIsHardware":false', '"recommendedIsHardware":0') + ',' + H265 + ']}',
        '{"capabilities":[' + H264.replace('"hardwareAvailable":true', '"hardwareAvailable":null') + ',' + H265 + ']}',
        '{"capabilities":[' + H264 + ',' + H265.replace('"recommendedIsHardware":false', '"recommendedIsHardware":true') + ']}',
        ' '.repeat(65537)];
      const rows: string[] = [H264, H265];
      for (let i = 0; i < 15; i++) {
        rows.push('{"codec":"VP9"}');
      }
      invalid.push('{"capabilities":[' + rows.join(',') + ']}');
      for (let i = 0; i < invalid.length; i++) {
        expect(JSON.stringify(projectDecoderCandidateSnapshot(invalid[i]))).assertEqual(
          '{"state":"unavailable","scope":"runtime_capability_only","surfaceBindingVerified":false,' +
          '"zeroCopyProven":false,"candidates":[]}');
      }
    });
  });
}
