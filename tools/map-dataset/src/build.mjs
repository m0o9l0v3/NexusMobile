/**
 * MapDataset GeoJSON の決定的生成。
 *
 * 原本（QGIS由来GeoJSON / 実地調査Excel / 明示インライン値）と対応設定だけを入力とし、
 * 同じ入力からバイト単位で同じ出力を作る。
 *
 * 設定にない地物、重複ID、IDの不一致、未確認値は黙って除外・補正せず、
 * すべて検証レポートへ理由付きで残す。
 */

import { Findings } from './findings.mjs';
import { normalizeGeometry } from './geometry.mjs';
import { compareIds } from './serialize.mjs';
import { readGeoJsonSource } from './sources/geojson-source.mjs';
import { readExcelSource } from './sources/excel-source.mjs';
import { evaluateFloorTransform, normalizeAnchor } from './anchors.mjs';
import { applySimilarity, enuToWgs84 } from './transform.mjs';

/**
 * Feature 種別ごとの geometry 型と、出力時のプロパティ順（E1-4）。
 */
export const FEATURE_TYPE_SPECS = Object.freeze({
  building: { geometry: /** @type {const} */ ('Polygon'), order: ['feature_type', 'name'] },
  formal_entrance: {
    geometry: /** @type {const} */ ('Point'),
    order: [
      'feature_type',
      'building_id',
      'floor_id',
      'outside_node_id',
      'inside_node_id',
      'is_primary',
      'accessibility',
      'name',
      'opening_hours',
    ],
  },
  walking_path: {
    geometry: /** @type {const} */ ('LineString'),
    order: [
      'feature_type',
      'scope',
      'building_id',
      'floor_id',
      'from_node_id',
      'to_node_id',
      'path_kind',
      'bidirectional',
      'accessibility',
      'distance_m',
      'estimated_seconds',
    ],
  },
  indoor_node: {
    geometry: /** @type {const} */ ('Point'),
    order: ['feature_type', 'building_id', 'floor_id', 'node_kind', 'name'],
  },
  outdoor_node: {
    geometry: /** @type {const} */ ('Point'),
    order: ['feature_type', 'scope', 'node_kind', 'name'],
  },
});

/**
 * @typedef {object} SourceRecord 原本1件分の共通表現。
 * @property {string} source_key
 * @property {string|null} source_feature_id
 * @property {string|null} source_property_id
 * @property {boolean} id_conflict
 * @property {unknown} [geometry] WGS 84 geometry（GeoJSON 原本）。
 * @property {{type: 'Point'|'LineString'|'Polygon', coordinates: unknown}} [geometry_local] floor-local geometry。
 * @property {string} [floor_id]
 * @property {string|null} source_name 原本が持つ表示名。
 * @property {Record<string, unknown>} properties
 * @property {import('./findings.mjs').SourceRef} source
 * @property {number} order 原本内の並び（決定的な報告順のため）。
 */

/**
 * @typedef {object} TraceEntry
 * @property {'included'|'excluded'|'failed'} result
 * @property {string|null} canonical_id
 * @property {string|null} feature_type
 * @property {import('./findings.mjs').SourceRef} source
 * @property {string[]} dropped_properties
 * @property {string[]} notes
 * @property {string} [reason_code]
 * @property {string} [reason]
 */

/**
 * @typedef {object} BuildResult
 * @property {Record<string, unknown>|null} dataset
 * @property {Findings} findings
 * @property {TraceEntry[]} trace
 * @property {import('./anchors.mjs').FloorTransformResult[]} transforms
 * @property {{code: string, description: string, owner?: string}[]} blockers
 * @property {{source_records: number, included: number, excluded: number, failed: number}} counts
 */

/**
 * 原本を読み、共通表現の配列へ整える。
 *
 * @param {import('./config.mjs').LoadedConfig} loaded
 * @param {Findings} findings
 * @returns {Map<string, SourceRecord[]>}
 */
