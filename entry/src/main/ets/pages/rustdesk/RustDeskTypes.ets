export const DOMAIN = 0xFF01;
export const TAG = 'RustDeskIndex';
export const EVENT_POLL_INTERVAL_MS = 50;
export const RENDER_STATS_POLL_INTERVAL_MS = 1000;
export const MAX_PREVIEW_LONG_EDGE = 1280;
export const PASSWORD_TIMEOUT_MS = 60000;

export interface BridgeSummary {
  integrationStage: string;
  upstreamRepo: string;
  upstreamPath?: string;
  nativeCrate: string;
  nativePackage: string;
  plannedModules: string[];
  nextSteps: string[];
  notes: string;
}

export interface SessionSnapshot {
  sessionId: string;
  coreSessionId?: string;
  peerTarget: string;
  normalizedPeerId: string;
  phase: string;
  lastAction: string;
  lastError?: string;
  selectedDisplays: number[];
}

export interface ActionResponse {
  ok: boolean;
  action: string;
  message?: string;
  session?: SessionSnapshot;
  events?: NativeEvent[];
  stats?: RenderStatsResponse;
}

export interface RenderStatsResponse {
  display: number;
  stats: RenderStatsSnapshot;
}

export interface RenderStatsSnapshot {
  fps: number;
  totalFrames: number;
  lastFrameAgeMs: number;
  hasRenderedFrame: boolean;
}

export interface NativeEvent {
  name: string;
  type?: string;
  secure?: string;
  direct?: string;
  stream_type?: string;
  id?: string;
  hostname?: string;
  platform?: string;
  version?: string;
  displays?: string;
  resolutions?: string;
  current_display?: string;
  title?: string;
  text?: string;
  display?: number;
  width?: string;
  height?: string;
  fps?: string;
  delay?: string;
  codec_format?: string;
}

export interface PeerDisplayInfo {
  width: number;
  height: number;
  x: number;
  y: number;
}

export interface ResolutionInfo {
  width: number;
  height: number;
}

export interface DecoderCapability {
  codec: string;
  mime: string;
  recommendedAvailable: boolean;
  recommendedName: string;
  recommendedIsHardware: boolean;
  hardwareAvailable: boolean;
  hardwareName: string;
  softwareAvailable: boolean;
  softwareName: string;
}

export interface DecoderCapabilityResponse {
  buildMarker: string;
  capabilities: DecoderCapability[];
}

export interface SavedConnectionSettings {
  target: string;
  password: string;
  rememberPassword: boolean;
}
