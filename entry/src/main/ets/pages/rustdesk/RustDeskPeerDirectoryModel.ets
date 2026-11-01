import { DirectorySnapshot, NativeLanReply, PeerOnlineState, PeerProtocol, PeerRecord } from './RustDeskDirectoryTypes';

export function formatPeerId(id: string): string {
  const compact = id.replaceAll(' ', '');
  let idValue = compact;
  let suffix = '';
  if (idValue.endsWith('\\r') || idValue.endsWith('/r')) {
    suffix = idValue.substring(idValue.length - 2);
    idValue = idValue.substring(0, idValue.length - 2);
  }
  if (idValue.length === 0 || !/^\d+$/.test(idValue)) {
    return id;
  }
  if (idValue.length <= 3) {
    return `${idValue}${suffix}`;
  }
  const firstGroupLength = idValue.length % 3 === 0 ? 3 : idValue.length % 3;
  let formatted = idValue.substring(0, firstGroupLength);
  for (let index = firstGroupLength; index < idValue.length; index += 3) {
    formatted += ` ${idValue.substring(index, index + 3)}`;
  }
  return `${formatted}${suffix}`;
}

/**
 * The remote-desktop protocol a target names.
 *
 * A bare id or `host:port` is a RustDesk peer; only an explicit scheme selects
 * another protocol, because silently turning `10.0.0.1:5900` into VNC would
 * break every direct RustDesk connection.
 */
export function peerProtocolFor(target: string): PeerProtocol {
  const value = target.trim().toLowerCase();
  if (value.startsWith('vnc://')) {
    return 'vnc';
  }
  if (value.startsWith('rdp://')) {
    return 'rdp';
  }
  return 'rustdesk';
}

/**
 * The address part of a stored target.
 *
 * Earlier builds saved direct targets with their `vnc://`/`rdp://` scheme. The
 * mode bar names the protocol now and the address field refuses a scheme, so a
 * stored value is reduced to its address before it is put back in the field or
 * dialled.
 */
export function bareTargetAddress(target: string): string {
  const value = target.trim();
  const prefix = value.substring(0, 6).toLowerCase();
  return prefix === 'vnc://' || prefix === 'rdp://' ? value.substring(6) : value;
}

/**
 * The protocol of a peer record.
 *
 * A record saved in the local directory states its protocol; a transient row
 * that does not state one still follows its target's scheme.
 */
export function peerProtocolOf(peer: PeerRecord): PeerProtocol {
  const stated = peer.protocol;
  if (stated !== undefined) {
    return stated;
  }
  return peerProtocolFor(peer.id);
}

/** The protocol's display name: `RustDesk`, `VNC` or `RDP`. */
export function peerProtocolName(protocol: PeerProtocol): string {
  if (protocol === 'vnc') {
    return 'VNC';
  }
  return protocol === 'rdp' ? 'RDP' : 'RustDesk';
}

/** The short label shown on a device card, or an empty string for RustDesk. */
export function peerProtocolLabel(protocol: PeerProtocol): string {
  return protocol === 'rustdesk' ? '' : peerProtocolName(protocol);
}

/**
 * What is known about a peer's reachability: an unobserved peer is `unknown`,
 * which is not the same claim as an observed `offline`.
 */
export function peerOnlineState(online: boolean | undefined): PeerOnlineState {
  if (online === undefined) {
    return 'unknown';
  }
  return online ? 'online' : 'offline';
}

export function peerDisplayTitle(peer: PeerRecord): string {
  const alias = peer.alias.trim();
  return alias.length > 0 ? alias : formatPeerId(peer.id.trim());
}

/**
 * A VNC/RDP device shows the address it is reached at, with the port only when
 * it is not the protocol's default. A RustDesk peer shows the account and
 * machine it reported, `user@host`, leaving out a missing half rather than
 * showing a bare `@`.
 */
export function peerDisplaySubtitle(peer: PeerRecord): string {
  const protocol = peerProtocolOf(peer);
  if (protocol !== 'rustdesk') {
    const address = (peer.address ?? '').trim();
    if (address.length === 0) {
      return bareTargetAddress(peer.id.trim());
    }
    const port = peer.port ?? 0;
    if (port <= 0 || port === (protocol === 'vnc' ? 5900 : 3389)) {
      return address;
    }
    return `${address.includes(':') ? `[${address}]` : address}:${port}`;
  }
  const user = peer.username.trim();
  const host = peer.hostname.trim();
  if (user.length > 0 && host.length > 0) {
    return `${user}@${host}`;
  }
  return user.length > 0 ? user : host;
}

