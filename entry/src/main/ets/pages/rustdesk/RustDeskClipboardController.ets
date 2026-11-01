import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { isDirectWireKind } from './DirectWireCredentials';

const MAX_CLIPBOARD_FILES = 64;
const MAX_CLIPBOARD_IMAGE_BYTES = 64 * 1024 * 1024;
const MAX_CLIPBOARD_IMAGE_PIXELS = MAX_CLIPBOARD_IMAGE_BYTES / 4;
const MAX_CLIPBOARD_IMAGE_DIMENSION = 16384;
const CLIPBOARD_STAGING_GENERATIONS = 2;
const MAX_CLIPBOARD_STAGED_BYTES = 4 * 1024 * 1024 * 1024;
const MAX_CLIPBOARD_STAGED_ENTRIES = 16384;
const MAX_CLIPBOARD_STAGED_DEPTH = 64;

interface ClipboardStagingNode {
  path: string;
  depth: number;
}

interface ClipboardIncomingRoot {
  path: string;
  mtime: number;
}

export interface RustDeskRemoteClipboardImage {
  format: string;
  width: number;
  height: number;
  bytes: Uint8Array;
}

export interface RustDeskRemoteClipboardPayload {
  text?: string;
  html?: string;
  image?: RustDeskRemoteClipboardImage;
  files?: Array<string>;
}

export interface RustDeskClipboardControllerCallbacks {
  sendText: (sessionId: string, content: string) => boolean;
  sendImage: (sessionId: string, image: Uint8Array) => boolean;
  sendFiles: (sessionId: string, paths: Array<string>) => boolean;
  /**
   * Whether this session can carry file and image clipboard payloads at all.
   *
   * A session that cannot must not have its local files copied into the staging
   * area or its pixel maps decoded: the send would be refused after the work was
   * done, while the text on the same clipboard still has to be forwarded.
   */
  supportsRichClipboard: (sessionId: string) => boolean;
  log: (label: string, payload: string) => void;
}

/** Whether a session kind carries clipboard text: a RustDesk session or a direct wire. */
export function carriesTextClipboard(kind: string): boolean {
  return kind === 'remote_control' || isDirectWireKind(kind);
}

/**
 * Whether a session kind carries file and image clipboard payloads.
 *
 * Only the RustDesk Core wire has those channels; a direct VNC/RDP wire carries
 * text only, so staging a file or decoding a pixel map for one would be work whose
 * result the peer refuses.
 */
export function carriesRichClipboard(kind: string): boolean {
  return kind === 'remote_control';
}

/**
 * Whether the active session's clipboard text may be synchronized right now.
 *
 * The operator's own switch gates it, and so does the session's `disable-clipboard`
 * option: the wire enforces that option as well, so honouring it here keeps the
 * local read path from copying text the peer would refuse.
 */
export function clipboardTextSyncAllowed(
  syncEnabled: boolean,
  kind: string,
  sessionClipboardDisabled: boolean,
): boolean {
  return syncEnabled && carriesTextClipboard(kind) && !sessionClipboardDisabled;
}

/**
 * Whether a peer payload says the remote clipboard is now empty.
 *
 * An empty text is a clear, not a text: the peer removed what it held, so the
 * local clipboard must not be left holding it. Absent text is no text at all,
 * which is what an image-only or file-only payload looks like.
 */
export function isRemoteClipboardClear(payload: RustDeskRemoteClipboardPayload): boolean {
  return payload.text !== undefined && payload.text.length === 0
    && payload.html === undefined
    && payload.image === undefined
    && (payload.files === undefined || payload.files.length === 0);
}

/**
 * The identity of a file clipboard payload: the URIs it publishes, in order.
 *
 * It is what both sides of an echo comparison are built from, because the pasteboard
 * hands a published file payload back as its URI records.
 */
export function fileClipboardSignature(uris: Array<string>): string {
  return `files:${uris.join('\n')}`;
}

/**
 * Whether a locally read file payload is the one this session already applied or sent.
 *
 * The peer's files arrive as the URI records its own apply published, and our sends
 * come back through the pasteboard update listener; neither may be staged and sent
 * again.
 */
export function isClipboardFileEcho(
  uris: Array<string>,
  lastRemoteFileSignature: string | undefined,
  lastLocalSignature: string | undefined,
): boolean {
  const signature = fileClipboardSignature(uris);
  return signature === lastRemoteFileSignature || signature === lastLocalSignature;
}

/**
 * Whether locally read text is text this session already applied or sent.
 *
 * The peer's own text arrives back through the local clipboard once it is applied,
 * and our own sends come back through the pasteboard update listener. The applied
 * text is recognized by its content, while our own sends are recognized by the
 * signature they were sent under, because a clipboard read may hand back a
 * normalized form of what was written.
 */
export function isClipboardTextEcho(
  content: string,
  lastRemoteText: string | undefined,
  lastLocalSignature: string | undefined,
): boolean {
  return content === lastRemoteText || `text:${content}` === lastLocalSignature;
}

/**
 * The clipboard surface the controller drives.
 *
 * It is a port so the controller's ordering rules — a local read overtaken by a
 * peer write, a clear queued across a lifecycle boundary, a peer update that
 * supersedes the local send history — can be exercised against a pasteboard a test
 * resolves on demand. Production passes `RustDeskSystemClipboardHost`, which drives
 * the system pasteboard and answers the read permission from the ability context.
 */
