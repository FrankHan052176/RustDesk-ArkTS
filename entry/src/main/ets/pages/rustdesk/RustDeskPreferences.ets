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
const DEFAULT_TWO_FINGER_RIGHT_CLICK_KEY = 'default_two_finger_right_click';
const DEFAULT_AUDIO_ENABLED_KEY = 'default_audio_enabled';
const DEFAULT_CLIPBOARD_ENABLED_KEY = 'default_clipboard_enabled';
const DEFAULT_QUALITY_PRESET_KEY = 'default_quality_preset';
const DEFAULT_CUSTOM_QUALITY_KEY = 'default_custom_quality';
const DEFAULT_CUSTOM_FPS_KEY = 'default_custom_fps';
const DEFAULT_PREFERRED_CODEC_KEY = 'default_preferred_codec';
const DEFAULT_CODEC_PRIORITY_VERSION_KEY = 'default_codec_priority_version';
const DEFAULT_CODEC_PRIORITY_VERSION = 1;
const DEFAULT_GESTURES_ENABLED_KEY = 'default_gestures_enabled';
const DEFAULT_TOOLBAR_EXPANDED_KEY = 'default_toolbar_expanded';
const SESSION_SHARING_ENABLED_KEY = 'session_sharing_enabled';
const ANDROID_NAVIGATION_VISIBLE_KEY = 'android_navigation_visible';
const ANDROID_NAVIGATION_POSITION_INITIALIZED_KEY = 'android_navigation_position_initialized';
const ANDROID_NAVIGATION_X_KEY = 'android_navigation_x';
const ANDROID_NAVIGATION_Y_KEY = 'android_navigation_y';
const EASYTIER_PRECONNECT_ENABLED_KEY = 'easytier_preconnect_enabled';
const EASYTIER_INSTANCE_ID_KEY = 'easytier_instance_id';
const EASYTIER_INSTANCE_NAME_KEY = 'easytier_instance_name';

export class AndroidNavigationPreferenceState {
  visible: boolean = true;
  positionInitialized: boolean = false;
  x: number = 0;
  y: number = 0;
}

