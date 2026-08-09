import { rustDeskNativeApi as native } from './RustDeskNativeApi';
import {
  AccountActionResult,
  AccountLoginOptionsResult,
  AccountLoginProvider,
  AccountState,
  PeerRecord,
  PeerSource,
  ServerConfig,
} from './RustDeskDirectoryTypes';

interface AccountLoginPayload {
  username: string;
  password: string;
}

interface AccountVerificationPayload {
  challengeId: string;
  code: string;
}

export class RustDeskMainBridge {
  private directoryMessage: string = '';

  resetDirectoryMessage(): void {
    this.directoryMessage = '';
  }

  getDirectoryMessage(): string {
    return this.directoryMessage;
  }

  loadServerConfig(): ServerConfig {
    const fallback = new ServerConfig();
    try {
      const response: ESObject = JSON.parse(native.runtimeGetServerConfig());
      return this.copyServerConfig(response.config, false, String(response.message ?? ''));
    } catch (error) {
      fallback.message = String(error);
      return fallback;
    }
  }

  testServerConfig(config: ServerConfig): ServerConfig {
    return this.runServerConfigAction('runtimeTestServerConfig', config);
  }

  saveServerConfig(config: ServerConfig): ServerConfig {
    return this.runServerConfigAction('runtimeSetServerConfig', config);
  }

  loadAccountState(): AccountState {
    const state = new AccountState();
    try {
      const response: ESObject = JSON.parse(native.runtimeGetAccountState());
      state.loggedIn = Boolean(response.loggedIn);
      state.apiServer = String(response.apiServer ?? '').trim();
      let user: ESObject = response.user;
      if (user !== undefined && user !== null) {
        state.name = String(user.name ?? '').trim();
        state.displayName = String(user.displayName ?? '').trim();
        state.email = String(user.email ?? '').trim();
      }
    } catch (error) {
      state.message = String(error);
    }
    return state;
  }

  startAccountLogin(username: string, password: string): AccountActionResult {
    const payload: AccountLoginPayload = {
      username: username.trim(),
      password,
    };
    return this.parseAccountAction((): string => native.runtimeStartAccountLogin(JSON.stringify(payload)));
  }

  startAccountLoginOptions(): AccountActionResult {
    return this.parseAccountAction((): string => native.runtimeStartAccountLoginOptions());
  }

  pollAccountLoginOptions(): AccountLoginOptionsResult {
    const result = new AccountLoginOptionsResult();
    try {
      const response: ESObject = JSON.parse(native.runtimePollAccountLoginOptions());
      result.ok = Boolean(response.ok);
      result.state = String(response.state ?? 'idle');
      result.message = String(response.message ?? '');
      result.apiServer = String(response.apiServer ?? '').trim();
      let providers: ESObject = response.providers;
      if (providers !== undefined && providers !== null) {
        for (let index = 0; index < providers.length; index += 1) {
          let row: ESObject = providers[index];
          const provider = new AccountLoginProvider();
          provider.name = String(row.name ?? '').trim();
          provider.label = String(row.label ?? provider.name).trim();
          if (provider.name.length > 0) {
            result.providers.push(provider);
          }
        }
      }
    } catch (error) {
      result.message = String(error);
    }
    return result;
  }

  startAccountOidc(provider: string): AccountActionResult {
    return this.parseAccountAction((): string => native.runtimeStartAccountOidc(provider.trim()));
  }

  pollAccountOidc(): AccountActionResult {
    return this.parseAccountAction((): string => native.runtimePollAccountOidc());
  }

  cancelAccountOidc(): boolean {
    try {
      const response: ESObject = JSON.parse(native.runtimeCancelAccountOidc());
      return Boolean(response.ok);
    } catch (_) {
      return false;
    }
  }

  startAccountVerification(challengeId: string, code: string): AccountActionResult {
    const payload: AccountVerificationPayload = {
      challengeId,
      code: code.trim(),
    };
    return this.parseAccountAction((): string => native.runtimeStartAccountVerification(JSON.stringify(payload)));
  }

  pollAccountAction(): AccountActionResult {
    return this.parseAccountAction((): string => native.runtimePollAccountAction());
  }

  logoutAccount(): boolean {
    try {
      const response: ESObject = JSON.parse(native.runtimeAccountLogout());
      return Boolean(response.ok);
    } catch (_) {
      return false;
    }
  }

  cancelAccountChallenge(): boolean {
    try {
      const response: ESObject = JSON.parse(native.runtimeCancelAccountChallenge());
      return Boolean(response.ok);
    } catch (_) {
      return false;
    }
  }