export interface RustDeskClipboardHost {
  readonly filesDir: string;
  readonly cacheDir: string;
  onUpdate(listener: () => void): void;
  offUpdate(listener: () => void): void;
  hasData(): Promise<boolean>;
  hasDataType(mimeType: string): boolean;
  getData(): Promise<pasteboard.PasteData>;
  /**
   * Writes the data into the system pasteboard synchronously.
   *
   * The commit is synchronous on purpose: the caller has already done its
   * potentially asynchronous preparation and validated admission, and a commit that
   * could still be outstanding when a lifecycle boundary arrives could not be
   * fenced by any later check.
   */
  setDataSync(data: pasteboard.PasteData): void;
  /** Empties the system pasteboard synchronously, with the same reasoning. */
  clearDataSync(): void;
  /** Whether the local clipboard may be read, requesting the permission once. */
  ensureReadAccess(): Promise<boolean>;
  /** Whether it may be read right now, without asking for the permission. */
  hasReadAccess(): Promise<boolean>;
  /** Forgets the read-access decision so the next read checks it again. */
  resetReadAccess(): void;
}

/** The system pasteboard and the ability context behind it. */
export class RustDeskSystemClipboardHost implements RustDeskClipboardHost {
  readonly filesDir: string;
  readonly cacheDir: string;
  private readonly context: common.UIAbilityContext;
  private readonly log: (label: string, payload: string) => void;
  private readonly systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
  private readonly atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  private readonly permissions: Permissions[] = ['ohos.permission.READ_PASTEBOARD'];
  private permissionRequestAttempted: boolean = false;
  private permissionGranted: boolean = false;

  constructor(context: common.UIAbilityContext, log: (label: string, payload: string) => void) {
    this.context = context;
    this.log = log;
    this.filesDir = context.filesDir;
    this.cacheDir = context.cacheDir;
  }

  onUpdate(listener: () => void): void {
    this.systemPasteboard.on('update', listener);
  }

  offUpdate(listener: () => void): void {
    this.systemPasteboard.off('update', listener);
  }

  hasData(): Promise<boolean> {
    return this.systemPasteboard.hasData();
  }

  hasDataType(mimeType: string): boolean {
    return this.systemPasteboard.hasDataType(mimeType);
  }

  getData(): Promise<pasteboard.PasteData> {
    return this.systemPasteboard.getData();
  }

  setDataSync(data: pasteboard.PasteData): void {
    this.systemPasteboard.setDataSync(data);
  }

  clearDataSync(): void {
    this.systemPasteboard.clearDataSync();
  }

  async ensureReadAccess(): Promise<boolean> {
    if (this.permissionGranted) {
      return true;
    }
    const permission = this.permissions[0];
    const tokenId = this.context.applicationInfo.accessTokenId;
    try {
      const current = await this.atManager.checkAccessToken(tokenId, permission);
      if (current === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        this.permissionGranted = true;
        return true;
      }
    } catch (error) {
      this.log('clipboard_permission', `status check failed=${String(error)}`);
    }
    if (this.permissionRequestAttempted) {
      return false;
    }
    this.permissionRequestAttempted = true;
    try {
      await this.atManager.requestPermissionsFromUser(this.context, this.permissions);
      const updated = await this.atManager.checkAccessToken(tokenId, permission);
      this.permissionGranted = updated === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      this.log('clipboard_permission', `request failed=${String(error)}`);
      this.permissionGranted = false;
    }
    if (!this.permissionGranted) {
      this.log('clipboard_permission', 'READ_PASTEBOARD was not granted');
    }
    return this.permissionGranted;
  }

  async hasReadAccess(): Promise<boolean> {
    if (this.permissionGranted) {
      return true;
    }
    try {
      const status = await this.atManager.checkAccessToken(
        this.context.applicationInfo.accessTokenId,
        this.permissions[0],
      );
      this.permissionGranted = status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      this.log('clipboard_permission', `status check failed=${String(error)}`);
      this.permissionGranted = false;
    }
    return this.permissionGranted;
  }

  resetReadAccess(): void {
    this.permissionGranted = false;
    this.permissionRequestAttempted = false;
  }
}

