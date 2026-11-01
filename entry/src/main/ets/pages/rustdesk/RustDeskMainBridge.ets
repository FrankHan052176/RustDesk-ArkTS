import { rustDeskNativeApi as native } from './RustDeskNativeApi';
import {
  ApprovedServerProfile,
  DirectoryReadReply,
  DirectoryWriteReply,
  NativeRecentPeerRow,
  PeerOnlineStatusResult,
  PeerRecord,
  PeerSource,
  ServerConfig,
  ServerEndpointTestState,
  ServerMode,
  ServerProfileReply,
} from './RustDeskDirectoryTypes';
import { peerProtocolOf } from './RustDeskPeerDirectoryModel';
import { deviceConnectionTarget } from './SavedDeviceModel';
import {
  RustDeskLanReply,
  rustDeskRuntimeController,
} from '../../services/RustDeskRuntimeController';

/** The four wire fields the engine's profile grammar accepts; UI-only fields never travel. */
interface NativeServerProfileFields {
  mode: ServerMode;
  idServer: string;
  relayServer: string;
  key: string;
}

export class RustDeskMainBridge {
  private directoryMessage: string = '';

  resetDirectoryMessage(): void {
    this.directoryMessage = '';
  }

  getDirectoryMessage(): string {
    return this.directoryMessage;
  }

  recordDirectoryMessage(scope: string, message: string): void {
    this.recordDirectoryError(scope, message);
  }

  /**
   * Reads the profile the engine itself saved.
   *
   * `ok` is the read, `approved` is the persisted explicit approval. A successful
   * read with `approved:false` is an empty store, not an official default, and it
   * never becomes an approval here.
   */
  async loadServerConfig(): Promise<ServerProfileReply> {
    const reply = new ServerProfileReply();
    reply.action = 'get_server_config';
    try {
      const response: ESObject = JSON.parse(await native.runtimeGetServerConfig());
      reply.ok = response.ok === true;
      const message = String(response.message ?? '').trim();
      reply.message = message;
      if (!reply.ok) {
        reply.error = String(response.error ?? '').trim() || message || '无法读取已保存的服务器配置';
        return reply;
      }
      if (response.approved !== true) {
        reply.config = new ServerConfig();
        reply.message = '尚无已明确保存的服务器配置';
        return reply;
      }
      const profile = ApprovedServerProfile.fromNative(response.approvedProfile);
      if (profile === undefined) {
        reply.ok = false;
        reply.error = '引擎返回的已批准服务器配置不完整';
        return reply;
      }
      reply.approved = true;
      reply.approvedProfile = profile;
      reply.revision = profile.revision;
      reply.config = this.copySavedServerConfig(response.config, '已读取引擎明确保存的配置；这里不检测服务器可达性');
      return reply;
    } catch (error) {
      reply.error = String(error);
      return reply;
    }
  }

  /**
   * Probes the configured endpoints over TCP; it saves nothing and approves nothing.
   *
   * `remoteReachable` reports only what those connects did. The engine has no API
   * server, so an API probe stays `untested` and official mode is never treated as
   * reachable by itself.
   */
  async testServerConfig(config: ServerConfig): Promise<ServerConfig> {
    const result = this.copyConfig(config);
    try {
      const response: ESObject = JSON.parse(
        await native.runtimeTestServerConfig(JSON.stringify(this.wireProfile(config))),
      );
      const ok = response.ok === true;
      result.remoteReachable = ok;
      result.resultState = ok ? 'success' : 'error';
      result.message = this.serverResponseMessage(response);
      this.applyEndpointTestResults(result, response.errors, ok);
      return result;
    } catch (error) {
      const message = String(error);
      result.remoteReachable = false;
      result.resultState = 'error';
      result.message = message;
      this.markConfiguredEndpointsFailed(result, message);
      return result;
    }
  }

  /**
   * The explicit-save act: the engine persists the profile and returns the
   * approved route it committed. Nothing short of `ok && approved && committed`
   * may be adopted by the caller.
   */
  async saveServerConfig(config: ServerConfig): Promise<ServerProfileReply> {
    const reply = new ServerProfileReply();
    reply.action = 'set_server_config';
    try {
      const response: ESObject = JSON.parse(
        await native.runtimeSetServerConfig(JSON.stringify(this.wireProfile(config))),
      );
      reply.message = String(response.message ?? '').trim();
      const committed = response.ok === true && response.approved === true &&
        response.committed === true;
      if (!committed) {
        reply.error = String(response.error ?? '').trim() || reply.message || '引擎未确认这次保存';
        return reply;
      }
      const profile = ApprovedServerProfile.fromNative(response.approvedProfile);
      if (profile === undefined) {
        reply.error = '引擎保存回执缺少完整的已批准配置';
        return reply;
      }
      reply.ok = true;
      reply.approved = true;
      reply.committed = true;
      reply.approvedProfile = profile;
      reply.revision = profile.revision;
      reply.config = this.copySavedServerConfig(response.config, reply.message);
      return reply;
    } catch (error) {
      reply.error = String(error);
      return reply;
    }
  }

