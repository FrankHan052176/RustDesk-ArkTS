import { NativeSessionBridge } from './NativeSessionBridge';
import { RustDeskViewportModel } from './RustDeskViewportModel';
import { ActionResponse, PeerDisplayInfo, ResolutionInfo } from './RustDeskTypes';

export type ImageQualityPreset = 'best' | 'balanced' | 'low' | 'custom';

export class SessionDisplayController {
  private readonly viewport: RustDeskViewportModel;
  private readonly bridge: NativeSessionBridge;
  private readonly invalidateFrames: () => void;
  private readonly reportActionError: (response: ActionResponse) => void;
  private displays: PeerDisplayInfo[] = [];
  private resolutions: ResolutionInfo[] = [];
  private platform: string = '';
  private imageQuality: ImageQualityPreset = 'balanced';
  private customImageQuality: number = 50;
  private customFps: number = 30;
  private awaitingAction: boolean = false;

  constructor(
    viewport: RustDeskViewportModel,
    bridge: NativeSessionBridge,
    invalidateFrames: () => void,
    reportActionError: (response: ActionResponse) => void,
  ) {
    this.viewport = viewport;
    this.bridge = bridge;
    this.invalidateFrames = invalidateFrames;
    this.reportActionError = reportActionError;
  }

  updatePeerInfo(
    displays: PeerDisplayInfo[],
    reportedCurrentDisplay: number | undefined,
    resolutions: ResolutionInfo[],
    platform: string,
  ): void {
    this.displays = displays;
    this.resolutions = resolutions;
    this.platform = platform;
    const selection = reportedCurrentDisplay === undefined
      ? this.viewport.getCurrentDisplayIndex()
      : reportedCurrentDisplay;
    this.viewport.setPeerDisplays(displays, selection);
  }

  selectDisplay(sessionId: string, display: number): boolean {
    if (!this.viewport.selectDisplay(display)) {
      return false;
    }
    const plan = this.viewport.buildRenderPlan();
    if (!plan) {
      return false;
    }
    const selectedDisplay = plan.display;
    const width = Math.max(Math.round(plan.videoSize.width), 1);
    const height = Math.max(Math.round(plan.videoSize.height), 1);
    this.invalidateFrames();
    this.awaitingAction = true;
    try {
      if (!this.applyAction(this.bridge.switchDisplay(sessionId, selectedDisplay))) {
        return false;
      }
      if (!this.applyAction(this.bridge.setSize(sessionId, selectedDisplay, width, height))) {
        return false;
      }
      return this.applyAction(this.bridge.refresh(sessionId, selectedDisplay));
    } finally {
      this.awaitingAction = false;
    }
  }

  canChangeResolution(peerPlatform: string): boolean {
    return peerPlatform.trim().toLowerCase() !== 'ohos';
  }

  requestResolution(
    sessionId: string,
    display: number,
    resolution: ResolutionInfo,
    peerPlatform: string,
  ): boolean {
    const selectedDisplay = this.viewport.getCurrentDisplayIndex();
    if (!this.canChangeResolution(peerPlatform)
      || !Number.isInteger(display)
      || display !== selectedDisplay
      || !Number.isFinite(resolution.width)
      || !Number.isFinite(resolution.height)
      || resolution.width <= 0
      || resolution.height <= 0) {
      return false;
    }
    this.awaitingAction = true;
    try {
      return this.applyAction(this.bridge.changeResolution(
        sessionId,
        selectedDisplay,
        Math.round(resolution.width),
        Math.round(resolution.height),
      ));
    } finally {
      this.awaitingAction = false;
    }
  }

  applyQuality(
    sessionId: string,
    quality: ImageQualityPreset,
    customQuality: number = 50,
    customFps: number = 30,
  ): boolean {
    if (!this.isValidQuality(quality)) {
      return false;
    }
    this.awaitingAction = true;
    try {
      if (quality !== 'custom') {
        if (!this.applyAction(this.bridge.setImageQuality(sessionId, quality))) {
          return false;
        }
        this.imageQuality = quality === 'best' ? 'best' : quality === 'balanced' ? 'balanced' : 'low';
        return true;
      }
      if (!this.isValidCustomQuality(customQuality) || !this.isValidCustomFps(customFps)) {
        return false;
      }
      this.bridge.setCustomImageQuality(sessionId, Math.round(customQuality));
      if (!this.applyAction(this.bridge.setCustomFps(sessionId, Math.round(customFps)))) {
        return false;
      }
      this.imageQuality = 'custom';
      this.customImageQuality = Math.round(customQuality);
      this.customFps = Math.round(customFps);
      return true;
    } finally {
      this.awaitingAction = false;
    }
  }

  getCurrentDisplayIndex(): number {
    return this.viewport.getCurrentDisplayIndex();
  }

  getDisplays(): PeerDisplayInfo[] {
    return this.displays;
  }

  getResolutions(): ResolutionInfo[] {
    return this.resolutions;
  }

  getPlatform(): string {
    return this.platform;
  }

  getImageQuality(): ImageQualityPreset {
    return this.imageQuality;
  }

  getCustomImageQuality(): number {
    return this.customImageQuality;
  }

  getCustomFps(): number {
    return this.customFps;
  }

  isAwaitingAction(): boolean {
    return this.awaitingAction;
  }

  private applyAction(response: ActionResponse): boolean {
    if (response.ok) {
      return true;
    }
    this.reportActionError(response);
    return false;
  }

  private isValidQuality(quality: string): boolean {
    return quality === 'best' || quality === 'balanced' || quality === 'low' || quality === 'custom';
  }

  private isValidCustomQuality(value: number): boolean {
    return Number.isFinite(value) && value >= 10 && value <= 2000;
  }

  private isValidCustomFps(value: number): boolean {
    return Number.isFinite(value) && value >= 5 && value <= 120;
  }
}
