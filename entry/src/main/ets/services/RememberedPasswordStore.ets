import { asset } from '@kit.AssetStoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

const ASSET_NOT_FOUND = 24000002;
const ALIAS_PREFIX = 'resk.remote-password.v1:';

/**
 * App-owned, device-local system secret storage. No Preferences, exported keys,
 * cloud sync, cross-uninstall persistence, logs, retries or fallback storage.
 * Calls are synchronous so a late storage callback cannot write a different
 * session's candidate after a tab/owner change.
 */
export class RememberedPasswordStore {
  private alias(identity: string): Uint8Array {
    if (identity.length === 0) {
      throw new Error('密码存储目标不可用');
    }
    // Hash the structured target/route identity, never the password. The fixed
    // size alias avoids putting long route strings into Asset's alias field.
    const md = cryptoFramework.createMd('SHA256');
    md.updateSync({ data: new util.TextEncoder('utf-8').encodeInto(identity) });
    const digest = md.digestSync().data;
    let hex = '';
    for (const value of digest) {
      hex += value.toString(16).padStart(2, '0');
    }
    return new util.TextEncoder('utf-8').encodeInto(ALIAS_PREFIX + hex);
  }

  /** Only the explicit new connection path calls this, not page load or polling. */
  read(identity: string): string {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias(identity));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    let results: asset.AssetMap[];
    try {
      results = asset.querySync(query);
    } catch (error) {
      if ((error as BusinessError).code === ASSET_NOT_FOUND) {
        return '';
      }
      throw new Error('无法读取已记住的密码');
    }
    const secret = results[0]?.get(asset.Tag.SECRET);
    if (!(secret instanceof Uint8Array) || secret.length === 0) {
      throw new Error('无法读取已记住的密码');
    }
    try {
      return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(secret);
    } catch (_) {
      throw new Error('无法读取已记住的密码');
    } finally {
      secret.fill(0);
    }
  }

  /** Invoked only with the candidate consumed from a successful bound poll. */
  save(identity: string, password: string): void {
    if (password.length === 0) {
      throw new Error('没有可保存的密码');
    }
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.alias(identity));
    const secret = new util.TextEncoder('utf-8').encodeInto(password);
    attributes.set(asset.Tag.SECRET, secret);
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    try {
      asset.addSync(attributes);
    } catch (_) {
      throw new Error('密码未能安全保存');
    } finally {
      secret.fill(0);
    }
  }

  /** Removing an already absent asset is success; other failures remain visible. */
  remove(identity: string): void {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias(identity));
    try {
      asset.removeSync(query);
    } catch (error) {
      if ((error as BusinessError).code !== ASSET_NOT_FOUND) {
        throw new Error('未能清除已记住的密码');
      }
    }
  }
}
