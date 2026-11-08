import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { abilityConnectionManager } from '@kit.DistributedServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { rustDeskNativeApi } from '../../pages/rustdesk/RustDeskNativeApi';
import { abilityConnectionTransport, AbilityConnectionTransport } from './AbilityConnectionTransport';
import { CollaborateParams, DEFAULT_SHARE_SERVICE_NAME } from './AbilityConnectionTypes';
import { ScreenShareInviteService } from './ScreenShareInviteService';

const INVITE_PARAMETER = 'reskScreenInvite';

interface NativeTransportResult {
  ok: boolean;
  transportClosed?: boolean;
}

interface NearbyBinding {
  source: boolean;
  id: string;
  epoch: string;
  transportEpoch: string;
}

/** One collaboration connection, carrying only the existing encrypted RustDesk wire. */
export class NearbyShareService {
  private binding: NearbyBinding | undefined = undefined;
  private pending: CollaborateParams | undefined = undefined;
  private pendingCode: string = '';
  private generation: number = 0;

  constructor() {
    abilityConnectionTransport.onStateChanged((state, epoch, reason): void => {
      const current = this.binding;
      if (current === undefined) {
        return;
      }
      if (state === 'connecting') {
        current.transportEpoch = epoch;
      } else if (current.transportEpoch === epoch && (state === 'disconnected' || state === 'failed')) {
        this.fail(current, reason === 'peer_disconnected' ? 'peer_disconnected' : 'transport_error');
      }
    });
    abilityConnectionTransport.onFrameReceived((data: ArrayBuffer, epoch: string): void => {
      const current = this.binding;
      if (current === undefined || current.transportEpoch !== epoch) {
        return;
      }
      try {
        const bytes = new Uint8Array(data);
        const raw = current.source
          ? rustDeskNativeApi.sharePushReceiveData(current.epoch, bytes)
          : rustDeskNativeApi.sessionPushReceiveData(current.id, current.epoch, bytes);
        if (!(JSON.parse(raw) as NativeTransportResult).ok) {
          this.fail(current, 'transport_error');
        }
      } catch (_) {
        this.fail(current, 'transport_error');
      }
    });
  }

  /** Called only from the real onCollaborate entry; keeps the viewing grant in memory. */
  offerIncoming(context: common.UIAbilityContext, wantParam: Record<string, Object>): boolean {
    const parsed = AbilityConnectionTransport.parseCollaborateParam(wantParam);
    const code = parsed?.connectOptions?.parameters?.[INVITE_PARAMETER];
    if (this.binding !== undefined || this.pending !== undefined || parsed === undefined
      || typeof code !== 'string' || !code.startsWith('RKS1.') || code.length > 512) {
      return false;
    }
    this.pending = parsed;
    this.pendingCode = code;
    ScreenShareInviteService.bufferIncoming(context, code);
    return true;
  }

  async connectSource(context: common.UIAbilityContext, deviceId: string, code: string, shareEpoch: string): Promise<void> {
    if (this.binding !== undefined || this.pending !== undefined) {
      throw new Error('已有近场分享连接');
    }
    const generation = this.generation;
    await this.requestPermission(context);
    const status = JSON.parse(rustDeskNativeApi.shareGetTransportStatus(shareEpoch)) as NativeTransportResult;
    if (this.generation !== generation || this.binding !== undefined || this.pending !== undefined
      || !status.ok || status.transportClosed) {
      throw new Error('近场分享已撤销');
    }
    const binding: NearbyBinding = { source: true, id: '', epoch: shareEpoch, transportEpoch: '' };
    this.binding = binding;
    try {
      const peer: abilityConnectionManager.PeerInfo = {
        deviceId,
        bundleName: context.abilityInfo.bundleName,
        moduleName: context.abilityInfo.moduleName,
        abilityName: context.abilityInfo.name,
        serviceName: DEFAULT_SHARE_SERVICE_NAME,
      };
      await abilityConnectionTransport.connectSource(context, peer, {
        needSendData: true,
        parameters: { reskScreenInvite: code },
      });
      if (this.binding !== binding || !(JSON.parse(rustDeskNativeApi.shareConnectTransport(shareEpoch)) as NativeTransportResult).ok) {
        throw new Error('分享会话已撤销');
      }
      this.startPump(binding);
    } catch (error) {
      this.fail(binding, 'transport_error');
      throw error as Error;
    }
  }

