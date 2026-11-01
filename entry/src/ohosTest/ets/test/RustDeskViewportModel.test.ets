import { describe, expect, it } from '@ohos/hypium';
import {
  computeSurfaceGeometry, findPeerResolutionIndex, getPeerDisplayModeSize, getPeerDisplayScale,
  normalizeRustDeskDisplayMode, RustDeskDisplayMode, RustDeskViewportModel, updatePeerDisplayGeometry,
} from '../../../main/ets/pages/rustdesk/RustDeskViewportModel';
import { PeerDisplayInfo, ResolutionInfo } from '../../../main/ets/pages/rustdesk/RustDeskTypes';
import { isLocalPointInsidePaintRect, RustDeskSize } from '../../../main/ets/pages/rustdesk/RustDeskInputMapper';

/** A viewport model presenting `display` in `mode` inside a 1000x1000 pane. */
function presentedModel(mode: RustDeskDisplayMode, display: PeerDisplayInfo): RustDeskViewportModel {
  const model = new RustDeskViewportModel();
  model.setViewportSize(1000, 1000);
  model.setPeerDisplays([display], 0);
  model.setDisplayMode(mode);
  return model;
}

/** The remote point a local point maps to, as `x,y`, or `none` without a space. */
function mappedPoint(model: RustDeskViewportModel, x: number, y: number): string {
  const point = model.mapLocalToRemote(x, y);
  return point === undefined ? 'none' : `${point.x},${point.y}`;
}

