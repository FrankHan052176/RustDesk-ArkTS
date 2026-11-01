import { describe, expect, it } from '@ohos/hypium';
import {
  EasyTierProbeTarget,
  EasyTierReadinessController,
  EasyTierReadinessProbe,
  EasyTierReadinessRuntime,
} from '../../../main/ets/services/EasyTierReadinessController';

class ReadinessTestProbe implements EasyTierReadinessProbe {
  closed: number = 0;
  timeoutMs: number = 0;
  target: EasyTierProbeTarget | undefined = undefined;
  succeed: () => void = (): void => {};

  connect(target: EasyTierProbeTarget, timeoutMs: number): Promise<void> {
    this.target = target;
    this.timeoutMs = timeoutMs;
    return new Promise<void>((resolve): void => {
      this.succeed = resolve;
    });
  }

  close(): void {
    this.closed += 1;
  }
}

class ReadinessTestTimer {
  id: number;
  at: number;
  callback: () => void;
  active: boolean = true;

  constructor(id: number, at: number, callback: () => void) {
    this.id = id;
    this.at = at;
    this.callback = callback;
  }
}

class ReadinessTestClock {
  time: number = 0;
  probes: ReadinessTestProbe[] = [];
  timers: ReadinessTestTimer[] = [];

  runtime(): EasyTierReadinessRuntime {
    return {
      createProbe: (): EasyTierReadinessProbe => {
        const probe = new ReadinessTestProbe();
        this.probes.push(probe);
        return probe;
      },
      now: (): number => this.time,
      schedule: (callback: () => void, delay: number): number => {
        const timer = new ReadinessTestTimer(this.timers.length, this.time + delay, callback);
        this.timers.push(timer);
        return timer.id;
      },
      clear: (id: number): void => {
        if (id >= 0 && id < this.timers.length) {
          this.timers[id].active = false;
        }
      },
    };
  }

  advance(ms: number): void {
    const end = this.time + ms;
    while (true) {
      let next: ReadinessTestTimer | undefined = undefined;
      for (const timer of this.timers) {
        if (timer.active && timer.at <= end && (next === undefined || timer.at < next.at)) {
          next = timer;
        }
      }
      if (next === undefined) {
        break;
      }
      next.active = false;
      this.time = next.at;
      next.callback();
    }
    this.time = end;
  }
}

export default function easyTierReadinessControllerTest(): void {
  describe('EasyTierReadinessControllerTest', (): void => {
    it('waits for delayed reachability and closes every probe before handing off', 0, async (): Promise<void> => {
      const clock = new ReadinessTestClock();
      const controller = new EasyTierReadinessController(clock.runtime());
      let progress = 0;
      const result = controller.wait(true, '10.20.30.40:22000', (attempt: number): void => {
        progress = attempt;
      });
      clock.advance(5000);
      expect(clock.probes.length).assertEqual(3);
      expect(progress).assertEqual(3);
      expect(clock.probes[0].closed).assertEqual(1);
      expect(clock.probes[1].closed).assertEqual(1);
      expect(clock.probes[2].timeoutMs).assertEqual(1500);
      expect(clock.probes[2].target?.port).assertEqual(22000);
      clock.probes[2].succeed();
      expect(await result).assertEqual('ready');
      expect(clock.probes[2].closed).assertEqual(1);
      clock.advance(20000);
      expect(clock.probes.length).assertEqual(3);
    });

    it('exhausts a bounded budget even when socket promises never settle', 0, async (): Promise<void> => {
      const clock = new ReadinessTestClock();
      const controller = new EasyTierReadinessController(clock.runtime());
      const result = controller.wait(true, '10.20.30.40', (): void => {});
      clock.advance(12000);
      expect(await result).assertEqual('exhausted');
      expect(clock.probes.length).assertEqual(5);
      expect(clock.probes[0].target?.port).assertEqual(21118);
      for (const probe of clock.probes) {
        expect(probe.closed).assertEqual(1);
      }
      clock.advance(60000);
      expect(clock.probes.length).assertEqual(5);
      const suspendedClock = new ReadinessTestClock();
      const suspended = new EasyTierReadinessController(suspendedClock.runtime());
      const late = suspended.wait(true, '10.20.30.40', (): void => {});
      // Simulate callbacks being delayed while the application is suspended.
      suspendedClock.time = 12001;
      suspendedClock.probes[0].succeed();
      expect(await late).assertEqual('exhausted');
      expect(suspendedClock.probes[0].closed).assertEqual(1);
    });

    it('cancels in-flight and backoff work and ignores stale generations and successes', 0,
      async (): Promise<void> => {
        const clock = new ReadinessTestClock();
        const controller = new EasyTierReadinessController(clock.runtime());
        const old = controller.wait(true, '10.0.0.1', (): void => {});
        const next = controller.wait(true, '10.0.0.2', (): void => {});
        expect(await old).assertEqual('cancelled');
        expect(clock.probes[0].closed).assertEqual(1);
        clock.probes[0].succeed();
        await Promise.resolve();
        expect(clock.probes[1].closed).assertEqual(0);
        clock.advance(1500);
        // A late success after an attempt timeout must not be considered readiness.
        clock.probes[1].succeed();
        await Promise.resolve();
        controller.cancel();
        expect(await next).assertEqual('cancelled');
        clock.advance(20000);
        expect(clock.probes.length).assertEqual(2);
      });

    it('does not probe ordinary connections or reinterpret DNS IDs and unsupported syntax', 0,
      async (): Promise<void> => {
        const clock = new ReadinessTestClock();
        const controller = new EasyTierReadinessController(clock.runtime());
        expect(await controller.wait(false, '10.0.0.1', (): void => {})).assertEqual('skipped');
        const targets = ['123456789', 'example.com:21118', '[fd00::1]:21118',
          '10.0.0.1@server', '010.0.0.1', '256.0.0.1', '10.0.0.1:65536'];
        for (const target of targets) {
          expect(await controller.wait(true, target, (): void => {})).assertEqual('skipped');
        }
        expect(clock.probes.length).assertEqual(0);
      });
  });
}
