import { describe, expect, it } from '@ohos/hypium';
import { NativeSessionBridge } from '../../../main/ets/pages/rustdesk/NativeSessionBridge';
import { RemoteAudioState, SessionStartOptions } from '../../../main/ets/pages/rustdesk/RustDeskSessionTypes';
import { DEFAULT_REFRESH_RATE, matchesResolutionRefusal, SessionDisplayController } from '../../../main/ets/pages/rustdesk/SessionDisplayController';
import { RustDeskViewportModel } from '../../../main/ets/pages/rustdesk/RustDeskViewportModel';
import { ActionResponse, NativeEvent, PeerDisplayInfo, ResolutionInfo } from '../../../main/ets/pages/rustdesk/RustDeskTypes';

class RecordingNativeSessionBridge implements NativeSessionBridge {
  commands: string[] = [];

  switchDisplay(_sessionId: string, display: number): ActionResponse {
    this.commands.push(`switch:${display}`);
    return this.ok('switch_display');
  }

  setSize(_sessionId: string, display: number, width: number, height: number): ActionResponse {
    this.commands.push(`size:${display}:${width}:${height}`);
    return this.ok('set_size');
  }

  refresh(_sessionId: string, display: number): ActionResponse {
    this.commands.push(`refresh:${display}`);
    return this.ok('refresh');
  }

  setVideoPaused(_sessionId: string, paused: boolean): ActionResponse {
    this.commands.push(`video-paused:${String(paused)}`);
    return this.ok('set_video_paused');
  }

  changeResolution(_sessionId: string, display: number, width: number, height: number): ActionResponse {
    this.commands.push(`resolution:${display}:${width}:${height}`);
    return this.ok('change_resolution');
  }

  getImageQuality(_sessionId: string): string | null {
    return null;
  }

  getConnToken(_sessionId: string): string | null {
    return null;
  }

  getEnableTrustedDevices(_sessionId: string): boolean {
    return false;
  }

  send2fa(_sessionId: string, _code: string, _trustThisDevice: boolean): ActionResponse {
    return this.ok('send_2fa');
  }

  inputString(_sessionId: string, _value: string): ActionResponse {
    return this.ok('input_string');
  }

  setImageQuality(_sessionId: string, quality: string): ActionResponse {
    this.commands.push(`quality:${quality}`);
    return this.ok('set_image_quality');
  }

  setCustomImageQuality(_sessionId: string, quality: number): ActionResponse {
    this.commands.push(`custom-quality:${quality}`);
    return this.ok('set_custom_image_quality');
  }

  setCustomFps(_sessionId: string, fps: number): ActionResponse {
    this.commands.push(`custom-fps:${fps}`);
    return this.ok('set_custom_fps');
  }

  getFrameRateSnapshot(_sessionId: string): string {
    return '{}';
  }

  sendClipboard(_sessionId: string, _content: string): ActionResponse {
    return this.ok('send_clipboard');
  }

  sendClipboardFiles(_sessionId: string, _paths: Array<string>): ActionResponse {
    return this.ok('send_clipboard_files');
  }

  sendClipboardImage(_sessionId: string, _image: Uint8Array): ActionResponse {
    return this.ok('send_clipboard_image');
  }

  setClipboardFileRoot(_sessionId: string, _root: string): ActionResponse {
    return this.ok('set_clipboard_file_root');
  }

  takeClipboard(_sessionId: string): ActionResponse {
    return this.ok('take_clipboard');
  }

  takeClipboardImage(_sessionId: string): Uint8Array {
    return new Uint8Array(0);
  }

  addSession(_sessionId: string, _target: string, _options: SessionStartOptions): ActionResponse {
    return this.ok('add_session');
  }

  startSession(_sessionId: string): ActionResponse {
    return this.ok('start_session');
  }

  async closeSession(_sessionId: string): Promise<ActionResponse> {
    return this.ok('close_session');
  }

  surfaceDestroyed(_sessionId: string, _surfaceId: string, _lifecycleEpoch: string): ActionResponse {
    return this.ok('surface_destroyed');
  }

  acknowledgeClose(_sessionId: string, _lifecycleEpoch: string): ActionResponse {
    return this.ok('acknowledge_close');
  }

