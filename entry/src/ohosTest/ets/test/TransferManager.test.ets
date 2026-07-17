import { describe, expect, it } from '@ohos/hypium';
import { NativeSessionBridge } from '../../../main/ets/pages/rustdesk/NativeSessionBridge';
import { SessionStartOptions } from '../../../main/ets/pages/rustdesk/RustDeskSessionTypes';
import { TransferManager } from '../../../main/ets/pages/rustdesk/TransferManager';
import { ActionResponse, NativeEvent } from '../../../main/ets/pages/rustdesk/RustDeskTypes';

class RecordingTransferBridge implements NativeSessionBridge {
  calls: string[] = [];
  events: NativeEvent[] = [];
  lastOptions: SessionStartOptions = {
    password: '',
    forceRelay: false,
    isFileTransfer: false,
    isViewCamera: false,
  };
  private nextJobId: number = 7;

  addSession(sessionId: string, target: string, options: SessionStartOptions): ActionResponse {
    this.lastOptions = options;
    this.calls.push(`add:${sessionId}:${target}:${options.isFileTransfer ? 'transfer' : 'desktop'}`);
    return this.ok('add_session');
  }

  startSession(sessionId: string): ActionResponse {
    this.calls.push(`start:${sessionId}`);
    return this.ok('start_session');
  }

  closeSession(sessionId: string): ActionResponse {
    this.calls.push(`close:${sessionId}`);
    return this.ok('close_session');
  }

  pollEvents(sessionId: string, limit: number): ActionResponse {
    this.calls.push(`poll:${sessionId}:${limit}`);
    return { ok: true, action: 'poll_events', events: this.events };
  }

  transferNextJobId(): number {
    const jobId = this.nextJobId;
    this.nextJobId += 1;
    return jobId;
  }

  readRemoteDir(sessionId: string, path: string): ActionResponse {
    this.calls.push(`read:${sessionId}:${path}`);
    return this.ok('read_remote_dir');
  }

  sendFiles(sessionId: string, actId: number, path: string, to: string, isRemote: boolean): ActionResponse {
    this.calls.push(`send:${sessionId}:${actId}:${path}:${to}:${isRemote}`);
    return this.ok('send_files');
  }

  setConfirmOverrideFile(sessionId: string, actId: number, needOverride: boolean, isUpload: boolean): ActionResponse {
    this.calls.push(`override:${sessionId}:${actId}:${needOverride}:${isUpload}`);
    return this.ok('set_confirm_override_file');
  }

  cancelTransfer(sessionId: string, actId: number): ActionResponse {
    this.calls.push(`cancel:${sessionId}:${actId}`);
    return this.ok('cancel_transfer');
  }

  switchDisplay(_sessionId: string, _display: number): ActionResponse {
    return this.ok('switch_display');
  }

  setSize(_sessionId: string, _display: number, _width: number, _height: number): ActionResponse {
    return this.ok('set_size');
  }

  refresh(_sessionId: string, _display: number): ActionResponse {
    return this.ok('refresh');
  }

  changeResolution(_sessionId: string, _display: number, _width: number, _height: number): ActionResponse {
    return this.ok('change_resolution');
  }

  getImageQuality(_sessionId: string): string | null {
    return null;
  }

  setImageQuality(_sessionId: string, _quality: string): ActionResponse {
    return this.ok('set_image_quality');
  }

  setCustomImageQuality(_sessionId: string, _quality: number): void {}

  setCustomFps(_sessionId: string, _fps: number): ActionResponse {
    return this.ok('set_custom_fps');
  }

  sendChat(_sessionId: string, _text: string): ActionResponse {
    return this.ok('send_chat');
  }

  private ok(action: string): ActionResponse {
    return { ok: true, action };
  }
}

function createManager(bridge: RecordingTransferBridge): TransferManager {
  return new TransferManager(bridge, () => 'file-session');
}

function openManager(manager: TransferManager): boolean {
  return manager.open('peer', 'secret', true, { uri: 'file:///root', path: '/root' });
}

