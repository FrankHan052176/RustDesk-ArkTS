export type TransferDirection = 'upload' | 'download';
export type TransferState = 'queued' | 'running' | 'awaiting_override' | 'completed' | 'failed' | 'cancelled';

export interface SessionStartOptions {
  password: string;
  connToken?: string;
  forceRelay: boolean;
  isFileTransfer: boolean;
  isViewCamera: boolean;
  isViewOnly: boolean;
  passwordEphemeral?: boolean;
}

export interface RemoteFileEntry {
  entry_type: number;
  name: string;
  size: number;
  modified_time: number;
}

export interface RemoteFileDirectory {
  id: number;
  path: string;
  entries: RemoteFileEntry[];
}

export interface LocalFileEntry {
  name: string;
  path: string;
  size: number;
}

export interface ChatMessage {
  localId: string;
  text: string;
  sentAt: number;
  outgoing: boolean;
  state: 'pending' | 'sent' | 'failed';
}

export interface TransferItem {
  id: number;
  fileNum: number;
  direction: TransferDirection;
  sourcePath: string;
  destinationPath: string;
  fileName: string;
  totalBytes: number;
  transferredBytes: number;
  speedBytesPerSecond: number;
  state: TransferState;
  errorText: string;
}

export interface QualityTelemetry {
  fps: string;
  delay: string;
  codec: string;
  speed: string;
  targetBitrate: string;
  chroma: string;
}

export interface RemoteAudioState {
  available: boolean;
  muted: boolean;
  rendererActive: boolean;
  errorText: string;
}

export interface DownloadRoot {
  uri: string;
  path: string;
}
