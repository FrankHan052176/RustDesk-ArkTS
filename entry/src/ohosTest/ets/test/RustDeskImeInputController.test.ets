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

    it('does not send pinyin preview text before the Chinese commit', 0, () => {
      const controller = new RustDeskImeInputController();
      const composingZ = `${RUSTDESK_IME_INITIAL_TEXT}z`;
      const first = controller.applyTextChange(
        composingZ,
        RUSTDESK_IME_INITIAL_TEXT.length,
        'z',
        RUSTDESK_IME_INITIAL_TEXT,
      );
      expect(first.insertedText).assertEqual('');
      expect(first.localText).assertEqual(composingZ);

      const composingZe = `${RUSTDESK_IME_INITIAL_TEXT}z'e`;
      const second = controller.applyTextChange(
        composingZe,
        RUSTDESK_IME_INITIAL_TEXT.length,
        "z'e",
        composingZ,
        RUSTDESK_IME_INITIAL_TEXT.length,
        'z',
      );
      expect(second.insertedText).assertEqual('');
      expect(second.backspaceCount).assertEqual(0);
      expect(second.localText).assertEqual(composingZe);

      const committed = controller.applyTextChange(
        `${RUSTDESK_IME_INITIAL_TEXT}这`,
        RUSTDESK_IME_INITIAL_TEXT.length + 1,
        '',
        composingZe,
        RUSTDESK_IME_INITIAL_TEXT.length,
        "z'e",
      );
      expect(committed.insertedText).assertEqual('这');
      expect(committed.backspaceCount).assertEqual(0);
    });

    it('keeps ordinary ASCII input ordered outside composition', 0, () => {
      const controller = new RustDeskImeInputController();
      const first = controller.applyTextChange(`${RUSTDESK_IME_INITIAL_TEXT}z`, -1, '');
      const second = controller.applyTextChange(`${RUSTDESK_IME_INITIAL_TEXT}z'e`, -1, '');
      expect(first.insertedText).assertEqual('z');
      expect(second.insertedText).assertEqual("'e");
      expect(second.backspaceCount).assertEqual(0);
    });

    it('handles preview offsets after a supplementary unicode prefix', 0, () => {
      const controller = new RustDeskImeInputController();
      const prefix = `${RUSTDESK_IME_INITIAL_TEXT}😀`;
      const prefixDelta = controller.applyTextChange(prefix, -1, '');
      expect(prefixDelta.insertedText).assertEqual('😀');

      const composing = `${prefix}zhong`;
      const previewDelta = controller.applyTextChange(
        composing,
        prefix.length,
        'zhong',
        prefix,
      );
      expect(previewDelta.insertedText).assertEqual('');
      expect(previewDelta.localText).assertEqual(composing);

      const committed = controller.applyTextChange(
        `${prefix}中`,
        -1,
        '',
        composing,
        prefix.length,
        'zhong',
      );
      expect(committed.insertedText).assertEqual('中');
      expect(committed.backspaceCount).assertEqual(0);
    });

    it('does not emit stale text when composition is cancelled', 0, () => {
      const controller = new RustDeskImeInputController();
      const composing = `${RUSTDESK_IME_INITIAL_TEXT}zhong`;
      controller.applyTextChange(
        composing,
        RUSTDESK_IME_INITIAL_TEXT.length,
        'zhong',
        RUSTDESK_IME_INITIAL_TEXT,
      );
      const cancelled = controller.applyTextChange(
        RUSTDESK_IME_INITIAL_TEXT,
        -1,
        '',
        composing,
        RUSTDESK_IME_INITIAL_TEXT.length,
        'zhong',
      );
      expect(cancelled.insertedText).assertEqual('');
      expect(cancelled.backspaceCount).assertEqual(0);
    });
  });
}
