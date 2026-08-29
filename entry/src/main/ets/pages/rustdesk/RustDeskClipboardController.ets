import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

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
  log: (label: string, payload: string) => void;
}

export class RustDeskClipboardController {
  private readonly context: common.UIAbilityContext;
  private readonly callbacks: RustDeskClipboardControllerCallbacks;
  private readonly systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
  private readonly atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  private readonly permissions: Permissions[] = ['ohos.permission.READ_PASTEBOARD'];
  private active: boolean = false;
  private sessionId: string = '';
  private lifecycleGeneration: number = 0;
  private readInFlight: boolean = false;
  private readAgain: boolean = false;
  private remoteWriteInFlight: boolean = false;
  private readonly remoteWriteIdleWaiters: Array<() => void> = [];
  private permissionRequestAttempted: boolean = false;
  private permissionGranted: boolean = false;
  private pendingRemoteClipboard: RustDeskRemoteClipboardPayload | undefined = undefined;
  private pendingRemoteSessionId: string = '';
  private lastRemoteText: string | undefined = undefined;
  private lastRemoteImageSignature: string | undefined = undefined;
  private lastRemoteChangeCount: number = -1;
  private lastLocalSignature: string | undefined = undefined;
  private stagingGeneration: number = 0;
  private readonly stagingRoots: Array<string> = [];
  private readonly activeCopySignals: Array<fileIo.TaskSignal> = [];
  private retainedClosedIncomingRoots: Array<string> = [];
  private incomingRoot: string = '';
  private readonly onPasteboardUpdate = (): void => {
    if (!this.active || this.remoteWriteInFlight) {
      return;
    }
    void this.cleanupRetainedIncomingRoots().then((): void => {
      this.readAndSendLocalClipboard();
    });
  };

  constructor(context: common.UIAbilityContext, callbacks: RustDeskClipboardControllerCallbacks) {
    this.context = context;
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
      this.lastLocalSignature = undefined;
      this.cancelActiveCopies();
    }
    if (this.active) {
      this.stopListener();
    }
    try {
      this.systemPasteboard.on('update', this.onPasteboardUpdate);
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
    this.readAgain = false;
    this.permissionGranted = false;
    this.permissionRequestAttempted = false;
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
      this.systemPasteboard.off('update', this.onPasteboardUpdate);
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
    this.lastRemoteChangeCount = -1;
    this.lastLocalSignature = undefined;
    this.permissionRequestAttempted = false;
    this.permissionGranted = false;
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
    this.lastRemoteText = payload.text;
    this.lastRemoteImageSignature = payload.image === undefined
      ? undefined
      : this.byteSignature(payload.image.bytes);
    this.pendingRemoteClipboard = payload;
    this.pendingRemoteSessionId = sessionId;
    this.flushRemoteClipboard();
  }

  incomingFileRoot(sessionId: string): string {
    const safeSessionId = sessionId.replace(/[^A-Za-z0-9_-]/g, '_');
    const parent = `${this.context.filesDir}/rustdesk-clipboard-in`;
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
    const parent = `${this.context.filesDir}/rustdesk-clipboard-in`;
    const root = `${parent}/${safeSessionId}`;
    try {
      const permission = this.permissions[0];
      const tokenId = this.context.applicationInfo.accessTokenId;
      const status = await this.atManager.checkAccessToken(tokenId, permission);
      if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return;
      }
      if (await this.systemPasteboard.hasData()
        && this.systemPasteboard.hasDataType(pasteboard.MIMETYPE_TEXT_URI)) {
        const data = await this.systemPasteboard.getData();
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
      const permission = this.permissions[0];
      const tokenId = this.context.applicationInfo.accessTokenId;
      const status = await this.atManager.checkAccessToken(tokenId, permission);
      if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return;
      }
      const publishedUris: Array<string> = [];
      if (await this.systemPasteboard.hasData()
        && this.systemPasteboard.hasDataType(pasteboard.MIMETYPE_TEXT_URI)) {
        const data = await this.systemPasteboard.getData();
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
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
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
      await this.systemPasteboard.setData(data);
      // The pasteboard is process-global. Suppress this write even if the user
      // switched tabs while setData was awaiting completion.
      this.lastRemoteChangeCount = this.systemPasteboard.getChangeCount();
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
    try {
      if (!await this.systemPasteboard.hasData()) {
        return;
      }
      if (!this.isCurrentSession(generation, sessionId)) {
        return;
      }
      if (!await this.ensureReadPermission()) {
        return;
      }
      if (!this.isCurrentSession(generation, sessionId)) {
        return;
      }
      const hasSupportedType = this.systemPasteboard.hasDataType(pasteboard.MIMETYPE_TEXT_URI)
        || this.systemPasteboard.hasDataType(pasteboard.MIMETYPE_PIXELMAP)
        || this.systemPasteboard.hasDataType(pasteboard.MIMETYPE_TEXT_HTML)
        || this.systemPasteboard.hasDataType(pasteboard.MIMETYPE_TEXT_PLAIN);
      if (!hasSupportedType) {
        return;
      }
      if (this.systemPasteboard.getChangeCount() === this.lastRemoteChangeCount) {
        return;
      }
      const data = await this.systemPasteboard.getData();
      if (!this.isCurrentSession(generation, sessionId) || data.getRecordCount() === 0) {
        return;
      }
      const uris = this.collectDefaultUris(data);
      if (uris.length > 0) {
        await this.sendLocalFiles(uris, generation, sessionId);
        return;
      }
      const pixelMap = this.firstDefaultPixelMap(data);
      if (pixelMap !== undefined) {
        await this.sendLocalImage(pixelMap, generation, sessionId);
        return;
      }
      this.sendLocalText(data, generation, sessionId);
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
  ): void {
    if (!this.isCurrentSession(generation, sessionId)) {
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
      if (content === this.lastRemoteText || signature === this.lastLocalSignature) {
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
  ): Promise<void> {
    const packer = image.createImagePacker();
    try {
      const packed = await packer.packToData(pixelMap, { format: 'image/png', quality: 100 });
      if (!this.isCurrentSession(generation, sessionId)) {
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
  ): Promise<void> {
    const signature = `files:${uris.join('\n')}`;
    if (signature === this.lastLocalSignature) {
      return;
    }
    const paths = await this.stageFileUris(uris, generation, sessionId);
    if (!this.isCurrentSession(generation, sessionId) || paths.length === 0) {
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
    const root = `${this.context.cacheDir}/rustdesk-clipboard-out/${Date.now()}-${this.stagingGeneration}`;
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

  private async ensureReadPermission(): Promise<boolean> {
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
      this.callbacks.log('clipboard_permission', `status check failed=${String(error)}`);
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
      this.callbacks.log('clipboard_permission', `request failed=${String(error)}`);
      this.permissionGranted = false;
    }
    if (!this.permissionGranted) {
      this.callbacks.log('clipboard_permission', 'READ_PASTEBOARD was not granted');
    }
    return this.permissionGranted;
  }
}
