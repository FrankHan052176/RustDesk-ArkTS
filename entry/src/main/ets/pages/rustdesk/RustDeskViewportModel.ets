import {
  mapLocalToRemote,
  mapRemoteToLocal,
  resolveCoordinateSpace,
  LocalPointerPosition,
  RemotePointerPosition,
  RustDeskCoordinateSpace,
  RustDeskRect,
  RustDeskSize,
} from './RustDeskInputMapper';
import { PeerDisplayInfo, ResolutionInfo } from './RustDeskTypes';

function isPixelSize(width: number, height: number): boolean {
  return Number.isSafeInteger(width) && Number.isSafeInteger(height) && width > 0 && height > 0;
}

// FlutterHandler projects only scaled_width = round(width/scale), not height.
// An optional scaled_height is validated when present. original_* is the initial mode,
// not a scale source: it need not equal the current mode after a resolution change.
export function getPeerDisplayScale(display: PeerDisplayInfo): number | undefined {
  const width = display.scaled_width ?? 0;
  if (!isPixelSize(display.width, display.height) || !isPixelSize(width, 1)) {
    return undefined;
  }
  const widthRatio = display.width / width;
  if (display.scaled_height === undefined) {
    return widthRatio;
  }
  const height = display.scaled_height;
  if (!isPixelSize(width, height)) {
    return undefined;
  }
  const lower = Math.max(display.width / (width + 0.5), display.height / (height + 0.5));
  const upper = Math.min(display.width / (width - 0.5), display.height / (height - 0.5));
  if (lower >= upper) {
    return undefined;
  }
  const ratio = widthRatio > lower && widthRatio <= upper ? widthRatio : (lower + upper) / 2;
  return Math.round(display.width / ratio) === width && Math.round(display.height / ratio) === height
    ? ratio : undefined;
}

export function getPeerDisplayModeSize(display: PeerDisplayInfo): ResolutionInfo | undefined {
  const ratio = getPeerDisplayScale(display);
  if (ratio === undefined) {
    return undefined;
  }
  return {
    width: display.scaled_width ?? 0,
    height: display.scaled_height ?? Math.round(display.height / ratio),
  };
}

export function findPeerResolutionIndex(
  display: PeerDisplayInfo | undefined,
  resolutions: ResolutionInfo[],
  requested: ResolutionInfo | undefined = undefined,
): number {
  const size = requested ?? (display === undefined ? undefined : getPeerDisplayModeSize(display));
  if (size === undefined || !isPixelSize(size.width, size.height)) {
    return -1;
  }
  for (let index = 0; index < resolutions.length; index += 1) {
    if (resolutions[index].width === size.width && resolutions[index].height === size.height) {
      return index;
    }
  }
  return -1;
}

// A sparse switch event supplies new raw geometry, but no new scale. Retain only
// a consistent known ratio; never infer Retina from original_* or pixel maxima.
export function updatePeerDisplayGeometry(
  previous: PeerDisplayInfo, width: number, height: number, x: number, y: number,
): PeerDisplayInfo {
  const ratio = getPeerDisplayScale(previous);
  const unchanged = width === previous.width && height === previous.height;
  const updated: PeerDisplayInfo = {
    width, height, x, y,
    cursor_embedded: previous.cursor_embedded,
    original_width: previous.original_width,
    original_height: previous.original_height,
  };
  if (isPixelSize(width, height) && ratio !== undefined) {
    updated.scaled_width = unchanged ? previous.scaled_width : Math.round(width / ratio);
    updated.scaled_height = unchanged ? previous.scaled_height : Math.round(height / ratio);
  }
  return updated;
}

export interface RustDeskRenderPlan {
  display: number;
  remoteRect: RustDeskRect;
  contentRect: RustDeskRect;
  renderSize: RustDeskSize;
  videoSize: RustDeskSize;
  surfaceSize: RustDeskSize;
  scale: number;
}

/**
 * How the remote frame is fitted into the preview pane.
 * - `stretch`: the frame fills the pane and keeps the pane's aspect ratio, so a
 *   mismatched remote aspect ratio is distorted.
 * - `fit`: the frame keeps its own aspect ratio and is letterboxed inside the
 *   pane; nothing is cropped and nothing is distorted.
 * - `original`: the frame is presented at its remote pixel size, only inset when
 *   it is smaller than the pane and never shrunk to fit.
 */
export type RustDeskDisplayMode = 'stretch' | 'fit' | 'original';

export function isRustDeskDisplayMode(value: string): boolean {
  return value === 'stretch' || value === 'fit' || value === 'original';
}

export function normalizeRustDeskDisplayMode(value: string): RustDeskDisplayMode {
  // ArkTS rejects user-defined type predicates (`value is T`), so the validated
  // string is narrowed by construction here instead.
  if (value === 'stretch') {
    return 'stretch';
  }
  if (value === 'original') {
    return 'original';
  }
  return 'fit';
}

