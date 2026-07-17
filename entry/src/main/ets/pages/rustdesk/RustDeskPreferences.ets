import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { SessionDefaults } from './RustDeskDirectoryTypes';
import { SavedConnectionSettings } from './RustDeskTypes';

const PREF_NAME = 'rustdesk_connection';
const TARGET_KEY = 'target';
const TARGET_RECORDED_KEY = 'target_recorded';
const PASSWORD_KEY = 'password';
const REMEMBER_PASSWORD_KEY = 'remember_password';
export const DOWNLOAD_ROOT_URI_KEY = 'download_root_uri';
const LEGACY_DEFAULT_TARGET = '10.52.176.1';
const DEFAULT_RELATIVE_MOUSE_KEY = 'default_relative_mouse';
const DEFAULT_AUDIO_ENABLED_KEY = 'default_audio_enabled';
const DEFAULT_CLIPBOARD_ENABLED_KEY = 'default_clipboard_enabled';
const DEFAULT_QUALITY_PRESET_KEY = 'default_quality_preset';
const DEFAULT_PREFERRED_CODEC_KEY = 'default_preferred_codec';
const DEFAULT_GESTURES_ENABLED_KEY = 'default_gestures_enabled';
const DEFAULT_TOOLBAR_EXPANDED_KEY = 'default_toolbar_expanded';

export class RustDeskPreferences {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private getStore(): preferences.Preferences | null {
    try {
      return preferences.getPreferencesSync(this.context, { name: PREF_NAME });
    } catch (_) {
      return null;
    }
  }

  load(): SavedConnectionSettings {
    const store = this.getStore();
    if (!store) {
      return {
        target: '',
        password: '',
        rememberPassword: false,
      };
    }
    try {
      const rawTarget = store.getSync(TARGET_KEY, '') as string;
      const targetRecorded = store.getSync(TARGET_RECORDED_KEY, false) as boolean;
      this.clearLegacyPassword(store);
      return {
        target: this.normalizeLoadedTarget(rawTarget, targetRecorded),
        password: '',
        rememberPassword: false,
      };
    } catch (_) {
      return {
        target: '',
        password: '',
        rememberPassword: false,
      };
    }
  }

  saveTarget(target: string): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(TARGET_KEY, target.trim());
      store.putSync(TARGET_RECORDED_KEY, true);
      store.flushSync();
    } catch (_) {
    }
  }

  savePassword(_password: string, _rememberPassword: boolean): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      this.clearLegacyPassword(store);
    } catch (_) {
    }
  }

  clearPassword(): void {
    this.savePassword('', false);
  }

  loadSessionDefaults(): SessionDefaults {
    const defaults = new SessionDefaults();
    const store = this.getStore();
    if (!store) {
      return defaults;
    }
    try {
      defaults.relativeMouseMode = store.getSync(
        DEFAULT_RELATIVE_MOUSE_KEY,
        defaults.relativeMouseMode,
      ) as boolean;
      defaults.audioEnabled = store.getSync(DEFAULT_AUDIO_ENABLED_KEY, defaults.audioEnabled) as boolean;
      defaults.clipboardEnabled = store.getSync(
        DEFAULT_CLIPBOARD_ENABLED_KEY,
        defaults.clipboardEnabled,
      ) as boolean;
      const qualityPreset = (store.getSync(DEFAULT_QUALITY_PRESET_KEY, defaults.qualityPreset) as string).trim();
      defaults.qualityPreset = qualityPreset.length > 0 ? qualityPreset : defaults.qualityPreset;
      const preferredCodec = (store.getSync(DEFAULT_PREFERRED_CODEC_KEY, defaults.preferredCodec) as string).trim();
      defaults.preferredCodec = preferredCodec.length > 0 ? preferredCodec : defaults.preferredCodec;
      defaults.gesturesEnabled = store.getSync(
        DEFAULT_GESTURES_ENABLED_KEY,
        defaults.gesturesEnabled,
      ) as boolean;
      defaults.toolbarExpanded = store.getSync(
        DEFAULT_TOOLBAR_EXPANDED_KEY,
        defaults.toolbarExpanded,
      ) as boolean;
    } catch (_) {
      return new SessionDefaults();
    }
    return defaults;
  }

  saveSessionDefaults(defaults: SessionDefaults): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(DEFAULT_RELATIVE_MOUSE_KEY, defaults.relativeMouseMode);
      store.putSync(DEFAULT_AUDIO_ENABLED_KEY, defaults.audioEnabled);
      store.putSync(DEFAULT_CLIPBOARD_ENABLED_KEY, defaults.clipboardEnabled);
      store.putSync(DEFAULT_QUALITY_PRESET_KEY, defaults.qualityPreset.trim());
      store.putSync(DEFAULT_PREFERRED_CODEC_KEY, defaults.preferredCodec.trim());
      store.putSync(DEFAULT_GESTURES_ENABLED_KEY, defaults.gesturesEnabled);
      store.putSync(DEFAULT_TOOLBAR_EXPANDED_KEY, defaults.toolbarExpanded);
      store.flushSync();
    } catch (_) {
    }
  }

  loadDownloadRootUri(): string {
    const store = this.getStore();
    if (!store) {
      return '';
    }
    try {
      return (store.getSync(DOWNLOAD_ROOT_URI_KEY, '') as string).trim();
    } catch (_) {
      return '';
    }
  }

  saveDownloadRootUri(uri: string): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(DOWNLOAD_ROOT_URI_KEY, uri.trim());
      store.flushSync();
    } catch (_) {
    }
  }

  private normalizeLoadedTarget(target: string, targetRecorded: boolean): string {
    const normalizedTarget = target.trim();
    if (!targetRecorded && normalizedTarget === LEGACY_DEFAULT_TARGET) {
      return '';
    }
    return normalizedTarget;
  }

  private clearLegacyPassword(store: preferences.Preferences): void {
    try {
      let changed = false;
      if (store.hasSync(PASSWORD_KEY)) {
        store.deleteSync(PASSWORD_KEY);
        changed = true;
      }
      if (store.hasSync(REMEMBER_PASSWORD_KEY)) {
        store.deleteSync(REMEMBER_PASSWORD_KEY);
        changed = true;
      }
      if (changed) {
        store.flushSync();
      }
    } catch (_) {
    }
  }
}
