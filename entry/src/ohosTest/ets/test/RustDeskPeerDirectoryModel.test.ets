import { describe, expect, it } from '@ohos/hypium';
import { PeerRecord, PeerSource } from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';
import {
  applyPeerOnlineStates,
  buildFavoritePeers,
  collectPeerOnlineIds,
  copyPeerRecord,
  formatPeerId,
  peerProjectionListsEqual,
  peerDisplaySubtitle,
  peerDisplayTitle,
  preservePeerOnlineStates,
} from '../../../main/ets/pages/rustdesk/RustDeskPeerDirectoryModel';

function makePeer(id: string, source: PeerSource): PeerRecord {
  const peer = new PeerRecord();
  peer.id = id;
  peer.source = source;
  return peer;
}

export default function rustDeskPeerDirectoryModelTest(): void {
  describe('RustDeskPeerDirectoryModelTest', () => {
    it('formats numeric ids exactly like Flutter and leaves direct targets unchanged', 0, () => {
      expect(formatPeerId('123456789')).assertEqual('123 456 789');
      expect(formatPeerId('12345678/r')).assertEqual('12 345 678/r');
      expect(formatPeerId('192.168.1.8')).assertEqual('192.168.1.8');
    });

    it('uses alias or formatted id as title and username at hostname as subtitle', 0, () => {
      const peer = makePeer('123456789', 'recent');
      peer.username = 'alice';
      peer.hostname = 'workstation';
      expect(peerDisplayTitle(peer)).assertEqual('123 456 789');
      expect(peerDisplaySubtitle(peer)).assertEqual('alice@workstation');

      peer.alias = 'Office PC';
      expect(peerDisplayTitle(peer)).assertEqual('Office PC');
    });

    it('preserves online state by stable peer id across Core list reloads', 0, () => {
      const previous = makePeer('10001', 'lan');
      previous.online = true;
      const reloaded = makePeer('10001', 'lan');
      const unrelated = makePeer('10002', 'lan');

      preservePeerOnlineStates([reloaded, unrelated], [[previous]]);

      expect(reloaded.online).assertTrue();
      expect(unrelated.online).assertFalse();
    });

    it('queries and updates online state only by peer id', 0, () => {
      const recent = makePeer('10001', 'recent');
      const sameLan = makePeer('10001', 'lan');
      const other = makePeer('192.168.1.20', 'recent');
      other.online = true;

      const ids = collectPeerOnlineIds([[recent], [sameLan, other]]);
      expect(ids.length).assertEqual(2);
      expect(ids[0]).assertEqual('10001');
      expect(ids[1]).assertEqual('192.168.1.20');

      applyPeerOnlineStates([[recent], [sameLan, other]], ['10001'], ['192.168.1.20']);
      expect(recent.online).assertTrue();
      expect(sameLan.online).assertTrue();
      expect(other.online).assertFalse();
    });

    it('builds Flutter favorite peers from recent first then LAN without duplicates', 0, () => {
      const recent = makePeer('10001', 'recent');
      recent.hostname = 'recent-host';
      const duplicateLan = makePeer('10001', 'lan');
      duplicateLan.hostname = 'lan-host';
      const lanOnly = makePeer('10002', 'lan');

      const favorites = buildFavoritePeers([recent], [duplicateLan, lanOnly], ['10002', '10001']);

      expect(favorites.length).assertEqual(2);
      expect(favorites[0].source).assertEqual('recent');
      expect(favorites[0].hostname).assertEqual('recent-host');
      expect(favorites[1].id).assertEqual('10002');
    });

    it('keeps unchanged LAN projections stable during incremental polling', 0, () => {
      const previous = makePeer('10001', 'lan');
      previous.username = 'alice';
      previous.hostname = 'workstation';
      previous.platform = 'Windows';
      previous.online = true;
      const reloaded = copyPeerRecord(previous);

      expect(peerProjectionListsEqual([previous], [reloaded])).assertTrue();
      reloaded.hostname = 'renamed';
      expect(peerProjectionListsEqual([previous], [reloaded])).assertFalse();
    });

    it('copies public peer fields without sharing tags or credential material', 0, () => {
      const source = makePeer('10001', 'addressBook');
      source.alias = 'Alias';
      source.forceAlwaysRelay = true;
      source.rdpPort = '3389';
      source.rdpUsername = 'rdp';
      source.loginName = 'login';
      source.deviceGroupName = 'group';
      source.note = 'note';
      source.sameServer = true;
      source.tags = ['work'];

      const copied = copyPeerRecord(source);
      source.tags.push('changed');

      expect(copied.forceAlwaysRelay).assertTrue();
      expect(copied.note).assertEqual('note');
      expect(copied.sameServer === true).assertTrue();
      expect(copied.tags.length).assertEqual(1);
    });
  });
}
