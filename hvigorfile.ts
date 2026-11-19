import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { execFileSync } from 'child_process';
import { getNode } from '@ohos/hvigor';
import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';

const SIGNING_DIRECTORY_ENV = 'RUSTDESK_SIGNING_DIR';
const SIGNING_CONFIG_FILE = 'signingConfigs.json';

// AGCD injects the rd-engine HAR and the categorized release changelog into the workspace
// before a local build; neither file is tracked.
const INJECTED_HAR_FILE = 'rustdesk-ohrs.har';
const INSTALLED_HAR_DIRECTORY = path.join('oh_modules', 'rustdesk-ohrs');
const HAR_STAMP_FILE = path.join('oh_modules', '.rustdesk-ohrs-har.sha256');
const HAR_SYNC_DIRECTORY = path.join('oh_modules', '.rustdesk-ohrs-sync');
const AGCD_CHANGELOG_FILE = 'agcd-changelog.json';
const MAX_VERSION_CODE = 2147483647;

interface SigningMaterial {
  storeFile: string;
  storePassword: string;
  keyAlias: string;
  keyPassword: string;
  signAlg: string;
  profile: string;
  certpath: string;
}

interface SigningConfig {
  [key: string]: unknown;
  name: string;
  material: SigningMaterial;
  type?: string;
}

interface SigningConfigInput {
  name?: unknown;
  material?: unknown;
  type?: unknown;
}

interface SigningMaterialInput {
  storeFile?: unknown;
  storePassword?: unknown;
  keyAlias?: unknown;
  keyPassword?: unknown;
  signAlg?: unknown;
  profile?: unknown;
  certpath?: unknown;
}

