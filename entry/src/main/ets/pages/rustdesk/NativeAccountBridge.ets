import { common, Want } from '@kit.AbilityKit';
import { rustDeskNativeApi as native } from './RustDeskNativeApi';
import {
  AccountProvider,
  AccountSnapshot,
  AccountState,
  AccountUser,
  ApprovedServerProfile,
  CloudAddressBook,
  CloudBookLoadResult,
  CloudMutation,
  CloudPeer,
  NativeAccountResponse,
  OidcPollResult,
  OidcResultState,
  OidcStartResult,
  PeerRecord,
} from './RustDeskDirectoryTypes';

const MAX_OIDC_POLL_COUNT: number = 180; // 180 seconds maximum
const OIDC_POLL_INTERVAL_MS: number = 1000;

export interface AccountBindServerResult {
  mode: string;
  profileRevision: number;
  sessionRetained: boolean;
}

export interface OidcCancelResult {
  cancelled: boolean;
  attemptReceipt: string;
}

export interface NativeAccountBridge {
  bindServer(approvedProfileJson: string): Promise<NativeAccountResponse<AccountBindServerResult>>;
  snapshot(): Promise<NativeAccountResponse<AccountSnapshot>>;
  getProviders(): Promise<NativeAccountResponse<AccountProvider[]>>;
  oidcStart(receipt: string, providerId: string, rememberMe: boolean): Promise<NativeAccountResponse<OidcStartResult>>;
  oidcResult(attemptReceipt: string): Promise<NativeAccountResponse<OidcPollResult>>;
  oidcCancel(attemptReceipt: string): Promise<NativeAccountResponse<OidcCancelResult>>;
  logout(receipt: string): Promise<NativeAccountResponse<void>>;
  listAddressBooks(receipt: string): Promise<NativeAccountResponse<CloudAddressBook[]>>;
  loadAddressBook(receipt: string, bookId: string): Promise<NativeAccountResponse<CloudBookLoadResult>>;
  mutateAddressBook(receipt: string, bookId: string, mutation: CloudMutation): Promise<NativeAccountResponse<void>>;
}

export class RustDeskNativeAccountBridge implements NativeAccountBridge {
  private parseEnvelope<T>(raw: string, fallbackAction: string): NativeAccountResponse<T> {
    try {
      const parsed: ESObject = JSON.parse(raw);
      const ok = parsed.ok === true;
      const code = parsed.code !== undefined ? String(parsed.code) : undefined;
      const error = parsed.error !== undefined ? String(parsed.error) : undefined;
      const sent = parsed.sent === true ? true : (parsed.sent === false ? false : undefined);
      return {
        ok,
        code,
        error,
        sent,
        data: parsed as T,
      };
    } catch (err) {
      return {
        ok: false,
        code: 'parse_error',
        error: `解析原生应答失败 (${fallbackAction}): ${String(err)}`,
      };
    }
  }

