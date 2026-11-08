import { describe, expect, it } from '@ohos/hypium';
import { cursorOverlayOrigin, resolveCursorPosition } from '../../../main/ets/pages/rustdesk/RustDeskCursorPresentation';
import { RemotePointerPosition } from '../../../main/ets/pages/rustdesk/RustDeskInputMapper';
import { NativeEvent, PeerDisplayInfo } from '../../../main/ets/pages/rustdesk/RustDeskTypes';
import { RustDeskCursorModel } from '../../../main/ets/pages/rustdesk/RustDeskCursorModel';
import { RustDeskViewportModel } from '../../../main/ets/pages/rustdesk/RustDeskViewportModel';

function pointText(point: RemotePointerPosition | undefined): string {
  return point === undefined ? 'none' : `${point.x},${point.y}`;
}

function tinyBitmap(id: string): NativeEvent {
  return { name: 'cursor_data', id, width: '1', height: '1', hotx: '0', hoty: '0', colors: '[255,255,255,255]' };
}

export default function cursorPresentationTest(): void {
  describe('RustDeskCursorPresentationTest', () => {
    it('switches between prediction and actual global samples without inventing a remote position', 0, () => {
      const display: PeerDisplayInfo = { x: -1920, y: -200, width: 1920, height: 1080 };
      const local: RemotePointerPosition = { x: 700, y: 400 };
      const remote: RemotePointerPosition = { x: -1800, y: 100 };
      expect(pointText(resolveCursorPosition('local', local, remote, display))).assertEqual('700,400');
      expect(pointText(resolveCursorPosition('remote', local, remote, display))).assertEqual('120,300');
      expect(pointText(resolveCursorPosition('remote', local, undefined, display))).assertEqual('none');
      // New actual samples move only remote presentation, not the input cursor.
      const nextRemote: RemotePointerPosition = { x: -1750, y: 150 };
      expect(pointText(resolveCursorPosition('remote', local, nextRemote, display))).assertEqual('170,350');
      expect(pointText(resolveCursorPosition('local', local, nextRemote, display))).assertEqual('700,400');
    });

    it('subtracts the selected display origin once and does not clamp another display into view', 0, () => {
      const display: PeerDisplayInfo = { x: 1920, y: 300, width: 1600, height: 900 };
      const remote: RemotePointerPosition = { x: 2120, y: 500 };
      expect(pointText(resolveCursorPosition('remote', undefined, remote, display))).assertEqual('200,200');
      const elsewhere: RemotePointerPosition = { x: 500, y: 500 };
      expect(pointText(resolveCursorPosition('remote', undefined, elsewhere, display))).assertEqual('none');
      expect(pointText(resolveCursorPosition('remote', undefined, remote, undefined))).assertEqual('none');
      const model = new RustDeskViewportModel();
      model.setPeerDisplays([display], 0);
      const rect = model.getRemoteRect();
      expect(rect !== undefined && rect.left === 0 && rect.top === 0).assertTrue();
    });

    it('anchors the scaled fallback tip and bitmap hotspot at the same mapped click point', 0, () => {
      const display: PeerDisplayInfo = { x: -1600, y: 100, width: 1600, height: 900 };
      const model = new RustDeskViewportModel();
      model.setPeerDisplays([display], 0);
      model.setViewportSize(1000, 800);
      model.setViewTransform(1.5, 20, -15, 90);
      const remote: RemotePointerPosition = { x: -800, y: 550 };
      const position = resolveCursorPosition('remote', undefined, remote, display);
      expect(position !== undefined).assertTrue();
      if (!position) {
        return;
      }
      const anchor = model.mapRemoteToLocal(position.x, position.y);
      expect(anchor !== undefined).assertTrue();
      if (!anchor) {
        return;
      }
      const visualScale = 2.25;
      const fallback = cursorOverlayOrigin(anchor.x, anchor.y, 1, 1, visualScale);
      expect(fallback.x + visualScale).assertEqual(anchor.x);
      expect(fallback.y + visualScale).assertEqual(anchor.y);
      const bitmap = cursorOverlayOrigin(anchor.x, anchor.y, 4, 9, visualScale);
      expect(bitmap.x + 4 * visualScale).assertEqual(anchor.x);
      expect(bitmap.y + 9 * visualScale).assertEqual(anchor.y);
      const click = model.mapLocalToRemote(fallback.x + visualScale, fallback.y + visualScale);
      expect(click !== undefined).assertTrue();
      if (!click) {
        return;
      }
      expect(Math.abs(click.x - 800) <= 1 && Math.abs(click.y - 450) <= 1).assertTrue();
    });

    it('preserves RGBA channels, alpha and row order in an asymmetric 2x3 cursor bitmap', 0, async () => {
      const model = new RustDeskCursorModel();
      // Distinct columns and rows expose channel swaps and spatial reordering.
      const colors: number[] = [
        255, 0, 0, 255, 0, 0, 255, 255,
        0, 255, 0, 255, 23, 107, 211, 255,
        0, 0, 0, 0, 240, 32, 64, 128,
      ];
      const event: NativeEvent = {
        name: 'cursor_data', id: 'rgba-2x3', width: '2', height: '3', hotx: '1', hoty: '2',
        colors: JSON.stringify(colors),
      };
      try {
        await model.updateCursorData(event, () => {}, () => {});
        const pixelMap = model.getSnapshot().pixelMap;
        expect(pixelMap !== undefined).assertTrue();
        if (!pixelMap) {
          return;
        }
        const info = await pixelMap.getImageInfo();
        expect(info.size.width).assertEqual(2);
        expect(info.size.height).assertEqual(3);
        const rowBytes = pixelMap.getBytesNumberPerRow();
        const buffer = new ArrayBuffer(pixelMap.getPixelBytesNumber());
        // Read the real ImageKit PixelMap, not the original input or a decoder stub.
        await pixelMap.readPixelsToBuffer(buffer);
        const actual = new Uint8Array(buffer);
        for (let row = 0; row < 3; row += 1) {
          for (let offset = 0; offset < 2 * 4; offset += 1) {
            expect(actual[row * rowBytes + offset]).assertEqual(colors[row * 2 * 4 + offset]);
          }
        }
      } finally {
        model.reset();
      }
    });

    it('evicts the oldest noncurrent bitmap at the ID limit and clears unknown shapes', 0, async () => {
      const model = new RustDeskCursorModel();
      try {
        for (let id = 0; id < 256; id += 1) {
          await model.updateCursorData(tinyBitmap(String(id)), () => {}, () => {});
        }
        expect(model.updateCursorId('0')).assertTrue();
        const pinned = model.getSnapshot().pixelMap;
        // The asynchronous new shape completes while the oldest shape is active.
        const pending = model.updateCursorData(tinyBitmap('256'), () => {}, () => {});
        expect(model.updateCursorId('0')).assertTrue();
        await pending;
        expect(model.getSnapshot().pixelMap === pinned).assertTrue();
        if (pinned) {
          const info = await pinned.getImageInfo();
          expect(info.size.width).assertEqual(1);
        }
        expect(model.updateCursorId('1')).assertFalse();
        expect(model.getSnapshot().pixelMap === undefined).assertTrue();
        expect(model.updateCursorId('256')).assertTrue();
      } finally {
        model.reset();
      }
    });

    it('bounds decoded bytes independently of the ID count', 0, async () => {
      const model = new RustDeskCursorModel();
      const colors = JSON.stringify(new Array<number>(512 * 512 * 4).fill(0));
      try {
        for (let id = 0; id < 17; id += 1) {
          const event: NativeEvent = {
            name: 'cursor_data', id: String(id), width: '512', height: '512', hotx: '1', hoty: '1', colors,
          };
          await model.updateCursorData(event, () => {}, () => {});
        }
        expect(model.updateCursorId('0')).assertFalse();
        expect(model.updateCursorId('1')).assertTrue();
        expect(model.updateCursorId('16')).assertTrue();
      } finally {
        model.reset();
      }
    });

    it('replaces valid same-ID data and prevents invalidated pending data from restoring a rejected shape', 0, async () => {
      const model = new RustDeskCursorModel();
      try {
        await model.updateCursorData(tinyBitmap('7'), () => {}, () => {});
        const original = model.getSnapshot().pixelMap;
        const replacement: NativeEvent = {
          name: 'cursor_data', id: '7', width: '2', height: '1', hotx: '1', hoty: '0',
          colors: '[255,255,255,255,0,0,0,255]',
        };
        await model.updateCursorData(replacement, () => {}, () => {});
        expect(model.getSnapshot().pixelMap !== original).assertTrue();
        expect(model.getSnapshot().bitmapWidth).assertEqual(2);
        expect(model.getSnapshot().hotX).assertEqual(1);
        const pending = model.updateCursorData(tinyBitmap('7'), () => {}, () => {});
        model.invalidateCursorId('7', () => {
          expect(model.getSnapshot().pixelMap === undefined).assertTrue();
        });
        await pending;
        expect(model.updateCursorId('7')).assertFalse();
        expect(model.getSnapshot().pixelMap === undefined).assertTrue();
        await model.updateCursorData(tinyBitmap('7'), () => {}, () => {});
        expect(model.updateCursorId('7')).assertTrue();
      } finally {
        model.reset();
      }
    });
  });
}
