import {
  controlledIncomingPoll,
  controlledIncomingResolve,
  controlledPasswordGet,
  controlledPasswordRefresh,
  controlledPasswordSetPermanent,
  controlledPasswordSetVerificationMethod,
  controlledScreenCaptureGetStatus,
  controlledScreenCaptureStop,
  controlledScreenConfigure,
  controlledSettingSet,
  controlledServerGetStatus,
  controlledServerStart,
  controlledServerStop,
  controlledTwoFactorBegin,
  controlledTwoFactorClearTrustedDevices,
  controlledTwoFactorDisable,
  controlledTwoFactorGet,
  controlledTwoFactorRemoveTrustedDevices,
  controlledTwoFactorVerify,
  runtimeGetServerConfig,
} from 'rustdesk-ohrs';

/**
 * The NAPI surface this HAR really exports for the viewed (被看) host.
 *
 * Exactly one native owner exists: `controlledServerStart` owns the listener,
 * the hbbs registration and the temporary-credential owner, and `stop` /
 * `stopScreenCapture` join that same owner, each waiting for the real teardown
 * and naming the run epoch they stop. `screenCaptureStatus` is the same owner's
 * capture projection, never a second capture singleton, and `status` carries the
 * same facts, so a listening host with no controller really has no capture.
 *
 * The security eleven (`password`, permanent password, verification method,
 * setting, 2FA and trusted devices) are async on this HAR: the record is opened
 * and written on a worker, and their answers are JSON documents whose `ok`
 * decides whether anything was stored. A refused or unpersisted change is
 * answered as such; nothing here defaults to "saved".
 *
 * The approved server profile comes only from `runtimeGetServerConfig`'s
 * explicit-save envelope; a host run never derives its server from a LAN scan,
 * a target string or a mutable configuration.
 */
export class NativeHostBridge {
  start(optionsJson: string): Promise<string> {
    return controlledServerStart(optionsJson);
  }

  /** Stops the one host owner this decimal run epoch names and waits for it. */
  stop(runEpoch: string): Promise<string> {
    return controlledServerStop(runEpoch);
  }

  status(): string {
    return controlledServerGetStatus();
  }

  pollIncoming(limit: number): string {
    return controlledIncomingPoll(limit);
  }

  /** The connection's own composite request token is passed through untouched. */
  resolveIncoming(requestId: string, allow: boolean): string {
    return controlledIncomingResolve(requestId, allow);
  }

  acceptIncoming(requestId: string): string {
    return this.resolveIncoming(requestId, true);
  }

  rejectIncoming(requestId: string): string {
    return this.resolveIncoming(requestId, false);
  }

  password(): Promise<string> {
    return controlledPasswordGet();
  }

  refreshPassword(): Promise<string> {
    return controlledPasswordRefresh();
  }

  setPermanentPassword(password: string): Promise<string> {
    return controlledPasswordSetPermanent(password);
  }

  setVerificationMethod(method: string): Promise<string> {
    return controlledPasswordSetVerificationMethod(method);
  }

  /** The engine acts on `trustedDevicesEnabled` with `true`/`false` only. */
  setSetting(key: string, value: string): Promise<string> {
    return controlledSettingSet(key, value);
  }

  twoFactor(): Promise<string> {
    return controlledTwoFactorGet();
  }

  beginTwoFactor(): Promise<string> {
    return controlledTwoFactorBegin();
  }

  verifyTwoFactor(code: string): Promise<string> {
    return controlledTwoFactorVerify(code);
  }

  disableTwoFactor(): Promise<string> {
    return controlledTwoFactorDisable();
  }

  /** The engine reads `number[][]`: the ArkTS device hwid is `number[]`. */
  removeTrustedDevices(hwidsJson: string): Promise<string> {
    return controlledTwoFactorRemoveTrustedDevices(hwidsJson);
  }

  clearTrustedDevices(): Promise<string> {
    return controlledTwoFactorClearTrustedDevices();
  }

  configureScreen(configJson: string): string {
    return controlledScreenConfigure(configJson);
  }

  /** The same owner stop; screen sharing has no separate capture owner. */
  stopScreenCapture(runEpoch: string): Promise<string> {
    return controlledScreenCaptureStop(runEpoch);
  }

  /** The real publisher-stats projection of that same owner, read only. */
  screenCaptureStatus(): string {
    return controlledScreenCaptureGetStatus();
  }

  serverConfig(): Promise<string> {
    return runtimeGetServerConfig();
  }
}
