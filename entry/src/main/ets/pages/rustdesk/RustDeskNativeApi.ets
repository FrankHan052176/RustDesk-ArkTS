import {
  backendSummary as bridgeBackendSummary,
  buildMarker as bridgeBuildMarker,
  healthcheck as bridgeHealthcheck,
  inputInterceptorPollEvents as bridgeInputInterceptorPollEvents,
  inputInterceptorStart as bridgeInputInterceptorStart,
  inputInterceptorStop as bridgeInputInterceptorStop,
  nativeVersion as bridgeNativeVersion,
  runtimeGetApiServer as bridgeRuntimeGetApiServer,
  runtimeGetAccountState as bridgeRuntimeGetAccountState,
  runtimeStartAccountLoginOptions as bridgeRuntimeStartAccountLoginOptions,
  runtimePollAccountLoginOptions as bridgeRuntimePollAccountLoginOptions,
  runtimeStartAccountLogin as bridgeRuntimeStartAccountLogin,
  runtimeStartAccountOidc as bridgeRuntimeStartAccountOidc,
  runtimePollAccountOidc as bridgeRuntimePollAccountOidc,
  runtimeCancelAccountOidc as bridgeRuntimeCancelAccountOidc,
  runtimeStartAccountVerification as bridgeRuntimeStartAccountVerification,
  runtimePollAccountAction as bridgeRuntimePollAccountAction,
  runtimeAccountLogout as bridgeRuntimeAccountLogout,
  runtimeCancelAccountChallenge as bridgeRuntimeCancelAccountChallenge,
  runtimeStartAddressBookSync as bridgeRuntimeStartAddressBookSync,
  runtimePollAddressBookSync as bridgeRuntimePollAddressBookSync,
  runtimeGetDecoderCapabilities as bridgeRuntimeGetDecoderCapabilities,
  runtimeGetServerConfig as bridgeRuntimeGetServerConfig,
  runtimeInit as bridgeRuntimeInit,
  runtimeListAddressBookPeers as bridgeRuntimeListAddressBookPeers,
  runtimeListFavorites as bridgeRuntimeListFavorites,
  runtimeListLanPeers as bridgeRuntimeListLanPeers,
  runtimeListLocalDir as bridgeRuntimeListLocalDir,
  runtimeListRecentPeers as bridgeRuntimeListRecentPeers,
  runtimeRemoveRecentPeer as bridgeRuntimeRemoveRecentPeer,
  runtimeScanLanPeers as bridgeRuntimeScanLanPeers,
  runtimeSetFavorite as bridgeRuntimeSetFavorite,
  runtimeSetServerConfig as bridgeRuntimeSetServerConfig,
  runtimeTestServerConfig as bridgeRuntimeTestServerConfig,
  sessionAdd as bridgeSessionAdd,
  sessionBindSurface as bridgeSessionBindSurface,
  sessionCancelJob as bridgeSessionCancelJob,
  sessionChangeResolution as bridgeSessionChangeResolution,
  sessionClose as bridgeSessionClose,
  sessionEnterOrLeave as bridgeSessionEnterOrLeave,
  sessionGetImageQuality as bridgeSessionGetImageQuality,
  sessionGetConnToken as bridgeSessionGetConnToken,
  sessionGetRenderStats as bridgeSessionGetRenderStats,
  sessionGetRemoteAudioState as bridgeSessionGetRemoteAudioState,
  sessionGetRgbaSize as bridgeSessionGetRgbaSize,
  sessionGetToggleOption as bridgeSessionGetToggleOption,
  sessionHandleFlutterKeyEvent as bridgeSessionHandleFlutterKeyEvent,
  sessionInputKey as bridgeSessionInputKey,
  sessionLogin as bridgeSessionLogin,
  sessionNextRgba as bridgeSessionNextRgba,
  sessionOnWaitingForImageDialogShow as bridgeSessionOnWaitingForImageDialogShow,
  sessionPollEvents as bridgeSessionPollEvents,
  sessionReadRemoteDir as bridgeSessionReadRemoteDir,
  sessionRefresh as bridgeSessionRefresh,
  sessionSendChat as bridgeSessionSendChat,
  sessionSendClipboard as bridgeSessionSendClipboard,
  sessionSendFiles as bridgeSessionSendFiles,
  sessionSendMouse as bridgeSessionSendMouse,
  sessionSetCodecPreference as bridgeSessionSetCodecPreference,
  sessionSetCommon as bridgeSessionSetCommon,
  sessionSetConfirmOverrideFile as bridgeSessionSetConfirmOverrideFile,
  sessionSetCustomFps as bridgeSessionSetCustomFps,
  sessionSetCustomImageQuality as bridgeSessionSetCustomImageQuality,
  sessionSetImageQuality as bridgeSessionSetImageQuality,
  sessionSetShowRemoteCursor as bridgeSessionSetShowRemoteCursor,
  sessionSetSize as bridgeSessionSetSize,
  sessionSetViewOnly as bridgeSessionSetViewOnly,
  sessionStart as bridgeSessionStart,
  sessionSwitchDisplay as bridgeSessionSwitchDisplay,
  sessionTakeRgbaFrame as bridgeSessionTakeRgbaFrame,
  sessionToggleOption as bridgeSessionToggleOption,
  transferNextJobId as bridgeTransferNextJobId,
} from 'rustdesk-ohrs';

