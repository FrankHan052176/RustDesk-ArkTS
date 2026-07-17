import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';

export interface RustDeskClipboardControllerCallbacks {
  sendText: (content: string) => boolean;
  log: (label: string, payload: string) => void;
}

export class RustDeskClipboardController {
  private readonly context: common.UIAbilityContext;
  private readonly callbacks: RustDeskClipboardControllerCallbacks;
  private readonly systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
  private readonly atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  private readonly permissions: Permissions[] = ['ohos.permission.READ_PASTEBOARD'];
  private active: boolean = false;
  private readInFlight: boolean = false;
  private readAgain: boolean = false;
  private remoteWriteInFlight: boolean = false;
  private permissionRequestAttempted: boolean = false;
  private permissionGranted: boolean = false;
  private pendingRemoteText: string | undefined = undefined;
  private lastRemoteText: string | undefined = undefined;
  private lastLocalText: string | undefined = undefined;
  private readonly onPasteboardUpdate = (): void => {
    if (!this.active || this.remoteWriteInFlight) {
      return;
    }
    this.readAndSendLocalText();
  };

  constructor(context: common.UIAbilityContext, callbacks: RustDeskClipboardControllerCallbacks) {
    this.context = context;
    this.callbacks = callbacks;
  }

  start(): void {
    if (this.active) {
      return;
    }
    try {
      this.systemPasteboard.on('update', this.onPasteboardUpdate);
      this.active = true;
    } catch (error) {
      this.callbacks.log('clipboard_listener', `start failed=${String(error)}`);
      return;
    }
    if (this.pendingRemoteText !== undefined) {
      this.flushRemoteText();
      return;
    }
    this.readAndSendLocalText();
  }

  stop(): void {
    if (!this.active) {
      return;
    }
    this.active = false;
    try {
      this.systemPasteboard.off('update', this.onPasteboardUpdate);
    } catch (error) {
      this.callbacks.log('clipboard_listener', `stop failed=${String(error)}`);
    }
    this.readAgain = false;
  }

  reset(): void {
    this.stop();
    this.pendingRemoteText = undefined;
    this.lastRemoteText = undefined;
    this.lastLocalText = undefined;
    this.permissionRequestAttempted = false;
    this.permissionGranted = false;
  }

  applyRemoteText(content: string): void {
    this.lastRemoteText = content;
    this.pendingRemoteText = content;
    this.flushRemoteText();
  }

  private async flushRemoteText(): Promise<void> {
    if (!this.active || this.remoteWriteInFlight || this.pendingRemoteText === undefined) {
      return;
    }
    const content = this.pendingRemoteText;
    this.pendingRemoteText = undefined;
    this.remoteWriteInFlight = true;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
      await this.systemPasteboard.setData(data);
      this.callbacks.log('clipboard_remote', `applied length=${content.length}`);
    } catch (error) {
      this.callbacks.log('clipboard_remote', `failed=${String(error)}`);
    } finally {
      this.remoteWriteInFlight = false;
      if (this.active && this.pendingRemoteText !== undefined) {
        this.flushRemoteText();
      }
    }
  }

  private async readAndSendLocalText(): Promise<void> {
    if (!this.active) {
      return;
    }
    if (this.readInFlight) {
      this.readAgain = true;
      return;
    }
    this.readInFlight = true;
    try {
      if (!this.systemPasteboard.hasDataType(pasteboard.MIMETYPE_TEXT_PLAIN)) {
        return;
      }
      if (!await this.ensureReadPermission()) {
        return;
      }
      const data = await this.systemPasteboard.getData();
      if (!this.active || data.getRecordCount() === 0) {
        return;
      }
      const content = data.getRecord(0).toPlainText();
      if (content === this.lastRemoteText || content === this.lastLocalText) {
        return;
      }
      if (this.callbacks.sendText(content)) {
        this.lastLocalText = content;
        this.callbacks.log('clipboard_local', `sent length=${content.length}`);
      }
    } catch (error) {
      this.callbacks.log('clipboard_local', `failed=${String(error)}`);
    } finally {
      this.readInFlight = false;
      if (this.active && this.readAgain) {
        this.readAgain = false;
        this.readAndSendLocalText();
      }
    }
  }

  private async ensureReadPermission(): Promise<boolean> {
    if (this.permissionGranted) {
      return true;
    }
    if (this.permissionRequestAttempted) {
      return false;
    }
    this.permissionRequestAttempted = true;
    try {
      const result = await this.atManager.requestPermissionsFromUser(this.context, this.permissions);
      this.permissionGranted = result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (error) {
      this.callbacks.log('clipboard_permission', `request failed=${String(error)}`);
      this.permissionGranted = false;
    }
    if (!this.permissionGranted) {
      this.callbacks.log('clipboard_permission', 'READ_PASTEBOARD was not granted');
    }
    return this.permissionGranted;
  }
}
