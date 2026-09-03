import { describe, expect, it } from '@ohos/hypium';
import { RemoteSessionTabsController } from '../../../main/ets/pages/rustdesk/RemoteSessionTabsController';
import { NativeEvent } from '../../../main/ets/pages/rustdesk/RustDeskTypes';

export default function remoteSessionTabsControllerTest(): void {
  describe('RemoteSessionTabsController', () => {
    it('keeps several sessions and pauses every inactive tab', 0, () => {
      const controller = new RemoteSessionTabsController(3);
      const first = controller.add('session-1', '100 001', 'remote_control');
      const second = controller.add('session-2', '100 002', 'view_only');
      expect(first !== undefined).assertTrue();
      expect(second !== undefined).assertTrue();
      expect(controller.count()).assertEqual(2);
      expect(controller.activeId()).assertEqual('session-2');
      expect(controller.get('session-1')?.paused ?? false).assertTrue();
      expect(controller.get('session-2')?.paused ?? true).assertFalse();

      const switched = controller.activate('session-1');
      expect(switched?.previousSessionId ?? '').assertEqual('session-2');
      expect(controller.get('session-1')?.paused ?? true).assertFalse();
      expect(controller.get('session-2')?.paused ?? false).assertTrue();
    });

    it('selects the nearest remaining tab after closing the active session', 0, () => {
      const controller = new RemoteSessionTabsController();
      controller.add('session-1', 'one', 'remote_control');
      controller.add('session-2', 'two', 'remote_control');
      controller.add('session-3', 'three', 'remote_control');
      controller.activate('session-2');
      expect(controller.remove('session-2')).assertEqual('session-3');
      expect(controller.count()).assertEqual(2);
    });

    it('returns to the most recently used session after active close', 0, () => {
      const controller = new RemoteSessionTabsController();
      controller.add('session-1', 'one', 'remote_control');
      controller.add('session-2', 'two', 'remote_control');
      controller.add('session-3', 'three', 'remote_control');
      controller.activate('session-1');
      controller.activate('session-2');

      expect(controller.remove('session-2')).assertEqual('session-1');
    });

    it('stores background peer info and bounded attention events', 0, () => {
      const controller = new RemoteSessionTabsController();
      controller.add('session-1', '100 001', 'remote_control');
      controller.add('session-2', '100 002', 'remote_control');
      const peerInfo: NativeEvent = { name: 'peer_info', hostname: 'Office PC' };
      controller.markPeerInfo('session-1', peerInfo);
      for (let index = 0; index < 70; index += 1) {
        controller.enqueue('session-1', { name: 'chat_client_mode', text: `${index}` });
      }
      expect(controller.get('session-1')?.label ?? '').assertEqual('Office PC');
      expect(controller.get('session-1')?.needsAttention ?? false).assertTrue();
      expect(controller.takePendingEvents('session-1').length).assertEqual(70);
    });

    it('preserves mixed chat and actionable event order', 0, () => {
      const controller = new RemoteSessionTabsController();
      controller.add('session-1', 'one', 'remote_control');
      controller.add('session-2', 'two', 'remote_control');

      controller.enqueue('session-1', { name: 'chat_client_mode', text: 'before' });
      controller.enqueue('session-1', { name: 'msgbox', type: 'error', text: 'problem' });
      controller.enqueue('session-1', { name: 'chat_client_mode', text: 'after' });

      const events = controller.takePendingEvents('session-1');
      expect(events.length).assertEqual(3);
      expect(events[0].name).assertEqual('chat_client_mode');
      expect(events[1].name).assertEqual('msgbox');
      expect(events[2].name).assertEqual('chat_client_mode');
    });

    it('caches cursor bitmaps and the active cursor id per session', 0, () => {
      const controller = new RemoteSessionTabsController();
      controller.add('session-1', 'one', 'remote_control');
      controller.add('session-2', 'two', 'remote_control');
      controller.cacheCursorEvent('session-1', { name: 'cursor_data', id: 'arrow', colors: '[1]' });
      controller.cacheCursorEvent('session-1', { name: 'cursor_data', id: 'text', colors: '[2]' });
      controller.cacheCursorEvent('session-1', { name: 'cursor_data', id: 'arrow', colors: '[3]' });
      controller.cacheCursorEvent('session-1', { name: 'cursor_id', id: 'arrow' });

      const cursorData = controller.cursorDataSnapshot('session-1');
      expect(cursorData.length).assertEqual(2);
      expect(cursorData[0].colors ?? '').assertEqual('[3]');
      expect(controller.lastCursorId('session-1')).assertEqual('arrow');
      expect(controller.cursorDataSnapshot('session-2').length).assertEqual(0);
    });

    it('keeps protected actions when replaceable background events overflow', 0, () => {
      const controller = new RemoteSessionTabsController();
      controller.add('session-1', 'one', 'remote_control');
      controller.add('session-2', 'two', 'remote_control');
      controller.enqueue('session-1', { name: 'msgbox', type: 'error', text: 'keep' });
      for (let index = 0; index < 80; index += 1) {
        controller.enqueue('session-1', { name: 'connection_ready', value: `${index}` });
      }

      const events = controller.takePendingEvents('session-1');
      expect(events.length).assertEqual(65);
      expect(events[0].name).assertEqual('msgbox');
    });

    it('marks omitted chat history after the per-session retention limit', 0, () => {
      const controller = new RemoteSessionTabsController();
      controller.add('session-1', 'one', 'remote_control');
      controller.add('session-2', 'two', 'remote_control');
      for (let index = 0; index < 520; index += 1) {
        controller.enqueue('session-1', { name: 'chat_client_mode', text: `${index}` });
      }

      const events = controller.takePendingEvents('session-1');
      expect(events.length).assertEqual(513);
      expect(String(events[0].text ?? '').includes('8')).assertTrue();
    });

    it('bounds protected background alerts without dropping terminal close', 0, () => {
      const controller = new RemoteSessionTabsController();
      controller.add('session-1', 'one', 'remote_control');
      controller.add('session-2', 'two', 'remote_control');
      controller.enqueue('session-1', { name: 'close' }, true);
      for (let index = 0; index < 140; index += 1) {
        controller.enqueue('session-1', { name: 'msgbox', type: 'error', text: `${index}` }, true);
      }

      const events = controller.takePendingEvents('session-1');
      expect(events.length).assertEqual(129);
      expect(events.some((event: NativeEvent) => event.name === 'close')).assertTrue();
      expect(events.some((event: NativeEvent) => event.title === '后台事件已截断')).assertTrue();
    });

    it('enforces the configured concurrent-session limit', 0, () => {
      const controller = new RemoteSessionTabsController(2);
      expect(controller.add('session-1', 'one', 'remote_control') !== undefined).assertTrue();
      expect(controller.add('session-2', 'two', 'remote_control') !== undefined).assertTrue();
      expect(controller.add('session-3', 'three', 'remote_control') === undefined).assertTrue();
      expect(controller.canAdd()).assertFalse();
    });
  });
}
