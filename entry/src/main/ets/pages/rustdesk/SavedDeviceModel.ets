import { PeerProtocol, PeerRecord, ServerConfig } from './RustDeskDirectoryTypes';
import { bareTargetAddress, copyPeerRecord, peerProtocolOf } from './RustDeskPeerDirectoryModel';
import { checkCertificateSha256, checkRdpUser } from './DirectWireCredentials';

export class DeviceAddressParts {
  address: string = '';
  port: number = 0;
  valid: boolean = false;
}

export function isIpv4Address(address: string): boolean {
  const parts = address.split('.');
  return parts.length === 4 && parts.every((part: string): boolean =>
    /^\d{1,3}$/.test(part) && Number(part) <= 255);
}

export function isIpv6Address(address: string): boolean {
  if (!address.includes(':') || address.includes(':::') || !/^[0-9a-fA-F:.]+$/.test(address) ||
    (address.startsWith(':') && !address.startsWith('::')) ||
    (address.endsWith(':') && !address.endsWith('::'))) {
    return false;
  }
  const halves = address.split('::');
  if (halves.length > 2) {
    return false;
  }
  const groups = address.split(':').filter((part: string): boolean => part.length > 0);
  let count = 0;
  for (let index = 0; index < groups.length; index += 1) {
    const group = groups[index];
    if (group.includes('.')) {
      if (index !== groups.length - 1 || !isIpv4Address(group)) {
        return false;
      }
      count += 2;
    } else {
      if (!/^[0-9a-fA-F]{1,4}$/.test(group)) {
        return false;
      }
      count += 1;
    }
  }
  return halves.length === 2 ? count < 8 : count === 8;
}

export function deviceDefaultPort(protocol: PeerProtocol, address: string): number {
  if (protocol === 'vnc') {
    return 5900;
  }
  if (protocol === 'rdp') {
    return 3389;
  }
  return isIpv4Address(address) || isIpv6Address(address) ? 21118 : 0;
}

export function splitDeviceAddress(raw: string, protocol: PeerProtocol): DeviceAddressParts {
  const parts = new DeviceAddressParts();
  let value = bareTargetAddress(raw);
  if (protocol === 'rustdesk' && /^[\d ]+$/.test(value)) {
    value = value.replaceAll(' ', '');
  }
  if (value.length === 0 || /[\s/?#]/.test(value) || value.includes('://') ||
    (protocol !== 'rustdesk' && value.includes('@'))) {
    return parts;
  }
  const bracket = /^\[([^\]]+)\](?::(\d+))?$/.exec(value);
  const hostPort = /^([^:]+):(\d+)$/.exec(value);
  if (bracket !== null) {
    parts.address = bracket[1];
    if (!isIpv6Address(parts.address)) {
      return parts;
    }
    parts.port = bracket[2] === undefined ? deviceDefaultPort(protocol, parts.address) : Number(bracket[2]);
  } else if (hostPort !== null) {
    parts.address = hostPort[1];
    parts.port = Number(hostPort[2]);
  } else {
    parts.address = value;
    if (value.includes(':') && !isIpv6Address(value)) {
      return parts;
    }
    parts.port = deviceDefaultPort(protocol, parts.address);
  }
  parts.valid = Number.isInteger(parts.port) && parts.port >= 0 && parts.port <= 65535 &&
    (parts.port > 0 || protocol === 'rustdesk');
  return parts;
}

export function deviceConnectionTarget(peer: PeerRecord): string {
  if (peer.address.length === 0) {
    return bareTargetAddress(peer.id);
  }
  if (peer.port <= 0) {
    return peer.address;
  }
  return `${peer.address.includes(':') ? `[${peer.address}]` : peer.address}:${peer.port}`;
}

export function savedDeviceKey(peer: PeerRecord): string {
  return JSON.stringify([peerProtocolOf(peer), deviceConnectionTarget(peer), peer.rustdeskIdOnly]);
}

/** Core classifies the qualified ID before looking up its rendezvous server, never as an IP. */
export function rustDeskIdDialTarget(target: string, config: ServerConfig): string {
  const id = target.trim();
  if (id.includes('@')) {
    return id;
  }
  const server = config.idServer.trim() || 'public';
  const key = config.key.trim();
  return `${id}@${server}${key.length > 0 ? `?key=${key}` : ''}`;
}

