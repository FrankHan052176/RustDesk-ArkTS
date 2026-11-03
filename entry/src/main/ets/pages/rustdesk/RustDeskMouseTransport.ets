import { RustDeskMousePayload, validInputGeneration } from './RustDeskInputMapper';
import { ActionResponse } from './RustDeskTypes';

export interface RustDeskMouseSink {
  sessionSendMouse(sessionId: string, canonicalJson: string, inputGeneration: number): string;
}

class CanonicalMouseEvent {
  kind: number = 0;
  button: number = 0;
  x?: number;
  y?: number;
}

function mouseEventKind(type: string | undefined): number | undefined {
  switch (type) {
    case undefined:
    case 'move': return 0;
    case 'down': return 1;
    case 'up': return 2;
    case 'wheel': return 3;
    case 'trackpad': return 4;
    case 'move_relative': return 5;
    default: return undefined;
  }
}

function mouseButtonCode(button: string | undefined): number | undefined {
  switch (button) {
    case undefined: return 0;
    case 'left': return 1;
    case 'right': return 2;
    case 'wheel': return 3;
    case 'back': return 4;
    case 'forward': return 5;
    default: return undefined;
  }
}

function coordinate(value: string | undefined): number | undefined {
  if (value === undefined || value.trim().length === 0) {
    return undefined;
  }
  const number = Number(value);
  return Number.isInteger(number) && number >= -2147483648 && number <= 2147483647
    ? number : undefined;
}

function refused(message: string): ActionResponse {
  return { ok: false, action: 'session_send_mouse', message };
}

/**
 * The only pointer transport. The mapper's absolute positions include the display
 * origin for cursor overlays; NAPI takes display-local pixels and adds its own
 * authoritative origin. An omitted button position stays omitted, never (0, 0).
 */
export function sendNativeMouse(api: RustDeskMouseSink, sessionId: string,
  payload: RustDeskMousePayload, inputGeneration: number,
  displayOriginX: number = 0, displayOriginY: number = 0): ActionResponse {
  if (!validInputGeneration(inputGeneration)) {
    return refused('尚未取得有效的输入代际');
  }
  const kind = mouseEventKind(payload.type);
  const button = mouseButtonCode(payload.buttons);
  if (kind === undefined || button === undefined || (kind === 1 || kind === 2 ? button === 0 : button !== 0)) {
    return refused('不支持的鼠标事件或按键');
  }
  const event = new CanonicalMouseEvent();
  event.kind = kind;
  event.button = button;
  const x = coordinate(payload.x);
  const y = coordinate(payload.y);
  if ((payload.x !== undefined && x === undefined) || (payload.y !== undefined && y === undefined)) {
    return refused('鼠标坐标必须为 32 位整数');
  }
  if (kind <= 2) {
    if ((x === undefined) !== (y === undefined) || (kind === 0 && x === undefined)) {
      return refused('绝对移动需要完整坐标');
    }
    if (x !== undefined && y !== undefined) {
      const localX = x - displayOriginX;
      const localY = y - displayOriginY;
      if (!Number.isInteger(localX) || !Number.isInteger(localY)
        || localX < 0 || localY < 0 || localX > 2147483647 || localY > 2147483647) {
        return refused('鼠标坐标不在当前显示器内');
      }
      event.x = localX;
      event.y = localY;
    }
  } else {
    event.x = x ?? 0;
    event.y = y ?? 0;
  }
  try {
    return JSON.parse(api.sessionSendMouse(sessionId, JSON.stringify(event), inputGeneration)) as ActionResponse;
  } catch (_) {
    return refused('原生鼠标输入未返回有效回执');
  }
}