function readSources(loaded, findings) {
  /** @type {Map<string, SourceRecord[]>} */
  const bySource = new Map();
  for (const [key, spec] of Object.entries(loaded.config.sources)) {
    if (spec.kind === 'geojson') {
      const records = readGeoJsonSource(spec, loaded.resolveInput(spec.path), findings);
      bySource.set(
        key,
        records.map((record, index) => ({
          source_key: key,
          source_feature_id: record.source_feature_id,
          source_property_id: record.source_property_id,
          id_conflict: record.id_conflict,
          geometry: record.geometry,
          source_name: typeof record.properties.name === 'string' ? record.properties.name : null,
          properties: record.properties,
          source: record.source,
          order: index,
        })),
      );
      continue;
    }
    if (spec.kind === 'excel') {
      // Excel ソースは建物レジストリ・アンカー入力として使う。Feature geometry の供給元にはしない。
      const rows = readExcelSource(spec, loaded.resolveInput(spec.path), findings);
      bySource.set(
        key,
        rows.map((row, index) => ({
          source_key: key,
          source_feature_id: null,
          source_property_id: null,
          id_conflict: false,
          source_name: null,
          properties: row.values,
          source: row.source,
          order: index,
        })),
      );
      continue;
    }
    bySource.set(
      key,
      spec.records.map((record, index) => ({
        source_key: key,
        source_feature_id: null,
        source_property_id: record.source_id,
        id_conflict: false,
        geometry_local: record.geometry_local,
        floor_id: record.floor_id,
        source_name: record.name ?? null,
        properties: {},
        source: { file: `${loaded.configPath} (inline: ${key})` },
        order: index,
      })),
    );
  }
  return bySource;
}

/**
 * 建物レジストリ（canonical building ID -> 表示名）を作る。
 *
 * @param {import('./config.mjs').LoadedConfig} loaded
 * @param {Map<string, SourceRecord[]>} sources
 * @param {Findings} findings
 * @returns {Map<string, string>}
 */
function buildRegistry(loaded, sources, findings) {
  /** @type {Map<string, string>} */
  const registry = new Map();
  const spec = loaded.config.building_registry;
  if (!spec) return registry;
  for (const record of sources.get(spec.source) ?? []) {
    const id = String(record.properties[spec.id_column] ?? '').trim();
    const name = String(record.properties[spec.name_column] ?? '').trim();
    if (id === '') continue;
    if (registry.has(id)) {
      findings.error('duplicate_registry_id', `建物レジストリに重複した ID "${id}" がある。`, {
        source: record.source,
      });
      continue;
    }
    registry.set(id, name);
  }
  return registry;
}

/**
 * indoor_transforms を評価する。
 *
 * @param {import('./config.mjs').LoadedConfig} loaded
 * @param {Map<string, SourceRecord[]>} sources
 * @param {Findings} findings
 * @returns {Map<string, import('./anchors.mjs').FloorTransformResult>}
 */
function evaluateTransforms(loaded, sources, findings) {
  /** @type {Map<string, import('./anchors.mjs').FloorTransformResult>} */
  const results = new Map();
  for (const spec of loaded.config.indoor_transforms ?? []) {
    /** @type {{raw: Record<string, unknown>, source: import('./findings.mjs').SourceRef}[]} */
    const rawAnchors = [];
    if (spec.anchors) {
      spec.anchors.forEach((raw, index) => {
        rawAnchors.push({
          raw,
          source: { file: `${loaded.configPath} (indoor_transforms[${spec.floor_id}].anchors[${index}])` },
        });
      });
    } else if (spec.anchors_source) {
      for (const record of sources.get(spec.anchors_source) ?? []) {
        rawAnchors.push({ raw: record.properties, source: record.source });
      }
    }

    /** @type {import('./anchors.mjs').Anchor[]} */
    const anchors = [];
    let anchorsOk = true;
    for (const { raw, source } of rawAnchors) {
      const anchor = normalizeAnchor(raw, {
        findings,
        source,
        floor_id: spec.floor_id,
        building_id: spec.building_id,
      });
      if (anchor === null) anchorsOk = false;
      else anchors.push(anchor);
    }

    const result = evaluateFloorTransform(
      { floor_id: spec.floor_id, building_id: spec.building_id, origin: spec.origin },
      anchors,
      findings,
    );
    if (!anchorsOk) result.status = 'failed';
    results.set(spec.floor_id, result);
  }
  return results;
}

/**
 * floor-local geometry を WGS 84 geometry へ変換する（丸めは normalizeGeometry 側）。
 *
 * @param {{type: 'Point'|'LineString'|'Polygon', coordinates: unknown}} localGeometry
 * @param {import('./anchors.mjs').FloorTransformResult} transform
 * @returns {{type: string, coordinates: unknown}}
 */
