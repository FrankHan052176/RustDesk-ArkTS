import { socket } from '@kit.NetworkKit';
import {
  EasyTierProbeTarget,
  EasyTierReadinessController,
  EasyTierReadinessProbe,
} from './EasyTierReadinessController';

class EasyTierSocketProbe implements EasyTierReadinessProbe {
  private readonly tcp: socket.TCPSocket = socket.constructTCPSocketInstance();

  connect(target: EasyTierProbeTarget, timeoutMs: number): Promise<void> {
    // No bind/protect/network selection: use the same system VPN route as the subsequent Core socket.
    // No send/receive, RustDesk handshake, password, or DNS operations belong in this probe.
    return this.tcp.connect({
      address: { address: target.address, port: target.port, family: 1 },
      timeout: timeoutMs,
    });
  }

  close(): void {
    void this.tcp.close().catch((): void => {});
  }
}

export function createEasyTierReadinessController(): EasyTierReadinessController {
  return new EasyTierReadinessController({
    createProbe: (): EasyTierReadinessProbe => new EasyTierSocketProbe(),
    now: (): number => Date.now(),
    schedule: (callback: () => void, delayMs: number): number => setTimeout(callback, delayMs) as number,
    clear: (timer: number): void => {
      if (timer >= 0) {
        clearTimeout(timer);
      }
    },
  });
}
