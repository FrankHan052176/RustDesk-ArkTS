export class RustDeskSurfaceController extends XComponentController {
  onCreated?: (surfaceId: string) => void;
  onChanged?: (surfaceId: string, rect: SurfaceRect) => void;
  onDestroyed?: (surfaceId: string) => void;

  onSurfaceCreated(surfaceId: string): void {
    this.onCreated?.(surfaceId);
  }

  onSurfaceChanged(surfaceId: string, rect: SurfaceRect): void {
    this.onChanged?.(surfaceId, rect);
  }

  onSurfaceDestroyed(surfaceId: string): void {
    this.onDestroyed?.(surfaceId);
  }
}
