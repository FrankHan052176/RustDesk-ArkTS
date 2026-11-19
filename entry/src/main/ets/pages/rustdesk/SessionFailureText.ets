/**
 * What the engine said about a session that ended or was never established, as
 * one sentence the operator can act on.
 *
 * The engine classifies every failure itself and puts the category in the poll
 * and close answers (`rendezvous_failure`, `login_failure`, `peer_close_reason`,
 * and `error` for a direct VNC/RDP wire). Nothing here is a guess from a phase
 * or from elapsed time, and no server or peer text is shown.
 */

import { ActionResponse } from './RustDeskTypes';

/** The typed facts one poll or close answer carried. Absent fields are `''`. */
export class SessionFailureFacts {
  rendezvousFailure: string = '';
  loginFailure: string = '';
  peerCloseReason: string = '';
  /** The engine's own error string, e.g. `RendezvousFailed` or an RDP cause. */
  error: string = '';
}

/** Text plus whether "connect via relay" is a different path worth offering. */
export class SessionFailureText {
  text: string = '';
  relayMayHelp: boolean = false;
}

export const SESSION_ENDED_TEXT: string = '连接已结束';

function text(value: ESObject): string {
  return typeof value === 'string' ? (value as string).trim() : '';
}

/** Reads the failure facts from a raw `sessionPollEvents` / `sessionClose` answer. */
export function sessionFailureFactsFromEnvelope(raw: string): SessionFailureFacts {
  const facts = new SessionFailureFacts();
  try {
    const envelope: ESObject = JSON.parse(raw);
    if (envelope === null || typeof envelope !== 'object') {
      return facts;
    }
    facts.rendezvousFailure = text(envelope.rendezvous_failure);
    facts.loginFailure = text(envelope.login_failure);
    facts.peerCloseReason = text(envelope.peer_close_reason);
    facts.error = text(envelope.error);
  } catch (_) {
    // An unreadable answer carries no facts; the caller keeps its generic text.
  }
  return facts;
}

function field(value: string | null | undefined): string {
  return typeof value === 'string' ? value.trim() : '';
}

/** The same facts from an answer that is already parsed. */
export function sessionFailureFactsFromResponse(response: ActionResponse): SessionFailureFacts {
  const facts = new SessionFailureFacts();
  facts.rendezvousFailure = field(response.rendezvous_failure);
  facts.loginFailure = field(response.login_failure);
  facts.peerCloseReason = field(response.peer_close_reason);
  facts.error = field(response.error);
  return facts;
}

export function hasSessionFailureFacts(facts: SessionFailureFacts): boolean {
  return facts.rendezvousFailure.length > 0 || facts.loginFailure.length > 0 ||
    facts.peerCloseReason.length > 0 || facts.error.length > 0;
}

function rendezvousText(category: string): string {
  switch (category) {
    case 'server_unreachable':
      return '无法连接 ID 服务器。请检查网络，或在“设置 > 服务器”确认服务器地址。';
    case 'server_silent':
      return 'ID 服务器没有回应。请稍后重试。';
    case 'id_not_exist':
      return '这个 ID 不存在。请核对对方设备上显示的 ID。';
    case 'offline':
      return '对方设备不在线。请确认对方已打开并联网。';
    case 'key_mismatch':
      return '服务器 Key 不匹配。请在“设置 > 服务器”核对 Key。';
    case 'key_overuse':
      return '服务器 Key 的使用次数已达上限。';
    case 'server_refused':
      return '服务器拒绝了这次连接。可能需要先登录账号，或没有访问该设备的权限。';
    case 'key_unverified':
      return '无法确认对方设备的身份：它的公钥没有经过当前服务器 Key 签名。请核对服务器 Key。';
    case 'direct_failed':
      return '无法直接连接到对方设备，并且没有可用的中继服务器。';
    case 'direct_handshake':
      return '已连上对方设备，但安全握手没有完成。';
    case 'relay_refused':
      return '对方设备拒绝了中继连接。';
    case 'relay_failed':
      return '无法通过中继服务器连接。请检查网络或中继服务器设置。';
    case 'peer_handshake':
      return '通过中继连上了对方设备，但安全握手没有完成。';
    case 'timeout':
      return '连接超时。请确认对方在线、网络可用后重试。';
    default:
      return '未能通过服务器连接到对方设备。';
  }
}

/**
 * The sentence for these facts, or `fallback` when the engine named nothing.
 *
 * Order: a refused route explains why nothing was established; a login verdict
 * explains an established route that was not authorized; a manual close by the
 * peer is its own clear statement.
 */
export function describeSessionFailure(facts: SessionFailureFacts, fallback: string): SessionFailureText {
  const result = new SessionFailureText();
  if (facts.rendezvousFailure.length > 0) {
    result.text = rendezvousText(facts.rendezvousFailure);
    result.relayMayHelp = facts.rendezvousFailure === 'direct_failed' ||
      facts.rendezvousFailure === 'direct_handshake';
    return result;
  }
  if (facts.loginFailure === 'wrong_password') {
    result.text = '密码不正确。';
    return result;
  }
  if (facts.loginFailure === 'empty_password') {
    result.text = '对方设备需要密码。';
    return result;
  }
  if (facts.loginFailure === 'refused') {
    result.text = '对方设备拒绝了这次连接。';
    return result;
  }
  if (facts.peerCloseReason === 'manual_request') {
    result.text = '对方结束了这次连接。';
    return result;
  }
  switch (facts.error) {
    case 'ConnectFailed':
      result.text = '无法连接到这个地址。请确认地址、端口和网络。';
      return result;
    case 'TransportFailed':
      result.text = '网络连接中断。';
      return result;
    case 'AuthenticationFailed':
      result.text = '身份验证没有通过。';
      return result;
    case 'UnsupportedCodec':
    // The same refusal as the local decoder reports it.
    case 'Surface decoder: UnsupportedCodec':
      result.text = '对方设备发来的视频编码本机无法解码。本机只支持 H.264 / H.265：请在对方设备的 RustDesk 设置里开启“硬件编解码”后重试；对方没有可用的硬件编码器时，暂时无法从本机查看。';
      return result;
    default:
      break;
  }
  result.text = fallback;
  return result;
}
