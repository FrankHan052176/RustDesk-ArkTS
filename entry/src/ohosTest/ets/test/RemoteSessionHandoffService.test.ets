import { describe, expect, it } from '@ohos/hypium';
import {
  RemoteSessionHandoffEnvelope,
  RemoteSessionHandoffService,
  RemoteSessionShareSnapshot,
} from '../../../main/ets/services/RemoteSessionHandoffService';

export default function remoteSessionHandoffServiceTest(): void {
  describe('RemoteSessionHandoffServiceTest', () => {
    it('removes server context from direct IP snapshots', 0, () => {
      const source = new RemoteSessionShareSnapshot();
      source.target = '192.168.1.10:21118';
      source.targetKind = 'ip';
      source.connToken = 'token';
      source.idServer = 'id.example.com';
      source.relayServer = 'relay.example.com';
      source.apiServer = 'https://api.example.com';
      source.key = 'public-key';
      source.forceRelay = true;

      const snapshot = RemoteSessionHandoffService.copySnapshot(source);

      expect(snapshot.idServer).assertEqual('');
      expect(snapshot.relayServer).assertEqual('');
      expect(snapshot.apiServer).assertEqual('');
      expect(snapshot.key).assertEqual('');
      expect(snapshot.forceRelay).assertEqual(false);
    });

    it('keeps server context for target sessions', 0, () => {
      const source = new RemoteSessionShareSnapshot();
      source.target = '123456789';
      source.targetKind = 'target';
      source.connToken = 'token';
      source.idServer = 'id.example.com:21116';
      source.relayServer = 'relay.example.com:21117';
      source.apiServer = 'https://api.example.com';
      source.key = 'public-key';
      source.forceRelay = true;

      const snapshot = RemoteSessionHandoffService.copySnapshot(source);

      expect(snapshot.idServer).assertEqual(source.idServer);
      expect(snapshot.relayServer).assertEqual(source.relayServer);
      expect(snapshot.apiServer).assertEqual(source.apiServer);
      expect(snapshot.key).assertEqual(source.key);
      expect(snapshot.forceRelay).assertEqual(true);
    });

    it('builds direct IP connections without a server suffix', 0, () => {
      const envelope = new RemoteSessionHandoffEnvelope();
      envelope.target = '192.168.1.10:21118';
      envelope.targetKind = 'ip';
      envelope.idServer = 'id.example.com:21116';
      envelope.key = 'public-key';

      expect(RemoteSessionHandoffService.buildConnectionTarget(envelope))
        .assertEqual('192.168.1.10:21118');
    });

    it('rejects manually accepted sessions without a Core connection token', 0, () => {
      const snapshot = new RemoteSessionShareSnapshot();
      snapshot.target = '192.168.1.10:21118';
      snapshot.targetKind = 'ip';

      RemoteSessionHandoffService.setOutgoingSnapshot(snapshot);
      const payload = RemoteSessionHandoffService.createContinuationPayload();
      RemoteSessionHandoffService.setOutgoingSnapshot(undefined);

      expect(payload === undefined).assertEqual(true);
    });

    it('accepts a Core connection token without a plaintext password', 0, () => {
      const snapshot = new RemoteSessionShareSnapshot();
      snapshot.target = '123456789';
      snapshot.targetKind = 'target';
      snapshot.connToken = '{"password":[1,2,3],"password_source":"Undefined","session_id":7}';
      snapshot.idServer = 'id.example.com:21116';

      RemoteSessionHandoffService.setOutgoingSnapshot(snapshot);
      const payload = RemoteSessionHandoffService.createContinuationPayload();
      RemoteSessionHandoffService.setOutgoingSnapshot(undefined);

      expect(payload === undefined).assertEqual(false);
    });

    it('shares a custom Deep Link instead of an App Linking URL', 0, () => {
      const snapshot = new RemoteSessionShareSnapshot();
      snapshot.target = '123456789';
      snapshot.targetKind = 'target';
      snapshot.connToken = 'token';
      snapshot.idServer = 'id.example.com:21116';

      const data = RemoteSessionHandoffService.buildSharedData(snapshot, 'gesture');
      expect(data === undefined).assertEqual(false);
      if (data === undefined) {
        return;
      }
      const records = data.getRecords();
      expect(records.length).assertEqual(1);
      const content = records[0].content ?? '';
      expect(content.startsWith('resk://handoff/remote?')).assertEqual(true);
      expect(content.includes('v=1')).assertEqual(true);
      expect(content.includes('target=123456789')).assertEqual(true);
      expect(content.includes('source=gesture')).assertEqual(true);
      expect(content.startsWith('https://')).assertEqual(false);
    });
  });
}
