import { devicePicker } from '@kit.ServiceCollaborationKit';

/**
 * 一个源会话的一个显示器对应的系统设备选择器。
 *
 * 系统控制器自己持有已选设备和业务状态；菜单重建卡片时必须复用同一控制器，
 * 否则选择与蓝色状态随视图销毁丢失。`networkId` 记录上次以 SUCCESSFUL 同步的
 * networkId，重开的卡片据此能清掉已经停止分享的旧蓝。只持有控制器与自身状态，
 * 不持有页面 UI、回调、上下文或邀请码。
 */
@ObservedV2
export class DisplaySharePickerEntry {
  readonly controller: devicePicker.DevicePickerController = devicePicker.createDevicePickerController();
  /** 当前在途的选择/停止操作；跨视图重建保留，异步结束后由发起方清除。 */
  @Trace busy: boolean = false;
  /** 上次 updateState 为 SUCCESSFUL 的 networkId；空表示没有声称中的分享。 */
  networkId: string = '';
  /** 已释放后不得再 on/off/updateState 同一个控制器。 */
  released: boolean = false;

  /** 幂等：重复释放不再触碰已释放的控制器。 */
  release(): void {
    if (this.released) {
      return;
    }
    this.released = true;
    this.controller.release();
  }
}

/**
 * 按源 sessionId 与显示器序号隔离的系统选择器仓库。
 * 释放由页面在真实源关闭/替换与 Ability 销毁时调用，卡片卸载不释放。
 */
export class DisplaySharePickerStore {
  private sessions: Map<string, Map<number, DisplaySharePickerEntry>> =
    new Map<string, Map<number, DisplaySharePickerEntry>>();

  get(sessionId: string, display: number): DisplaySharePickerEntry {
    let byDisplay = this.sessions.get(sessionId);
    if (byDisplay === undefined) {
      byDisplay = new Map<number, DisplaySharePickerEntry>();
      this.sessions.set(sessionId, byDisplay);
    }
    const existing = byDisplay.get(display);
    if (existing !== undefined) {
      return existing;
    }
    const created = new DisplaySharePickerEntry();
    byDisplay.set(display, created);
    return created;
  }

  releaseSession(sessionId: string): void {
    const byDisplay = this.sessions.get(sessionId);
    if (byDisplay === undefined) {
      return;
    }
    this.sessions.delete(sessionId);
    const entries: DisplaySharePickerEntry[] = [];
    byDisplay.forEach((entry: DisplaySharePickerEntry): void => {
      entries.push(entry);
    });
    for (let index = 0; index < entries.length; index += 1) {
      entries[index].release();
    }
  }

  releaseAll(): void {
    const sessionIds: string[] = [];
    this.sessions.forEach((_byDisplay: Map<number, DisplaySharePickerEntry>, sessionId: string): void => {
      sessionIds.push(sessionId);
    });
    for (let index = 0; index < sessionIds.length; index += 1) {
      this.releaseSession(sessionIds[index]);
    }
  }
}

export const displaySharePickerStore: DisplaySharePickerStore = new DisplaySharePickerStore();
