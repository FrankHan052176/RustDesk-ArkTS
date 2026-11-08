import { describe, expect, it } from '@ohos/hypium';
import { util } from '@kit.ArkTS';
import { parseServerConfigText } from '../../../main/ets/pages/rustdesk/ServerConfigImport';

function encodeOfficialConfig(host: string, relay: string, api: string, key: string): string {
  const jsonStr = JSON.stringify({ host, relay, api, key });
  const helper = new util.Base64Helper();
  const bytes = new Uint8Array(new util.TextEncoder().encodeInto(jsonStr));
  const base64 = helper.encodeToStringSync(bytes);
  return base64.split('').reverse().join('');
}

export default function serverConfigImportTest(): void {
  describe('ServerConfigImportTest', () => {
    it('parses direct JSON with all official fields', 0, () => {
      const input = '{"host":"rd.example.com/","relay":"relay.example.com/","api":"https://api.example.com/","key":"ed25519pubkey"}';
      const parsed = parseServerConfigText(input);
      expect(parsed.host).assertEqual('rd.example.com');
      expect(parsed.relay).assertEqual('relay.example.com');
      expect(parsed.api).assertEqual('https://api.example.com');
      expect(parsed.key).assertEqual('ed25519pubkey');
    });

    it('parses direct JSON with null and omitted optional fields', 0, () => {
      const input = '{"host":"192.168.1.100","relay":null}';
      const parsed = parseServerConfigText(input);
      expect(parsed.host).assertEqual('192.168.1.100');
      expect(parsed.relay).assertEqual('');
      expect(parsed.api).assertEqual('');
      expect(parsed.key).assertEqual('');
    });

    it('decodes official reversed base64 configuration', 0, () => {
      const encoded = encodeOfficialConfig('test.domain.com:21116', 'test.domain.com:21117', 'http://test.domain.com:21114', 'mykey');
      const parsed = parseServerConfigText(encoded);
      expect(parsed.host).assertEqual('test.domain.com:21116');
      expect(parsed.relay).assertEqual('test.domain.com:21117');
      expect(parsed.api).assertEqual('http://test.domain.com:21114');
      expect(parsed.key).assertEqual('mykey');
    });

    it('handles rustdesk://config/ scheme prefix', 0, () => {
      const encoded = encodeOfficialConfig('myhost.org', '', '', '');
      const uri = `rustdesk://config/${encoded}`;
      const parsed = parseServerConfigText(uri);
      expect(parsed.host).assertEqual('myhost.org');
      expect(parsed.relay).assertEqual('');
    });

    it('rejects empty input or missing host', 0, () => {
      let threwEmpty = false;
      try {
        parseServerConfigText('   ');
      } catch (_) {
        threwEmpty = true;
      }
      expect(threwEmpty).assertTrue();

      let threwNoHost = false;
      try {
        parseServerConfigText('{"relay":"relay.only"}');
      } catch (_) {
        threwNoHost = true;
      }
      expect(threwNoHost).assertTrue();
    });

    it('rejects non-string field types', 0, () => {
      let threw = false;
      try {
        parseServerConfigText('{"host":12345}');
      } catch (_) {
        threw = true;
      }
      expect(threw).assertTrue();
    });

    it('rejects invalid JSON / Base64 format', 0, () => {
      let threw = false;
      try {
        parseServerConfigText('!!!not-valid-base64-or-json@@@');
      } catch (_) {
        threw = true;
      }
      expect(threw).assertTrue();
    });
  });
}
