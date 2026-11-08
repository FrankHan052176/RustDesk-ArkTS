import { describe, expect, it } from '@ohos/hypium';
import {
  FrameRateSnapshot,
  FrameRateTelemetry,
  parseFrameRateSnapshot,
} from '../../../main/ets/services/FrameRateTelemetry';
import {
  QualityStatusFields,
  QualityTelemetry,
  applyFrameRateSnapshot,
  clearQualityFrameMetrics,
  emptyQualityTelemetry,
  mergeQualityStatus,
} from '../../../main/ets/pages/rustdesk/RustDeskSessionTypes';

/** The fields of one Core status tick this suite varies. */
interface CoreTick {
  display: number;
  round: string;
  generation: string;
  codec: string;
  receivedFps: string;
  submittedFps: string;
  queuedUnits: string;
  failed: boolean;
}

/**
 * One Core status tick, in the exact shape `session_get_frame_rate_snapshot`
 * writes it: counters as decimal strings, geometry and display as numbers.
 */
function coreTick(fields: CoreTick): string {
  return '{"available":true,"source":"core_status_tick","display":' + fields.display
    + ',"round":"' + fields.round + '","generation":"' + fields.generation
    + '","codec":"' + fields.codec + '","width":1920,"height":1080'
    + ',"receivedPackets":"120","receivedFps":"' + fields.receivedFps + '"'
    + ',"decodedFrames":"100","submittedFrames":"90","submittedFps":"' + fields.submittedFps + '"'
    + ',"presentedFrames":"0","presentedFps":"0","nativeImporter":false'
    + ',"nativePaintedFps":"0","firstOutputSubmitted":true'
    + ',"queuedUnits":"' + fields.queuedUnits + '","failed":' + (fields.failed ? 'true' : 'false')
    + ',"reclamationUnconfirmed":false}';
}

/** One tick of the shape this suite varies least, for the cases that are not about the numbers. */
function plainTick(round: string, generation: string, display: number): string {
  return coreTick({
    display,
    round,
    generation,
    codec: 'h265',
    receivedFps: '59',
    submittedFps: '45',
    queuedUnits: '0',
    failed: false,
  });
}

/** Fields of the real cumulative Viewer producer, not the obsolete rate fixture. */
interface ViewerTick {
  elapsedMs: number;
  receivedPackets: number;
  submittedFrames: number;
  status?: string;
  generation?: string;
  intentRevision?: string;
  display?: number;
  codec?: string;
  queuedUnits?: number | null;
  networkRttMs?: number | null;
}

/**
 * Current native fields plus the paired HAR's actual display/optional RTT.
 * No framesAvailable or precomputed rates: the client must form its own window.
 */
function viewerTick(fields: ViewerTick): string {
  const generation = fields.generation ?? '1';
  const queued = fields.queuedUnits === undefined ? 0 : fields.queuedUnits;
  return '{"available":true,"source":"engine_viewer_snapshot"'
    + ',"generation":"' + generation + '","intentRevision":"' + (fields.intentRevision ?? generation) + '"'
    + ',"desiredFps":120,"elapsedMs":' + fields.elapsedMs
    + ',"status":"' + (fields.status ?? 'streaming') + '","display":' + (fields.display ?? 0)
    + ',"receivedPackets":' + fields.receivedPackets + ',"submittedFrames":' + fields.submittedFrames
    + ',"codec":"' + (fields.codec ?? 'H265') + '","queuedUnits":' + String(queued)
    + ',"networkRttMs":' + String(fields.networkRttMs ?? null) + '}';
}

/** Observed runtime counters; display/RTT follow the paired native contract. */
const VIEWER_TICK = viewerTick({ elapsedMs: 1223201, receivedPackets: 106399, submittedFrames: 106399 });

/** A Core session with nothing published to read. */
const NO_TICK = '{"available":false,"reason":"the connection has not published a status tick yet"}';

