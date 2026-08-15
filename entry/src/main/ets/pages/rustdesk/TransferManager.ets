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
import { RemoteFilePath } from './RemoteFilePath';

type TransferSessionState = 'idle' | 'connecting' | 'awaiting_password' | 'ready' | 'failed';

export class TransferManager {
  private readonly bridge: NativeSessionBridge;
  private readonly sessionIdFactory: () => string;
  private fileSessionId: string = '';
  private downloadRoot: DownloadRoot | undefined = undefined;
  private remoteDirectory: string = '/';
  private remoteEntries: RemoteFileEntry[] = [];
  private transfers: TransferItem[] = [];
  private pendingTransfers: TransferItem[] = [];
  private issuedSessionIds: string[] = [];
  private passwordRequested: boolean = false;
  private passwordMessage: string = '';
  private sessionState: TransferSessionState = 'idle';
  private statusMessage: string = '文件传输未连接';
  private transferErrorMessage: string = '';
  private closeInProgress: boolean = false;

  constructor(bridge: NativeSessionBridge, sessionIdFactory: () => string) {
    this.bridge = bridge;
    this.sessionIdFactory = sessionIdFactory;
  }

  public open(target: string, password: string, forceRelay: boolean, root: DownloadRoot): boolean {
    if (this.closeInProgress || this.fileSessionId.length > 0 || root.path.trim().length === 0) {
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
      isViewOnly: false,
    };
    const addResponse = this.bridge.addSession(sessionId, target, options);
    if (!addResponse.ok) {
      this.statusMessage = addResponse.message?.trim() || '无法创建文件传输会话';
      return false;
    }
    const resolvedSessionId = addResponse.session?.sessionId.trim() || sessionId;
    this.fileSessionId = resolvedSessionId;
    this.downloadRoot = root;
    this.remoteDirectory = '/';
    this.remoteEntries = [];
    this.transfers = [];
    this.pendingTransfers = [];
    this.passwordRequested = false;
    this.passwordMessage = '';
    this.sessionState = 'connecting';
    this.statusMessage = '正在建立文件传输连接';
    this.transferErrorMessage = '';

    if (!this.bridge.startSession(resolvedSessionId).ok) {
      this.bridge.closeSession(resolvedSessionId);
      this.resetSessionState('文件传输连接启动失败');
      return false;
    }
    this.issuedSessionIds.push(resolvedSessionId);
    return true;
  }

  public poll(): boolean {
    if (this.closeInProgress || !this.isReady()) {
      return false;
    }
    const response = this.bridge.pollEvents(this.fileSessionId, 20);
    if (!response.ok) {
      this.sessionState = 'failed';
      this.statusMessage = response.message?.trim() || '文件传输事件通道已断开';
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
    if (!this.canTransfer() || !this.isSafeRemoteDirectoryPath(path)) {
      return false;
    }
    return this.bridge.readRemoteDir(this.fileSessionId, path).ok;
  }

  public download(remoteFullPath: string, localFullPath: string, totalBytes: number = 0): boolean {
    return this.startTransfer('download', remoteFullPath, localFullPath, totalBytes, true);
  }

  public cancel(actId: number): boolean {
    const item = this.findTransfer(actId);
    if (this.closeInProgress || !item || this.isTerminal(item) || !this.isReady()) {
      return false;
    }
    const response = this.bridge.cancelTransfer(this.fileSessionId, actId);
    if (!response.ok) {
      return false;
    }
    this.promoteTransfer(actId);
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
      this.sessionState = 'failed';
      this.statusMessage = response.message?.trim() || '文件传输密码提交失败';
      return false;
    }
    this.passwordRequested = false;
    this.passwordMessage = '';
    this.sessionState = 'connecting';
    this.statusMessage = '正在验证文件传输密码';
    return true;
  }

