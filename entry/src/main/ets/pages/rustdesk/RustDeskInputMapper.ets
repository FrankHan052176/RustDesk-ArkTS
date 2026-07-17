export type RustDeskModifierKey = 'alt' | 'ctrl' | 'shift' | 'command';

export interface RustDeskKeyMapping {
  name: string;
  modifier?: RustDeskModifierKey;
}

export interface RemotePointerPosition {
  x: number;
  y: number;
}

export interface LocalPointerPosition {
  x: number;
  y: number;
}

export class RustDeskRect {
  left: number;
  top: number;
  width: number;
  height: number;

  constructor(left: number, top: number, width: number, height: number) {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }
}

export class RustDeskSize {
  width: number;
  height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

export class RustDeskPreviewTransform {
  contentRect: RustDeskRect;
  renderSize: RustDeskSize;

  constructor(contentRect: RustDeskRect, renderSize: RustDeskSize) {
    this.contentRect = contentRect;
    this.renderSize = renderSize;
  }
}

export class RustDeskCoordinateSpace {
  remoteRect: RustDeskRect;
  viewSize: RustDeskSize;
  paintRect: RustDeskRect;
  renderSize: RustDeskSize;
  rotation: number;
  viewScale: number;
  viewOffsetX: number;
  viewOffsetY: number;
  viewRotation: number;

  constructor(
    remoteRect: RustDeskRect,
    viewSize: RustDeskSize,
    paintRect: RustDeskRect,
    renderSize: RustDeskSize,
    rotation: number,
    viewScale: number = 1,
    viewOffsetX: number = 0,
    viewOffsetY: number = 0,
    viewRotation: number = 0,
  ) {
    this.remoteRect = remoteRect;
    this.viewSize = viewSize;
    this.paintRect = paintRect;
    this.renderSize = renderSize;
    this.rotation = rotation;
    this.viewScale = viewScale;
    this.viewOffsetX = viewOffsetX;
    this.viewOffsetY = viewOffsetY;
    this.viewRotation = viewRotation;
  }
}

export class RustDeskMousePayload {
  type?: string;
  buttons?: string;
  x?: string;
  y?: string;
  relative_mouse_mode?: string;
}

export class RustDeskKeyPayload {
  name: string;
  down: boolean;
  press: boolean;
  alt: boolean = false;
  ctrl: boolean = false;
  shift: boolean = false;
  command: boolean = false;

  constructor(name: string, down: boolean) {
    this.name = name;
    this.down = down;
    this.press = false;
  }
}

export class RustDeskFlutterKeyPayload {
  character: string;
  usb_hid: number;
  lock_modes: number;
  down_or_up: boolean;

