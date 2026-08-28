export type ServerMode = 'custom';
export type ServerEndpointTestState = 'untested' | 'success' | 'error';
export type PeerSource = 'recent' | 'addressBook' | 'lan';
export type RustDeskInputMode = 'touch' | 'mouse' | 'relative';
export type RustDeskRightClickGesture = 'double_tap' | 'two_finger_tap' | 'long_press';

export class ServerConfig {
  mode: ServerMode = 'custom';
  idServer: string = '';
  relayServer: string = '';
  apiServer: string = '';
  key: string = '';
  effectiveApiServer: string = '';
  usingPublicServer: boolean = false;
  remoteReachable: boolean = false;
  accountAvailable: boolean = false;
  resultState: string = 'idle';
  message: string = '';
  idServerTestState: ServerEndpointTestState = 'untested';
  relayServerTestState: ServerEndpointTestState = 'untested';
  apiServerTestState: ServerEndpointTestState = 'untested';
  idServerTestMessage: string = '';
  relayServerTestMessage: string = '';
  apiServerTestMessage: string = '';
}

@ObservedV2
export class PeerRecord {
  id: string = '';
  targetId: string = '';
  username: string = '';
  hostname: string = '';
  platform: string = '';
  alias: string = '';
  lanIp: string = '';
  source: PeerSource = 'recent';
  addressBookName: string = '';
  tags: string[] = [];
  @Trace online: boolean = false;
  @Trace onlineKnown: boolean = false;
  @Trace favorite: boolean = false;
}

export class DirectorySnapshot {
  revision: number = 0;
  recent: PeerRecord[] = [];
  addressBook: PeerRecord[] = [];
  lan: PeerRecord[] = [];
  favorites: string[] = [];
  lanScanning: boolean = false;
  message: string = '';
}

export class PeerOnlineStatusResult {
  ok: boolean = false;
  onlines: string[] = [];
  offlines: string[] = [];
  unknowns: string[] = [];
  message: string = '';
}

export class PeerDirectProbeTarget {
  key: string = '';
  target: string = '';
}

export class SessionDefaults {
  touchMode: boolean = true;
  relativeMouseMode: boolean = false;
  rightClickGesture: RustDeskRightClickGesture = 'two_finger_tap';
  audioEnabled: boolean = true;
  clipboardEnabled: boolean = true;
  qualityPreset: string = 'balanced';
  customQuality: number = 50;
  customFps: number = 30;
  preferredCodec: string = 'auto';
  gesturesEnabled: boolean = true;
  toolbarExpanded: boolean = false;
  sessionSharingEnabled: boolean = false;
}

export class AccountState {
  loggedIn: boolean = false;
  apiServer: string = '';
  name: string = '';
  displayName: string = '';
  email: string = '';
  busy: boolean = false;
  syncing: boolean = false;
  challengeId: string = '';
  challengeType: string = '';
  emailHint: string = '';
  oidcProvider: string = '';
  message: string = '';
}

export class AccountLoginProvider {
  name: string = '';
  label: string = '';
}

export class AccountLoginOptionsResult {
  ok: boolean = false;
  state: string = 'idle';
  message: string = '';
  apiServer: string = '';
  providers: AccountLoginProvider[] = [];
}

export class AccountActionResult {
  ok: boolean = false;
  state: string = 'idle';
  message: string = '';
  challengeId: string = '';
  challengeType: string = '';
  emailHint: string = '';
  name: string = '';
  displayName: string = '';
  email: string = '';
  url: string = '';
  stateMessage: string = '';
  provider: string = '';
  addressBookCount: number = 0;
  peerCount: number = 0;
}