// The video Surface is a fixed-size native producer: its produced frame is
// composited into whatever rectangle it is measured at, with no aspect
// correction. A geometry that does not carry the remote aspect ratio is
// therefore a stretch by construction, so every non-stretch mode must express
// the fit through the measured rectangle instead of a render hint.
//
// The pane is measured in vp and the video in physical pixels. Fit and stretch
// are ratios of the two and need no conversion; `original` is an absolute size,
// so the remote pixels are converted with the panel's own px-per-vp ratio and
// one remote pixel lands on one physical pixel.
export function computeSurfaceGeometry(
  mode: RustDeskDisplayMode,
  videoWidth: number,
  videoHeight: number,
  viewportWidth: number,
  viewportHeight: number,
  pxPerVp: number,
): RustDeskSize {
  const paneWidth = Number.isFinite(viewportWidth) ? Math.max(Math.floor(viewportWidth), 1) : 1;
  const paneHeight = Number.isFinite(viewportHeight) ? Math.max(Math.floor(viewportHeight), 1) : 1;
  if (!isPixelSize(videoWidth, videoHeight)) {
    // No authoritative frame geometry yet: present the pane unchanged and let
    // the confirmed video size drive the next measurement.
    return new RustDeskSize(paneWidth, paneHeight);
  }
  if (mode === 'stretch') {
    return new RustDeskSize(paneWidth, paneHeight);
  }
  if (mode === 'original') {
    // Never magnify past the remote pixel size and never shrink below it.
    const density = Number.isFinite(pxPerVp) && pxPerVp > 0 ? pxPerVp : 1;
    return new RustDeskSize(videoWidth / density, videoHeight / density);
  }
  const scale = Math.min(paneWidth / videoWidth, paneHeight / videoHeight);
  return new RustDeskSize(
    Math.max(Math.round(videoWidth * scale), 1),
    Math.max(Math.round(videoHeight * scale), 1),
  );
}

export class RustDeskViewportModel {
  private displays: PeerDisplayInfo[] = [];
  private currentDisplay: number = 0;
  private viewportWidth: number = 0;
  private viewportHeight: number = 0;
  private surfaceWidth: number = 0;
  private surfaceHeight: number = 0;
  private rotation: number = 0;
  private displayMode: RustDeskDisplayMode = 'fit';
  /**
   * Whether the picture is presented by the RGBA fallback image rather than the
   * native Surface.
   *
   * The two clip differently: the Surface's container is measured at the mode's
   * rectangle and clips the transformed picture to it, while the fallback image fills
   * the pane and is transformed outside that container, so the pane is its clip.
   * Input must follow whichever is presenting.
   */
  private fallbackPresentation: boolean = false;
  /** The panel's physical pixels per vp, which `original` mode measures with. */
  private pxPerVp: number = 1;
  private viewScale: number = 1;
  private viewOffsetX: number = 0;
  private viewOffsetY: number = 0;
  private viewRotation: number = 0;
  private submittedVideoSize: RustDeskSize | undefined = undefined;

  reset(): void {
    this.resetSessionGeometry();
    this.viewportWidth = 0;
    this.viewportHeight = 0;
  }

  resetSessionGeometry(): void {
    this.displays = [];
    this.submittedVideoSize = undefined;
    this.currentDisplay = 0;
    this.surfaceWidth = 0;
    this.surfaceHeight = 0;
    this.rotation = 0;
    this.viewScale = 1;
    this.viewOffsetX = 0;
    this.viewOffsetY = 0;
    this.viewRotation = 0;
  }

  setPeerDisplays(displays: PeerDisplayInfo[], currentDisplay: number): void {
    // A fresh authoritative mode report invalidates the previous submission sample.
    this.submittedVideoSize = undefined;
    this.displays = displays;
    this.currentDisplay = this.clampDisplayIndex(currentDisplay);
  }

  setViewportSize(width: number, height: number): void {
    if (width > 0) {
      this.viewportWidth = width;
    }
    if (height > 0) {
      this.viewportHeight = height;
    }
  }

  /** Records the panel density; it belongs to the screen, not to a session. */
  setPixelDensity(pxPerVp: number): void {
    if (Number.isFinite(pxPerVp) && pxPerVp > 0) {
      this.pxPerVp = pxPerVp;
    }
  }

  setSurfaceSize(width: number, height: number): void {
    this.surfaceWidth = Math.max(Math.round(width), 0);
    this.surfaceHeight = Math.max(Math.round(height), 0);
  }

