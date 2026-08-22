import { describe, expect, it } from '@ohos/hypium';
import {
  RUSTDESK_IME_INITIAL_TEXT,
  RustDeskImeInputController,
} from '../../../main/ets/pages/rustdesk/RustDeskImeInputController';

export default function rustDeskImeInputControllerTest(): void {
  describe('RustDeskImeInputControllerTest', () => {
    it('sends only committed text appended after the sentinel', 0, () => {
      const controller = new RustDeskImeInputController();

      const composing = controller.applyCommittedText(RUSTDESK_IME_INITIAL_TEXT);
      expect(composing.backspaceCount).assertEqual(0);
      expect(composing.insertedText).assertEqual('');

      const committed = controller.applyCommittedText(`${RUSTDESK_IME_INITIAL_TEXT}你好`);
      expect(committed.backspaceCount).assertEqual(0);
      expect(committed.insertedText).assertEqual('你好');
      expect(committed.localText).assertEqual(`${RUSTDESK_IME_INITIAL_TEXT}你好`);
    });

    it('turns deletions and replacements into remote backspaces plus text', 0, () => {
      const controller = new RustDeskImeInputController();
      controller.applyCommittedText(`${RUSTDESK_IME_INITIAL_TEXT}hello`);

      const replaced = controller.applyCommittedText(`${RUSTDESK_IME_INITIAL_TEXT}hi`);
      expect(replaced.backspaceCount).assertEqual(4);
      expect(replaced.insertedText).assertEqual('i');
    });

    it('keeps consecutive backspaces observable inside the sentinel reservoir', 0, () => {
      const controller = new RustDeskImeInputController();
      const afterFirst = RUSTDESK_IME_INITIAL_TEXT.substring(0, RUSTDESK_IME_INITIAL_TEXT.length - 1);
      const afterSecond = afterFirst.substring(0, afterFirst.length - 1);

      const firstBackspace = controller.applyCommittedText(afterFirst);
      expect(firstBackspace.backspaceCount).assertEqual(1);
      expect(firstBackspace.localText).assertEqual(afterFirst);

      const secondBackspace = controller.applyCommittedText(afterSecond);
      expect(secondBackspace.backspaceCount).assertEqual(1);
      expect(secondBackspace.localText).assertEqual(afterSecond);
    });

    it('deletes mirrored remote text but not the sentinel on full replacement', 0, () => {
      const controller = new RustDeskImeInputController();
      controller.applyCommittedText(`${RUSTDESK_IME_INITIAL_TEXT}hello`);

      const replaced = controller.applyCommittedText('world');
      expect(replaced.backspaceCount).assertEqual(5);
      expect(replaced.insertedText).assertEqual('world');
    });

    it('counts a supplementary unicode character as one backspace', 0, () => {
      const controller = new RustDeskImeInputController();
      controller.applyCommittedText(`${RUSTDESK_IME_INITIAL_TEXT}😀`);

      const removed = controller.applyCommittedText(RUSTDESK_IME_INITIAL_TEXT);
      expect(removed.backspaceCount).assertEqual(1);
      expect(removed.insertedText).assertEqual('');
    });
  });
}