  /** Lists the rows the engine stored after this client observed sessions. */
  async listRecentPeers(favorites: string[] = []): Promise<DirectoryReadReply> {
    const reply = new DirectoryReadReply();
    reply.action = 'list_recent_peers';
    try {
      const response: ESObject = JSON.parse(await native.runtimeListRecentPeers());
      this.readDirectoryReply(reply, response, '读取最近设备失败');
      if (reply.ok) {
        reply.peers = this.copyPeerRows(response.peers, 'recent', favorites);
      }
      return reply;
    } catch (error) {
      reply.error = String(error);
      return reply;
    }
  }

  /** Lists the favourite targets the engine stored, in insertion order. */
  async listFavorites(): Promise<DirectoryReadReply> {
    const reply = new DirectoryReadReply();
    reply.action = 'list_favorites';
    try {
      const response: ESObject = JSON.parse(await native.runtimeListFavorites());
      this.readDirectoryReply(reply, response, '读取收藏设备失败');
      if (reply.ok) {
        reply.favorites = this.copyStringArray(response.favorites);
      }
      return reply;
    } catch (error) {
      reply.error = String(error);
      return reply;
    }
  }

  async setFavorite(peer: PeerRecord, favorite: boolean): Promise<DirectoryWriteReply> {
    const reply = new DirectoryWriteReply();
    reply.action = 'set_favorite';
    const id = this.directoryPeerId(peer);
    if (id.length === 0) {
      reply.error = '收藏目标缺少可用标识';
      return reply;
    }
    try {
      const response: ESObject = JSON.parse(await native.runtimeSetFavorite(id, favorite));
      this.readDirectoryWrite(reply, response, '引擎未写入收藏');
      return reply;
    } catch (error) {
      reply.error = String(error);
      return reply;
    }
  }

  /** Persists one peer this client really observed; it never infers a success time. */
  async recordRecentPeer(peer: PeerRecord): Promise<DirectoryWriteReply> {
    const reply = new DirectoryWriteReply();
    reply.action = 'record_recent_peer';
    const id = this.directoryPeerId(peer);
    if (id.length === 0) {
      reply.error = '最近设备缺少可用标识';
      return reply;
    }
    const row: NativeRecentPeerRow = {
      id: id,
      protocol: peerProtocolOf(peer),
      address: peer.address,
      port: Number.isFinite(peer.port) && peer.port > 0 ? Math.round(peer.port) : 0,
      username: peer.username,
      hostname: peer.hostname,
      platform: peer.platform,
      alias: peer.alias,
      note: peer.note,
      lastSuccessAt: Number.isSafeInteger(peer.lastSuccessAt) && peer.lastSuccessAt > 0
        ? peer.lastSuccessAt : 0,
    };
    try {
      const response: ESObject = JSON.parse(await native.runtimeRecordRecentPeer(JSON.stringify(row)));
      this.readDirectoryWrite(reply, response, '引擎未写入最近设备');
      return reply;
    } catch (error) {
      reply.error = String(error);
      return reply;
    }
  }

  async removeRecentPeer(peer: PeerRecord): Promise<DirectoryWriteReply> {
    const reply = new DirectoryWriteReply();
    reply.action = 'remove_recent_peer';
    const id = this.directoryPeerId(peer);
    if (id.length === 0) {
      reply.error = '最近设备缺少可用标识';
      return reply;
    }
    try {
      const response: ESObject = JSON.parse(await native.runtimeRemoveRecentPeer(id));
      this.readDirectoryWrite(reply, response, '引擎未删除最近设备');
      return reply;
    } catch (error) {
      reply.error = String(error);
      return reply;
    }
  }