  /**
   * Measured size the video Surface must be laid out at for `mode`.
   * `videoSize` is the last authoritative frame size, never the peer mode.
   *
   * The mode is a parameter rather than stored state because the caller holds it
   * as observable UI state: a surface re-measures only when an expression the
   * renderer tracks changes, and a plain field inside this object is not one.
   */
  buildSurfaceGeometry(
    mode: RustDeskDisplayMode,
    videoSize: RustDeskSize | undefined,
  ): RustDeskSize {
    return computeSurfaceGeometry(
      mode,
      videoSize === undefined ? 0 : videoSize.width,
      videoSize === undefined ? 0 : videoSize.height,
      this.viewportWidth,
      this.viewportHeight,
      this.pxPerVp,
    );
  }

  setRotation(rotation: number): void {
    this.rotation = rotation;
  }

  /**
   * The mode the preview presents in, which decides the rectangle the picture
   * occupies and therefore the geometry input is mapped through.
   *
   * It is the caller's live presentation state, not session geometry: it is kept
   * across a session reset the way the display mode itself is.
   */
  setDisplayMode(mode: RustDeskDisplayMode): void {
    this.displayMode = mode;
  }

  /**
   * Whether the RGBA fallback image presents the picture instead of the Surface.
   *
   * It is the caller's live presentation state: the fallback is used only while an
   * RGBA frame is on screen, and it changes the clip input is mapped through.
   */
  setFallbackPresentation(active: boolean): void {
    this.fallbackPresentation = active;
  }

  setViewTransform(scale: number, offsetX: number, offsetY: number, rotation: number): void {
    this.viewScale = Number.isFinite(scale) && scale > 0 ? scale : 1;
    this.viewOffsetX = Number.isFinite(offsetX) ? offsetX : 0;
    this.viewOffsetY = Number.isFinite(offsetY) ? offsetY : 0;
    this.viewRotation = Number.isFinite(rotation) ? rotation : 0;
  }

  selectDisplay(index: number): boolean {
    if (!Number.isFinite(index)) return false;
    const normalized = Math.floor(index);
    if (normalized < 0 || normalized >= this.displays.length) return false;
    this.submittedVideoSize = undefined;
    this.currentDisplay = normalized;
    return true;
  }

  getCurrentDisplayIndex(): number {
    return this.clampDisplayIndex(this.currentDisplay);
  }

  getCurrentDisplay(): PeerDisplayInfo | undefined {
    if (this.displays.length === 0) {
      return undefined;
    }
    return this.displays[this.getCurrentDisplayIndex()];
  }

  /**
   * The selected display's own extent, in display-local pixels.
   *
   * `Viewer::send_mouse` takes display-local coordinates and adds the peer's
   * screen origin itself, so this rectangle must not carry that origin: a
   * mapping that added it too would apply it twice, putting a click on a
   * secondary display at the wrong place or outside the display entirely, where
   * the engine refuses it as invalid. Origin is therefore 0/0 while
   * width/height stay the display's own extent.
   */
  getRemoteRect(): RustDeskRect | undefined {
    const displayInfo = this.getCurrentDisplay();
    if (!displayInfo || !isPixelSize(displayInfo.width, displayInfo.height)) {
      return undefined;
    }
    return new RustDeskRect(0, 0, displayInfo.width, displayInfo.height);
  }

  getDisplayScaleFactor(): number {
    const displayInfo = this.getCurrentDisplay();
    return displayInfo === undefined ? 1 : getPeerDisplayScale(displayInfo) ?? 1;
  }

  // Observed video dimensions are metadata, never a peer mode or input rectangle.
  // Keep buildRenderPlan.videoSize as renderer configuration, not this sample.
  setSubmittedVideoSize(display: number, width: number, height: number): boolean {
    if (!Number.isInteger(display) || display !== this.getCurrentDisplayIndex()
      || this.getCurrentDisplay() === undefined || !isPixelSize(width, height)) {
      return false;
    }
    this.submittedVideoSize = new RustDeskSize(width, height);
    return true;
  }

  getSubmittedVideoSize(): RustDeskSize | undefined {
    const size = this.submittedVideoSize;
    return size === undefined ? undefined : new RustDeskSize(size.width, size.height);
  }

  clearSubmittedVideoSize(): void {
    this.submittedVideoSize = undefined;
  }

  getCoordinateSpace(): RustDeskCoordinateSpace | undefined {
    const remoteRect = this.getRemoteRect();
    if (!remoteRect || this.viewportWidth <= 0 || this.viewportHeight <= 0) {
      return undefined;
    }
    const presented = this.presentedSurfaceRect(remoteRect);
    const space = resolveCoordinateSpace(
      this.viewportWidth,
      this.viewportHeight,
      remoteRect,
      this.rotation,
      presented,
      this.fallbackPresentation ? new RustDeskRect(0, 0, this.viewportWidth, this.viewportHeight) : presented,
    );
    space.viewScale = this.viewScale;
    space.viewOffsetX = this.viewOffsetX;
    space.viewOffsetY = this.viewOffsetY;
    space.viewRotation = this.viewRotation;
    return space;
  }

