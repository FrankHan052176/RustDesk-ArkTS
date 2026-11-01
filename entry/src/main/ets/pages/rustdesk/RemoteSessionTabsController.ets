import { NativeEvent } from './RustDeskTypes';
import { ServerConfig, SessionDefaults } from './RustDeskDirectoryTypes';
import { DEFAULT_REFRESH_RATE } from './RustDeskRefreshRate';

const MAX_PENDING_PROTECTED_ACTIONS = 128;

export type RemoteSessionKind = 'remote_control' | 'vnc' | 'rdp';

export class RemoteSessionTab {
  sessionId: string = '';
  coreSessionId: string = '';
  /** Native lifecycle epoch (decimal string) for bind/ACK; never a UI guess. */
  lifecycleEpoch: string = '';
  /** Engine input generation (decimal string) the viewer must echo on input. */
  inputGeneration: string = '';
  target: string = '';
  label: string = '';
  kind: RemoteSessionKind = 'remote_control';
  phase: string = 'connecting';
  message: string = '';
  connectionSummary: string = '';
  connected: boolean = false;
  paused: boolean = false;
  needsAttention: boolean = false;
  audioMuted: boolean = true;
  audioPreferenceCaptured: boolean = false;
  uiStateCaptured: boolean = false;
  touchMode: boolean = true;
  relativeMouseMode: boolean = false;
  inputEnabled: boolean = true;
  toolbarExpanded: boolean = true;
  displayIndex: number = 0;
  viewScale: number = 1;
  viewOffsetX: number = 0;
  viewOffsetY: number = 0;
  viewRotation: number = 0;
  refreshRate: number = DEFAULT_REFRESH_RATE;
  sessionDefaults: SessionDefaults = new SessionDefaults();
  serverConfig: ServerConfig = new ServerConfig();
  shareTargetKind: string = 'target';
  rustdeskIdOnly: boolean = false;
  forceRelay: boolean = false;
  peerInfo?: NativeEvent = undefined;
  cursorDataEvents: Array<NativeEvent> = [];
  lastCursorId: string = '';
  pendingEvents: Array<NativeEvent> = [];
  omittedProtectedEvents: number = 0;
  createdAt: number = 0;
  lastActivatedAt: number = 0;

  constructor(sessionId: string, target: string, kind: RemoteSessionKind) {
    this.sessionId = sessionId;
    this.target = target;
    this.label = target;
    this.kind = kind;
    this.createdAt = Date.now();
  }
}

export class RemoteSessionTabSwitch {
  previousSessionId: string = '';
  activeSessionId: string = '';
}

export class RemoteSessionTabsController {
  private tabs: Array<RemoteSessionTab> = [];
  private activeSessionId: string = '';
  private readonly maxSessions: number;
  private activationSequence: number = 0;

  constructor(maxSessions: number = 6) {
    this.maxSessions = Math.max(1, maxSessions);
  }

  count(): number {
    return this.tabs.length;
  }

  canAdd(): boolean {
    return this.tabs.length < this.maxSessions;
  }

  activeId(): string {
    return this.activeSessionId;
  }

  snapshot(): Array<RemoteSessionTab> {
    return this.tabs.slice();
  }

  get(sessionId: string): RemoteSessionTab | undefined {
    return this.tabs.find((tab: RemoteSessionTab) => tab.sessionId === sessionId);
  }

  add(sessionId: string, target: string, kind: RemoteSessionKind): RemoteSessionTab | undefined {
    const existing = this.get(sessionId);
    if (existing !== undefined) {
      this.activate(sessionId);
      return existing;
    }
    if (!this.canAdd()) {
      return undefined;
    }
    const tab = new RemoteSessionTab(sessionId, target, kind);
    this.tabs.push(tab);
    this.activate(sessionId);
    return tab;
  }

  activate(sessionId: string): RemoteSessionTabSwitch | undefined {
    const tab = this.get(sessionId);
    if (tab === undefined) {
      return undefined;
    }
    const result = new RemoteSessionTabSwitch();
    result.previousSessionId = this.activeSessionId;
    result.activeSessionId = sessionId;
    this.activeSessionId = sessionId;
    this.activationSequence += 1;
    tab.lastActivatedAt = this.activationSequence;
    for (const item of this.tabs) {
      item.paused = item.sessionId !== sessionId;
    }
    tab.needsAttention = false;
    return result;
  }

  remove(sessionId: string): string {
    const index = this.tabs.findIndex((tab: RemoteSessionTab) => tab.sessionId === sessionId);
    if (index < 0) {
      return this.activeSessionId;
    }
    const removedActive = this.activeSessionId === sessionId;
    this.tabs.splice(index, 1);
    if (!removedActive) {
      return this.activeSessionId;
    }
    if (this.tabs.length === 0) {
      this.activeSessionId = '';
      return '';
    }
    let fallback = this.tabs[0];
    for (const candidate of this.tabs) {
      if (candidate.lastActivatedAt > fallback.lastActivatedAt) {
        fallback = candidate;
      }
    }
    this.activeSessionId = fallback.sessionId;
    for (const item of this.tabs) {
      item.paused = item.sessionId !== this.activeSessionId;
    }
    return this.activeSessionId;
  }

