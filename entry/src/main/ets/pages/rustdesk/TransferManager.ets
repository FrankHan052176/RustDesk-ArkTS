import { NativeSessionBridge } from './NativeSessionBridge';
import {
  DownloadRoot,
  RemoteFileDirectory,
  RemoteFileEntry,
  SessionStartOptions,
  TransferDirection,
  TransferItem,
} from './RustDeskSessionTypes';
import { ApprovedServerProfile } from './RustDeskDirectoryTypes';
import { ActionResponse, NativeEvent } from './RustDeskTypes';
import { RemoteFilePath } from './RemoteFilePath';

type TransferSessionState = 'idle' | 'connecting' | 'awaiting_password' | 'awaiting_2fa' | 'ready' | 'failed' | 'closing';

/**
 * The second-factor step this file session's peer is asking for.
 *
 * It is the peer's own text plus the local enrollment capability the challenge
 * event carried. Both describe answering this one session's authentication:
 * neither is a claim that a code was accepted, and neither names another
 * session's metadata.
 */
export interface SecondFactorChallenge {
  /** The peer's text for this challenge, exactly as the msgbox event carried it. */
  message: string;
  /**
   * Whether this build can really enroll a trusted device.
   *
   * The native side reports it on the challenge itself; `false` (or absent)
   * means an answer with `trust = true` would be refused before it reached the
   * session, so the switch is not offered.
   */
  trustEnrollmentSupported: boolean;
}

/**
 * The receipt of one second-factor answer offered to this file session.
 *
 * `queued` is the whole of a successful call: the code reached the session's own
 * authentication loop on its own wire, so the peer has not answered yet. It is
 * never a claim that the peer authenticated this session.
 */