export function copyPeerRecord(source: PeerRecord): PeerRecord {
  const peer = new PeerRecord();
  peer.id = source.id;
  peer.address = source.address ?? '';
  peer.port = source.port ?? 0;
  peer.rdpCertificateSha256 = source.rdpCertificateSha256 ?? '';
  peer.protocol = source.protocol;
  peer.rustdeskIdOnly = source.rustdeskIdOnly;
  peer.username = source.username;
  peer.hostname = source.hostname;
  peer.platform = source.platform;
  peer.alias = source.alias;
  peer.forceAlwaysRelay = source.forceAlwaysRelay;
  peer.rdpPort = source.rdpPort;
  peer.rdpUsername = source.rdpUsername;
  peer.loginName = source.loginName;
  peer.deviceGroupName = source.deviceGroupName;
  peer.note = source.note;
  peer.sameServer = source.sameServer;
  peer.source = source.source;
  peer.addressBookName = source.addressBookName;
  peer.tags = (source.tags ?? []).slice();
  peer.lastSuccessAt = source.lastSuccessAt;
  peer.online = source.online;
  peer.directWireReachable = source.directWireReachable;
  peer.favorite = source.favorite;
  return peer;
}

function previousPeer(peer: PeerRecord, previousLists: PeerRecord[][]): PeerRecord | undefined {
  for (let listIndex = 0; listIndex < previousLists.length; listIndex += 1) {
    const peers = previousLists[listIndex];
    for (let peerIndex = 0; peerIndex < peers.length; peerIndex += 1) {
      if (peers[peerIndex].id === peer.id && peerProtocolOf(peers[peerIndex]) === peerProtocolOf(peer) &&
        peers[peerIndex].rustdeskIdOnly === peer.rustdeskIdOnly) {
        return peers[peerIndex];
      }
    }
  }
  return undefined;
}

/**
 * Carries the two observations a rebuild must not lose: an hbbs answer
 * (`online`) and a direct wire's TCP reachability. Neither is derived from the
 * other, and an observation one of them never made stays undefined.
 */
export function preservePeerOnlineStates(peers: PeerRecord[], previousLists: PeerRecord[][]): void {
  for (let index = 0; index < peers.length; index += 1) {
    const previous = previousPeer(peers[index], previousLists);
    if (previous === undefined) {
      continue;
    }
    if (previous.online !== undefined) {
      peers[index].online = previous.online;
    }
    if (previous.directWireReachable !== undefined) {
      peers[index].directWireReachable = previous.directWireReachable;
    }
  }
}

function isRendezvousPeer(peer: PeerRecord): boolean {
  if (peerProtocolOf(peer) !== 'rustdesk') {
    return false;
  }
  if (peer.rustdeskIdOnly) {
    return true;
  }
  const target = peer.address.length > 0 ? peer.address : peer.id;
  return !/^\d{1,3}(\.\d{1,3}){3}(:\d+)?$/.test(target) && !target.includes(':');
}

export function collectPeerOnlineIds(lists: PeerRecord[][]): string[] {
  const ids: string[] = [];
  for (let listIndex = 0; listIndex < lists.length; listIndex += 1) {
    for (let peerIndex = 0; peerIndex < lists[listIndex].length; peerIndex += 1) {
      if (!isRendezvousPeer(lists[listIndex][peerIndex])) {
        continue;
      }
      const id = lists[listIndex][peerIndex].id.trim();
      if (id.length > 0 && ids.indexOf(id) < 0) {
        ids.push(id);
      }
    }
  }
  return ids;
}

export function applyPeerOnlineStates(
  lists: PeerRecord[][],
  onlines: string[],
  offlines: string[],
): void {
  for (let listIndex = 0; listIndex < lists.length; listIndex += 1) {
    for (let peerIndex = 0; peerIndex < lists[listIndex].length; peerIndex += 1) {
      const peer = lists[listIndex][peerIndex];
      if (!isRendezvousPeer(peer)) {
        continue;
      }
      if (onlines.indexOf(peer.id) >= 0) {
        peer.online = true;
      } else if (offlines.indexOf(peer.id) >= 0) {
        peer.online = false;
      }
    }
  }
}

/**
 * What a card may show for this peer.
 *
 * A RustDesk peer reads only hbbs's `OnlineResponse`; an RDP/VNC peer reads only
 * its own direct TCP reachability. Neither source can fill the other's row.
 */
