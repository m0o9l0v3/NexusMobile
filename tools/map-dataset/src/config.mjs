/**
 * 対応設定（mapping config）の読み込みと検証。
 *
 * 設定は「どの原本のどの地物を、どの canonical ID・どの Feature 種別として採用するか」を
 * 明示するための唯一の入力であり、ここに書かれていない地物は黙って除外しない。
 */

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import Ajv2020Module from 'ajv/dist/2020.js';

const require = createRequire(import.meta.url);
/** @type {any} */
const Ajv2020 = /** @type {any} */ (Ajv2020Module).default ?? Ajv2020Module;

/** @type {Record<string, unknown>} */
const configSchema = require('./config.schema.json');

/**
 * @typedef {import('./sources/geojson-source.mjs').GeoJsonSourceSpec} GeoJsonSourceSpec
 * @typedef {import('./sources/excel-source.mjs').ExcelSourceSpec} ExcelSourceSpec
 */

/**
 * @typedef {object} InlineRecordSpec
 * @property {string} source_id
 * @property {string} [floor_id]
 * @property {string} [name]
 * @property {{type: 'Point'|'LineString'|'Polygon', coordinates: unknown}} [geometry_local]
 */

/**
 * @typedef {object} InlineSourceSpec
 * @property {'inline'} kind
 * @property {string} origin_note
 * @property {InlineRecordSpec[]} records
 */

/**
 * @typedef {GeoJsonSourceSpec | ExcelSourceSpec | InlineSourceSpec} SourceSpec
 */

/**
 * @typedef {object} FeatureEntry
 * @property {string} source
 * @property {string} source_id
 * @property {'property_id'|'feature_id'} [match_on]
 * @property {'include'|'exclude'} decision
 * @property {'building'|'formal_entrance'|'walking_path'|'indoor_node'|'outdoor_node'} [feature_type]
 * @property {string} [canonical_id]
 * @property {{use: 'property_id'|'feature_id', reason: string}} [resolve_id_conflict]
 * @property {{policy: 'require_agreement'|'from_source'|'explicit'|'omit', value?: string, reason?: string}} [name]
 * @property {Record<string, unknown>} [properties]
 * @property {string} [reason_code]
 * @property {string} [reason]
 */

/**
 * @typedef {object} IndoorTransformSpec
 * @property {string} floor_id
 * @property {string} building_id
 * @property {import('./transform.mjs').GeodeticOrigin} origin
 * @property {Record<string, unknown>[]} [anchors]
 * @property {string} [anchors_source]
 */

/**
 * @typedef {object} MappingConfig
 * @property {'1.0.0'} config_version
 * @property {string} dataset_name
 * @property {string} [description]
 * @property {Record<string, SourceSpec>} sources
 * @property {{source: string, id_column: string, name_column: string}} [building_registry]
 * @property {string[]} [reserved_ids]
 * @property {{id: string, building_id: string, name?: string}[]} floors
 * @property {FeatureEntry[]} features
 * @property {IndoorTransformSpec[]} [indoor_transforms]
 * @property {{blockers: {code: string, description: string, owner?: string}[]}} [publish_readiness]
 */

/**
 * @typedef {object} LoadedConfig
 * @property {MappingConfig} config
 * @property {string} configPath 絶対パス。
 * @property {string} inputRoot 絶対パス。
 * @property {(relativePath: string) => string} resolveInput
 */

export class ConfigError extends Error {}

/**
 * 設定ファイルを読み、スキーマ検証したうえで参照整合を確認する。
 *
 * @param {{configPath: string, inputRoot: string}} options
 * @returns {LoadedConfig}
 */
export function loadConfig(options) {
  const configPath = path.resolve(options.configPath);
  const inputRoot = path.resolve(options.inputRoot);

  /** @type {unknown} */
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(configPath, 'utf8'));
  } catch (error) {
    throw new ConfigError(`対応設定を読み込めない: ${configPath} / ${String(error)}`);
  }

  // strictRequired は if/then による条件付き required を許すために無効化する。
  const ajv = new Ajv2020({ strict: true, strictRequired: false, allErrors: true });
  const validate = ajv.compile(configSchema);
  if (!validate(parsed)) {
    const details = (validate.errors ?? [])
      .map((/** @type {{instancePath?: string, message?: string}} */ error) =>
        `  - ${error.instancePath || '/'}: ${error.message ?? ''}`,
      )
      .join('\n');
    throw new ConfigError(`対応設定がスキーマに適合しない: ${configPath}\n${details}`);
  }

  const config = /** @type {MappingConfig} */ (parsed);

  // 参照整合（スキーマでは表現できない部分）。
  /** @type {string[]} */
  const problems = [];
  const sourceKeys = new Set(Object.keys(config.sources));

  if (config.building_registry) {
    const registrySource = config.sources[config.building_registry.source];
    if (!registrySource) {
      problems.push(`building_registry.source "${config.building_registry.source}" が sources にない。`);
    } else if (registrySource.kind !== 'excel') {
      problems.push('building_registry.source は excel ソースでなければならない。');
    } else {
      for (const column of [config.building_registry.id_column, config.building_registry.name_column]) {
        if (!(column in registrySource.columns)) {
          problems.push(`building_registry が参照する論理名 "${column}" が excel ソースの columns にない。`);
        }
      }
    }
  }

  const floorIds = new Set(config.floors.map((floor) => floor.id));
  for (const floor of config.floors) {
    if (config.floors.filter((other) => other.id === floor.id).length > 1) {
      problems.push(`floors に重複した id "${floor.id}" がある。`);
    }
  }

  /** @type {Set<string>} */
  const seenEntryKeys = new Set();
  for (const entry of config.features) {
    if (!sourceKeys.has(entry.source)) {
      problems.push(`features のエントリが未定義の source "${entry.source}" を参照している。`);
    }
    const key = `${entry.source} ${entry.match_on ?? 'property_id'} ${entry.source_id}`;
    if (seenEntryKeys.has(key)) {
      problems.push(`features に重複したエントリがある: source=${entry.source}, source_id=${entry.source_id}`);
    }
    seenEntryKeys.add(key);
  }

  for (const transform of config.indoor_transforms ?? []) {
    if (!floorIds.has(transform.floor_id)) {
      problems.push(`indoor_transforms の floor_id "${transform.floor_id}" が floors に登録されていない。`);
    }
    if (transform.anchors_source !== undefined) {
      const anchorSource = config.sources[transform.anchors_source];
      if (!anchorSource) {
        problems.push(`indoor_transforms.anchors_source "${transform.anchors_source}" が sources にない。`);
      } else if (anchorSource.kind !== 'excel') {
        problems.push('indoor_transforms.anchors_source は excel ソースでなければならない。');
      }
    }
  }

  if (problems.length > 0) {
    const list = problems.map((problem) => `  - ${problem}`).join('\n');
    throw new ConfigError(`対応設定の参照整合に問題がある: ${configPath}\n${list}`);
  }

  return {
    config,
    configPath,
    inputRoot,
    resolveInput: (relativePath) => path.resolve(inputRoot, relativePath),
  };
}
