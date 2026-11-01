import { RustDeskMousePayload } from './RustDeskInputMapper';

export interface RustDeskMouseSink {
  sessionSendMouseEvent(sessionId: string, eventKind: number, button: number,
    x: number, y: number, relativeMarker: number): boolean;
}

// These are bridge command codes; RustDesk wire bit packing belongs to Core.
function mouseEventKind(type: string | undefined): number {
  switch (type) {
    case 'down': return 1;
    case 'up': return 2;
    case 'wheel': return 3;
    case 'trackpad': return 4;
    case 'move_relative': return 5;
    default: return 0;
  }
}

function mouseButtonCode(button: string | undefined): number {
  switch (button) {
    case 'left': return 1;
    case 'right': return 2;
    case 'wheel': return 3;
    case 'back': return 4;
    case 'forward': return 5;
    default: return 0;
  }
}

export function sendNativeMouse(api: RustDeskMouseSink, sessionId: string,
  payload: RustDeskMousePayload): boolean {
  const x = payload.x === undefined ? 0 : Number(payload.x);
  const y = payload.y === undefined ? 0 : Number(payload.y);
  // Core's legacy JSON entry point treated omitted coordinates as zero. Keep
  // that established contract for the compact NAPI path as well.
  if ((!Number.isInteger(x) || x < -2147483648 || x > 2147483647)
    || (!Number.isInteger(y) || y < -2147483648 || y > 2147483647)) {
    return false;
  }
  let marker = -1;
  if (payload.relative_mouse_mode !== undefined) {
    marker = payload.relative_mouse_mode === '1' || payload.relative_mouse_mode === 'Y' ||
      payload.relative_mouse_mode === 'on' ? 1 : 0;
    // Preserve the legacy enable-marker rule: even an empty buttons property
    // is forbidden, because markers must never become a real button event.
    if (marker === 1 && payload.buttons !== undefined) {
      return false;
    }
  }
  return api.sessionSendMouseEvent(sessionId, mouseEventKind(payload.type), mouseButtonCode(payload.buttons),
    x, y, marker);
}