  /**
   * Asks hbbs whether these ids are online, against one explicitly saved profile.
   *
   * Without that approval hbbs is not asked at all and no id may be published as
   * online or offline. `queryGeneration` is the engine's own token for an answered
   * query, so a reply that carries none decides nothing.
   */
  async queryPeerOnlineStates(peerIds: string[],
    profile: ApprovedServerProfile | undefined): Promise<PeerOnlineStatusResult> {
    const result = new PeerOnlineStatusResult();
    if (profile === undefined) {
      result.message = '服务器配置尚未明确保存，未查询 RustDesk 在线状态';
      return result;
    }
    try {
      const response: ESObject = JSON.parse(await native.peerQueryOnline(
        JSON.stringify(peerIds),
        JSON.stringify(profile),
      ));
      result.ok = response.ok === true;
      result.queryGeneration = String(response.queryGeneration ?? '').trim();
      result.message = String(response.error ?? '').trim() || String(response.message ?? '').trim();
      if (result.ok) {
        result.onlines = this.copyStringArray(response.online);
        result.offlines = this.copyStringArray(response.offline);
      }
      return result;
    } catch (error) {
      result.message = String(error);
      return result;
    }
  }

  removeDiscoveredPeer(peerId: string): Promise<RustDeskLanReply | undefined> {
    return rustDeskRuntimeController.removeLanPeer(peerId.trim());
  }

  scanLan(): Promise<RustDeskLanReply | undefined> {
    return rustDeskRuntimeController.startLanScan();
  }

  queryLanPeers(): Promise<RustDeskLanReply | undefined> {
    return rustDeskRuntimeController.queryLanPeers();
  }

  stopLan(): Promise<RustDeskLanReply | undefined> {
    return rustDeskRuntimeController.stopLanScan();
  }

