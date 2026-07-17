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
import { PeerDisplayInfo } from './RustDeskTypes';

export interface RustDeskRenderPlan {
  display: number;
  remoteRect: RustDeskRect;
  contentRect: RustDeskRect;
  renderSize: RustDeskSize;
  videoSize: RustDeskSize;
  surfaceSize: RustDeskSize;
  scale: number;
}

export class RustDeskViewportModel {
  private displays: PeerDisplayInfo[] = [];
  private currentDisplay: number = 0;
  private viewportWidth: number = 0;
  private viewportHeight: number = 0;
  private surfaceWidth: number = 0;
  private surfaceHeight: number = 0;
  private rotation: number = 0;
  private viewScale: number = 1;
  private viewOffsetX: number = 0;
  private viewOffsetY: number = 0;
  private viewRotation: number = 0;

  reset(): void {
    this.displays = [];
    this.currentDisplay = 0;
    this.viewportWidth = 0;
    this.viewportHeight = 0;
    this.surfaceWidth = 0;
    this.surfaceHeight = 0;
    this.rotation = 0;
    this.viewScale = 1;
    this.viewOffsetX = 0;
    this.viewOffsetY = 0;
    this.viewRotation = 0;
  }

  setPeerDisplays(displays: PeerDisplayInfo[], currentDisplay: number): void {
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

  setSurfaceSize(width: number, height: number): void {
    this.surfaceWidth = Math.max(Math.round(width), 0);
    this.surfaceHeight = Math.max(Math.round(height), 0);
  }

  setRotation(rotation: number): void {
    this.rotation = rotation;
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

  getRemoteRect(): RustDeskRect | undefined {
    const displayInfo = this.getCurrentDisplay();
    if (!displayInfo || displayInfo.width <= 0 || displayInfo.height <= 0) {
      return undefined;
    }
    return new RustDeskRect(displayInfo.x, displayInfo.y, displayInfo.width, displayInfo.height);
  }

  getDisplayScaleFactor(): number {
    const displayInfo = this.getCurrentDisplay();
    if (!displayInfo) {
      return 1;
    }
    const scaledWidth = Number(displayInfo.scaled_width ?? 0);
    const scaledHeight = Number(displayInfo.scaled_height ?? 0);
    if (scaledWidth <= 0 || scaledHeight <= 0 || displayInfo.width <= 0 || displayInfo.height <= 0) {
      return 1;
    }
    const widthScale = displayInfo.width / scaledWidth;
    const heightScale = displayInfo.height / scaledHeight;
    if (widthScale <= 1.01 || heightScale <= 1.01) {
      return 1;
    }
    if (Math.abs(widthScale - heightScale) > 0.08) {
      return 1;
    }
    return Math.max(widthScale, heightScale);
  }

  getCoordinateSpace(): RustDeskCoordinateSpace | undefined {
    const remoteRect = this.getRemoteRect();
    if (!remoteRect || this.viewportWidth <= 0 || this.viewportHeight <= 0) {
      return undefined;
    }
    const space = resolveCoordinateSpace(
      this.viewportWidth,
      this.viewportHeight,
      remoteRect,
      this.rotation,
    );
    space.viewScale = this.viewScale;
    space.viewOffsetX = this.viewOffsetX;
    space.viewOffsetY = this.viewOffsetY;
    space.viewRotation = this.viewRotation;
    return space;
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
