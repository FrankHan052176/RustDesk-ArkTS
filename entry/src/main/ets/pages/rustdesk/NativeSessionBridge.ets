import { rustDeskNativeApi as native } from './RustDeskNativeApi';
import { RemoteAudioState, SessionStartOptions } from './RustDeskSessionTypes';
import { ActionResponse } from './RustDeskTypes';

interface RemoteAudioStateResponse extends ActionResponse {
  audio?: RemoteAudioState;
}

export interface NativeSessionBridge {
  switchDisplay(sessionId: string, display: number): ActionResponse;
  setSize(sessionId: string, display: number, width: number, height: number): ActionResponse;
  refresh(sessionId: string, display: number): ActionResponse;
  changeResolution(sessionId: string, display: number, width: number, height: number): ActionResponse;
  getImageQuality(sessionId: string): string | null;
  getConnToken(sessionId: string): string | null;
  getEnableTrustedDevices(sessionId: string): boolean;
  send2fa(sessionId: string, code: string, trustThisDevice: boolean): ActionResponse;
  inputString(sessionId: string, value: string): ActionResponse;
  setImageQuality(sessionId: string, quality: string): ActionResponse;
  setCustomImageQuality(sessionId: string, quality: number): void;
  setCustomFps(sessionId: string, fps: number): ActionResponse;
  sendChat(sessionId: string, text: string): ActionResponse;
  sendClipboard(sessionId: string, content: string): ActionResponse;
  addSession(sessionId: string, target: string, options: SessionStartOptions): ActionResponse;
  startSession(sessionId: string): ActionResponse;
  setViewOnly(sessionId: string, enabled: boolean): ActionResponse;
  login(sessionId: string, password: string, remember?: boolean): ActionResponse;
  setCommon(sessionId: string, key: string, value: string): void;
  closeSession(sessionId: string): ActionResponse;
  pollEvents(sessionId: string, limit: number): ActionResponse;
  transferNextJobId(): number;
  readRemoteDir(sessionId: string, path: string): ActionResponse;
  sendFiles(sessionId: string, actId: number, path: string, to: string, isRemote: boolean): ActionResponse;
  setConfirmOverrideFile(sessionId: string, actId: number, fileNum: number,
    needOverride: boolean, isUpload: boolean): ActionResponse;
  cancelTransfer(sessionId: string, actId: number): ActionResponse;
  getToggleOption(sessionId: string, option: string): boolean;
  toggleOption(sessionId: string, option: string): void;
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

  changeResolution(sessionId: string, display: number, width: number, height: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionChangeResolution(sessionId, display, width, height));
  }

  getImageQuality(sessionId: string): string | null {
    return native.sessionGetImageQuality(sessionId);
  }

  getConnToken(sessionId: string): string | null {
    return native.sessionGetConnToken(sessionId);
  }

  getEnableTrustedDevices(sessionId: string): boolean {
    return native.sessionGetEnableTrustedDevices(sessionId);
  }

  send2fa(sessionId: string, code: string, trustThisDevice: boolean): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSend2fa(sessionId, code, trustThisDevice));
  }

  inputString(sessionId: string, value: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionInputString(sessionId, value));
  }

  setImageQuality(sessionId: string, quality: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetImageQuality(sessionId, quality));
  }

  setCustomImageQuality(sessionId: string, quality: number): void {
    native.sessionSetCustomImageQuality(sessionId, quality);
  }

  setCustomFps(sessionId: string, fps: number): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSetCustomFps(sessionId, fps));
  }

  sendChat(sessionId: string, text: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSendChat(sessionId, text));
  }

  sendClipboard(sessionId: string, content: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionSendClipboard(sessionId, content));
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

  setCommon(sessionId: string, key: string, value: string): void {
    native.sessionSetCommon(sessionId, key, value);
  }

  closeSession(sessionId: string): ActionResponse {
    return this.parseNativeResponse(() => native.sessionClose(sessionId));
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

  toggleOption(sessionId: string, option: string): void {
    native.sessionToggleOption(sessionId, option);
  }

  getRemoteAudioState(sessionId: string): RemoteAudioState {
    if (sessionId.length === 0) {
      return this.unavailableRemoteAudioState();
    }
    try {
      const response = JSON.parse(native.sessionGetRemoteAudioState(sessionId)) as RemoteAudioStateResponse;
      const audio = response.audio;
      if (audio === undefined) {
        return this.unavailableRemoteAudioState();
      }
      return audio;
    } catch (error) {
      return this.unavailableRemoteAudioState();
    }
  }

  setRemoteAudioMuted(sessionId: string, muted: boolean): boolean {
    if (sessionId.length === 0) {
      return false;
    }
    const disableAudio = this.getToggleOption(sessionId, 'disable-audio');
    if (disableAudio !== muted) {
      this.toggleOption(sessionId, 'disable-audio');
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