export function peerReachability(peer: PeerRecord): boolean | undefined {
  return peerProtocolOf(peer) === 'rustdesk' ? peer.online : peer.directWireReachable;
}

export function peerProjectionListsEqual(left: PeerRecord[], right: PeerRecord[]): boolean {
  if (left.length !== right.length) {
    return false;
  }
  for (let index = 0; index < left.length; index += 1) {
    const leftPeer = left[index];
    const rightPeer = right[index];
    if (leftPeer.id !== rightPeer.id
      || peerProtocolOf(leftPeer) !== peerProtocolOf(rightPeer)
      || leftPeer.rustdeskIdOnly !== rightPeer.rustdeskIdOnly
      || leftPeer.address !== rightPeer.address
      || leftPeer.port !== rightPeer.port
      || leftPeer.rdpUsername !== rightPeer.rdpUsername
      || leftPeer.rdpCertificateSha256 !== rightPeer.rdpCertificateSha256
      || leftPeer.lastSuccessAt !== rightPeer.lastSuccessAt
      || leftPeer.username !== rightPeer.username
      || leftPeer.hostname !== rightPeer.hostname
      || leftPeer.platform !== rightPeer.platform
      || leftPeer.alias !== rightPeer.alias
      || leftPeer.note !== rightPeer.note
      || leftPeer.online !== rightPeer.online
      || leftPeer.directWireReachable !== rightPeer.directWireReachable
      || leftPeer.favorite !== rightPeer.favorite
      || leftPeer.source !== rightPeer.source) {
      return false;
    }
  }
  return true;
}

/** LAN claims only supply display metadata and an ID, never reachability or route trust. */
export function projectDirectory(saved: DirectorySnapshot, lan: NativeLanReply, allowed: boolean,
  pending: string, disabledReason: ResourceStr, error: string): DirectorySnapshot {
  const snapshot = new DirectorySnapshot();
  snapshot.revision = saved.revision;
  snapshot.recent = saved.recent;
  snapshot.favorite = saved.favorite;
  snapshot.saved = saved.saved;
  snapshot.message = saved.message;
  const savedRustDesk = new Map<string, PeerRecord>();
  for (let index = 0; index < saved.saved.length; index += 1) {
    const record = saved.saved[index];
    if (peerProtocolOf(record) === 'rustdesk' && record.rustdeskIdOnly) {
      savedRustDesk.set(record.id, record);
    }
  }
  for (let index = 0; index < lan.peers.length; index += 1) {
    const observation = lan.peers[index];
    const peer = new PeerRecord();
    peer.id = observation.id;
    peer.protocol = 'rustdesk';
    peer.rustdeskIdOnly = true;
    peer.username = observation.username;
    peer.hostname = observation.hostname;
    peer.platform = observation.platform;
    peer.source = 'lan';
    const local = savedRustDesk.get(peer.id);
    if (local !== undefined) {
      peer.alias = local.alias;
      peer.note = local.note;
      peer.favorite = local.favorite;
    }
    snapshot.lan.push(peer);
  }
  snapshot.lanCanScan = allowed && pending.length === 0;
  snapshot.lanScanning = allowed && (lan.state === 'scanning' || lan.state === 'stopping');
  snapshot.lanState = pending.length > 0 ? pending : (allowed ? (lan.ok ? lan.state : 'loading') : 'unavailable');
  snapshot.lanTerminal = lan.terminal ?? '';
  snapshot.lanDisabledReason = disabledReason;
  snapshot.lanError = error;
  return snapshot;
}

/**
 * The favourite view of the directory: saved peers that are marked favourite,
 * in source order and without duplicates.
 */
export function buildFavoritePeers(
  recent: PeerRecord[],
  lan: PeerRecord[],
): PeerRecord[] {
  const peers: PeerRecord[] = [];
  const addedIds: string[] = [];
  const sources: PeerRecord[][] = [recent, lan];
  for (let sourceIndex = 0; sourceIndex < sources.length; sourceIndex += 1) {
    for (let peerIndex = 0; peerIndex < sources[sourceIndex].length; peerIndex += 1) {
      const peer = sources[sourceIndex][peerIndex];
      const key = JSON.stringify([peerProtocolOf(peer), peer.id, peer.rustdeskIdOnly]);
      if (peer.favorite && addedIds.indexOf(key) < 0) {
        peers.push(peer);
        addedIds.push(key);
      }
    }
  }
  return peers;
}
