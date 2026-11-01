import { describe, expect, it } from '@ohos/hypium';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  RustDeskClipboardController,
  RustDeskClipboardControllerCallbacks,
  RustDeskClipboardHost,
  carriesRichClipboard,
  carriesTextClipboard,
  clipboardTextSyncAllowed,
  fileClipboardSignature,
  isClipboardFileEcho,
  isClipboardTextEcho,
  isRemoteClipboardClear,
  RustDeskRemoteClipboardPayload,
} from '../../../main/ets/pages/rustdesk/RustDeskClipboardController';

/** A promise the test resolves on demand, for one pasteboard read. */
class Deferred<T> {
  private readonly promise: Promise<T>;
  private settle: (value: T) => void = (): void => {};
  private done: boolean = false;

  constructor() {
    this.promise = new Promise<T>((resolve: (value: T) => void): void => {
      this.settle = resolve;
    });
  }

  resolve(value: T): void {
    if (this.done) {
      return;
    }
    this.done = true;
    this.settle(value);
  }

  when(): Promise<T> {
    return this.promise;
  }
}

/**
 * A pasteboard the test drives.
 *
 * Writes and clears commit synchronously, as the real host does, so a test can
 * observe that a mutation is complete before the call returns; reads can be held so
 * the ordering around an in-flight read is exercised.
 */
class TestClipboardHost implements RustDeskClipboardHost {
  readonly filesDir: string = '';
  readonly cacheDir: string = '';
  /** What the clipboard holds now. */
  current: pasteboard.PasteData | undefined = undefined;
  /** Held so the test can complete one read at will. */
  read: Deferred<pasteboard.PasteData> | undefined = undefined;
  writes: number = 0;
  clears: number = 0;
  private listener: (() => void) | undefined = undefined;

  onUpdate(listener: () => void): void {
    this.listener = listener;
  }

  offUpdate(_listener: () => void): void {
    this.listener = undefined;
  }

  hasData(): Promise<boolean> {
    return Promise.resolve(this.current !== undefined);
  }

  hasDataType(mimeType: string): boolean {
    return this.current !== undefined && this.current.hasType(mimeType);
  }

  getData(): Promise<pasteboard.PasteData> {
    const held = this.read;
    this.read = undefined;
    if (held !== undefined) {
      return held.when();
    }
    const current = this.current;
    return current === undefined
      ? Promise.reject(new Error('no clipboard data'))
      : Promise.resolve(current);
  }

  setDataSync(data: pasteboard.PasteData): void {
    this.writes += 1;
    this.current = data;
  }

  clearDataSync(): void {
    this.clears += 1;
    this.current = undefined;
  }

  ensureReadAccess(): Promise<boolean> {
    return Promise.resolve(true);
  }

  hasReadAccess(): Promise<boolean> {
    return Promise.resolve(true);
  }

  resetReadAccess(): void {
  }

  /** A copy the user made. */
  copyLocal(data: pasteboard.PasteData): void {
    this.current = data;
  }

  /** The pasteboard update the controller's own listener would receive. */
  triggerUpdate(): void {
    const listener = this.listener;
    if (listener !== undefined) {
      listener();
    }
  }
}

function pasteData(text: string): pasteboard.PasteData {
  return pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
}

/** Lets every pending clipboard continuation run. */
async function settle(): Promise<void> {
  await new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, 0);
  });
  await new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, 0);
  });
}

/** What the controller handed to the peer. */
class SentText {
  readonly contents: string[] = [];
}

function clipboardCallbacks(sent: SentText): RustDeskClipboardControllerCallbacks {
  return {
    sendText: (_sessionId: string, content: string): boolean => {
      sent.contents.push(content);
      return true;
    },
    sendImage: (_sessionId: string, _image: Uint8Array): boolean => false,
    sendFiles: (_sessionId: string, _paths: Array<string>): boolean => false,
    supportsRichClipboard: (_sessionId: string): boolean => false,
    log: (_label: string, _payload: string): void => {},
  };
}

