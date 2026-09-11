/**
 * GeoJSON 入力アダプター。
 *
 * QGIS / geojson.io / KML 由来の原本をそのまま読み、
 * Feature 直下 `id` と `properties.id` の両方を追跡情報として保持する。
 * どちらを canonical ID として採用するかは対応設定だけが決める。
 */

import { readFileSync } from 'node:fs';

/**
 * @typedef {object} GeoJsonSourceSpec
 * @property {'geojson'} kind
 * @property {string} path --input-root からの相対パス。
 * @property {string} [source_id_property] canonical 候補を保持する properties のキー（既定 `id`）。
 */

/**
 * @typedef {object} GeoJsonSourceRecord
 * @property {number} feature_index
 * @property {string|null} source_feature_id Feature 直下の `id`。
 * @property {string|null} source_property_id `properties[source_id_property]`。
 * @property {boolean} id_conflict 両方が存在して不一致。
 * @property {unknown} geometry
 * @property {Record<string, unknown>} properties
 * @property {import('../findings.mjs').SourceRef} source
 */

/**
 * @param {GeoJsonSourceSpec} spec
 * @param {string} absolutePath
 * @param {import('../findings.mjs').Findings} findings
 * @returns {GeoJsonSourceRecord[]}
 */
export function readGeoJsonSource(spec, absolutePath, findings) {
  const idProperty = spec.source_id_property ?? 'id';
  /** @type {unknown} */
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(absolutePath, 'utf8'));
  } catch (error) {
    findings.error('invalid_json', `${spec.path}: JSON として読み込めない（${String(error)}）。`, {
      source: { file: spec.path },
    });
    return [];
  }

  if (parsed === null || typeof parsed !== 'object') {
    findings.error('invalid_geojson', `${spec.path}: ルートがオブジェクトではない。`, { source: { file: spec.path } });
    return [];
  }
  const root = /** @type {{type?: unknown, features?: unknown, crs?: unknown}} */ (parsed);
  if (root.type !== 'FeatureCollection') {
    findings.error('invalid_geojson', `${spec.path}: ルートの type が FeatureCollection ではない。`, {
      source: { file: spec.path },
    });
    return [];
  }
  if (root.crs !== undefined) {
    // 原本が旧 GeoJSON の crs メンバーを持つ場合、座標系を推定せず明示的に失敗させる。
    findings.error(
      'legacy_crs_member',
      `${spec.path}: 廃止された crs メンバーがある。WGS 84（OGC CRS84）であることを確定してから crs を除去した原本で再実行する。`,
      { source: { file: spec.path } },
    );
    return [];
  }
  if (!Array.isArray(root.features)) {
    findings.error('invalid_geojson', `${spec.path}: features が配列ではない。`, { source: { file: spec.path } });
    return [];
  }

  /** @type {GeoJsonSourceRecord[]} */
  const records = [];
  root.features.forEach((rawFeature, index) => {
    /** @type {import('../findings.mjs').SourceRef} */
    const baseSource = { file: spec.path, feature_index: index };
    if (rawFeature === null || typeof rawFeature !== 'object' || Array.isArray(rawFeature)) {
      findings.error('invalid_geojson', `${spec.path}: features[${index}] がオブジェクトではない。`, {
        source: baseSource,
      });
      return;
    }
    const feature = /** @type {{type?: unknown, id?: unknown, geometry?: unknown, properties?: unknown}} */ (
      rawFeature
    );
    if (feature.type !== 'Feature') {
      findings.error('invalid_geojson', `${spec.path}: features[${index}] の type が Feature ではない。`, {
        source: baseSource,
      });
      return;
    }

    const properties =
      feature.properties !== null && typeof feature.properties === 'object' && !Array.isArray(feature.properties)
        ? /** @type {Record<string, unknown>} */ (feature.properties)
        : {};

    const featureId =
      typeof feature.id === 'string' ? feature.id : typeof feature.id === 'number' ? String(feature.id) : null;
    const rawPropertyId = properties[idProperty];
    const propertyId =
      typeof rawPropertyId === 'string'
        ? rawPropertyId
        : typeof rawPropertyId === 'number'
          ? String(rawPropertyId)
          : null;

    records.push({
      feature_index: index,
      source_feature_id: featureId,
      source_property_id: propertyId,
      id_conflict: featureId !== null && propertyId !== null && featureId !== propertyId,
      geometry: feature.geometry,
      properties,
      source: {
        ...baseSource,
        source_feature_id: featureId,
        source_property_id: propertyId,
      },
    });
  });

  return records;
}
