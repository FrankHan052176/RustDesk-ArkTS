// Transport readiness only. Core/HAR remains authoritative for RustDesk sessions and authentication.
export class EasyTierProbeTarget {
  address: string;
  port: number;

  constructor(address: string, port: number) {
    this.address = address;
    this.port = port;
  }
}

export interface EasyTierReadinessProbe {
  connect(target: EasyTierProbeTarget, timeoutMs: number): Promise<void>;
  close(): void;
}

export interface EasyTierReadinessRuntime {
  createProbe: () => EasyTierReadinessProbe;
  now: () => number;
  schedule: (callback: () => void, delayMs: number) => number;
  clear: (timer: number) => void;
}

export type EasyTierReadinessResult = 'ready' | 'exhausted' | 'cancelled' | 'skipped';

class EasyTierReadinessRun {
  target: EasyTierProbeTarget;
  resolve: (result: EasyTierReadinessResult) => void;
  progress: (attempt: number, maximum: number) => void;
  attempt: number = 0;
  attemptStartedAt: number = 0;
  deadline: number = 0;
  probe: EasyTierReadinessProbe | undefined = undefined;
  attemptTimer: number = -1;
  retryTimer: number = -1;
  budgetTimer: number = -1;

  constructor(target: EasyTierProbeTarget, resolve: (result: EasyTierReadinessResult) => void,
    progress: (attempt: number, maximum: number) => void) {
    this.target = target;
    this.resolve = resolve;
    this.progress = progress;
  }
}

export class EasyTierReadinessController {
  private readonly runtime: EasyTierReadinessRuntime;
  private active: EasyTierReadinessRun | undefined = undefined;

  constructor(runtime: EasyTierReadinessRuntime) {
    this.runtime = runtime;
  }

  // Deliberately conservative: never resolve DNS, reinterpret IDs/URLs, or rewrite the Core target.
  // IPv6 and decorated targets retain the existing Core path rather than guessing their grammar.
  static probeTarget(target: string): EasyTierProbeTarget | undefined {
    const match = /^(\d{1,3}(?:\.\d{1,3}){3})(?::([1-9]\d{0,4}))?$/.exec(target.trim());
    if (match === null) {
      return undefined;
    }
    const octets = match[1].split('.');
    for (let index = 0; index < octets.length; index += 1) {
      if (Number(octets[index]) > 255 || String(Number(octets[index])) !== octets[index]) {
        return undefined;
      }
    }
    // Core src/client.rs uses RELAY_PORT + 1 (21118) for bare direct IPs.
    const port = match[2] === undefined ? 21118 : Number(match[2]);
    return port <= 65535 ? new EasyTierProbeTarget(match[1], port) : undefined;
  }

  wait(easyTier: boolean, target: string,
    progress: (attempt: number, maximum: number) => void): Promise<EasyTierReadinessResult> {
    this.cancel();
    const endpoint = easyTier ? EasyTierReadinessController.probeTarget(target) : undefined;
    if (endpoint === undefined) {
      return Promise.resolve('skipped');
    }
    return new Promise<EasyTierReadinessResult>((resolve): void => {
      const run = new EasyTierReadinessRun(endpoint, resolve, progress);
      run.deadline = this.runtime.now() + 12000;
      this.active = run;
      run.budgetTimer = this.runtime.schedule((): void => this.finish(run, 'exhausted'), 12000);
      this.attempt(run);
    });
  }

  cancel(): void {
    if (this.active !== undefined) {
      this.finish(this.active, 'cancelled');
    }
  }

  private attempt(run: EasyTierReadinessRun): void {
    if (this.active !== run) {
      return;
    }
    if (this.runtime.now() >= run.deadline) {
      this.finish(run, 'exhausted');
      return;
    }
    run.retryTimer = -1;
    run.attempt += 1;
    const attempt = run.attempt;
    run.attemptStartedAt = this.runtime.now();
    run.progress(attempt, 5);
    if (this.active !== run) {
      return;
    }
    run.attemptTimer = this.runtime.schedule((): void => this.failed(run, attempt), 1500);
    try {
      const probe = this.runtime.createProbe();
      run.probe = probe;
      probe.connect(run.target, 1500).then((): void => {
        if (this.active === run && run.attempt === attempt && run.probe === probe) {
          this.finish(run, this.runtime.now() < run.deadline ? 'ready' : 'exhausted');
        }
      }).catch((): void => this.failed(run, attempt));
    } catch (_) {
      this.failed(run, attempt);
    }
  }

  private failed(run: EasyTierReadinessRun, attempt: number): void {
    if (this.active !== run || run.attempt !== attempt || run.attemptTimer < 0) {
      return;
    }
    this.runtime.clear(run.attemptTimer);
    run.attemptTimer = -1;
    this.closeProbe(run);
    if (run.attempt >= 5) {
      this.finish(run, 'exhausted');
      return;
    }
    // Space starts, not just failures: immediate refusals still allow routes time to converge.
    const delay = Math.max(0, 2500 - (this.runtime.now() - run.attemptStartedAt));
    run.retryTimer = this.runtime.schedule((): void => this.attempt(run), delay);
  }

  private closeProbe(run: EasyTierReadinessRun): void {
    const probe = run.probe;
    run.probe = undefined;
    try {
      probe?.close();
    } catch (_) {
      // Cleanup must never revive or stall a cancelled preflight.
    }
  }

  private finish(run: EasyTierReadinessRun, result: EasyTierReadinessResult): void {
    if (this.active !== run) {
      return;
    }
    this.active = undefined;
    this.runtime.clear(run.attemptTimer);
    this.runtime.clear(run.retryTimer);
    this.runtime.clear(run.budgetTimer);
    this.closeProbe(run);
    run.resolve(result);
  }
}
