import { privacyManager } from '@kit.AppGalleryKit';

export class PrivacyConsentService {
  /**
   * Reads the store-managed privacy agreement.  The public event is only a
   * change notification; the store result is the startup source of truth.
   * Fail closed when the service is unavailable or no agreement is present.
   */
  static readSystemAccepted(): boolean {
    try {
      const results: privacyManager.AppPrivacyResult[] = privacyManager.getAppPrivacyResult();
      for (let index = 0; index < results.length; index += 1) {
        const result = results[index];
        if (result.type === privacyManager.AppPrivacyType.PRIVACY_AGREEMENT &&
          result.result === privacyManager.AppPrivacyResultType.FULL_MODE_AGREED) {
          return true;
        }
      }
    } catch (_) {
      // A missing/unavailable standard privacy service must never unlock sensors.
    }
    return false;
  }

}
