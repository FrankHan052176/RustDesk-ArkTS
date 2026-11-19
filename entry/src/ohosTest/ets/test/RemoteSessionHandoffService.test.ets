import { describe, expect, it } from '@ohos/hypium';
import { url } from '@kit.ArkTS';
import {
  RemoteSessionHandoffEnvelope,
  RemoteSessionHandoffService,
  RemoteSessionShareSnapshot,
} from '../../../main/ets/services/RemoteSessionHandoffService';

/** The envelope a shared link carries, read back from the link itself. */
function sharedEnvelope(snapshot: RemoteSessionShareSnapshot): ESObject | undefined {
  const data = RemoteSessionHandoffService.buildSharedData(snapshot, 'gesture');
  if (data === undefined) {
    return undefined;
  }
  const records = data.getRecords();
  if (records.length !== 1) {
    return undefined;
  }
  const payload = url.URL.parseURL(records[0].content ?? '').params.get('payload');
  if (payload === null || payload.length === 0) {
    return undefined;
  }
  const envelope: ESObject = JSON.parse(payload);
  return envelope;
}

export default function remoteSessionHandoffServiceTest(): void {
  describe('RemoteSessionHandoffServiceTest', () => {
    it('never shares server context with a direct IP session', 0, () => {
      const source = new RemoteSessionShareSnapshot();
      source.target = '192.168.1.10:21118';
      source.targetKind = 'ip';
      source.connToken = 'token';
      source.idServer = 'id.example.com';
      source.relayServer = 'relay.example.com';
      source.apiServer = 'https://api.example.com';
      source.key = 'public-key';
      source.forceRelay = true;

      // A direct IP session has no server; a snapshot claiming one is refused
      // whole instead of being sent with or without it.
      expect(sharedEnvelope(source) === undefined).assertEqual(true);

      source.idServer = '';
      source.relayServer = '';
      source.apiServer = '';
      source.key = '';
      source.forceRelay = false;
      const envelope: ESObject | undefined = sharedEnvelope(source);
      expect(envelope === undefined).assertEqual(false);
      if (envelope === undefined) {
        return;
      }
      expect(envelope.targetKind).assertEqual('ip');
      expect(envelope.idServer).assertEqual('');
      expect(envelope.key).assertEqual('');
      expect(envelope.forceRelay).assertEqual(false);
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

      const envelope: ESObject | undefined = sharedEnvelope(source);
      expect(envelope === undefined).assertEqual(false);
      if (envelope === undefined) {
        return;
      }
      expect(envelope.idServer).assertEqual(source.idServer);
      expect(envelope.relayServer).assertEqual(source.relayServer);
      expect(envelope.apiServer).assertEqual(source.apiServer);
      expect(envelope.key).assertEqual(source.key);
      expect(envelope.forceRelay).assertEqual(true);
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

      RemoteSessionHandoffService.setOutgoingSnapshotProvider(
        (): RemoteSessionShareSnapshot | undefined => snapshot);
      const payload = RemoteSessionHandoffService.createContinuationPayload();
      RemoteSessionHandoffService.setOutgoingSnapshotProvider(undefined);

      expect(payload === undefined).assertEqual(true);
    });

    it('accepts a Core connection token without a plaintext password', 0, () => {
      const snapshot = new RemoteSessionShareSnapshot();
      snapshot.target = '123456789';
      snapshot.targetKind = 'target';
      snapshot.connToken = '{"password":[1,2,3],"password_source":"Undefined","session_id":7}';
      snapshot.idServer = 'id.example.com:21116';

      RemoteSessionHandoffService.setOutgoingSnapshotProvider(
        (): RemoteSessionShareSnapshot | undefined => snapshot);
      const payload = RemoteSessionHandoffService.createContinuationPayload();
      RemoteSessionHandoffService.setOutgoingSnapshotProvider(undefined);

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
      expect(content.startsWith('resk://handoff/remote?payload=')).assertEqual(true);
      expect(content.startsWith('https://')).assertEqual(false);
      const envelope: ESObject | undefined = sharedEnvelope(snapshot);
      expect(envelope === undefined).assertEqual(false);
      if (envelope === undefined) {
        return;
      }
      expect(envelope.version).assertEqual(2);
      expect(envelope.target).assertEqual('123456789');
      expect(envelope.source).assertEqual('gesture');
    });
  });
}
