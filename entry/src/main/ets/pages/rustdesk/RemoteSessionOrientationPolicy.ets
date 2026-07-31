export enum RemoteSessionOrientationMode {
  FOLLOW_DESKTOP = 'follow_desktop',
  PORTRAIT = 'portrait',
  LANDSCAPE = 'landscape',
}

export class RemoteSessionOrientationPolicy {
  static resolve(deviceType: string, remoteWidth: number, remoteHeight: number): RemoteSessionOrientationMode {
    if (!Number.isFinite(remoteWidth) || !Number.isFinite(remoteHeight)
      || remoteWidth <= 0 || remoteHeight <= 0) {
      return RemoteSessionOrientationMode.FOLLOW_DESKTOP;
    }
    const normalizedDeviceType = deviceType.trim().toLowerCase();
    if (normalizedDeviceType === 'tablet') {
      return RemoteSessionOrientationMode.FOLLOW_DESKTOP;
    }
    if (normalizedDeviceType === '2in1') {
      return RemoteSessionOrientationMode.LANDSCAPE;
    }
    if (normalizedDeviceType === 'phone') {
      return remoteHeight > remoteWidth
        ? RemoteSessionOrientationMode.PORTRAIT
        : RemoteSessionOrientationMode.LANDSCAPE;
    }
    return RemoteSessionOrientationMode.FOLLOW_DESKTOP;
  }
}
