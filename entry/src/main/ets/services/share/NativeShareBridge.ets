import { rustDeskNativeApi } from '../../pages/rustdesk/RustDeskNativeApi';
import {
  ShareStartOptions,
  ShareStartResult,
  ShareStopResult,
  ShareStatusResult,
  ShareInviteResult,
} from './ShareTypes';

export class NativeShareBridge {
  async start(options: ShareStartOptions): Promise<ShareStartResult> {
    try {
      const raw = await rustDeskNativeApi.shareStart(JSON.stringify(options));
      return JSON.parse(raw) as ShareStartResult;
    } catch (error) {
      return { ok: false, error: String(error), message: `shareStart failed: ${String(error)}` };
    }
  }

  async stop(shareEpoch: string): Promise<ShareStopResult> {
    try {
      const raw = await rustDeskNativeApi.shareStop(shareEpoch);
      return JSON.parse(raw) as ShareStopResult;
    } catch (error) {
      return { ok: false, message: `shareStop failed: ${String(error)}` };
    }
  }

  status(): ShareStatusResult {
    try {
      const raw = rustDeskNativeApi.shareGetStatus();
      return JSON.parse(raw) as ShareStatusResult;
    } catch (error) {
      return { state: 'idle', message: `shareGetStatus failed: ${String(error)}` };
    }
  }

  getInvite(shareEpoch: string): ShareInviteResult {
    try {
      const raw = rustDeskNativeApi.shareGetInvite(shareEpoch);
      return JSON.parse(raw) as ShareInviteResult;
    } catch (error) {
      return { ok: false, message: `shareGetInvite failed: ${String(error)}` };
    }
  }
}

export const nativeShareBridge: NativeShareBridge = new NativeShareBridge();
