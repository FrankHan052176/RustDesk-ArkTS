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
} from 'rustdesk-ohrs';

export class NativeHostBridge {
  start(optionsJson: string): string {
    return controlledServerStart(optionsJson);
  }

  stop(): string {
    return controlledServerStop();
  }

  status(): string {
    return controlledServerGetStatus();
  }

  pollIncoming(limit: number): string {
    return controlledIncomingPoll(limit);
  }

  rejectIncoming(requestId: string): string {
    return controlledIncomingResolve(requestId, false);
  }

  password(): string {
    return controlledPasswordGet();
  }

  refreshPassword(): string {
    return controlledPasswordRefresh();
  }

  setPermanentPassword(password: string): string {
    return controlledPasswordSetPermanent(password);
  }

  setVerificationMethod(method: string): string {
    return controlledPasswordSetVerificationMethod(method);
  }

  setSetting(key: string, value: string): string {
    return controlledSettingSet(key, value);
  }

  twoFactor(): string {
    return controlledTwoFactorGet();
  }

  beginTwoFactor(): string {
    return controlledTwoFactorBegin();
  }

  verifyTwoFactor(code: string): string {
    return controlledTwoFactorVerify(code);
  }

  disableTwoFactor(): string {
    return controlledTwoFactorDisable();
  }

  removeTrustedDevices(hwidsJson: string): string {
    return controlledTwoFactorRemoveTrustedDevices(hwidsJson);
  }

  clearTrustedDevices(): string {
    return controlledTwoFactorClearTrustedDevices();
  }

  configureScreen(configJson: string): string {
    return controlledScreenConfigure(configJson);
  }

  stopScreenCapture(): string {
    return controlledScreenCaptureStop();
  }

  screenCaptureStatus(): string {
    return controlledScreenCaptureGetStatus();
  }
}
