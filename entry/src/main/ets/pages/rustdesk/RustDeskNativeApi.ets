import {
  nativeVersion as bridgeNativeVersion,
  accountBindServer as bridgeAccountBindServer,
  accountSnapshot as bridgeAccountSnapshot,
  accountProviders as bridgeAccountProviders,
  accountOidcStart as bridgeAccountOidcStart,
  accountOidcResult as bridgeAccountOidcResult,
  accountOidcCancel as bridgeAccountOidcCancel,
  accountLoginPassword as bridgeAccountLoginPassword,
  accountLoginVerify as bridgeAccountLoginVerify,
  accountLoginCancel as bridgeAccountLoginCancel,
  accountRefreshUser as bridgeAccountRefreshUser,
  accountLogout as bridgeAccountLogout,
  cloudAddressBookList as bridgeCloudAddressBookList,
  cloudAddressBookLoad as bridgeCloudAddressBookLoad,
  cloudAddressBookMutate as bridgeCloudAddressBookMutate,
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
  sessionAddShared as bridgeSessionAddShared,
  shareStart as bridgeShareStart,
  shareConnectTransport as bridgeShareConnectTransport,
  shareStop as bridgeShareStop,
  shareGetStatus as bridgeShareGetStatus,
  shareGetInvite as bridgeShareGetInvite,
  shareGetTransportStatus as bridgeShareGetTransportStatus,
  sessionGetTransportStatus as bridgeSessionGetTransportStatus,
  sharePollSendData as bridgeSharePollSendData,
  sharePushReceiveData as bridgeSharePushReceiveData,
  shareReportSendResult as bridgeShareReportSendResult,
  sessionPollSendData as bridgeSessionPollSendData,
  sessionPushReceiveData as bridgeSessionPushReceiveData,
  sessionReportSendResult as bridgeSessionReportSendResult,
  sessionBindSurface as bridgeSessionBindSurface,
  sessionCancelJob as bridgeSessionCancelJob,
  sessionChangeResolution as bridgeSessionChangeResolution,
  sessionClose as bridgeSessionClose,
  sessionGetClipboardFileState as bridgeSessionGetClipboardFileState,
  sessionGetConnToken as bridgeSessionGetConnToken,
  sessionHasConnToken as bridgeSessionHasConnToken,
  sessionGetEnableTrustedDevices as bridgeSessionGetEnableTrustedDevices,
  sessionGetFrameRateSnapshot as bridgeSessionGetFrameRateSnapshot,
  sessionGetImageQuality as bridgeSessionGetImageQuality,
  sessionGetRemoteAudioState as bridgeSessionGetRemoteAudioState,
  sessionGetToggleOption as bridgeSessionGetToggleOption,
  sessionInputKey as bridgeSessionInputKey,
  sessionInputString as bridgeSessionInputString,
  sessionReleaseInput as bridgeSessionReleaseInput,
  sessionSendKeysym as bridgeSessionSendKeysym,
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
  sessionSetUnverifiedInputAccepted as bridgeSessionSetUnverifiedInputAccepted,
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
import { RustDeskMouseSink } from './RustDeskMouseTransport';

export class RustDeskNativeApi implements RustDeskMouseSink {
  nativeVersion(): string {
    return bridgeNativeVersion();
  }

  accountBindServer(approvedProfileJson: string): Promise<string> {
    return bridgeAccountBindServer(approvedProfileJson);
  }

  accountSnapshot(): Promise<string> {
    return bridgeAccountSnapshot();
  }

  accountProviders(): Promise<string> {
    return bridgeAccountProviders();
  }

  accountOidcStart(receipt: string, providerId: string, rememberMe: boolean): Promise<string> {
    return bridgeAccountOidcStart(receipt, providerId, rememberMe);
  }

  accountOidcResult(attemptReceipt: string): Promise<string> {
    return bridgeAccountOidcResult(attemptReceipt);
  }

  accountOidcCancel(attemptReceipt: string): Promise<string> {
    return bridgeAccountOidcCancel(attemptReceipt);
  }

  accountLoginPassword(receipt: string, username: string, password: string, rememberMe: boolean): Promise<string> {
    return bridgeAccountLoginPassword(receipt, username, password, rememberMe);
  }

  accountLoginVerify(challengeReceipt: string, code: string, trustDevice: boolean): Promise<string> {
    return bridgeAccountLoginVerify(challengeReceipt, code, trustDevice);
  }

  accountLoginCancel(challengeReceipt: string): Promise<string> {
    return bridgeAccountLoginCancel(challengeReceipt);
  }

  accountRefreshUser(receipt: string): Promise<string> {
    return bridgeAccountRefreshUser(receipt);
  }

  accountLogout(receipt: string): Promise<string> {
    return bridgeAccountLogout(receipt);
  }

  cloudAddressBookList(receipt: string): Promise<string> {
    return bridgeCloudAddressBookList(receipt);
  }

  cloudAddressBookLoad(receipt: string, bookId: string): Promise<string> {
    return bridgeCloudAddressBookLoad(receipt, bookId);
  }

  cloudAddressBookMutate(receipt: string, bookId: string, mutationJson: string): Promise<string> {
    return bridgeCloudAddressBookMutate(receipt, bookId, mutationJson);
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

  sessionAddShared(sessionId: string, inviteCode: string, optionsJson: string): string {
    return bridgeSessionAddShared(sessionId, inviteCode, optionsJson);
  }

  shareStart(optionsJson: string): Promise<string> {
    return bridgeShareStart(optionsJson);
  }

  shareStop(shareEpoch: string): Promise<string> {
    return bridgeShareStop(shareEpoch);
  }

  shareGetStatus(): string {
    return bridgeShareGetStatus();
  }

  shareConnectTransport(epoch: string): string {
    return bridgeShareConnectTransport(epoch);
  }

  shareGetTransportStatus(epoch: string): string {
    return bridgeShareGetTransportStatus(epoch);
  }

  sessionGetTransportStatus(sessionId: string, epoch: string): string {
    return bridgeSessionGetTransportStatus(sessionId, epoch);
  }

  sharePollSendData(epoch: string): Uint8Array {
    return bridgeSharePollSendData(epoch);
  }

  sharePushReceiveData(epoch: string, data: Uint8Array): string {
    return bridgeSharePushReceiveData(epoch, data);
  }

  shareReportSendResult(epoch: string, ok: boolean, label: string, code: number = 0): string {
    return bridgeShareReportSendResult(epoch, ok, label, code);
  }

  sessionPollSendData(sessionId: string, epoch: string): Uint8Array {
    return bridgeSessionPollSendData(sessionId, epoch);
  }

  sessionPushReceiveData(sessionId: string, epoch: string, data: Uint8Array): string {
    return bridgeSessionPushReceiveData(sessionId, epoch, data);
  }

  sessionReportSendResult(sessionId: string, epoch: string, ok: boolean, label: string, code: number = 0): string {
    return bridgeSessionReportSendResult(sessionId, epoch, ok, label, code);
  }

  shareGetInvite(shareEpoch: string): string {
    return bridgeShareGetInvite(shareEpoch);
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

  sessionInputKey(sessionId: string, keyJson: string, inputGeneration: number): string {
    return bridgeSessionInputKey(sessionId, keyJson, inputGeneration);
  }

  sessionInputString(sessionId: string, value: string, inputGeneration: number): string {
    return bridgeSessionInputString(sessionId, value, inputGeneration);
  }

  sessionSendKeysym(sessionId: string, keysym: number, down: boolean, inputGeneration: number): string {
    return bridgeSessionSendKeysym(sessionId, keysym, down, inputGeneration);
  }

  sessionReleaseInput(sessionId: string): string {
    return bridgeSessionReleaseInput(sessionId);
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

  sessionSendMouse(sessionId: string, mouseJson: string, inputGeneration: number): string {
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

  sessionSetUnverifiedInputAccepted(sessionId: string, accepted: boolean): string {
    return bridgeSessionSetUnverifiedInputAccepted(sessionId, accepted);
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