  startAddressBookSync(): AccountActionResult {
    return this.parseAccountAction((): string => native.runtimeStartAddressBookSync());
  }

  pollAddressBookSync(): AccountActionResult {
    return this.parseAccountAction((): string => native.runtimePollAddressBookSync());
  }

  listRecentPeers(): PeerRecord[] {
    try {
      const response: ESObject = JSON.parse(native.runtimeListRecentPeers());
      if (!Boolean(response.ok)) {
        this.recordDirectoryError('最近设备', String(response.message ?? '读取失败'));
        return [];
      }
      return this.copyPeerRows(response.peers, 'recent', '', this.listFavorites());
    } catch (error) {
      this.recordDirectoryError('最近设备', String(error));
      return [];
    }
  }

  removeRecentPeer(peerId: string): boolean {
    try {
      const response: ESObject = JSON.parse(native.runtimeRemoveRecentPeer(peerId.trim()));
      return Boolean(response.ok) && Boolean(response.removed);
    } catch (_) {
      return false;
    }
  }

  listFavorites(): string[] {
    try {
      const response: ESObject = JSON.parse(native.runtimeListFavorites());
      if (!Boolean(response.ok)) {
        this.recordDirectoryError('收藏设备', String(response.message ?? '读取失败'));
        return [];
      }
      return this.copyStringArray(response.favorites);
    } catch (error) {
      this.recordDirectoryError('收藏设备', String(error));
      return [];
    }
  }

  setFavorite(peerId: string, favorite: boolean): boolean {
    try {
      const response: ESObject = JSON.parse(native.runtimeSetFavorite(peerId.trim(), favorite));
      return Boolean(response.ok);
    } catch (_) {
      return false;
    }
  }

  scanLan(): boolean {
    try {
      const response: ESObject = JSON.parse(native.runtimeScanLanPeers());
      return Boolean(response.ok);
    } catch (_) {
      return false;
    }
  }

  listLanPeers(): PeerRecord[] {
    try {
      const response: ESObject = JSON.parse(native.runtimeListLanPeers());
      if (!Boolean(response.ok)) {
        this.recordDirectoryError('局域网设备', String(response.message ?? '读取失败'));
        return [];
      }
      return this.copyPeerRows(response.peers, 'lan', '', this.listFavorites());
    } catch (error) {
      this.recordDirectoryError('局域网设备', String(error));
      return [];
    }
  }

  listAddressBookPeers(): PeerRecord[] {
    try {
      const response: ESObject = JSON.parse(native.runtimeListAddressBookPeers());
      if (!Boolean(response.ok)) {
        this.recordDirectoryError('通讯簿', String(response.message ?? '读取失败'));
        return [];
      }
      const favorites = this.listFavorites();
      const records: PeerRecord[] = [];
      let addressBooks: ESObject = response.addressBooks;
      if (addressBooks === undefined || addressBooks === null) {
        return records;
      }
      for (let index = 0; index < addressBooks.length; index += 1) {
        let addressBook: ESObject = addressBooks[index];
        const name = String(addressBook.name ?? '').trim();
        const peers = this.copyPeerRows(addressBook.peers, 'addressBook', name, favorites);
        for (let peerIndex = 0; peerIndex < peers.length; peerIndex += 1) {
          records.push(peers[peerIndex]);
        }
      }
      return records;
    } catch (error) {
      this.recordDirectoryError('通讯簿', String(error));
      return [];
    }
  }

  private recordDirectoryError(scope: string, message: string): void {
    const detail = message.trim().length > 0 ? message.trim() : '读取失败';
    const entry = `${scope}：${detail}`;
    if (this.directoryMessage.includes(entry)) {
      return;
    }
    this.directoryMessage = this.directoryMessage.length > 0
      ? `${this.directoryMessage} · ${entry}`
      : entry;
  }

  private runServerConfigAction(exportName: string, config: ServerConfig): ServerConfig {
    const fallback = this.copyServerConfig(config as ESObject, false, '');
    try {
      let response: ESObject;
      const payload = JSON.stringify(config);
      if (exportName === 'runtimeTestServerConfig') {
        response = JSON.parse(native.runtimeTestServerConfig(payload));
      } else {
        response = JSON.parse(native.runtimeSetServerConfig(payload));
      }
      let source: ESObject = response.config;
      if (source === undefined || source === null) {
        source = config as ESObject;
      }
      return this.copyServerConfig(source, Boolean(response.ok), this.serverResponseMessage(response));
    } catch (error) {
      fallback.message = String(error);
      return fallback;
    }
  }

