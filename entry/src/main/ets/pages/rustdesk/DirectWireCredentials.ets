/**
 * What a direct VNC/RDP wire needs before it can be dialled, and the rules its
 * credentials have to satisfy.
 *
 * A direct viewer consumes its credential when it dials: the engine's own target
 * parser refuses an RDP endpoint that names no account, and the password is read
 * once, at dial time. So the operator's answers are collected before anything is
 * registered and travel in the `sessionAdd` options and in the endpoint itself,
 * never in a later `sessionLogin`.
 *
 * Everything here is pure: the strings this module produces are the exact ones
 * handed to the engine. For RDP the initial password also waits in memory for the
 * TLS certificate decision, then is cleared on success, rejection/cancel or an
 * explicitly accepted redial. Nothing is persisted or put into a URL.
 */

/** The direct wires this client can speak. */
export type DirectWireProtocol = 'vnc' | 'rdp';

/** The engine's own bound on an account name inside an endpoint authority. */
export const MAX_RDP_USER_LENGTH = 128;

/** A SHA-256 fingerprint, as hexadecimal characters. */
export const CERTIFICATE_SHA256_HEX_LENGTH = 64;

/**
 * One answered credential request, waiting for the dial that consumes it.
 *
 * `displayTarget` is the bare address the operator typed, and what the session
 * tab is named after; `dialTarget` is what the engine is given: the scheme of the
 * selected mode and, for RDP, the account. An initial RDP password waits only for
 * certificate resolution; an accepted redial drops it after `sessionAdd` takes it.
 */
export class DirectWireCredentials {
  kind: string = '';
  displayTarget: string = '';
  dialTarget: string = '';
  username: string = '';
  password: string = '';
  passwordAvailable: boolean = true;
  certificateSha256: string = '';
  certificateAccepted: boolean = false;

  wipePassword(): void {
    this.password = '';
    this.passwordAvailable = false;
  }
}

/** Why one account name can or cannot be written into an RDP authority. */
export interface RdpUserCheck {
  ok: boolean;
  /** `''` when acceptable, otherwise which rule the value broke. */
  reason: string;
}

/** The certificate pin an option would carry, and whether the field was acceptable. */
export interface CertificatePinCheck {
  ok: boolean;
  /** The normalized pin; `''` for "no pin" and for a value that was refused. */
  pin: string;
}

/**
 * Why the address field cannot be dialled as typed, or `''` when it can.
 *
 * The mode bar names the protocol, so the field holds only an address: a typed
 * `vnc://`/`rdp://` scheme is refused in every mode instead of overriding the
 * selected one. A direct wire's account is asked for by the credential dialog,
 * so a `user@` in a VNC/RDP address is refused too; a RustDesk target keeps its
 * own `id@server` form.
 */
export type TargetFieldIssue = '' | 'scheme' | 'account';

export function targetFieldIssue(kind: string, target: string): TargetFieldIssue {
  const value = target.trim();
  if (value.includes('://')) {
    return 'scheme';
  }
  if (isDirectWireKind(kind) && value.includes('@')) {
    return 'account';
  }
  return '';
}

/** What the operator is told about one refused address, naming the field rule it broke. */
export function targetFieldIssueText(kind: string, issue: TargetFieldIssue): string {
  if (issue === 'scheme') {
    return '地址无需填写 vnc:// 或 rdp://，协议请用上方模式栏选择';
  }
  if (issue === 'account') {
    return kind === 'rdp'
      ? 'RDP 地址只填主机或 IP[:端口]，用户名在连接时填写'
      : 'VNC 地址只填主机或 IP[:端口]';
  }
  return '';
}

/** Whether a session kind is one of the two direct wires. */
export function isDirectWireKind(kind: string): boolean {
  return kind === 'vnc' || kind === 'rdp';
}

/**
 * The endpoint the engine is given for one direct wire.
 *
 * The engine routes by scheme, so the selected mode's scheme is added here and
 * nowhere else; an RDP endpoint also names its account, because the engine reads
 * the RDP user from the authority (split on its last `@`, so an e-mail account
 * survives).
 */
export function directDialTarget(protocol: DirectWireProtocol, address: string, user: string): string {
  const host = address.trim();
  return protocol === 'rdp' ? `rdp://${user}@${host}` : `vnc://${host}`;
}

/**
 * Whether one account name can be written into an RDP authority.
 *
 * The engine splits the authority on its last `@`, rejects an empty user or one
 * containing `:`, caps its length and refuses any `/`, `?` or `#` anywhere in the
 * target, so a name that would change the host or be silently truncated is
 * refused here with its own reason instead of being sent as a different endpoint
 * than the operator asked for. `DOMAIN\user` and an e-mail account (a Microsoft
 * account) are ordinary account names on this wire and pass.
 */
export function checkRdpUser(raw: string): RdpUserCheck {
  const user = raw.trim();
  if (user.length === 0) {
    return { ok: false, reason: 'required' };
  }
  if (user.length > MAX_RDP_USER_LENGTH) {
    return { ok: false, reason: 'too_long' };
  }
  if (user.includes(':') || user.includes('/') || user.includes('?') || user.includes('#')) {
    return { ok: false, reason: 'invalid' };
  }
  return { ok: true, reason: '' };
}

/**
 * The certificate pin an option would carry.
 *
 * An empty option leaves the decision to system roots. Non-empty values must be
 * exactly 64 hexadecimal characters. Certificate metadata alone never grants
 * trust: only an explicit certificate decision may supply or remember this pin.
 */
export function checkCertificateSha256(raw: string): CertificatePinCheck {
  const value = raw.trim();
  if (value.length === 0) {
    return { ok: true, pin: '' };
  }
  if (value.length !== CERTIFICATE_SHA256_HEX_LENGTH || !/^[0-9a-fA-F]+$/.test(value)) {
    return { ok: false, pin: '' };
  }
  return { ok: true, pin: value.toLowerCase() };
}