export class RustDeskNativeApi {
  backendSummary(): string {
    return bridgeBackendSummary();
  }

  buildMarker(): string {
    return bridgeBuildMarker();
  }

  healthcheck(): string {
    return bridgeHealthcheck();
  }

  inputInterceptorPollEvents(limit: number): string {
    return bridgeInputInterceptorPollEvents(limit);
  }

  inputInterceptorStart(): string {
    return bridgeInputInterceptorStart();
  }

  inputInterceptorStop(): string {
    return bridgeInputInterceptorStop();
  }

  nativeVersion(): string {
    return bridgeNativeVersion();
  }

  runtimeGetApiServer(): string {
    return bridgeRuntimeGetApiServer();
  }

  runtimeGetAccountState(): string {
    return bridgeRuntimeGetAccountState();
  }

  runtimeStartAccountLoginOptions(): string {
    return bridgeRuntimeStartAccountLoginOptions();
  }

  runtimePollAccountLoginOptions(): string {
    return bridgeRuntimePollAccountLoginOptions();
  }

  runtimeStartAccountLogin(payloadJson: string): string {
    return bridgeRuntimeStartAccountLogin(payloadJson);
  }

  runtimeStartAccountOidc(provider: string): string {
    return bridgeRuntimeStartAccountOidc(provider);
  }

  runtimePollAccountOidc(): string {
    return bridgeRuntimePollAccountOidc();
  }

  runtimeCancelAccountOidc(): string {
    return bridgeRuntimeCancelAccountOidc();
  }

  runtimeStartAccountVerification(payloadJson: string): string {
    return bridgeRuntimeStartAccountVerification(payloadJson);
  }

  runtimePollAccountAction(): string {
    return bridgeRuntimePollAccountAction();
  }

  runtimeAccountLogout(): string {
    return bridgeRuntimeAccountLogout();
  }

  runtimeCancelAccountChallenge(): string {
    return bridgeRuntimeCancelAccountChallenge();
  }

  runtimeStartAddressBookSync(): string {
    return bridgeRuntimeStartAddressBookSync();
  }

  runtimePollAddressBookSync(): string {
    return bridgeRuntimePollAddressBookSync();
  }

  runtimeGetDecoderCapabilities(): string {
    return bridgeRuntimeGetDecoderCapabilities();
  }

  runtimeGetServerConfig(): string {
    return bridgeRuntimeGetServerConfig();
  }

  runtimeInit(appDir: string, deviceName: string): string {
    return bridgeRuntimeInit(appDir, deviceName);
  }

  runtimeListAddressBookPeers(): string {
    return bridgeRuntimeListAddressBookPeers();
  }

  runtimeListFavorites(): string {
    return bridgeRuntimeListFavorites();
  }

  runtimeListLanPeers(): string {
    return bridgeRuntimeListLanPeers();
  }

  runtimeListLocalDir(path: string): string {
    return bridgeRuntimeListLocalDir(path);
  }

  runtimeListRecentPeers(): string {
    return bridgeRuntimeListRecentPeers();
  }

  runtimeRemoveRecentPeer(peerId: string): string {
    return bridgeRuntimeRemoveRecentPeer(peerId);
  }

  runtimeScanLanPeers(): string {
    return bridgeRuntimeScanLanPeers();
  }

  runtimeSetFavorite(peerId: string, favorite: boolean): string {
    return bridgeRuntimeSetFavorite(peerId, favorite);
  }

  runtimeSetServerConfig(configJson: string): string {
    return bridgeRuntimeSetServerConfig(configJson);
  }

  runtimeTestServerConfig(configJson: string): string {
    return bridgeRuntimeTestServerConfig(configJson);
  }

  sessionAdd(sessionId: string, peerTarget: string, optionsJson: string): string {
    return bridgeSessionAdd(sessionId, peerTarget, optionsJson);
  }

  sessionBindSurface(sessionId: string, display: number, surfaceId: string): string {
    return bridgeSessionBindSurface(sessionId, display, surfaceId);
  }

  sessionCancelJob(sessionId: string, actId: number): string {
    return bridgeSessionCancelJob(sessionId, actId);
  }

  sessionChangeResolution(sessionId: string, display: number, width: number, height: number): string {
    return bridgeSessionChangeResolution(sessionId, display, width, height);
  }

  sessionClose(sessionId: string): string {
    return bridgeSessionClose(sessionId);
  }

  sessionEnterOrLeave(sessionId: string, enter: boolean): string {
    return bridgeSessionEnterOrLeave(sessionId, enter);
  }

