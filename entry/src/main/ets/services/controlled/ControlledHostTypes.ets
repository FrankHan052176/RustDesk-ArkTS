export type ControlledHostPhase = 'disabled' | 'starting' | 'ready' | 'incoming' | 'active' | 'stopping' |
  'failed';
export type ControlledPasswordMode = 'use-temporary-password' | 'use-permanent-password' | 'use-both-passwords';

export const PASSWORD_MODE_TEMPORARY: ControlledPasswordMode = 'use-temporary-password';
export const PASSWORD_MODE_PERMANENT: ControlledPasswordMode = 'use-permanent-password';
export const PASSWORD_MODE_BOTH: ControlledPasswordMode = 'use-both-passwords';

export class ControlledIncomingPeer {
  requestId: string = '';
  peerId: string = '';
  peerName: string = '';
  authorized: boolean = false;
}

export class ControlledTrustedDevice {
  hwid: number[] = [];
  time: number = 0;
  id: string = '';
  name: string = '';
  platform: string = '';
}

@ObservedV2
export class ControlledTwoFactorState {
  @Trace enabled: boolean = false;
  @Trace setupUri: string = '';
  @Trace verificationCode: string = '';
  @Trace trustedDevicesEnabled: boolean = true;
  @Trace trustedDevicesFixed: boolean = false;
  @Trace trustedDevices: ControlledTrustedDevice[] = [];
  @Trace busy: boolean = false;
  @Trace errorText: string = '';
}

@ObservedV2
export class ControlledHostState {
  @Trace phase: ControlledHostPhase = 'disabled';
  @Trace myId: string = '';
  @Trace temporaryPassword: string = '';
  @Trace verificationMethod: ControlledPasswordMode = PASSWORD_MODE_BOTH;
  @Trace permanentPasswordSet: boolean = false;
  @Trace localPermanentPasswordSet: boolean = false;
  @Trace verificationMethodFixed: boolean = false;
  @Trace permanentPasswordChangeDisabled: boolean = false;
  @Trace maxPasswordLength: number = 128;
  @Trace passwordError: string = '';
  @Trace statusText: string = '被看服务未启用';
  @Trace lastError: string = '';
  @Trace incoming: ControlledIncomingPeer | undefined = undefined;
  @Trace activePeerName: string = '';
  @Trace captureActive: boolean = false;
  @Trace runningInBackground: boolean = false;
}

export type ControlledHostStateListener = (state: ControlledHostState) => void;

export interface ControlledNativeActionPayload {
  ok?: boolean;
  active?: boolean;
  nativeStateCode?: number;
  framesObserved?: number;
  audioFramesObserved?: number;
  audioFramesForwarded?: number;
  message?: string;
  lastError?: string;
}

export interface ControlledPasswordPayload extends ControlledNativeActionPayload {
  temporaryPassword?: string;
  verificationMethod?: string;
  permanentPasswordSet?: boolean;
  localPermanentPasswordSet?: boolean;
  verificationMethodFixed?: boolean;
  permanentPasswordChangeDisabled?: boolean;
  maxPasswordLength?: number;
}

export interface ControlledServerStatusPayload extends ControlledNativeActionPayload {
  state?: string;
  serverRunning?: boolean;
  myId?: string;
  temporaryPassword?: string;
  clientCount?: number;
}

export interface ControlledIncomingPayload {
  clients?: ControlledIncomingPeer[];
  requests?: ControlledIncomingPeer[];
}

export interface ControlledTwoFactorPayload extends ControlledNativeActionPayload {
  enabled?: boolean;
  uri?: string;
  trustedDevicesEnabled?: boolean;
  trustedDevicesFixed?: boolean;
  trustedDevices?: ControlledTrustedDevice[];
}
