import { describe, expect, it } from '@ohos/hypium';
import {
  hasSoftwarePresentActivity,
  hasRetainedSoftwareSubmission,
  isSoftwarePresentCodec,
  parseSoftwarePresentState,
  shouldSelectSoftwarePresent,
  SoftwarePresentObserver,
  SoftwarePresentSnapshot,
} from '../../../main/ets/services/SoftwarePresentState';

function submitted(generation: string, count: number): string {
  const state = new SoftwarePresentSnapshot();
  state.generation = generation;
  state.bound = true;
  state.state = 'submitted';
  state.width = 1920;
  state.height = 1080;
  state.submittedFrames = count;
  state.reason = 'submitted';
  return JSON.stringify(state);
}

export default function softwarePresentStateTest(): void {
  describe('SoftwarePresentState', () => {
    it('requires truthful submitted metadata and fails closed on malformed or copied claims', 0, () => {
      const state = parseSoftwarePresentState(submitted('7', 1));
      expect(state.state).assertEqual('submitted');
      expect(state.width).assertEqual(1920);
      expect(state.zeroCopyProven).assertFalse();
      expect(hasSoftwarePresentActivity(state)).assertTrue();
      // Same Surface/generation retains its old VP9 submission after H264 switch.
      expect(shouldSelectSoftwarePresent('VP9', state)).assertTrue();
      expect(shouldSelectSoftwarePresent('H264', state)).assertFalse();
      expect(shouldSelectSoftwarePresent('H265', state)).assertFalse();
      expect(shouldSelectSoftwarePresent('Unknown', state)).assertTrue();
      state.state = 'unavailable';
      state.reason = 'no_buffer';
      expect(hasRetainedSoftwareSubmission(state)).assertTrue();
      expect(shouldSelectSoftwarePresent('Unknown', state)).assertTrue();
      expect(shouldSelectSoftwarePresent('H264', state)).assertFalse();
      state.reason = 'busy';
      expect(hasRetainedSoftwareSubmission(state)).assertTrue();
      expect(state.width).assertEqual(1920);
      expect(state.height).assertEqual(1080);
      state.submittedFrames = 0;
      expect(hasRetainedSoftwareSubmission(state)).assertFalse();
      expect(shouldSelectSoftwarePresent('Unknown', state)).assertFalse();
      state.state = 'submitted';
      state.reason = 'submission_only';
      state.submittedFrames = 1;
      expect(parseSoftwarePresentState(submitted('7', 0)).bound).assertFalse();
      expect(parseSoftwarePresentState(submitted('', 1)).bound).assertFalse();
      expect(parseSoftwarePresentState('not json').bound).assertFalse();
      expect(parseSoftwarePresentState('{}').bound).assertFalse();
      state.zeroCopyProven = true;
      expect(parseSoftwarePresentState(JSON.stringify(state)).bound).assertFalse();
      state.zeroCopyProven = false;
      state.reason = 'private pointer 0x123';
      expect(parseSoftwarePresentState(JSON.stringify(state)).bound).assertFalse();
      state.reason = 'waiting';
      state.state = 'waiting';
      state.submittedFrames = 0;
      expect(parseSoftwarePresentState(JSON.stringify(state)).state).assertEqual('waiting');
      expect(hasSoftwarePresentActivity(state)).assertFalse();
      state.state = 'failed';
      state.reason = 'target_failed';
      expect(hasSoftwarePresentActivity(state)).assertTrue();
      expect(hasRetainedSoftwareSubmission(state)).assertFalse();
      expect(shouldSelectSoftwarePresent('H264', state)).assertFalse();
      expect(shouldSelectSoftwarePresent('H265', state)).assertFalse();
      expect(shouldSelectSoftwarePresent('Unknown', state)).assertFalse();
      expect(shouldSelectSoftwarePresent('VP9', state)).assertTrue();
      state.reason = 'retirement_failed';
      expect(hasSoftwarePresentActivity(state)).assertFalse();
      state.bound = false;
      expect(parseSoftwarePresentState(JSON.stringify(state)).state).assertEqual('unavailable');
      expect(isSoftwarePresentCodec('VP8')).assertTrue();
      expect(isSoftwarePresentCodec('VP9')).assertTrue();
      expect(isSoftwarePresentCodec('AV1')).assertTrue();
      expect(isSoftwarePresentCodec('H264')).assertFalse();
      expect(isSoftwarePresentCodec('H265')).assertFalse();
      expect(isSoftwarePresentCodec('Unknown')).assertFalse();
    });

    it('coalesces metadata without frame pacing and rejects cancelled binding observations', 0, () => {
      const observer = new SoftwarePresentObserver();
      expect(observer.shouldPoll(0)).assertFalse();
      observer.selectBinding('surface_a');
      const oldToken = observer.token();
      expect(observer.shouldPoll(0)).assertTrue();
      expect(observer.shouldPoll(16)).assertFalse();
      expect(observer.shouldPoll(99)).assertFalse();
      expect(observer.selectBinding('surface_a')).assertFalse();
      expect(observer.shouldPoll(100)).assertTrue();
      const waiting = parseSoftwarePresentState(submitted('7', 1));
      waiting.state = 'waiting';
      waiting.reason = 'waiting_for_frame';
      waiting.submittedFrames = 0;
      expect(hasSoftwarePresentActivity(observer.accept(JSON.stringify(waiting), oldToken)
        ?? new SoftwarePresentSnapshot())).assertFalse();
      expect(observer.accept(submitted('7', 100), oldToken)?.submittedFrames).assertEqual(100);
      const pressure = parseSoftwarePresentState(submitted('7', 100));
      pressure.state = 'unavailable';
      pressure.reason = 'no_buffer';
      const retained = observer.accept(JSON.stringify(pressure), oldToken) ?? new SoftwarePresentSnapshot();
      expect(hasRetainedSoftwareSubmission(retained)).assertTrue();
      expect(retained.width).assertEqual(1920);
      expect(retained.height).assertEqual(1080);
      expect(shouldSelectSoftwarePresent('H265', retained)).assertFalse();
      expect(observer.accept(submitted('7', 99), oldToken)?.state).assertEqual('unavailable');
      expect(observer.accept(submitted('8', 1), oldToken)?.state).assertEqual('unavailable');
      expect(observer.accept(submitted('7', 101), oldToken)?.state).assertEqual('submitted');
      expect(observer.accept('', oldToken)?.state).assertEqual('unavailable');
      expect(observer.accept(submitted('8', 102), oldToken)?.state).assertEqual('unavailable');
      observer.selectBinding('');
      expect(hasRetainedSoftwareSubmission(observer.accept(JSON.stringify(pressure), oldToken)
        ?? new SoftwarePresentSnapshot())).assertFalse();
      expect(observer.accept(submitted('8', 2), oldToken) === undefined).assertTrue();
      observer.selectBinding('surface_b');
      expect(observer.shouldPoll(101)).assertTrue();
      expect(observer.accept(submitted('8', 2), oldToken) === undefined).assertTrue();
      expect(observer.accept(submitted('9', 1), observer.token())?.state).assertEqual('submitted');
      expect(observer.accept('', observer.token())?.state).assertEqual('unavailable');
    });
  });
}