interface AgcdVersion {
  versionName: string;
  versionCode: number;
}

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Signing configuration field ${fieldName} must be a non-empty string.`);
  }
  return value;
}

function parseSigningMaterial(value: unknown, configName: string): SigningMaterial {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error(`Signing configuration ${configName} has no valid material object.`);
  }
  const input = value as SigningMaterialInput;
  return {
    storeFile: requireString(input.storeFile, `${configName}.material.storeFile`),
    storePassword: requireString(input.storePassword, `${configName}.material.storePassword`),
    keyAlias: requireString(input.keyAlias, `${configName}.material.keyAlias`),
    keyPassword: requireString(input.keyPassword, `${configName}.material.keyPassword`),
    signAlg: requireString(input.signAlg, `${configName}.material.signAlg`),
    profile: requireString(input.profile, `${configName}.material.profile`),
    certpath: requireString(input.certpath, `${configName}.material.certpath`)
  };
}

function parseSigningConfig(value: unknown): SigningConfig {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('Each signing configuration must be an object.');
  }
  const input = value as SigningConfigInput;
  const name = requireString(input.name, 'name');
  const config: SigningConfig = {
    name: name,
    material: parseSigningMaterial(input.material, name)
  };
  if (input.type !== undefined) {
    config.type = requireString(input.type, `${name}.type`);
  }
  return config;
}

function assertMaterialFile(filePath: string, fieldName: string): void {
  if (!path.isAbsolute(filePath)) {
    throw new Error(`Signing material ${fieldName} must resolve to an absolute path.`);
  }
  let realFilePath: string;
  try {
    realFilePath = fs.realpathSync(filePath);
    fs.accessSync(realFilePath, fs.constants.R_OK);
  } catch {
    throw new Error(`Signing material ${fieldName} is missing or unreadable.`);
  }
  if (!fs.statSync(realFilePath).isFile()) {
    throw new Error(`Signing material ${fieldName} must be a regular file.`);
  }
}

function validateSigningMaterials(configs: SigningConfig[]): void {
  for (const config of configs) {
    assertMaterialFile(config.material.storeFile, `${config.name}.storeFile`);
    assertMaterialFile(config.material.profile, `${config.name}.profile`);
    assertMaterialFile(config.material.certpath, `${config.name}.certpath`);
  }
}

function loadSigningConfigs(): SigningConfig[] | undefined {
  const configuredDirectory = process.env[SIGNING_DIRECTORY_ENV];
  if (!configuredDirectory) {
    return undefined;
  }

  const signingRoot = path.resolve(configuredDirectory);
  const signingConfigPath = path.join(signingRoot, SIGNING_CONFIG_FILE);
  let rawConfig: string;
  try {
    rawConfig = fs.readFileSync(signingConfigPath, 'utf8');
  } catch {
    throw new Error('RUSTDESK_SIGNING_DIR must contain a readable signingConfigs.json file.');
  }
  let parsedConfig: unknown;
  try {
    parsedConfig = JSON.parse(rawConfig) as unknown;
  } catch {
    throw new Error('signingConfigs.json must contain valid JSON.');
  }
  if (!Array.isArray(parsedConfig) || parsedConfig.length === 0) {
    throw new Error('signingConfigs.json must contain a non-empty array.');
  }

  const configs = parsedConfig.map((value: unknown): SigningConfig => parseSigningConfig(value));
  const configNames = new Set<string>();
  for (const config of configs) {
    if (configNames.has(config.name)) {
      throw new Error(`Duplicate signing configuration name: ${config.name}.`);
    }
    configNames.add(config.name);
  }
  if (!configNames.has('default') || !configNames.has('publish')) {
    throw new Error('signingConfigs.json must contain default and publish configurations.');
  }

  validateSigningMaterials(configs);
  return configs;
}

function sha256OfFile(filePath: string): string {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function readRecordedHarDigest(): string | undefined {
  try {
    return fs.readFileSync(HAR_STAMP_FILE, 'utf8').trim();
  } catch {
    return undefined;
  }
}

// ohpm expands a `file:` HAR dependency once, so a HAR replaced in place would keep the
// previous engine compiled into the app. Refresh the installed package whenever the injected
// archive no longer matches the recorded digest; `ohpm install` stays the only installer.
function syncInjectedHar(): void {
  if (!fs.existsSync(INJECTED_HAR_FILE) || !fs.existsSync(INSTALLED_HAR_DIRECTORY)) {
    return;
  }

  const harDigest = sha256OfFile(INJECTED_HAR_FILE);
  const installedPackageFile = path.join(INSTALLED_HAR_DIRECTORY, 'oh-package.json5');
  if (readRecordedHarDigest() === harDigest && fs.existsSync(installedPackageFile)) {
    return;
  }

  // ohpm links a local HAR into the shared cache, so the link target owns the real files.
  const installedDirectory = fs.realpathSync(INSTALLED_HAR_DIRECTORY);
  try {
    fs.rmSync(HAR_SYNC_DIRECTORY, { recursive: true, force: true });
    fs.mkdirSync(HAR_SYNC_DIRECTORY, { recursive: true });
    execFileSync('tar', ['-xzf', INJECTED_HAR_FILE, '--strip-components=1', '-C', HAR_SYNC_DIRECTORY]);
    for (const entry of fs.readdirSync(installedDirectory)) {
      fs.rmSync(path.join(installedDirectory, entry), { recursive: true, force: true });
    }
    for (const entry of fs.readdirSync(HAR_SYNC_DIRECTORY)) {
      fs.cpSync(path.join(HAR_SYNC_DIRECTORY, entry), path.join(installedDirectory, entry), { recursive: true });
    }
    fs.writeFileSync(HAR_STAMP_FILE, `${harDigest}\n`, 'utf8');
  } catch (error) {
    throw new Error(`Unable to sync ${INJECTED_HAR_FILE} into ${INSTALLED_HAR_DIRECTORY}: ${error}`);
  } finally {
    fs.rmSync(HAR_SYNC_DIRECTORY, { recursive: true, force: true });
  }
  console.log(`> hvigor Synced ${INJECTED_HAR_FILE} into ${INSTALLED_HAR_DIRECTORY} (${harDigest.slice(0, 12)}).`);
}

function loadAgcdVersion(): AgcdVersion | undefined {
  if (!fs.existsSync(AGCD_CHANGELOG_FILE)) {
    return undefined;
  }

  let payload: unknown;
  try {
    payload = JSON.parse(fs.readFileSync(AGCD_CHANGELOG_FILE, 'utf8')) as unknown;
  } catch {
    throw new Error(`${AGCD_CHANGELOG_FILE} must contain valid JSON.`);
  }
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    throw new Error(`${AGCD_CHANGELOG_FILE} must contain a JSON object.`);
  }

  const record = payload as Record<string, unknown>;
  const versionName = record.versionName;
  if (typeof versionName !== 'string' || versionName.trim().length === 0) {
    throw new Error(`${AGCD_CHANGELOG_FILE} must carry a non-empty versionName.`);
  }
  const versionCode = record.versionCode;
  if (typeof versionCode !== 'number' || !Number.isInteger(versionCode)
    || versionCode < 1 || versionCode > MAX_VERSION_CODE) {
    throw new Error(`${AGCD_CHANGELOG_FILE} must carry an integer versionCode between 1 and ${MAX_VERSION_CODE}.`);
  }
  return { versionName: versionName.trim(), versionCode: versionCode };
}

function injectAgcdVersion(appContext: OhosAppContext): void {
  const agcdVersion = loadAgcdVersion();
  if (!agcdVersion) {
    return;
  }

  // The release identity belongs to AGCD; tracked AppScope/app.json5 keeps the local baseline.
  const appJson = appContext.getAppJsonOpt();
  appJson.app.versionName = agcdVersion.versionName;
  appJson.app.versionCode = agcdVersion.versionCode;
  appContext.setAppJsonOpt(appJson);
  console.log(`> hvigor Injected ${AGCD_CHANGELOG_FILE} version ${agcdVersion.versionName} (${agcdVersion.versionCode}).`);
}

syncInjectedHar();

const rootNode = getNode(__filename);
if (!rootNode) {
  throw new Error('Unable to access the root Hvigor node.');
}
rootNode.afterNodeEvaluate((node) => {
  const appContext = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext | undefined;
  if (!appContext) {
    throw new Error('Unable to access the HarmonyOS App build context.');
  }
  injectAgcdVersion(appContext);

  const signingConfigs = loadSigningConfigs();
  if (!signingConfigs) {
    return;
  }

  const buildProfile = appContext.getBuildProfileOpt();
  const products = buildProfile.app.products;
  if (!Array.isArray(products)) {
    throw new Error('build-profile.json5 must define App products.');
  }

  const requiredProducts = new Set<string>(['default', 'publish']);
  for (const product of products) {
    if (requiredProducts.has(product.name)) {
      product.signingConfig = product.name;
      requiredProducts.delete(product.name);
    }
  }
  if (requiredProducts.size > 0) {
    throw new Error('build-profile.json5 must define default and publish products.');
  }

  buildProfile.app.signingConfigs = signingConfigs;
  appContext.setBuildProfileOpt(buildProfile);
  console.log('> hvigor Injected RustDesk signing configuration from RUSTDESK_SIGNING_DIR.');
});

export default {
  system: appTasks,
  plugins: []
}