  async bindServer(approvedProfileJson: string): Promise<NativeAccountResponse<AccountBindServerResult>> {
    try {
      const raw = await native.accountBindServer(approvedProfileJson);
      const envelope: NativeAccountResponse<ESObject> = this.parseEnvelope<ESObject>(raw, 'accountBindServer');
      if (!envelope.ok || envelope.data === undefined) {
        return {
          ok: false,
          code: envelope.code,
          error: envelope.error,
          sent: envelope.sent,
        };
      }
      const revision = Number(envelope.data.profileRevision);
      return {
        ok: true,
        data: {
          mode: String(envelope.data.mode ?? ''),
          profileRevision: Number.isSafeInteger(revision) ? revision : 0,
          sessionRetained: envelope.data.sessionRetained === true,
        },
      };
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async snapshot(): Promise<NativeAccountResponse<AccountSnapshot>> {
    try {
      const raw = await native.accountSnapshot();
      const envelope: NativeAccountResponse<ESObject> = this.parseEnvelope<ESObject>(raw, 'accountSnapshot');
      if (!envelope.ok || envelope.data === undefined) {
        return {
          ok: false,
          code: envelope.code,
          error: envelope.error,
          sent: envelope.sent,
        };
      }
      return {
        ok: true,
        data: this.parseSnapshotData(envelope.data),
      };
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async getProviders(): Promise<NativeAccountResponse<AccountProvider[]>> {
    try {
      const raw = await native.accountProviders();
      const envelope: NativeAccountResponse<ESObject> = this.parseEnvelope<ESObject>(raw, 'accountProviders');
      if (!envelope.ok || envelope.data === undefined) {
        return {
          ok: false,
          code: envelope.code,
          error: envelope.error,
          sent: envelope.sent,
        };
      }
      const list: AccountProvider[] = [];
      const rawProviders: ESObject = envelope.data.providers;
      if (Array.isArray(rawProviders)) {
        for (let i = 0; i < rawProviders.length; i += 1) {
          const item: ESObject = rawProviders[i];
          if (item && item.id) {
            list.push({
              id: String(item.id),
              label: String(item.label ?? item.id),
            });
          }
        }
      }
      return { ok: true, data: list };
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async oidcStart(receipt: string, providerId: string, rememberMe: boolean): Promise<NativeAccountResponse<OidcStartResult>> {
    try {
      const raw = await native.accountOidcStart(receipt, providerId, rememberMe);
      const envelope: NativeAccountResponse<ESObject> = this.parseEnvelope<ESObject>(raw, 'accountOidcStart');
      if (!envelope.ok || envelope.data === undefined) {
        return {
          ok: false,
          code: envelope.code,
          error: envelope.error,
          sent: envelope.sent,
        };
      }
      return {
        ok: true,
        data: {
          attemptReceipt: String(envelope.data.attemptReceipt ?? ''),
          state: String(envelope.data.state ?? 'pending'),
        },
      };
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async oidcResult(attemptReceipt: string): Promise<NativeAccountResponse<OidcPollResult>> {
    try {
      const raw = await native.accountOidcResult(attemptReceipt);
      const envelope: NativeAccountResponse<ESObject> = this.parseEnvelope<ESObject>(raw, 'accountOidcResult');
      if (!envelope.ok || envelope.data === undefined) {
        return {
          ok: false,
          code: envelope.code,
          error: envelope.error,
          sent: envelope.sent,
        };
      }
      const rawState = String(envelope.data.state ?? 'pending') as OidcResultState;
      const url = envelope.data.url ? String(envelope.data.url) : undefined;
      return {
        ok: true,
        data: {
          state: rawState,
          url: url,
          code: envelope.code,
          error: envelope.error ?? (envelope.data.message ? String(envelope.data.message) : undefined),
        },
      };
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async oidcCancel(attemptReceipt: string): Promise<NativeAccountResponse<OidcCancelResult>> {
    try {
      const raw = await native.accountOidcCancel(attemptReceipt);
      const envelope: NativeAccountResponse<ESObject> = this.parseEnvelope<ESObject>(raw, 'accountOidcCancel');
      if (!envelope.ok || envelope.data === undefined) {
        return {
          ok: false,
          code: envelope.code,
          error: envelope.error,
          sent: envelope.sent,
        };
      }
      return {
        ok: true,
        data: {
          cancelled: envelope.data.cancelled === true,
          attemptReceipt: String(envelope.data.attemptReceipt ?? attemptReceipt),
        },
      };
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async logout(receipt: string): Promise<NativeAccountResponse<void>> {
    try {
      const raw = await native.accountLogout(receipt);
      return this.parseEnvelope<void>(raw, 'accountLogout');
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async listAddressBooks(receipt: string): Promise<NativeAccountResponse<CloudAddressBook[]>> {
    try {
      const raw = await native.cloudAddressBookList(receipt);
      const envelope: NativeAccountResponse<ESObject> = this.parseEnvelope<ESObject>(raw, 'cloudAddressBookList');
      if (!envelope.ok || envelope.data === undefined) {
        return {
          ok: false,
          code: envelope.code,
          error: envelope.error,
          sent: envelope.sent,
        };
      }
      const books: CloudAddressBook[] = [];
      const rawBooks: ESObject = envelope.data.books;
      if (Array.isArray(rawBooks)) {
        for (let i = 0; i < rawBooks.length; i += 1) {
          const item: ESObject = rawBooks[i];
          if (item && item.id) {
            books.push({
              id: String(item.id),
              name: String(item.name ?? item.id),
              kind: String(item.kind ?? 'personal'),
              writable: item.writable === true,
              capabilities: item.capabilities,
            });
          }
        }
      }
      return { ok: true, data: books };
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async loadAddressBook(receipt: string, bookId: string): Promise<NativeAccountResponse<CloudBookLoadResult>> {
    try {
      const raw = await native.cloudAddressBookLoad(receipt, bookId);
      const envelope: NativeAccountResponse<ESObject> = this.parseEnvelope<ESObject>(raw, 'cloudAddressBookLoad');
      if (!envelope.ok || envelope.data === undefined) {
        return {
          ok: false,
          code: envelope.code,
          error: envelope.error,
          sent: envelope.sent,
        };
      }
      const rawBook: ESObject = envelope.data.book as ESObject;
      const book: CloudAddressBook = {
        id: String(rawBook?.id ?? bookId),
        name: String(rawBook?.name ?? ''),
        kind: String(rawBook?.kind ?? 'personal'),
        writable: rawBook?.writable === true,
        capabilities: rawBook?.capabilities,
      };

      const peers: CloudPeer[] = [];
      const rawPeers: ESObject = envelope.data.peers;
      if (Array.isArray(rawPeers)) {
        for (let i = 0; i < rawPeers.length; i += 1) {
          const p: ESObject = rawPeers[i];
          if (p && p.id) {
            const tags: string[] = [];
            if (Array.isArray(p.tags)) {
              for (let t = 0; t < p.tags.length; t += 1) {
                tags.push(String(p.tags[t]));
              }
            }
            peers.push({
              id: String(p.id),
              alias: p.alias ? String(p.alias) : undefined,
              tags: tags,
              hostname: p.hostname ? String(p.hostname) : undefined,
              platform: p.platform ? String(p.platform) : undefined,
            });
          }
        }
      }

      const tags: string[] = [];
      if (Array.isArray(envelope.data.tags)) {
        for (let i = 0; i < envelope.data.tags.length; i += 1) {
          tags.push(String(envelope.data.tags[i]));
        }
      }

      const revision = Number(envelope.data.revision);
      return {
        ok: true,
        data: {
          book,
          peers,
          tags,
          revision: Number.isSafeInteger(revision) ? revision : undefined,
        },
      };
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  async mutateAddressBook(receipt: string, bookId: string, mutation: CloudMutation): Promise<NativeAccountResponse<void>> {
    try {
      const raw = await native.cloudAddressBookMutate(receipt, bookId, JSON.stringify(mutation));
      return this.parseEnvelope<void>(raw, 'cloudAddressBookMutate');
    } catch (err) {
      return { ok: false, code: 'network', error: String(err) };
    }
  }

  private parseSnapshotData(raw: ESObject): AccountSnapshot {
    const rawBinding: ESObject = raw.serverBinding as ESObject;
    const rawUser: ESObject = raw.user as ESObject;
    let user: AccountUser | undefined = undefined;
    if (rawUser && typeof rawUser === 'object') {
      user = {
        name: String(rawUser.name ?? ''),
        displayName: rawUser.displayName ? String(rawUser.displayName) : undefined,
        avatar: rawUser.avatar ? String(rawUser.avatar) : undefined,
        status: rawUser.status ? String(rawUser.status) : undefined,
      };
    }
    const revision = Number(rawBinding?.profileRevision);
    return {
      receipt: String(raw.receipt ?? ''),
      loggedIn: raw.loggedIn === true,
      serverBinding: {
        mode: String(rawBinding?.mode ?? ''),
        profileRevision: Number.isSafeInteger(revision) ? revision : 0,
      },
      user,
    };
  }
}

export const rustDeskNativeAccountBridge: RustDeskNativeAccountBridge = new RustDeskNativeAccountBridge();

/**
 * Controller orchestrating Account OAuth login flow, polling timers, and Address Book sync.
 */
@ObservedV2
export class RustDeskAccountController {
  private bridge: NativeAccountBridge = rustDeskNativeAccountBridge;
  @Trace state: AccountState = new AccountState();
  @Trace providers: AccountProvider[] = [];
  @Trace providersLoading: boolean = false;
  @Trace selectedProviderId: string = '';
  @Trace rememberMe: boolean = true;
  @Trace oidcInProgress: boolean = false;
  @Trace oidcUrlOpened: boolean = false;
  @Trace oidcPollMessage: string = '';
  @Trace oidcError: string = '';
  @Trace addressBooks: CloudAddressBook[] = [];
  @Trace activeBookId: string = '';
  @Trace activeBook: CloudAddressBook | undefined = undefined;
  @Trace activeBookPeers: CloudPeer[] = [];
  @Trace activeBookTags: string[] = [];
  @Trace booksLoading: boolean = false;
  @Trace booksError: string = '';
  @Trace mutationInFlight: boolean = false;
  @Trace mutationFeedback: string = '';

  private activeAttemptReceipt: string = '';
  private oidcGeneration: number = 0;
  private pollTimer: number = -1;
  private pollCount: number = 0;
  private pollInFlight: boolean = false;

  constructor(bridge?: NativeAccountBridge) {
    if (bridge) {
      this.bridge = bridge;
    }
  }

  setBridge(bridge: NativeAccountBridge): void {
    this.bridge = bridge;
  }

  /**
   * Called on app initialization and after server profile updates.
   * Compares native authoritative server binding with approved profile.
   */
  async bindAuthoritativeServer(approvedProfile: ApprovedServerProfile | undefined): Promise<void> {
    const profileJson = approvedProfile ? JSON.stringify(approvedProfile) : '';
    const res = await this.bridge.bindServer(profileJson);
    if (!res.ok || res.data === undefined) {
      if (res.code === 'forbidden') {
        this.state.error = '无访问权限 (forbidden)';
      } else {
        this.state.error = res.error || res.code || '服务器绑定失败';
      }
      return;
    }
    this.state.error = '';
    const bindResult = res.data;
    const prevRevision = this.state.serverBindingRevision;
    const prevMode = this.state.serverBindingMode;

    await this.loadSnapshot();

    // If server scope changed or session was not retained, clear old cloud cache
    if (bindResult.profileRevision !== prevRevision || bindResult.mode !== prevMode || !bindResult.sessionRetained) {
      this.clearCloudCache();
    }
  }

  async loadSnapshot(): Promise<void> {
    const res = await this.bridge.snapshot();
    if (res.ok && res.data !== undefined) {
      this.applySnapshot(res.data);
      if (res.data.loggedIn) {
        await this.loadAddressBooks();
      } else {
        await this.loadProviders();
      }
    } else {
      this.state.error = res.error || res.code || '读取账户状态失败';
    }
  }

  private applySnapshot(snapshot: AccountSnapshot): void {
    this.state.receipt = snapshot.receipt;
    this.state.error = '';
    this.state.message = '';
    this.state.loggedIn = snapshot.loggedIn;
    this.state.serverBindingMode = snapshot.serverBinding.mode;
    this.state.serverBindingRevision = snapshot.serverBinding.profileRevision;
    if (snapshot.user) {
      this.state.name = snapshot.user.name;
      this.state.displayName = snapshot.user.displayName ?? snapshot.user.name;
      this.state.avatar = snapshot.user.avatar ?? '';
      this.state.status = snapshot.user.status ?? '';
    } else {
      this.state.name = '';
      this.state.displayName = '';
      this.state.avatar = '';
      this.state.status = '';
    }
  }

  async loadProviders(): Promise<void> {
    if (this.state.loggedIn) {
      return;
    }
    this.providersLoading = true;
    try {
      const res = await this.bridge.getProviders();
      if (res.ok && res.data !== undefined) {
        this.state.error = '';
        this.providers = res.data;
        if (this.providers.length > 0 && this.selectedProviderId.length === 0) {
          this.selectedProviderId = this.providers[0].id;
        }
      } else {
        this.providers = [];
        this.state.error = res.error || res.code || '无法获取登录提供商';
      }
    } finally {
      this.providersLoading = false;
    }
  }

  async startOidcLogin(context: common.UIAbilityContext): Promise<void> {
    if (this.oidcInProgress) {
      return;
    }
    if (this.selectedProviderId.length === 0) {
      this.oidcError = '请选择登录提供商';
      return;
    }
    const generation = ++this.oidcGeneration;
    this.oidcInProgress = true;
    this.oidcUrlOpened = false;
    this.oidcPollMessage = '正在请求登录…';
    this.oidcError = '';
    this.state.busy = true;

    let res = await this.bridge.oidcStart(this.state.receipt, this.selectedProviderId, this.rememberMe);
    if (!res.ok && res.code === 'stale_receipt' && generation === this.oidcGeneration) {
      await this.refreshReceipt();
      if (generation === this.oidcGeneration) {
        res = await this.bridge.oidcStart(this.state.receipt, this.selectedProviderId, this.rememberMe);
      }
    }
    if (generation !== this.oidcGeneration || !this.oidcInProgress) {
      if (res.ok && res.data !== undefined && res.data.attemptReceipt.length > 0) {
        await this.bridge.oidcCancel(res.data.attemptReceipt);
      }
      return;
    }
    if (!res.ok || res.data === undefined || res.data.attemptReceipt.length === 0) {
      this.endOidc('', this.describeFailure(res.error, res.code, '发起登录请求失败'));
      return;
    }

    this.activeAttemptReceipt = res.data.attemptReceipt;
    this.pollCount = 0;
    this.startPollTimer(context, generation);
  }

  private startPollTimer(context: common.UIAbilityContext, generation: number): void {
    this.stopPollTimer();
    this.pollTimer = setInterval((): void => {
      void this.pollOidcResult(context, generation);
    }, OIDC_POLL_INTERVAL_MS);
  }

  private stopPollTimer(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private endOidc(message: string, error: string): void {
    this.stopPollTimer();
    this.activeAttemptReceipt = '';
    this.oidcInProgress = false;
    this.state.busy = false;
    this.oidcPollMessage = message;
    this.oidcError = error;
  }

  private describeFailure(error: string | undefined, code: string | undefined, fallback: string): string {
    const raw = error ?? code ?? '';
    if (raw === 'Account authentication rejected by server') { return '账号服务器拒绝了本次登录'; }
    if (raw === 'Account authentication request failed') { return '无法连接账号服务器，请检查网络'; }
    if (raw === 'Account authentication request timed out' || raw === 'timeout') {
      return '登录请求超时，请重试';
    }
    return raw.length > 0 ? raw : fallback;
  }

  private async refreshReceipt(): Promise<void> {
    const snap = await this.bridge.snapshot();
    if (snap.ok && snap.data !== undefined) {
      this.applySnapshot(snap.data);
    }
  }

  private async pollOidcResult(context: common.UIAbilityContext, generation: number): Promise<void> {
    if (generation !== this.oidcGeneration || !this.oidcInProgress || this.activeAttemptReceipt.length === 0) {
      this.stopPollTimer();
      return;
    }
    this.pollCount += 1;
    if (this.pollCount > MAX_OIDC_POLL_COUNT) {
      const receipt = this.activeAttemptReceipt;
      this.endOidc('', '登录等待超时，请重试');
      void this.bridge.oidcCancel(receipt);
      return;
    }

    const attemptReceipt = this.activeAttemptReceipt;
    if (this.pollInFlight) { return; }
    this.pollInFlight = true;
    try {
      await this.applyPoll(context, generation, attemptReceipt);
    } finally {
      this.pollInFlight = false;
    }
  }

  private async applyPoll(context: common.UIAbilityContext, generation: number, attemptReceipt: string): Promise<void> {
    const res = await this.bridge.oidcResult(attemptReceipt);
    if (generation !== this.oidcGeneration || !this.oidcInProgress || this.activeAttemptReceipt !== attemptReceipt) {
      return;
    }
    if (!res.ok || res.data === undefined) {
      if (res.code === 'network') { return; }
      await this.loadSnapshot();
      if (generation !== this.oidcGeneration) { return; }
      if (this.state.loggedIn) {
        this.endOidc('登录成功', '');
      } else {
        this.endOidc('', this.describeFailure(res.error, res.code, '登录失败'));
      }
      return;
    }

    const poll = res.data;
    if (poll.state === 'url-ready') {
      if (!this.oidcUrlOpened && poll.url && poll.url.length > 0) {
        if (!poll.url.startsWith('https://') && !poll.url.startsWith('http://')) {
          this.endOidc('', '登录链接不合法 (必须为 http/https 协议)');
          void this.bridge.oidcCancel(attemptReceipt);
          return;
        }
        this.oidcUrlOpened = true;
        this.oidcPollMessage = '已在浏览器中打开授权页面，等待授权完成…';
        try {
          const want: Want = {
            action: 'ohos.want.action.viewData',
            entities: ['entity.system.browsable'],
            uri: poll.url,
          };
          await context.startAbility(want);
        } catch (openErr) {
          if (generation === this.oidcGeneration) {
            this.endOidc('', `打开浏览器授权失败：${String(openErr)}`);
            void this.bridge.oidcCancel(attemptReceipt);
          }
          return;
        }
      }
    } else if (poll.state === 'complete') {
      await this.loadSnapshot();
      if (generation !== this.oidcGeneration) { return; }
      if (this.state.loggedIn) {
        this.endOidc('登录成功', '');
      } else {
        this.endOidc('', '登录已完成但账号状态未生效，请重试');
      }
    } else if (poll.state === 'failed') {
      this.endOidc('', this.describeFailure(poll.error, poll.code, '登录失败'));
    } else if (poll.state === 'cancelled') {
      this.endOidc('登录已取消', '');
    } else if (poll.state === 'needs-business') {
      this.endOidc('', '该登录需要邮箱验证或二次验证，Resk 暂不支持，请改用其他登录方式');
    }
  }

  async cancelOidcLogin(): Promise<void> {
    const receipt = this.activeAttemptReceipt;
    ++this.oidcGeneration;
    this.endOidc('已取消登录', '');
    if (receipt.length > 0) {
      await this.bridge.oidcCancel(receipt);
    }
  }

  async logout(): Promise<void> {
    if (this.state.receipt.length > 0) {
      await this.bridge.logout(this.state.receipt);
    }
    this.clearCloudCache();
    await this.loadSnapshot();
  }

  async loadAddressBooks(): Promise<void> {
    if (!this.state.loggedIn || this.state.receipt.length === 0) {
      this.clearCloudCache();
      return;
    }
    this.booksLoading = true;
    this.booksError = '';
    try {
      const res = await this.bridge.listAddressBooks(this.state.receipt);
      if (res.ok && res.data !== undefined) {
        this.addressBooks = res.data;
        if (this.addressBooks.length > 0) {
          const targetBookId = (this.activeBookId.length > 0 &&
            this.addressBooks.some((b: CloudAddressBook) => b.id === this.activeBookId))
            ? this.activeBookId
            : this.addressBooks[0].id;
          await this.loadActiveBook(targetBookId);
        } else {
          this.activeBookId = '';
          this.activeBook = undefined;
          this.activeBookPeers = [];
          this.activeBookTags = [];
        }
      } else {
        this.booksError = res.error || res.code || '无法读取云端通讯录列表';
      }
    } finally {
      this.booksLoading = false;
    }
  }

  async loadActiveBook(bookId: string): Promise<void> {
    this.activeBookId = bookId;
    this.booksLoading = true;
    this.booksError = '';
    try {
      const res = await this.bridge.loadAddressBook(this.state.receipt, bookId);
      if (res.ok && res.data !== undefined) {
        this.activeBook = res.data.book;
        this.activeBookPeers = res.data.peers;
        this.activeBookTags = res.data.tags;
      } else {
        this.booksError = res.error || res.code || '加载通讯录设备失败';
      }
    } finally {
      this.booksLoading = false;
    }
  }

  async mutate(mutation: CloudMutation): Promise<boolean> {
    if (!this.activeBook || !this.activeBook.writable || this.activeBookId.length === 0) {
      this.mutationFeedback = '当前通讯录为只读，不允许修改';
      return false;
    }
    this.mutationInFlight = true;
    this.mutationFeedback = '';
    try {
      const res = await this.bridge.mutateAddressBook(this.state.receipt, this.activeBookId, mutation);
      if (res.ok) {
        await this.loadActiveBook(this.activeBookId);
        return true;
      }
      if (res.sent === true) {
        this.mutationFeedback = '变更已提交但确认结果未知，请刷新核对状态';
      } else {
        this.mutationFeedback = res.error || res.code || '操作失败';
      }
      return false;
    } finally {
      this.mutationInFlight = false;
    }
  }

  clearCloudCache(): void {
    this.addressBooks = [];
    this.activeBookId = '';
    this.activeBook = undefined;
    this.activeBookPeers = [];
    this.activeBookTags = [];
    this.booksError = '';
    this.mutationFeedback = '';
  }

  /** Convert cloud peers into PeerRecord array for display in PeerCard and directory */
  toPeerRecords(): PeerRecord[] {
    const list: PeerRecord[] = [];
    const bookName = this.activeBook?.name ?? '云端通讯录';
    for (let i = 0; i < this.activeBookPeers.length; i += 1) {
      const cp = this.activeBookPeers[i];
      const record = new PeerRecord();
      record.id = cp.id;
      record.alias = cp.alias ?? '';
      record.hostname = cp.hostname ?? '';
      record.platform = cp.platform ?? '';
      record.tags = cp.tags ? cp.tags.slice() : [];
      record.source = 'addressBook';
      record.addressBookName = bookName;
      record.rustdeskIdOnly = true;
      record.protocol = 'rustdesk';
      // Online is deliberately undefined (unknown). Strict requirement: do not fake online!
      record.online = undefined;
      record.directWireReachable = undefined;
      list.push(record);
    }
    return list;
  }

  destroy(): void {
    const receipt = this.activeAttemptReceipt;
    ++this.oidcGeneration;
    this.endOidc('', '');
    if (receipt.length > 0) {
      void this.bridge.oidcCancel(receipt);
    }
  }
}

export const rustDeskAccountController: RustDeskAccountController = new RustDeskAccountController();
