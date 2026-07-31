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

    it('centers a portrait remote display inside a landscape PC viewport', 0, () => {
      const model = new RustDeskViewportModel();
      const displays: PeerDisplayInfo[] = [
        { width: 1080, height: 1920, x: 0, y: 0 },
      ];
      model.setViewportSize(1920, 1080);
      model.setPeerDisplays(displays, 0);

      const plan = model.buildRenderPlan();
      expect(plan !== undefined).assertTrue();
      if (!plan) {
        return;
      }
      expect(plan.contentRect.left > 0).assertTrue();
      expect(plan.contentRect.top).assertEqual(0);
      expect(plan.contentRect.width < 1920).assertTrue();
      expect(plan.contentRect.height).assertEqual(1080);
    });
  });
}
