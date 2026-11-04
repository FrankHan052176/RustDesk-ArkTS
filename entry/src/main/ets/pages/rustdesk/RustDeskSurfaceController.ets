import { FrameNode, NodeController, typeNode, UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Generation-scoped typed XComponent and SurfaceHolder event adapter. */
export class RustDeskSurfaceController extends NodeController {
  onCreated?: (surfaceId: string) => void;
  onChanged?: (surfaceId: string, rect: SurfaceRect) => void;
  onDestroyed?: (surfaceId: string) => void;
  onNodeReady?: (frameNode: FrameNode) => boolean;
  onDetached?: () => void;
  private surfaceId: string = '';
  private frameNode?: FrameNode;
  /**
   * The opaque native holder this instance adopted on attach, empty until one was
   * allocated. It belongs to the instance, not to the page, so a late callback
   * from an older node detaches exactly its own holder instead of the current one.
   */
  adoptedComponentId: string = '';

  makeNode(uiContext: UIContext): FrameNode | null {
    if (this.frameNode === undefined) {
      // No constructor id/controller: this selects the native-lifecycle TYPE_NODE.
      const parameters: NativeXComponentParameters = { type: XComponentType.SURFACE };
      const node = typeNode.createNode(uiContext, 'XComponent', parameters);
      node.commonAttribute.width('100%').height('100%');
      this.frameNode = node;
    }
    // Adopt and disable automatic lifecycle before NodeContainer mounts this node.
    return this.onNodeReady?.(this.frameNode) === true ? this.frameNode : null;
  }

  onDetach(): void {
    // Unmount is not a release receipt. Native retains the FrameNode while held;
    // never dispose it here or bypass the existing close/join/ACK + detach owner.
    this.onDetached?.();
  }

  // This callback retains its generation even after the page replaces its adapter.
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
