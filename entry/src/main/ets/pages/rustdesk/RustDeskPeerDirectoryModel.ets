import { PeerRecord } from './RustDeskDirectoryTypes';

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

export function peerDisplayTitle(peer: PeerRecord): string {
  const alias = peer.alias.trim();
  return alias.length > 0 ? alias : formatPeerId(peer.id.trim());
}

export function peerDisplaySubtitle(peer: PeerRecord): string {
  return `${peer.username.trim()}@${peer.hostname.trim()}`;
}

export function copyPeerRecord(source: PeerRecord): PeerRecord {
  const peer = new PeerRecord();
  peer.id = source.id;
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
  peer.tags = source.tags.slice();
  peer.online = source.online;
  peer.favorite = source.favorite;
  return peer;
}

function previousOnlineState(id: string, previousLists: PeerRecord[][]): boolean | undefined {
  for (let listIndex = 0; listIndex < previousLists.length; listIndex += 1) {
    const peers = previousLists[listIndex];
    for (let peerIndex = 0; peerIndex < peers.length; peerIndex += 1) {
      if (peers[peerIndex].id === id) {
        return peers[peerIndex].online;
      }
    }
  }
  return undefined;
}

export function preservePeerOnlineStates(peers: PeerRecord[], previousLists: PeerRecord[][]): void {
  for (let index = 0; index < peers.length; index += 1) {
    const previous = previousOnlineState(peers[index].id, previousLists);
    if (previous !== undefined) {
      peers[index].online = previous;
    }
  }
}

export function collectPeerOnlineIds(lists: PeerRecord[][]): string[] {
  const ids: string[] = [];
  for (let listIndex = 0; listIndex < lists.length; listIndex += 1) {
    for (let peerIndex = 0; peerIndex < lists[listIndex].length; peerIndex += 1) {
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
      if (onlines.indexOf(peer.id) >= 0) {
        peer.online = true;
      } else if (offlines.indexOf(peer.id) >= 0) {
        peer.online = false;
      }
    }
  }
}

export function peerProjectionListsEqual(left: PeerRecord[], right: PeerRecord[]): boolean {
  if (left.length !== right.length) {
    return false;
  }
  for (let index = 0; index < left.length; index += 1) {
    const leftPeer = left[index];
    const rightPeer = right[index];
    if (leftPeer.id !== rightPeer.id
      || leftPeer.username !== rightPeer.username
      || leftPeer.hostname !== rightPeer.hostname
      || leftPeer.platform !== rightPeer.platform
      || leftPeer.alias !== rightPeer.alias
      || leftPeer.online !== rightPeer.online
      || leftPeer.favorite !== rightPeer.favorite
      || leftPeer.source !== rightPeer.source) {
      return false;
    }
  }
  return true;
}

export function buildFavoritePeers(
  recent: PeerRecord[],
  lan: PeerRecord[],
  favoriteIds: string[],
): PeerRecord[] {
  const peers: PeerRecord[] = [];
  const addedIds: string[] = [];
  const sources: PeerRecord[][] = [recent, lan];
  for (let sourceIndex = 0; sourceIndex < sources.length; sourceIndex += 1) {
    for (let peerIndex = 0; peerIndex < sources[sourceIndex].length; peerIndex += 1) {
      const peer = sources[sourceIndex][peerIndex];
      if (favoriteIds.indexOf(peer.id) >= 0 && addedIds.indexOf(peer.id) < 0) {
        peers.push(peer);
        addedIds.push(peer.id);
      }
    }
  }
  return peers;
}
