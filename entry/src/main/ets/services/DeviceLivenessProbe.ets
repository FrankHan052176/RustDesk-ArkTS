import socket from '@ohos.net.socket';
import { BusinessError } from '@kit.BasicServicesKit';
import { PeerRecord } from '../pages/rustdesk/RustDeskDirectoryTypes';
import { copyPeerRecord, peerProtocolOf } from '../pages/rustdesk/RustDeskPeerDirectoryModel';
import { isIpv4Address, isIpv6Address, migrateDeviceRecord, savedDeviceKey } from '../pages/rustdesk/SavedDeviceModel';

const PROBE_TIMEOUT_MS = 1500;
const PROBE_CONCURRENCY = 4;

class ActiveDeviceProbe {
  tcp: socket.TCPSocket;
  timer: number = -1;
  finish: (online: boolean | undefined) => void = (_online: boolean | undefined): void => {};

  constructor(tcp: socket.TCPSocket) {
    this.tcp = tcp;
  }
}

export class DeviceLivenessProbe {
  private generation: number = 0;
  private active: ActiveDeviceProbe[] = [];

  cancel(): void {
    this.generation += 1;
    for (const probe of this.active.slice()) {
      probe.finish(undefined);
    }
  }

  async probe(peers: PeerRecord[]): Promise<PeerRecord[]> {
    this.cancel();
    const generation = this.generation;
    const unique = new Map<string, PeerRecord>();
    for (const peer of peers) {
      unique.set(savedDeviceKey(peer), copyPeerRecord(peer));
    }
    const records = Array.from(unique.values());
    let next = 0;
    const workers: Promise<void>[] = [];
    for (let index = 0; index < Math.min(PROBE_CONCURRENCY, records.length); index += 1) {
      workers.push((async (): Promise<void> => {
        while (generation === this.generation && next < records.length) {
          const peer = records[next++];
          const endpoint = migrateDeviceRecord(peer);
          const ip = isIpv4Address(endpoint.address) || isIpv6Address(endpoint.address);
          if ((peer.rustdeskIdOnly && peerProtocolOf(peer) === 'rustdesk') || !ip || endpoint.port <= 0) {
            continue;
          }
          // A TCP accept on this direct endpoint is that wire's reachability;
          // hbbs never answers here, so it can never become a RustDesk online row.
          peer.directWireReachable = await this.connect(endpoint, generation);
        }
      })());
    }
    await Promise.all(workers);
    return generation === this.generation ? records : [];
  }

  private connect(peer: PeerRecord, generation: number): Promise<boolean | undefined> {
    return new Promise<boolean | undefined>((resolve) => {
      if (generation !== this.generation) {
        resolve(undefined);
        return;
      }
      let tcp: socket.TCPSocket;
      try {
        tcp = socket.constructTCPSocketInstance();
      } catch (_) {
        resolve(undefined);
        return;
      }
      const probe = new ActiveDeviceProbe(tcp);
      let finished = false;
      probe.finish = (online: boolean | undefined): void => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(probe.timer);
        const index = this.active.indexOf(probe);
        if (index >= 0) {
          this.active.splice(index, 1);
        }
        try {
          void tcp.close().catch((error: BusinessError): void => {
            console.warn(`Device probe close: ${error.code}`);
          });
        } catch (error) {
          console.warn(`Device probe close: ${String(error)}`);
        }
        resolve(generation === this.generation ? online : undefined);
      };
      this.active.push(probe);
      probe.timer = setTimeout((): void => probe.finish(false), PROBE_TIMEOUT_MS) as number;
      try {
        const address: socket.NetAddress = {
          address: peer.address,
          port: peer.port,
          family: isIpv6Address(peer.address) ? 2 : 1,
        };
        const options: socket.TCPConnectOptions = { address, timeout: PROBE_TIMEOUT_MS };
        void tcp.connect(options).then((): void => probe.finish(true))
          .catch((error: BusinessError): void => {
            // Refused/reset/timed out is a completed negative TCP observation;
            // permission, no route, unsupported socket or local failures stay unknown.
            probe.finish([2301111, 2301104, 2301110].includes(error.code) ? false : undefined);
          });
      } catch (_) {
        probe.finish(undefined);
      }
    });
  }
}
