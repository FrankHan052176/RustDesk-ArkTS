export enum RemoteSessionOrientationMode {
  FOLLOW_DESKTOP = 'follow_desktop',
  LOCKED = 'locked',
  PORTRAIT = 'portrait',
  LANDSCAPE = 'landscape',
  PORTRAIT_INVERTED = 'portrait_inverted',
  LANDSCAPE_INVERTED = 'landscape_inverted',
}

export class RemoteSessionOrientationPolicy {
  static offersKeepScreenOrientation(deviceType: string): boolean {
    const type = deviceType.trim().toLowerCase();
    return type === 'phone' || type === 'tablet';
  }

  /** Initial session direction; later geometry changes must not reapply it. */
  static resolve(deviceType: string, remoteWidth: number, remoteHeight: number,
    keepScreenOrientation: boolean = false): RemoteSessionOrientationMode {
    const type = deviceType.trim().toLowerCase();
    if (type === 'tablet' || (type === 'phone' && keepScreenOrientation)) {
      return RemoteSessionOrientationMode.LOCKED;
    }
    if (type === '2in1') {
      return RemoteSessionOrientationMode.LANDSCAPE;
    }
    if (type === 'phone') {
      if (!Number.isFinite(remoteWidth) || !Number.isFinite(remoteHeight)
        || remoteWidth <= 0 || remoteHeight <= 0) {
        return RemoteSessionOrientationMode.LOCKED;
      }
      return remoteHeight > remoteWidth
        ? RemoteSessionOrientationMode.PORTRAIT
        : RemoteSessionOrientationMode.LANDSCAPE;
    }
    return RemoteSessionOrientationMode.FOLLOW_DESKTOP;
  }

  /** Positive 90 degrees, clockwise, including the two inverted directions. */
  static rotateClockwise(mode: RemoteSessionOrientationMode): RemoteSessionOrientationMode {
    switch (mode) {
      case RemoteSessionOrientationMode.PORTRAIT: return RemoteSessionOrientationMode.LANDSCAPE_INVERTED;
      case RemoteSessionOrientationMode.LANDSCAPE_INVERTED: return RemoteSessionOrientationMode.PORTRAIT_INVERTED;
      case RemoteSessionOrientationMode.PORTRAIT_INVERTED: return RemoteSessionOrientationMode.LANDSCAPE;
      default: return RemoteSessionOrientationMode.PORTRAIT;
    }
  }

  static fromGravity(x: number, y: number): RemoteSessionOrientationMode | undefined {
    // A flat device has no well-defined in-plane direction.
    if (!Number.isFinite(x) || !Number.isFinite(y) || Math.hypot(x, y) < 3) {
      return undefined;
    }
    if (Math.abs(x) > Math.abs(y)) {
      return x > 0 ? RemoteSessionOrientationMode.LANDSCAPE : RemoteSessionOrientationMode.LANDSCAPE_INVERTED;
    }
    return y > 0 ? RemoteSessionOrientationMode.PORTRAIT : RemoteSessionOrientationMode.PORTRAIT_INVERTED;
  }
}