  private copyServerConfig(source: ESObject, reachable: boolean, message: string): ServerConfig {
    const config = new ServerConfig();
    if (source === undefined || source === null) {
      config.remoteReachable = reachable;
      config.message = message;
      return config;
    }
    config.mode = 'custom';
    config.idServer = String(source.idServer ?? '').trim();
    config.relayServer = String(source.relayServer ?? '').trim();
    config.apiServer = String(source.apiServer ?? '').trim();
    config.key = String(source.key ?? '').trim();
    config.effectiveApiServer = String(source.effectiveApiServer ?? config.apiServer).trim();
    config.usingPublicServer = false;
    config.remoteReachable = source.remoteReachable === undefined
      ? reachable
      : Boolean(source.remoteReachable);
    config.accountAvailable = source.accountAvailable === undefined
      ? false
      : Boolean(source.accountAvailable);
    config.message = message.length > 0 ? message : String(source.message ?? '');
    return config;
  }

  private serverResponseMessage(response: ESObject): string {
    const message = String(response.message ?? '').trim();
    if (Boolean(response.ok)) {
      return message;
    }
    let errors: ESObject = response.errors;
    if (errors === undefined || errors === null) {
      return message;
    }
    const details: string[] = [];
    const idError = String(errors.idServer ?? '').trim();
    const relayError = String(errors.relayServer ?? '').trim();
    const apiError = String(errors.apiServer ?? '').trim();
    if (idError.length > 0) {
      details.push(`ID Server: ${idError}`);
    }
    if (relayError.length > 0) {
      details.push(`Relay Server: ${relayError}`);
    }
    if (apiError.length > 0) {
      details.push(`API Server: ${apiError}`);
    }
    return details.length > 0 ? details.join(' · ') : message;
  }

  private parseAccountAction(call: () => string): AccountActionResult {
    const result = new AccountActionResult();
    try {
      const response: ESObject = JSON.parse(call());
      result.ok = Boolean(response.ok);
      result.state = String(response.state ?? 'idle');
      result.message = String(response.message ?? '');
      result.challengeId = String(response.challengeId ?? '');
      result.challengeType = String(response.challengeType ?? '');
      result.emailHint = String(response.emailHint ?? '');
      result.url = String(response.url ?? '').trim();
      result.stateMessage = String(response.stateMessage ?? '');
      result.provider = String(response.provider ?? '').trim();
      result.addressBookCount = Number(response.addressBookCount ?? 0);
      result.peerCount = Number(response.peerCount ?? 0);
      let user: ESObject = response.user;
      if (user !== undefined && user !== null) {
        result.name = String(user.name ?? '').trim();
        result.displayName = String(user.displayName ?? '').trim();
        result.email = String(user.email ?? '').trim();
      }
    } catch (error) {
      result.message = String(error);
    }
    return result;
  }

  private copyPeerRows(
    source: ESObject,
    peerSource: PeerSource,
    addressBookName: string,
    favorites: string[],
  ): PeerRecord[] {
    const records: PeerRecord[] = [];
    if (source === undefined || source === null) {
      return records;
    }
    for (let index = 0; index < source.length; index += 1) {
      let row: ESObject = source[index];
      const record = new PeerRecord();
      record.id = String(row.id ?? '').trim();
      if (record.id.length === 0) {
        continue;
      }
      record.username = String(row.username ?? '').trim();
      record.hostname = String(row.hostname ?? '').trim();
      record.platform = String(row.platform ?? '').trim();
      record.alias = String(row.alias ?? '').trim();
      record.lanIp = String(row.ip ?? '').trim();
      record.source = peerSource;
      record.addressBookName = addressBookName;
      record.tags = this.copyStringArray(row.tags);
      record.online = row.online === undefined ? peerSource === 'lan' : Boolean(row.online);
      record.favorite = this.containsString(favorites, record.id);
      records.push(record);
    }
    return records;
  }

  private copyStringArray(source: ESObject): string[] {
    const values: string[] = [];
    if (source === undefined || source === null) {
      return values;
    }
    for (let index = 0; index < source.length; index += 1) {
      const value = String(source[index] ?? '').trim();
      if (value.length > 0) {
        values.push(value);
      }
    }
    return values;
  }

  private containsString(values: string[], expected: string): boolean {
    for (let index = 0; index < values.length; index += 1) {
      if (values[index] === expected) {
        return true;
      }
    }
    return false;
  }
}
