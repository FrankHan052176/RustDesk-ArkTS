import { describe, expect, it } from '@ohos/hypium';
import { RustDeskViewportModel } from '../../../main/ets/pages/rustdesk/RustDeskViewportModel';
import { PeerDisplayInfo } from '../../../main/ets/pages/rustdesk/RustDeskTypes';

export default function viewportModelTest(): void {
  describe('RustDeskViewportModelTest', () => {
    it('selectDisplay changes only to a valid display', 0, () => {
      const model = new RustDeskViewportModel();
      const displays: PeerDisplayInfo[] = [
        { width: 1920, height: 1080, x: 0, y: 0 },
        { width: 1280, height: 1024, x: 1920, y: 0 },
      ];
      model.setPeerDisplays(displays, 0);

      expect(model.selectDisplay(1)).assertTrue();
      expect(model.getCurrentDisplayIndex()).assertEqual(1);
      expect(model.selectDisplay(2)).assertFalse();
      expect(model.getCurrentDisplayIndex()).assertEqual(1);
    });
  });
}
