import { describe, expect, it } from '@ohos/hypium';
import { DirectWireCredentials } from '../../../main/ets/pages/rustdesk/DirectWireCredentials';
import {
  RdpCertificateChallenge,
  RdpTrustedCertificate,
  groupedRdpFingerprint,
  parseRdpCertificateEvent,
  rdpCertificateChallengeFromEvent,
  rdpCertificateTrustKey,
  rememberRdpCertificate,
  validRdpTrustedCertificates,
} from '../../../main/ets/pages/rustdesk/RdpCertificateTrust';
import { NativeEvent } from '../../../main/ets/pages/rustdesk/RustDeskTypes';

function certificateEvent(): NativeEvent {
  return {
    name: 'certificate_untrusted', target: 'SERVER:3389', sha256: 'ab'.repeat(32),
    subject: 'CN=server', issuer: 'CN=server', notBefore: '2026-01-01T00:00:00Z',
    notAfter: '2027-01-01T00:00:00+00:00', reason: 'untrusted', pinnedSha256: '',
  };
}

function certificateChallenge(): RdpCertificateChallenge {
  const challenge = new RdpCertificateChallenge();
  challenge.target = 'server:3389';
  challenge.sha256 = 'ab'.repeat(32);
  challenge.subject = 'CN=server';
  challenge.reason = 'untrusted';
  return challenge;
}

