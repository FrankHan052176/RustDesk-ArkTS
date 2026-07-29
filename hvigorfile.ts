import fs from 'fs';
import path from 'path';
import { getNode } from '@ohos/hvigor';
import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';

const SIGNING_DIRECTORY_ENV = 'RUSTDESK_SIGNING_DIR';
const SIGNING_CONFIG_FILE = 'signingConfigs.json';

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

const rootNode = getNode(__filename);
if (!rootNode) {
  throw new Error('Unable to access the root Hvigor node.');
}
rootNode.afterNodeEvaluate((node) => {
  const signingConfigs = loadSigningConfigs();
  if (!signingConfigs) {
    return;
  }

  const appContext = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext | undefined;
  if (!appContext) {
    throw new Error('Unable to access the HarmonyOS App build context.');
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
