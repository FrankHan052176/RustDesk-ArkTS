export const DOMAIN = 0xFF01;
export const TAG = 'RustDeskIndex';
export const EVENT_POLL_INTERVAL_MS = 50;
export const MAX_PREVIEW_LONG_EDGE = 1280;
export const PASSWORD_TIMEOUT_MS = 60000;

export interface BridgeSummary {
  integrationStage: string;
  upstreamRepo: string;
  notes: string;
}

export interface SessionSnapshot {
  sessionId: string;
  coreSessionId?: string;
  phase: string;
  lastError?: string;
}

export interface ActionResponse {
  ok: boolean;
  action: string;
  message?: string;
  session?: SessionSnapshot;
  events?: NativeEvent[];
}

export interface NativeEvent {
  name: string;
  content?: string;
  paths?: Array<string>;
  type?: string;
  secure?: string;
  direct?: string;
  stream_type?: string;
  id?: string;
  hostname?: string;
  platform?: string;
  version?: string;
  keyboard?: string;
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
  x?: string;
  y?: string;
  hotx?: string;
  hoty?: string;
  colors?: string;
  gpu_texture?: boolean;
  speed?: string;
  target_bitrate?: string;
  chroma?: string;
  value?: string;
  is_local?: string;
  file_num?: string;
  finished_size?: string;
  err?: string;
  read_path?: string;
  is_upload?: string;
  is_identical?: string;
}

export interface PeerDisplayInfo {
  width: number;
  height: number;
  x: number;
  y: number;
  cursor_embedded?: number;
  original_width?: number;
  original_height?: number;
  scaled_width?: number;
  scaled_height?: number;
}

export interface ResolutionInfo {
  width: number;
  height: number;
}

export class DecoderCapability {
  codec: string = '';
  mime: string = '';
  mimeAvailable: boolean = false;
  recommendedAvailable: boolean = false;
  recommendedName: string = '';
  recommendedIsHardware: boolean = false;
  hardwareAvailable: boolean = false;
  hardwareName: string = '';
  softwareAvailable: boolean = false;
  softwareName: string = '';
}

export interface SavedConnectionSettings {
  target: string;
  password: string;
  rememberPassword: boolean;
}