  constructor(character: string, usbHid: number, lockModes: number, downOrUp: boolean) {
    this.character = character;
    this.usb_hid = usbHid;
    this.lock_modes = lockModes;
    this.down_or_up = downOrUp;
  }
}

const KEYCODE_0 = 2000;
const KEYCODE_9 = 2009;
const KEYCODE_A = 2017;
const KEYCODE_Z = 2042;
const KEYCODE_F1 = 2090;
const KEYCODE_F12 = 2101;
const KEYCODE_NUMPAD0 = 2103;
const KEYCODE_NUMPAD9 = 2112;

function printableFromCode(keyCode: number): string | undefined {
  if (keyCode >= KEYCODE_0 && keyCode <= KEYCODE_9) {
    return String.fromCharCode('0'.charCodeAt(0) + keyCode - KEYCODE_0);
  }
  if (keyCode >= KEYCODE_A && keyCode <= KEYCODE_Z) {
    return String.fromCharCode('a'.charCodeAt(0) + keyCode - KEYCODE_A);
  }
  if (keyCode >= KEYCODE_F1 && keyCode <= KEYCODE_F12) {
    return `VK_F${keyCode - KEYCODE_F1 + 1}`;
  }
  if (keyCode >= KEYCODE_NUMPAD0 && keyCode <= KEYCODE_NUMPAD9) {
    return `VK_NUMPAD${keyCode - KEYCODE_NUMPAD0}`;
  }
  return undefined;
}

export function mapHarmonyKeyCode(keyCode: number): RustDeskKeyMapping | undefined {
  const printable = printableFromCode(keyCode);
  if (printable) {
    return { name: printable };
  }

  switch (keyCode) {
    case 2012:
      return { name: 'VK_UP' };
    case 2013:
      return { name: 'VK_DOWN' };
    case 2014:
      return { name: 'VK_LEFT' };
    case 2015:
      return { name: 'VK_RIGHT' };
    case 2016:
      return { name: 'VK_RETURN' };
    case 2043:
      return { name: ',' };
    case 2044:
      return { name: '.' };
    case 2045:
      return { name: 'VK_MENU', modifier: 'alt' };
    case 2046:
      return { name: 'RAlt', modifier: 'alt' };
    case 2047:
      return { name: 'VK_SHIFT', modifier: 'shift' };
    case 2048:
      return { name: 'RShift', modifier: 'shift' };
    case 2049:
      return { name: 'VK_TAB' };
    case 2050:
      return { name: 'VK_SPACE' };
    case 2054:
      return { name: 'VK_RETURN' };
    case 2055:
      return { name: 'VK_BACK' };
    case 2056:
      return { name: '`' };
    case 2057:
      return { name: '-' };
    case 2058:
      return { name: '=' };
    case 2059:
      return { name: '[' };
    case 2060:
      return { name: ']' };
    case 2061:
      return { name: '\\' };
    case 2062:
      return { name: ';' };
    case 2063:
      return { name: '\'' };
    case 2064:
      return { name: '/' };
    case 2066:
      return { name: '+' };
    case 2067:
      return { name: 'Apps' };
    case 2068:
      return { name: 'VK_PRIOR' };
    case 2069:
      return { name: 'VK_NEXT' };
    case 2070:
      return { name: 'VK_ESCAPE' };
    case 2071:
      return { name: 'VK_DELETE' };
    case 2072:
      return { name: 'VK_CONTROL', modifier: 'ctrl' };
    case 2073:
      return { name: 'RControl', modifier: 'ctrl' };
    case 2074:
      return { name: 'VK_CAPITAL' };
    case 2075:
      return { name: 'VK_SCROLL' };
    case 2076:
      return { name: 'Meta', modifier: 'command' };
    case 2077:
      return { name: 'RWin', modifier: 'command' };
    case 2079:
      return { name: 'VK_SNAPSHOT' };
    case 2080:
      return { name: 'VK_PAUSE' };
    case 2081:
      return { name: 'VK_HOME' };
    case 2082:
      return { name: 'VK_END' };
    case 2083:
      return { name: 'VK_INSERT' };
    case 2102:
      return { name: 'VK_NUMLOCK' };
    case 2113:
      return { name: 'VK_DIVIDE' };
    case 2114:
      return { name: 'VK_MULTIPLY' };
    case 2115:
      return { name: 'VK_SUBTRACT' };
    case 2116:
      return { name: 'VK_ADD' };
    case 2117:
      return { name: 'VK_DECIMAL' };
    case 2119:
      return { name: 'VK_RETURN' };
    default:
      return undefined;
  }
}

export function mapHarmonyKeyCodeToUsbHid(keyCode: number): number | undefined {
  if (keyCode >= KEYCODE_A && keyCode <= KEYCODE_Z) {
    return 0x04 + keyCode - KEYCODE_A;
  }
  if (keyCode >= 2001 && keyCode <= KEYCODE_9) {
    return 0x1E + keyCode - 2001;
  }
  if (keyCode === KEYCODE_0) {
    return 0x27;
  }
  if (keyCode >= KEYCODE_F1 && keyCode <= KEYCODE_F12) {
    return 0x3A + keyCode - KEYCODE_F1;
  }
  if (keyCode === KEYCODE_NUMPAD0) {
    return 0x62;
  }
  if (keyCode >= KEYCODE_NUMPAD0 + 1 && keyCode <= KEYCODE_NUMPAD9) {
    return 0x59 + keyCode - (KEYCODE_NUMPAD0 + 1);
  }

  switch (keyCode) {
    case 2012:
      return 0x52;
    case 2013:
      return 0x51;
    case 2014:
      return 0x50;
    case 2015:
      return 0x4F;
    case 2016:
      return 0x28;
    case 2043:
      return 0x36;
    case 2044:
      return 0x37;
    case 2045:
      return 0xE2;
    case 2046:
      return 0xE6;
    case 2047:
      return 0xE1;
    case 2048:
      return 0xE5;
    case 2049:
      return 0x2B;
    case 2050:
      return 0x2C;
    case 2054:
      return 0x28;
    case 2055:
      return 0x2A;
    case 2056:
      return 0x35;
    case 2057:
      return 0x2D;
    case 2058:
      return 0x2E;
    case 2059:
      return 0x2F;
    case 2060:
      return 0x30;
    case 2061:
      return 0x31;
    case 2062:
      return 0x33;
    case 2063:
      return 0x34;
    case 2064:
      return 0x38;
    case 2066:
      return 0x2E;
    case 2068:
      return 0x4B;
    case 2069:
      return 0x4E;
    case 2070:
      return 0x29;
    case 2071:
      return 0x4C;
    case 2072:
      return 0xE0;
    case 2073:
      return 0xE4;
    case 2074:
      return 0x39;
    case 2075:
      return 0x47;
    case 2076:
      return 0xE3;
    case 2077:
      return 0xE7;
    case 2079:
      return 0x46;
    case 2080:
      return 0x48;
    case 2081:
      return 0x4A;
    case 2082:
      return 0x4D;
    case 2083:
      return 0x49;
    case 2102:
      return 0x53;
    case 2113:
      return 0x54;
    case 2114:
      return 0x55;
    case 2115:
      return 0x56;
    case 2116:
      return 0x57;
    case 2117:
      return 0x63;
    case 2119:
      return 0x58;
    default:
      return undefined;
  }
}

export function mapMouseButton(button: MouseButton): string | undefined {
  switch (button) {
    case MouseButton.Left:
      return 'left';
    case MouseButton.Right:
      return 'right';
    case MouseButton.Middle:
      return 'wheel';
    case MouseButton.Back:
      return 'back';
    case MouseButton.Forward:
      return 'forward';
    default:
      return undefined;
  }
}

function normalizeRotation(rotation: number): number {
  const normalized = rotation % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

export function resolvePreviewTransform(
  viewWidth: number,
  viewHeight: number,
  remoteWidth: number,
  remoteHeight: number,
  rotation: number,
): RustDeskPreviewTransform {
  const safeViewWidth = Math.max(viewWidth, 1);
  const safeViewHeight = Math.max(viewHeight, 1);
  const safeRemoteWidth = Math.max(remoteWidth, 1);
  const safeRemoteHeight = Math.max(remoteHeight, 1);
  const normalizedRotation = normalizeRotation(rotation);
  const rotatedWidth = normalizedRotation === 90 || normalizedRotation === 270
    ? safeRemoteHeight
    : safeRemoteWidth;
  const rotatedHeight = normalizedRotation === 90 || normalizedRotation === 270
    ? safeRemoteWidth
    : safeRemoteHeight;
  const scale = Math.min(safeViewWidth / rotatedWidth, safeViewHeight / rotatedHeight);
  const contentWidth = rotatedWidth * scale;
  const contentHeight = rotatedHeight * scale;
  const offsetX = (safeViewWidth - contentWidth) / 2;
  const offsetY = (safeViewHeight - contentHeight) / 2;
  const renderWidth = normalizedRotation === 90 || normalizedRotation === 270 ? contentHeight : contentWidth;
  const renderHeight = normalizedRotation === 90 || normalizedRotation === 270 ? contentWidth : contentHeight;
  return new RustDeskPreviewTransform(
    new RustDeskRect(offsetX, offsetY, contentWidth, contentHeight),
    new RustDeskSize(renderWidth, renderHeight),
  );
}

export function resolveCoordinateSpace(
  viewWidth: number,
  viewHeight: number,
  remoteRect: RustDeskRect,
  rotation: number,
): RustDeskCoordinateSpace {
  const viewSize = new RustDeskSize(Math.max(viewWidth, 1), Math.max(viewHeight, 1));
  const safeRemoteRect = new RustDeskRect(
    remoteRect.left,
    remoteRect.top,
    Math.max(remoteRect.width, 1),
    Math.max(remoteRect.height, 1),
  );
  const transform = resolvePreviewTransform(
    viewSize.width,
    viewSize.height,
    safeRemoteRect.width,
    safeRemoteRect.height,
    rotation,
  );
  return new RustDeskCoordinateSpace(
    safeRemoteRect,
    viewSize,
    transform.contentRect,
    transform.renderSize,
    rotation,
  );
}

export function isLocalPointInsidePaintRect(space: RustDeskCoordinateSpace, localX: number, localY: number): boolean {
  const basePoint = mapViewPointToBase(space, localX, localY);
  return basePoint.x >= space.paintRect.left
    && basePoint.x <= space.paintRect.left + space.paintRect.width
    && basePoint.y >= space.paintRect.top
    && basePoint.y <= space.paintRect.top + space.paintRect.height;
}

function clampToRange(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function remoteSpanEnd(start: number, size: number): number {
  return start + Math.max(size, 1) - 1;
}

function safeViewScale(space: RustDeskCoordinateSpace): number {
  return Number.isFinite(space.viewScale) && space.viewScale > 0 ? space.viewScale : 1;
}

function rotateVector(x: number, y: number, angle: number): LocalPointerPosition {
  const radians = angle * Math.PI / 180;
  const cosine = Math.cos(radians);
  const sine = Math.sin(radians);
  return {
    x: x * cosine - y * sine,
    y: x * sine + y * cosine,
  };
}

function mapViewPointToBase(
  space: RustDeskCoordinateSpace,
  localX: number,
  localY: number,
): LocalPointerPosition {
  const centerX = space.viewSize.width / 2;
  const centerY = space.viewSize.height / 2;
  const translatedX = localX - space.viewOffsetX - centerX;
  const translatedY = localY - space.viewOffsetY - centerY;
  const unrotated = rotateVector(translatedX, translatedY, -space.viewRotation);
  const scale = safeViewScale(space);
  return {
    x: centerX + unrotated.x / scale,
    y: centerY + unrotated.y / scale,
  };
}

function mapBasePointToView(
  space: RustDeskCoordinateSpace,
  localX: number,
  localY: number,
): LocalPointerPosition {
  const centerX = space.viewSize.width / 2;
  const centerY = space.viewSize.height / 2;
  const scale = safeViewScale(space);
  const rotated = rotateVector((localX - centerX) * scale, (localY - centerY) * scale, space.viewRotation);
  return {
    x: centerX + rotated.x + space.viewOffsetX,
    y: centerY + rotated.y + space.viewOffsetY,
  };
}

export function mapViewDeltaToBase(
  space: RustDeskCoordinateSpace,
  deltaX: number,
  deltaY: number,
): LocalPointerPosition {
  const unrotated = rotateVector(deltaX, deltaY, -space.viewRotation);
  const scale = safeViewScale(space);
  return {
    x: unrotated.x / scale,
    y: unrotated.y / scale,
  };
}

export function mapLocalToRemote(
  space: RustDeskCoordinateSpace,
  localX: number,
  localY: number,
): RemotePointerPosition {
  const basePoint = mapViewPointToBase(space, localX, localY);
  const normalizedPaintX = clampToRange(
    (basePoint.x - space.paintRect.left) / Math.max(space.paintRect.width, 1),
    0,
    1,
  );
  const normalizedPaintY = clampToRange(
    (basePoint.y - space.paintRect.top) / Math.max(space.paintRect.height, 1),
    0,
    1,
  );
  let normalizedRemoteX = normalizedPaintX;
  let normalizedRemoteY = normalizedPaintY;
  const normalizedRotation = normalizeRotation(space.rotation);
  switch (normalizedRotation) {
    case 90:
      normalizedRemoteX = normalizedPaintY;
      normalizedRemoteY = 1 - normalizedPaintX;
      break;
    case 180:
      normalizedRemoteX = 1 - normalizedPaintX;
      normalizedRemoteY = 1 - normalizedPaintY;
      break;
    case 270:
      normalizedRemoteX = 1 - normalizedPaintY;
      normalizedRemoteY = normalizedPaintX;
      break;
    default:
      break;
  }
  const minX = space.remoteRect.left;
  const minY = space.remoteRect.top;
  const maxX = remoteSpanEnd(minX, space.remoteRect.width);
  const maxY = remoteSpanEnd(minY, space.remoteRect.height);
  return {
    x: Math.round(clampToRange(minX + normalizedRemoteX * (maxX - minX), minX, maxX)),
    y: Math.round(clampToRange(minY + normalizedRemoteY * (maxY - minY), minY, maxY)),
  };
}

export function mapRemoteToLocal(
  space: RustDeskCoordinateSpace,
  remoteX: number,
  remoteY: number,
): LocalPointerPosition {
  const minX = space.remoteRect.left;
  const minY = space.remoteRect.top;
  const maxX = remoteSpanEnd(minX, space.remoteRect.width);
  const maxY = remoteSpanEnd(minY, space.remoteRect.height);
  const normalizedRemoteX = (remoteX - minX) / Math.max(maxX - minX, 1);
  const normalizedRemoteY = (remoteY - minY) / Math.max(maxY - minY, 1);
  let normalizedPaintX = normalizedRemoteX;
  let normalizedPaintY = normalizedRemoteY;
  const normalizedRotation = normalizeRotation(space.rotation);
  switch (normalizedRotation) {
    case 90:
      normalizedPaintX = 1 - normalizedRemoteY;
      normalizedPaintY = normalizedRemoteX;
      break;
    case 180:
      normalizedPaintX = 1 - normalizedRemoteX;
      normalizedPaintY = 1 - normalizedRemoteY;
      break;
    case 270:
      normalizedPaintX = normalizedRemoteY;
      normalizedPaintY = 1 - normalizedRemoteX;
      break;
    default:
      break;
  }
  const basePoint: LocalPointerPosition = {
    x: Math.round(space.paintRect.left + normalizedPaintX * space.paintRect.width),
    y: Math.round(space.paintRect.top + normalizedPaintY * space.paintRect.height),
  };
  const viewPoint = mapBasePointToView(space, basePoint.x, basePoint.y);
  return {
    x: Math.round(viewPoint.x),
    y: Math.round(viewPoint.y),
  };
}

export function mapRemoteDeltaToLocal(
  space: RustDeskCoordinateSpace,
  remoteDeltaX: number,
  remoteDeltaY: number,
): LocalPointerPosition {
  return {
    x: remoteDeltaX / Math.max(space.remoteRect.width, 1) * space.paintRect.width,
    y: remoteDeltaY / Math.max(space.remoteRect.height, 1) * space.paintRect.height,
  };
}
