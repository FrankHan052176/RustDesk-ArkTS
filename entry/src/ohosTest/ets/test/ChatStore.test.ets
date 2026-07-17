import { describe, expect, it } from '@ohos/hypium';
import { ChatStore } from '../../../main/ets/pages/rustdesk/ChatStore';

export default function chatStoreTest(): void {
  describe('ChatStoreTest', () => {
    it('creates an outgoing pending message', 0, () => {
      const store = new ChatStore();
      const message = store.send('hello', 100);

      expect(message !== undefined).assertTrue();
      expect(message!.text).assertEqual('hello');
      expect(message!.outgoing).assertTrue();
      expect(message!.state).assertEqual('pending');
      expect(message!.sentAt).assertEqual(100);
    });

    it('marks a pending outgoing message as sent', 0, () => {
      const store = new ChatStore();
      const message = store.send('hello', 100);

      store.markSent(message!.localId);

      expect(store.messages()[0].state).assertEqual('sent');
    });

    it('increments unread count for a received remote message', 0, () => {
      const store = new ChatStore();

      store.receive('remote hello', 200);

      expect(store.messages()[0].outgoing).assertFalse();
      expect(store.messages()[0].state).assertEqual('sent');
      expect(store.unreadCount()).assertEqual(1);
    });

    it('marks received messages as read', 0, () => {
      const store = new ChatStore();
      store.receive('remote hello', 200);

      store.markRead();

      expect(store.unreadCount()).assertEqual(0);
    });

    it('rejects empty outgoing messages', 0, () => {
      const store = new ChatStore();

      const message = store.send('', 100);

      expect(message === undefined).assertTrue();
      expect(store.messages().length).assertEqual(0);
    });

    it('rejects whitespace-only outgoing messages', 0, () => {
      const store = new ChatStore();

      const message = store.send('  \n\t ', 100);

      expect(message === undefined).assertTrue();
      expect(store.messages().length).assertEqual(0);
    });

    it('keeps failed outgoing text available for retry', 0, () => {
      const store = new ChatStore();
      const message = store.send('retry this text', 100);
      store.markFailed(message!.localId);

      const retry = store.retry(message!.localId);

      expect(store.messages()[0].text).assertEqual('retry this text');
      expect(retry !== undefined).assertTrue();
      expect(retry!.state).assertEqual('pending');
      expect(retry!.text).assertEqual('retry this text');
    });
  });
}
