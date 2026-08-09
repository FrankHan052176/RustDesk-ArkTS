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
      source.password = 'temporary';
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
      source.password = 'temporary';
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
  });
}
