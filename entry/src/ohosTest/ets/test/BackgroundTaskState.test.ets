import { describe, expect, it } from '@ohos/hypium';
import { BackgroundTaskState } from '../../../main/ets/services/BackgroundTaskState';

export default function backgroundTaskStateTest(): void {
  describe('BackgroundTaskStateTest', () => {
    it('keeps transfer and audio task identifiers isolated', 0, () => {
      const state = new BackgroundTaskState();
      state.setTransferTaskId(11);
      state.setAudioTaskId(12);
      expect(state.taskIdFor('transfer')).assertEqual(11);
      expect(state.taskIdFor('audio')).assertEqual(12);

      state.clearTransfer();
      expect(state.taskIdFor('transfer')).assertEqual(-1);
      expect(state.taskIdFor('audio')).assertEqual(12);
    });

    it('does not clear an unrelated transfer task with audio state', 0, () => {
      const state = new BackgroundTaskState();
      state.setTransferTaskId(11);
      state.setAudioTaskId(12);
      state.clearAudio();
      expect(state.taskIdFor('transfer')).assertEqual(11);
      expect(state.taskIdFor('audio')).assertEqual(-1);
    });
  });
}
