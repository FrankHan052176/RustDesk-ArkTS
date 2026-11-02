import { rustDeskNativeApi as native } from './RustDeskNativeApi';
import { RemoteAudioState, SessionStartOptions } from './RustDeskSessionTypes';
import { ActionResponse } from './RustDeskTypes';

interface RemoteAudioStateResponse extends ActionResponse {
  audio?: RemoteAudioState;
}

export interface NativeClipboardImageDescriptor {
  format: string;
  width: number;
  height: number;
  byteLength: number;
}

export interface NativeClipboardResponse extends ActionResponse {
  text?: string;
  html?: string;
  image?: NativeClipboardImageDescriptor | null;
}

/**
 * One file clipboard fact, exactly as the engine reported it.
 *
 * Only `files` carries paths: a peer's files that really landed on this device,
 * keeping the generation they were received under even if the permission has been
 * withdrawn since. `offered` is this side's offer that really reached the wire, and
 * `failed` names a reason from the engine's own vocabulary. Nothing here is derived
 * from a queued command, so no fact is optimistic.
 */
export interface NativeClipboardFileEvent {
  kind: string;
  request_id?: number | null;
  revision?: string;
  paths?: Array<string>;
  bytes?: number;
  files?: number;
  reason?: string;
  error?: string;
}

export interface NativeClipboardFileResponse {
  ok: boolean;
  action: string;
  message?: string;
  allowed?: boolean;
  revision?: string;
  pending?: number;
  events?: Array<NativeClipboardFileEvent>;
}

export interface NativeSessionBridge {
  switchDisplay(sessionId: string, display: number): ActionResponse;
  setSize(sessionId: string, display: number, width: number, height: number): ActionResponse;
  refresh(sessionId: string, display: number): ActionResponse;
  setVideoPaused(sessionId: string, paused: boolean): ActionResponse;
  changeResolution(sessionId: string, display: number, width: number, height: number): ActionResponse;
  getImageQuality(sessionId: string): string | null;
  getConnToken(sessionId: string): string | null;
  hasConnToken(sessionId: string): boolean;
  getEnableTrustedDevices(sessionId: string): boolean;
  send2fa(sessionId: string, code: string, trustThisDevice: boolean): ActionResponse;
  inputString(sessionId: string, value: string, inputGeneration?: string): ActionResponse;
  setImageQuality(sessionId: string, quality: string): ActionResponse;
  setCustomImageQuality(sessionId: string, quality: number): ActionResponse;
  setCustomFps(sessionId: string, fps: number): ActionResponse;
  getFrameRateSnapshot(sessionId: string, display: number): string;
  sendClipboard(sessionId: string, content: string): ActionResponse;
  sendClipboardFiles(sessionId: string, paths: Array<string>): ActionResponse;
  sendClipboardImage(sessionId: string, image: Uint8Array): ActionResponse;
  setClipboardFileRoot(sessionId: string, root: string): ActionResponse;
  /**
   * The file clipboard's non-consuming state: the permission generation, whether
   * exchange is allowed, and how many facts are waiting.
   *
   * This is what a background poll may look at. It takes no event, so it can never
   * steal the applying consumer's own batch.
   */
  getClipboardFileState(sessionId: string): NativeClipboardFileResponse;
  /**
   * The foreground consumer's own batch of file clipboard facts, at most eight.
   *
   * Every returned fact must be processed. The batch is taken once and stays taken:
   * a fact that is not handled is not offered again by a later read.
   */
  takeClipboardFileEvents(sessionId: string): NativeClipboardFileResponse;
  takeClipboard(sessionId: string): NativeClipboardResponse;
  takeClipboardImage(sessionId: string): Uint8Array;
  addSession(sessionId: string, target: string, options: SessionStartOptions): ActionResponse;
  startSession(sessionId: string): ActionResponse;
  setViewOnly(sessionId: string, enabled: boolean): ActionResponse;
  login(sessionId: string, password: string, remember?: boolean): ActionResponse;
  setCommon(sessionId: string, key: string, value: string): ActionResponse;
  /**
   * Requests the close and resolves with the native join receipt, not with
   * "the request was accepted": the caller may destroy the Surface and remove
   * the tab once the receipt reports every destination released, and only then
   * acknowledges the epoch.
   */
  closeSession(sessionId: string): Promise<ActionResponse>;
  acknowledgeClose(sessionId: string, lifecycleEpoch: string): ActionResponse;
  pollEvents(sessionId: string, limit: number): ActionResponse;
  transferNextJobId(): number;
  readRemoteDir(sessionId: string, path: string): ActionResponse;
  sendFiles(sessionId: string, actId: number, path: string, to: string, isRemote: boolean): ActionResponse;
  setConfirmOverrideFile(sessionId: string, actId: number, fileNum: number,
    needOverride: boolean, isUpload: boolean): ActionResponse;
  cancelTransfer(sessionId: string, actId: number): ActionResponse;
  getToggleOption(sessionId: string, option: string): boolean;
  toggleOption(sessionId: string, option: string): ActionResponse;
  getRemoteAudioState(sessionId: string): RemoteAudioState;
  setRemoteAudioMuted(sessionId: string, muted: boolean): boolean;
}

