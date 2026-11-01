import { hilog } from '@kit.PerformanceAnalysisKit';

/** Generation-scoped SurfaceHolder event adapter, deliberately not an XComponentController. */
export class RustDeskSurfaceController {
  onCreated?: (surfaceId: string) => void;
  onChanged?: (surfaceId: string, rect: SurfaceRect) => void;
  onDestroyed?: (surfaceId: string) => void;
  onAttached?: () => void;
  onDetached?: () => void;
  private surfaceId: string = '';
  /**
   * The opaque native holder this instance adopted on attach, empty until one was
   * allocated. It belongs to the instance, not to the page, so a late callback
   * from an older node detaches exactly its own holder instead of the current one.
   */
  adoptedComponentId: string = '';

  // These callbacks retain their generation even after the page replaces its adapter.
  readonly handleNodeAttach: () => void = (): void => this.onAttached?.();
  readonly handleNodeDetach: () => void = (): void => this.onDetached?.();
  readonly handleNativeSurfaceEvent: (raw: string) => void = (raw: string): void => {
    try {
      const event: ESObject = JSON.parse(raw);
      const surfaceId = String(event.surfaceId ?? '');
      const kind = String(event.event ?? '');
      if (surfaceId.length === 0) {
        return;
      }
      if (kind === 'created' || kind === 'changed') {
        if (this.surfaceId !== surfaceId) {
          if (this.surfaceId.length > 0) {
            this.onDestroyed?.(this.surfaceId);
          }
          this.surfaceId = surfaceId;
          this.onCreated?.(surfaceId);
        }
        if (kind === 'changed') {
          const rect: SurfaceRect = {
            offsetX: 0, offsetY: 0,
            surfaceWidth: Number(event.width), surfaceHeight: Number(event.height)
          };
          this.onChanged?.(surfaceId, rect);
        }
      } else if (kind === 'destroyed' && this.surfaceId === surfaceId) {
        this.surfaceId = '';
        this.onDestroyed?.(surfaceId);
      }
      hilog.info(0xFF01, 'RustDeskSurface', 'holder_event=%{public}s', raw);
    } catch (error) {
      hilog.error(0xFF01, 'RustDeskSurface', 'holder event failed: %{public}s', String(error));
    }
  };

  getSurfaceId(): string {
    return this.surfaceId;
  }
}