export default function frameRateTelemetryTest(): void {
  describe('FrameRateTelemetry', () => {
    it('reads the Core status tick the way the engine writes it', 0, () => {
      const snapshot = parseFrameRateSnapshot(coreTick({
        display: 1,
        round: '12',
        generation: '7',
        codec: 'h265',
        receivedFps: '59',
        submittedFps: '45',
        queuedUnits: '0',
        failed: false,
      }));
      expect(snapshot !== undefined).assertTrue();
      const reading = snapshot as FrameRateSnapshot;
      expect(reading.kind).assertEqual('measured');
      expect(reading.measured()).assertTrue();
      expect(reading.display).assertEqual(1);
      expect(reading.round).assertEqual('12');
      expect(reading.generation).assertEqual('7');
      expect(reading.codec).assertEqual('h265');
      // The rates are the engine's own, so they are taken as written.
      expect(reading.receivedFps).assertEqual(59);
      expect(reading.submittedFps).assertEqual(45);
      // A measured zero is a reading: a decoder that queued nothing says so.
      expect(reading.queuedUnits).assertEqual(0);
    });

    it('classifies a reading that carries no frame counters instead of rejecting it', 0, () => {
      // Nothing published yet, or no admission to read it: the engine says why.
      const unavailable = parseFrameRateSnapshot(NO_TICK);
      expect(unavailable !== undefined).assertTrue();
      expect((unavailable as FrameRateSnapshot).kind).assertEqual('unavailable');
      expect((unavailable as FrameRateSnapshot).measured()).assertFalse();
      expect((unavailable as FrameRateSnapshot).receivedFps === null).assertTrue();
      expect((unavailable as FrameRateSnapshot).submittedFps === null).assertTrue();
      expect((unavailable as FrameRateSnapshot).queuedUnits === null).assertTrue();
      expect(parseFrameRateSnapshot('{"available":false,"reason":"unknown_session"}') !== undefined)
        .assertTrue();

      // A cumulative Viewer reading is a baseline, not an instantaneous rate.
      const viewer = parseFrameRateSnapshot(VIEWER_TICK);
      expect(viewer !== undefined).assertTrue();
      expect((viewer as FrameRateSnapshot).kind).assertEqual('engine_viewer');
      expect((viewer as FrameRateSnapshot).measured()).assertFalse();
      expect((viewer as FrameRateSnapshot).receivedFps === null).assertTrue();
      expect((viewer as FrameRateSnapshot).submittedFps === null).assertTrue();
      expect((viewer as FrameRateSnapshot).queuedUnits).assertEqual(0);
      expect((viewer as FrameRateSnapshot).codec).assertEqual('H265');
      expect((viewer as FrameRateSnapshot).networkRttMs === null).assertTrue();

      // A failed generation's rates do not describe the session's picture.
      const failed = parseFrameRateSnapshot(plainTick('12', '7', 0).replace('"failed":false', '"failed":true'));
      expect((failed as FrameRateSnapshot).kind).assertEqual('decoder_failed');
      expect((failed as FrameRateSnapshot).measured()).assertFalse();

      // A packet this build cannot read at all is not a state of the session.
      for (const unreadable of ['', 'broken', '{}', 'null', '[]', '"text"',
        '{"available":true}',
        '{"available":true,"source":"some_future_tick"}',
        plainTick('12', '7', 0).replace('"round":"12"', '"round":"12.5"'),
        plainTick('12', '7', 0).replace('"round":"12"', '"round":""'),
        plainTick('12', '7', 0).replace('"generation":"7"', '"generation":"-1"'),
        plainTick('12', '7', 0).replace('"generation":"7"', '"generation":"9007199254740992"'),
        plainTick('12', '7', 0).replace('"round":"12",', ''),
        plainTick('12', '7', 0).replace('"display":0', '"display":"0"'),
        plainTick('12', '7', 0).replace('"display":0', '"display":-1'),
        plainTick('12', '7', 0).replace('"display":0', '"display":1.5'),
        plainTick('12', '7', 0).replace('"failed":false', '"failed":"false"')]) {
        expect(parseFrameRateSnapshot(unreadable) === undefined).assertTrue();
      }
    });

    it('differences adjacent real Viewer counters over native elapsed time, including measured zero', 0, () => {
      const telemetry = new FrameRateTelemetry();
      expect(telemetry.shouldRead('viewer:epoch-1', 0)).assertTrue();
      const first = telemetry.sample(VIEWER_TICK, 0) as FrameRateSnapshot;
      expect(first.measured()).assertFalse();
      expect(first.receivedFps === null).assertTrue();
      expect(first.submittedFps === null).assertTrue();
      expect(first.generation).assertEqual('1');
      expect(first.intentRevision).assertEqual('1');

      // The two runtime samples are 1018ms apart, not a fabricated 1s window.
      expect(telemetry.shouldRead('viewer:epoch-1', 1019)).assertTrue();
      const next = telemetry.sample(viewerTick({
        elapsedMs: 1224219, receivedPackets: 106502, submittedFrames: 106501,
      }), 0) as FrameRateSnapshot;
      expect(next.measured()).assertTrue();
      expect(next.receivedFps).assertEqual(103000 / 1018);
      expect(next.submittedFps).assertEqual(102000 / 1018);
      expect(telemetry.consumeFrameReset()).assertFalse();
      const shown = applyFrameRateSnapshot(emptyQualityTelemetry(), next, '120');
      expect(shown.receivedFps).assertEqual('101.2');
      expect(shown.submittedFps).assertEqual('100.2');
      expect(shown.requestedFps).assertEqual('120');

      // Counters unchanged over positive native time really measure zero.
      const zero = telemetry.sample(viewerTick({
        elapsedMs: 1225219, receivedPackets: 106502, submittedFrames: 106501,
      }), 0) as FrameRateSnapshot;
      expect(zero.measured()).assertTrue();
      expect(zero.receivedFps).assertEqual(0);
      expect(zero.submittedFps).assertEqual(0);
    });

    it('requires the Viewer dial/display identities and never relabels another display', 0, () => {
      const streaming = VIEWER_TICK;
      const unreadable = [
        streaming.replace('"display":0,', ''),
        streaming.replace('"display":0,', '"display":-1,'),
        streaming.replace('"display":0,', '"display":"0",'),
        streaming.replace('"display":0,', '"display":1.5,'),
        streaming.replace('"generation":"1",', ''),
        streaming.replace('"intentRevision":"1",', ''),
      ];
      for (const packet of unreadable) {
        expect(parseFrameRateSnapshot(packet) === undefined).assertTrue();
      }

      const otherDisplay = viewerTick({ elapsedMs: 1000, receivedPackets: 60, submittedFrames: 50, display: 1 });
      const declared = parseFrameRateSnapshot(otherDisplay) as FrameRateSnapshot;
      expect(declared.display).assertEqual(1);
      const telemetry = new FrameRateTelemetry();
      expect(telemetry.shouldRead('viewer:epoch-1', 0)).assertTrue();
      expect(telemetry.sample(otherDisplay, 0) === undefined).assertTrue();
      expect((telemetry.sample(otherDisplay, 1) as FrameRateSnapshot).submittedFps === null).assertTrue();
    });

    it('keeps a decimal string only inside the safe numeric bounds', 0, () => {
      const withCounts = (received: string, submitted: string, queued: string): FrameRateSnapshot => {
        return parseFrameRateSnapshot(coreTick({
          display: 0,
          round: '1',
          generation: '1',
          codec: 'h264',
          receivedFps: received,
          submittedFps: submitted,
          queuedUnits: queued,
          failed: false,
        })) as FrameRateSnapshot;
      };
      const zeroes = withCounts('0', '0', '0');
      expect(zeroes.kind).assertEqual('measured');
      expect(zeroes.receivedFps).assertEqual(0);
      expect(zeroes.submittedFps).assertEqual(0);
      expect(zeroes.queuedUnits).assertEqual(0);

      // A number the engine did not write as a decimal string is not measured,
      // and it must not blank the fields beside it either.
      const unsafe = withCounts('9007199254740992', '60', '2');
      expect(unsafe.kind).assertEqual('measured');
      expect(unsafe.receivedFps === null).assertTrue();
      expect(unsafe.submittedFps).assertEqual(60);
      expect(unsafe.queuedUnits).assertEqual(2);
      expect(withCounts('59.5', '60', '2').receivedFps === null).assertTrue();
      expect(withCounts('-1', '60', '2').receivedFps === null).assertTrue();
      expect(withCounts('007', '60', '2').receivedFps === null).assertTrue();
      expect(withCounts('', '60', '2').receivedFps === null).assertTrue();
      expect(withCounts('nope', '60', '2').receivedFps === null).assertTrue();
      // A JSON number is accepted as well: the value is what matters, not its spelling.
      expect(withCounts('59', '60', '2').receivedFps).assertEqual(59);
      expect(parseFrameRateSnapshot(plainTick('1', '1', 0).replace('"receivedFps":"59"', '"receivedFps":59'))
        !== undefined).assertTrue();
      // A counter the engine left out entirely is unknown, never zero.
      const missing = parseFrameRateSnapshot(plainTick('1', '1', 0).replace('"submittedFps":"45",', ''));
      expect((missing as FrameRateSnapshot).submittedFps === null).assertTrue();
      expect((missing as FrameRateSnapshot).receivedFps).assertEqual(59);
    });

    it('reads once a second per binding and re-anchors a clock that moved backwards', 0, () => {
      const telemetry = new FrameRateTelemetry();
      expect(telemetry.shouldRead('', 0)).assertFalse();
      expect(telemetry.shouldRead('session:core', 0)).assertTrue();
      expect(telemetry.shouldRead('session:core', 999)).assertFalse();
      expect(telemetry.shouldRead('session:core', 1000)).assertTrue();
      expect(telemetry.shouldRead('session:core', 1999)).assertFalse();
      // A clock that moved backwards is not an elapsed interval: it is
      // re-anchored, not divided by, and it does not read twice in a row.
      expect(telemetry.shouldRead('session:core', 900)).assertFalse();
      expect(telemetry.shouldRead('session:core', 1899)).assertFalse();
      expect(telemetry.shouldRead('session:core', 1900)).assertTrue();
      // A different session is read at once.
      expect(telemetry.shouldRead('other:core', 1900)).assertTrue();
      expect(telemetry.shouldRead('other:core', 1901)).assertFalse();
      // An unusable binding ends the reading instead of continuing the last one.
      expect(telemetry.shouldRead('', 1901)).assertFalse();
      expect(telemetry.shouldRead('other:core', 1901)).assertTrue();
    });

    it('publishes a measured reading and drops the old one on a pipeline change', 0, () => {
      const telemetry = new FrameRateTelemetry();
      expect(telemetry.consumeFrameReset()).assertFalse();
      // Nothing is read before a binding is known.
      expect(telemetry.sample(plainTick('12', '7', 0), 0) === undefined).assertTrue();
      expect(telemetry.shouldRead('session:core', 0)).assertTrue();

      // The first reading of a session has nothing to compare with, so it is published.
      const first = telemetry.sample(plainTick('12', '7', 0), 0);
      expect(first !== undefined).assertTrue();
      expect((first as FrameRateSnapshot).submittedFps).assertEqual(45);
      expect(telemetry.consumeFrameReset()).assertFalse();
      expect(telemetry.sample(plainTick('12', '7', 0), 0) !== undefined).assertTrue();

      // A new decoder generation is a new pipeline: the caller is told once to
      // drop the rows that described the old one, and the next read publishes.
      expect(telemetry.sample(plainTick('12', '8', 0), 0) === undefined).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
      expect(telemetry.sample(plainTick('12', '8', 0), 0) !== undefined).assertTrue();

      // A new connection round is a new pipeline too.
      expect(telemetry.sample(plainTick('13', '1', 0), 0) === undefined).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      expect(telemetry.sample(plainTick('13', '1', 0), 0) !== undefined).assertTrue();

      // Another display's reading is not this display's, whatever its identity.
      expect(telemetry.sample(plainTick('13', '1', 1), 0) === undefined).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      expect(telemetry.sample(plainTick('13', '1', 1), 1) !== undefined).assertTrue();

      // The engine stops reporting: the rows on screen must not outlive it.
      expect(telemetry.sample(NO_TICK, 1) === undefined).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
      expect(telemetry.sample(VIEWER_TICK, 1) === undefined).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
      expect(telemetry.sample('broken', 1) === undefined).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
      expect(telemetry.sample(plainTick('13', '1', 1), 1) !== undefined).assertTrue();

      // A session that ended reads nothing at all until a binding is set again.
      telemetry.reset();
      expect(telemetry.sample(plainTick('13', '1', 1), 1) === undefined).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
    });

    it('rebuilds Viewer windows on dial, display and lifecycle changes', 0, () => {
      const telemetry = new FrameRateTelemetry();
      expect(telemetry.shouldRead('session:core:epoch-1', 0)).assertTrue();
      telemetry.sample(viewerTick({ elapsedMs: 1000, receivedPackets: 100, submittedFrames: 90 }), 0);
      const measured = telemetry.sample(viewerTick({ elapsedMs: 2000, receivedPackets: 160, submittedFrames: 135 }), 0);
      expect((measured as FrameRateSnapshot).submittedFps).assertEqual(45);

      const newDial = telemetry.sample(viewerTick({
        generation: '2', elapsedMs: 50, receivedPackets: 3, submittedFrames: 2,
      }), 0) as FrameRateSnapshot;
      expect(newDial.measured()).assertFalse();
      expect(newDial.submittedFps === null).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
      const dialWindow = telemetry.sample(viewerTick({
        generation: '2', elapsedMs: 1050, receivedPackets: 63, submittedFrames: 52,
      }), 0) as FrameRateSnapshot;
      expect(dialWindow.submittedFps).assertEqual(50);

      const displayBaseline = telemetry.sample(viewerTick({
        generation: '2', display: 1, elapsedMs: 2050, receivedPackets: 120, submittedFrames: 100,
      }), 1) as FrameRateSnapshot;
      expect(displayBaseline.measured()).assertFalse();
      expect(displayBaseline.receivedFps === null).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      const displayWindow = viewerTick({
        generation: '2', display: 1, elapsedMs: 3050, receivedPackets: 180, submittedFrames: 150,
      });
      expect((telemetry.sample(displayWindow, 1) as FrameRateSnapshot).submittedFps).assertEqual(50);

      // Same session/core id, but another lifecycle must not reuse this window.
      expect(telemetry.shouldRead('session:core:epoch-2', 4000)).assertTrue();
      const nextLifecycle = telemetry.sample(displayWindow, 1) as FrameRateSnapshot;
      expect(nextLifecycle.measured()).assertFalse();
      expect(nextLifecycle.submittedFps === null).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
    });

    it('clears Viewer FPS outside streaming and requires a fresh streaming baseline', 0, () => {
      const telemetry = new FrameRateTelemetry();
      telemetry.shouldRead('viewer:epoch-1', 0);
      telemetry.sample(viewerTick({ elapsedMs: 1000, receivedPackets: 100, submittedFrames: 90 }), 0);
      telemetry.sample(viewerTick({ elapsedMs: 2000, receivedPackets: 160, submittedFrames: 135 }), 0);
      const idle = telemetry.sample(viewerTick({
        status: 'opening_surface', elapsedMs: 3000, receivedPackets: 170, submittedFrames: 140,
      }), 0) as FrameRateSnapshot;
      expect(idle.measured()).assertFalse();
      expect(idle.submittedFps === null).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
      const resumed = telemetry.sample(viewerTick({
        elapsedMs: 4000, receivedPackets: 220, submittedFrames: 180,
      }), 0) as FrameRateSnapshot;
      expect(resumed.measured()).assertFalse();
      expect(resumed.receivedFps === null).assertTrue();
      const next = telemetry.sample(viewerTick({
        elapsedMs: 5000, receivedPackets: 280, submittedFrames: 230,
      }), 0) as FrameRateSnapshot;
      expect(next.receivedFps).assertEqual(60);
      expect(next.submittedFps).assertEqual(50);
    });

    it('does not turn stalled time, reversed time or counter rollback into a Viewer rate', 0, () => {
      const telemetry = new FrameRateTelemetry();
      telemetry.shouldRead('viewer:epoch-1', 0);
      telemetry.sample(viewerTick({ elapsedMs: 1000, receivedPackets: 100, submittedFrames: 90 }), 0);
      const stalled = telemetry.sample(viewerTick({
        elapsedMs: 1000, receivedPackets: 100, submittedFrames: 90,
      }), 0) as FrameRateSnapshot;
      expect(stalled.measured()).assertFalse();
      expect(stalled.submittedFps === null).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      const reversed = telemetry.sample(viewerTick({
        elapsedMs: 900, receivedPackets: 100, submittedFrames: 90,
      }), 0) as FrameRateSnapshot;
      expect(reversed.measured()).assertFalse();
      expect(reversed.receivedFps === null).assertTrue();
      const forward = telemetry.sample(viewerTick({
        elapsedMs: 1900, receivedPackets: 160, submittedFrames: 140,
      }), 0) as FrameRateSnapshot;
      expect(forward.submittedFps).assertEqual(50);
      const rollback = telemetry.sample(viewerTick({
        elapsedMs: 2900, receivedPackets: 10, submittedFrames: 145,
      }), 0) as FrameRateSnapshot;
      expect(rollback.measured()).assertFalse();
      expect(rollback.receivedFps === null).assertTrue();
      expect(rollback.submittedFps === null).assertTrue();
      const rebuilt = telemetry.sample(viewerTick({
        elapsedMs: 3900, receivedPackets: 70, submittedFrames: 195,
      }), 0) as FrameRateSnapshot;
      expect(rebuilt.receivedFps).assertEqual(60);
      expect(rebuilt.submittedFps).assertEqual(50);
    });
  });

  describe('QualityTelemetry', () => {
    it('folds batched quality events without erasing what another batch measured', 0, () => {
      // The status tick and the delay receipt arrive as separate events, and
      // each leaves out the half it did not measure.
      const tick: QualityStatusFields = {
        speed: '123.45kB/s',
        delay: '',
        targetBitrate: '',
        codec: 'H265',
      };
      const receipt: QualityStatusFields = {
        speed: '',
        delay: '23',
        targetBitrate: '8000',
        codec: '',
      };
      const first = mergeQualityStatus(emptyQualityTelemetry(), tick);
      expect(first.receiveBandwidthKBs).assertEqual('123.45');
      expect(first.codec).assertEqual('H265');
      expect(first.networkRttMs).assertEqual('');
      expect(first.targetBitrateKbps).assertEqual('');

      const merged = mergeQualityStatus(first, receipt);
      expect(merged.networkRttMs).assertEqual('23');
      expect(merged.targetBitrateKbps).assertEqual('8000');
      // The receipt carried no bandwidth and no codec, so both survive it.
      expect(merged.receiveBandwidthKBs).assertEqual('123.45');
      expect(merged.codec).assertEqual('H265');

      // An event that carried nothing changes nothing.
      const empty: QualityStatusFields = { speed: '', delay: '', targetBitrate: '', codec: '' };
      const unchanged = mergeQualityStatus(merged, empty);
      expect(unchanged.networkRttMs).assertEqual('23');
      expect(unchanged.receiveBandwidthKBs).assertEqual('123.45');
      expect(unchanged.targetBitrateKbps).assertEqual('8000');
      expect(unchanged.codec).assertEqual('H265');

      // A measured zero is a measurement and is kept as one.
      const zeroes = mergeQualityStatus(merged, {
        speed: '0.00kB/s',
        delay: '0',
        targetBitrate: '0',
        codec: '',
      });
      expect(zeroes.receiveBandwidthKBs).assertEqual('0.00');
      expect(zeroes.networkRttMs).assertEqual('0');
      expect(zeroes.targetBitrateKbps).assertEqual('0');

      // A field this build cannot read keeps the previous reading instead of
      // replacing it with a value nobody measured.
      const unreadable = mergeQualityStatus(zeroes, {
        speed: '12MB/s',
        delay: '9007199254740992',
        targetBitrate: 'fast',
        codec: '',
      });
      expect(unreadable.receiveBandwidthKBs).assertEqual('0.00');
      expect(unreadable.networkRttMs).assertEqual('0');
      expect(unreadable.targetBitrateKbps).assertEqual('0');
      expect(mergeQualityStatus(zeroes, {
        speed: '-1kB/s',
        delay: '23.5',
        targetBitrate: '',
        codec: '',
      }).networkRttMs).assertEqual('0');
    });

    it('applies a frame snapshot to the frame rows and leaves the session fields alone', 0, () => {
      const measured = parseFrameRateSnapshot(plainTick('12', '7', 0)) as FrameRateSnapshot;
      const applied = applyFrameRateSnapshot(emptyQualityTelemetry(), measured, '90');
      expect(applied.submittedFps).assertEqual('45');
      expect(applied.receivedFps).assertEqual('59');
      expect(applied.queuedUnits).assertEqual('0');
      expect(applied.requestedFps).assertEqual('90');

      // A session that has been running: the network rows survive a new frame reading.
      const running = mergeQualityStatus(applied, {
        speed: '123.45kB/s',
        delay: '23',
        targetBitrate: '8000',
        codec: 'H265',
      });
      const refreshed = applyFrameRateSnapshot(running, measured, '90');
      expect(refreshed.networkRttMs).assertEqual('23');
      expect(refreshed.receiveBandwidthKBs).assertEqual('123.45');
      expect(refreshed.targetBitrateKbps).assertEqual('8000');

      // A reading with no counters clears the frame rows rather than showing
      // zeros, and still keeps the session's own numbers.
      const unavailable = parseFrameRateSnapshot(NO_TICK) as FrameRateSnapshot;
      const cleared = applyFrameRateSnapshot(running, unavailable, '90');
      expect(cleared.submittedFps).assertEqual('');
      expect(cleared.receivedFps).assertEqual('');
      expect(cleared.queuedUnits).assertEqual('');
      expect(cleared.networkRttMs).assertEqual('23');
      expect(cleared.receiveBandwidthKBs).assertEqual('123.45');
      expect(cleared.targetBitrateKbps).assertEqual('8000');
      expect(cleared.codec).assertEqual('H265');

      // The reset the sampler asks for clears exactly the same rows.
      const reset: QualityTelemetry = clearQualityFrameMetrics(running);
      expect(reset.submittedFps).assertEqual('');
      expect(reset.receivedFps).assertEqual('');
      expect(reset.queuedUnits).assertEqual('');
      expect(reset.requestedFps).assertEqual('90');
      expect(reset.codec).assertEqual('H265');
      expect(reset.networkRttMs).assertEqual('23');
      expect(reset.receiveBandwidthKBs).assertEqual('123.45');
      expect(reset.targetBitrateKbps).assertEqual('8000');

      // Nothing measured yet is empty everywhere, which the panel shows as `--`.
      const empty = emptyQualityTelemetry();
      expect(empty.submittedFps).assertEqual('');
      expect(empty.requestedFps).assertEqual('');
      expect(empty.receivedFps).assertEqual('');
      expect(empty.queuedUnits).assertEqual('');
      expect(empty.codec).assertEqual('');
      expect(empty.networkRttMs).assertEqual('');
      expect(empty.receiveBandwidthKBs).assertEqual('');
      expect(empty.targetBitrateKbps).assertEqual('');
    });

    it('publishes Viewer codec, queue and RTT before FPS, and clears unknown facts without inventing values', 0, () => {
      const running = mergeQualityStatus(emptyQualityTelemetry(), {
        speed: '123.45kB/s',
        delay: '23',
        targetBitrate: '8000',
        codec: 'H265',
      });
      const telemetry = new FrameRateTelemetry();
      telemetry.shouldRead('viewer:epoch-1', 0);
      const baseline = telemetry.sample(viewerTick({
        elapsedMs: 1000, receivedPackets: 60, submittedFrames: 44,
        codec: 'H264', queuedUnits: 2, networkRttMs: 31,
      }), 0) as FrameRateSnapshot;
      const applied = applyFrameRateSnapshot(running, baseline, '60');
      expect(applied.submittedFps).assertEqual('');
      expect(applied.receivedFps).assertEqual('');
      expect(applied.queuedUnits).assertEqual('2');
      expect(applied.requestedFps).assertEqual('60');
      expect(applied.networkRttMs).assertEqual('31');
      expect(applied.codec).assertEqual('H264');
      expect(applied.receiveBandwidthKBs).assertEqual('123.45');
      expect(applied.targetBitrateKbps).assertEqual('8000');

      const zero = telemetry.sample(viewerTick({
        elapsedMs: 2000, receivedPackets: 60, submittedFrames: 44, networkRttMs: 31,
      }), 0) as FrameRateSnapshot;
      const zeroed = applyFrameRateSnapshot(applied, zero, '60');
      expect(zeroed.submittedFps).assertEqual('0');
      expect(zeroed.receivedFps).assertEqual('0');
      expect(zeroed.queuedUnits).assertEqual('0');

      const idle = telemetry.sample(viewerTick({
        status: 'closing', elapsedMs: 3000, receivedPackets: 60, submittedFrames: 44,
        codec: '', queuedUnits: null, networkRttMs: null,
      }), 0) as FrameRateSnapshot;
      const cleared = applyFrameRateSnapshot(zeroed, idle, '60');
      expect(cleared.submittedFps).assertEqual('');
      expect(cleared.receivedFps).assertEqual('');
      expect(cleared.queuedUnits).assertEqual('');
      expect(cleared.networkRttMs).assertEqual('');
      expect(cleared.codec).assertEqual('');

      // Proto3 default 0 is not evidence of a measured RTT on this producer.
      const noRtt = parseFrameRateSnapshot(viewerTick({
        elapsedMs: 3000, receivedPackets: 60, submittedFrames: 44, networkRttMs: 0,
      })) as FrameRateSnapshot;
      expect(noRtt.networkRttMs === null).assertTrue();
    });
  });
}
