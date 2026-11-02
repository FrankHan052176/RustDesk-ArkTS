import {
  inputInterceptorPollEvents as bridgeInputInterceptorPollEvents,
  inputInterceptorStart as bridgeInputInterceptorStart,
  inputInterceptorStop as bridgeInputInterceptorStop,
  nativeVersion as bridgeNativeVersion,
  runtimeGetDecoderCapabilities as bridgeRuntimeGetDecoderCapabilities,
  runtimeGetServerConfig as bridgeRuntimeGetServerConfig,
  runtimeListFavorites as bridgeRuntimeListFavorites,
  runtimeListRecentPeers as bridgeRuntimeListRecentPeers,
  peerQueryOnline as bridgePeerQueryOnline,
  runtimeRecordRecentPeer as bridgeRuntimeRecordRecentPeer,
  runtimeRemoveRecentPeer as bridgeRuntimeRemoveRecentPeer,
  runtimeSetFavorite as bridgeRuntimeSetFavorite,
  runtimeSetServerConfig as bridgeRuntimeSetServerConfig,
  runtimeTestServerConfig as bridgeRuntimeTestServerConfig,
  sessionAcknowledgeClose as bridgeSessionAcknowledgeClose,
  sessionAdd as bridgeSessionAdd,
  sessionBindSurface as bridgeSessionBindSurface,
  sessionCancelJob as bridgeSessionCancelJob,
  sessionChangeResolution as bridgeSessionChangeResolution,
  sessionClose as bridgeSessionClose,
  sessionEnterOrLeave as bridgeSessionEnterOrLeave,
  sessionGetClipboardFileState as bridgeSessionGetClipboardFileState,
  sessionGetConnToken as bridgeSessionGetConnToken,
  sessionHasConnToken as bridgeSessionHasConnToken,
  sessionGetEnableTrustedDevices as bridgeSessionGetEnableTrustedDevices,
  sessionGetFrameRateSnapshot as bridgeSessionGetFrameRateSnapshot,
  sessionGetImageQuality as bridgeSessionGetImageQuality,
  sessionGetRemoteAudioState as bridgeSessionGetRemoteAudioState,
  sessionGetToggleOption as bridgeSessionGetToggleOption,
  sessionHandleFlutterKeyEvent as bridgeSessionHandleFlutterKeyEvent,
  sessionInputKey as bridgeSessionInputKey,
  sessionInputString as bridgeSessionInputString,
  sessionLogin as bridgeSessionLogin,
  sessionOnWaitingForImageDialogShow as bridgeSessionOnWaitingForImageDialogShow,
  sessionPollEvents as bridgeSessionPollEvents,
  sessionReadRemoteDir as bridgeSessionReadRemoteDir,
  sessionRefresh as bridgeSessionRefresh,
  sessionSend2fa as bridgeSessionSend2fa,
  sessionSendClipboard as bridgeSessionSendClipboard,
  sessionSendClipboardFiles as bridgeSessionSendClipboardFiles,
  sessionSendClipboardImage as bridgeSessionSendClipboardImage,
  sessionSendFiles as bridgeSessionSendFiles,
  sessionSendMouse as bridgeSessionSendMouse,
  sessionSetClipboardFileRoot as bridgeSessionSetClipboardFileRoot,
  sessionSetCodecPreference as bridgeSessionSetCodecPreference,
  sessionSetCommon as bridgeSessionSetCommon,
  sessionSetConfirmOverrideFile as bridgeSessionSetConfirmOverrideFile,
  sessionSetCustomFps as bridgeSessionSetCustomFps,
  sessionSetCustomImageQuality as bridgeSessionSetCustomImageQuality,
  sessionSetImageQuality as bridgeSessionSetImageQuality,
  sessionSetShowRemoteCursor as bridgeSessionSetShowRemoteCursor,
  sessionSetSize as bridgeSessionSetSize,
  sessionSetVideoPaused as bridgeSessionSetVideoPaused,
  sessionSetViewOnly as bridgeSessionSetViewOnly,
  sessionStart as bridgeSessionStart,
  sessionSwitchDisplay as bridgeSessionSwitchDisplay,
  sessionTakeClipboard as bridgeSessionTakeClipboard,
  sessionTakeClipboardFileEvents as bridgeSessionTakeClipboardFileEvents,
  sessionTakeClipboardImage as bridgeSessionTakeClipboardImage,
  sessionToggleOption as bridgeSessionToggleOption,
  transferNextJobId as bridgeTransferNextJobId,
  xcomponentAttach as bridgeXcomponentAttach,
  xcomponentDetach as bridgeXcomponentDetach,
  xcomponentSetFrameRateRangeNative as bridgeXcomponentSetFrameRateRangeNative,
} from 'rustdesk-ohrs';

