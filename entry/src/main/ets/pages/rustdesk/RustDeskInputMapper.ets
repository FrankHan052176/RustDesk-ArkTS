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
  /**
   * The rectangle the current presentation clips the picture to, in pane
   * coordinates.
   *
   * The native Surface's enclosing container is measured at the picture's own
   * rectangle and clips the transformed picture to it. Hit testing follows that
   * visible clip.
   */
  clipRect: RustDeskRect;
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
    clipRect?: RustDeskRect,
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
    this.clipRect = clipRect ?? paintRect;
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

export interface RustDeskInputBinding {
  sessionId: string;
  inputGeneration: number;
}

export function validInputGeneration(value: number | undefined): boolean {
  return value !== undefined && Number.isSafeInteger(value) && value >= 1;
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
    // HarmonyOS reports NumLock as keyCode 2102, but the engine's key vocabulary
    // has no NumLock name (see `control_key`/`plain_key` in the NAPI layer), so
    // mapping it here would make every press fail with "does not support key
    // name". It is left unmapped instead of being forwarded under a name the
    // peer cannot receive.
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

// X11 keysym definitions used by RFB, not Harmony key codes or RustDesk wire bits.
export function unicodeKeysym(codePoint: number): number | undefined {
  if (!Number.isInteger(codePoint) || codePoint < 1 || codePoint > 0x10FFFF
    || (codePoint >= 0xD800 && codePoint <= 0xDFFF)) {
    return undefined;
  }
  return codePoint <= 0xFF ? codePoint : 0x01000000 + codePoint;
}

export function mapLegacyKeyToKeysym(name: string): number | undefined {
  if (/^VK_F([1-9]|1[0-2])$/.test(name)) {
    return 0xFFBE + Number(name.substring(4)) - 1;
  }
  if (/^VK_NUMPAD[0-9]$/.test(name)) {
    return 0xFFB0 + Number(name.substring(9));
  }
  if (/^VK_[A-Z0-9]$/.test(name)) {
    return name.substring(3).toLowerCase().charCodeAt(0);
  }
  if (name.length === 1) {
    return unicodeKeysym(name.charCodeAt(0));
  }
  if (name.length === 2) {
    const high = name.charCodeAt(0);
    const low = name.charCodeAt(1);
    if (high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF) {
      return unicodeKeysym(0x10000 + (high - 0xD800) * 0x400 + low - 0xDC00);
    }
  }
  switch (name) {
    case 'VK_BACK': return 0xFF08;
    case 'VK_TAB': return 0xFF09;
    case 'VK_CLEAR': return 0xFF0B;
    case 'VK_ENTER':
    case 'VK_RETURN': return 0xFF0D;
    case 'VK_PAUSE': return 0xFF13;
    case 'VK_SCROLL': return 0xFF14;
    case 'VK_ESCAPE': return 0xFF1B;
    case 'VK_SPACE': return 0x20;
    case 'VK_HOME': return 0xFF50;
    case 'VK_LEFT': return 0xFF51;
    case 'VK_UP': return 0xFF52;
    case 'VK_RIGHT': return 0xFF53;
    case 'VK_DOWN': return 0xFF54;
    case 'VK_PRIOR': return 0xFF55;
    case 'VK_NEXT': return 0xFF56;
    case 'VK_END': return 0xFF57;
    case 'VK_SNAPSHOT': return 0xFF61;
    case 'VK_INSERT': return 0xFF63;
    case 'Apps': return 0xFF67;
    case 'VK_CANCEL': return 0xFF69;
    case 'VK_DELETE': return 0xFFFF;
    case 'VK_NUMLOCK': return 0xFF7F;
    case 'VK_MULTIPLY': return 0xFFAA;
    case 'VK_ADD': return 0xFFAB;
    case 'VK_SUBTRACT': return 0xFFAD;
    case 'VK_DECIMAL': return 0xFFAE;
    case 'VK_DIVIDE': return 0xFFAF;
    case 'VK_SHIFT': return 0xFFE1;
    case 'RShift': return 0xFFE2;
    case 'VK_CONTROL': return 0xFFE3;
    case 'RControl': return 0xFFE4;
    case 'VK_CAPITAL': return 0xFFE5;
    case 'VK_MENU': return 0xFFE9;
    case 'RAlt': return 0xFFEA;
    case 'Meta': return 0xFFEB;
    case 'RWin': return 0xFFEC;
    default: return undefined;
  }
}

export function mapHarmonyKeyCodeToKeysym(keyCode: number): number | undefined {
  if (keyCode === 2102) {
    return 0xFF7F;
  }
  if (keyCode === 2119) {
    return 0xFF8D;
  }
  const mapping = mapHarmonyKeyCode(keyCode);
  return mapping === undefined ? undefined : mapLegacyKeyToKeysym(mapping.name);
}

/** The last item is the tapped key; preceding items are temporary modifiers. */
export function vncKeyChord(payload: RustDeskKeyPayload): Array<number> | undefined {
  const key = payload.name === 'CTRL_ALT_DEL' ? 0xFFFF
    : (payload.name === 'LOCK_SCREEN' ? 0x6C : mapLegacyKeyToKeysym(payload.name));
  if (key === undefined) {
    return undefined;
  }
  const chord: number[] = [];
  if ((payload.ctrl || payload.name === 'CTRL_ALT_DEL') && key !== 0xFFE3 && key !== 0xFFE4) {
    chord.push(0xFFE3);
  }
  if ((payload.alt || payload.name === 'CTRL_ALT_DEL') && key !== 0xFFE9 && key !== 0xFFEA) {
    chord.push(0xFFE9);
  }
  if (payload.shift && key !== 0xFFE1 && key !== 0xFFE2) {
    chord.push(0xFFE1);
  }
  if ((payload.command || payload.name === 'LOCK_SCREEN') && key !== 0xFFEB && key !== 0xFFEC) {
    chord.push(0xFFEB);
  }
  chord.push(key);
  return chord;
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

/**
 * @param presentedRect the rectangle the presented picture really occupies in the
 * pane, when the caller knows it. The fit rect is only right while the picture is
 * fitted: a stretched picture fills the pane and a picture shown at its own pixel
 * size may exceed it, so normalizing against the fit rect would offset every point
 * in those modes. A caller that presents in a known rectangle passes it here.
 * @param clipRect the rectangle the presentation clips the picture to, when it is
 * not the picture's own rectangle.
 */
export function resolveCoordinateSpace(
  viewWidth: number,
  viewHeight: number,
  remoteRect: RustDeskRect,
  rotation: number,
  presentedRect?: RustDeskRect,
  clipRect?: RustDeskRect,
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
    presentedRect ?? transform.contentRect,
    transform.renderSize,
    rotation,
    clipRect,
  );
}

/**
 * Whether a pane point is on the presented picture.
 *
 * Two things must hold. The picture is rendered inside a clip the presentation owns
 * — the mode's rectangle for the native Surface — and a point outside that clip
 * is not on the picture however the inverse
 * transform maps it: at a zoom-in the transformed picture reaches past the clip, and
 * a click on the letterbox beside it must not reach the peer. Inside the clip, the
 * point is mapped back through the user transform and must land on the picture
 * itself, which is what excludes the empty margin of a zoomed-out or panned picture.
 */
export function isLocalPointInsidePaintRect(space: RustDeskCoordinateSpace, localX: number, localY: number): boolean {
  if (!isPointInsideRect(space.clipRect, localX, localY)) {
    return false;
  }
  const basePoint = mapViewPointToBase(space, localX, localY);
  return isPointInsideRect(space.paintRect, basePoint.x, basePoint.y);
}

function isPointInsideRect(rect: RustDeskRect, x: number, y: number): boolean {
  return x >= rect.left && x <= rect.left + rect.width
    && y >= rect.top && y <= rect.top + rect.height;
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