export class EasyTierPreferenceState {
  enabled: boolean = false;
  instanceId: string = '';
  instanceName: string = '';
}

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

  loadEasyTier(): EasyTierPreferenceState {
    const state = new EasyTierPreferenceState();
    const store = this.getStore();
    if (!store) {
      return state;
    }
    try {
      state.enabled = store.getSync(EASYTIER_PRECONNECT_ENABLED_KEY, false) as boolean;
      state.instanceId = (store.getSync(EASYTIER_INSTANCE_ID_KEY, '') as string).trim();
      state.instanceName = (store.getSync(EASYTIER_INSTANCE_NAME_KEY, '') as string).trim();
      if (state.instanceId.length === 0) {
        state.instanceName = '';
      }
      return state;
    } catch (_) {
      return new EasyTierPreferenceState();
    }
  }

  saveEasyTierEnabled(enabled: boolean): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(EASYTIER_PRECONNECT_ENABLED_KEY, enabled);
      store.flushSync();
    } catch (_) {
    }
  }

  saveEasyTierInstance(instanceId: string, instanceName: string): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(EASYTIER_INSTANCE_ID_KEY, instanceId.trim());
      store.putSync(EASYTIER_INSTANCE_NAME_KEY, instanceName.trim());
      store.flushSync();
    } catch (_) {
    }
  }

  clearEasyTierInstance(): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      if (store.hasSync(EASYTIER_INSTANCE_ID_KEY)) {
        store.deleteSync(EASYTIER_INSTANCE_ID_KEY);
      }
      if (store.hasSync(EASYTIER_INSTANCE_NAME_KEY)) {
        store.deleteSync(EASYTIER_INSTANCE_NAME_KEY);
      }
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
      defaults.twoFingerRightClick = store.getSync(
        DEFAULT_TWO_FINGER_RIGHT_CLICK_KEY,
        defaults.twoFingerRightClick,
      ) as boolean;
      defaults.audioEnabled = store.getSync(DEFAULT_AUDIO_ENABLED_KEY, defaults.audioEnabled) as boolean;
      defaults.clipboardEnabled = store.getSync(
        DEFAULT_CLIPBOARD_ENABLED_KEY,
        defaults.clipboardEnabled,
      ) as boolean;
      const qualityPreset = (store.getSync(DEFAULT_QUALITY_PRESET_KEY, defaults.qualityPreset) as string).trim();
      defaults.qualityPreset = qualityPreset.length > 0 ? qualityPreset : defaults.qualityPreset;
      defaults.customQuality = store.getSync(DEFAULT_CUSTOM_QUALITY_KEY, defaults.customQuality) as number;
      defaults.customFps = store.getSync(DEFAULT_CUSTOM_FPS_KEY, defaults.customFps) as number;
      const preferredCodec = (store.getSync(DEFAULT_PREFERRED_CODEC_KEY, defaults.preferredCodec) as string).trim();
      defaults.preferredCodec = preferredCodec.length > 0 ? preferredCodec : defaults.preferredCodec;
      const codecPriorityVersion = store.getSync(DEFAULT_CODEC_PRIORITY_VERSION_KEY, 0) as number;
      if (codecPriorityVersion < DEFAULT_CODEC_PRIORITY_VERSION) {
        // H.264 used to be the implicit default. Move that legacy value to the
        // capability-driven priority chain; users can still explicitly select
        // H.264 again after the one-time migration.
        if (defaults.preferredCodec === 'h264') {
          defaults.preferredCodec = 'auto';
          store.putSync(DEFAULT_PREFERRED_CODEC_KEY, defaults.preferredCodec);
        }
        store.putSync(DEFAULT_CODEC_PRIORITY_VERSION_KEY, DEFAULT_CODEC_PRIORITY_VERSION);
        store.flushSync();
      }
      defaults.gesturesEnabled = store.getSync(
        DEFAULT_GESTURES_ENABLED_KEY,
        defaults.gesturesEnabled,
      ) as boolean;
      defaults.toolbarExpanded = store.getSync(
        DEFAULT_TOOLBAR_EXPANDED_KEY,
        defaults.toolbarExpanded,
      ) as boolean;
      defaults.sessionSharingEnabled = store.getSync(
        SESSION_SHARING_ENABLED_KEY,
        defaults.sessionSharingEnabled,
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
      store.putSync(DEFAULT_TWO_FINGER_RIGHT_CLICK_KEY, defaults.twoFingerRightClick);
      store.putSync(DEFAULT_AUDIO_ENABLED_KEY, defaults.audioEnabled);
      store.putSync(DEFAULT_CLIPBOARD_ENABLED_KEY, defaults.clipboardEnabled);
      store.putSync(DEFAULT_QUALITY_PRESET_KEY, defaults.qualityPreset.trim());
      store.putSync(DEFAULT_CUSTOM_QUALITY_KEY, defaults.customQuality);
      store.putSync(DEFAULT_CUSTOM_FPS_KEY, defaults.customFps);
      store.putSync(DEFAULT_PREFERRED_CODEC_KEY, defaults.preferredCodec.trim());
      store.putSync(DEFAULT_GESTURES_ENABLED_KEY, defaults.gesturesEnabled);
      store.putSync(DEFAULT_TOOLBAR_EXPANDED_KEY, defaults.toolbarExpanded);
      store.putSync(SESSION_SHARING_ENABLED_KEY, defaults.sessionSharingEnabled);
      store.flushSync();
    } catch (_) {
    }
  }

  loadAndroidNavigationState(): AndroidNavigationPreferenceState {
    const state = new AndroidNavigationPreferenceState();
    const store = this.getStore();
    if (!store) {
      return state;
    }
    try {
      state.visible = store.getSync(ANDROID_NAVIGATION_VISIBLE_KEY, true) as boolean;
      state.positionInitialized = store.getSync(
        ANDROID_NAVIGATION_POSITION_INITIALIZED_KEY,
        false,
      ) as boolean;
      if (!state.positionInitialized) {
        return state;
      }
      const x = store.getSync(ANDROID_NAVIGATION_X_KEY, 0) as number;
      const y = store.getSync(ANDROID_NAVIGATION_Y_KEY, 0) as number;
      if (!Number.isFinite(x) || !Number.isFinite(y)) {
        state.positionInitialized = false;
        return state;
      }
      state.x = x;
      state.y = y;
      return state;
    } catch (_) {
      return new AndroidNavigationPreferenceState();
    }
  }

  saveAndroidNavigationVisible(visible: boolean): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(ANDROID_NAVIGATION_VISIBLE_KEY, visible);
      store.flushSync();
    } catch (_) {
    }
  }

  saveAndroidNavigationPosition(x: number, y: number): void {
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      return;
    }
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(ANDROID_NAVIGATION_X_KEY, x);
      store.putSync(ANDROID_NAVIGATION_Y_KEY, y);
      store.putSync(ANDROID_NAVIGATION_POSITION_INITIALIZED_KEY, true);
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