export class RustDeskNativeApi {
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

  runtimeGetDecoderCapabilities(): Promise<string> {
    return bridgeRuntimeGetDecoderCapabilities();
  }

  runtimeGetServerConfig(): Promise<string> {
    return bridgeRuntimeGetServerConfig();
  }

  runtimeListFavorites(): Promise<string> {
    return bridgeRuntimeListFavorites();
  }

  runtimeListRecentPeers(): Promise<string> {
    return bridgeRuntimeListRecentPeers();
  }

  peerQueryOnline(peerIdsJson: string, approvedProfileJson: string): Promise<string> {
    return bridgePeerQueryOnline(peerIdsJson, approvedProfileJson);
  }

  runtimeSetFavorite(peerId: string, favorite: boolean): Promise<string> {
    return bridgeRuntimeSetFavorite(peerId, favorite);
  }

  runtimeRecordRecentPeer(peerJson: string): Promise<string> {
    return bridgeRuntimeRecordRecentPeer(peerJson);
  }

  runtimeRemoveRecentPeer(peerId: string): Promise<string> {
    return bridgeRuntimeRemoveRecentPeer(peerId);
  }

  runtimeSetServerConfig(configJson: string): Promise<string> {
    return bridgeRuntimeSetServerConfig(configJson);
  }

  runtimeTestServerConfig(configJson: string): Promise<string> {
    return bridgeRuntimeTestServerConfig(configJson);
  }

  sessionAcknowledgeClose(sessionId: string, lifecycleEpoch: string): string {
    return bridgeSessionAcknowledgeClose(sessionId, lifecycleEpoch);
  }

  sessionAdd(sessionId: string, peerTarget: string, optionsJson: string): string {
    return bridgeSessionAdd(sessionId, peerTarget, optionsJson);
  }

  /** The third argument is the opaque componentId xcomponentAttach returned, never a Surface id. */
  sessionBindSurface(sessionId: string, display: number, componentId: string,
    lifecycleEpoch: string): string {
    return bridgeSessionBindSurface(sessionId, display, componentId, lifecycleEpoch);
  }

  sessionCancelJob(sessionId: string, actId: number): string {
    return bridgeSessionCancelJob(sessionId, actId);
  }

  sessionChangeResolution(sessionId: string, display: number, width: number, height: number): string {
    return bridgeSessionChangeResolution(sessionId, display, width, height);
  }

  sessionClose(sessionId: string): Promise<string> {
    return bridgeSessionClose(sessionId);
  }

  sessionEnterOrLeave(sessionId: string, enter: boolean): string {
    return bridgeSessionEnterOrLeave(sessionId, enter);
  }

  sessionGetClipboardFileState(sessionId: string): string {
    return bridgeSessionGetClipboardFileState(sessionId);
  }

  sessionGetConnToken(sessionId: string): string | null {
    return bridgeSessionGetConnToken(sessionId);
  }

  sessionHasConnToken(sessionId: string): boolean {
    return bridgeSessionHasConnToken(sessionId);
  }

  sessionGetEnableTrustedDevices(sessionId: string): boolean {
    return bridgeSessionGetEnableTrustedDevices(sessionId);
  }

  sessionGetFrameRateSnapshot(sessionId: string, display: number): string {
    return bridgeSessionGetFrameRateSnapshot(sessionId, display);
  }

  sessionGetImageQuality(sessionId: string): string | null {
    return bridgeSessionGetImageQuality(sessionId);
  }

  sessionGetRemoteAudioState(sessionId: string): string {
    return bridgeSessionGetRemoteAudioState(sessionId);
  }

  sessionGetToggleOption(sessionId: string, option: string): boolean {
    return bridgeSessionGetToggleOption(sessionId, option);
  }