export default function viewportModelTest(): void {
  describe('RustDeskViewportModelTest', () => {
    it('matches HiDPI modes including width-only FlutterHandler payloads and sparse switches', 0, () => {
      // Production make_displays_msg has neither scaled_height nor raw scale.
      // original_* is also optional, so it cannot be a prerequisite for HiDPI.
      const first: PeerDisplayInfo = {
        width: 5120, height: 2880, x: 0, y: 0, scaled_width: 2560,
      };
      const second: PeerDisplayInfo = {
        width: 3000, height: 2000, x: 5120, y: 0, scaled_width: 2000,
      };
      expect(getPeerDisplayScale(first)).assertEqual(2);
      expect(getPeerDisplayScale(second)).assertEqual(1.5);
      const mode = getPeerDisplayModeSize(first);
      const fractionalMode = getPeerDisplayModeSize(second);
      expect(mode !== undefined && fractionalMode !== undefined).assertTrue();
      if (mode && fractionalMode) {
        expect(mode.width).assertEqual(2560);
        expect(mode.height).assertEqual(1440);
        expect(fractionalMode.height).assertEqual(1333);
      }
      expect(findPeerResolutionIndex(first, [{ width: 2560, height: 1440 }])).assertEqual(0);
      const same = updatePeerDisplayGeometry(first, 5120, 2880, 10, 20);
      expect(same.scaled_width).assertEqual(2560);
      expect(getPeerDisplayScale(same)).assertEqual(2);
      const resized = updatePeerDisplayGeometry(same, 3840, 2160, 10, 20);
      expect(resized.scaled_width).assertEqual(1920);
      expect(resized.scaled_height).assertEqual(1080);
      expect(getPeerDisplayScale(resized)).assertEqual(2);
      const fractionalResize = updatePeerDisplayGeometry(second, 2400, 1600, 5120, 0);
      expect(fractionalResize.scaled_width).assertEqual(1600);
      expect(fractionalResize.scaled_height).assertEqual(1067);
      const model = new RustDeskViewportModel();
      model.setPeerDisplays([same, second], 0);
      expect(model.getDisplayScaleFactor()).assertEqual(2);
      expect(model.selectDisplay(1)).assertTrue();
      expect(model.getDisplayScaleFactor()).assertEqual(1.5);
      model.setPeerDisplays([resized, fractionalResize], 1);
      expect(model.getDisplayScaleFactor()).assertEqual(1.5);
      expect(model.selectDisplay(0)).assertTrue();
      expect(model.getDisplayScaleFactor()).assertEqual(2);

      const display: PeerDisplayInfo = {
        width: 5120, height: 2880, x: 0, y: 0,
        original_width: 2560, original_height: 1440, scaled_width: 2560, scaled_height: 1440,
      };
      const modes: ResolutionInfo[] = [
        { width: 5120, height: 2880 }, { width: 2560, height: 1440 },
      ];
      expect(getPeerDisplayScale(display)).assertEqual(2);
      const size = getPeerDisplayModeSize(display);
      expect(size !== undefined).assertTrue();
      if (size) {
        expect(size.width).assertEqual(2560);
        expect(size.height).assertEqual(1440);
      }
      expect(findPeerResolutionIndex(display, modes)).assertEqual(1);
      expect(findPeerResolutionIndex(display, [modes[0]])).assertEqual(-1);
      expect(findPeerResolutionIndex(display, [])).assertEqual(-1);
      expect(findPeerResolutionIndex(undefined, modes)).assertEqual(-1);
      expect(findPeerResolutionIndex(display, modes, { width: 1280, height: 720 })).assertEqual(-1);
      expect(findPeerResolutionIndex(display, modes, modes[0])).assertEqual(0);
    });

    it('preserves known ratios for sparse same-size and resized switch confirmations', 0, () => {
      const display: PeerDisplayInfo = {
        width: 5120, height: 2880, x: 0, y: 0,
        original_width: 2560, original_height: 1440, scaled_width: 2560, scaled_height: 1440,
      };
      const same = updatePeerDisplayGeometry(display, 5120, 2880, -5120, 20);
      expect(same.scaled_width).assertEqual(2560);
      expect(same.scaled_height).assertEqual(1440);
      expect(same.x).assertEqual(-5120);
      const changed = updatePeerDisplayGeometry(same, 3840, 2160, 100, 20);
      expect(changed.scaled_width).assertEqual(1920);
      expect(changed.scaled_height).assertEqual(1080);
      expect(changed.original_width).assertEqual(2560);
      expect(getPeerDisplayScale(changed)).assertEqual(2);
      expect(display.width).assertEqual(5120);
      expect(display.x).assertEqual(0);
      const fractional: PeerDisplayInfo = {
        width: 3000, height: 2000, x: 0, y: 0, scaled_width: 2000, scaled_height: 1333,
      };
      expect(getPeerDisplayScale(fractional)).assertEqual(1.5);
      const resized = updatePeerDisplayGeometry(fractional, 2400, 1600, 0, 0);
      expect(resized.scaled_width).assertEqual(1600);
      expect(resized.scaled_height).assertEqual(1067);
    });

    it('does not invent scale from missing conflicting or invalid authoritative metadata', 0, () => {
      const missing: PeerDisplayInfo = {
        width: 5120, height: 2880, x: 0, y: 0, original_width: 2560, original_height: 1440,
      };
      const conflicting: PeerDisplayInfo = {
        width: 5120, height: 2880, x: 0, y: 0, scaled_width: 2560, scaled_height: 2880,
      };
      const invalid: PeerDisplayInfo = {
        width: 5120, height: 2880, x: 0, y: 0, scaled_width: Number.NaN, scaled_height: 1440,
      };
      const samples: PeerDisplayInfo[] = [missing, conflicting, invalid];
      for (let index = 0; index < samples.length; index += 1) {
        expect(getPeerDisplayScale(samples[index]) === undefined).assertTrue();
        expect(getPeerDisplayModeSize(samples[index]) === undefined).assertTrue();
        expect(findPeerResolutionIndex(samples[index], [{ width: 5120, height: 2880 }])).assertEqual(-1);
        const updated = updatePeerDisplayGeometry(samples[index], 3840, 2160, 0, 0);
        expect(updated.scaled_width === undefined).assertTrue();
        expect(updated.scaled_height === undefined).assertTrue();
      }
    });

    it('keeps submitted video dimensions separate from peer mode fit and normalized input', 0, () => {
      const model = new RustDeskViewportModel();
      const display: PeerDisplayInfo = {
        width: 5120, height: 2880, x: -5120, y: 100,
        original_width: 2560, original_height: 1440, scaled_width: 2560, scaled_height: 1440,
      };
      model.setViewportSize(1280, 800);
      model.setPeerDisplays([display], 0);
      model.setViewTransform(1.5, 30, 20, 0);
      const before = model.buildRenderPlan();
      const pointer = model.mapLocalToRemote(700, 450);
      // Deliberately different aspect: a video sample must not redefine the peer.
      expect(model.setSubmittedVideoSize(0, 1920, 1200)).assertTrue();
      const after = model.buildRenderPlan();
      const mapped = model.mapLocalToRemote(700, 450);
      expect(before !== undefined && after !== undefined && pointer !== undefined && mapped !== undefined).assertTrue();
      if (before && after && pointer && mapped) {
        expect(after.remoteRect.width).assertEqual(5120);
        expect(after.remoteRect.height).assertEqual(2880);
        expect(after.videoSize.width).assertEqual(before.videoSize.width);
        expect(after.contentRect.height).assertEqual(before.contentRect.height);
        expect(after.contentRect.top).assertEqual(before.contentRect.top);
        expect(after.scale).assertEqual(2);
        expect(mapped.x).assertEqual(pointer.x);
        expect(mapped.y).assertEqual(pointer.y);
        const local = model.mapRemoteToLocal(mapped.x, mapped.y);
        expect(local !== undefined).assertTrue();
        if (local) {
          expect(Math.abs(local.x - 700) <= 1).assertTrue();
          expect(Math.abs(local.y - 450) <= 1).assertTrue();
        }
      }
      expect(display.width).assertEqual(5120);
      expect(display.scaled_width).assertEqual(2560);
      const video = model.getSubmittedVideoSize();
      expect(video !== undefined).assertTrue();
      if (video) {
        expect(video.width).assertEqual(1920);
        expect(video.height).assertEqual(1200);
      }
      expect(model.setSubmittedVideoSize(1, 640, 480)).assertFalse();
      expect(model.setSubmittedVideoSize(0, 0, 480)).assertFalse();
      // Same-display Surface/route replacement must not expose the old submission.
      model.clearSubmittedVideoSize();
      expect(model.getSubmittedVideoSize() === undefined).assertTrue();
      expect(model.getCurrentDisplay()).assertEqual(display);
      expect(model.getDisplayScaleFactor()).assertEqual(2);
      expect(model.setSubmittedVideoSize(0, 1280, 720)).assertTrue();
      const fresh = model.getSubmittedVideoSize();
      expect(fresh !== undefined).assertTrue();
      if (fresh) {
        expect(fresh.width).assertEqual(1280);
        fresh.width = 1;
        const retained = model.getSubmittedVideoSize();
        expect(retained !== undefined).assertTrue();
        if (retained) {
          expect(retained.width).assertEqual(1280);
        }
      }
      model.setPeerDisplays([display], 0);
      expect(model.getSubmittedVideoSize() === undefined).assertTrue();
    });

    it('invalidates submission metadata on switch and reset without fabricating unknown geometry', 0, () => {
      const model = new RustDeskViewportModel();
      model.setViewportSize(1280, 800);
      expect(model.setSubmittedVideoSize(0, 1920, 1080)).assertFalse();
      expect(model.buildRenderPlan() === undefined).assertTrue();
      const displays: PeerDisplayInfo[] = [
        { width: 5120, height: 2880, x: 0, y: 0, scaled_width: 2560, scaled_height: 1440 },
        { width: 1920, height: 1080, x: 5120, y: 0, scaled_width: 1920, scaled_height: 1080 },
      ];
      model.setPeerDisplays(displays, 0);
      expect(model.setSubmittedVideoSize(0, 2560, 1440)).assertTrue();
      expect(model.selectDisplay(1)).assertTrue();
      expect(model.getSubmittedVideoSize() === undefined).assertTrue();
      expect(model.getDisplayScaleFactor()).assertEqual(1);
      expect(model.setSubmittedVideoSize(0, 2560, 1440)).assertFalse();
      expect(model.setSubmittedVideoSize(1, 1280, 720)).assertTrue();
      model.resetSessionGeometry();
      expect(model.getSubmittedVideoSize() === undefined).assertTrue();
      expect(model.getRemoteRect() === undefined).assertTrue();
      expect(model.mapLocalToRemote(100, 100) === undefined).assertTrue();
    });

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

    it('measures the video Surface so only stretch mode distorts the frame', 0, () => {
      // The native producer composites a fixed-size frame into the measured
      // rectangle, so that rectangle is the only aspect-ratio control we have.
      const stretch = computeSurfaceGeometry('stretch', 2560, 1440, 1120, 630, 1);
      expect(stretch.width).assertEqual(1120);
      expect(stretch.height).assertEqual(630);

      const fit = computeSurfaceGeometry('fit', 2560, 1440, 1000, 1000, 2.5);
      expect(fit.width).assertEqual(1000);
      expect(fit.height).assertEqual(563);

      // Original mode presents remote pixels and never magnifies to the pane.
      const original = computeSurfaceGeometry('original', 800, 600, 100, 100, 1);
      expect(original.width).assertEqual(800);
      expect(original.height).assertEqual(600);
      // The pane is measured in vp, so one remote pixel is one physical pixel
      // only after the panel's px-per-vp ratio is taken out.
      const dense = computeSurfaceGeometry('original', 2560, 1440, 1120, 736, 2.5);
      expect(dense.width).assertEqual(1024);
      expect(dense.height).assertEqual(576);

      // Without an authoritative frame size the pane is left unchanged.
      const unknown = computeSurfaceGeometry('fit', 0, 0, 400, 300, 1);
      expect(unknown.width).assertEqual(400);
      expect(unknown.height).assertEqual(300);
    });

    it('keeps the fitted Surface inside the pane and reports the mode', 0, () => {
      const model = new RustDeskViewportModel();
      model.setViewportSize(1000, 1000);
      const geometry = model.buildSurfaceGeometry('fit', new RustDeskSize(2560, 1440));
      const stretched = computeSurfaceGeometry('stretch', 2560, 1440, 1000, 1000, 1);
      expect(geometry.height < stretched.height).assertTrue();
      expect(geometry.width <= 1000).assertTrue();

      // An unknown mode never silently becomes a stretch.
      expect(normalizeRustDeskDisplayMode('')).assertEqual('fit');
      expect(normalizeRustDeskDisplayMode('stretch')).assertEqual('stretch');
      expect(normalizeRustDeskDisplayMode('original')).assertEqual('original');
      expect(normalizeRustDeskDisplayMode('bogus')).assertEqual('fit');
    });

    it('sizes the Surface from the current display before any frame is observed', 0, () => {
      // The mode must act on the rectangle as soon as peer geometry is known,
      // not only after the first frame: the display's own size is what the
      // Surface is measured against until an observed frame size exists.
      const model = new RustDeskViewportModel();
      model.setViewportSize(1000, 1000);
      const display: PeerDisplayInfo = { width: 2560, height: 1440, x: 0, y: 0 };
      model.setPeerDisplays([display], 0);

      const fit = model.buildSurfaceGeometryForDisplay('fit');
      expect(fit.width).assertEqual(1000);
      expect(fit.height).assertEqual(563);

      const stretch = model.buildSurfaceGeometryForDisplay('stretch');
      expect(stretch.width).assertEqual(1000);
      expect(stretch.height).assertEqual(1000);

      // Remote pixels, never magnified to the pane.
      const original = model.buildSurfaceGeometryForDisplay('original');
      expect(original.width).assertEqual(2560);
      expect(original.height).assertEqual(1440);

      // An observed frame size wins over the display's declaration.
      expect(model.setSubmittedVideoSize(0, 1280, 720)).assertTrue();
      const observed = model.buildSurfaceGeometryForDisplay('fit');
      expect(observed.width).assertEqual(1000);
      expect(observed.height).assertEqual(563);
    });

    it('maps input through the rectangle each display mode presents', 0, () => {
      const display: PeerDisplayInfo = { width: 1600, height: 1200, x: 0, y: 0 };
      const stretched = presentedModel('stretch', display);
      const fitted = presentedModel('fit', display);
      const original = presentedModel('original', display);

      // The same local point is a different remote point in each mode, because the
      // picture occupies a different rectangle: the pane, the letterboxed fit rect,
      // or the remote pixels centered and clipped to the pane.
      expect(mappedPoint(stretched, 250, 250)).assertEqual('400,300');
      expect(mappedPoint(fitted, 250, 250)).assertEqual('400,200');
      expect(mappedPoint(original, 250, 250)).assertEqual('550,350');

      const stretchedPlan = stretched.buildRenderPlan();
      const fittedPlan = fitted.buildRenderPlan();
      const originalPlan = original.buildRenderPlan();
      expect(stretchedPlan !== undefined && fittedPlan !== undefined && originalPlan !== undefined).assertTrue();
      if (stretchedPlan && fittedPlan && originalPlan) {
        expect(stretchedPlan.contentRect.left).assertEqual(0);
        expect(stretchedPlan.contentRect.height).assertEqual(1000);
        expect(fittedPlan.contentRect.top).assertEqual(125);
        expect(fittedPlan.contentRect.height).assertEqual(750);
        expect(originalPlan.contentRect.left).assertEqual(-300);
        expect(originalPlan.contentRect.width).assertEqual(1600);
      }
    });

    it('rejects a point the presented picture does not cover', 0, () => {
      const display: PeerDisplayInfo = { width: 1600, height: 1200, x: 0, y: 0 };
      const stretchedSpace = presentedModel('stretch', display).getCoordinateSpace();
      const fittedSpace = presentedModel('fit', display).getCoordinateSpace();
      expect(stretchedSpace !== undefined && fittedSpace !== undefined).assertTrue();
      if (!stretchedSpace || !fittedSpace) {
        return;
      }
      // The letterbox a fit leaves is not part of the picture, while the pane a
      // stretch fills is; the same local point is inside only one of them.
      expect(isLocalPointInsidePaintRect(fittedSpace, 500, 50)).assertFalse();
      expect(isLocalPointInsidePaintRect(fittedSpace, 500, 500)).assertTrue();
      expect(isLocalPointInsidePaintRect(stretchedSpace, 500, 50)).assertTrue();
    });

    it('keeps the presented rectangle under the user transform', 0, () => {
      const model = presentedModel('fit', { width: 1600, height: 1200, x: 0, y: 0 });
      model.setViewTransform(1.5, 40, -20, 30);

      const mapped = model.mapLocalToRemote(600, 400);
      expect(mapped !== undefined).assertTrue();
      if (!mapped) {
        return;
      }
      const local = model.mapRemoteToLocal(mapped.x, mapped.y);
      expect(local !== undefined).assertTrue();
      if (local) {
        expect(Math.abs(local.x - 600) <= 1).assertTrue();
        expect(Math.abs(local.y - 400) <= 1).assertTrue();
      }
    });

    it('rejects a point the presented clip does not show', 0, () => {
      const display: PeerDisplayInfo = { width: 1600, height: 1200, x: 0, y: 0 };
      const zoomedIn = presentedModel('fit', display);
      zoomedIn.setViewTransform(2, 0, 0, 0);
      const zoomedSpace = zoomedIn.getCoordinateSpace();
      expect(zoomedSpace !== undefined).assertTrue();
      if (!zoomedSpace) {
        return;
      }
      // The picture is scaled inside a clip that stays the fit rectangle, so the
      // letterbox beside it is not part of the picture however the inverse transform
      // maps that point.
      expect(isLocalPointInsidePaintRect(zoomedSpace, 500, 500)).assertTrue();
      expect(isLocalPointInsidePaintRect(zoomedSpace, 500, 50)).assertFalse();

      const zoomedOut = presentedModel('fit', display);
      zoomedOut.setViewTransform(0.5, 0, 0, 0);
      const outSpace = zoomedOut.getCoordinateSpace();
      expect(outSpace !== undefined).assertTrue();
      if (!outSpace) {
        return;
      }
      // A zoomed-out picture leaves an empty margin inside that same clip.
      expect(isLocalPointInsidePaintRect(outSpace, 500, 500)).assertTrue();
      expect(isLocalPointInsidePaintRect(outSpace, 500, 200)).assertFalse();
    });

    it('accepts a point the RGBA fallback shows outside the Surface clip', 0, () => {
      const display: PeerDisplayInfo = { width: 1600, height: 1200, x: 0, y: 0 };
      const fallback = presentedModel('fit', display);
      fallback.setFallbackPresentation(true);
      fallback.setViewTransform(2, 0, 0, 0);
      const fallbackSpace = fallback.getCoordinateSpace();
      expect(fallbackSpace !== undefined).assertTrue();
      if (!fallbackSpace) {
        return;
      }
      // The fallback image fills the pane and is transformed outside the Surface's
      // container, so the letterbox beside the fit rectangle is visible there and a
      // click on it must still reach the peer.
      expect(isLocalPointInsidePaintRect(fallbackSpace, 500, 50)).assertTrue();
      expect(isLocalPointInsidePaintRect(fallbackSpace, 500, 500)).assertTrue();

      // Without a transform the fallback letterboxes the picture itself, so the same
      // point is off the picture.
      const untransformed = presentedModel('fit', display);
      untransformed.setFallbackPresentation(true);
      const untransformedSpace = untransformed.getCoordinateSpace();
      expect(untransformedSpace !== undefined).assertTrue();
      if (!untransformedSpace) {
        return;
      }
      expect(isLocalPointInsidePaintRect(untransformedSpace, 500, 50)).assertFalse();
      expect(isLocalPointInsidePaintRect(untransformedSpace, 500, 500)).assertTrue();
    });
  });
}