export class RustDeskNativeSessionBridge implements NativeSessionBridge {
  switchDisplay(sessionId: string, display: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSwitchDisplay(sessionId, JSON.stringify([display])));
  }

  setSize(sessionId: string, display: number, width: number, height: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetSize(sessionId, display, width, height));
  }

  refresh(sessionId: string, display: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionRefresh(sessionId, display));
  }

  setVideoPaused(sessionId: string, paused: boolean): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetVideoPaused(sessionId, paused));
  }

  changeResolution(sessionId: string, display: number, width: number, height: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionChangeResolution(sessionId, display, width, height));
  }

  getImageQuality(sessionId: string): string | null {
    return native.sessionGetImageQuality(sessionId);
  }

  getConnToken(sessionId: string): string | null {
    return native.sessionGetConnToken(sessionId);
  }

  hasConnToken(sessionId: string): boolean {
    return native.sessionHasConnToken(sessionId);
  }

  getEnableTrustedDevices(sessionId: string): boolean {
    return native.sessionGetEnableTrustedDevices(sessionId);
  }

  send2fa(sessionId: string, code: string, trustThisDevice: boolean): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSend2fa(sessionId, code, trustThisDevice));
  }

  inputString(sessionId: string, value: string, inputGeneration?: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionInputString(sessionId, value, inputGeneration));
  }

  setImageQuality(sessionId: string, quality: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetImageQuality(sessionId, quality));
  }

  setCustomImageQuality(sessionId: string, quality: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetCustomImageQuality(sessionId, quality));
  }

  setCustomFps(sessionId: string, fps: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetCustomFps(sessionId, fps));
  }

  getFrameRateSnapshot(sessionId: string, display: number): string {
    return native.sessionGetFrameRateSnapshot(sessionId, display);
  }

  sendClipboard(sessionId: string, content: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSendClipboard(sessionId, content));
  }

  sendClipboardFiles(sessionId: string, paths: Array<string>): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSendClipboardFiles(sessionId, JSON.stringify(paths)));
  }

  sendClipboardImage(sessionId: string, image: Uint8Array): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSendClipboardImage(sessionId, image));
  }

  setClipboardFileRoot(sessionId: string, root: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetClipboardFileRoot(sessionId, root));
  }

  getClipboardFileState(sessionId: string): NativeClipboardFileResponse {
    return this.parseClipboardFileResponse(
      'session_get_clipboard_file_state',
      () => native.sessionGetClipboardFileState(sessionId),
    );
  }

  takeClipboardFileEvents(sessionId: string): NativeClipboardFileResponse {
    return this.parseClipboardFileResponse(
      'session_take_clipboard_file_events',
      () => native.sessionTakeClipboardFileEvents(sessionId),
    );
  }

  takeClipboard(sessionId: string): NativeClipboardResponse {
    try {
      return JSON.parse(native.sessionTakeClipboard(sessionId)) as NativeClipboardResponse;
    } catch (error) {
      return {
        ok: false,
        action: 'session_take_clipboard',
        message: `Native response parsing failed: ${String(error)}`,
      };
    }
  }

  takeClipboardImage(sessionId: string): Uint8Array {
    return native.sessionTakeClipboardImage(sessionId);
  }

  addSession(sessionId: string, target: string, options: SessionStartOptions): ActionResponse {
    return this.parseNativeResponse(() => native.sessionAdd(sessionId, target, JSON.stringify(options)));
  }

  startSession(sessionId: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionStart(sessionId));
  }

  setViewOnly(sessionId: string, enabled: boolean): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetViewOnly(sessionId, enabled));
  }

  login(sessionId: string, password: string, remember: boolean = false): ActionResponse {
    return this.parseNativeResponse(() => native.sessionLogin(sessionId, JSON.stringify({
      password,
      remember,
    })));
  }

  setCommon(sessionId: string, key: string, value: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetCommon(sessionId, key, value));
  }

  async closeSession(sessionId: string): Promise<ActionResponse> {
    try {
      return JSON.parse(await native.sessionClose(sessionId)) as ActionResponse;
    } catch (error) {
      return {
        ok: false,
        action: 'session_close',
        message: String(error),
      };
    }
  }

  acknowledgeClose(sessionId: string, lifecycleEpoch: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionAcknowledgeClose(sessionId, lifecycleEpoch));
  }

  pollEvents(sessionId: string, limit: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionPollEvents(sessionId, limit));
  }

  transferNextJobId(): number {
    return native.transferNextJobId();
  }

  readRemoteDir(sessionId: string, path: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionReadRemoteDir(sessionId, path, false));
  }

  sendFiles(sessionId: string, actId: number, path: string, to: string, isRemote: boolean): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSendFiles(sessionId, actId, path, to, 0, false, isRemote, false));
  }

  setConfirmOverrideFile(sessionId: string, actId: number, fileNum: number,
    needOverride: boolean, isUpload: boolean): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetConfirmOverrideFile(
      sessionId,
      actId,
      fileNum,
      needOverride,
      false,
      isUpload,
    ));
  }

  cancelTransfer(sessionId: string, actId: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionCancelJob(sessionId, actId));
  }

  getToggleOption(sessionId: string, option: string): boolean {
    return native.sessionGetToggleOption(sessionId, option);
  }

  toggleOption(sessionId: string, option: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionToggleOption(sessionId, option));
  }

  getRemoteAudioState(sessionId: string): RemoteAudioState {
    if (sessionId.length === 0) {
      return this.unavailableRemoteAudioState();
    }
    try {
      const response = JSON.parse(native.sessionGetRemoteAudioState(sessionId)) as RemoteAudioStateResponse;
      const audio = response.audio;
      if (audio === undefined) {
        const state = this.unavailableRemoteAudioState();
        state.errorText = response.message ?? '';
        return state;
      }
      return audio;
    } catch (error) {
      const state = this.unavailableRemoteAudioState();
      state.errorText = String(error);
      return state;
    }
  }

  setRemoteAudioMuted(sessionId: string, muted: boolean): boolean {
    if (sessionId.length === 0) {
      return false;
    }
    const disableAudio = this.getToggleOption(sessionId, 'disable-audio');
    if (disableAudio !== muted) {
      return this.toggleOption(sessionId, 'disable-audio').ok;
    }
    return true;
  }

  private unavailableRemoteAudioState(): RemoteAudioState {
    return {
      available: false,
      muted: false,
      rendererActive: false,
      errorText: '',
    };
  }

  /**
   * Parses a clipboard file receipt without copying a parse error into it.
   *
   * The rejected document is a native string that may quote clipboard paths, so the
   * client never echoes it: the failure keeps a fixed message and the action it was
   * asked for.
   */
  private parseClipboardFileResponse(action: string,
    call: () => string): NativeClipboardFileResponse {
    try {
      return JSON.parse(call()) as NativeClipboardFileResponse;
    } catch (_) {
      return {
        ok: false,
        action: action,
        message: 'Native clipboard file response parsing failed',
      };
    }
  }

  private parseNativeResponse(call: () => string): ActionResponse {
    try {
      return JSON.parse(call()) as ActionResponse;
    } catch (error) {
      return {
        ok: false,
        action: 'native_response',
        message: String(error),
      };
    }
  }
}
