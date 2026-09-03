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

    it('preserves the measured viewport while resetting session geometry', 0, () => {
      const model = new RustDeskViewportModel();
      const firstDisplays: PeerDisplayInfo[] = [
        { width: 1920, height: 1080, x: 0, y: 0 },
      ];
      const nextDisplays: PeerDisplayInfo[] = [
        { width: 1280, height: 720, x: 0, y: 0 },
      ];
      model.setViewportSize(960, 540);
      model.setPeerDisplays(firstDisplays, 0);
      model.setSurfaceSize(1920, 1080);
      model.setViewTransform(1.5, 20, 10, 0);

      model.resetSessionGeometry();
      expect(model.getCoordinateSpace() === undefined).assertTrue();

      model.setPeerDisplays(nextDisplays, 0);
      expect(model.getCoordinateSpace() !== undefined).assertTrue();
      const plan = model.buildRenderPlan();
      expect(plan !== undefined).assertTrue();
      if (!plan) {
        return;
      }
      expect(plan.contentRect.width).assertEqual(960);
      expect(plan.contentRect.height).assertEqual(540);
      expect(plan.surfaceSize.width).assertEqual(0);
      expect(plan.surfaceSize.height).assertEqual(0);

      const mapped = model.mapLocalToRemote(480, 270);
      expect(mapped !== undefined).assertTrue();
      if (mapped) {
        expect(mapped.x).assertEqual(640);
        expect(mapped.y).assertEqual(360);
      }

      model.reset();
      model.setPeerDisplays(nextDisplays, 0);
      expect(model.getCoordinateSpace() === undefined).assertTrue();
    });
  });
}