export class RustDeskClipboardController {
  private readonly host: RustDeskClipboardHost;
  private readonly callbacks: RustDeskClipboardControllerCallbacks;
  private active: boolean = false;
  private sessionId: string = '';
  private lifecycleGeneration: number = 0;
  private readInFlight: boolean = false;
  private readAgain: boolean = false;
  private remoteWriteInFlight: boolean = false;
  private readonly remoteWriteIdleWaiters: Array<() => void> = [];
  /**
   * How many peer clipboard applies have started.
   *
   * The session epoch is not enough to judge a local read: a peer apply in the same
   * session supersedes a snapshot taken before it, so a read carries the revision it
   * started under and is dropped when a peer apply began meanwhile.
   */
  private peerApplyRevision: number = 0;
  private pendingRemoteClipboard: RustDeskRemoteClipboardPayload | undefined = undefined;
  private pendingRemoteSessionId: string = '';
  private lastRemoteText: string | undefined = undefined;
  private lastRemoteImageSignature: string | undefined = undefined;
  private lastRemoteFileSignature: string | undefined = undefined;
  private lastLocalSignature: string | undefined = undefined;
  private stagingGeneration: number = 0;
  private readonly stagingRoots: Array<string> = [];
  private readonly activeCopySignals: Array<fileIo.TaskSignal> = [];
  private retainedClosedIncomingRoots: Array<string> = [];
  private incomingRoot: string = '';
  private readonly onPasteboardUpdate = (): void => {
    if (!this.active) {
      return;
    }
    if (this.remoteWriteInFlight) {
      // The pasteboard changed while a peer payload was being applied: the user may
      // have copied something of their own in that window, and the write is about to
      // overwrite it. The update is remembered so the completion re-reads the
      // pasteboard instead of treating the change as this write's own echo.
      this.readAgain = true;
      return;
    }
    void this.cleanupRetainedIncomingRoots().then((): void => {
      this.readAndSendLocalClipboard();
    });
  };

  constructor(host: RustDeskClipboardHost, callbacks: RustDeskClipboardControllerCallbacks) {
    this.host = host;
    this.callbacks = callbacks;
  }

  start(sessionId: string): void {
    if (sessionId.length === 0) {
      this.stop();
      return;
    }
    if (this.active && this.sessionId === sessionId) {
      return;
    }
    const sessionChanged = this.sessionId !== sessionId;
    this.lifecycleGeneration += 1;
    this.sessionId = sessionId;
    if (sessionChanged) {
      if (this.pendingRemoteSessionId !== sessionId) {
        this.pendingRemoteClipboard = undefined;
        this.pendingRemoteSessionId = '';
      }
      this.lastRemoteText = undefined;
      this.lastRemoteImageSignature = undefined;
      this.lastRemoteFileSignature = undefined;
      this.lastLocalSignature = undefined;
      this.cancelActiveCopies();
    }
    if (this.active) {
      this.stopListener();
    }
    try {
      this.host.onUpdate(this.onPasteboardUpdate);
      this.active = true;
    } catch (error) {
      this.callbacks.log('clipboard_listener', `start failed=${String(error)}`);
      return;
    }
    if (this.pendingRemoteClipboard !== undefined) {
      this.flushRemoteClipboard();
      return;
    }
    void this.cleanupRetainedIncomingRoots().then((): void => {
      this.readAndSendLocalClipboard();
    });
  }

  stop(): void {
    const wasActive = this.active;
    this.lifecycleGeneration += 1;
    this.active = false;
    if (wasActive) {
      this.stopListener();
    }
    this.cancelActiveCopies();
    // Queued peer work belongs to the lifecycle that admitted it. It is dropped
    // here rather than carried into the next start, where it would be applied under
    // a fresh generation and could overwrite what the user copied meanwhile: a
    // clear queued before a pause must not erase a newer local clipboard on resume.
    this.pendingRemoteClipboard = undefined;
    this.pendingRemoteSessionId = '';
    this.readAgain = false;
    this.host.resetReadAccess();
  }

  async stopAndDrainRemoteWrite(): Promise<void> {
    this.stop();
    if (!this.remoteWriteInFlight) {
      return;
    }
    await new Promise<void>((resolve: () => void): void => {
      this.remoteWriteIdleWaiters.push(resolve);
    });
  }

  private stopListener(): void {
    try {
      this.host.offUpdate(this.onPasteboardUpdate);
    } catch (error) {
      this.callbacks.log('clipboard_listener', `stop failed=${String(error)}`);
    }
  }

  reset(): void {
    this.stop();
    this.pendingRemoteClipboard = undefined;
    this.pendingRemoteSessionId = '';
    this.lastRemoteText = undefined;
    this.lastRemoteImageSignature = undefined;
    this.lastRemoteFileSignature = undefined;
    this.lastLocalSignature = undefined;
    this.host.resetReadAccess();
    this.sessionId = '';
    this.incomingRoot = '';
    this.cleanupAllStagingRoots();
  }

  applyRemoteText(sessionId: string, content: string): void {
    this.applyRemoteClipboard(sessionId, { text: content });
  }

  applyRemoteClipboard(sessionId: string, payload: RustDeskRemoteClipboardPayload): void {
    if (sessionId.length === 0) {
      return;
    }
    // The echo identity of a peer payload is established when it is committed, not
    // when it is queued: a queued payload can be dropped at a lifecycle boundary or
    // survive a session switch, and only the payload that actually reaches the
    // pasteboard may be recognized as the peer's own. What is recorded here is only
    // that the peer moved on, so the local send history is no longer current.
    this.lastLocalSignature = undefined;
    this.pendingRemoteClipboard = payload;
    this.pendingRemoteSessionId = sessionId;
    this.flushRemoteClipboard();
  }

  incomingFileRoot(sessionId: string): string {
    const safeSessionId = sessionId.replace(/[^A-Za-z0-9_-]/g, '_');
    const parent = `${this.host.filesDir}/rustdesk-clipboard-in`;
    this.incomingRoot = `${parent}/${safeSessionId}`;
    this.cleanupOldIncomingRoots(parent, this.incomingRoot);
    return this.incomingRoot;
  }