  public resolveOverride(actId: number, needOverride: boolean): boolean {
    const item = this.findTransfer(actId);
    if (!item || item.state !== 'awaiting_override' || !this.isReady()) {
      return false;
    }
    const response = this.bridge.setConfirmOverrideFile(
      this.fileSessionId,
      actId,
      item.fileNum,
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
      const title = String(event.title ?? '');
      const text = String(event.text ?? '');
      if (type === 'input-password' || type === 're-input-password') {
        this.passwordRequested = true;
        this.passwordMessage = title.length > 0 ? `${title}: ${text}` : text;
        this.sessionState = 'awaiting_password';
        this.statusMessage = '文件传输等待密码验证';
        return true;
      }
      if (title === 'Connection Error' || type.includes('error')) {
        this.sessionState = 'failed';
        this.statusMessage = title.length > 0 ? `${title}: ${text}` : (text || '文件传输连接失败');
        return true;
      }
      if (type === 'success') {
        return true;
      }
      this.statusMessage = title.length > 0 ? `${title}: ${text}` : (text || this.statusMessage);
      return true;
    }
    if (event.name === 'connection_ready') {
      this.statusMessage = '安全通道已建立，正在读取远端文件';
      return true;
    }
    if (event.name === 'peer_info' || event.name === 'sync_peer_info') {
      const shouldLoadDirectory = this.sessionState !== 'ready';
      this.sessionState = 'ready';
      this.statusMessage = '文件传输已连接';
      if (shouldLoadDirectory) {
        this.bridge.readRemoteDir(this.fileSessionId, this.remoteDirectory);
      }
      return true;
    }
    if (event.name === 'close') {
      this.sessionState = 'failed';
      this.statusMessage = '文件传输连接已结束';
      return true;
    }
    if (event.name === 'file_dir') {
      return this.handleRemoteDirectory(event);
    }

    const item = this.findTransferForEvent(event);
    if (!item || this.isTerminal(item)) {
      return false;
    }
    if (event.name === 'job_progress') {
      const fileNum = this.parseNonNegativeInteger(event.file_num);
      if (fileNum !== undefined) {
        item.fileNum = fileNum;
      }
      this.promoteTransfer(item.id);
      item.state = 'running';
      const speed = this.parseNonNegativeNumber(event.speed);
      if (speed !== undefined) {
        item.speedBytesPerSecond = speed;
      }
      const finishedSize = this.parseNonNegativeNumber(event.finished_size);
      if (finishedSize !== undefined) {
        item.transferredBytes = item.totalBytes > 0
          ? Math.min(finishedSize, item.totalBytes)
          : finishedSize;
      }
      return true;
    }
    if (event.name === 'job_done') {
      const fileNum = this.parseNonNegativeInteger(event.file_num);
      if (fileNum !== undefined) {
        item.fileNum = fileNum;
      }
      this.promoteTransfer(item.id);
      item.state = 'completed';
      if (item.totalBytes > item.transferredBytes) {
        item.transferredBytes = item.totalBytes;
      }
      return true;
    }
    if (event.name === 'job_error') {
      const fileNum = this.parseNonNegativeInteger(event.file_num);
      if (fileNum !== undefined) {
        item.fileNum = fileNum;
      }
      const error = event.err?.trim() || 'Transfer failed';
      if (error === 'cancel') {
        this.promoteTransfer(item.id);
        item.state = 'cancelled';
        item.errorText = '';
      } else if (error === 'skipped') {
        this.promoteTransfer(item.id);
        item.state = 'completed';
        item.transferredBytes = item.totalBytes;
        item.errorText = '';
      } else {
        if (this.isPendingTransfer(item.id)) {
          this.removePendingTransfer(item.id);
          this.transferErrorMessage = this.transferStartErrorMessage(item.direction, error);
          this.statusMessage = this.transferErrorMessage;
        } else {
          item.state = 'failed';
          item.errorText = error;
        }
      }
      return true;
    }
    if (event.name === 'override_file_confirm') {
      const fileNum = this.parseNonNegativeInteger(event.file_num);
      if (fileNum !== undefined) {
        item.fileNum = fileNum;
      }
      this.promoteTransfer(item.id);
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

  public canTransfer(): boolean {
    return this.isReady() && this.sessionState === 'ready';
  }

  public hasFailed(): boolean {
    return this.isReady() && this.sessionState === 'failed';
  }

  public getStatusMessage(): string {
    return this.statusMessage;
  }

  public consumeTransferError(): string | undefined {
    if (this.transferErrorMessage.length === 0) {
      return undefined;
    }
    const message = this.transferErrorMessage;
    this.transferErrorMessage = '';
    return message;
  }

  public close(): boolean {
    if (this.fileSessionId.length === 0) {
      this.resetSessionState('文件传输未连接');
      return true;
    }
    if (this.closeInProgress) {
      return true;
    }
    this.closeInProgress = true;
    const sessionId = this.fileSessionId;
    const response = this.bridge.closeSession(sessionId);
    this.resetSessionState('文件传输未连接');
    this.closeInProgress = false;
    return response.ok;
  }

  private startTransfer(
    direction: TransferDirection,
    sourcePath: string,
    destinationPath: string,
    totalBytes: number,
    isRemote: boolean,
  ): boolean {
    if (!this.canTransfer()
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
    const response = this.bridge.sendFiles(this.fileSessionId, actId, sourcePath, destinationPath, isRemote);
    if (response.ok) {
      this.pendingTransfers.push(item);
      this.statusMessage = direction === 'upload'
        ? '正在验证远端目录是否可写'
        : '正在验证本地目录是否可写';
      return true;
    }
    this.transferErrorMessage = this.transferStartErrorMessage(
      direction,
      response.message?.trim() || 'Unable to start transfer',
    );
    this.statusMessage = this.transferErrorMessage;
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
      if (directory.id > 0) {
        const item = this.findTransfer(directory.id);
        if (!item) {
          return false;
        }
        let totalBytes = 0;
        for (let index = 0; index < directory.entries.length; index += 1) {
          totalBytes += Math.max(Number(directory.entries[index].size), 0);
        }
        if (totalBytes > 0) {
          item.totalBytes = totalBytes;
        }
        return true;
      }
      this.sessionState = 'ready';
      this.statusMessage = '文件传输已连接';
      this.remoteDirectory = directory.path;
      this.remoteEntries = directory.entries;
      return true;
    } catch (_) {
      return false;
    }
  }

  private findTransferForEvent(event: NativeEvent): TransferItem | undefined {
    const actId = this.parsePositiveInteger(event.id);
    if (actId === undefined) {
      return undefined;
    }
    return this.findTransfer(actId);
  }

  private findTransfer(actId: number): TransferItem | undefined {
    for (let index = 0; index < this.transfers.length; index += 1) {
      const item = this.transfers[index];
      if (item.id === actId) {
        return item;
      }
    }
    for (let index = 0; index < this.pendingTransfers.length; index += 1) {
      const item = this.pendingTransfers[index];
      if (item.id === actId) {
        return item;
      }
    }
    return undefined;
  }

  private isPendingTransfer(actId: number): boolean {
    for (let index = 0; index < this.pendingTransfers.length; index += 1) {
      if (this.pendingTransfers[index].id === actId) {
        return true;
      }
    }
    return false;
  }

  private promoteTransfer(actId: number): void {
    const pending = this.findPendingTransfer(actId);
    if (pending === undefined) {
      return;
    }
    this.removePendingTransfer(actId);
    this.transfers.push(pending);
    this.statusMessage = '文件传输已连接';
  }

  private findPendingTransfer(actId: number): TransferItem | undefined {
    for (let index = 0; index < this.pendingTransfers.length; index += 1) {
      if (this.pendingTransfers[index].id === actId) {
        return this.pendingTransfers[index];
      }
    }
    return undefined;
  }

  private removePendingTransfer(actId: number): void {
    const remaining: TransferItem[] = [];
    for (let index = 0; index < this.pendingTransfers.length; index += 1) {
      if (this.pendingTransfers[index].id !== actId) {
        remaining.push(this.pendingTransfers[index]);
      }
    }
    this.pendingTransfers = remaining;
  }

  private transferStartErrorMessage(direction: TransferDirection, error: string): string {
    const destination = direction === 'upload' ? '远端目录' : '本地目录';
    return `${destination}无法创建文件或文件夹，无法开始传输：${error}`;
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
    return RemoteFilePath.isSafeAbsoluteDirectory(path);
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

  private resetSessionState(message: string): void {
    this.fileSessionId = '';
    this.downloadRoot = undefined;
    this.remoteDirectory = '/';
    this.remoteEntries = [];
    this.transfers = [];
    this.pendingTransfers = [];
    this.passwordRequested = false;
    this.passwordMessage = '';
    this.sessionState = 'idle';
    this.statusMessage = message;
    this.transferErrorMessage = '';
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