  // Synchronous projection only: no native I/O and no invented query success.
  // The controller publishes rows only after owner/scan/call/revision matching.
  listLanPeers(favorites: string[] = []): PeerRecord[] {
    const state = rustDeskRuntimeController.state();
    if (state.error.length > 0) {
      this.recordDirectoryError('局域网设备', state.error);
    }
    const reply = state.lan;
    if (!state.discoveryAllowed || reply === undefined || !reply.ok ||
      reply.ownerGeneration !== state.ownerGeneration || reply.scanId !== state.scanId) {
      return [];
    }
    return this.copyPeerRows(reply.peers as ESObject, 'lan', favorites);
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

  private wireProfile(config: ServerConfig): NativeServerProfileFields {
    const fields: NativeServerProfileFields = {
      mode: config.mode,
      idServer: config.idServer.trim(),
      relayServer: config.relayServer.trim(),
      key: config.key.trim(),
    };
    return fields;
  }

  /** The directory's identity for a row, computed once so every write names the same key. */
  private directoryPeerId(peer: PeerRecord): string {
    return deviceConnectionTarget(peer).trim();
  }

  private readDirectoryReply(reply: DirectoryReadReply, response: ESObject, fallback: string): void {
    reply.ok = response.ok === true;
    reply.action = String(response.action ?? '').trim() || reply.action;
    reply.source = String(response.source ?? '').trim();
    reply.exists = response.exists === true;
    const revision = Number(response.revision);
    reply.revision = Number.isSafeInteger(revision) ? revision : 0;
    if (!reply.ok) {
      reply.error = String(response.error ?? '').trim() || fallback;
    }
  }

  private readDirectoryWrite(reply: DirectoryWriteReply, response: ESObject, fallback: string): void {
    reply.ok = response.ok === true;
    reply.action = String(response.action ?? '').trim() || reply.action;
    const revision = Number(response.revision);
    reply.revision = Number.isSafeInteger(revision) ? revision : 0;
    if (!reply.ok) {
      reply.error = String(response.error ?? '').trim() || fallback;
    }
  }

  /**
   * Copies an engine-normalized profile into the card's shape.
   *
   * The engine owns mode/idServer/relayServer/key only: it has no API server and
   * no account capability, so those probes stay `untested` and unreachable.
   */
  private copySavedServerConfig(source: ESObject, message: string): ServerConfig {
    const config = new ServerConfig();
    if (source === undefined || source === null) {
      config.message = message;
      return config;
    }
    config.mode = String(source.mode ?? '').trim() === 'custom' ? 'custom' : 'official';
    config.idServer = String(source.idServer ?? '').trim();
    config.relayServer = String(source.relayServer ?? '').trim();
    config.key = String(source.key ?? '').trim();
    config.usingPublicServer = config.mode === 'official';
    config.apiServer = '';
    config.effectiveApiServer = '';
    config.accountAvailable = false;
    config.remoteReachable = false;
    config.resultState = '';
    config.message = message;
    return config;
  }

  private copyConfig(source: ServerConfig): ServerConfig {
    const config = new ServerConfig();
    config.mode = source.mode;
    config.idServer = source.idServer;
    config.relayServer = source.relayServer;
    config.apiServer = source.apiServer;
    config.key = source.key;
    config.effectiveApiServer = source.effectiveApiServer;
    config.usingPublicServer = source.usingPublicServer;
    config.remoteReachable = source.remoteReachable;
    config.accountAvailable = source.accountAvailable;
    config.resultState = source.resultState;
    config.message = source.message;
    config.idServerTestState = source.idServerTestState;
    config.relayServerTestState = source.relayServerTestState;
    config.apiServerTestState = source.apiServerTestState;
    config.idServerTestMessage = source.idServerTestMessage;
    config.relayServerTestMessage = source.relayServerTestMessage;
    config.apiServerTestMessage = source.apiServerTestMessage;
    return config;
  }

  private endpointTestState(value: string, error: string, ok: boolean,
    hasEndpointResult: boolean): ServerEndpointTestState {
    if (value.trim().length === 0) {
      return 'untested';
    }
    if (error.length > 0) {
      return 'error';
    }
    if (ok || hasEndpointResult) {
      return 'success';
    }
    return 'error';
  }

  private applyEndpointTestResults(config: ServerConfig, rawErrors: ESObject, ok: boolean): void {
    let idError = '';
    let relayError = '';
    let apiError = '';
    if (rawErrors !== undefined && rawErrors !== null) {
      idError = String(rawErrors.idServer ?? '').trim();
      relayError = String(rawErrors.relayServer ?? '').trim();
      apiError = String(rawErrors.apiServer ?? '').trim();
    }
    const hasEndpointResult = idError.length > 0 || relayError.length > 0 || apiError.length > 0;
    config.idServerTestState = this.endpointTestState(config.idServer, idError, ok, hasEndpointResult);
    config.relayServerTestState = this.endpointTestState(config.relayServer, relayError, ok, hasEndpointResult);
    config.apiServerTestState = 'untested';
    config.idServerTestMessage = idError;
    config.relayServerTestMessage = relayError;
    config.apiServerTestMessage = '';
  }

  private markConfiguredEndpointsFailed(config: ServerConfig, message: string): void {
    if (config.idServer.trim().length > 0) {
      config.idServerTestState = 'error';
      config.idServerTestMessage = message;
    }
    if (config.relayServer.trim().length > 0) {
      config.relayServerTestState = 'error';
      config.relayServerTestMessage = message;
    }
    config.apiServerTestState = 'untested';
    config.apiServerTestMessage = '';
  }

  private serverResponseMessage(response: ESObject): string {
    const error = String(response.error ?? '').trim();
    if (error.length > 0) {
      return error;
    }
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
    if (idError.length > 0) {
      details.push(`ID Server: ${idError}`);
    }
    if (relayError.length > 0) {
      details.push(`Relay Server: ${relayError}`);
    }
    return details.length > 0 ? details.join(' · ') : message;
  }

  private copyPeerRows(
    source: ESObject,
    peerSource: PeerSource,
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
      record.forceAlwaysRelay = String(row.forceAlwaysRelay ?? '').toLowerCase() === 'true';
      record.rdpPort = String(row.rdpPort ?? '').trim();
      record.rdpUsername = String(row.rdpUsername ?? '').trim();
      record.loginName = String(row.loginName ?? '').trim();
      record.deviceGroupName = String(row.device_group_name ?? '').trim();
      record.note = typeof row.note === 'string' ? String(row.note) : '';
      const protocol = String(row.protocol ?? '');
      if (protocol === 'vnc' || protocol === 'rdp' || protocol === 'rustdesk') {
        record.protocol = protocol;
      }
      record.address = String(row.address ?? '');
      record.rustdeskIdOnly = peerSource === 'lan' || Boolean(row.rustdeskIdOnly ?? false);
      record.port = Number(row.port ?? 0);
      record.rdpCertificateSha256 = String(row.rdpCertificateSha256 ?? '');
      record.lastSuccessAt = Number(row.lastSuccessAt ?? 0);
      record.sameServer = row.same_server === undefined ? undefined : Boolean(row.same_server);
      record.source = peerSource;
      record.tags = this.copyStringArray(row.tags);
      record.online = undefined;
      record.directWireReachable = undefined;
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
