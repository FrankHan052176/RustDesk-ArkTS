import { describe, expect, it } from '@ohos/hypium';
import {
  CERTIFICATE_SHA256_HEX_LENGTH,
  MAX_RDP_USER_LENGTH,
  checkCertificateSha256,
  checkRdpUser,
  directDialTarget,
  isDirectWireKind,
  targetFieldIssue,
} from '../../../main/ets/pages/rustdesk/DirectWireCredentials';

export default function directWireCredentialsTest(): void {
  describe('DirectWireCredentialsTest', () => {
    it('refuses a typed scheme in every mode instead of letting it pick the wire', 0, () => {
      expect(targetFieldIssue('vnc', 'vnc://10.0.0.5')).assertEqual('scheme');
      expect(targetFieldIssue('vnc', 'rdp://10.0.0.5')).assertEqual('scheme');
      expect(targetFieldIssue('rdp', ' RDP://10.0.0.5:3390 ')).assertEqual('scheme');
      expect(targetFieldIssue('remote_control', 'vnc://10.0.0.5')).assertEqual('scheme');
    });

    it('accepts a bare address and keeps the RustDesk id@server form', 0, () => {
      expect(targetFieldIssue('vnc', '10.0.0.5')).assertEqual('');
      expect(targetFieldIssue('rdp', ' 10.0.0.5:3390 ')).assertEqual('');
      expect(targetFieldIssue('rdp', '[fe80::1]:3390')).assertEqual('');
      expect(targetFieldIssue('remote_control', 'id@server:21116?key=abc')).assertEqual('');
    });

    it('leaves a direct wire account to the credential dialog', 0, () => {
      expect(targetFieldIssue('rdp', 'ann@10.0.0.5')).assertEqual('account');
      expect(targetFieldIssue('vnc', 'ann@10.0.0.5')).assertEqual('account');
    });

    it('recognizes only the two direct wires', 0, () => {
      expect(isDirectWireKind('vnc')).assertTrue();
      expect(isDirectWireKind('rdp')).assertTrue();
      expect(isDirectWireKind('remote_control')).assertFalse();
      expect(isDirectWireKind('')).assertFalse();
    });

    it('dials the selected mode with the account the engine reads back', 0, () => {
      expect(directDialTarget('vnc', ' 10.0.0.5:5901 ', '')).assertEqual('vnc://10.0.0.5:5901');
      expect(directDialTarget('rdp', '10.0.0.5', 'CORP\\ann')).assertEqual('rdp://CORP\\ann@10.0.0.5');
      expect(directDialTarget('rdp', '[fe80::1]:3390', 'ann')).assertEqual('rdp://ann@[fe80::1]:3390');
      // The engine splits on the last `@`, so an e-mail account stays whole.
      expect(directDialTarget('rdp', '10.0.0.5', 'ann@example.com')).assertEqual('rdp://ann@example.com@10.0.0.5');
    });

    it('accepts the account names the engine can read and refuses the rest by reason', 0, () => {
      expect(checkRdpUser('ann').ok).assertTrue();
      expect(checkRdpUser('ann').reason).assertEqual('');
      expect(checkRdpUser('CORP\\ann').ok).assertTrue();
      expect(checkRdpUser('ann@example.com').ok).assertTrue();
      expect(checkRdpUser('  ann  ').ok).assertTrue();
      expect(checkRdpUser('').reason).assertEqual('required');
      expect(checkRdpUser('   ').reason).assertEqual('required');
      expect(checkRdpUser('ann:3390').reason).assertEqual('invalid');
      expect(checkRdpUser('CORP/ann').reason).assertEqual('invalid');
      expect(checkRdpUser('ann?key=1').reason).assertEqual('invalid');
      expect(checkRdpUser('ann#fragment').reason).assertEqual('invalid');
      expect(checkRdpUser('a'.repeat(MAX_RDP_USER_LENGTH)).ok).assertTrue();
      expect(checkRdpUser('a'.repeat(MAX_RDP_USER_LENGTH + 1)).reason).assertEqual('too_long');
    });

    it('carries no pin when no certificate was remembered', 0, () => {
      const empty = checkCertificateSha256('');
      expect(empty.ok).assertTrue();
      expect(empty.pin).assertEqual('');
      const blank = checkCertificateSha256('   ');
      expect(blank.ok).assertTrue();
      expect(blank.pin).assertEqual('');
    });

    it('normalizes a full fingerprint and refuses anything that is not one', 0, () => {
      const upper = 'A1'.repeat(CERTIFICATE_SHA256_HEX_LENGTH / 2);
      const normalized = checkCertificateSha256(`  ${upper}  `);
      expect(normalized.ok).assertTrue();
      expect(normalized.pin).assertEqual(upper.toLowerCase());
      expect(normalized.pin.length).assertEqual(CERTIFICATE_SHA256_HEX_LENGTH);

      const short = checkCertificateSha256('a'.repeat(CERTIFICATE_SHA256_HEX_LENGTH - 1));
      expect(short.ok).assertFalse();
      expect(short.pin).assertEqual('');
      expect(checkCertificateSha256('a'.repeat(CERTIFICATE_SHA256_HEX_LENGTH + 1)).ok).assertFalse();
      expect(checkCertificateSha256('g'.repeat(CERTIFICATE_SHA256_HEX_LENGTH)).ok).assertFalse();
      // A colon-separated fingerprint of the right length is still not the value
      // the engine revalidates, so it is refused rather than stripped.
      const colons = 'ab:'.repeat(21) + 'a';
      expect(colons.length).assertEqual(CERTIFICATE_SHA256_HEX_LENGTH);
      expect(checkCertificateSha256(colons).ok).assertFalse();
    });
  });
}
