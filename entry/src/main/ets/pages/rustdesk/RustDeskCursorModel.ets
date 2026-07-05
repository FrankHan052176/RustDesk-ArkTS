import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { NativeEvent } from './RustDeskTypes';

export interface RustDeskCursorBitmap {
  id: string;
  pixelMap: image.PixelMap;
  hotX: number;
  hotY: number;
  width: number;
  height: number;
}

export interface RustDeskCursorSnapshot {
  hasRemotePosition: boolean;
  remoteX: number;
  remoteY: number;
  remoteUpdatedAt: number;
  currentId: string;
  pixelMap?: image.PixelMap;
  bitmapWidth: number;
  bitmapHeight: number;
  hotX: number;
  hotY: number;
}

export class RustDeskCursorModel {
  private currentId: string = '-1';
  private remoteX: number = -10000;
  private remoteY: number = -10000;
  private remoteUpdatedAt: number = 0;
  private hasRemotePosition: boolean = false;
  private currentBitmap?: RustDeskCursorBitmap = undefined;
  private cache: Map<string, RustDeskCursorBitmap> = new Map();

  reset(): void {
    this.hasRemotePosition = false;
    this.remoteX = -10000;
    this.remoteY = -10000;
    this.remoteUpdatedAt = 0;
    this.currentId = '-1';
    this.currentBitmap = undefined;
    this.releaseCache();
  }

  updatePosition(remoteX: number, remoteY: number): void {
    this.remoteX = remoteX;
    this.remoteY = remoteY;
    this.remoteUpdatedAt = Date.now();
    this.hasRemotePosition = true;
  }

  updateCursorId(id: string): boolean {
    if (id.length === 0) {
      return false;
    }
    this.currentId = id;
    return this.applyCurrentBitmap();
  }

  updateCursorData(
    event: NativeEvent,
    log: (message: string) => void,
    onChanged: () => void,
  ): void {
    const id = String(event.id ?? '');
    const width = Number(event.width ?? '0');
    const height = Number(event.height ?? '0');
    const hotX = Number(event.hotx ?? '0');
    const hotY = Number(event.hoty ?? '0');
    if (id.length === 0 || width <= 0 || height <= 0 || !event.colors) {
      return;
    }
    // Flutter updates the last cursor id before decoding cursor_data, so data
    // without a separate cursor_id event still becomes the active cursor image.
    this.currentId = id;
    let colors: number[] = [];
    try {
      colors = JSON.parse(event.colors) as number[];
    } catch (error) {
      log(`parse_failed id=${id} error=${String(error)}`);
      return;
    }
    const expectedLength = width * height * 4;
    if (colors.length < expectedLength) {
      log(`bad_length id=${id} got=${colors.length} expected=${expectedLength}`);
      return;
    }
    const buffer = new ArrayBuffer(expectedLength);
    const rgba = new Uint8Array(buffer);
    for (let index = 0; index < expectedLength; index++) {
      rgba[index] = Number(colors[index]) & 0xFF;
    }
    const options: image.InitializationOptions = {
      editable: false,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      size: { width, height },
      alphaType: image.AlphaType.UNPREMUL,
    };
    image.createPixelMap(buffer, options)
      .then((pixelMap: image.PixelMap) => {
        const previous = this.cache.get(id);
        const cursor: RustDeskCursorBitmap = {
          id,
          pixelMap,
          hotX,
          hotY,
          width,
          height,
        };
        this.cache.set(id, cursor);
        if (this.currentId === id) {
          this.currentBitmap = cursor;
        }
        if (previous && previous !== this.currentBitmap) {
          previous.pixelMap.release().catch((_error: BusinessError) => {});
        }
        log(`id=${id} size=${width}x${height} hot=(${hotX},${hotY})`);
        onChanged();
      })
      .catch((error: BusinessError) => {
        log(`create_failed id=${id} error=${JSON.stringify(error) ?? String(error)}`);
      });
  }

  getSnapshot(): RustDeskCursorSnapshot {
    return {
      hasRemotePosition: this.hasRemotePosition,
      remoteX: this.remoteX,
      remoteY: this.remoteY,
      remoteUpdatedAt: this.remoteUpdatedAt,
      currentId: this.currentId,
      pixelMap: this.currentBitmap?.pixelMap,
      bitmapWidth: this.currentBitmap?.width ?? 0,
      bitmapHeight: this.currentBitmap?.height ?? 0,
      hotX: this.currentBitmap?.hotX ?? 0,
      hotY: this.currentBitmap?.hotY ?? 0,
    };
  }

  describe(relativeMode: boolean, relativeModeStartedAt: number): string {
    if (!this.hasRemotePosition) {
      return 'remoteActual=none';
    }
    const modeAgeText = relativeMode && relativeModeStartedAt > 0
      ? ` modeAge=${Date.now() - relativeModeStartedAt}ms`
      : '';
    return `remoteActual=(${this.remoteX.toFixed(0)},${this.remoteY.toFixed(0)}) age=${Date.now() - this.remoteUpdatedAt}ms${modeAgeText}`;
  }

  private applyCurrentBitmap(): boolean {
    const cursor = this.cache.get(this.currentId);
    if (!cursor) {
      this.currentBitmap = undefined;
      return false;
    }
    this.currentBitmap = cursor;
    return true;
  }

  private releaseCache(): void {
    this.cache.forEach((cursor: RustDeskCursorBitmap) => {
      cursor.pixelMap.release().catch((_error: BusinessError) => {});
    });
    this.cache.clear();
  }
}
