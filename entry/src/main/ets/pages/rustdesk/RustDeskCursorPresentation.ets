import { LocalPointerPosition, RemotePointerPosition } from './RustDeskInputMapper';
import { PeerDisplayInfo } from './RustDeskTypes';

export type RustDeskCursorSource = 'local' | 'remote';

/**
 * Input's virtual cursor is already display-local. Protocol cursor_position is
 * desktop-global: subtract the selected display origin exactly once, before
 * mapping through RustDeskViewportModel. A cursor on another display is absent,
 * not clamped to this display's edge. `source` is the latest position producer,
 * not the selected artwork: peer artwork can follow our own input position
 * without manufacturing a remotePosition sample or claiming a peer ACK.
 */
export function resolveCursorPosition(
  source: RustDeskCursorSource,
  localPosition: RemotePointerPosition | undefined,
  remotePosition: RemotePointerPosition | undefined,
  display: PeerDisplayInfo | undefined,
): RemotePointerPosition | undefined {
  if (source === 'local') {
    return localPosition;
  }
  if (remotePosition === undefined || display === undefined) {
    return undefined;
  }
  const x = remotePosition.x - display.x;
  const y = remotePosition.y - display.y;
  return x >= 0 && y >= 0 && x < display.width && y < display.height ? { x, y } : undefined;
}

/** Bitmap hotx/hoty and the fallback path's tip (1,1) use the same visual scale. */
export function cursorOverlayOrigin(
  anchorX: number,
  anchorY: number,
  hotX: number,
  hotY: number,
  visualScale: number,
): LocalPointerPosition {
  return {
    x: anchorX - hotX * visualScale,
    y: anchorY - hotY * visualScale,
  };
}