export default function rdpCertificateTrustTest(): void {
  describe('RdpCertificateTrustTest', () => {
    it('normalizes host case and the default RDP port but keeps other ports distinct', 0, () => {
      expect(rdpCertificateTrustKey(' SERVER ')).assertEqual('server:3389');
      expect(rdpCertificateTrustKey('server:03389')).assertEqual('server:3389');
      expect(rdpCertificateTrustKey('SERVER:3390')).assertEqual('server:3390');
      expect(rdpCertificateTrustKey('[FE80::A]')).assertEqual('[fe80::a]:3389');
      expect(rdpCertificateTrustKey('[FE80::A]:3390')).assertEqual('[fe80::a]:3390');
      expect(rdpCertificateTrustKey('user@server')).assertEqual('');
      expect(rdpCertificateTrustKey('rdp://server')).assertEqual('');
      expect(rdpCertificateTrustKey('server:0')).assertEqual('');
      expect(rdpCertificateTrustKey('server:65536')).assertEqual('');
    });

    it('parses the all-string native contract and retains display metadata only', 0, () => {
      const parsed = parseRdpCertificateEvent(JSON.stringify(certificateEvent()));
      expect(parsed !== undefined).assertTrue();
      if (parsed === undefined) {
        return;
      }
      expect(parsed.target).assertEqual('server:3389');
      expect(parsed.subject).assertEqual('CN=server');
      expect(parsed.issuer).assertEqual('CN=server');
      expect(parsed.sha256).assertEqual('ab'.repeat(32));
      expect(parsed.notBefore).assertEqual('2026-01-01T00:00:00Z');
      expect(parsed.pinnedSha256).assertEqual('');
      expect(parseRdpCertificateEvent('{') === undefined).assertTrue();
      expect(parseRdpCertificateEvent('null') === undefined).assertTrue();
      expect(parseRdpCertificateEvent('{"name":"certificate_untrusted","sha256":42}') === undefined).assertTrue();
    });

    it('rejects every fingerprint that is not exactly 64 hexadecimal characters', 0, () => {
      const event = certificateEvent();
      for (const value of ['', 'a'.repeat(63), 'a'.repeat(65), 'g'.repeat(64), 'ab:'.repeat(21) + 'a']) {
        event.sha256 = value;
        expect(rdpCertificateChallengeFromEvent(event) === undefined).assertTrue();
      }
      event.sha256 = 'AB'.repeat(32);
      expect(rdpCertificateChallengeFromEvent(event)?.sha256).assertEqual('ab'.repeat(32));
    });

    it('accepts known trust reasons and refuses malformed validity or changed-pin evidence', 0, () => {
      const event = certificateEvent();
      for (const reason of ['untrusted', 'name_mismatch', 'expired', 'not_yet_valid']) {
        event.reason = reason;
        expect(rdpCertificateChallengeFromEvent(event) !== undefined).assertTrue();
      }
      event.reason = 'other';
      expect(rdpCertificateChallengeFromEvent(event) === undefined).assertTrue();
      event.reason = 'pin_mismatch';
      expect(rdpCertificateChallengeFromEvent(event) === undefined).assertTrue();
      event.pinnedSha256 = 'ab'.repeat(32);
      expect(rdpCertificateChallengeFromEvent(event) === undefined).assertTrue();
      event.pinnedSha256 = 'cd'.repeat(32);
      expect(rdpCertificateChallengeFromEvent(event) !== undefined).assertTrue();
      event.pinnedSha256 = 'bad';
      expect(rdpCertificateChallengeFromEvent(event) === undefined).assertTrue();
      event.pinnedSha256 = 'cd'.repeat(32);
      event.notAfter = 'invalid';
      expect(rdpCertificateChallengeFromEvent(event) === undefined).assertTrue();
      event.notAfter = '2025-01-01T00:00:00Z';
      expect(rdpCertificateChallengeFromEvent(event) === undefined).assertTrue();
    });

    it('remembers only public certificate fields without mutating the input store', 0, () => {
      const empty: RdpTrustedCertificate[] = [];
      const challenge = certificateChallenge();
      const next = rememberRdpCertificate(empty, challenge, false, 1234);
      expect(empty.length).assertEqual(0);
      expect(next?.length).assertEqual(1);
      expect(next?.[0].sha256).assertEqual(challenge.sha256);
      expect(next?.[0].subject).assertEqual(challenge.subject);
      expect(next?.[0].savedAt).assertEqual(1234);
      expect(JSON.stringify(next).includes('password')).assertFalse();
      expect(rememberRdpCertificate(empty, challenge, false, 0) === undefined).assertTrue();
      challenge.sha256 = 'bad';
      expect(rememberRdpCertificate(empty, challenge, false, 1234) === undefined).assertTrue();
    });

    it('replaces the old pin only after explicit confirmation and rejects stale decisions', 0, () => {
      const old = new RdpTrustedCertificate();
      old.target = 'server:3389';
      old.sha256 = 'cd'.repeat(32);
      old.subject = 'CN=old';
      old.savedAt = 1;
      const records = [old];
      const challenge = certificateChallenge();
      expect(rememberRdpCertificate(records, challenge, false, 2) === undefined).assertTrue();
      expect(rememberRdpCertificate(records, challenge, true, 2) === undefined).assertTrue();
      challenge.reason = 'pin_mismatch';
      challenge.pinnedSha256 = old.sha256;
      expect(rememberRdpCertificate(records, challenge, false, 2) === undefined).assertTrue();
      const replaced = rememberRdpCertificate(records, challenge, true, 2);
      expect(replaced?.[0].sha256).assertEqual(challenge.sha256);
      expect(replaced?.[0].savedAt).assertEqual(2);
      expect(records[0].sha256).assertEqual('cd'.repeat(32));
      challenge.pinnedSha256 = 'ef'.repeat(32);
      expect(rememberRdpCertificate(records, challenge, true, 2) === undefined).assertTrue();
      challenge.target = 'server:3390';
      challenge.reason = 'untrusted';
      challenge.pinnedSha256 = '';
      expect(rememberRdpCertificate(records, challenge, false, 3)?.length).assertEqual(2);
    });

    it('sanitizes persisted records and groups fingerprints without changing their bytes', 0, () => {
      const valid = new RdpTrustedCertificate();
      valid.target = 'SERVER';
      valid.sha256 = 'AB'.repeat(32);
      valid.subject = 'CN=server';
      valid.savedAt = 10;
      const invalid = new RdpTrustedCertificate();
      invalid.target = 'server:3390';
      invalid.sha256 = 'bad';
      invalid.savedAt = 10;
      const result = validRdpTrustedCertificates([valid, invalid]);
      expect(result.length).assertEqual(1);
      expect(result[0].target).assertEqual('server:3389');
      expect(result[0].sha256).assertEqual('ab'.repeat(32));
      const grouped = groupedRdpFingerprint(valid.sha256);
      expect(grouped.split('\n').length).assertEqual(4);
      expect(grouped.replaceAll(':', '').replaceAll('\n', '').toLowerCase()).assertEqual(result[0].sha256);
    });

    it('wipes credential references without erasing the non-secret redial identity', 0, () => {
      const credentials = new DirectWireCredentials();
      credentials.password = 'secret';
      credentials.username = 'CORP\\ann';
      credentials.dialTarget = 'rdp://CORP\\ann@server';
      credentials.wipePassword();
      expect(credentials.password).assertEqual('');
      expect(credentials.passwordAvailable).assertFalse();
      expect(credentials.username).assertEqual('CORP\\ann');
      expect(credentials.dialTarget).assertEqual('rdp://CORP\\ann@server');
    });
  });
}
