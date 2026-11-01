import { NativeSessionBridge } from './NativeSessionBridge';
import { RustDeskViewportModel } from './RustDeskViewportModel';
import { ActionResponse, NativeEvent, PeerDisplayInfo, ResolutionInfo } from './RustDeskTypes';

import {
  DEFAULT_REFRESH_RATE,
  MAX_REFRESH_RATE,
  MIN_REFRESH_RATE,
  isValidRefreshRate,
} from './RustDeskRefreshRate';

export { DEFAULT_REFRESH_RATE, MAX_REFRESH_RATE, MIN_REFRESH_RATE, isValidRefreshRate };

/** Direct refusal fields are strings; a late refusal must not clear a newer pending size. */
export function matchesResolutionRefusal(event: NativeEvent, display: number, width: number, height: number): boolean {
  return event.name === 'resolution_refused' && display >= 0 && width > 0 && height > 0
    && Number(event.display ?? -1) === display && Number(event.width ?? '0') === width
    && Number(event.height ?? '0') === height;
}

export class SessionDisplayController {
  private readonly viewport: RustDeskViewportModel;
  private readonly bridge: NativeSessionBridge;
  private readonly invalidateFrames: () => void;
  private readonly reportActionError: (response: ActionResponse) => void;
  private displays: PeerDisplayInfo[] = [];
  private resolutions: ResolutionInfo[] = [];
  private platform: string = '';
  private refreshRate: number = DEFAULT_REFRESH_RATE;
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
    resolutions: ResolutionInfo[] | undefined,
    platform: string,
  ): void {
    this.displays = displays;
    if (resolutions !== undefined) {
      this.resolutions = resolutions;
    }
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

  /**
   * Ask the peer for a capture rate.
   *
   * The rate is the only picture control the operator sets. Encoding quality is
   * deliberately not offered: a quality level makes the app guess at a bandwidth
   * the session cannot see, whereas a rate leaves the encoder free to spend
   * whatever the path currently sustains.
   */
  applyRefreshRate(sessionId: string, refreshRate: number): boolean {
    if (!this.isValidRefreshRate(refreshRate)) {
      return false;
    }
    this.awaitingAction = true;
    try {
      if (!this.applyAction(this.bridge.setCustomFps(sessionId, Math.round(refreshRate)))) {
        return false;
      }
      this.refreshRate = Math.round(refreshRate);
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

  getRefreshRate(): number {
    return this.refreshRate;
  }

  restoreRefreshRate(refreshRate: number): void {
    this.refreshRate = this.isValidRefreshRate(refreshRate) ? Math.round(refreshRate) : DEFAULT_REFRESH_RATE;
  }

  private isValidRefreshRate(value: number): boolean {
    return isValidRefreshRate(value);
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

}
