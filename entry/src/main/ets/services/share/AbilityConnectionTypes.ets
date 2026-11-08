/**
 * Types and constants for the AbilityConnectionManager near-field data plane transport.
 *
 * Replaces LAN TCP / LinkEnhance assumptions with official
 * abilityConnectionManager.sendData(ArrayBuffer) as the primary near-field carrier.
 */
import { abilityConnectionManager } from '@kit.DistributedServiceKit';

/**
 * Well-known DMS collaboration Want keys.
 */
export const DMS_COLLABORATE_INDEX_KEY = 'ohos.extra.param.key.supportCollaborateIndex';
export const DMS_COLLAB_TOKEN_KEY = 'ohos.dms.collabToken';
export const DMS_PEER_INFO_KEY = 'PeerInfo';
export const DMS_CONNECT_OPTION_KEY = 'ConnectOption';

/** Default service name for Resk screen share collaboration */
export const DEFAULT_SHARE_SERVICE_NAME = 'resk_screen_share';

/** Transport lifecycle states */
export type AbilityTransportState =
  | 'idle'
  | 'connecting'
  | 'connected'
  | 'disconnecting'
  | 'disconnected'
  | 'failed';

/** Role in this collaboration session */
export type AbilityTransportRole = 'source' | 'sink';

/**
 * Parsed collaboration parameters from EntryAbility onCollaborate wantParam.
 */
export interface CollaborateParams {
  collabToken: string;
  peerInfo: abilityConnectionManager.PeerInfo;
  connectOptions?: abilityConnectionManager.ConnectOptions;
  customParameters?: Record<string, string>;
}

/**
 * Transport data telemetry and packet statistics.
 */
export interface AbilityTransportStats {
  bytesSent: number;
  framesSent: number;
  bytesReceived: number;
  framesReceived: number;
  lastSendTimestampMs: number;
  lastReceiveTimestampMs: number;
  lastSendError?: string;
  lastReceiveError?: string;
}

/**
 * Snapshot of current transport status.
 */
export interface AbilityTransportStatus {
  state: AbilityTransportState;
  role?: AbilityTransportRole;
  epoch: string;
  sessionId: number;
  peerInfo?: abilityConnectionManager.PeerInfo;
  stats: AbilityTransportStats;
}

/**
 * Listener for received binary frames.
 * The callback is provided the ArrayBuffer and the session epoch.
 */
export type FrameReceiveListener = (data: ArrayBuffer, epoch: string) => void;

/**
 * Listener for transport state and lifecycle transitions.
 */
export type StateChangeListener = (
  state: AbilityTransportState,
  epoch: string,
  reason?: string
) => void;
