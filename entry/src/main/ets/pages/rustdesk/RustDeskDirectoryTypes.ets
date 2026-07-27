export type ServerMode = 'official' | 'custom';
export type PeerSource = 'recent' | 'addressBook' | 'lan';

export class ServerConfig {
  mode: ServerMode = 'official';
  idServer: string = '';
  relayServer: string = '';
  apiServer: string = '';
  key: string = '';
  effectiveApiServer: string = '';
  usingPublicServer: boolean = true;
  remoteReachable: boolean = false;
  accountAvailable: boolean = false;
  message: string = '';
}

export class PeerRecord {
  id: string = '';
  username: string = '';
  hostname: string = '';
  platform: string = '';
  alias: string = '';
  source: PeerSource = 'recent';
  addressBookName: string = '';
  tags: string[] = [];
  online: boolean = false;
  favorite: boolean = false;
}

export class DirectorySnapshot {
  recent: PeerRecord[] = [];
  addressBook: PeerRecord[] = [];
  lan: PeerRecord[] = [];
  favorites: string[] = [];
  lanScanning: boolean = false;
  message: string = '';
}

export class SessionDefaults {
  relativeMouseMode: boolean = false;
  audioEnabled: boolean = true;
  clipboardEnabled: boolean = true;
  qualityPreset: string = 'balanced';
  customQuality: number = 50;
  customFps: number = 30;
  preferredCodec: string = 'auto';
  gesturesEnabled: boolean = true;
  toolbarExpanded: boolean = false;
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
