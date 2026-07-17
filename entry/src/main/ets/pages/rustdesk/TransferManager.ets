import { NativeSessionBridge } from './NativeSessionBridge';
import {
  DownloadRoot,
  RemoteFileDirectory,
  RemoteFileEntry,
  SessionStartOptions,
  TransferDirection,
  TransferItem,
} from './RustDeskSessionTypes';
import { NativeEvent } from './RustDeskTypes';

export class TransferManager {
  private readonly bridge: NativeSessionBridge;
  private readonly sessionIdFactory: () => string;
  private fileSessionId: string = '';
  private downloadRoot: DownloadRoot | undefined = undefined;
  private remoteDirectory: string = '/';
  private remoteEntries: RemoteFileEntry[] = [];
  private transfers: TransferItem[] = [];
  private issuedSessionIds: string[] = [];
  private passwordRequested: boolean = false;
  private passwordMessage: string = '';

  constructor(bridge: NativeSessionBridge, sessionIdFactory: () => string) {
    this.bridge = bridge;
    this.sessionIdFactory = sessionIdFactory;
  }

  public open(target: string, password: string, forceRelay: boolean, root: DownloadRoot): boolean {
    if (this.fileSessionId.length > 0 || root.path.trim().length === 0) {
      return false;
    }

    const sessionId = this.nextFileSessionId();
    if (!sessionId) {
      return false;
    }

    const options: SessionStartOptions = {
      password,
      forceRelay,
      isFileTransfer: true,
      isViewCamera: false,
    };
    const addResponse = this.bridge.addSession(sessionId, target, options);
    if (!addResponse.ok) {
      return false;
    }
    const resolvedSessionId = addResponse.session?.sessionId.trim() || sessionId;
    if (!this.bridge.startSession(resolvedSessionId).ok) {
      this.bridge.closeSession(resolvedSessionId);
      return false;
    }
    if (!this.bridge.readRemoteDir(resolvedSessionId, '/').ok) {
      this.bridge.closeSession(resolvedSessionId);
      return false;
    }

    this.fileSessionId = resolvedSessionId;
    this.issuedSessionIds.push(resolvedSessionId);
    this.downloadRoot = root;
    this.remoteDirectory = '/';
    this.remoteEntries = [];
    this.transfers = [];
    this.passwordRequested = false;
    this.passwordMessage = '';
    return true;
  }

  public poll(): boolean {
    if (!this.isReady()) {
      return false;
    }
    const response = this.bridge.pollEvents(this.fileSessionId, 20);
    if (!response.ok) {
      return false;
    }
    const events = response.events ?? [];
    for (let index = 0; index < events.length; index += 1) {
      this.handleEvent(events[index]);
    }
    return true;
  }

  public upload(localFullPath: string, remoteFullPath: string, totalBytes: number = 0): boolean {
    return this.startTransfer('upload', localFullPath, remoteFullPath, totalBytes, false);
  }

  public readRemoteDirectory(path: string): boolean {
    if (!this.isReady() || !this.isSafeRemoteDirectoryPath(path)) {
      return false;
    }
    return this.bridge.readRemoteDir(this.fileSessionId, path).ok;
  }

  public download(remoteFullPath: string, localFullPath: string, totalBytes: number = 0): boolean {
    return this.startTransfer('download', remoteFullPath, localFullPath, totalBytes, true);
  }

  public cancel(actId: number): boolean {
    const item = this.findTransfer(actId, 0);
    if (!item || this.isTerminal(item) || !this.isReady()) {
      return false;
    }
    const response = this.bridge.cancelTransfer(this.fileSessionId, actId);
    if (!response.ok) {
      return false;
    }
    item.state = 'cancelled';
    return true;
  }

  public consumePasswordRequest(): string | undefined {
    if (!this.passwordRequested) {
      return undefined;
    }
    this.passwordRequested = false;
    return this.passwordMessage;
  }

  public login(password: string, remember: boolean = false): boolean {
    if (!this.isReady() || password.trim().length === 0) {
      return false;
    }
    const response = this.bridge.login(this.fileSessionId, password, remember);
    if (!response.ok) {
      return false;
    }
    this.passwordRequested = false;
    this.passwordMessage = '';
    this.bridge.readRemoteDir(this.fileSessionId, '/');
    return true;
  }

