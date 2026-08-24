export const RUSTDESK_IME_INITIAL_TEXT: string = '1'.repeat(1024);

export class RustDeskImeInputDelta {
  backspaceCount: number;
  insertedText: string;
  localText: string;

  constructor(backspaceCount: number, insertedText: string, localText: string) {
    this.backspaceCount = backspaceCount;
    this.insertedText = insertedText;
    this.localText = localText;
  }
}

/**
 * Converts the committed value of a hidden ArkUI TextInput into remote editing
 * operations. The leading sentinel keeps Backspace observable even when the
 * user has not entered local text yet, matching RustDesk Flutter's mobile IME
 * bridge. Preview/composing text is deliberately excluded by the caller.
 */
export class RustDeskImeInputController {
  private committedText: string = RUSTDESK_IME_INITIAL_TEXT;
  private sentinelPrefixLength: number = RUSTDESK_IME_INITIAL_TEXT.length;

  reset(): string {
    this.committedText = RUSTDESK_IME_INITIAL_TEXT;
    this.sentinelPrefixLength = RUSTDESK_IME_INITIAL_TEXT.length;
    return this.committedText;
  }

  currentText(): string {
    return this.committedText;
  }

  applyTextChange(value: string, previewOffset: number, previewValue: string,
    oldContent?: string, oldPreviewOffset: number = -1, oldPreviewValue: string = ''): RustDeskImeInputDelta {
    const committedValue = this.withoutPreviewText(value, previewOffset, previewValue);
    const oldCommittedValue = oldContent === undefined
      ? undefined
      : this.withoutPreviewText(oldContent, oldPreviewOffset, oldPreviewValue);
    const delta = this.applyCommittedText(committedValue, oldCommittedValue);
    // Keep ArkUI's complete local value, including the current composing range,
    // bound to TextInput. Replacing it with the committed-only value while an
    // IME is composing moves the insertion point and can reorder pinyin.
    delta.localText = value;
    return delta;
  }

  applyCommittedText(value: string, oldContent?: string): RustDeskImeInputDelta {
    if (value === this.committedText && oldContent !== undefined && oldContent !== this.committedText) {
      return new RustDeskImeInputDelta(0, '', this.committedText);
    }
    let previous = oldContent ?? this.committedText;
    this.committedText = value;

    const previousSentinelLength = Math.min(this.sentinelPrefixLength, previous.length);
    const previousSentinel = previous.substring(0, previousSentinelLength);
    const keepsWholeSentinel = value.length >= previousSentinelLength
      && value.substring(0, previousSentinelLength) === previousSentinel;
    const shortensSentinel = value.length < previousSentinelLength
      && previousSentinel.substring(0, value.length) === value;

    // If an input method replaces the entire hidden value, only the actual
    // remote mirror after the sentinel needs deleting; the sentinel itself was
    // never inserted remotely.
    if (previousSentinelLength > 0 && value.length > 0
      && !keepsWholeSentinel && !shortensSentinel) {
      previous = previous.substring(previousSentinelLength);
      this.sentinelPrefixLength = 0;
    } else if (shortensSentinel) {
      this.sentinelPrefixLength = value.length;
    } else if (keepsWholeSentinel) {
      this.sentinelPrefixLength = previousSentinelLength;
    } else if (value.length === 0) {
      this.sentinelPrefixLength = 0;
    }

    const commonPrefixLength = this.commonPrefixLength(previous, value);
    const removedText = previous.substring(commonPrefixLength);
    const insertedText = value.substring(commonPrefixLength);
    const backspaceCount = this.unicodeCodePointLength(removedText);

    return new RustDeskImeInputDelta(backspaceCount, insertedText, this.committedText);
  }

  private commonPrefixLength(left: string, right: string): number {
    const limit = Math.min(left.length, right.length);
    let index = 0;
    while (index < limit && left.charCodeAt(index) === right.charCodeAt(index)) {
      index += 1;
    }
    // Do not split a surrogate pair when two emoji share the same high surrogate.
    if (index > 0 && index < left.length && index < right.length
      && this.isHighSurrogate(left.charCodeAt(index - 1))) {
      index -= 1;
    }
    return index;
  }

  private withoutPreviewText(value: string, previewOffset: number, previewValue: string): string {
    if (previewValue.length === 0) {
      return value;
    }
    const start = previewOffset;
    const end = start + previewValue.length;
    if (start < 0 || end > value.length || value.substring(start, end) !== previewValue) {
      return value;
    }
    return `${value.substring(0, start)}${value.substring(end)}`;
  }

  private unicodeCodePointLength(value: string): number {
    let count = 0;
    for (let index = 0; index < value.length; index += 1) {
      const first = value.charCodeAt(index);
      if (this.isHighSurrogate(first) && index + 1 < value.length
        && this.isLowSurrogate(value.charCodeAt(index + 1))) {
        index += 1;
      }
      count += 1;
    }
    return count;
  }

  private isHighSurrogate(value: number): boolean {
    return value >= 0xD800 && value <= 0xDBFF;
  }

  private isLowSurrogate(value: number): boolean {
    return value >= 0xDC00 && value <= 0xDFFF;
  }
}
