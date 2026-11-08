import { sensor } from '@kit.SensorServiceKit';
import { RemoteSessionOrientationMode, RemoteSessionOrientationPolicy } from './RemoteSessionOrientationPolicy';

/** Samples only for the explicit rotate action; never subscribes for auto-rotation. */
export function readSessionPhysicalOrientation(): Promise<RemoteSessionOrientationMode> {
  return new Promise<RemoteSessionOrientationMode>((resolve, reject) => {
    let finished = false;
    let timer: number = -1;
    const cleanup = (): void => {
      if (timer >= 0) {
        clearTimeout(timer);
      }
      sensor.off(sensor.SensorId.GRAVITY, onGravity);
    };
    const onGravity = (value: sensor.GravityResponse): void => {
      if (finished) {
        return;
      }
      finished = true;
      cleanup();
      const mode = RemoteSessionOrientationPolicy.fromGravity(value.x, value.y);
      if (mode === undefined) {
        reject(new Error('设备平放时无法判断方向，请竖起设备或使用旋转90度'));
      } else {
        resolve(mode);
      }
    };
    try {
      sensor.on(sensor.SensorId.GRAVITY, onGravity);
      timer = setTimeout((): void => {
        if (!finished) {
          finished = true;
          cleanup();
          reject(new Error('未能读取设备方向，请使用旋转90度'));
        }
      }, 1000);
    } catch (_) {
      finished = true;
      reject(new Error('当前设备无法读取方向，请使用旋转90度'));
    }
  });
}
