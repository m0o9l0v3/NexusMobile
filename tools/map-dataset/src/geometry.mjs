/**
 * geometry の正規化と検査。
 *
 * 契約:
 * - docs/decisions/E1-4-geojson-schema.md 「座標と GeoJSON 準拠」
 * - docs/decisions/E1-5-coordinate-reference-system.md 「採用方針」
 *
 * position は WGS 84（OGC CRS84）の2次元 `[longitude, latitude]` 固定。
 * 高度の第3要素は受け付けず、丸めは小数6桁。
 */

import { Findings } from './findings.mjs';

/** 出力座標の小数桁数（E1-5）。 */
export const COORDINATE_DECIMALS = 6;

/**
 * 小数6桁へ丸める。`-0` は `0` に正規化して出力を安定させる。
 * @param {number} value
 * @returns {number}
 */
export function roundCoordinate(value) {
  const rounded = Number(value.toFixed(COORDINATE_DECIMALS));
  return Object.is(rounded, -0) ? 0 : rounded;
}

/**
 * すでに小数6桁へ丸め済みかどうか。
 * @param {number} value
 */
export function isRounded(value) {
  return Object.is(roundCoordinate(value), Object.is(value, -0) ? 0 : value);
}

/**
 * 1つの position を2次元・範囲内・丸め済みへ正規化する。
 *
 * @param {unknown} position
 * @param {{findings: Findings, source?: import('./findings.mjs').SourceRef, canonical_id?: string, path: string}} ctx
 * @returns {[number, number] | null} 異常時は null（理由は findings へ積む）。
 */
export function normalizePosition(position, ctx) {
  const { findings, source, canonical_id, path } = ctx;
  const at = { source, canonical_id };
  if (!Array.isArray(position)) {
    findings.error('invalid_position', `${path}: position が配列ではない。`, at);
    return null;
  }
  if (position.length === 3) {
    findings.error(
      'three_dimensional_position',
      `${path}: 3要素の position（高度付き）は v1.0 では許可されない。E1-4 により2要素へ確定してから再実行する。`,
      at,
    );
    return null;
  }
  if (position.length !== 2) {
    findings.error('invalid_position', `${path}: position の要素数が ${position.length}。2要素固定。`, at);
    return null;
  }
  const [lon, lat] = position;
  if (typeof lon !== 'number' || typeof lat !== 'number' || !Number.isFinite(lon) || !Number.isFinite(lat)) {
    findings.error('invalid_position', `${path}: position に有限数でない値がある。`, at);
    return null;
  }
  if (lon < -180 || lon > 180) {
    findings.error(
      'longitude_out_of_range',
      `${path}: longitude ${lon} が [-180, 180] の範囲外。position は [longitude, latitude] の順。`,
      at,
    );
    return null;
  }
  if (lat < -90 || lat > 90) {
    findings.error(
      'latitude_out_of_range',
      `${path}: latitude ${lat} が [-90, 90] の範囲外。経度・緯度が入れ替わっている可能性がある。`,
      at,
    );
    return null;
  }
  return [roundCoordinate(lon), roundCoordinate(lat)];
}

/**
 * 環の符号付き面積（shoelace）。正なら反時計回り。
 * @param {[number, number][]} ring
 */
export function signedArea(ring) {
  let sum = 0;
  for (let i = 0; i < ring.length - 1; i += 1) {
    sum += ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1];
  }
  return sum / 2;
}

/**
 * @typedef {object} RingNormalization
 * @property {[number, number][]|null} ring
 * @property {boolean} closed 環を閉じるために末尾を追加した。
 * @property {boolean} reversed 向きを反転した。
 */

/**
 * 1つの linear ring を「閉じる」「外環は反時計回り・内環は時計回り」へ正規化する。
 *
 * @param {unknown} rawRing
 * @param {{findings: Findings, source?: import('./findings.mjs').SourceRef, canonical_id?: string, path: string, isOuter: boolean}} ctx
 * @returns {RingNormalization}
 */