export default function transferManagerTest(): void {
  describe('TransferManagerTest', () => {
    it('opens a distinct file session with exact transfer options', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);

      expect(openManager(manager)).assertTrue();
      expect(bridge.calls[0]).assertEqual('add:file-session:peer:transfer');
      expect(bridge.calls[1]).assertEqual('start:file-session');
      expect(bridge.calls[2]).assertEqual('read:file-session:/');
      expect(bridge.lastOptions.password).assertEqual('secret');
      expect(bridge.lastOptions.forceRelay).assertTrue();
      expect(bridge.lastOptions.isFileTransfer).assertTrue();
      expect(bridge.lastOptions.isViewCamera).assertFalse();
    });

    it('advances a queued upload from progress to completed', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      openManager(manager);
      expect(manager.upload('/root/local.txt', '/remote/local.txt', 100)).assertTrue();

      expect(manager.snapshot()[0].state).assertEqual('queued');
      expect(manager.handleEvent({ name: 'job_progress', id: '7', file_num: '0', speed: '12', finished_size: '30' })).assertTrue();
      expect(manager.snapshot()[0].transferredBytes).assertEqual(30);
      expect(manager.snapshot()[0].speedBytesPerSecond).assertEqual(12);
      expect(manager.handleEvent({ name: 'job_done', id: '7', file_num: '0' })).assertTrue();
      expect(manager.snapshot()[0].state).assertEqual('completed');
    });

    it('records failures and waits for an override decision', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      openManager(manager);
      manager.upload('/root/failed.txt', '/remote/failed.txt', 50);

      expect(manager.handleEvent({ name: 'job_error', id: '7', file_num: '0', err: 'disk full' })).assertTrue();
      expect(manager.snapshot()[0].state).assertEqual('failed');
      expect(manager.snapshot()[0].errorText).assertEqual('disk full');

      manager.upload('/root/override.txt', '/remote/override.txt', 50);
      expect(manager.handleEvent({ name: 'override_file_confirm', id: '8', file_num: '0', is_upload: 'true' })).assertTrue();
      expect(manager.snapshot()[1].state).assertEqual('awaiting_override');
      expect(manager.resolveOverride(8, true)).assertTrue();
      expect(bridge.calls[5]).assertEqual('override:file-session:8:true:true');
    });

    it('does not update jobs for another job or file number', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      openManager(manager);
      manager.upload('/root/local.txt', '/remote/local.txt', 100);

      expect(manager.handleEvent({ name: 'job_progress', id: '8', file_num: '0', speed: '12', finished_size: '30' })).assertFalse();
      expect(manager.handleEvent({ name: 'job_progress', id: '7', file_num: '1', speed: '12', finished_size: '30' })).assertFalse();
      expect(manager.snapshot()[0].state).assertEqual('queued');
      expect(manager.snapshot()[0].transferredBytes).assertEqual(0);
    });

    it('routes polled file-session events to the transfer state', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      openManager(manager);
      manager.upload('/root/local.txt', '/remote/local.txt', 100);
      bridge.events = [{ name: 'job_progress', id: '7', file_num: '0', speed: '12', finished_size: '30' }];

      expect(manager.poll()).assertTrue();
      expect(bridge.calls[4]).assertEqual('poll:file-session:20');
      expect(manager.snapshot()[0].state).assertEqual('running');
    });

    it('rejects local paths that escape the approved download root', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      openManager(manager);

      expect(manager.upload('/root/../outside.txt', '/remote/outside.txt', 10)).assertFalse();
      expect(manager.upload('/root/child\\..\\outside.txt', '/remote/outside.txt', 10)).assertFalse();
      expect(manager.download('/remote/outside.txt', '/root/child/../outside.txt', 10)).assertFalse();
      expect(bridge.calls.length).assertEqual(3);
    });

    it('does not apply late events after a transfer is terminal', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      openManager(manager);
      manager.upload('/root/local.txt', '/remote/local.txt', 100);
      expect(manager.cancel(7)).assertTrue();

      expect(manager.handleEvent({ name: 'job_done', id: '7', file_num: '0' })).assertFalse();
      expect(manager.cancel(7)).assertFalse();
      expect(manager.handleEvent({ name: 'job_error', id: '7', file_num: '0', err: 'late failure' })).assertFalse();
      expect(manager.handleEvent({ name: 'override_file_confirm', id: '7', file_num: '0' })).assertFalse();
      expect(manager.snapshot()[0].state).assertEqual('cancelled');
    });

    it('creates a fresh file session after close when the factory repeats an ID', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      expect(openManager(manager)).assertTrue();
      expect(manager.close()).assertTrue();

      expect(openManager(manager)).assertTrue();
      expect(bridge.calls[4]).assertEqual('add:file-session-1:peer:transfer');
    });

    it('returns transfer-item snapshots without exposing internal state', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      openManager(manager);
      manager.upload('/root/local.txt', '/remote/local.txt', 100);

      const items = manager.snapshot();
      items[0].state = 'completed';
      expect(manager.snapshot()[0].state).assertEqual('queued');
    });

    it('sends downloads, cancels jobs, and closes only the file session', 0, () => {
      const bridge = new RecordingTransferBridge();
      const manager = createManager(bridge);
      openManager(manager);
      expect(manager.download('/remote/report.pdf', '/root/report.pdf', 90)).assertTrue();
      expect(bridge.calls[3]).assertEqual('send:file-session:7:/remote/report.pdf:/root/report.pdf:true');
      expect(manager.cancel(7)).assertTrue();
      expect(manager.snapshot()[0].state).assertEqual('cancelled');

      expect(manager.close()).assertTrue();
      expect(bridge.calls[5]).assertEqual('close:file-session');
      expect(bridge.calls.some((call: string) => call.includes('desktop-session'))).assertFalse();
    });
  });
}