  sessionHandleFlutterKeyEvent(sessionId: string, keyJson: string): string {
    return bridgeSessionHandleFlutterKeyEvent(sessionId, keyJson);
  }

  sessionInputKey(sessionId: string, keyJson: string, inputGeneration?: string): string {
    return bridgeSessionInputKey(sessionId, keyJson, inputGeneration);
  }

  sessionInputString(sessionId: string, value: string, inputGeneration?: string): string {
    return bridgeSessionInputString(sessionId, value, inputGeneration);
  }

  sessionLogin(sessionId: string, loginJson: string): string {
    return bridgeSessionLogin(sessionId, loginJson);
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

  sessionSend2fa(sessionId: string, code: string, trustThisDevice: boolean): string {
    return bridgeSessionSend2fa(sessionId, code, trustThisDevice);
  }

  sessionSendClipboard(sessionId: string, content: string): string {
    return bridgeSessionSendClipboard(sessionId, content);
  }

  sessionSendClipboardFiles(sessionId: string, pathsJson: string): string {
    return bridgeSessionSendClipboardFiles(sessionId, pathsJson);
  }

  sessionSendClipboardImage(sessionId: string, image: Uint8Array): string {
    return bridgeSessionSendClipboardImage(sessionId, image);
  }

  sessionSendFiles(sessionId: string, actId: number, path: string, to: string, fileNum: number,
    includeHidden: boolean, isRemote: boolean, isDir: boolean): string {
    return bridgeSessionSendFiles(sessionId, actId, path, to, fileNum, includeHidden, isRemote, isDir);
  }

  sessionSendMouse(sessionId: string, mouseJson: string, inputGeneration?: string): string {
    return bridgeSessionSendMouse(sessionId, mouseJson, inputGeneration);
  }

  sessionSetClipboardFileRoot(sessionId: string, root: string): string {
    return bridgeSessionSetClipboardFileRoot(sessionId, root);
  }

  sessionSetCodecPreference(sessionId: string, codec: string): string {
    return bridgeSessionSetCodecPreference(sessionId, codec);
  }

  sessionSetCommon(sessionId: string, key: string, value: string): string {
    return bridgeSessionSetCommon(sessionId, key, value);
  }

  sessionSetConfirmOverrideFile(sessionId: string, actId: number, fileNum: number,
    needOverride: boolean, remember: boolean, isUpload: boolean): string {
    return bridgeSessionSetConfirmOverrideFile(sessionId, actId, fileNum, needOverride, remember, isUpload);
  }

  sessionSetCustomFps(sessionId: string, fps: number): string {
    return bridgeSessionSetCustomFps(sessionId, fps);
  }

  sessionSetCustomImageQuality(sessionId: string, value: number): string {
    return bridgeSessionSetCustomImageQuality(sessionId, value);
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

  sessionSetVideoPaused(sessionId: string, paused: boolean): string {
    return bridgeSessionSetVideoPaused(sessionId, paused);
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

  sessionTakeClipboard(sessionId: string): string {
    return bridgeSessionTakeClipboard(sessionId);
  }

  sessionTakeClipboardFileEvents(sessionId: string): string {
    return bridgeSessionTakeClipboardFileEvents(sessionId);
  }

  sessionTakeClipboardImage(sessionId: string): Uint8Array {
    return bridgeSessionTakeClipboardImage(sessionId);
  }

  sessionToggleOption(sessionId: string, option: string): string {
    return bridgeSessionToggleOption(sessionId, option);
  }

  transferNextJobId(): number {
    return bridgeTransferNextJobId();
  }

  xcomponentAttach(nodeId: string, frameNode: Object, onSurfaceEvent: (event: string) => void): string {
    return bridgeXcomponentAttach(nodeId, frameNode, onSurfaceEvent);
  }

  xcomponentDetach(componentId: string): string {
    return bridgeXcomponentDetach(componentId);
  }

  xcomponentSetFrameRateRangeNative(componentId: string, expected: number, min: number,
    max: number): string {
    return bridgeXcomponentSetFrameRateRangeNative(componentId, expected, min, max);
  }
}

export const rustDeskNativeApi: RustDeskNativeApi = new RustDeskNativeApi();