export function normalizeRing(rawRing, ctx) {
  const { findings, source, canonical_id, path, isOuter } = ctx;
  const at = { source, canonical_id };
  if (!Array.isArray(rawRing)) {
    findings.error('invalid_ring', `${path}: linear ring が配列ではない。`, at);
    return { ring: null, closed: false, reversed: false };
  }
  /** @type {[number, number][]} */
  const positions = [];
  for (let i = 0; i < rawRing.length; i += 1) {
    const pos = normalizePosition(rawRing[i], { findings, source, canonical_id, path: `${path}[${i}]` });
    if (pos === null) return { ring: null, closed: false, reversed: false };
    positions.push(pos);
  }

  let closed = false;
  const first = positions[0];
  const last = positions[positions.length - 1];
  if (!first || !last) {
    findings.error('invalid_ring', `${path}: linear ring が空。`, at);
    return { ring: null, closed: false, reversed: false };
  }
  if (first[0] !== last[0] || first[1] !== last[1]) {
    positions.push([first[0], first[1]]);
    closed = true;
  }

  if (positions.length < 4) {
    findings.error(
      'invalid_ring',
      `${path}: 閉じた linear ring には4以上の position が必要（現在 ${positions.length}）。`,
      at,
    );
    return { ring: null, closed, reversed: false };
  }

  const area = signedArea(positions);
  if (area === 0) {
    findings.error('degenerate_ring', `${path}: 面積0の linear ring。原本を確認する。`, at);
    return { ring: null, closed, reversed: false };
  }

  let reversed = false;
  const wantCounterClockwise = isOuter;
  const isCounterClockwise = area > 0;
  if (isCounterClockwise !== wantCounterClockwise) {
    positions.reverse();
    reversed = true;
  }
  return { ring: positions, closed, reversed };
}

/**
 * @typedef {object} GeometryNormalization
 * @property {{type: string, coordinates: unknown}|null} geometry
 * @property {string[]} notes 正規化で行った変更の記録。
 */

/**
 * geometry を Feature 種別の要求型に合わせて正規化する。
 *
 * @param {unknown} rawGeometry
 * @param {'Point'|'LineString'|'Polygon'} expectedType
 * @param {{findings: Findings, source?: import('./findings.mjs').SourceRef, canonical_id?: string}} ctx
 * @returns {GeometryNormalization}
 */
export function normalizeGeometry(rawGeometry, expectedType, ctx) {
  const { findings, source, canonical_id } = ctx;
  const at = { source, canonical_id };
  /** @type {string[]} */
  const notes = [];
  if (rawGeometry === null || typeof rawGeometry !== 'object' || Array.isArray(rawGeometry)) {
    findings.error('invalid_geometry', 'geometry がオブジェクトではない。', at);
    return { geometry: null, notes };
  }
  const geometry = /** @type {{type?: unknown, coordinates?: unknown}} */ (rawGeometry);
  if (geometry.type !== expectedType) {
    findings.error(
      'geometry_type_mismatch',
      `geometry.type が ${String(geometry.type)}。この feature_type には ${expectedType} が必要（E1-4）。`,
      at,
    );
    return { geometry: null, notes };
  }

  if (expectedType === 'Point') {
    const pos = normalizePosition(geometry.coordinates, { findings, source, canonical_id, path: 'coordinates' });
    if (pos === null) return { geometry: null, notes };
    return { geometry: { type: 'Point', coordinates: pos }, notes };
  }

  if (expectedType === 'LineString') {
    if (!Array.isArray(geometry.coordinates) || geometry.coordinates.length < 2) {
      findings.error('invalid_geometry', 'LineString には2以上の position が必要。', at);
      return { geometry: null, notes };
    }
    /** @type {[number, number][]} */
    const line = [];
    for (let i = 0; i < geometry.coordinates.length; i += 1) {
      const pos = normalizePosition(geometry.coordinates[i], {
        findings,
        source,
        canonical_id,
        path: `coordinates[${i}]`,
      });
      if (pos === null) return { geometry: null, notes };
      line.push(pos);
    }
    return { geometry: { type: 'LineString', coordinates: line }, notes };
  }

  if (!Array.isArray(geometry.coordinates) || geometry.coordinates.length < 1) {
    findings.error('invalid_geometry', 'Polygon には1以上の linear ring が必要。', at);
    return { geometry: null, notes };
  }
  /** @type {[number, number][][]} */
  const rings = [];
  for (let i = 0; i < geometry.coordinates.length; i += 1) {
    const result = normalizeRing(geometry.coordinates[i], {
      findings,
      source,
      canonical_id,
      path: `coordinates[${i}]`,
      isOuter: i === 0,
    });
    if (result.ring === null) return { geometry: null, notes };
    if (result.closed) notes.push(`ring[${i}] の末尾を先頭と一致させて閉じた。`);
    if (result.reversed) notes.push(`ring[${i}] の向きを ${i === 0 ? '反時計回り' : '時計回り'} へ反転した。`);
    rings.push(result.ring);
  }
  return { geometry: { type: 'Polygon', coordinates: rings }, notes };
}

/**
 * geometry 内の全 position を走査する。
 * @param {{type: string, coordinates: unknown}} geometry
 * @returns {[number, number][]}
 */
export function collectPositions(geometry) {
  /** @type {[number, number][]} */
  const out = [];
  /** @param {unknown} node */
  const walk = (node) => {
    if (!Array.isArray(node)) return;
    if (typeof node[0] === 'number') {
      out.push(/** @type {[number, number]} */ (node));
      return;
    }
    for (const child of node) walk(child);
  };
  walk(geometry.coordinates);
  return out;
}
