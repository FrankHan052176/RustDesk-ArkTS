import { privacyManager } from '@kit.AppGalleryKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class PrivacyConsentState {
  accepted: boolean = false;
  available: boolean = true;
  error: string = '';
}

export class PrivacyConsentService {
  /** Events only invalidate this authoritative store-managed result. */
  static readSystemState(): PrivacyConsentState {
    const state = new PrivacyConsentState();
    try {
      const results: privacyManager.AppPrivacyResult[] = privacyManager.getAppPrivacyResult();
      let found = false;
      for (let index = 0; index < results.length; index += 1) {
        const result = results[index];
        if (result.type === privacyManager.AppPrivacyType.PRIVACY_AGREEMENT) {
          if (result.result !== privacyManager.AppPrivacyResultType.FULL_MODE_AGREED) {
            return state;
          }
          found = true;
        }
      }
      state.accepted = found;
    } catch (error) {
      const failure = error as BusinessError;
      state.available = false;
      state.error = `${failure.code}: ${failure.message}`;
    }
    return state;
  }
}
