import { SessionDefaults } from './RustDeskDirectoryTypes';
import { ResolutionInfo } from './RustDeskTypes';

export const RDP_RESOLUTION_CHOICES: string[] = [
  'follow', '1280x720', '1600x900', '1920x1080', '1920x1200', '2560x1440', '2560x1600',
];
export const RDP_SETTING_SCALE_CHOICES: number[] = [0, 100, 150, 200, 250];
const RDP_NATIVE_SCALE_CHOICES: number[] = [100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500];

function desktopSide(value: number): number {
  return Math.max(200, Math.min(8192, Number.isFinite(value) ? Math.floor(value) : 200));
}

export function computeRdpDesktopSize(paneWidthVp: number, paneHeightVp: number,
  pxPerVp: number, resolution: string = 'follow'): ResolutionInfo {
  let width = paneWidthVp * pxPerVp;
  let height = paneHeightVp * pxPerVp;
  if (resolution !== 'follow' && RDP_RESOLUTION_CHOICES.indexOf(resolution) >= 0) {
    const sides = resolution.split('x');
    width = Number(sides[0]);
    height = Number(sides[1]);
  }
  return { width: Math.floor(desktopSide(width) / 2) * 2, height: desktopSide(height) };
}

export function computeRdpScaleFactor(pxPerVp: number, setting: number = 0): number {
  const requested = setting > 0 ? setting : (Number.isFinite(pxPerVp) ? pxPerVp * 100 : 100);
  let closest = RDP_NATIVE_SCALE_CHOICES[0];
  for (const value of RDP_NATIVE_SCALE_CHOICES) {
    if (Math.abs(value - requested) < Math.abs(closest - requested)) {
      closest = value;
    }
  }
  return closest;
}

/** Only the opposite wire's default is rewritten; custom ports and IPv6 survive. */
export function swapDefaultDirectPort(target: string, nextMode: number): string {
  const otherPort = nextMode === 1 ? '3389' : (nextMode === 2 ? '5900' : '');
  if (otherPort.length === 0) {
    return target;
  }
  const value = target.trim();
  const match = /^(\[[^\]]+\]|[^:@/\s]+):(\d+)$/.exec(value);
  if (match === null || match[2] !== otherPort) {
    return target;
  }
  return `${match[1]}:${nextMode === 1 ? 5900 : 3389}`;
}

export function copySessionDefaults(source: SessionDefaults): SessionDefaults {
  const next = new SessionDefaults();
  next.touchMode = source.touchMode;
  next.relativeMouseMode = source.relativeMouseMode;
  next.inputEnabled = source.inputEnabled;
  next.rightClickGesture = source.rightClickGesture;
  next.audioEnabled = source.audioEnabled;
  next.clipboardEnabled = source.clipboardEnabled;
  next.refreshRate = source.refreshRate;
  next.preferredCodec = source.preferredCodec;
  next.gesturesEnabled = source.gesturesEnabled;
  next.toolbarExpanded = source.toolbarExpanded;
  next.sessionSharingEnabled = source.sessionSharingEnabled;
  next.rdpResolution = source.rdpResolution;
  next.rdpScaleFactor = source.rdpScaleFactor;
  next.rdpAudioEnabled = source.rdpAudioEnabled;
  next.vncQuality = source.vncQuality;
  return next;
}