export interface SecondFactorSubmission {
  /** The code reached this session's own authentication loop. */
  queued: boolean;
  /** The engine's own refusal text; empty only when `queued` is true. */
  message: string;
}

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
  private secondFactorRequested: boolean = false;
  private secondFactorMessage: string = '';
  private secondFactorTrustEnrollmentSupported: boolean = false;
  private sessionState: TransferSessionState = 'idle';
  private statusMessage: string = '文件传输未连接';
  private transferErrorMessage: string = '';
  private closeInProgress: boolean = false;
  /** The lifecycle epoch native issued for this session; the ACK echoes it. */
  private sessionEpoch: string = '';
  /** The one close attempt of the current session; every caller shares it. */
  private closePromise: Promise<boolean> | undefined = undefined;
  /** Native has not confirmed this session's release, so the id stays ours. */
  private closeUnconfirmed: boolean = false;

  constructor(bridge: NativeSessionBridge, sessionIdFactory: () => string) {
    this.bridge = bridge;
    this.sessionIdFactory = sessionIdFactory;
  }

  /**
   * Opens the one file-transfer session this manager owns.
   *
   * `approvedServerProfile` is the route the engine already recorded for an
   * explicitly saved profile. It is a value-owned envelope, so passing it cannot
   * turn an editable draft, a LAN claim or a typed address into trust, and
   * omitting it leaves the session on whatever route it would have had anyway.
   * The root is named at add time rather than after start because the engine
   * fixes it for the session: a later path would be a different root than the
   * one this add authorised.
   */
  public open(target: string, password: string, forceRelay: boolean, root: DownloadRoot,
    approvedServerProfile?: ApprovedServerProfile, rustdeskIdOnly: boolean = false): boolean {
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
      isViewOnly: false,
      rustdeskIdOnly,
      transferRoot: root.path,
    };
    if (approvedServerProfile !== undefined) {
      options.approvedServerProfile = approvedServerProfile;
    }
    const addResponse = this.bridge.addSession(sessionId, target, options);
    if (!addResponse.ok) {
      this.statusMessage = addResponse.message?.trim() || '无法创建文件传输会话';
      return false;
    }
    const resolvedSessionId = addResponse.session?.sessionId.trim() || sessionId;
    this.fileSessionId = resolvedSessionId;
    // Native issues this session's own epoch at add time; a close ACK must echo
    // that value, so it is captured before anything else can name the session.
    this.sessionEpoch = this.sessionEpochOf(addResponse, resolvedSessionId);
    this.downloadRoot = root;
    this.remoteDirectory = '/';
    this.remoteEntries = [];
    this.transfers = [];
    this.pendingTransfers = [];
    this.passwordRequested = false;
    this.passwordMessage = '';
    this.secondFactorRequested = false;
    this.secondFactorMessage = '';
    this.secondFactorTrustEnrollmentSupported = false;
    this.sessionState = 'connecting';
    this.statusMessage = '正在建立文件传输连接';
    this.transferErrorMessage = '';

    const startResponse = this.bridge.startSession(resolvedSessionId);
    if (!startResponse.ok) {
      // The add already gave this id to the engine, so the failed start is
      // retired through the one close owner instead of a fire-and-forget close:
      // the same attempt, the same receipt, and the identity kept until that
      // receipt reports the release.
      if (this.sessionEpoch.length === 0) {
        this.sessionEpoch = this.sessionEpochOf(startResponse, resolvedSessionId);
      }
      void this.beginClose('文件传输连接启动失败');
      this.statusMessage = '文件传输连接启动失败';
      return false;
    }
    if (this.sessionEpoch.length === 0) {
      this.sessionEpoch = this.sessionEpochOf(startResponse, resolvedSessionId);
    }
    this.issuedSessionIds.push(resolvedSessionId);
    return true;
  }

  public poll(): boolean {
    if (this.closeInProgress || this.closeUnconfirmed || !this.isReady()) {
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
    if (this.closeInProgress || this.closeUnconfirmed || !item || this.isTerminal(item) || !this.isReady()) {
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

  /**
   * Takes the second-factor step this file session's peer asked for, once.
   *
   * Taking it here only stops this client from raising the same prompt twice for
   * one challenge: the challenge itself stays live in the engine until the peer
   * answers, so nothing about this session is ended by reading it.
   */
  public consumeSecondFactorRequest(): SecondFactorChallenge | undefined {
    if (!this.secondFactorRequested) {
      return undefined;
    }
    this.secondFactorRequested = false;
    return {
      message: this.secondFactorMessage,
      trustEnrollmentSupported: this.secondFactorTrustEnrollmentSupported,
    };
  }

  /**
   * Whether this file session's own peer metadata allows trusted-device
   * enrollment.
   *
   * The value is read for this session's id, so a desktop session's answer never
   * describes this connection. A session that is not open, a peer that has not
   * reported the flag and a HAR that cannot answer the call are all `false`: the
   * switch is hidden and the mandatory code is still asked for, which is the
   * same outcome as a peer that really refused enrollment.
   */
  public canTrustDevice(): boolean {
    if (!this.isReady()) {
      return false;
    }
    try {
      return this.bridge.getEnableTrustedDevices(this.fileSessionId);
    } catch (_) {
      return false;
    }
  }

  /**
   * Offers one second-factor code to this file session, and to no other.
   *
   * `undefined` means this file session is not open, or is already closing, and
   * therefore owns no challenge: the caller must not raise a prompt for it.
   * A refusal comes back as `queued: false` with the engine's own text and this
   * session's authentication untouched: the engine refuses a code before it
   * takes ownership of it, so only the peer may end that step.
   */
  public submitSecondFactor(code: string, trustThisDevice: boolean): SecondFactorSubmission | undefined {
    if (!this.isReady() || this.closeInProgress || this.closeUnconfirmed || this.sessionState === 'failed') {
      return undefined;
    }
    const response = this.bridge.send2fa(this.fileSessionId, code, trustThisDevice);
    if (!response.ok || response.queued !== true) {
      return { queued: false, message: response.message?.trim() || '未收到验证码入队确认，请重试' };
    }
    // Only a queued code leaves the caller's draft. This session is not ready
    // here: `peer_info` is what says the peer authorized it.
    this.secondFactorRequested = false;
    this.secondFactorMessage = '';
    this.secondFactorTrustEnrollmentSupported = false;
    this.sessionState = 'connecting';
    this.statusMessage = '2FA 验证码已提交，正在等待远端验证';
    return { queued: true, message: '' };
  }

  public login(password: string, remember: boolean = false): boolean {
    if (!this.isReady() || this.closeInProgress || this.closeUnconfirmed || password.trim().length === 0) {
      return false;
    }
    const response = this.bridge.login(this.fileSessionId, password, remember);
    if (!response.ok || response.queued !== true) {
      // A locally refused answer ends neither the peer's challenge nor this
      // session. Only a queued answer leaves the caller's password draft.
      this.statusMessage = response.message?.trim() || '未收到密码入队确认，请重试';
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
    if (!item || item.state !== 'awaiting_override' || !this.isReady()
      || this.closeInProgress || this.closeUnconfirmed) {
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
      if (type === 'input-2fa' || type === 're-input-2fa') {
        if (this.sessionState === 'failed' || this.closeInProgress) {
          // The session this challenge names has already ended, so nothing here
          // may raise a prompt for it.
          return true;
        }
        this.secondFactorRequested = true;
        this.secondFactorMessage = title.length > 0 ? `${title}: ${text}` : text;
        this.secondFactorTrustEnrollmentSupported = event.trust_this_device_supported === true;
        this.sessionState = 'awaiting_2fa';
        this.statusMessage = '文件传输等待二次验证 (2FA)';
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
      // Nothing about this session is answerable any more, a second-factor step
      // it had not delivered included.
      this.passwordRequested = false;
      this.passwordMessage = '';
      this.secondFactorRequested = false;
      this.secondFactorMessage = '';
      this.secondFactorTrustEnrollmentSupported = false;
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

  /**
   * Whether this manager still owes the engine a confirmed close.
   *
   * A close in flight and a close whose release native did not confirm both
   * leave the session owned here: no transfer may resume, and no other session
   * may take its place, until a close is really confirmed.
   */
  public isClosePending(): boolean {
    return this.closeInProgress || this.closeUnconfirmed;
  }

  public canTransfer(): boolean {
    return this.isReady()
      && !this.closeInProgress
      && !this.closeUnconfirmed
      && this.sessionState === 'ready';
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

  /**
   * Retires the session this manager owns and reports whether native really
   * released it.
   *
   * `true` means no session is owed any more: either there was nothing to
   * reclaim, or the close receipt reported every destination released and the
   * epoch native issued for that same session was acknowledged afterwards. It
   * is never a claim that a native session was reclaimed when there was none.
   *
   * Repeated calls while one attempt is in flight share that attempt's result,
   * so a second caller is never told that a session closed when it did not. A
   * close native did not confirm keeps the session id, its epoch and its root,
   * so the same manager can be asked again; it is never replaced by a new
   * session.
   */
  public close(): Promise<boolean> {
    return this.beginClose('文件传输未连接');
  }

  private beginClose(closedMessage: string): Promise<boolean> {
    if (this.fileSessionId.length === 0) {
      this.resetSessionState(closedMessage);
      return Promise.resolve(true);
    }
    if (this.closePromise !== undefined) {
      return this.closePromise;
    }
    this.closeInProgress = true;
    this.sessionState = 'closing';
    this.statusMessage = '正在关闭文件传输会话';
    const sessionId = this.fileSessionId;
    const epoch = this.sessionEpoch;
    const attempt = this.reclaimSession(sessionId, epoch, closedMessage);
    this.closePromise = attempt;
    // The attempt is cleared only after it has really settled, so a later
    // close() starts the next attempt with the identity this one kept.
    attempt.then(() => {
      this.clearCloseAttempt(attempt);
    }, () => {
      this.clearCloseAttempt(attempt);
    });
    return attempt;
  }

  private clearCloseAttempt(attempt: Promise<boolean>): void {
    if (this.closePromise === attempt) {
      this.closePromise = undefined;
    }
  }

  private async reclaimSession(sessionId: string, epoch: string, closedMessage: string): Promise<boolean> {
    try {
      // Even an incomplete add receipt must not leave the viewer running.
      // The missing epoch still forbids an ACK or an identity reset below.
      const release = await this.bridge.closeSession(sessionId);
      if (epoch.length === 0) {
        return this.markCloseUnconfirmed('文件传输会话未能确认释放：缺少该会话的生命周期标识');
      }
      if (!release.ok || release.released !== true) {
        const detail = release.message === undefined ? '' : release.message.trim();
        return this.markCloseUnconfirmed(detail.length > 0
          ? `文件传输会话未能确认释放：${detail}`
          : '文件传输会话未能确认释放，会话可能仍被占用');
      }
      if (!this.isSameSessionReceipt(release, sessionId, epoch)) {
        // A receipt that names another session id or another epoch is not this
        // session's release: acknowledging it would retire the wrong one.
        return this.markCloseUnconfirmed('文件传输会话关闭回执属于其他会话，未确认释放');
      }
      const acknowledgement = this.bridge.acknowledgeClose(sessionId, epoch);
      if (!acknowledgement.ok) {
        const detail = acknowledgement.message === undefined ? '' : acknowledgement.message.trim();
        return this.markCloseUnconfirmed(detail.length > 0
          ? `文件传输关闭回执未被确认：${detail}`
          : '文件传输关闭回执未被确认，会话仍由本地持有');
      }
      this.closeInProgress = false;
      this.closeUnconfirmed = false;
      this.resetSessionState(closedMessage);
      return true;
    } catch (error) {
      return this.markCloseUnconfirmed(`文件传输会话关闭请求失败：${String(error)}`);
    }
  }

  /**
   * Records a close native did not confirm, keeping everything that names the
   * session so the operator can ask again.
   */
  private markCloseUnconfirmed(message: string): boolean {
    this.closeInProgress = false;
    this.closeUnconfirmed = true;
    this.sessionState = 'closing';
    this.statusMessage = message;
    return false;
  }

  /**
   * Whether a close receipt really describes this session and its epoch.
   *
   * Native always names the session and epoch. Missing identity is not
   * evidence for this session and must not permit its ACK.
   */
  private isSameSessionReceipt(release: ActionResponse, sessionId: string, epoch: string): boolean {
    const session = release.session;
    if (session === undefined) {
      return false;
    }
    if (session.sessionId.trim() !== sessionId) {
      return false;
    }
    const receiptEpoch = session.lifecycleEpoch;
    return receiptEpoch !== undefined && receiptEpoch.trim() === epoch;
  }

  /**
   * The epoch native issued for this exact session in a real response, or ''.
   *
   * A response that names another session id cannot contribute an epoch: the
   * ACK must echo a value issued for the session being closed and no other.
   */
  private sessionEpochOf(response: ActionResponse, sessionId: string): string {
    const session = response.session;
    if (session === undefined) {
      return '';
    }
    if (session.sessionId.trim() !== sessionId) {
      return '';
    }
    const epoch = session.lifecycleEpoch;
    return epoch === undefined ? '' : epoch.trim();
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
    this.sessionEpoch = '';
    this.downloadRoot = undefined;
    this.remoteDirectory = '/';
    this.remoteEntries = [];
    this.transfers = [];
    this.pendingTransfers = [];
    this.passwordRequested = false;
    this.passwordMessage = '';
    this.secondFactorRequested = false;
    this.secondFactorMessage = '';
    this.secondFactorTrustEnrollmentSupported = false;
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
