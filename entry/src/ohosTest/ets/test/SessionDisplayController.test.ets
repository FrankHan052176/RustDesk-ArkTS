import { describe, expect, it } from '@ohos/hypium';
import { NativeSessionBridge } from '../../../main/ets/pages/rustdesk/NativeSessionBridge';
import { RemoteAudioState, SessionStartOptions } from '../../../main/ets/pages/rustdesk/RustDeskSessionTypes';
import { SessionDisplayController } from '../../../main/ets/pages/rustdesk/SessionDisplayController';
import { RustDeskViewportModel } from '../../../main/ets/pages/rustdesk/RustDeskViewportModel';
import { ActionResponse, PeerDisplayInfo, ResolutionInfo } from '../../../main/ets/pages/rustdesk/RustDeskTypes';

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

  changeResolution(_sessionId: string, display: number, width: number, height: number): ActionResponse {
    this.commands.push(`resolution:${display}:${width}:${height}`);
    return this.ok('change_resolution');
  }

  getImageQuality(_sessionId: string): string | null {
    return null;
  }

  setImageQuality(_sessionId: string, quality: string): ActionResponse {
    this.commands.push(`quality:${quality}`);
    return this.ok('set_image_quality');
  }

  setCustomImageQuality(_sessionId: string, quality: number): void {
    this.commands.push(`custom-quality:${quality}`);
  }

  setCustomFps(_sessionId: string, fps: number): ActionResponse {
    this.commands.push(`custom-fps:${fps}`);
    return this.ok('set_custom_fps');
  }

  sendChat(_sessionId: string, text: string): ActionResponse {
    this.commands.push(`chat:${text}`);
    return this.ok('send_chat');
  }

  sendClipboard(_sessionId: string, _content: string): ActionResponse {
    return this.ok('send_clipboard');
  }

  addSession(_sessionId: string, _target: string, _options: SessionStartOptions): ActionResponse {
    return this.ok('add_session');
  }

  startSession(_sessionId: string): ActionResponse {
    return this.ok('start_session');
  }

  closeSession(_sessionId: string): ActionResponse {
    return this.ok('close_session');
  }

  setViewOnly(_sessionId: string, _enabled: boolean): ActionResponse {
    return this.ok('set_view_only');
  }

  login(_sessionId: string, _password: string, _remember: boolean = false): ActionResponse {
    return this.ok('login');
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

  toggleOption(_sessionId: string, _option: string): void {}

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

    it('applies custom quality in native order with valid defaults and bounds', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);

      expect(controller.applyQuality('session-1', 'custom')).assertTrue();
      expect(bridge.commands.join(',')).assertEqual('custom-quality:50,custom-fps:30');
      expect(controller.getImageQuality()).assertEqual('custom');
      expect(controller.getCustomImageQuality()).assertEqual(50);
      expect(controller.getCustomFps()).assertEqual(30);

      bridge.commands = [];
      expect(controller.applyQuality('session-1', 'custom', 10, 5)).assertTrue();
      expect(bridge.commands.join(',')).assertEqual('custom-quality:10,custom-fps:5');
      expect(controller.applyQuality('session-1', 'custom', 2001, 5)).assertFalse();
      expect(controller.applyQuality('session-1', 'custom', 10, 121)).assertFalse();
    });

    it('can change resolution for Windows and presets do not emit custom fps', 0, () => {
      const bridge = new RecordingNativeSessionBridge();
      const controller = createController(bridge);

      expect(controller.canChangeResolution('Windows')).assertTrue();
      expect(controller.applyQuality('session-1', 'low', 500, 60)).assertTrue();
      expect(bridge.commands.join(',')).assertEqual('quality:low');
    });
  });
}