  setViewOnly(_sessionId: string, _enabled: boolean): ActionResponse {
    return this.ok('set_view_only');
  }

  login(_sessionId: string, _password: string, _remember: boolean = false): ActionResponse {
    return this.ok('login');
  }

  setCommon(_sessionId: string, _key: string, _value: string): ActionResponse {
    return this.ok('set_common');
  }

  pollEvents(_sessionId: string, _limit: number): ActionResponse {
    return this.ok('poll_events');
  }

  transferNextJobId(): number {
    return 0;
  }

  readRemoteDir(_sessionId: string, _path: string): ActionResponse {
    return this.ok('read_remote_dir');
  }

  sendFiles(_sessionId: string, _actId: number, _path: string, _to: string, _isRemote: boolean): ActionResponse {
    return this.ok('send_files');
  }

  setConfirmOverrideFile(_sessionId: string, _actId: number, _fileNum: number,
    _needOverride: boolean, _isUpload: boolean): ActionResponse {
    return this.ok('set_confirm_override_file');
  }

  cancelTransfer(_sessionId: string, _actId: number): ActionResponse {
    return this.ok('cancel_transfer');
  }

  getToggleOption(_sessionId: string, _option: string): boolean {
    return false;
  }

  toggleOption(_sessionId: string, _option: string): ActionResponse {
    return this.ok('toggle_option');
  }

  getRemoteAudioState(_sessionId: string): RemoteAudioState {
    return {
      available: false,
      muted: false,
      rendererActive: false,
      errorText: '',
    };
  }

  setRemoteAudioMuted(_sessionId: string, _muted: boolean): boolean {
    return true;
  }

  private ok(action: string): ActionResponse {
    return { ok: true, action };
  }
}

function displays(): PeerDisplayInfo[] {
  return [
    { width: 1920, height: 1080, x: 0, y: 0 },
    { width: 1280, height: 1024, x: 1920, y: 0 },
  ];
}

function resolutions(): ResolutionInfo[] {
  return [
    { width: 1280, height: 720 },
    { width: 1920, height: 1080 },
  ];
}

function createController(bridge: RecordingNativeSessionBridge): SessionDisplayController {
  const viewport = new RustDeskViewportModel();
  viewport.setViewportSize(1280, 1024);
  return new SessionDisplayController(viewport, bridge, () => {}, () => {});
}