  sessionGetImageQuality(sessionId: string): string | null {
    return bridgeSessionGetImageQuality(sessionId);
  }

  sessionGetConnToken(sessionId: string): string | null {
    return bridgeSessionGetConnToken(sessionId);
  }

  sessionGetRenderStats(sessionId: string, display: number): string {
    return bridgeSessionGetRenderStats(sessionId, display);
  }

  sessionGetRemoteAudioState(sessionId: string): string {
    return bridgeSessionGetRemoteAudioState(sessionId);
  }

  sessionGetRgbaSize(sessionId: string, display: number): number {
    return bridgeSessionGetRgbaSize(sessionId, display);
  }

  sessionGetToggleOption(sessionId: string, arg: string): boolean {
    return bridgeSessionGetToggleOption(sessionId, arg);
  }

  sessionHandleFlutterKeyEvent(sessionId: string, keyJson: string): string {
    return bridgeSessionHandleFlutterKeyEvent(sessionId, keyJson);
  }

  sessionInputKey(sessionId: string, keyJson: string): string {
    return bridgeSessionInputKey(sessionId, keyJson);
  }

  sessionLogin(sessionId: string, loginJson: string): string {
    return bridgeSessionLogin(sessionId, loginJson);
  }

  sessionNextRgba(sessionId: string, display: number): void {
    bridgeSessionNextRgba(sessionId, display);
  }

  sessionOnWaitingForImageDialogShow(sessionId: string): string {
    return bridgeSessionOnWaitingForImageDialogShow(sessionId);
  }

  sessionPollEvents(sessionId: string, limit: number): string {
    return bridgeSessionPollEvents(sessionId, limit);
  }

  sessionReadRemoteDir(sessionId: string, path: string, includeHidden: boolean): string {
    return bridgeSessionReadRemoteDir(sessionId, path, includeHidden);
  }

  sessionRefresh(sessionId: string, display: number): string {
    return bridgeSessionRefresh(sessionId, display);
  }

  sessionSendChat(sessionId: string, text: string): string {
    return bridgeSessionSendChat(sessionId, text);
  }

  sessionSendClipboard(sessionId: string, content: string): string {
    return bridgeSessionSendClipboard(sessionId, content);
  }

  sessionSendFiles(sessionId: string, actId: number, path: string, to: string, fileNum: number, includeHidden: boolean, isRemote: boolean, isDir: boolean): string {
    return bridgeSessionSendFiles(sessionId, actId, path, to, fileNum, includeHidden, isRemote, isDir);
  }

  sessionSendMouse(sessionId: string, mouseJson: string): string {
    return bridgeSessionSendMouse(sessionId, mouseJson);
  }

  sessionSetCodecPreference(sessionId: string, codec: string): string {
    return bridgeSessionSetCodecPreference(sessionId, codec);
  }

  sessionSetCommon(sessionId: string, key: string, value: string): void {
    bridgeSessionSetCommon(sessionId, key, value);
  }

  sessionSetConfirmOverrideFile(sessionId: string, actId: number, fileNum: number, needOverride: boolean, remember: boolean, isUpload: boolean): string {
    return bridgeSessionSetConfirmOverrideFile(sessionId, actId, fileNum, needOverride, remember, isUpload);
  }

  sessionSetCustomFps(sessionId: string, fps: number): string {
    return bridgeSessionSetCustomFps(sessionId, fps);
  }

  sessionSetCustomImageQuality(sessionId: string, value: number): void {
    bridgeSessionSetCustomImageQuality(sessionId, value);
  }

  sessionSetImageQuality(sessionId: string, value: string): string {
    return bridgeSessionSetImageQuality(sessionId, value);
  }

  sessionSetShowRemoteCursor(sessionId: string, enabled: boolean): string {
    return bridgeSessionSetShowRemoteCursor(sessionId, enabled);
  }

  sessionSetSize(sessionId: string, display: number, width: number, height: number): string {
    return bridgeSessionSetSize(sessionId, display, width, height);
  }

  sessionSetViewOnly(sessionId: string, enabled: boolean): string {
    return bridgeSessionSetViewOnly(sessionId, enabled);
  }

  sessionStart(sessionId: string): string {
    return bridgeSessionStart(sessionId);
  }

  sessionSwitchDisplay(sessionId: string, displaysJson: string): string {
    return bridgeSessionSwitchDisplay(sessionId, displaysJson);
  }

  sessionTakeRgbaFrame(sessionId: string, display: number): Uint8Array {
    return bridgeSessionTakeRgbaFrame(sessionId, display);
  }

  sessionToggleOption(sessionId: string, arg: string): void {
    bridgeSessionToggleOption(sessionId, arg);
  }

  transferNextJobId(): number {
    return bridgeTransferNextJobId();
  }

}

export const rustDeskNativeApi: RustDeskNativeApi = new RustDeskNativeApi();