function projectLocalGeometry(localGeometry, transform) {
  const params = transform.params;
  if (params === null) throw new Error(`フロア ${transform.floor_id} の変換パラメータが未確定。`);
  /**
   * @param {unknown} node
   * @returns {unknown}
   */
  const walk = (node) => {
    if (!Array.isArray(node)) throw new Error('floor-local coordinates の構造が不正。');
    if (typeof node[0] === 'number') {
      if (node.length !== 2 || typeof node[1] !== 'number') {
        throw new Error('floor-local position は [x_m, y_m] の2要素固定。');
      }
      const enu = applySimilarity(node[0], node[1], params);
      const wgs84 = enuToWgs84(enu.east_m, enu.north_m, transform.origin);
      return [wgs84.longitude, wgs84.latitude];
    }
    return node.map(walk);
  };
  return { type: localGeometry.type, coordinates: walk(localGeometry.coordinates) };
}

/**
 * 対応設定に従って MapDataset FeatureCollection を組み立てる。
 *
 * @param {import('./config.mjs').LoadedConfig} loaded
 * @returns {BuildResult}
 */
export function buildDataset(loaded) {
  const findings = new Findings();
  const { config } = loaded;

  const sources = readSources(loaded, findings);
  const registry = buildRegistry(loaded, sources, findings);
  const transforms = evaluateTransforms(loaded, sources, findings);

  /** @type {TraceEntry[]} */
  const trace = [];
  /** @type {Record<string, unknown>[]} */
  const features = [];
  /** @type {Map<string, import('./findings.mjs').SourceRef>} */
  const usedCanonicalIds = new Map();
  /** @type {Set<string>} */
  const matchedRecordKeys = new Set();

  /** @param {SourceRecord} record */
  const recordKey = (record) => `${record.source_key}#${record.order}`;

  for (const entry of config.features) {
    const matchOn = entry.match_on ?? 'property_id';
    const candidates = (sources.get(entry.source) ?? []).filter((record) =>
      matchOn === 'feature_id' ? record.source_feature_id === entry.source_id : record.source_property_id === entry.source_id,
    );

    if (candidates.length === 0) {
      findings.error(
        'missing_source_feature',
        `対応設定のエントリ（source=${entry.source}, ${matchOn}=${entry.source_id}）に対応する地物が原本にない。`,
      );
      continue;
    }
    if (candidates.length > 1) {
      findings.error(
        'ambiguous_source_match',
        `対応設定のエントリ（source=${entry.source}, ${matchOn}=${entry.source_id}）が原本の ${candidates.length} 件に一致する。原本側でIDを一意にする。`,
        { source: candidates[0].source },
      );
      continue;
    }

    const record = candidates[0];
    matchedRecordKeys.add(recordKey(record));

    if (entry.decision === 'exclude') {
      trace.push({
        result: 'excluded',
        canonical_id: null,
        feature_type: null,
        source: record.source,
        dropped_properties: Object.keys(record.properties).sort(compareIds),
        notes: [],
        reason_code: entry.reason_code,
        reason: entry.reason,
      });
      continue;
    }

    const canonicalId = /** @type {string} */ (entry.canonical_id);
    const featureType = /** @type {keyof typeof FEATURE_TYPE_SPECS} */ (entry.feature_type);
    const spec = FEATURE_TYPE_SPECS[featureType];
    /** @type {string[]} */
    const notes = [];
    let entryOk = true;

    if (usedCanonicalIds.has(canonicalId)) {
      findings.error(
        'duplicate_canonical_id',
        `canonical ID "${canonicalId}" が複数の原本地物へ割り当てられている。`,
        { source: record.source, canonical_id: canonicalId },
      );
      entryOk = false;
    } else {
      usedCanonicalIds.set(canonicalId, record.source);
    }

    if (record.id_conflict) {
      if (!entry.resolve_id_conflict) {
        findings.error(
          'feature_id_conflict',
          `原本の Feature id "${String(record.source_feature_id)}" と properties.id "${String(record.source_property_id)}" が不一致。採用するIDを resolve_id_conflict で明示するまで canonical ID へ移行しない（E1-4）。`,
          { source: record.source, canonical_id: canonicalId },
        );
        entryOk = false;
      } else {
        notes.push(
          `ID不一致を resolve_id_conflict=${entry.resolve_id_conflict.use} で解決: ${entry.resolve_id_conflict.reason}`,
        );
      }
    }

    // 表示名の決定。原本間で食い違う場合は勝手に選ばない。
    /** @type {string|undefined} */
    let displayName;
    const policy = entry.name?.policy ?? 'omit';
    const sourceName = record.source_name !== null && record.source_name.trim() !== '' ? record.source_name.trim() : null;
    const registryName = registry.get(canonicalId);
    if (policy === 'explicit') {
      displayName = entry.name?.value;
    } else if (policy === 'from_source') {
      if (sourceName === null) {
        findings.error('missing_display_name', `"${canonicalId}": 原本に表示名がなく from_source を満たせない。`, {
          source: record.source,
          canonical_id: canonicalId,
        });
        entryOk = false;
      } else {
        displayName = sourceName;
      }
    } else if (policy === 'require_agreement') {
      if (sourceName === null || registryName === undefined || registryName === '') {
        findings.error(
          'missing_display_name',
          `"${canonicalId}": require_agreement には原本と建物レジストリの双方の表示名が必要（原本=${String(sourceName)}, レジストリ=${String(registryName)}）。`,
          { source: record.source, canonical_id: canonicalId },
        );
        entryOk = false;
      } else if (sourceName !== registryName) {
        findings.error(
          'display_name_conflict',
          `"${canonicalId}": 表示名が原本間で不一致（原本="${sourceName}" / レジストリ="${registryName}"）。どちらかを推定採用せず、正式名称を確定するか name.policy を明示する。`,
          { source: record.source, canonical_id: canonicalId },
        );
        entryOk = false;
      } else {
        displayName = sourceName;
      }
    } else if (entry.name === undefined) {
      // name を持てる Feature 種別だけ、未設定を警告する。
      if (spec.order.includes('name')) {
        findings.warn(
          'display_name_not_configured',
          `"${canonicalId}": name の扱いが未設定のため表示名を出力しない。`,
          { source: record.source, canonical_id: canonicalId },
        );
      }
    } else {
      notes.push(`表示名を出力しない: ${String(entry.name.reason)}`);
    }

    // geometry の決定。
    /** @type {{type: string, coordinates: unknown}|null} */
    let geometry = null;
    if (record.geometry_local !== undefined) {
      const floorId = record.floor_id;
      if (floorId === undefined) {
        findings.error('missing_floor_id', `"${canonicalId}": geometry_local には floor_id が必要。`, {
          source: record.source,
          canonical_id: canonicalId,
        });
        entryOk = false;
      } else {
        const transform = transforms.get(floorId);
        if (!transform) {
          findings.error(
            'missing_indoor_transform',
            `"${canonicalId}": floor "${floorId}" の indoor_transforms が未定義。実アンカーが登録されるまで屋内geometryを出力しない。`,
            { source: record.source, canonical_id: canonicalId },
          );
          entryOk = false;
        } else if (transform.status !== 'ok') {
          findings.error(
            'unusable_indoor_transform',
            `"${canonicalId}": floor "${floorId}" の変換が合格条件を満たしていないため座標を出力しない。`,
            { source: record.source, canonical_id: canonicalId },
          );
          entryOk = false;
        } else {
          try {
            const projected = projectLocalGeometry(record.geometry_local, transform);
            notes.push(`floor-local 座標を floor "${floorId}" の相似変換で WGS 84 へ変換した。`);
            geometry = normalizeGeometry(projected, spec.geometry, {
              findings,
              source: record.source,
              canonical_id: canonicalId,
            }).geometry;
          } catch (error) {
            findings.error(
              'local_geometry_projection_failed',
              `"${canonicalId}": ${(error instanceof Error ? error : new Error(String(error))).message}`,
              { source: record.source, canonical_id: canonicalId },
            );
            entryOk = false;
          }
        }
      }
    } else {
      const normalized = normalizeGeometry(record.geometry, spec.geometry, {
        findings,
        source: record.source,
        canonical_id: canonicalId,
      });
      geometry = normalized.geometry;
      notes.push(...normalized.notes);
    }
    if (geometry === null) entryOk = false;

    // プロパティ。原本の未知・スタイル属性は持ち込まず、設定で宣言した値だけを出力する。
    /** @type {Record<string, unknown>} */
    const configured = { ...(entry.properties ?? {}) };
    const unknownKeys = Object.keys(configured).filter((key) => !spec.order.includes(key));
    if (unknownKeys.length > 0) {
      findings.error(
        'unknown_configured_property',
        `"${canonicalId}": feature_type=${featureType} に存在しないプロパティ ${unknownKeys.join(', ')} が設定されている（E1-4 は未知プロパティを拒否する）。`,
        { source: record.source, canonical_id: canonicalId },
      );
      entryOk = false;
    }
    if (Object.prototype.hasOwnProperty.call(configured, 'feature_type')) {
      findings.error(
        'unknown_configured_property',
        `"${canonicalId}": feature_type は properties ではなく feature_type フィールドで指定する。`,
        { source: record.source, canonical_id: canonicalId },
      );
      entryOk = false;
    }

    const droppedProperties = Object.keys(record.properties).sort(compareIds);

    if (!entryOk || geometry === null) {
      trace.push({
        result: 'failed',
        canonical_id: canonicalId,
        feature_type: featureType,
        source: record.source,
        dropped_properties: droppedProperties,
        notes,
      });
      continue;
    }

    /** @type {Record<string, unknown>} */
    const properties = {};
    for (const key of spec.order) {
      if (key === 'feature_type') {
        properties.feature_type = featureType;
        continue;
      }
      if (key === 'name') {
        if (displayName !== undefined) properties.name = displayName;
        continue;
      }
      if (Object.prototype.hasOwnProperty.call(configured, key)) properties[key] = configured[key];
    }

    features.push({ type: 'Feature', id: canonicalId, geometry, properties });
    trace.push({
      result: 'included',
      canonical_id: canonicalId,
      feature_type: featureType,
      source: record.source,
      dropped_properties: droppedProperties,
      notes,
    });
  }

  // 設定にない原本地物を黙って除外しない。
  for (const [key, records] of sources) {
    const spec = config.sources[key];
    if (spec.kind === 'excel') continue; // レジストリ・アンカー入力は Feature 対応表の対象外。
    for (const record of records) {
      if (matchedRecordKeys.has(recordKey(record))) continue;
      findings.error(
        'unmapped_source_feature',
        `原本の地物（source=${key}, feature_id=${String(record.source_feature_id)}, properties.id=${String(record.source_property_id)}）が対応設定にない。採用か除外かを理由付きで明示する。`,
        { source: record.source },
      );
      trace.push({
        result: 'failed',
        canonical_id: null,
        feature_type: null,
        source: record.source,
        dropped_properties: Object.keys(record.properties).sort(compareIds),
        notes: ['対応設定に未登録。'],
        reason_code: 'unmapped_source_feature',
      });
    }
  }

  const floors = [...config.floors]
    .sort((a, b) => compareIds(a.id, b.id))
    .map((floor) => {
      /** @type {Record<string, unknown>} */
      const value = { id: floor.id, building_id: floor.building_id };
      if (floor.name !== undefined) value.name = floor.name;
      return value;
    });

  features.sort((a, b) => compareIds(String(a.id), String(b.id)));

  /** @type {Record<string, unknown>} */
  const dataset = {
    type: 'FeatureCollection',
    nexus: { schema_version: '1.0.0', floors },
    features,
  };

  trace.sort((a, b) => {
    const byFile = compareIds(a.source.file, b.source.file);
    if (byFile !== 0) return byFile;
    const aOrder = a.source.feature_index ?? a.source.row ?? 0;
    const bOrder = b.source.feature_index ?? b.source.row ?? 0;
    if (aOrder !== bOrder) return aOrder - bOrder;
    return compareIds(a.canonical_id ?? '', b.canonical_id ?? '');
  });

  const counts = {
    source_records: [...sources.entries()]
      .filter(([key]) => config.sources[key].kind !== 'excel')
      .reduce((sum, [, records]) => sum + records.length, 0),
    included: trace.filter((item) => item.result === 'included').length,
    excluded: trace.filter((item) => item.result === 'excluded').length,
    failed: trace.filter((item) => item.result === 'failed').length,
  };

  return {
    dataset: findings.ok ? dataset : null,
    findings,
    trace,
    transforms: [...transforms.values()].sort((a, b) => compareIds(a.floor_id, b.floor_id)),
    blockers: config.publish_readiness?.blockers ?? [],
    counts,
  };
}