  async cleanupIncomingRootForClosedSession(sessionId: string): Promise<void> {
    if (sessionId.length === 0) {
      return;
    }
    const safeSessionId = sessionId.replace(/[^A-Za-z0-9_-]/g, '_');
    if (safeSessionId.length === 0) {
      return;
    }
    const parent = `${this.host.filesDir}/rustdesk-clipboard-in`;
    const root = `${parent}/${safeSessionId}`;
    try {
      if (!await this.host.hasReadAccess()) {
        return;
      }
      if (await this.host.hasData()
        && this.host.hasDataType(pasteboard.MIMETYPE_TEXT_URI)) {
        const data = await this.host.getData();
        const uris = this.collectDefaultUris(data);
        const rootUri = fileUri.getUriFromPath(root);
        for (const uri of uris) {
          if (uri === rootUri || uri.startsWith(`${rootUri}/`)) {
            // The process-global pasteboard still publishes this URI. Keep
            // only this bounded root until it is superseded.
            if (!this.retainedClosedIncomingRoots.includes(root)) {
              this.retainedClosedIncomingRoots.push(root);
            }
            return;
          }
        }
      }
      this.removeTree(root);
      this.retainedClosedIncomingRoots = this.retainedClosedIncomingRoots.filter(
        (retainedRoot: string): boolean => retainedRoot !== root,
      );
      if (this.incomingRoot === root) {
        this.incomingRoot = '';
      }
    } catch (error) {
      this.callbacks.log('clipboard_cleanup', `closed session cleanup skipped=${String(error)}`);
    }
  }

  private async cleanupRetainedIncomingRoots(): Promise<void> {
    if (this.retainedClosedIncomingRoots.length === 0) {
      return;
    }
    try {
      if (!await this.host.hasReadAccess()) {
        return;
      }
      const publishedUris: Array<string> = [];
      if (await this.host.hasData()
        && this.host.hasDataType(pasteboard.MIMETYPE_TEXT_URI)) {
        const data = await this.host.getData();
        publishedUris.push(...this.collectDefaultUris(data));
      }
      const remaining: Array<string> = [];
      for (const root of this.retainedClosedIncomingRoots) {
        const rootUri = fileUri.getUriFromPath(root);
        const stillPublished = publishedUris.some((uri: string): boolean =>
          uri === rootUri || uri.startsWith(`${rootUri}/`));
        if (stillPublished) {
          remaining.push(root);
        } else {
          this.removeTree(root);
        }
      }
      this.retainedClosedIncomingRoots = remaining;
    } catch (error) {
      this.callbacks.log('clipboard_cleanup', `retained root cleanup skipped=${String(error)}`);
    }
  }

  private cleanupOldIncomingRoots(parent: string, currentRoot: string): void {
    let names: Array<string> = [];
    try {
      names = fileIo.listFileSync(parent);
    } catch (_) {
      return;
    }
    const roots: Array<ClipboardIncomingRoot> = [];
    for (const name of names) {
      if (!/^[A-Za-z0-9_-]+$/.test(name)) {
        continue;
      }
      const path = `${parent}/${name}`;
      if (path === currentRoot) {
        continue;
      }
      try {
        const stat = fileIo.lstatSync(path);
        if (stat.isSymbolicLink()) {
          fileIo.unlinkSync(path);
        } else if (stat.isDirectory()) {
          roots.push({ path, mtime: stat.mtime });
        }
      } catch (_) {
      }
    }
    roots.sort((left: ClipboardIncomingRoot, right: ClipboardIncomingRoot): number =>
      right.mtime - left.mtime);
    if (roots.length > 0 && !this.retainedClosedIncomingRoots.includes(roots[0].path)) {
      this.retainedClosedIncomingRoots.push(roots[0].path);
    }
    // Keep only the most recent previous root so the current system
    // pasteboard URI remains usable without allowing per-session data to grow
    // without bound across reconnects and app restarts.
    for (let index = 1; index < roots.length; index += 1) {
      this.removeTree(roots[index].path);
    }
  }