  /** Binds the C native record before accepting, so early handshake data has an owner. */
  async acceptSession(context: common.UIAbilityContext, code: string, sessionId: string, lifecycleEpoch: string): Promise<void> {
    const incoming = this.pending;
    if (incoming === undefined || code !== this.pendingCode || this.binding !== undefined) {
      throw new Error('近场邀请已失效，请由分享端重新发起');
    }
    await this.requestPermission(context);
    if (this.pending !== incoming || this.binding !== undefined) {
      throw new Error('近场邀请已撤销');
    }
    const status = JSON.parse(rustDeskNativeApi.sessionGetTransportStatus(sessionId, lifecycleEpoch)) as NativeTransportResult;
    if (!status.ok || status.transportClosed) {
      throw new Error('观看会话已关闭');
    }
    this.pending = undefined;
    this.pendingCode = '';
    const binding: NearbyBinding = { source: false, id: sessionId, epoch: lifecycleEpoch, transportEpoch: '' };
    this.binding = binding;
    try {
      await abilityConnectionTransport.acceptSink(context, incoming.peerInfo, incoming.collabToken, incoming.connectOptions);
      this.startPump(binding);
    } catch (error) {
      this.fail(binding, 'transport_error');
      throw error as Error;
    }
  }

  discardIncoming(code: string): void {
    if (this.pendingCode !== code) {
      return;
    }
    const incoming = this.pending;
    this.pending = undefined;
    this.pendingCode = '';
    if (incoming !== undefined) {
      try {
        abilityConnectionManager.reject(incoming.collabToken, 'share_not_accepted');
      } catch (_) {
        // The platform may have already ended this unaccepted request.
      }
    }
  }

  private async requestPermission(context: common.UIAbilityContext): Promise<void> {
    const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context,
      ['ohos.permission.DISTRIBUTED_DATASYNC']);
    if (result.authResults.length !== 1 || result.authResults[0] !== 0) {
      throw new Error('请允许分布式数据同步以连接附近设备');
    }
  }

  private startPump(binding: NearbyBinding): void {
    if (this.binding !== binding || binding.transportEpoch !== abilityConnectionTransport.getEpoch()) {
      throw new Error('近场连接已撤销');
    }
    void this.pump(binding).catch((error: BusinessError): void => {
      // Never copy a platform error message: it can echo collaboration parameters.
      this.fail(binding, 'send_data_rejected', error.code ?? -1);
    });
  }

  private async pump(binding: NearbyBinding): Promise<void> {
    while (this.binding === binding) {
      const rawStatus = binding.source
        ? rustDeskNativeApi.shareGetTransportStatus(binding.epoch)
        : rustDeskNativeApi.sessionGetTransportStatus(binding.id, binding.epoch);
      const status = JSON.parse(rawStatus) as NativeTransportResult;
      if (!status.ok || status.transportClosed) {
        hilog.info(0xFF00, 'RustDeskShare', 'native transport closed: source=%{public}s ok=%{public}s',
          String(binding.source), String(status.ok));
        this.closeBinding(binding);
        return;
      }
      const bytes = binding.source
        ? rustDeskNativeApi.sharePollSendData(binding.epoch)
        : rustDeskNativeApi.sessionPollSendData(binding.id, binding.epoch);
      if (bytes.byteLength === 0) {
        await new Promise<void>((resolve): void => { setTimeout(resolve, 8); });
        continue;
      }
      // Send exactly this view; a Uint8Array can cover only part of its backing buffer.
      const data = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
      await abilityConnectionTransport.sendFrame(data, binding.transportEpoch);
      if (this.binding !== binding) {
        return;
      }
      // A completed platform call is not a display/render acknowledgement.
      if (binding.source) {
        rustDeskNativeApi.shareReportSendResult(binding.epoch, true, '');
      } else {
        rustDeskNativeApi.sessionReportSendResult(binding.id, binding.epoch, true, '');
      }
    }
  }

  private fail(binding: NearbyBinding, label: string, code: number = 0): void {
    if (this.binding !== binding) {
      return;
    }
    const stats = abilityConnectionTransport.getStats();
    hilog.info(0xFF00, 'RustDeskShare',
      'transport ended: source=%{public}s reason=%{public}s code=%{public}d sent=%{public}d received=%{public}d lastSendMs=%{public}s lastReceiveMs=%{public}s',
      String(binding.source), label, code, stats.framesSent, stats.framesReceived,
      String(stats.lastSendTimestampMs), String(stats.lastReceiveTimestampMs));
    if (binding.source) {
      rustDeskNativeApi.shareReportSendResult(binding.epoch, false, label, code);
    } else {
      rustDeskNativeApi.sessionReportSendResult(binding.id, binding.epoch, false, label, code);
    }
    this.closeBinding(binding);
  }

  private closeBinding(binding: NearbyBinding): void {
    if (this.binding !== binding) {
      return;
    }
    this.binding = undefined;
    void abilityConnectionTransport.disconnect(binding.transportEpoch);
  }

  closeSource(shareEpoch: string): void {
    const binding = this.binding;
    if (binding !== undefined && binding.source && binding.epoch === shareEpoch) {
      this.fail(binding, 'user_stop');
    }
  }

  destroy(): void {
    this.generation += 1;
    const binding = this.binding;
    if (binding !== undefined) {
      this.fail(binding, 'transport_closed');
    }
    this.pending = undefined;
    this.pendingCode = '';
    void abilityConnectionTransport.disconnect();
  }
}

export const nearbyShareService: NearbyShareService = new NearbyShareService();
