import { describe, expect, it } from '@ohos/hypium';
import {
  ApprovedServerProfile,
  PeerRecord,
  ServerProfileReply,
} from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';
import {
  peerReachability,
  preservePeerOnlineStates,
} from '../../../main/ets/pages/rustdesk/RustDeskPeerDirectoryModel';

/**
 * The exact `approvedProfile` envelope `app_profile.rs` returns for a saved
 * profile. The engine already validated the key, so it is only carried here.
 */
const ENGINE_APPROVED = '{"schemaVersion":2,"approval":"explicit-save","revision":7,' +
  '"mode":"custom","idServer":"rd.example.com:21116",' +
  '"relayServer":"rd.example.com:21117","key":"AAAA"}';

function envelope(source: string): ESObject {
  return JSON.parse(source) as ESObject;
}

function peer(id: string, protocol: 'rustdesk' | 'vnc' | 'rdp'): PeerRecord {
  const record = new PeerRecord();
  record.id = id;
  record.protocol = protocol;
  return record;
}

export default function rustDeskServerProfileReplyTest(): void {
  describe('RustDeskServerProfileReplyTest', () => {
    it('rebuilds the engine approval and sends back exactly its wire fields', 0, () => {
      const profile = ApprovedServerProfile.fromNative(envelope(ENGINE_APPROVED));
      expect(profile !== undefined).assertTrue();
      if (profile === undefined) {
        return;
      }
      // This object is what sessionAdd options and peerQueryOnline carry.
      const wire = JSON.parse(JSON.stringify(profile)) as ESObject;
      expect(wire.schemaVersion).assertEqual(2);
      expect(wire.approval).assertEqual('explicit-save');
      expect(wire.revision).assertEqual(7);
      expect(wire.mode).assertEqual('custom');
      expect(wire.idServer).assertEqual('rd.example.com:21116');
      expect(wire.relayServer).assertEqual('rd.example.com:21117');
      expect(wire.key).assertEqual('AAAA');
    });

    it('refuses an envelope the engine did not approve', 0, () => {
      const rejected: string[] = [
        '{}',
        '{"schemaVersion":1,"approval":"explicit-save","revision":7,"mode":"custom",' +
          '"idServer":"rd.example.com:21116","key":"AAAA"}',
        '{"schemaVersion":2,"approval":"legacy","revision":7,"mode":"custom",' +
          '"idServer":"rd.example.com:21116","key":"AAAA"}',
        '{"schemaVersion":2,"approval":"explicit-save","revision":0,"mode":"custom",' +
          '"idServer":"rd.example.com:21116","key":"AAAA"}',
        '{"schemaVersion":2,"approval":"explicit-save","revision":-3,"mode":"custom",' +
          '"idServer":"rd.example.com:21116","key":"AAAA"}',
        '{"schemaVersion":2,"approval":"explicit-save","revision":7,"mode":"lan",' +
          '"idServer":"rd.example.com:21116","key":"AAAA"}',
        '{"schemaVersion":2,"approval":"explicit-save","revision":7,"mode":"custom",' +
          '"idServer":"rd.example.com:21116","key":""}',
      ];
      for (let index = 0; index < rejected.length; index += 1) {
        expect(ApprovedServerProfile.fromNative(envelope(rejected[index])) === undefined).assertTrue();
      }
    });

    it('never turns a failed save or a draft into an approval', 0, () => {
      const refused = new ServerProfileReply();
      refused.ok = false;
      refused.error = 'the saved server profile is not valid JSON';
      expect(refused.toProfileState().approval).assertEqual('missing');
      expect(refused.toProfileState().revision).assertEqual(0);

      // A test receipt is a successful call that approves nothing.
      const tested = new ServerProfileReply();
      tested.ok = true;
      tested.approved = false;
      expect(tested.toProfileState().approval).assertEqual('missing');

      // A successful read restores the approval the engine already persisted.
      const restored = new ServerProfileReply();
      restored.ok = true;
      restored.approved = true;
      restored.approvedProfile = ApprovedServerProfile.fromNative(envelope(ENGINE_APPROVED));
      const state = restored.toProfileState();
      expect(state.approval).assertEqual('approved');
      expect(state.revision).assertEqual(7);
      expect(state.config.idServer).assertEqual('rd.example.com:21116');
      const captured = state.captureApproved();
      expect(captured !== undefined).assertTrue();
      if (captured === undefined) {
        return;
      }
      const capturedWire = JSON.parse(JSON.stringify(captured)) as ESObject;
      expect(capturedWire.revision).assertEqual(7);
    });

    it('reads hbbs online only for RustDesk peers and TCP reachability only for direct wires', 0, () => {
      const rustdesk = peer('123456789', 'rustdesk');
      rustdesk.online = true;
      rustdesk.directWireReachable = false;
      expect(peerReachability(rustdesk) === true).assertTrue();

      // An accepted TCP socket is not a RustDesk online answer.
      const claimed = peer('123456788', 'rustdesk');
      claimed.directWireReachable = true;
      expect(peerReachability(claimed) === undefined).assertTrue();

      // A direct wire is not answered by hbbs either.
      const vnc = peer('fe80::1', 'vnc');
      vnc.online = true;
      vnc.directWireReachable = false;
      expect(peerReachability(vnc) === false).assertTrue();

      const rdp = peer('10.0.0.5', 'rdp');
      rdp.directWireReachable = true;
      expect(peerReachability(rdp) === true).assertTrue();
    });

    it('rebuilds both observations without filling one from the other', 0, () => {
      const previousRustdesk = peer('123456789', 'rustdesk');
      previousRustdesk.online = true;
      const previousVnc = peer('fe80::1', 'vnc');
      previousVnc.directWireReachable = false;

      const nextRustdesk = peer('123456789', 'rustdesk');
      const nextVnc = peer('fe80::1', 'vnc');
      preservePeerOnlineStates([nextRustdesk, nextVnc], [[previousRustdesk, previousVnc]]);

      expect(nextRustdesk.online === true).assertTrue();
      expect(nextRustdesk.directWireReachable === undefined).assertTrue();
      expect(nextVnc.directWireReachable === false).assertTrue();
      expect(nextVnc.online === undefined).assertTrue();
    });
  });
}