  public resolveOverride(actId: number, needOverride: boolean): boolean {
    const item = this.findTransfer(actId, 0);
    if (!item || item.state !== 'awaiting_override' || !this.isReady()) {
      return false;
    }
    const response = this.bridge.setConfirmOverrideFile(
      this.fileSessionId,
      actId,
      needOverride,
      item.direction === 'upload',
    );
    if (!response.ok) {
      return false;
    }
    item.state = 'queued';
    return true;
  }

  public handleEvent(event: NativeEvent): boolean {
    if (event.name === 'msgbox') {
      const type = String(event.type ?? '');
      if (type === 'input-password' || type === 're-input-password') {
        const title = String(event.title ?? '');
        const text = String(event.text ?? '');
        this.passwordRequested = true;
        this.passwordMessage = title.length > 0 ? `${title}: ${text}` : text;
        return true;
      }
      return false;
    }
    if (event.name === 'file_dir') {
      return this.handleRemoteDirectory(event);
    }

    const item = this.findTransferForEvent(event);
    if (!item || this.isTerminal(item)) {
      return false;
    }
    if (event.name === 'job_progress') {
      item.state = 'running';
      const speed = this.parseNonNegativeNumber(event.speed);
      if (speed !== undefined) {
        item.speedBytesPerSecond = speed;
      }
      const finishedSize = this.parseNonNegativeNumber(event.finished_size);
      if (finishedSize !== undefined) {
        item.transferredBytes = finishedSize;
      }
      return true;
    }
    if (event.name === 'job_done') {
      item.state = 'completed';
      if (item.totalBytes > item.transferredBytes) {
        item.transferredBytes = item.totalBytes;
      }
      return true;
    }
    if (event.name === 'job_error') {
      item.state = 'failed';
      item.errorText = event.err?.trim() || 'Transfer failed';
      return true;
    }
    if (event.name === 'override_file_confirm') {
      item.state = 'awaiting_override';
      return true;
    }
    return false;
  }

  public snapshot(): TransferItem[] {
    const snapshot: TransferItem[] = [];
    for (let index = 0; index < this.transfers.length; index += 1) {
      const item = this.transfers[index];
      snapshot.push({
        id: item.id,
        fileNum: item.fileNum,
        direction: item.direction,
        sourcePath: item.sourcePath,
        destinationPath: item.destinationPath,
        fileName: item.fileName,
        totalBytes: item.totalBytes,
        transferredBytes: item.transferredBytes,
        speedBytesPerSecond: item.speedBytesPerSecond,
        state: item.state,
        errorText: item.errorText,
      });
    }
    return snapshot;
  }

  public getRemoteDirectory(): string {
    return this.remoteDirectory;
  }

  public getRemoteEntries(): RemoteFileEntry[] {
    return this.remoteEntries.slice();
  }

  public isReady(): boolean {
    return this.fileSessionId.length > 0 && this.downloadRoot !== undefined;
  }

  public close(): boolean {
    if (!this.isReady()) {
      return false;
    }
    const response = this.bridge.closeSession(this.fileSessionId);
    if (!response.ok) {
      return false;
    }
    this.fileSessionId = '';
    this.downloadRoot = undefined;
    this.remoteDirectory = '/';
    this.remoteEntries = [];
    this.transfers = [];
    this.passwordRequested = false;
    this.passwordMessage = '';
    return true;
  }

  private startTransfer(
    direction: TransferDirection,
    sourcePath: string,
    destinationPath: string,
    totalBytes: number,
    isRemote: boolean,
  ): boolean {
    if (!this.isReady()
      || !this.isValidLocalPath(isRemote ? destinationPath : sourcePath)
      || !this.isSafeFilePath(sourcePath)
      || !this.isSafeFilePath(destinationPath)) {
      return false;
    }

    const actId = this.bridge.transferNextJobId();
    if (!Number.isInteger(actId) || actId <= 0) {
      return false;
    }
    const fileName = this.fileNameFromPath(sourcePath);
    if (!fileName) {
      return false;
    }
    const item: TransferItem = {
      id: actId,
      fileNum: 0,
      direction,
      sourcePath,
      destinationPath,
      fileName,
      totalBytes: this.normalizedTotalBytes(totalBytes),
      transferredBytes: 0,
      speedBytesPerSecond: 0,
      state: 'queued',
      errorText: '',
    };
    this.transfers.push(item);

    const response = this.bridge.sendFiles(this.fileSessionId, actId, sourcePath, destinationPath, isRemote);
    if (response.ok) {
      return true;
    }
    item.state = 'failed';
    item.errorText = response.message?.trim() || 'Unable to start transfer';
    return false;
  }