export default function sessionDisplayControllerTest(): void {
  describe('SessionDisplayControllerTest', () => {
    it('matches direct string-valued refusals only to the pending display and size', 0, () => {
      const refused: NativeEvent = {
        name: 'resolution_refused', display: '0', width: '1280', height: '720', message: 'Resize refused',
      };
      expect(matchesResolutionRefusal(refused, 0, 1280, 720)).assertTrue();
      expect(matchesResolutionRefusal(refused, 1, 1280, 720)).assertFalse();
      expect(matchesResolutionRefusal(refused, 0, 1920, 1080)).assertFalse();
      expect(matchesResolutionRefusal(refused, -1, 0, 0)).assertFalse();
      expect(matchesResolutionRefusal({ name: 'resolution_refused' }, 0, 1280, 720)).assertFalse();
      expect(matchesResolutionRefusal({ name: 'resolution_refused', display: '0', width: 'bad', height: '720' },
        0, 1280, 720)).assertFalse();
      expect(matchesResolutionRefusal({ name: 'switch_display', display: 0, width: '1280', height: '720' },
        0, 1280, 720)).assertFalse();
    });

    it('keeps HiDPI initialization on the reported display without changing mode or multiplying scale', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const viewport = new RustDeskViewportModel();
      viewport.setViewportSize(1280, 800);
      const controller = new SessionDisplayController(viewport, bridge, () => {}, () => {});
      const peerDisplays: PeerDisplayInfo[] = [
        { width: 7680, height: 4320, x: 0, y: 0, scaled_width: 3840, scaled_height: 2160 },
        { width: 5120, height: 2880, x: 7680, y: 0, scaled_width: 2560, scaled_height: 1440 },
      ];
      controller.updatePeerInfo(peerDisplays, 1, resolutions(), 'Mac OS');
      expect(controller.getCurrentDisplayIndex()).assertEqual(1);
      expect(bridge.commands.length).assertEqual(0);
      expect(viewport.setSubmittedVideoSize(1, 2560, 1440)).assertTrue();
      expect(controller.getDisplays()[1].width).assertEqual(5120);
      expect(controller.getDisplays()[1].scaled_width).assertEqual(2560);
      expect(controller.selectDisplay('session-hidpi', 1)).assertTrue();
      expect(bridge.commands.join(',')).assertEqual('switch:1,size:1:5120:2880,refresh:1');
      expect(viewport.getSubmittedVideoSize() === undefined).assertTrue();
    });

    it('selecting a display sends switch size refresh in order', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);
      controller.updatePeerInfo(displays(), 0, resolutions(), 'Windows');

      expect(controller.selectDisplay('session-1', 1)).assertTrue();
      expect(bridge.commands.join(',')).assertEqual('switch:1,size:1:1280:1024,refresh:1');
    });

    it('sync peer info without a reported display preserves local selection', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);
      controller.updatePeerInfo(displays(), 0, resolutions(), 'Windows');
      expect(controller.selectDisplay('session-1', 1)).assertTrue();

      controller.updatePeerInfo(displays(), undefined, resolutions(), 'Windows');

      expect(controller.getCurrentDisplayIndex()).assertEqual(1);
    });

    it('sparse sync peer info preserves previously reported resolutions', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);
      controller.updatePeerInfo(displays(), 0, resolutions(), 'Windows');

      controller.updatePeerInfo(displays(), undefined, undefined, 'Windows');

      expect(controller.getResolutions().length).assertEqual(2);
      expect(controller.getResolutions()[0].width).assertEqual(1280);
      expect(controller.getResolutions()[1].height).assertEqual(1080);
    });

    it('explicit empty resolutions clear previously reported resolutions', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);
      controller.updatePeerInfo(displays(), 0, resolutions(), 'Windows');

      controller.updatePeerInfo(displays(), undefined, [], 'Windows');

      expect(controller.getResolutions().length).assertEqual(0);
    });

    it('only requests a resolution change for the selected display', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);
      controller.updatePeerInfo(displays(), 0, resolutions(), 'Windows');
      expect(controller.selectDisplay('session-1', 1)).assertTrue();
      bridge.commands = [];

      expect(controller.requestResolution('session-1', 7, { width: 1280, height: 720 }, 'Windows')).assertFalse();
      expect(bridge.commands.length).assertEqual(0);
      expect(controller.requestResolution('session-1', 1, { width: 1280, height: 720 }, 'Windows')).assertTrue();
      expect(bridge.commands.join(',')).assertEqual('resolution:1:1280:720');
    });

    it('does not request a resolution change for OHOS peers', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);
      controller.updatePeerInfo(displays(), 0, resolutions(), 'ohos');

      expect(controller.canChangeResolution('OHOS')).assertFalse();
      expect(controller.requestResolution('session-1', 0, { width: 1280, height: 720 }, 'OHOS')).assertFalse();
      expect(bridge.commands.length).assertEqual(0);
    });

    it('asks the peer for a capture rate and remembers the one it accepted', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);

      expect(controller.applyRefreshRate('session-1', 120)).assertTrue();
      expect(bridge.commands.join(',')).assertEqual('custom-fps:120');
      expect(controller.getRefreshRate()).assertEqual(120);

      bridge.commands = [];
      // 0 is below the peer's bound and 241 above it; neither may be sent.
      expect(controller.applyRefreshRate('session-1', 0)).assertFalse();
      expect(controller.applyRefreshRate('session-1', 241)).assertFalse();
      expect(bridge.commands.length).assertEqual(0);
      expect(controller.getRefreshRate()).assertEqual(120);
    });

    it('can change resolution for Windows', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);

      expect(controller.canChangeResolution('Windows')).assertTrue();
    });

    it('restores a per-session capture rate without sending native commands', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);

      controller.restoreRefreshRate(90);
      expect(controller.getRefreshRate()).assertEqual(90);
      // A stored rate outside the peer's bound falls back rather than being kept.
      controller.restoreRefreshRate(0);
      expect(controller.getRefreshRate()).assertEqual(DEFAULT_REFRESH_RATE);
      expect(bridge.commands.length).assertEqual(0);
    });
  });
}