/** A saved account/endpoint edit supersedes the username offered back after a failed dial. */
export function invalidatesRdpUsernameCache(original: PeerRecord, value: PeerRecord,
  cachedTarget: string): boolean {
  if (cachedTarget.length === 0) {
    return false;
  }
  const cached = new PeerRecord();
  cached.id = cachedTarget;
  cached.protocol = 'rdp';
  const cachedKey = savedDeviceKey(migrateDeviceRecord(cached));
  const next = migrateDeviceRecord(value);
  const previous = migrateDeviceRecord(original);
  if (savedDeviceKey(next) !== cachedKey && savedDeviceKey(previous) !== cachedKey) {
    return false;
  }
  return savedDeviceKey(previous) !== savedDeviceKey(next) || previous.rdpUsername !== next.rdpUsername;
}

/** Explicit protocol wins; old schemes alone infer the wire, never port numbers. */
export function migrateDeviceRecord(source: PeerRecord): PeerRecord {
  const peer = copyPeerRecord(source);
  const protocol = peerProtocolOf(source);
  peer.protocol = protocol;
  let target = bareTargetAddress(source.address?.trim().length > 0 ? source.address : source.id);
  if (peer.protocol === 'rdp' && target.includes('@')) {
    const separator = target.lastIndexOf('@');
    const user = target.substring(0, separator).split(':')[0];
    peer.rdpUsername = source.rdpUsername?.trim().length > 0 ? source.rdpUsername : user;
    target = target.substring(separator + 1);
  }
  if (peer.protocol === 'vnc' && target.includes('@')) {
    target = target.substring(target.lastIndexOf('@') + 1);
  }
  const parts = splitDeviceAddress(target, protocol);
  peer.address = parts.address.length > 0 ? parts.address : target;
  peer.port = source.port > 0 ? source.port : parts.port;
  peer.rustdeskIdOnly = source.rustdeskIdOnly === true;
  if (peer.protocol === 'rdp' && !(source.port > 0) && /^\d+$/.test(source.rdpPort ?? '')) {
    peer.port = Number(source.rdpPort);
  }
  if (peer.rustdeskIdOnly && peer.protocol === 'rustdesk') {
    peer.address = target;
    peer.port = 0;
  }
  peer.rdpCertificateSha256 = peer.protocol === 'rdp'
    ? checkCertificateSha256(source.rdpCertificateSha256 ?? '').pin : '';
  peer.rdpUsername = peer.protocol === 'rdp' && checkRdpUser(peer.rdpUsername ?? '').ok
    ? peer.rdpUsername.trim() : '';
  peer.id = deviceConnectionTarget(peer);
  peer.lastSuccessAt = Number.isFinite(source.lastSuccessAt) ? source.lastSuccessAt : 0;
  peer.favorite = source.favorite === true;
  peer.online = undefined;
  return peer;
}

/** Only named public fields reach Preferences; no passwords or persisted liveness. */
export function persistedDeviceRecords(peers: PeerRecord[]): PeerRecord[] {
  return peers.map((source: PeerRecord): PeerRecord => {
    const migrated = migrateDeviceRecord(source);
    const peer = new PeerRecord();
    peer.protocol = migrated.protocol;
    peer.id = migrated.id;
    peer.address = migrated.address;
    peer.port = migrated.port;
    peer.alias = source.alias ?? '';
    peer.favorite = migrated.favorite;
    peer.rustdeskIdOnly = migrated.rustdeskIdOnly;
    peer.rdpUsername = migrated.rdpUsername;
    peer.rdpCertificateSha256 = migrated.rdpCertificateSha256;
    peer.username = source.username ?? '';
    peer.hostname = source.hostname ?? '';
    peer.platform = source.platform ?? '';
    peer.note = source.note ?? '';
    peer.lastSuccessAt = migrated.lastSuccessAt;
    return peer;
  });
}

export function mergeSavedDevices(existing: PeerRecord[], incoming: PeerRecord[]): PeerRecord[] {
  const result = existing.slice();
  for (const source of incoming) {
    const peer = migrateDeviceRecord(source);
    if (peer.id.length > 0 && !result.some((row: PeerRecord): boolean => savedDeviceKey(row) === savedDeviceKey(peer))) {
      result.push(peer);
    }
  }
  return result;
}