  private async flushRemoteClipboard(): Promise<void> {
    if (!this.active || this.remoteWriteInFlight || this.pendingRemoteClipboard === undefined
      || this.pendingRemoteSessionId !== this.sessionId) {
      return;
    }
    const payload = this.pendingRemoteClipboard;
    const generation = this.lifecycleGeneration;
    const sessionId = this.sessionId;
    this.pendingRemoteClipboard = undefined;
    this.pendingRemoteSessionId = '';
    this.remoteWriteInFlight = true;
    // This is the payload the peer's clipboard now holds, so its echo identity is
    // recorded here: after any session-switch reset, and before its own pasteboard
    // update can be reconciled and read back as a local copy.
    this.lastRemoteText = payload.text;
    this.lastRemoteImageSignature = payload.image === undefined
      ? undefined
      : this.byteSignature(payload.image.bytes);
    this.lastRemoteFileSignature = payload.files !== undefined && payload.files.length > 0
      ? fileClipboardSignature(this.publishedFileUris(payload.files))
      : undefined;
    // This apply supersedes any local read that started before it: the snapshot such
    // a read is holding is older than the peer's state.
    this.peerApplyRevision += 1;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      if (isRemoteClipboardClear(payload)) {
        await this.applyRemoteClipboardClear(generation, sessionId);
        return;
      }
      let data: pasteboard.PasteData | undefined = undefined;
      if (payload.files !== undefined && payload.files.length > 0) {
        data = this.createFilePasteData(payload.files);
      } else if (payload.image !== undefined) {
        pixelMap = await this.createRemotePixelMap(payload.image);
        if (!this.isCurrentSession(generation, sessionId)) {
          return;
        }
        data = pasteboard.createData(pasteboard.MIMETYPE_PIXELMAP, pixelMap);
        const imageRecord = data.getRecord(0);
        if (payload.html !== undefined && payload.html.length > 0) {
          imageRecord.addEntry(pasteboard.MIMETYPE_TEXT_HTML, payload.html);
        }
        if (payload.text !== undefined && payload.text.length > 0) {
          imageRecord.addEntry(pasteboard.MIMETYPE_TEXT_PLAIN, payload.text);
        }
      } else if (payload.html !== undefined && payload.html.length > 0) {
        data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_HTML, payload.html);
        if (payload.text !== undefined && payload.text.length > 0) {
          data.getRecord(0).addEntry(pasteboard.MIMETYPE_TEXT_PLAIN, payload.text);
        }
      } else if (payload.text !== undefined) {
        data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, payload.text);
      }
      if (data === undefined) {
        return;
      }
      const property = data.getProperty();
      property.shareOption = pasteboard.ShareOption.LOCALDEVICE;
      data.setProperty(property);
      // Admission is checked before the write, not only after it, and the commit is
      // synchronous: no await separates the check from the mutation, so a stop or a
      // session change cannot leave a pasteboard write outstanding behind it.
      if (!this.isCurrentSession(generation, sessionId)) {
        return;
      }
      this.host.setDataSync(data);
      await this.cleanupRetainedIncomingRoots();
      if (!this.isCurrentSession(generation, sessionId)) {
        return;
      }
      this.callbacks.log(
        'clipboard_remote',
        `applied image=${payload.image !== undefined} files=${payload.files?.length ?? 0} text=${payload.text?.length ?? 0}`,
      );
    } catch (error) {
      this.callbacks.log('clipboard_remote', `failed=${String(error)}`);
    } finally {
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (_) {
        }
      }
      this.remoteWriteInFlight = false;
      while (this.remoteWriteIdleWaiters.length > 0) {
        const resolve = this.remoteWriteIdleWaiters.shift();
        if (resolve !== undefined) {
          resolve();
        }
      }
      if (this.active && this.pendingRemoteClipboard !== undefined
        && this.pendingRemoteSessionId === this.sessionId) {
        this.flushRemoteClipboard();
      } else if (this.active && this.readAgain) {
        this.readAgain = false;
        this.readAndSendLocalClipboard();
      }
    }
  }

  /**
   * Applies a remote clear to the system pasteboard.
   *
   * `clearDataSync` is the pasteboard's own clear; an empty text record is a
   * different operation and is not documented to be accepted. The retained file
   * roots are re-examined exactly as after a write, so a root the peer no longer
   * publishes is not kept alive by the clear.
   */
  private async applyRemoteClipboardClear(generation: number, sessionId: string): Promise<void> {
    // A clear cannot be undone, so admission is checked before it runs rather than
    // after, and the clear is committed synchronously in the same turn: no await
    // separates the check from the mutation, so a stop cannot be overtaken by a
    // clear that was already submitted.
    if (!this.isCurrentSession(generation, sessionId)) {
      return;
    }
    this.host.clearDataSync();
    await this.cleanupRetainedIncomingRoots();
    if (!this.isCurrentSession(generation, sessionId)) {
      return;
    }
    this.callbacks.log('clipboard_remote', 'applied clear');
  }

  /**
   * The URIs a committed file payload publishes, in order.
   *
   * The pasteboard hands these same URIs back on the next read, so they are the
   * identity the echo comparison is built from.
   */
  private publishedFileUris(paths: Array<string>): Array<string> {
    const uris: Array<string> = [];
    for (let index = 0; index < paths.length; index += 1) {
      uris.push(fileUri.getUriFromPath(paths[index]));
    }
    return uris;
  }

  private createFilePasteData(paths: Array<string>): pasteboard.PasteData {
    if (paths.length === 0 || paths.length > MAX_CLIPBOARD_FILES) {
      throw new Error('Remote file clipboard has an invalid path count');
    }
    if (this.incomingRoot.length === 0) {
      throw new Error('Remote file clipboard root is not configured');
    }
    const allowedRoot = `${this.incomingRoot}/`;
    for (const path of paths) {
      const relativePath = path.startsWith(allowedRoot) ? path.substring(allowedRoot.length) : '';
      const components = relativePath.split('/');
      if (relativePath.length === 0
        || components.some((component: string) => component.length === 0 || component === '.' || component === '..')) {
        throw new Error('Remote file clipboard path is outside the managed root');
      }
      fileIo.statSync(path);
    }
    const firstUri = fileUri.getUriFromPath(paths[0]);
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_URI, firstUri);
    for (let index = 1; index < paths.length; index += 1) {
      data.addRecord(pasteboard.MIMETYPE_TEXT_URI, fileUri.getUriFromPath(paths[index]));
    }
    return data;
  }

  private async createRemotePixelMap(remoteImage: RustDeskRemoteClipboardImage): Promise<image.PixelMap> {
    if (remoteImage.bytes.length === 0 || remoteImage.bytes.length > MAX_CLIPBOARD_IMAGE_BYTES) {
      throw new Error('Remote clipboard image has an invalid byte length');
    }
    const buffer = this.copyArrayBuffer(remoteImage.bytes);
    if (remoteImage.format === 'png') {
      const source = image.createImageSource(buffer);
      try {
        const info = await source.getImageInfo(0);
        this.validateRemoteImageSize(info.size.width, info.size.height);
        return await source.createPixelMap();
      } finally {
        await source.release();
      }
    }
    if (remoteImage.format === 'rgba') {
      this.validateRemoteImageSize(remoteImage.width, remoteImage.height);
      const expected = remoteImage.width * remoteImage.height * 4;
      if (expected !== remoteImage.bytes.length) {
        throw new Error('Remote RGBA clipboard dimensions do not match the payload');
      }
      const options: image.InitializationOptions = {
        editable: false,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        alphaType: image.AlphaType.UNPREMUL,
        size: { width: remoteImage.width, height: remoteImage.height },
      };
      return await image.createPixelMap(buffer, options);
    }
    throw new Error(`Unsupported remote clipboard image format=${remoteImage.format}`);
  }

  private validateRemoteImageSize(width: number, height: number): void {
    if (!Number.isInteger(width) || !Number.isInteger(height)
      || width <= 0 || height <= 0
      || width > MAX_CLIPBOARD_IMAGE_DIMENSION || height > MAX_CLIPBOARD_IMAGE_DIMENSION
      || width * height > MAX_CLIPBOARD_IMAGE_PIXELS) {
      throw new Error('Remote clipboard image dimensions exceed the safe decode limit');
    }
  }

  private async readAndSendLocalClipboard(): Promise<void> {
    if (!this.active) {
      return;
    }
    if (this.remoteWriteInFlight) {
      this.readAgain = true;
      return;
    }
    if (this.readInFlight) {
      this.readAgain = true;
      return;
    }
    this.readInFlight = true;
    const generation = this.lifecycleGeneration;
    const sessionId = this.sessionId;
    const applyRevision = this.peerApplyRevision;
    try {
      if (!await this.host.hasData()) {
        return;
      }
      if (!this.isLocalReadCurrent(generation, sessionId, applyRevision)) {
        return;
      }
      if (!await this.host.ensureReadAccess()) {
        return;
      }
      if (!this.isLocalReadCurrent(generation, sessionId, applyRevision)) {
        return;
      }
      const hasSupportedType = this.host.hasDataType(pasteboard.MIMETYPE_TEXT_URI)
        || this.host.hasDataType(pasteboard.MIMETYPE_PIXELMAP)
        || this.host.hasDataType(pasteboard.MIMETYPE_TEXT_HTML)
        || this.host.hasDataType(pasteboard.MIMETYPE_TEXT_PLAIN);
      if (!hasSupportedType) {
        return;
      }
      // There is deliberately no change-count short circuit here: the system count is
      // global and belongs to whichever writer produced it (this session, another
      // application, or the pasteboard expiring), so it can neither prove that this
      // session wrote the content nor prove that the content is an echo. Echo is
      // judged by the content itself, in the send helpers below.
      const data = await this.host.getData();
      if (!this.isLocalReadCurrent(generation, sessionId, applyRevision) || data.getRecordCount() === 0) {
        return;
      }
      if (this.callbacks.supportsRichClipboard(sessionId)) {
        const uris = this.collectDefaultUris(data);
        if (uris.length > 0) {
          await this.sendLocalFiles(uris, generation, sessionId, applyRevision);
          return;
        }
        const pixelMap = this.firstDefaultPixelMap(data);
        if (pixelMap !== undefined) {
          await this.sendLocalImage(pixelMap, generation, sessionId, applyRevision);
          return;
        }
      }
      this.sendLocalText(data, generation, sessionId, applyRevision);
    } catch (error) {
      this.callbacks.log('clipboard_local', `failed=${String(error)}`);
    } finally {
      this.readInFlight = false;
      if (this.active && this.readAgain) {
        this.readAgain = false;
        this.readAndSendLocalClipboard();
      }
    }
  }

  /**
   * Whether a local read may still hand its snapshot to the peer.
   *
   * The session epoch alone is not enough: a peer clipboard apply in the same
   * session supersedes a snapshot taken before it, so the apply revision the read
   * started under is part of the check. It is revalidated after every await and
   * immediately before the send, because the read's own awaits are long enough for
   * a peer update to be applied meanwhile.
   */
  private isLocalReadCurrent(generation: number, sessionId: string, applyRevision: number): boolean {
    return this.isCurrentSession(generation, sessionId) && applyRevision === this.peerApplyRevision;
  }

  private collectDefaultUris(data: pasteboard.PasteData): Array<string> {
    const uris: Array<string> = [];
    for (let index = 0; index < data.getRecordCount(); index += 1) {
      const record = data.getRecord(index);
      if (record.mimeType === pasteboard.MIMETYPE_TEXT_URI && record.uri.length > 0) {
        if (uris.length >= MAX_CLIPBOARD_FILES) {
          throw new Error(`Clipboard contains more than ${MAX_CLIPBOARD_FILES} files`);
        }
        uris.push(record.uri);
      }
    }
    return uris;
  }

  private firstDefaultPixelMap(data: pasteboard.PasteData): image.PixelMap | undefined {
    for (let index = 0; index < data.getRecordCount(); index += 1) {
      const record = data.getRecord(index);
      if (record.mimeType === pasteboard.MIMETYPE_PIXELMAP) {
        return record.pixelMap;
      }
    }
    return undefined;
  }

  private sendLocalText(
    data: pasteboard.PasteData,
    generation: number,
    sessionId: string,
    applyRevision: number,
  ): void {
    if (!this.isLocalReadCurrent(generation, sessionId, applyRevision)) {
      return;
    }
    for (let index = 0; index < data.getRecordCount(); index += 1) {
      const record = data.getRecord(index);
      if (record.mimeType !== pasteboard.MIMETYPE_TEXT_PLAIN
        && record.mimeType !== pasteboard.MIMETYPE_TEXT_HTML) {
        continue;
      }
      const content = record.mimeType === pasteboard.MIMETYPE_TEXT_PLAIN
        ? record.plainText
        : record.toPlainText();
      const signature = `text:${content}`;
      if (isClipboardTextEcho(content, this.lastRemoteText, this.lastLocalSignature)) {
        return;
      }
      if (this.callbacks.sendText(sessionId, content)) {
        this.lastLocalSignature = signature;
        this.callbacks.log('clipboard_local', `sent text length=${content.length}`);
      }
      return;
    }
  }

  private async sendLocalImage(
    pixelMap: image.PixelMap,
    generation: number,
    sessionId: string,
    applyRevision: number,
  ): Promise<void> {
    const packer = image.createImagePacker();
    try {
      const packed = await packer.packToData(pixelMap, { format: 'image/png', quality: 100 });
      if (!this.isLocalReadCurrent(generation, sessionId, applyRevision)) {
        return;
      }
      const bytes = new Uint8Array(packed);
      const signature = this.byteSignature(bytes);
      if (signature === this.lastRemoteImageSignature || `image:${signature}` === this.lastLocalSignature) {
        return;
      }
      if (this.callbacks.sendImage(sessionId, bytes)) {
        this.lastLocalSignature = `image:${signature}`;
        this.callbacks.log('clipboard_local', `sent image bytes=${bytes.length}`);
      }
    } finally {
      await packer.release();
    }
  }

  private async sendLocalFiles(
    uris: Array<string>,
    generation: number,
    sessionId: string,
    applyRevision: number,
  ): Promise<void> {
    // The peer's own files come back as the URI records its apply published, so they
    // are recognized before anything is staged or copied out.
    if (isClipboardFileEcho(uris, this.lastRemoteFileSignature, this.lastLocalSignature)) {
      return;
    }
    const signature = fileClipboardSignature(uris);
    const paths = await this.stageFileUris(uris, generation, sessionId);
    if (!this.isLocalReadCurrent(generation, sessionId, applyRevision) || paths.length === 0) {
      return;
    }
    if (this.callbacks.sendFiles(sessionId, paths)) {
      this.lastLocalSignature = signature;
      this.callbacks.log('clipboard_local', `sent files count=${paths.length}`);
    }
  }

  private async stageFileUris(
    uris: Array<string>,
    generation: number,
    sessionId: string,
  ): Promise<Array<string>> {
    this.stagingGeneration += 1;
    const root = `${this.host.cacheDir}/rustdesk-clipboard-out/${Date.now()}-${this.stagingGeneration}`;
    fileIo.mkdirSync(root, true);
    const paths: Array<string> = [];
    const stagedNames: Array<string> = [];
    let copiedBytes = 0;
    try {
      for (let index = 0; index < uris.length; index += 1) {
        const itemRoot = `${root}/item-${index}`;
        fileIo.mkdirSync(itemRoot, true);
        const copySignal = new fileIo.TaskSignal();
        this.activeCopySignals.push(copySignal);
        let itemProcessedBytes = 0;
        let sizeLimitExceeded = false;
        const copyOptions: fileIo.CopyOptions = {
          copySignal: copySignal,
          progressListener: (progress: fileIo.Progress): void => {
            itemProcessedBytes = progress.processedSize;
            if (copiedBytes + progress.totalSize > MAX_CLIPBOARD_STAGED_BYTES
              || copiedBytes + progress.processedSize > MAX_CLIPBOARD_STAGED_BYTES) {
              sizeLimitExceeded = true;
              try {
                copySignal.cancel();
              } catch (error) {
                this.callbacks.log('clipboard_stage_cancel', String(error));
              }
            }
          }
        };
        try {
          await fileIo.copy(uris[index], fileUri.getUriFromPath(itemRoot), copyOptions);
        } catch (error) {
          if (sizeLimitExceeded) {
            throw new Error('Clipboard staging exceeds 4 GiB');
          }
          throw new Error(String(error));
        } finally {
          this.removeCopySignal(copySignal);
        }
        if (!this.isCurrentSession(generation, sessionId)) {
          throw new Error('Clipboard session changed while staging files');
        }
        if (sizeLimitExceeded) {
          throw new Error('Clipboard staging exceeds 4 GiB');
        }
        copiedBytes += itemProcessedBytes;
        const names = fileIo.listFileSync(itemRoot);
        if (names.length !== 1) {
          throw new Error(`Clipboard URI ${index} produced ${names.length} staged entries`);
        }
        const stagedName = this.uniqueStagedName(names[0], stagedNames);
        if (stagedName !== names[0]) {
          fileIo.renameSync(`${itemRoot}/${names[0]}`, `${itemRoot}/${stagedName}`);
        }
        stagedNames.push(stagedName);
        paths.push(`${itemRoot}/${stagedName}`);
      }
      this.validateStagedTree(root);
    } catch (error) {
      this.removeTree(root);
      throw new Error(String(error));
    }
    this.stagingRoots.push(root);
    while (this.stagingRoots.length > CLIPBOARD_STAGING_GENERATIONS) {
      const staleRoot = this.stagingRoots.shift();
      if (staleRoot !== undefined) {
        this.removeTree(staleRoot);
      }
    }
    return paths;
  }

  private isCurrentSession(generation: number, sessionId: string): boolean {
    return this.active
      && generation === this.lifecycleGeneration
      && sessionId.length > 0
      && sessionId === this.sessionId;
  }

  private removeCopySignal(signal: fileIo.TaskSignal): void {
    const index = this.activeCopySignals.indexOf(signal);
    if (index >= 0) {
      this.activeCopySignals.splice(index, 1);
    }
  }

  private cancelActiveCopies(): void {
    while (this.activeCopySignals.length > 0) {
      const signal = this.activeCopySignals.pop();
      if (signal === undefined) {
        continue;
      }
      try {
        signal.cancel();
      } catch (_) {
      }
    }
  }

  private uniqueStagedName(name: string, usedNames: Array<string>): string {
    if (!usedNames.includes(name)) {
      return name;
    }
    const dot = name.lastIndexOf('.');
    const hasExtension = dot > 0 && dot < name.length - 1;
    const stem = hasExtension ? name.substring(0, dot) : name;
    const extension = hasExtension ? name.substring(dot) : '';
    let suffix = 2;
    let candidate = `${stem} (${suffix})${extension}`;
    while (usedNames.includes(candidate)) {
      suffix += 1;
      candidate = `${stem} (${suffix})${extension}`;
    }
    return candidate;
  }

  private validateStagedTree(root: string): void {
    const pending: Array<ClipboardStagingNode> = [{ path: root, depth: 0 }];
    let entryCount = 0;
    let totalBytes = 0;
    while (pending.length > 0) {
      const node = pending.pop();
      if (node === undefined) {
        break;
      }
      const stat = fileIo.lstatSync(node.path);
      if (stat.isSymbolicLink()) {
        throw new Error('Clipboard staging does not allow symbolic links');
      }
      entryCount += 1;
      if (entryCount > MAX_CLIPBOARD_STAGED_ENTRIES) {
        throw new Error(`Clipboard staging exceeds ${MAX_CLIPBOARD_STAGED_ENTRIES} entries`);
      }
      if (!stat.isDirectory()) {
        totalBytes += stat.size;
        if (totalBytes > MAX_CLIPBOARD_STAGED_BYTES) {
          throw new Error('Clipboard staging exceeds 4 GiB');
        }
        continue;
      }
      if (node.depth >= MAX_CLIPBOARD_STAGED_DEPTH) {
        throw new Error(`Clipboard staging exceeds depth ${MAX_CLIPBOARD_STAGED_DEPTH}`);
      }
      const names = fileIo.listFileSync(node.path);
      for (const name of names) {
        pending.push({ path: `${node.path}/${name}`, depth: node.depth + 1 });
      }
    }
  }

  private cleanupAllStagingRoots(): void {
    while (this.stagingRoots.length > 0) {
      const root = this.stagingRoots.shift();
      if (root !== undefined) {
        this.removeTree(root);
      }
    }
  }

  private removeTree(path: string): void {
    try {
      const stat = fileIo.lstatSync(path);
      if (stat.isDirectory() && !stat.isSymbolicLink()) {
        const names = fileIo.listFileSync(path);
        for (const name of names) {
          this.removeTree(`${path}/${name}`);
        }
        fileIo.rmdirSync(path);
      } else {
        fileIo.unlinkSync(path);
      }
    } catch (_) {
    }
  }

  private copyArrayBuffer(bytes: Uint8Array): ArrayBuffer {
    const copy = new Uint8Array(bytes.length);
    copy.set(bytes);
    return copy.buffer;
  }

  private byteSignature(bytes: Uint8Array): string {
    let hash = 2166136261;
    const step = Math.max(Math.floor(bytes.length / 4096), 1);
    for (let index = 0; index < bytes.length; index += step) {
      hash = Math.imul(hash ^ bytes[index], 16777619);
    }
    return `${bytes.length}:${hash >>> 0}`;
  }
}