  markPeerInfo(sessionId: string, event: NativeEvent): void {
    const tab = this.get(sessionId);
    if (tab === undefined) {
      return;
    }
    tab.peerInfo = event;
    tab.connected = true;
    tab.phase = 'connected';
    if (event.hostname !== undefined && event.hostname.trim().length > 0) {
      tab.label = event.hostname.trim();
    }
  }

  cacheCursorEvent(sessionId: string, event: NativeEvent): void {
    const tab = this.get(sessionId);
    if (tab === undefined) {
      return;
    }
    const id = String(event.id ?? '');
    if (id.length === 0) {
      return;
    }
    tab.lastCursorId = id;
    if (event.name !== 'cursor_data') {
      return;
    }
    const existingIndex = tab.cursorDataEvents.findIndex((item: NativeEvent) =>
      String(item.id ?? '') === id);
    if (existingIndex >= 0) {
      tab.cursorDataEvents[existingIndex] = event;
      return;
    }
    tab.cursorDataEvents.push(event);
  }

  cursorDataSnapshot(sessionId: string): Array<NativeEvent> {
    return this.get(sessionId)?.cursorDataEvents.slice() ?? [];
  }

  lastCursorId(sessionId: string): string {
    return this.get(sessionId)?.lastCursorId ?? '';
  }

  markPhase(sessionId: string, phase: string, message: string = ''): void {
    const tab = this.get(sessionId);
    if (tab === undefined) {
      return;
    }
    tab.phase = phase;
    tab.message = message;
    tab.connected = phase === 'connected';
    if (phase === 'failed' || phase === 'closed' || phase === 'awaiting_password') {
      tab.needsAttention = sessionId !== this.activeSessionId;
    }
  }

  enqueue(sessionId: string, event: NativeEvent, needsAttention: boolean = false): void {
    const tab = this.get(sessionId);
    if (tab === undefined) {
      return;
    }
    if (event.name === 'close'
      && tab.pendingEvents.some((item: NativeEvent) => item.name === 'close')) {
      // One terminal event is sufficient and must never be evicted.
    } else {
      if (event.name === 'switch_display') {
        const previousSwitch = tab.pendingEvents.findIndex((item: NativeEvent) =>
          item.name === 'switch_display');
        if (previousSwitch >= 0) {
          tab.pendingEvents.splice(previousSwitch, 1);
        }
      }
      tab.pendingEvents.push(event);
    }
    while (this.pendingReplaceableActionCount(tab) > 64) {
      const oldestReplaceable = tab.pendingEvents.findIndex((item: NativeEvent) =>
        !this.isProtectedAction(item));
      if (oldestReplaceable < 0) {
        break;
      }
      tab.pendingEvents.splice(oldestReplaceable, 1);
    }
    while (this.pendingProtectedActionCount(tab) > MAX_PENDING_PROTECTED_ACTIONS) {
      const oldestProtected = tab.pendingEvents.findIndex((item: NativeEvent) =>
        this.isProtectedAction(item) && item.name !== 'close');
      if (oldestProtected < 0) {
        break;
      }
      tab.pendingEvents.splice(oldestProtected, 1);
      tab.omittedProtectedEvents += 1;
    }
    if (needsAttention) {
      tab.needsAttention = true;
    }
  }

  takePendingEvents(sessionId: string): Array<NativeEvent> {
    const tab = this.get(sessionId);
    if (tab === undefined) {
      return [];
    }
    const events = tab.pendingEvents.slice();
    if (tab.omittedProtectedEvents > 0) {
      const marker: NativeEvent = {
        name: 'msgbox',
        type: 'warning',
        title: '后台事件已截断',
        text: `${tab.omittedProtectedEvents} 条较早后台提醒已省略`,
      };
      const firstProtected = events.findIndex((item: NativeEvent) => this.isProtectedAction(item));
      events.splice(firstProtected < 0 ? 0 : firstProtected, 0, marker);
    }
    tab.pendingEvents = [];
    tab.omittedProtectedEvents = 0;
    return events;
  }

  private isProtectedAction(event: NativeEvent): boolean {
    return event.name === 'close' || event.name === 'msgbox' || event.name === 'switch_display'
      || event.name === 'resolution_refused';
  }

  private pendingReplaceableActionCount(tab: RemoteSessionTab): number {
    let count = 0;
    for (const event of tab.pendingEvents) {
      if (!this.isProtectedAction(event)) {
        count += 1;
      }
    }
    return count;
  }

  private pendingProtectedActionCount(tab: RemoteSessionTab): number {
    let count = 0;
    for (const event of tab.pendingEvents) {
      if (this.isProtectedAction(event)) {
        count += 1;
      }
    }
    return count;
  }
}
