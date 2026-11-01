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

/** The VNC/RDP wire before it has a frame-rate sample: nothing measured. */
const VIEWER_TICK = '{"available":true,"source":"engine_viewer_snapshot","protocol":"vnc",'
  + '"status":"connected","route":"direct","width":1920,"height":1080,"authenticated":true,'
  + '"encrypted":true,"peerVerified":true,"keyboardAllowed":true,"inputGeneration":"3",'
  + '"desiredFps":0,"framesAvailable":false,"receivedPackets":null,"decodedFrames":null,'
  + '"submittedFrames":null,"nativeImporter":false,"codec":"","queuedUnits":null}';

/** The fields of one direct-wire snapshot this suite varies. */
interface DirectTick {
  status: string;
  framesAvailable: boolean;
  display?: number;
  receivedFps: string | null;
  submittedFps: string | null;
  queuedUnits: string | null;
}

/**
 * One direct VNC/RDP snapshot, in the shape `session_get_frame_rate_snapshot`
 * writes it: the phase and admission the wire publishes, the rates as decimal
 * strings or null, and the cumulative counters this build does not read.
 */
function directTick(fields: DirectTick): string {
  const display = fields.display === undefined ? 0 : fields.display;
  const rate = (value: string | null): string => value === null ? 'null' : '"' + value + '"';
  return '{"available":true,"source":"engine_viewer_snapshot","protocol":"vnc"'
    + ',"status":"' + fields.status + '"'
    + ',"route":"direct","width":1280,"height":720,"authenticated":true,"encrypted":true'
    + ',"peerVerified":true,"keyboardAllowed":true,"inputGeneration":"3","desiredFps":0'
    + ',"display":' + display
    + ',"framesAvailable":' + (fields.framesAvailable ? 'true' : 'false')
    + ',"receivedUpdates":"1200","decodedFrames":null,"submittedFrames":"900"'
    + ',"nativeImporter":false,"codec":"","queuedUnits":' + rate(fields.queuedUnits)
    + ',"receivedFps":' + rate(fields.receivedFps)
    + ',"submittedFps":' + rate(fields.submittedFps) + '}';
}

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

      // A direct wire before it has a sample counts no frames. Its null
      // counters must not become 0.
      const viewer = parseFrameRateSnapshot(VIEWER_TICK);
      expect(viewer !== undefined).assertTrue();
      expect((viewer as FrameRateSnapshot).kind).assertEqual('engine_viewer');
      expect((viewer as FrameRateSnapshot).measured()).assertFalse();
      expect((viewer as FrameRateSnapshot).receivedFps === null).assertTrue();
      expect((viewer as FrameRateSnapshot).submittedFps === null).assertTrue();
      expect((viewer as FrameRateSnapshot).queuedUnits === null).assertTrue();

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

    it('measures a direct wire only while it streams and admits a real sample', 0, () => {
      const measured = parseFrameRateSnapshot(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '58',
        submittedFps: '44',
        queuedUnits: null,
      }));
      expect(measured !== undefined).assertTrue();
      const reading = measured as FrameRateSnapshot;
      expect(reading.kind).assertEqual('measured');
      expect(reading.measured()).assertTrue();
      // The direct wire decodes one display and names no decoder round or
      // generation, so the reading is bound to its session and display alone.
      expect(reading.display).assertEqual(0);
      expect(reading.round).assertEqual('');
      expect(reading.generation).assertEqual('');
      expect(reading.receivedFps).assertEqual(58);
      expect(reading.submittedFps).assertEqual(44);
      // A direct wire measures no queue depth: absent, never zero.
      expect(reading.queuedUnits === null).assertTrue();

      // A measured zero is still a measurement, and differs from "not measured".
      const zero = parseFrameRateSnapshot(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '0',
        submittedFps: '0',
        queuedUnits: null,
      })) as FrameRateSnapshot;
      expect(zero.kind).assertEqual('measured');
      expect(zero.receivedFps).assertEqual(0);
      expect(zero.submittedFps).assertEqual(0);

      // Half a sample is still a measurement: the rate the engine left out is
      // unknown, not zero, and it does not blank the rate beside it.
      const partial = parseFrameRateSnapshot(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: null,
        submittedFps: '44',
        queuedUnits: null,
      })) as FrameRateSnapshot;
      expect(partial.kind).assertEqual('measured');
      expect(partial.receivedFps === null).assertTrue();
      expect(partial.submittedFps).assertEqual(44);

      // A wire that is not streaming, or that publishes no sample, measured
      // nothing even though its counters are present.
      const idleTicks = [
        directTick({ status: 'opening_surface', framesAvailable: true, receivedFps: '58', submittedFps: '44', queuedUnits: null }),
        directTick({ status: 'streaming', framesAvailable: false, receivedFps: null, submittedFps: null, queuedUnits: null }),
        directTick({ status: 'connecting', framesAvailable: false, receivedFps: null, submittedFps: null, queuedUnits: null }),
      ];
      for (const idle of idleTicks) {
        const viewer = parseFrameRateSnapshot(idle) as FrameRateSnapshot;
        expect(viewer.kind).assertEqual('engine_viewer');
        expect(viewer.measured()).assertFalse();
        expect(viewer.receivedFps === null).assertTrue();
        expect(viewer.submittedFps === null).assertTrue();
      }

      // A sample the wire wrote in a spelling this build cannot read is
      // unknown, never zero.
      const broken = parseFrameRateSnapshot(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '59.5',
        submittedFps: 'nope',
        queuedUnits: null,
      })) as FrameRateSnapshot;
      expect(broken.measured()).assertTrue();
      expect(broken.receivedFps === null).assertTrue();
      expect(broken.submittedFps === null).assertTrue();
    });

    it('rejects a direct sample with a missing or malformed display and keeps a declared one', 0, () => {
      const streaming = directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '58',
        submittedFps: '44',
        queuedUnits: null,
      });
      // The contract always names the display, so a missing or malformed one is
      // an unreadable packet, not a display to relabel as 0.
      const unreadable = [
        streaming.replace('"display":0,', ''),
        streaming.replace('"display":0,', '"display":-1,'),
        streaming.replace('"display":0,', '"display":"0",'),
        streaming.replace('"display":0,', '"display":1.5,'),
      ];
      for (const packet of unreadable) {
        expect(parseFrameRateSnapshot(packet) === undefined).assertTrue();
      }

      // A genuinely declared other display is retained, so a poll for display 0
      // does not consume the reading that belongs to display 1.
      const declared = parseFrameRateSnapshot(directTick({
        status: 'streaming',
        framesAvailable: true,
        display: 1,
        receivedFps: '58',
        submittedFps: '44',
        queuedUnits: null,
      })) as FrameRateSnapshot;
      expect(declared.display).assertEqual(1);
      const telemetry = new FrameRateTelemetry();
      expect(telemetry.shouldRead('direct:vnc', 0)).assertTrue();
      expect(telemetry.sample(directTick({
        status: 'streaming',
        framesAvailable: true,
        display: 1,
        receivedFps: '58',
        submittedFps: '44',
        queuedUnits: null,
      }), 0) === undefined).assertTrue();
      expect(telemetry.sample(directTick({
        status: 'streaming',
        framesAvailable: true,
        display: 1,
        receivedFps: '58',
        submittedFps: '44',
        queuedUnits: null,
      }), 1) !== undefined).assertTrue();
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

    it('publishes a direct wire sample and drops it the moment the wire stops measuring', 0, () => {
      const telemetry = new FrameRateTelemetry();
      expect(telemetry.shouldRead('direct:vnc', 0)).assertTrue();

      // A streaming direct wire publishes its own rates, with no round or
      // generation to tell apart.
      const first = telemetry.sample(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '58',
        submittedFps: '44',
        queuedUnits: null,
      }), 0);
      expect(first !== undefined).assertTrue();
      expect((first as FrameRateSnapshot).submittedFps).assertEqual(44);
      expect(telemetry.consumeFrameReset()).assertFalse();
      expect(telemetry.sample(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '59',
        submittedFps: '45',
        queuedUnits: null,
      }), 0) !== undefined).assertTrue();

      // The wire stops measuring (opening a new surface, or it failed): the rows
      // on screen must not outlive it, and the old rate must not be republished
      // as if it were current.
      expect(telemetry.sample(directTick({
        status: 'opening_surface',
        framesAvailable: false,
        receivedFps: null,
        submittedFps: null,
        queuedUnits: null,
      }), 0) === undefined).assertTrue();
      expect(telemetry.consumeFrameReset()).assertTrue();
      expect(telemetry.consumeFrameReset()).assertFalse();
      expect(telemetry.sample(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '60',
        submittedFps: '46',
        queuedUnits: null,
      }), 0) !== undefined).assertTrue();

      // A different session cannot reuse the last one's rates: the binding
      // resets, so the first sample of the new session is its own.
      expect(telemetry.shouldRead('direct:rdp', 2000)).assertTrue();
      const other = telemetry.sample(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '30',
        submittedFps: '20',
        queuedUnits: null,
      }), 0);
      expect(other !== undefined).assertTrue();
      expect((other as FrameRateSnapshot).receivedFps).assertEqual(30);
      expect((other as FrameRateSnapshot).submittedFps).assertEqual(20);
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
      const viewer = parseFrameRateSnapshot(VIEWER_TICK) as FrameRateSnapshot;
      const cleared = applyFrameRateSnapshot(running, viewer, '90');
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

    it('shows a direct wire\'s own rates and keeps an unmeasured queue row as dashes', 0, () => {
      const running = mergeQualityStatus(emptyQualityTelemetry(), {
        speed: '123.45kB/s',
        delay: '23',
        targetBitrate: '8000',
        codec: 'H265',
      });
      const streaming = parseFrameRateSnapshot(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '58',
        submittedFps: '44',
        queuedUnits: null,
      })) as FrameRateSnapshot;
      const applied = applyFrameRateSnapshot(running, streaming, '60');
      expect(applied.submittedFps).assertEqual('44');
      expect(applied.receivedFps).assertEqual('58');
      // A direct wire measures no queue depth, so the row stays unmeasured --
      // the panel's `--`, not a fabricated 0.
      expect(applied.queuedUnits).assertEqual('');
      expect(applied.requestedFps).assertEqual('60');
      // The session's own numbers survive a direct frame reading.
      expect(applied.networkRttMs).assertEqual('23');
      expect(applied.receiveBandwidthKBs).assertEqual('123.45');
      expect(applied.targetBitrateKbps).assertEqual('8000');
      expect(applied.codec).assertEqual('H265');

      // A measured zero from the wire is a reading and shows as 0, never `--`.
      const zero = parseFrameRateSnapshot(directTick({
        status: 'streaming',
        framesAvailable: true,
        receivedFps: '0',
        submittedFps: '0',
        queuedUnits: null,
      })) as FrameRateSnapshot;
      const zeroed = applyFrameRateSnapshot(running, zero, '60');
      expect(zeroed.submittedFps).assertEqual('0');
      expect(zeroed.receivedFps).assertEqual('0');
      expect(zeroed.queuedUnits).assertEqual('');

      // A wire that stopped measuring clears the frame rows and keeps the rest.
      const idle = parseFrameRateSnapshot(directTick({
        status: 'opening_surface',
        framesAvailable: false,
        receivedFps: null,
        submittedFps: null,
        queuedUnits: null,
      })) as FrameRateSnapshot;
      const cleared = applyFrameRateSnapshot(applied, idle, '60');
      expect(cleared.submittedFps).assertEqual('');
      expect(cleared.receivedFps).assertEqual('');
      expect(cleared.queuedUnits).assertEqual('');
      expect(cleared.networkRttMs).assertEqual('23');
      expect(cleared.codec).assertEqual('H265');
    });
  });
}