  private handleRemoteDirectory(event: NativeEvent): boolean {
    if (event.is_local !== 'false' || !event.value) {
      return false;
    }
    try {
      const directory = JSON.parse(event.value) as RemoteFileDirectory;
      if (directory.path.trim().length === 0) {
        return false;
      }
      this.remoteDirectory = directory.path;
      this.remoteEntries = directory.entries;
      return true;
    } catch (_) {
      return false;
    }
  }

  private findTransferForEvent(event: NativeEvent): TransferItem | undefined {
    const actId = this.parsePositiveInteger(event.id);
    const fileNum = this.parseNonNegativeInteger(event.file_num);
    if (actId === undefined || fileNum === undefined) {
      return undefined;
    }
    return this.findTransfer(actId, fileNum);
  }

  private findTransfer(actId: number, fileNum: number): TransferItem | undefined {
    for (let index = 0; index < this.transfers.length; index += 1) {
      const item = this.transfers[index];
      if (item.id === actId && item.fileNum === fileNum) {
        return item;
      }
    }
    return undefined;
  }

  private isValidLocalPath(path: string): boolean {
    if (!this.downloadRoot) {
      return false;
    }
    const root = this.downloadRoot.path.trim().replace(/\/+$/, '');
    const candidate = path.trim();
    if (root.length === 0 || !candidate.startsWith(`${root}/`)) {
      return false;
    }
    const relativePath = candidate.substring(root.length + 1).replace(/\\/g, '/');
    return !this.hasTraversalSegment(relativePath);
  }

  private isSafeFilePath(path: string): boolean {
    return this.fileNameFromPath(path) !== undefined;
  }

  private isSafeRemoteDirectoryPath(path: string): boolean {
    const normalized = path.trim().replace(/\\/g, '/');
    if (normalized.length === 0 || !normalized.startsWith('/')) {
      return false;
    }
    return !this.hasTraversalSegment(normalized);
  }

  private hasTraversalSegment(path: string): boolean {
    const segments = path.split('/');
    for (let index = 0; index < segments.length; index += 1) {
      if (segments[index] === '..') {
        return true;
      }
    }
    return false;
  }

  private isTerminal(item: TransferItem): boolean {
    return item.state === 'completed' || item.state === 'failed' || item.state === 'cancelled';
  }

  private nextFileSessionId(): string | undefined {
    const baseId = this.sessionIdFactory().trim();
    if (baseId.length === 0) {
      return undefined;
    }
    let candidate = baseId;
    let suffix = 1;
    while (this.hasIssuedSessionId(candidate)) {
      candidate = `${baseId}-${suffix}`;
      suffix += 1;
    }
    return candidate;
  }

  private hasIssuedSessionId(sessionId: string): boolean {
    for (let index = 0; index < this.issuedSessionIds.length; index += 1) {
      if (this.issuedSessionIds[index] === sessionId) {
        return true;
      }
    }
    return false;
  }

  private fileNameFromPath(path: string): string | undefined {
    const value = path.trim();
    const separator = Math.max(value.lastIndexOf('/'), value.lastIndexOf('\\'));
    const fileName = value.substring(separator + 1);
    if (fileName.length === 0 || fileName === '.' || fileName === '..' || fileName.includes('\0')) {
      return undefined;
    }
    return fileName;
  }

  private normalizedTotalBytes(totalBytes: number): number {
    if (!Number.isFinite(totalBytes) || totalBytes < 0) {
      return 0;
    }
    return Math.round(totalBytes);
  }

  private parsePositiveInteger(value: string | undefined): number | undefined {
    const parsed = this.parseNonNegativeInteger(value);
    if (parsed === undefined || parsed <= 0) {
      return undefined;
    }
    return parsed;
  }

  private parseNonNegativeInteger(value: string | undefined): number | undefined {
    const parsed = this.parseNonNegativeNumber(value);
    if (parsed === undefined || !Number.isInteger(parsed)) {
      return undefined;
    }
    return parsed;
  }

  private parseNonNegativeNumber(value: string | undefined): number | undefined {
    if (value === undefined || value.trim().length === 0) {
      return undefined;
    }
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0) {
      return undefined;
    }
    return parsed;
  }
}
