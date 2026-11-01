import { describe, expect, it } from '@ohos/hypium';
import { PeerRecord, PeerSource } from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';
import {
  applyPeerOnlineStates,
  collectPeerOnlineIds,
  buildFavoritePeers,
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
      peer.username = '';
      expect(peerDisplaySubtitle(peer)).assertEqual('workstation');
      peer.hostname = '';
      // A peer that reports neither half shows no bare '@'.
      expect(peerDisplaySubtitle(peer)).assertEqual('');

      peer.alias = 'Office PC';
      expect(peerDisplayTitle(peer)).assertEqual('Office PC');
    });

    it('shows a direct device address, with the port only when it is not the default', 0, () => {
      const peer = makePeer('192.168.1.8:3389', 'recent');
      peer.protocol = 'rdp';
      peer.address = '192.168.1.8';
      peer.port = 3389;
      peer.hostname = 'workstation';
      expect(peerDisplaySubtitle(peer)).assertEqual('192.168.1.8');
      peer.port = 13389;
      expect(peerDisplaySubtitle(peer)).assertEqual('192.168.1.8:13389');
      peer.protocol = 'vnc';
      peer.address = 'fe80::1';
      peer.port = 5901;
      expect(peerDisplaySubtitle(peer)).assertEqual('[fe80::1]:5901');
      peer.port = 5900;
      expect(peerDisplaySubtitle(peer)).assertEqual('fe80::1');
    });

    it('preserves online state by stable peer id across Core list reloads', 0, () => {
      const previous = makePeer('10001', 'lan');
      previous.online = true;
      const reloaded = makePeer('10001', 'lan');
      const unrelated = makePeer('10002', 'lan');
      const otherProtocol = makePeer('10001', 'recent');
      otherProtocol.protocol = 'vnc';

      preservePeerOnlineStates([reloaded, unrelated, otherProtocol], [[previous]]);

      expect(reloaded.online).assertTrue();
      expect(unrelated.online).assertUndefined();
      expect(otherProtocol.online).assertUndefined();
    });

    it('queries RustDesk IDs and never submits TCP endpoints to rendezvous', 0, () => {
      const recent = makePeer('10001', 'recent');
      const sameLan = makePeer('10001', 'lan');
      const other = makePeer('192.168.1.20', 'recent');
      other.online = true;
      const vnc = makePeer('10001', 'recent');
      vnc.protocol = 'vnc';

      const ids = collectPeerOnlineIds([[recent], [sameLan, other, vnc]]);
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual('10001');

      applyPeerOnlineStates([[recent], [sameLan, other, vnc]], ['10001'], ['192.168.1.20']);
      expect(recent.online).assertTrue();
      expect(sameLan.online).assertTrue();
      expect(other.online).assertTrue();
      expect(vnc.online).assertUndefined();
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
      source.address = '10.0.0.5';
      source.port = 3389;
      source.rdpCertificateSha256 = 'ab'.repeat(32);

      const copied = copyPeerRecord(source);
      source.tags.push('changed');

      expect(copied.forceAlwaysRelay).assertTrue();
      expect(copied.note).assertEqual('note');
      expect(copied.sameServer === true).assertTrue();
      expect(copied.tags.length).assertEqual(1);
      expect(copied.address).assertEqual('10.0.0.5');
      expect(copied.port).assertEqual(3389);
      expect(copied.rdpCertificateSha256).assertEqual('ab'.repeat(32));
    });

    it('keeps protocol-specific favorites on the same target distinct', 0, () => {
      const vnc = makePeer('host', 'recent');
      vnc.protocol = 'vnc';
      vnc.favorite = true;
      const rdp = makePeer('host', 'recent');
      rdp.protocol = 'rdp';
      rdp.favorite = true;
      const plain = makePeer('host', 'recent');
      const peers = buildFavoritePeers([vnc, rdp, plain], [copyPeerRecord(vnc)]);
      expect(peers.length).assertEqual(2);
    });

    it('invalidates projections when edited endpoint or RDP trust fields change', 0, () => {
      const original = makePeer('host', 'recent');
      original.protocol = 'rdp';
      const edited = copyPeerRecord(original);
      edited.port = 3390;
      expect(peerProjectionListsEqual([original], [edited])).assertFalse();
      edited.port = original.port;
      edited.rdpCertificateSha256 = 'cd'.repeat(32);
      expect(peerProjectionListsEqual([original], [edited])).assertFalse();
    });
  });
}
