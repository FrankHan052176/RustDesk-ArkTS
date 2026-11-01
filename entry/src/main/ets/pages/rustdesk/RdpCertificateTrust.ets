import { checkCertificateSha256 } from './DirectWireCredentials';
import { splitDeviceAddress } from './SavedDeviceModel';
import { NativeEvent } from './RustDeskTypes';

/** Public certificate metadata only. No credential is ever serialized with trust. */
export class RdpTrustedCertificate {
  target: string = '';
  sha256: string = '';
  subject: string = '';
  savedAt: number = 0;
}

/** Display-only until an explicit connect-once or remember decision. */
export class RdpCertificateChallenge {
  target: string = '';
  sha256: string = '';
  subject: string = '';
  issuer: string = '';
  notBefore: string = '';
  notAfter: string = '';
  reason: string = '';
  pinnedSha256: string = '';
}

/** Uses the same endpoint parser as saved devices; account/scheme never enter the key. */
export function rdpCertificateTrustKey(target: string): string {
  if (target.includes('://') || target.includes('@')) {
    return '';
  }
  const parts = splitDeviceAddress(target, 'rdp');
  if (!parts.valid) {
    return '';
  }
  const host = parts.address.toLowerCase();
  return `${host.includes(':') ? `[${host}]` : host}:${parts.port}`;
}

function validCertificateTime(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value) &&
    Number.isFinite(Date.parse(value));
}

/** Rejects missing/non-string fields, invalid pins, reasons and validity intervals. */
export function rdpCertificateChallengeFromEvent(event: NativeEvent): RdpCertificateChallenge | undefined {
  if (event === null || typeof event !== 'object' || event.name !== 'certificate_untrusted' ||
    typeof event.target !== 'string' || typeof event.sha256 !== 'string' ||
    typeof event.subject !== 'string' || typeof event.issuer !== 'string' ||
    typeof event.notBefore !== 'string' || typeof event.notAfter !== 'string' ||
    typeof event.reason !== 'string' || typeof event.pinnedSha256 !== 'string') {
    return undefined;
  }
  const target = rdpCertificateTrustKey(event.target);
  if (target.length === 0 || !/^[0-9a-fA-F]{64}$/.test(event.sha256) ||
    (event.pinnedSha256.length > 0 && !/^[0-9a-fA-F]{64}$/.test(event.pinnedSha256)) ||
    !validCertificateTime(event.notBefore) || !validCertificateTime(event.notAfter) ||
    Date.parse(event.notBefore) > Date.parse(event.notAfter) ||
    !['untrusted', 'name_mismatch', 'expired', 'not_yet_valid', 'pin_mismatch'].includes(event.reason)) {
    return undefined;
  }
  const challenge = new RdpCertificateChallenge();
  challenge.target = target;
  challenge.sha256 = event.sha256.toLowerCase();
  challenge.subject = event.subject;
  challenge.issuer = event.issuer;
  challenge.notBefore = event.notBefore;
  challenge.notAfter = event.notAfter;
  challenge.reason = event.reason;
  challenge.pinnedSha256 = event.pinnedSha256.toLowerCase();
  if (challenge.reason === 'pin_mismatch' &&
    (challenge.pinnedSha256.length === 0 || challenge.pinnedSha256 === challenge.sha256)) {
    return undefined;
  }
  return challenge;
}

export function parseRdpCertificateEvent(raw: string): RdpCertificateChallenge | undefined {
  try {
    return rdpCertificateChallengeFromEvent(JSON.parse(raw) as NativeEvent);
  } catch (_) {
    return undefined;
  }
}

export function validRdpTrustedCertificates(records: RdpTrustedCertificate[]): RdpTrustedCertificate[] {
  const result: RdpTrustedCertificate[] = [];
  if (!Array.isArray(records)) {
    return result;
  }
  for (const source of records) {
    if (source === null || typeof source !== 'object' || typeof source.target !== 'string' ||
      typeof source.sha256 !== 'string' || typeof source.subject !== 'string' ||
      !Number.isFinite(source.savedAt) || source.savedAt <= 0) {
      continue;
    }
    const target = rdpCertificateTrustKey(source.target);
    const pin = checkCertificateSha256(source.sha256);
    if (target.length === 0 || !pin.ok || pin.pin.length === 0 ||
      result.some((record: RdpTrustedCertificate): boolean => record.target === target)) {
      continue;
    }
    const record = new RdpTrustedCertificate();
    record.target = target;
    record.sha256 = pin.pin;
    record.subject = source.subject;
    record.savedAt = source.savedAt;
    result.push(record);
  }
  return result;
}

/** Never replaces another pin silently, including when a stale dialog races a newer decision. */
export function rememberRdpCertificate(records: RdpTrustedCertificate[], challenge: RdpCertificateChallenge,
  replaceConfirmed: boolean, savedAt: number): RdpTrustedCertificate[] | undefined {
  const target = rdpCertificateTrustKey(challenge.target);
  const pin = checkCertificateSha256(challenge.sha256);
  if (target.length === 0 || !pin.ok || pin.pin.length === 0 || !Number.isFinite(savedAt) || savedAt <= 0) {
    return undefined;
  }
  const current = records.find((record: RdpTrustedCertificate): boolean => record.target === target);
  if (challenge.reason === 'pin_mismatch' && !replaceConfirmed) {
    return undefined;
  }
  if (current !== undefined && current.sha256 !== pin.pin &&
    (!replaceConfirmed || challenge.reason !== 'pin_mismatch' || current.sha256 !== challenge.pinnedSha256)) {
    return undefined;
  }
  const remembered = new RdpTrustedCertificate();
  remembered.target = target;
  remembered.sha256 = pin.pin;
  remembered.subject = challenge.subject;
  remembered.savedAt = savedAt;
  return records.filter((record: RdpTrustedCertificate): boolean => record.target !== target).concat([remembered]);
}

export function groupedRdpFingerprint(sha256: string): string {
  const rows: string[] = [];
  for (let offset = 0; offset < sha256.length; offset += 16) {
    const pairs: string[] = [];
    for (let index = offset; index < Math.min(offset + 16, sha256.length); index += 2) {
      pairs.push(sha256.substring(index, index + 2).toUpperCase());
    }
    rows.push(pairs.join(':'));
  }
  return rows.join('\n');
}
