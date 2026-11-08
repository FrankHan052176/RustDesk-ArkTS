/**
 * Types for forwarding one independently selected source display through B.
 */

export * from './AbilityConnectionTypes';

export type ShareState = 'idle' | 'arming' | 'ready' | 'listening' | 'connected' | 'stopping' | 'stopped' | 'failed';

export type ShareStopReason =
  | 'user_stop'
  | 'source_closed'
  | 'source_replaced'
  | 'display_list_changed'
  | 'geometry_changed'
  | 'codec_changed'
  | 'unsupported_codec'
  | 'lifecycle_fence'
  | 'invite_expired'
  | 'auth_failed'
  | 'viewer_gone'
  | 'resync_timeout'
  | 'internal';

export interface ShareStartOptions {
  sessionId: string;
  display: number; // Peer display index; does not change B's local selection.
  ttlSeconds?: number;
  acceptUnverifiedSource?: boolean;
}

export interface ShareStartDisplay {
  index: number;
  name?: string;
}

export interface ShareStartResult {
  ok: boolean;
  shareEpoch?: string;
  inviteCode?: string;
  expiresAtMs?: number;
  endpoint?: string;
  codec?: string;
  width?: number;
  height?: number;
  display?: ShareStartDisplay;
  error?: string;
  reason?: string;
  message?: string;
}

export interface ShareStopResult {
  ok: boolean;
  reason?: string;
  reclaimed?: boolean;
  message?: string;
}

export interface ShareStatusResult {
  ok?: boolean;
  state: ShareState;
  reason?: ShareStopReason | string;
  shareEpoch?: string;
  sessionId?: string;
  endpoint?: string;
  expiresAtMs?: number;
  display?: ShareStartDisplay;
  sourceEncrypted?: boolean;
  viewerConnected?: boolean;
  units?: number;
  bytes?: number;
  dropped?: number;
  resyncs?: number;
  keyframeRequests?: number;
  encrypted?: boolean;
  peerVerified?: boolean;
  message?: string;
}

export interface ShareInviteResult {
  ok: boolean;
  inviteCode?: string;
  shareEpoch?: string;
  message?: string;
}

export function shareReasonText(reason: string): string {
  switch (reason) {
    case 'user_stop': return '已主动停止转分享';
    case 'source_closed': return '源端会话已断开，转分享已停止';
    case 'source_replaced': return '源端会话被替换，转分享已停止';
    case 'display_list_changed': return '源端显示器配置发生变更，转分享已停止';
    case 'geometry_changed': return '分享屏幕的分辨率或几何尺寸改变，分享已停止';
    case 'codec_changed': return '源端视频编码格式变更，转分享已停止';
    case 'unsupported_codec': return '不支持该视频编码，转分享已停止';
    case 'lifecycle_fence': return '系统生命周期回收，转分享已停止';
    case 'invite_expired': return '分享邀请码已过期';
    case 'auth_failed': return '远端认证失败超限，转分享已停止';
    case 'viewer_gone': return '观看端已断开连接';
    case 'transport_failed': return '近场连接已中断，请重新分享';
    case 'send_failed': return '近场数据发送失败，分享已停止，请重新分享';
    case 'resync_timeout': return '重同步关键帧超时，转分享已停止';
    case 'internal': return '转分享内部异常，已停止';
    default: return reason || '转分享已停止';
  }
}
