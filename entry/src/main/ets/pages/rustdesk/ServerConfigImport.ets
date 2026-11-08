import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

const MAX_CONFIG_TEXT_BYTES: number = 64 * 1024;
const RUSTDESK_CONFIG_URI_PREFIX: string = 'rustdesk://config/';

export interface ImportedServerConfig {
  host: string;
  relay: string;
  api: string;
  key: string;
}

function removeEndSlash(input: string): string {
  const trimmed = input.trim();
  return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

function extractStringField(obj: ESObject, field: string): string {
  const value: ESObject = obj[field];
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value !== 'string') {
    throw new Error(`配置字段 '${field}' 必须为字符串类型`);
  }
  return value as string;
}

/**
 * Decodes server configuration from UTF-8 text (JSON or official reversed base64).
 *
 * Rules strictly align with official client:
 * 1. Optional `rustdesk://config/` URI scheme prefix is stripped.
 * 2. Attempts standard JSON.parse first.
 * 3. On failure, reverses string and decodes standard/URL-safe Base64 with padding.
 * 4. Extracts official fields: host, relay, api, key.
 *    Non-string values are rejected; omitted/null default to empty string.
 *    host cannot be empty.
 *    Trailing slashes are removed for host, relay, api.
 *    Key is trimmed without treating it as relay key or bypassing 32-byte Ed25519 validation.
 */
export function parseServerConfigText(rawText: string): ImportedServerConfig {
  if (rawText === undefined || rawText === null) {
    throw new Error('配置内容为空');
  }
  let text = rawText.trim();
  if (text.length === 0) {
    throw new Error('配置内容为空');
  }
  if (text.length > MAX_CONFIG_TEXT_BYTES) {
    throw new Error('配置内容超出大小限制 (最大 64KB)');
  }
  if (text.startsWith(RUSTDESK_CONFIG_URI_PREFIX)) {
    text = text.substring(RUSTDESK_CONFIG_URI_PREFIX.length).trim();
    if (text.startsWith('/')) {
      text = text.substring(1).trim();
    }
    try {
      text = decodeURIComponent(text).trim();
    } catch (_) {
      // Keep original text if URI decoding fails
    }
  }

  let json: ESObject | undefined = undefined;
  try {
    json = JSON.parse(text) as ESObject;
  } catch (_) {
    // Fall back to reversed base64 decode
  }

  if (json === undefined) {
    try {
      const reversed = text.split('').reverse().join('');
      let base64Str = reversed.replace(/-/g, '+').replace(/_/g, '/');
      const pad = base64Str.length % 4;
      if (pad === 2) {
        base64Str += '==';
      } else if (pad === 3) {
        base64Str += '=';
      } else if (pad === 1) {
        throw new Error('Base64 长度不合法');
      }
      const helper = new util.Base64Helper();
      const decodedBytes = helper.decodeSync(base64Str);
      const decodedText = util.TextDecoder.create('utf-8', { fatal: false }).decodeToString(decodedBytes);
      json = JSON.parse(decodedText) as ESObject;
    } catch (error) {
      throw new Error(`无法解析配置：请输入正确的 JSON 或官方反转 Base64 格式 (${String(error)})`);
    }
  }

  if (typeof json !== 'object' || json === null || Array.isArray(json)) {
    throw new Error('配置根结构必须为 JSON 对象');
  }

  const rawHost = extractStringField(json, 'host');
  const rawRelay = extractStringField(json, 'relay');
  const rawApi = extractStringField(json, 'api');
  const rawKey = extractStringField(json, 'key');

  const host = removeEndSlash(rawHost);
  const relay = removeEndSlash(rawRelay);
  const api = removeEndSlash(rawApi);
  const key = rawKey.trim();

  if (host.length === 0) {
    throw new Error('ID 服务器地址 (host) 不能为空');
  }

  return {
    host,
    relay,
    api,
    key,
  };
}

/**
 * Reads text content from system pasteboard.
 */
export async function readClipboardConfigText(): Promise<string> {
  const systemPasteboard = pasteboard.getSystemPasteboard();
  const data = await systemPasteboard.getData();
  if (data.getRecordCount() === 0) {
    throw new Error('剪贴板中没有内容');
  }
  for (let index = 0; index < data.getRecordCount(); index += 1) {
    const record = data.getRecord(index);
    if (record.plainText && record.plainText.trim().length > 0) {
      return record.plainText.trim();
    }
    if (record.toPlainText) {
      const text = record.toPlainText();
      if (text && text.trim().length > 0) {
        return text.trim();
      }
    }
  }
  throw new Error('剪贴板中未找到文本内容');
}

/**
 * Opens document view picker to let the user select a UTF-8 text/JSON server config file.
 * Returns undefined if user cancels.
 */
export async function pickServerConfigFile(context: common.UIAbilityContext): Promise<string | undefined> {
  const documentPicker = new picker.DocumentViewPicker(context);
  const options = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  const uris = await documentPicker.select(options);
  if (!uris || uris.length === 0) {
    return undefined;
  }
  const uri = uris[0];
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const stat = fileIo.statSync(file.fd);
    if (stat.size > MAX_CONFIG_TEXT_BYTES) {
      throw new Error(`配置文件过大 (${stat.size} 字节，最大支持 64KB)`);
    }
    const buf = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buf);
    const decoder = util.TextDecoder.create('utf-8', { fatal: true });
    return decoder.decodeToString(new Uint8Array(buf));
  } finally {
    fileIo.closeSync(file.fd);
  }
}