  /**
   * The rectangle the presented picture occupies inside the pane.
   *
   * The Surface is measured at `computeSurfaceGeometry`'s size for the current
   * mode and the preview centers it, so that centered rectangle is where the
   * picture is: the pane in `stretch`, the letterboxed fit rect in `fit`, and the
   * remote pixel size, centered and clipped, in `original`. Input is mapped
   * through this rectangle, not through the fit rect the mode may not use.
   */
  private presentedSurfaceRect(remoteRect: RustDeskRect): RustDeskRect {
    const size = computeSurfaceGeometry(
      this.displayMode,
      remoteRect.width,
      remoteRect.height,
      this.viewportWidth,
      this.viewportHeight,
      this.pxPerVp,
    );
    return new RustDeskRect(
      (this.viewportWidth - size.width) / 2,
      (this.viewportHeight - size.height) / 2,
      size.width,
      size.height,
    );
  }

  getRenderSize(): RustDeskSize {
    const space = this.getCoordinateSpace();
    if (space) {
      return new RustDeskSize(
        Math.max(Math.round(space.renderSize.width), 1),
        Math.max(Math.round(space.renderSize.height), 1),
      );
    }
    const remoteRect = this.getRemoteRect();
    if (remoteRect) {
      return new RustDeskSize(Math.max(Math.round(remoteRect.width), 1), Math.max(Math.round(remoteRect.height), 1));
    }
    return new RustDeskSize(1, 1);
  }

  getSurfaceRenderSize(): RustDeskSize {
    if (this.surfaceWidth > 0 && this.surfaceHeight > 0) {
      return new RustDeskSize(this.surfaceWidth, this.surfaceHeight);
    }
    return this.getRenderSize();
  }

  getSurfaceSize(): RustDeskSize {
    return new RustDeskSize(this.surfaceWidth, this.surfaceHeight);
  }

  /**
   * Measured size the video Surface must be laid out at, from the current mode.
   *
   * The observed frame size wins when it is known, because the peer's declared
   * geometry can differ from what it actually sends; otherwise the current
   * display's reported size is authoritative. With neither, the pane is used
   * unchanged and the next measurement corrects it.
   */
  buildSurfaceGeometryForDisplay(mode: RustDeskDisplayMode): RustDeskSize {
    const submitted = this.submittedVideoSize;
    if (submitted !== undefined) {
      return this.buildSurfaceGeometry(mode, submitted);
    }
    const display = this.getCurrentDisplay();
    if (display === undefined) {
      return this.buildSurfaceGeometry(mode, undefined);
    }
    return this.buildSurfaceGeometry(mode, new RustDeskSize(display.width, display.height));
  }

  buildRenderPlan(): RustDeskRenderPlan | undefined {
    const space = this.getCoordinateSpace();
    const remoteRect = this.getRemoteRect();
    if (!space || !remoteRect) {
      return undefined;
    }
    const renderSize = this.getRenderSize();
    return {
      display: this.getCurrentDisplayIndex(),
      remoteRect,
      contentRect: space.paintRect,
      renderSize,
      videoSize: new RustDeskSize(
        Math.max(Math.round(remoteRect.width), 1),
        Math.max(Math.round(remoteRect.height), 1),
      ),
      surfaceSize: this.getSurfaceSize(),
      scale: this.getDisplayScaleFactor(),
    };
  }

  mapLocalToRemote(localX: number, localY: number): RemotePointerPosition | undefined {
    const space = this.getCoordinateSpace();
    if (!space) {
      return undefined;
    }
    return mapLocalToRemote(space, localX, localY);
  }

  mapRemoteToLocal(remoteX: number, remoteY: number): LocalPointerPosition | undefined {
    const space = this.getCoordinateSpace();
    if (!space) {
      return undefined;
    }
    return mapRemoteToLocal(space, remoteX, remoteY);
  }

  describeRenderPlan(): string {
    const plan = this.buildRenderPlan();
    if (!plan) {
      return 'Display not ready';
    }
    const surfaceWidth = plan.surfaceSize.width > 0 ? plan.surfaceSize.width : plan.renderSize.width;
    const surfaceHeight = plan.surfaceSize.height > 0 ? plan.surfaceSize.height : plan.renderSize.height;
    return `Remote ${plan.videoSize.width}x${plan.videoSize.height} -> surface ${surfaceWidth}x${surfaceHeight}`;
  }

  private clampDisplayIndex(index: number): number {
    if (this.displays.length === 0) {
      return 0;
    }
    const normalized = Number.isFinite(index) ? Math.floor(index) : 0;
    return Math.min(Math.max(normalized, 0), this.displays.length - 1);
  }
}
