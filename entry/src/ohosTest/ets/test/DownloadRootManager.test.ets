import { describe, expect, it } from '@ohos/hypium';
import { DownloadRootManager } from '../../../main/ets/pages/rustdesk/DownloadRootManager';

export default function downloadRootManagerTest(): void {
  describe('DownloadRootManagerTest', () => {
    it('builds a direct child inside the approved root', 0, () => {
      const manager = new DownloadRootManager();
      expect(manager.buildChildPath('/safe/root', 'report.pdf')).assertEqual('/safe/root/report.pdf');
    });

    it('checks paths are inside the approved root', 0, () => {
      const manager = new DownloadRootManager();
      expect(manager.isInsideRoot('/safe/root', '/safe/root/report.pdf')).assertTrue();
      expect(manager.isInsideRoot('/safe/root', '/safe/rooted/report.pdf')).assertFalse();
      expect(manager.isInsideRoot(' ', '/safe/root/report.pdf')).assertFalse();
    });

    it('rejects traversal separators and empty names', 0, () => {
      const manager = new DownloadRootManager();
      expect(manager.buildChildPath('/safe/root', '.')).assertUndefined();
      expect(manager.buildChildPath('/safe/root', '..')).assertUndefined();
      expect(manager.buildChildPath('/safe/root', '../report.pdf')).assertUndefined();
      expect(manager.buildChildPath('/safe/root', 'nested/report.pdf')).assertUndefined();
      expect(manager.buildChildPath('/safe/root', 'nested\\report.pdf')).assertUndefined();
      expect(manager.buildChildPath('/safe/root', 'unsafe\0name')).assertUndefined();
      expect(manager.buildChildPath('/safe/root', '')).assertUndefined();
    });
  });
}
