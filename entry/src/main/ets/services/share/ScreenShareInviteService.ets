import { common, Want } from '@kit.AbilityKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { url } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { systemShare } from '@kit.ShareKit';

export const SCREEN_SHARE_INVITE_EVENT = 'rustdesk.screen_share_invite';

const DOMAIN = 0xFF00;
const TAG = 'RustDeskShareInvite';

/**
 * Only this exact link shape is produced or accepted. It carries the opaque RKS1
 * invite and nothing else: no A credentials, no server context, no display state.
 */
const SHARE_SCHEME = 'resk:';
const SHARE_HOST = 'share';
const SHARE_PATH = '/screen';
const SHARE_LINK_PREFIX = 'resk://share/screen?';
const SHARE_ACTION = 'ohos.want.action.sendData';
const CODE_PARAM = 'code';
const CODE_PREFIX = 'RKS1.';
const MAX_CODE_LENGTH = 512;
const MAX_LINK_LENGTH = 1024;

/**
 * System ShareKit entry point for "send this display's invite to another device".
 *
 * The invite names one display but never changes what the local viewer is
 * watching, and it is not a media channel: the picture keeps flowing over the
 * existing B->C connection. Only the short-lived RKS1 viewing grant travels
 * through 华为分享 / 系统分享, so this service must never claim the peer received,
 * accepted or is playing anything.
 */
export class ScreenShareInviteService {
  // Memory only: nothing is persisted, and a cancelled app leaves no invite behind.
  private static pendingInviteCode: string | undefined = undefined;

  /**
   * Opens the system share sheet carrying `resk://share/screen?code=<RKS1 …>`.
   *
   * Resolving means the sheet was opened. Whether 华为分享 is offered, which
   * channel the user picks, and whether the peer ever receives the link are all
   * device and user decisions this service cannot observe.
   */
  static async send(context: common.UIAbilityContext, inviteCode: string, display: number): Promise<void> {
    const code = ScreenShareInviteService.readInviteCode(inviteCode);
    if (code === undefined) {
      throw new Error('分享邀请码不可用');
    }
    const data = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: ScreenShareInviteService.buildInviteLink(code),
      title: ScreenShareInviteService.displayTitle(display),
      description: '仅供观看',
    });
    try {
      await new systemShare.ShareController(data).show(context, {});
      hilog.info(DOMAIN, TAG, 'system share sheet opened for display=%{public}d', display);
    } catch (error) {
      // The platform may echo the shared link inside its own message, so only the
      // numeric BusinessError code is logged and the caller gets a neutral error.
      const failure = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'system share sheet failed for display=%{public}d code=%{public}d',
        display, failure.code);
      throw new Error('无法打开系统分享面板');
    }
  }

  /**
   * True only when this want carried a screen invite; the code is buffered for
   * `takeIncoming()` and `SCREEN_SHARE_INVITE_EVENT` is emitted. Never throws, so
   * the caller can keep routing the want through its other handlers on `false`.
   */
  static async handleWant(context: common.UIAbilityContext, want: Want): Promise<boolean> {
    try {
      const code = await ScreenShareInviteService.readInviteCodeFromWant(want);
      if (code === undefined) {
        return false;
      }
      ScreenShareInviteService.pendingInviteCode = code;
      context.eventHub.emit(SCREEN_SHARE_INVITE_EVENT);
      hilog.info(DOMAIN, TAG, 'screen share invite buffered codeLength=%{public}d', code.length);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'screen share invite inspection failed');
      return false;
    }
  }

  static bufferIncoming(context: common.UIAbilityContext, code: string): void {
    ScreenShareInviteService.pendingInviteCode = code;
    context.eventHub.emit(SCREEN_SHARE_INVITE_EVENT);
  }

  /** Hands the buffered invite to exactly one caller and clears it. */
  static takeIncoming(): string | undefined {
    const code = ScreenShareInviteService.pendingInviteCode;
    ScreenShareInviteService.pendingInviteCode = undefined;
    return code;
  }

  private static async readInviteCodeFromWant(want: Want): Promise<string | undefined> {
    const uri = want.uri;
    if (uri !== undefined && uri.length > 0) {
      const fromUri = ScreenShareInviteService.parseInviteLink(uri);
      if (fromUri !== undefined) {
        return fromUri;
      }
    }
    if (want.action !== SHARE_ACTION) {
      return undefined;
    }
    return ScreenShareInviteService.readInviteCodeFromRecords(want);
  }

  /**
   * The system share sheet hands the record list over in the want itself; unrelated
   * wants (EasyTier results, continuation payloads) never reach this path.
   */
  private static async readInviteCodeFromRecords(want: Want): Promise<string | undefined> {
    const contents: string[] = [];
    try {
      const data = await systemShare.getSharedData(want);
      const records = data.getRecords();
      for (let index = 0; index < records.length; index += 1) {
        contents.push(records[index].content ?? '');
      }
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'share action carried no system share records');
      return undefined;
    }
    for (let index = 0; index < contents.length; index += 1) {
      const code = ScreenShareInviteService.parseInviteLink(contents[index]);
      if (code !== undefined) {
        return code;
      }
    }
    return undefined;
  }

  /**
   * Strict shape check: `resk://share/screen` with exactly one `code` parameter and
   * no credentials or fragment. Anything else stays an unrelated want.
   */
  private static parseInviteLink(raw: string): string | undefined {
    const link = raw.trim();
    if (link.length === 0 || link.length > MAX_LINK_LENGTH) {
      return undefined;
    }
    // Reject credentials and fragments before parsing; this shape never needs them.
    if (!link.startsWith(SHARE_LINK_PREFIX) || link.includes('#') || link.includes('@')) {
      return undefined;
    }
    const query = link.substring(SHARE_LINK_PREFIX.length);
    if (!query.startsWith(`${CODE_PARAM}=`) || query.includes('&')) {
      return undefined;
    }
    let protocol = '';
    let hostname = '';
    let pathname = '';
    let decoded = '';
    try {
      const parsed = url.URL.parseURL(link);
      protocol = parsed.protocol;
      hostname = parsed.hostname;
      pathname = parsed.pathname;
      decoded = parsed.params.get(CODE_PARAM) ?? '';
    } catch (error) {
      return undefined;
    }
    if (protocol !== SHARE_SCHEME || hostname !== SHARE_HOST || pathname !== SHARE_PATH) {
      return undefined;
    }
    return ScreenShareInviteService.readInviteCode(decoded);
  }

  /** Light shape check only; native `sessionAddShared` owns the real credential. */
  private static readInviteCode(value: string): string | undefined {
    const code = value.trim();
    if (!code.startsWith(CODE_PREFIX) || code.length > MAX_CODE_LENGTH ||
      code.length <= CODE_PREFIX.length) {
      return undefined;
    }
    return code;
  }

  private static buildInviteLink(code: string): string {
    try {
      const link = url.URL.parseURL('resk://share/screen');
      link.params.set(CODE_PARAM, code);
      return link.toString();
    } catch (error) {
      throw new Error('无法生成分享链接');
    }
  }

  /**
   * `display` is the zero-based card index from DisplaySelectorSheet; the title uses
   * the same one-based numbering as the sheet ("显示器 1").
   */
  private static displayTitle(display: number): string {
    return `显示器 ${display >= 0 ? display + 1 : 1}`;
  }
}
