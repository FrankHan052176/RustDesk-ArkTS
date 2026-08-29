import { ChatMessage } from './RustDeskSessionTypes';

export class ChatStore {
  private items: ChatMessage[] = [];
  private unread: number = 0;
  private nextLocalNonce: number = 1;

  send(text: string, now: number): ChatMessage | undefined {
    const trimmedText = text.trim();
    if (trimmedText.length === 0) {
      return undefined;
    }

    const message: ChatMessage = {
      localId: this.createLocalId(),
      text: trimmedText,
      sentAt: now,
      outgoing: true,
      state: 'pending',
    };
    this.items.push(message);
    return message;
  }

  markSent(localId: string): void {
    const message = this.findMessage(localId);
    if (message && message.outgoing) {
      message.state = 'sent';
    }
  }

  markFailed(localId: string): void {
    const message = this.findMessage(localId);
    if (message && message.outgoing) {
      message.state = 'failed';
    }
  }

  receive(text: string, now: number): ChatMessage {
    const message: ChatMessage = {
      localId: this.createLocalId(),
      text,
      sentAt: now,
      outgoing: false,
      state: 'sent',
    };
    this.items.push(message);
    this.unread++;
    return message;
  }

  retry(localId: string): ChatMessage | undefined {
    const message = this.findMessage(localId);
    if (!message || !message.outgoing || message.state !== 'failed') {
      return undefined;
    }

    message.state = 'pending';
    return message;
  }

  messages(): ChatMessage[] {
    return this.items.slice();
  }

  unreadCount(): number {
    return this.unread;
  }

  markRead(): void {
    this.unread = 0;
  }

  clear(): void {
    this.items = [];
    this.unread = 0;
  }

  restore(messages: ChatMessage[], unread: number): void {
    this.items = messages.slice();
    this.unread = Math.max(Math.min(Math.floor(unread), this.items.length), 0);
    let nextNonce = 1;
    for (const message of this.items) {
      const parsed = Number(message.localId);
      if (Number.isFinite(parsed)) {
        nextNonce = Math.max(nextNonce, Math.floor(parsed) + 1);
      }
    }
    this.nextLocalNonce = nextNonce;
  }

  private createLocalId(): string {
    const localId = String(this.nextLocalNonce);
    this.nextLocalNonce++;
    return localId;
  }

  private findMessage(localId: string): ChatMessage | undefined {
    for (let index = 0; index < this.items.length; index++) {
      if (this.items[index].localId === localId) {
        return this.items[index];
      }
    }
    return undefined;
  }
}
