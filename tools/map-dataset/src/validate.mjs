/**
 * MapDataset GeoJSON の検証。
 *
 * 1. JSON Schema Draft 2020-12（docs/schemas/map-dataset-geojson-v1.schema.json）
 * 2. 出力を安全に生成するために不可欠な最小限の整合検査
 *
 * E2-2 の publish validator（到達可能性、孤立ノード、自己交差、キャンパス許容範囲、
 * alias 名前空間との突合など）はここでは扱わない。責務境界は
 * docs/e1-6-map-dataset-conversion.md を参照。
 */

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv2020Module from 'ajv/dist/2020.js';

import { Findings } from './findings.mjs';
import { collectPositions, isRounded, signedArea } from './geometry.mjs';

/** @type {any} */
const Ajv2020 = /** @type {any} */ (Ajv2020Module).default ?? Ajv2020Module;

const here = path.dirname(fileURLToPath(import.meta.url));

/** リポジトリ同梱のスキーマ既定パス（tools/map-dataset/src から見た相対）。 */
export const DEFAULT_SCHEMA_PATH = path.resolve(here, '../../../docs/schemas/map-dataset-geojson-v1.schema.json');

/**
 * @param {string} schemaPath
 */
export function createSchemaValidator(schemaPath) {
  const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));
  const ajv = new Ajv2020({ strict: true, allErrors: true });
  return ajv.compile(schema);
}

/**
 * @typedef {object} ValidateOptions
 * @property {string} [schemaPath]
 * @property {string[]} [reservedIds]
 * @property {string} [label] エラーメッセージに付ける対象名。
 */

/**
 * @param {unknown} dataset
 * @param {ValidateOptions} [options]
 * @returns {Findings}
 */
