import { describe, expect, it } from '@ohos/hypium';
import { PeerRecord, ServerConfig } from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';
import { deviceConnectionTarget, invalidatesRdpUsernameCache, isIpv6Address, mergeSavedDevices, migrateDeviceRecord,
  persistedDeviceRecords, rustDeskIdDialTarget, savedDeviceKey, splitDeviceAddress } from '../../../main/ets/pages/rustdesk/SavedDeviceModel';

export default function savedDeviceModelTest(): void {
  describe('SavedDeviceModelTest', () => {
    it('infers legacy schemes but never selects a protocol by its port', 0, () => {
      const oldVnc = new PeerRecord();
      oldVnc.id = 'vnc://10.0.0.1:5901';
      oldVnc.alias = 'Office';
      oldVnc.favorite = true;
      const vnc = migrateDeviceRecord(oldVnc);
      expect(vnc.protocol).assertEqual('vnc');
      expect(vnc.address).assertEqual('10.0.0.1');
      expect(vnc.port).assertEqual(5901);
      expect(vnc.alias).assertEqual('Office');
      expect(vnc.favorite).assertTrue();
      const rustdesk = new PeerRecord();
      rustdesk.id = '10.0.0.1:5900';
      expect(migrateDeviceRecord(rustdesk).protocol).assertEqual('rustdesk');
    });

    it('migrates RDP account endpoints without persisting authority passwords', 0, () => {
      const oldRdp = new PeerRecord();
      oldRdp.id = 'rdp://CORP\\ann:do-not-store@10.0.0.2:3389';
      oldRdp.rdpCertificateSha256 = 'AB'.repeat(32);
      const peer = migrateDeviceRecord(oldRdp);
      expect(peer.protocol).assertEqual('rdp');
      expect(peer.rdpUsername).assertEqual('CORP\\ann');
      expect(peer.address).assertEqual('10.0.0.2');
      expect(peer.port).assertEqual(3389);
      expect(peer.rdpCertificateSha256).assertEqual('ab'.repeat(32));
      expect(JSON.stringify(persistedDeviceRecords([oldRdp])).includes('do-not-store')).assertFalse();
    });

    it('keeps explicit wire and supplies its default port', 0, () => {
      const peer = new PeerRecord();
      peer.id = '10.0.0.3';
      peer.protocol = 'rdp';
      const migrated = migrateDeviceRecord(peer);
      expect(migrated.port).assertEqual(3389);
      expect(deviceConnectionTarget(migrated)).assertEqual('10.0.0.3:3389');
      peer.protocol = 'vnc';
      expect(migrateDeviceRecord(peer).port).assertEqual(5900);
    });

    it('retains old RDP port metadata and bracketed IPv6 endpoints', 0, () => {
      const peer = new PeerRecord();
      peer.protocol = 'rdp';
      peer.id = '[2001:db8::1]';
      peer.rdpPort = '3390';
      const migrated = migrateDeviceRecord(peer);
      expect(migrated.address).assertEqual('2001:db8::1');
      expect(migrated.port).assertEqual(3390);
      expect(deviceConnectionTarget(migrated)).assertEqual('[2001:db8::1]:3390');
      expect(isIpv6Address('2001:db8::1')).assertTrue();
      expect(isIpv6Address('2001:db8:::1')).assertFalse();
      expect(splitDeviceAddress('[2001:db8::1]:5901', 'vnc').port).assertEqual(5901);
    });

    it('preserves ID-only LAN intent even when the ID resembles an IP', 0, () => {
      const peer = new PeerRecord();
      peer.id = '10.0.0.4';
      peer.rustdeskIdOnly = true;
      const migrated = migrateDeviceRecord(peer);
      expect(migrated.rustdeskIdOnly).assertTrue();
      expect(migrated.port).assertEqual(0);
      expect(deviceConnectionTarget(migrated)).assertEqual('10.0.0.4');
    });

    it('qualifies an IP-looking ID for Core while leaving its saved target bare', 0, () => {
      const config = new ServerConfig();
      expect(rustDeskIdDialTarget(' 10.0.0.4 ', config)).assertEqual('10.0.0.4@public');
      config.idServer = ' rendezvous.example:21116 ';
      config.key = ' server-key ';
      expect(rustDeskIdDialTarget('10.0.0.4', config))
        .assertEqual('10.0.0.4@rendezvous.example:21116?key=server-key');
      expect(rustDeskIdDialTarget('10.0.0.4@other.example?key=other-key', config))
        .assertEqual('10.0.0.4@other.example?key=other-key');
      const peer = new PeerRecord();
      peer.id = '10.0.0.4';
      peer.rustdeskIdOnly = true;
      const stored = persistedDeviceRecords([peer])[0];
      expect(stored.id).assertEqual('10.0.0.4');
      expect(stored.rustdeskIdOnly).assertTrue();
    });

    it('invalidates an edited RDP account at the cached endpoint including its default port', 0, () => {
      const original = new PeerRecord();
      original.id = '10.0.0.4';
      original.protocol = 'rdp';
      original.rdpUsername = 'old-account';
      const edited = migrateDeviceRecord(original);
      edited.rdpUsername = 'new-account';
      expect(invalidatesRdpUsernameCache(original, edited, '10.0.0.4')).assertTrue();
      expect(invalidatesRdpUsernameCache(original, edited, '10.0.0.4:3389')).assertTrue();
      expect(invalidatesRdpUsernameCache(original, edited, '10.0.0.5:3389')).assertFalse();
      expect(invalidatesRdpUsernameCache(original, edited, '')).assertFalse();
      const renamed = migrateDeviceRecord(original);
      renamed.alias = 'Office';
      expect(invalidatesRdpUsernameCache(original, renamed, '10.0.0.4')).assertFalse();
      const moved = migrateDeviceRecord(original);
      moved.address = '10.0.0.5';
      expect(invalidatesRdpUsernameCache(original, moved, '10.0.0.4')).assertTrue();
      expect(invalidatesRdpUsernameCache(original, moved, '10.0.0.5')).assertTrue();
      moved.protocol = 'vnc';
      expect(invalidatesRdpUsernameCache(original, moved, '10.0.0.4')).assertTrue();
    });

    it('whitelists persisted fields and does not remember online claims', 0, () => {
      const old = JSON.parse('{"id":"123456789","alias":"Laptop","favorite":true,"online":true,"password":"never-save"}') as PeerRecord;
      const stored = persistedDeviceRecords([old]);
      expect(stored[0].online).assertUndefined();
      expect(stored[0].alias).assertEqual('Laptop');
      expect(stored[0].favorite).assertTrue();
      expect(JSON.stringify(stored).includes('never-save')).assertFalse();
      expect(JSON.stringify(stored).includes('"password"')).assertFalse();
    });

    it('deduplicates by wire endpoint and intent rather than host text alone', 0, () => {
      const rustdesk = new PeerRecord();
      rustdesk.id = '10.0.0.5';
      const vnc = new PeerRecord();
      vnc.id = '10.0.0.5';
      vnc.protocol = 'vnc';
      const rdp = new PeerRecord();
      rdp.id = '10.0.0.5';
      rdp.protocol = 'rdp';
      const peers = mergeSavedDevices([], [rustdesk, vnc, rdp, vnc]);
      expect(peers.length).assertEqual(3);
      expect(savedDeviceKey(peers[1]) === savedDeviceKey(peers[2])).assertFalse();
      expect(splitDeviceAddress('123 456 789', 'rustdesk').address).assertEqual('123456789');
    });
  });
}
