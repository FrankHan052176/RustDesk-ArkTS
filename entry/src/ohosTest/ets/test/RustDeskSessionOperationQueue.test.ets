import { describe, expect, it } from '@ohos/hypium';
import { RustDeskSessionOperationQueue } from '../../../main/ets/pages/rustdesk/RustDeskSessionOperationQueue';

class DeferredOperation {
  private resolveOperation: (() => void) | undefined = undefined;

  wait(): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      this.resolveOperation = resolve;
    });
  }

  release(): void {
    if (this.resolveOperation !== undefined) {
      this.resolveOperation();
      this.resolveOperation = undefined;
    }
  }
}

export default function rustDeskSessionOperationQueueTest(): void {
  describe('RustDeskSessionOperationQueueTest', (): void => {
    it('serializes consecutive reconnects until each prior surface is released', 0,
      async (): Promise<void> => {
        const queue = new RustDeskSessionOperationQueue();
        const firstRelease = new DeferredOperation();
        const secondRelease = new DeferredOperation();
        const events: string[] = [];
        let activeSession = 'session-a';

        const first = queue.enqueue(async (): Promise<void> => {
          const closing = activeSession;
          events.push(`close:${closing}`);
          await firstRelease.wait();
          activeSession = 'session-b';
          events.push('start:session-b');
        });
        const second = queue.enqueue(async (): Promise<void> => {
          const closing = activeSession;
          events.push(`close:${closing}`);
          await secondRelease.wait();
          activeSession = 'session-c';
          events.push('start:session-c');
        });

        await Promise.resolve();
        expect(events.length).assertEqual(1);
        expect(events[0]).assertEqual('close:session-a');
        firstRelease.release();
        await first;
        await Promise.resolve();
        expect(events.length).assertEqual(3);
        expect(events[1]).assertEqual('start:session-b');
        expect(events[2]).assertEqual('close:session-b');
        secondRelease.release();
        await second;

        expect(activeSession).assertEqual('session-c');
        expect(events.length).assertEqual(4);
        expect(events[3]).assertEqual('start:session-c');
      });
  });
}
