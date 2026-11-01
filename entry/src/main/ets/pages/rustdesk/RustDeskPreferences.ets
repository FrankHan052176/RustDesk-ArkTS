import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { PeerRecord, RustDeskRightClickGesture, SessionDefaults, VncQuality } from './RustDeskDirectoryTypes';
import { DEFAULT_TOUCH_SCROLL_DIVISOR, isValidTouchScrollDivisor } from './RustDeskTouchGestureState';
import { isValidRefreshRate } from './RustDeskRefreshRate';
import { SavedConnectionSettings } from './RustDeskTypes';
import { RDP_RESOLUTION_CHOICES, RDP_SETTING_SCALE_CHOICES } from './DirectSessionSettings';
import { deviceConnectionTarget, mergeSavedDevices, persistedDeviceRecords } from './SavedDeviceModel';
import {
  RdpCertificateChallenge,
  RdpTrustedCertificate,
  rdpCertificateTrustKey,
  rememberRdpCertificate,
  validRdpTrustedCertificates,
} from './RdpCertificateTrust';

const PREF_NAME = 'rustdesk_connection';
const TARGET_KEY = 'target';
const TARGET_RECORDED_KEY = 'target_recorded';
const TARGET_MODE_KEY = 'target_mode';
const PASSWORD_KEY = 'password';
const REMEMBER_PASSWORD_KEY = 'remember_password';
export const DOWNLOAD_ROOT_URI_KEY = 'download_root_uri';
const LEGACY_DEFAULT_TARGET = '10.52.176.1';
const LEGACY_DEFAULT_RELATIVE_MOUSE_KEY = 'default_relative_mouse';
const DEFAULT_TOUCH_MODE_KEY = 'default_touch_mode_v2';
const DEFAULT_INPUT_ENABLED_KEY = 'default_input_enabled';
const DEFAULT_RELATIVE_MOUSE_KEY = 'default_relative_mouse_v2';
const DEFAULT_RIGHT_CLICK_GESTURE_KEY = 'default_right_click_gesture';
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
const DEFAULT_TOUCH_SCROLL_DIVISOR_KEY = 'default_touch_scroll_divisor';
const DEFAULT_SESSION_FULLSCREEN_KEY = 'default_session_fullscreen_layout';
const ANDROID_NAVIGATION_VISIBLE_KEY = 'android_navigation_visible';
const ANDROID_NAVIGATION_POSITION_INITIALIZED_KEY = 'android_navigation_position_initialized';
const ANDROID_NAVIGATION_X_KEY = 'android_navigation_x';
const ANDROID_NAVIGATION_Y_KEY = 'android_navigation_y';
const EASYTIER_PRECONNECT_ENABLED_KEY = 'easytier_preconnect_enabled';
const EASYTIER_INSTANCE_ID_KEY = 'easytier_instance_id';
const EASYTIER_INSTANCE_NAME_KEY = 'easytier_instance_name';
const BEGINNER_GUIDE_SHOWN_KEY = 'beginner_guide_shown_v1';
const SAVED_DEVICES_KEY = 'saved_protocol_devices_v1';
const RDP_CERTIFICATE_TRUST_KEY = 'rdp_certificate_trust_v1';
const RDP_RESOLUTION_KEY = 'rdp_resolution';
const RDP_SCALE_KEY = 'rdp_scale_factor';
const RDP_AUDIO_KEY = 'rdp_audio_enabled';
const VNC_QUALITY_KEY = 'vnc_quality';

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

  shouldShowBeginnerGuide(): boolean {
    const store = this.getStore();
    if (!store) {
      return false;
    }
    try {
      return !(store.getSync(BEGINNER_GUIDE_SHOWN_KEY, false) as boolean);
    } catch (_) {
      return false;
    }
  }

  markBeginnerGuideShown(): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(BEGINNER_GUIDE_SHOWN_KEY, true);
      store.flushSync();
    } catch (_) {
    }
  }

  load(): SavedConnectionSettings {
    const store = this.getStore();
    if (!store) {
      return {
        target: '',
        mode: 0,
        password: '',
        rememberPassword: false,
      };
    }
    try {
      const rawTarget = store.getSync(TARGET_KEY, '') as string;
      const targetRecorded = store.getSync(TARGET_RECORDED_KEY, false) as boolean;
      const savedMode = store.getSync(TARGET_MODE_KEY, -1) as number;
      this.clearLegacyPassword(store);
      return {
        target: this.normalizeLoadedTarget(rawTarget, targetRecorded),
        mode: this.loadedTargetMode(rawTarget, savedMode),
        password: '',
        rememberPassword: false,
      };
    } catch (_) {
      return {
        target: '',
        mode: 0,
        password: '',
        rememberPassword: false,
      };
    }
  }

  /**
   * The mode a target was saved under. A target recorded before the mode was
   * kept may still carry the scheme it was typed with, which names its wire.
   */
  private loadedTargetMode(rawTarget: string, savedMode: number): number {
    if (Number.isInteger(savedMode) && savedMode >= 0 && savedMode <= 3) {
      return savedMode;
    }
    const prefix = rawTarget.trim().substring(0, 6).toLowerCase();
    if (prefix === 'vnc://') {
      return 1;
    }
    return prefix === 'rdp://' ? 2 : 0;
  }

  saveTarget(target: string, mode: number): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(TARGET_KEY, target.trim());
      store.putSync(TARGET_RECORDED_KEY, true);
      store.putSync(TARGET_MODE_KEY, mode);
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

  /** Trust records contain only the accepted leaf fingerprint, subject and acceptance time. */
  loadRdpTrustedCertificates(): RdpTrustedCertificate[] {
    const store = this.getStore();
    if (store === null) {
      throw new Error('证书信任存储不可用');
    }
    const records = JSON.parse(store.getSync(RDP_CERTIFICATE_TRUST_KEY, '[]') as string) as RdpTrustedCertificate[];
    return validRdpTrustedCertificates(records);
  }

  rdpCertificateSha256(target: string): string {
    const key = rdpCertificateTrustKey(target);
    return this.loadRdpTrustedCertificates()
      .find((record: RdpTrustedCertificate): boolean => record.target === key)?.sha256 ?? '';
  }

  rememberRdpCertificate(challenge: RdpCertificateChallenge, replaceConfirmed: boolean): boolean {
    const store = this.getStore();
    if (store === null) {
      return false;
    }
    let previous = '[]';
    let changed = false;
    try {
      previous = store.getSync(RDP_CERTIFICATE_TRUST_KEY, '[]') as string;
      const next = rememberRdpCertificate(this.loadRdpTrustedCertificates(), challenge, replaceConfirmed, Date.now());
      if (next === undefined) {
        return false;
      }
      store.putSync(RDP_CERTIFICATE_TRUST_KEY, JSON.stringify(next));
      changed = true;
      store.flushSync();
      return true;
    } catch (_) {
      if (changed) {
        // flush failure must not leave the Preferences cache silently using the new pin.
        try {
          store.putSync(RDP_CERTIFICATE_TRUST_KEY, previous);
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }

  /** Saved-device pin fields are a projection, never another source of trust. */
  private savedPeersWithRdpTrust(peers: PeerRecord[]): PeerRecord[] {
    const records = this.loadRdpTrustedCertificates();
    const saved = persistedDeviceRecords(peers);
    for (const peer of saved) {
      const key = rdpCertificateTrustKey(deviceConnectionTarget(peer));
      peer.rdpCertificateSha256 = peer.protocol === 'rdp'
        ? (records.find((record: RdpTrustedCertificate): boolean => record.target === key)?.sha256 ?? '') : '';
    }
    return saved;
  }

  loadSavedPeers(legacy: PeerRecord[] | undefined): PeerRecord[] {
    const store = this.getStore();
    if (store === null) {
      throw new Error('设备存储不可用');
    }
    if (!store.hasSync(SAVED_DEVICES_KEY)) {
      if (legacy === undefined) {
        return [];
      }
      const peers = this.savedPeersWithRdpTrust(mergeSavedDevices([], legacy));
      store.putSync(SAVED_DEVICES_KEY, JSON.stringify(peers));
      store.flushSync();
      return peers;
    }
    const peers = JSON.parse(store.getSync(SAVED_DEVICES_KEY, '[]') as string) as PeerRecord[];
    return this.savedPeersWithRdpTrust(mergeSavedDevices([], peers));
  }

  /**
   * Whether this store has ever been written. The one-time engine-directory
   * migration only runs while it has not, so a partial migration never closes it.
   */
  hasSavedPeers(): boolean {
    const store = this.getStore();
    if (store === null) {
      return false;
    }
    try {
      return store.hasSync(SAVED_DEVICES_KEY);
    } catch (_) {
      return false;
    }
  }

  saveSavedPeers(peers: PeerRecord[]): boolean {
    const store = this.getStore();
    if (store === null) {
      return false;
    }
    try {
      store.putSync(SAVED_DEVICES_KEY, JSON.stringify(this.savedPeersWithRdpTrust(peers)));
      store.flushSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  loadSessionDefaults(): SessionDefaults {
    const defaults = new SessionDefaults();
    const store = this.getStore();
    if (!store) {
      return defaults;
    }
    try {
      const legacyMouseMode = store.getSync(LEGACY_DEFAULT_RELATIVE_MOUSE_KEY, false) as boolean;
      defaults.touchMode = store.getSync(DEFAULT_TOUCH_MODE_KEY, !legacyMouseMode) as boolean;
      defaults.relativeMouseMode = store.getSync(DEFAULT_RELATIVE_MOUSE_KEY, defaults.relativeMouseMode) as boolean;
      if (defaults.touchMode) {
        defaults.relativeMouseMode = false;
      }
      const rightClickGesture = store.getSync(
        DEFAULT_RIGHT_CLICK_GESTURE_KEY,
        defaults.rightClickGesture,
      ) as string;
      if (rightClickGesture === 'double_tap'
        || rightClickGesture === 'two_finger_tap'
        || rightClickGesture === 'long_press') {
        defaults.rightClickGesture = rightClickGesture as RustDeskRightClickGesture;
      }
      defaults.inputEnabled = store.getSync(DEFAULT_INPUT_ENABLED_KEY, defaults.inputEnabled) as boolean;
      defaults.audioEnabled = store.getSync(DEFAULT_AUDIO_ENABLED_KEY, defaults.audioEnabled) as boolean;
      defaults.clipboardEnabled = store.getSync(
        DEFAULT_CLIPBOARD_ENABLED_KEY,
        defaults.clipboardEnabled,
      ) as boolean;
      // `default_custom_fps` already held the capture rate the operator tuned,
      // so it carries over unchanged; the retired quality keys are left in place
      // rather than deleted, because a downgrade still reads them.
      const storedRate = store.getSync(DEFAULT_CUSTOM_FPS_KEY, defaults.refreshRate) as number;
      defaults.refreshRate = storedRate;
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
      const resolution = store.getSync(RDP_RESOLUTION_KEY, defaults.rdpResolution) as string;
      if (RDP_RESOLUTION_CHOICES.indexOf(resolution) >= 0) {
        defaults.rdpResolution = resolution;
      }
      const scale = store.getSync(RDP_SCALE_KEY, defaults.rdpScaleFactor) as number;
      if (RDP_SETTING_SCALE_CHOICES.indexOf(scale) >= 0) {
        defaults.rdpScaleFactor = scale;
      }
      defaults.rdpAudioEnabled = store.getSync(RDP_AUDIO_KEY, defaults.rdpAudioEnabled) as boolean;
      const quality = store.getSync(VNC_QUALITY_KEY, defaults.vncQuality) as string;
      if (quality === 'lossless' || quality === 'balanced' || quality === 'fast') {
        defaults.vncQuality = quality as VncQuality;
      }
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
      store.putSync(DEFAULT_TOUCH_MODE_KEY, defaults.touchMode);
      store.putSync(DEFAULT_RELATIVE_MOUSE_KEY, !defaults.touchMode && defaults.relativeMouseMode);
      store.putSync(DEFAULT_RIGHT_CLICK_GESTURE_KEY, defaults.rightClickGesture);
      store.putSync(DEFAULT_INPUT_ENABLED_KEY, defaults.inputEnabled);
      store.putSync(DEFAULT_AUDIO_ENABLED_KEY, defaults.audioEnabled);
      store.putSync(DEFAULT_CLIPBOARD_ENABLED_KEY, defaults.clipboardEnabled);
      store.putSync(DEFAULT_CUSTOM_FPS_KEY, defaults.refreshRate);
      store.putSync(DEFAULT_PREFERRED_CODEC_KEY, defaults.preferredCodec.trim());
      store.putSync(DEFAULT_GESTURES_ENABLED_KEY, defaults.gesturesEnabled);
      store.putSync(DEFAULT_TOOLBAR_EXPANDED_KEY, defaults.toolbarExpanded);
      store.putSync(SESSION_SHARING_ENABLED_KEY, defaults.sessionSharingEnabled);
      store.putSync(RDP_RESOLUTION_KEY, defaults.rdpResolution);
      store.putSync(RDP_SCALE_KEY, defaults.rdpScaleFactor);
      store.putSync(RDP_AUDIO_KEY, defaults.rdpAudioEnabled);
      store.putSync(VNC_QUALITY_KEY, defaults.vncQuality);
      store.flushSync();
    } catch (_) {
    }
  }

  /**
   * The capture rate the engine asks the peer for when the next viewer starts.
   *
   * It is persisted on its own rather than through `saveSessionDefaults`, which
   * would also write defaults for capabilities this build does not offer. The
   * engine takes the rate when a viewer dials (`customFps` on the session, or
   * `sessionSetCustomFps`), so a running session keeps the rate it started
   * with.
   */
  saveRequestedFps(fps: number): void {
    if (!isValidRefreshRate(fps)) {
      return;
    }
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(DEFAULT_CUSTOM_FPS_KEY, Math.round(fps));
      store.flushSync();
    } catch (_) {
    }
  }

  /**
   * Whether one-finger dragging selects (touch) or moves the peer's pointer.
   *
   * This is a local interaction default: both modes send the same protocol
   * coordinates, and the mode only changes what a drag starts.
   */
  saveTouchMode(touchMode: boolean): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(DEFAULT_TOUCH_MODE_KEY, touchMode);
      store.putSync(DEFAULT_RELATIVE_MOUSE_KEY, false);
      store.flushSync();
    } catch (_) {
    }
  }
  loadTouchScrollDivisor(): number {
    const store = this.getStore();
    if (!store) {
      return DEFAULT_TOUCH_SCROLL_DIVISOR;
    }
    try {
      const value = store.getSync(DEFAULT_TOUCH_SCROLL_DIVISOR_KEY, DEFAULT_TOUCH_SCROLL_DIVISOR) as number;
      return isValidTouchScrollDivisor(value) ? Math.round(value) : DEFAULT_TOUCH_SCROLL_DIVISOR;
    } catch (_) {
      return DEFAULT_TOUCH_SCROLL_DIVISOR;
    }
  }

  saveTouchScrollDivisor(value: number): void {
    if (!isValidTouchScrollDivisor(value)) {
      return;
    }
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(DEFAULT_TOUCH_SCROLL_DIVISOR_KEY, Math.round(value));
      store.flushSync();
    } catch (_) {
    }
  }

  loadSessionFullscreen(): boolean {
    const store = this.getStore();
    if (!store) {
      return false;
    }
    try {
      return store.getSync(DEFAULT_SESSION_FULLSCREEN_KEY, false) as boolean;
    } catch (_) {
      return false;
    }
  }

  saveSessionFullscreen(enabled: boolean): void {
    const store = this.getStore();
    if (!store) {
      return;
    }
    try {
      store.putSync(DEFAULT_SESSION_FULLSCREEN_KEY, enabled);
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