export default function rustDeskClipboardControllerTest(): void {
  describe('RustDeskClipboardControllerTest', () => {
    it('carries clipboard text on every desktop wire and rich payloads only on Core', 0, () => {
      expect(carriesTextClipboard('remote_control')).assertTrue();
      expect(carriesTextClipboard('vnc')).assertTrue();
      expect(carriesTextClipboard('rdp')).assertTrue();
      expect(carriesTextClipboard('file_transfer')).assertFalse();

      expect(carriesRichClipboard('remote_control')).assertTrue();
      expect(carriesRichClipboard('vnc')).assertFalse();
      expect(carriesRichClipboard('rdp')).assertFalse();
      expect(carriesRichClipboard('file_transfer')).assertFalse();
    });

    it('admits clipboard text only for an enabled session that carries it', 0, () => {
      expect(clipboardTextSyncAllowed(true, 'remote_control', false)).assertTrue();
      expect(clipboardTextSyncAllowed(true, 'vnc', false)).assertTrue();
      expect(clipboardTextSyncAllowed(true, 'rdp', false)).assertTrue();

      // The session's own switch, and the operator's.
      expect(clipboardTextSyncAllowed(true, 'vnc', true)).assertFalse();
      expect(clipboardTextSyncAllowed(false, 'remote_control', false)).assertFalse();
      expect(clipboardTextSyncAllowed(false, 'vnc', true)).assertFalse();

      // A session kind with no clipboard text channel at all.
      expect(clipboardTextSyncAllowed(true, 'file_transfer', false)).assertFalse();
    });

    it('reads an empty peer text as a clear and an absent one as nothing', 0, () => {
      const cleared: RustDeskRemoteClipboardPayload = { text: '' };
      expect(isRemoteClipboardClear(cleared)).assertTrue();

      // No text at all is not a clear: there is nothing to apply either way.
      expect(isRemoteClipboardClear({})).assertFalse();
      expect(isRemoteClipboardClear({ text: 'x' })).assertFalse();

      // A payload that still carries something is not empty.
      expect(isRemoteClipboardClear({ text: '', html: '<p></p>' })).assertFalse();
      expect(isRemoteClipboardClear({ text: '', files: ['/a'] })).assertFalse();
      expect(isRemoteClipboardClear({ files: [] })).assertFalse();
    });

    it('does not forward text the session already applied or sent', 0, () => {
      // The peer's own text comes back through the local clipboard once applied.
      expect(isClipboardTextEcho('hello', 'hello', undefined)).assertTrue();
      // Our own send comes back through the pasteboard update listener.
      expect(isClipboardTextEcho('hello', undefined, 'text:hello')).assertTrue();

      expect(isClipboardTextEcho('hello', 'other', 'text:other')).assertFalse();
      // An image or file signature never suppresses text.
      expect(isClipboardTextEcho('hello', undefined, 'files:/a')).assertFalse();
      expect(isClipboardTextEcho('hello', undefined, undefined)).assertFalse();
    });

    it('commits a peer payload inside the admitted turn', 0, async () => {
      const host = new TestClipboardHost();
      const sent = new SentText();
      const controller = new RustDeskClipboardController(host, clipboardCallbacks(sent));
      controller.start('s1');
      await settle();

      // No await between the admission check and the mutation: the write is already
      // complete when the call returns, so nothing can be left outstanding for a stop
      // to be overtaken by.
      controller.applyRemoteClipboard('s1', { text: 'peer-text' });
      expect(host.writes).assertEqual(1);
      await settle();
      controller.applyRemoteClipboard('s1', { text: '' });
      expect(host.clears).assertEqual(1);
      await settle();
      expect(host.clears).assertEqual(1);
    });

    it('re-reads a local copy made while a peer payload was being applied', 0, async () => {
      const host = new TestClipboardHost();
      const sent = new SentText();
      const controller = new RustDeskClipboardController(host, clipboardCallbacks(sent));
      controller.start('s1');
      await settle();

      // The commit is synchronous, but the apply is still finishing its post-write
      // work when the user copies something of their own.
      controller.applyRemoteClipboard('s1', { text: 'peer-text' });
      expect(host.writes).assertEqual(1);
      host.copyLocal(pasteData('fresh'));
      host.triggerUpdate();
      await settle();

      // That copy must not be lost to the peer's own change: it is read back and
      // forwarded.
      expect(sent.contents.length).assertEqual(1);
      expect(sent.contents[0]).assertEqual('fresh');
    });

    it('drops a peer payload that was queued before the session stopped', 0, async () => {
      const host = new TestClipboardHost();
      const sent = new SentText();
      const controller = new RustDeskClipboardController(host, clipboardCallbacks(sent));
      controller.start('s1');
      await settle();
      controller.stop();
      await settle();

      // A payload arriving while stopped is retained rather than written...
      controller.applyRemoteClipboard('s1', { text: 'peer-text' });
      expect(host.writes).assertEqual(0);

      // ...but a further stop ends the lifecycle that would have applied it, so the
      // next start does not carry it over a newer local clipboard.
      controller.stop();
      controller.start('s1');
      await settle();
      expect(host.writes).assertEqual(0);
    });

    it('retains a peer payload while stopped and applies it before the local read', 0, async () => {
      const host = new TestClipboardHost();
      const sent = new SentText();
      const controller = new RustDeskClipboardController(host, clipboardCallbacks(sent));
      controller.start('s1');
      await settle();
      controller.stop();
      await settle();

      // A payload that arrives while the session is stopped is retained, not written.
      host.copyLocal(pasteData('local-text'));
      controller.applyRemoteClipboard('s1', { text: 'peer-text' });
      expect(host.writes).assertEqual(0);

      // On resume the peer's text is applied first, so the session's own stale
      // clipboard is not sent over it.
      controller.start('s1');
      await settle();
      expect(host.writes).assertEqual(1);
      expect(sent.contents.length).assertEqual(0);
    });

    it('sends text again after the peer moved on', 0, async () => {
      const host = new TestClipboardHost();
      const sent = new SentText();
      const controller = new RustDeskClipboardController(host, clipboardCallbacks(sent));
      host.copyLocal(pasteData('same'));
      controller.start('s1');
      await settle();
      expect(sent.contents.length).assertEqual(1);
      expect(sent.contents[0]).assertEqual('same');

      // The peer replaces its clipboard, so what this session sent is no longer what
      // the peer holds.
      controller.applyRemoteClipboard('s1', { text: 'peer-text' });
      await settle();

      // The user deliberately copies the same text again.
      host.copyLocal(pasteData('same'));
      host.triggerUpdate();
      await settle();
      expect(sent.contents.length).assertEqual(2);
      expect(sent.contents[1]).assertEqual('same');
    });

    it('does not send back the files a peer just committed', 0, () => {
      const received = ['file://docs/a.pdf', 'file://docs/b.pdf'];
      const committed = fileClipboardSignature(received);

      // The pasteboard hands the committed payload back as its own URI records.
      expect(isClipboardFileEcho(received, committed, undefined)).assertTrue();
      // Our own send is recognized the same way.
      expect(isClipboardFileEcho(received, undefined, committed)).assertTrue();

      // A later, different local selection is not the peer's payload.
      expect(isClipboardFileEcho(['file://docs/c.pdf'], committed, undefined)).assertFalse();
      // Order is part of the identity.
      expect(isClipboardFileEcho([received[1], received[0]], committed, undefined)).assertFalse();
      expect(isClipboardFileEcho(received, undefined, undefined)).assertFalse();
    });

    it('does not echo a new tab payload applied before it starts', 0, async () => {
      const host = new TestClipboardHost();
      const sent = new SentText();
      const controller = new RustDeskClipboardController(host, clipboardCallbacks(sent));
      controller.start('A');
      await settle();
      controller.stop();
      await settle();

      // The activation path applies the new session's mailbox before starting it, and
      // the start resets the previous session's echo identity.
      controller.applyRemoteClipboard('B', { text: 'peer-B' });
      controller.start('B');
      await settle();
      expect(host.writes).assertEqual(1);

      // The pasteboard update that apply causes must not be read back and sent to B.
      host.triggerUpdate();
      await settle();
      expect(sent.contents.length).assertEqual(0);
    });

    it('drops a local read a peer apply overtook', 0, async () => {
      const host = new TestClipboardHost();
      const sent = new SentText();
      const controller = new RustDeskClipboardController(host, clipboardCallbacks(sent));
      host.copyLocal(pasteData('stale'));

      // The read is held inside getData.
      const read = new Deferred<pasteboard.PasteData>();
      host.read = read;
      controller.start('s1');
      await settle();

      // A peer update is applied before that read resolves.
      controller.applyRemoteClipboard('s1', { text: 'peer-text' });
      await settle();

      read.resolve(pasteData('stale'));
      await settle();
      expect(sent.contents.length).assertEqual(0);

      // A later local copy is still forwarded.
      host.copyLocal(pasteData('fresh'));
      host.triggerUpdate();
      await settle();
      expect(sent.contents.length).assertEqual(1);
      expect(sent.contents[0]).assertEqual('fresh');
    });
  });
}