export function validateDataset(dataset, options = {}) {
  const findings = new Findings();
  const schemaPath = options.schemaPath ?? DEFAULT_SCHEMA_PATH;

  const validate = createSchemaValidator(schemaPath);
  if (!validate(dataset)) {
    for (const error of validate.errors ?? []) {
      findings.error(
        'schema_violation',
        `${error.instancePath || '/'}: ${error.message ?? 'スキーマ違反'}${
          error.params && Object.keys(error.params).length > 0 ? ` (${JSON.stringify(error.params)})` : ''
        }`,
      );
    }
    // スキーマ違反がある状態で参照整合を評価しても誤解を招くため、ここで返す。
    return findings;
  }

  const collection = /** @type {{nexus: {floors: {id: string, building_id: string}[]}, features: any[]}} */ (dataset);

  /** @type {Map<string, {building_id: string}>} */
  const floors = new Map();
  for (const floor of collection.nexus.floors) {
    if (floors.has(floor.id)) {
      findings.error('duplicate_floor_id', `nexus.floors に重複した id "${floor.id}" がある。`);
      continue;
    }
    floors.set(floor.id, { building_id: floor.building_id });
    if (!floor.id.startsWith(`${floor.building_id}_`)) {
      findings.error(
        'floor_building_prefix_mismatch',
        `floor "${floor.id}" の接頭辞が building_id "${floor.building_id}" と一致しない（E1-2）。`,
      );
    }
  }

  /** @type {Map<string, {feature_type: string, properties: Record<string, unknown>}>} */
  const features = new Map();
  const buildingIds = new Set();
  for (const feature of collection.features) {
    const id = String(feature.id);
    if (features.has(id)) {
      findings.error('duplicate_canonical_id', `Feature id "${id}" が payload 内で重複している（E1-4）。`, {
        canonical_id: id,
      });
      continue;
    }
    features.set(id, { feature_type: String(feature.properties.feature_type), properties: feature.properties });
    if (feature.properties.feature_type === 'building') buildingIds.add(id);
    if (Object.prototype.hasOwnProperty.call(feature.properties, 'id')) {
      findings.error(
        'canonical_id_duplicated_in_properties',
        `Feature "${id}": canonical ID を properties.id へ複製している（E1-4 共通 Feature 契約 2）。`,
        { canonical_id: id },
      );
    }
  }

  const reserved = new Set(options.reservedIds ?? []);
  for (const id of features.keys()) {
    if (reserved.has(id)) {
      findings.error('reserved_id_collision', `Feature id "${id}" が予約済み識別子と衝突している（E1-3）。`, {
        canonical_id: id,
      });
    }
  }
  for (const id of floors.keys()) {
    if (reserved.has(id)) {
      findings.error('reserved_id_collision', `floor id "${id}" が予約済み識別子と衝突している（E1-3）。`);
    }
    if (features.has(id)) {
      findings.error('floor_feature_id_collision', `floor id "${id}" が Feature id と衝突している。`);
    }
  }

  for (const feature of collection.features) {
    const id = String(feature.id);
    const properties = /** @type {Record<string, unknown>} */ (feature.properties);
    const at = { canonical_id: id };

    // 座標: 2次元・小数6桁・Polygon の閉鎖と向き。
    for (const position of collectPositions(feature.geometry)) {
      if (position.length !== 2) {
        findings.error('three_dimensional_position', `Feature "${id}": position が2要素ではない。`, at);
        continue;
      }
      for (const value of position) {
        if (!isRounded(value)) {
          findings.error(
            'coordinate_not_rounded',
            `Feature "${id}": 座標 ${value} が小数6桁へ丸められていない（E1-5）。`,
            at,
          );
        }
      }
    }
    if (feature.geometry.type === 'Polygon') {
      feature.geometry.coordinates.forEach((/** @type {[number, number][]} */ ring, /** @type {number} */ index) => {
        const first = ring[0];
        const last = ring[ring.length - 1];
        if (first[0] !== last[0] || first[1] !== last[1]) {
          findings.error('unclosed_ring', `Feature "${id}": ring[${index}] が閉じていない（E1-4）。`, at);
          return;
        }
        const area = signedArea(ring);
        if (area === 0) {
          findings.error('degenerate_ring', `Feature "${id}": ring[${index}] の面積が0。`, at);
          return;
        }
        const shouldBeCounterClockwise = index === 0;
        if (area > 0 !== shouldBeCounterClockwise) {
          findings.error(
            'ring_orientation',
            `Feature "${id}": ring[${index}] の向きが ${shouldBeCounterClockwise ? '反時計回り' : '時計回り'} ではない（E1-4）。`,
            at,
          );
        }
      });
    }

    /**
     * @param {string} propertyName
     * @param {'building'|'floor'|'indoor_node'|'outdoor_node'} expected
     */
    const requireReference = (propertyName, expected) => {
      const value = properties[propertyName];
      if (typeof value !== 'string') return;
      if (expected === 'floor') {
        if (!floors.has(value)) {
          findings.error(
            'undefined_reference',
            `Feature "${id}": ${propertyName} "${value}" が nexus.floors に存在しない。`,
            at,
          );
        }
        return;
      }
      if (expected === 'building') {
        if (!buildingIds.has(value)) {
          findings.error(
            'undefined_reference',
            `Feature "${id}": ${propertyName} "${value}" の building Feature が payload 内に存在しない。`,
            at,
          );
        }
        return;
      }
      const target = features.get(value);
      if (!target) {
        findings.error('undefined_reference', `Feature "${id}": ${propertyName} "${value}" が payload 内にない。`, at);
        return;
      }
      if (target.feature_type !== expected) {
        findings.error(
          'reference_type_mismatch',
          `Feature "${id}": ${propertyName} "${value}" の feature_type が ${target.feature_type}。${expected} が必要。`,
          at,
        );
      }
    };

    const featureType = properties.feature_type;

    if (featureType === 'indoor_node' || featureType === 'formal_entrance' || (featureType === 'walking_path' && properties.scope === 'indoor')) {
      requireReference('building_id', 'building');
      requireReference('floor_id', 'floor');
      const floorId = properties.floor_id;
      const buildingId = properties.building_id;
      if (typeof floorId === 'string' && typeof buildingId === 'string') {
        const floor = floors.get(floorId);
        if (floor && floor.building_id !== buildingId) {
          findings.error(
            'floor_building_mismatch',
            `Feature "${id}": floor "${floorId}" は building "${floor.building_id}" 配下で、building_id "${buildingId}" と一致しない。`,
            at,
          );
        }
      }
      if (typeof buildingId === 'string' && featureType === 'formal_entrance' && !id.startsWith(`${buildingId}_`)) {
        findings.error(
          'entrance_building_prefix_mismatch',
          `Feature "${id}": 入口IDの接頭辞が building_id "${buildingId}" と一致しない（E1-4 正式入口）。`,
          at,
        );
      }
    }

    if (featureType === 'formal_entrance') {
      requireReference('outside_node_id', 'outdoor_node');
      requireReference('inside_node_id', 'indoor_node');
      const insideId = properties.inside_node_id;
      const floorId = properties.floor_id;
      if (typeof insideId === 'string' && typeof floorId === 'string') {
        const inside = features.get(insideId);
        if (inside && inside.properties.floor_id !== floorId) {
          findings.error(
            'entrance_inside_node_floor_mismatch',
            `Feature "${id}": inside_node_id "${insideId}" が floor "${floorId}" に属していない（E1-4）。`,
            at,
          );
        }
      }
    }

    if (featureType === 'walking_path') {
      const nodeType = properties.scope === 'indoor' ? 'indoor_node' : 'outdoor_node';
      requireReference('from_node_id', nodeType);
      requireReference('to_node_id', nodeType);
      if (properties.from_node_id === properties.to_node_id) {
        findings.error('self_loop_path', `Feature "${id}": from_node_id と to_node_id が同一（E1-4）。`, at);
      }
      if (properties.scope === 'indoor') {
        for (const propertyName of ['from_node_id', 'to_node_id']) {
          const nodeId = properties[propertyName];
          if (typeof nodeId !== 'string') continue;
          const node = features.get(nodeId);
          if (node && node.properties.floor_id !== properties.floor_id) {
            findings.error(
              'path_node_floor_mismatch',
              `Feature "${id}": ${propertyName} "${nodeId}" が floor "${String(properties.floor_id)}" に属していない。`,
              at,
            );
          }
        }
      }
      // LineString の端点とノード座標の一致（E1-4 経路端点契約の最小確認）。
      const line = /** @type {[number, number][]} */ (feature.geometry.coordinates);
      for (const [propertyName, position] of /** @type {[string, [number, number]][]} */ ([
        ['from_node_id', line[0]],
        ['to_node_id', line[line.length - 1]],
      ])) {
        const nodeId = properties[propertyName];
        if (typeof nodeId !== 'string') continue;
        const node = features.get(nodeId);
        if (!node) continue;
        const nodeFeature = collection.features.find((candidate) => String(candidate.id) === nodeId);
        if (!nodeFeature || nodeFeature.geometry.type !== 'Point') continue;
        const nodePosition = /** @type {[number, number]} */ (nodeFeature.geometry.coordinates);
        if (nodePosition[0] !== position[0] || nodePosition[1] !== position[1]) {
          findings.error(
            'path_endpoint_mismatch',
            `Feature "${id}": LineString の端点が ${propertyName} "${nodeId}" の座標と一致しない（E1-4）。`,
            at,
          );
        }
      }
    }
  }

  return findings;
}

/**
 * ファイルを読んで検証する。
 * @param {string} datasetPath
 * @param {ValidateOptions} [options]
 * @returns {{dataset: unknown, findings: Findings}}
 */
export function validateDatasetFile(datasetPath, options = {}) {
  const findings = new Findings();
  /** @type {unknown} */
  let dataset;
  try {
    dataset = JSON.parse(readFileSync(datasetPath, 'utf8'));
  } catch (error) {
    findings.error('invalid_json', `${datasetPath}: JSON として読み込めない（${String(error)}）。`);
    return { dataset: null, findings };
  }
  findings.merge(validateDataset(dataset, options));
  return { dataset, findings };
}
