/**
 * E1-5 のアンカー契約と合格条件の検証。
 *
 * 契約: docs/decisions/E1-5-coordinate-reference-system.md
 * 「アンカー契約」「合格条件と許容誤差」
 *
 * 外れ値の無言除外、平均化による合格化、アフィン変換への変更は行わない。
 * 1点でも上限を超えたらそのフロアの変換を失敗させる。
 */

import {
  applySimilarity,
  enuToWgs84,
  fitSimilarity,
  inspectDegeneracy,
  invertSimilarity,
  wgs84ToEnu,
} from './transform.mjs';
import { roundCoordinate } from './geometry.mjs';

/** 許容値（E1-5「合格条件と許容誤差」。実測結果を見る前に固定された値）。 */
export const TOLERANCES = Object.freeze({
  /** 数値往復誤差の各点上限 [m]。 */
  roundtrip_max_m: 0.05,
  /** fit 残差のRMS上限 [m]。 */
  fit_rms_max_m: 2.0,
  /** fit 残差の各点上限 [m]。 */
  fit_point_max_m: 3.0,
  /** check 誤差の各点上限 [m]。 */
  check_point_max_m: 3.0,
  /** 小数6桁丸めによる追加誤差の上限 [m]。 */
  rounding_max_m: 0.1,
});

/** アンカー1件が最低限保持しなければならない項目（E1-5 の表）。 */
export const REQUIRED_ANCHOR_FIELDS = Object.freeze([
  'anchor_id',
  'building_id',
  'floor_id',
  'role',
  'local_x_m',
  'local_y_m',
  'longitude',
  'latitude',
  'point_description',
  'source_file',
  'source_location',
  'measurement_method',
  'measured_at',
  'measured_by',
  'reported_accuracy_m',
  'approved_at',
  'approved_by',
]);

const NUMERIC_ANCHOR_FIELDS = Object.freeze(['local_x_m', 'local_y_m', 'longitude', 'latitude']);

/**
 * @typedef {Record<string, unknown>} RawAnchor
 */

/**
 * @typedef {object} Anchor
 * @property {string} anchor_id
 * @property {string} building_id
 * @property {string} floor_id
 * @property {'fit'|'check'} role
 * @property {number} local_x_m
 * @property {number} local_y_m
 * @property {number} longitude
 * @property {number} latitude
 * @property {number} reported_accuracy_m
 * @property {import('./findings.mjs').SourceRef} source
 */

/**
 * 数値として確定できる値だけを返す。推定・補完はしない。
 * @param {unknown} value
 * @returns {number|null}
 */
function toFiniteNumber(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed === '') return null;
    const parsed = Number(trimmed);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

/**
 * @param {unknown} value
 * @returns {string|null}
 */
function toNonEmptyString(value) {
  if (typeof value === 'string' && value.trim() !== '') return value.trim();
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return null;
}

/**
 * アンカー1件を契約に照らして検証し、確定値へ正規化する。
 *
 * @param {RawAnchor} raw
 * @param {{findings: import('./findings.mjs').Findings, source: import('./findings.mjs').SourceRef, floor_id: string, building_id: string}} ctx
 * @returns {Anchor|null}
 */
export function normalizeAnchor(raw, ctx) {
  const { findings, source, floor_id, building_id } = ctx;
  const label = toNonEmptyString(raw.anchor_id) ?? '(anchor_id 不明)';
  let ok = true;

  for (const field of REQUIRED_ANCHOR_FIELDS) {
    if (toNonEmptyString(raw[field]) === null) {
      findings.error(
        'missing_required_anchor_field',
        `アンカー ${label}: 必須項目 ${field} が空。E1-5 のアンカー入力契約を満たしていない。`,
        { source },
      );
      ok = false;
    }
  }

  /** @type {Record<string, number>} */
  const numbers = {};
  for (const field of NUMERIC_ANCHOR_FIELDS) {
    const value = toFiniteNumber(raw[field]);
    if (value === null) {
      if (toNonEmptyString(raw[field]) !== null) {
        findings.error(
          'invalid_anchor_value',
          `アンカー ${label}: ${field} が数値として確定できない（${String(raw[field])}）。推定しない。`,
          { source },
        );
      }
      ok = false;
    } else {
      numbers[field] = value;
    }
  }

  // 経緯度の範囲検証。数値であることだけでは、軸の取り違えや360度ずれを検出できない。
  if (numbers.longitude !== undefined && (numbers.longitude < -180 || numbers.longitude > 180)) {
    findings.error(
      'anchor_longitude_out_of_range',
      `アンカー ${label}: longitude ${numbers.longitude} が [-180, 180] の範囲外。360度ずれや軸の取り違えを推定補正しない。`,
      { source },
    );
    ok = false;
  }
  if (numbers.latitude !== undefined && (numbers.latitude < -90 || numbers.latitude > 90)) {
    findings.error(
      'anchor_latitude_out_of_range',
      `アンカー ${label}: latitude ${numbers.latitude} が [-90, 90] の範囲外。経度・緯度が入れ替わっている可能性がある。`,
      { source },
    );
    ok = false;
  }

  const role = toNonEmptyString(raw.role);
  if (role !== null && role !== 'fit' && role !== 'check') {
    findings.error('invalid_anchor_role', `アンカー ${label}: role は fit / check のみ（受領: ${role}）。`, { source });
    ok = false;
  }

  const accuracyRaw = toNonEmptyString(raw.reported_accuracy_m);
  let accuracy = Number.NaN;
  if (accuracyRaw === 'unknown') {
    findings.error(
      'unknown_reported_accuracy',
      `アンカー ${label}: reported_accuracy_m が unknown。精度不明の記録を自動的に既定値とみなさない（E1-5 却下事項）。`,
      { source },
    );
    ok = false;
  } else if (accuracyRaw !== null) {
    const parsed = toFiniteNumber(accuracyRaw);
    if (parsed === null || parsed <= 0) {
      findings.error(
        'invalid_anchor_value',
        `アンカー ${label}: reported_accuracy_m が正の数でも unknown でもない（${accuracyRaw}）。`,
        { source },
      );
      ok = false;
    } else {
      accuracy = parsed;
    }
  }

  const anchorFloor = toNonEmptyString(raw.floor_id);
  if (anchorFloor !== null && anchorFloor !== floor_id) {
    findings.error(
      'anchor_floor_mismatch',
      `アンカー ${label}: floor_id ${anchorFloor} が対象フロア ${floor_id} と一致しない。`,
      { source },
    );
    ok = false;
  }
  const anchorBuilding = toNonEmptyString(raw.building_id);
  if (anchorBuilding !== null && anchorBuilding !== building_id) {
    findings.error(
      'anchor_building_mismatch',
      `アンカー ${label}: building_id ${anchorBuilding} が対象建物 ${building_id} と一致しない。`,
      { source },
    );
    ok = false;
  }

  if (!ok) return null;
  return {
    anchor_id: /** @type {string} */ (toNonEmptyString(raw.anchor_id)),
    building_id,
    floor_id,
    role: /** @type {'fit'|'check'} */ (role),
    local_x_m: numbers.local_x_m,
    local_y_m: numbers.local_y_m,
    longitude: numbers.longitude,
    latitude: numbers.latitude,
    reported_accuracy_m: accuracy,
    source,
  };
}

/**
 * @typedef {object} AnchorMetric
 * @property {string} anchor_id
 * @property {'fit'|'check'} role
 * @property {number} residual_m 変換後位置と実測位置のENU上の水平距離。
 * @property {number} roundtrip_m 数値往復誤差。
 * @property {number} rounding_m 小数6桁丸めによる追加誤差。
 */

/**
 * @typedef {object} FloorTransformResult
 * @property {string} floor_id
 * @property {string} building_id
 * @property {import('./transform.mjs').GeodeticOrigin} origin
 * @property {'ok'|'failed'} status
 * @property {{fit: number, check: number, total: number}} anchor_counts
 * @property {import('./transform.mjs').SimilarityParams|null} params
 * @property {{fit_rms_m: number, fit_max_m: number, check_max_m: number, roundtrip_max_m: number, rounding_max_m: number}|null} metrics
 * @property {AnchorMetric[]} per_anchor
 */

/**
 * 1フロア分の変換パラメータを決定的に推定し、E1-5 の合格条件で検証する。
 *
 * @param {{floor_id: string, building_id: string, origin: import('./transform.mjs').GeodeticOrigin}} spec
 * @param {Anchor[]} anchors
 * @param {import('./findings.mjs').Findings} findings
 * @returns {FloorTransformResult}
 */
export function evaluateFloorTransform(spec, anchors, findings) {
  const { floor_id, building_id, origin } = spec;
  /** @type {FloorTransformResult} */
  const failed = {
    floor_id,
    building_id,
    origin,
    status: 'failed',
    anchor_counts: { fit: 0, check: 0, total: anchors.length },
    params: null,
    metrics: null,
    per_anchor: [],
  };

  // 入力順に依存しない決定的な計算のため anchor_id のコードポイント順へ固定する。
  const sorted = [...anchors].sort((a, b) => (a.anchor_id < b.anchor_id ? -1 : a.anchor_id > b.anchor_id ? 1 : 0));

  /** @type {Set<string>} */
  const seenIds = new Set();
  for (const anchor of sorted) {
    if (seenIds.has(anchor.anchor_id)) {
      findings.error('duplicate_anchor_id', `フロア ${floor_id}: anchor_id ${anchor.anchor_id} が重複している。`, {
        source: anchor.source,
      });
      return failed;
    }
    seenIds.add(anchor.anchor_id);
  }

  const fitAnchors = sorted.filter((a) => a.role === 'fit');
  const checkAnchors = sorted.filter((a) => a.role === 'check');
  failed.anchor_counts = { fit: fitAnchors.length, check: checkAnchors.length, total: sorted.length };

  // fit と check を同じ点で兼用しない（E1-5）。
  for (const fit of fitAnchors) {
    for (const check of checkAnchors) {
      const sameLocal = fit.local_x_m === check.local_x_m && fit.local_y_m === check.local_y_m;
      const sameWgs84 = fit.longitude === check.longitude && fit.latitude === check.latitude;
      if (sameLocal || sameWgs84) {
        findings.error(
          'fit_check_shared_point',
          `フロア ${floor_id}: fit ${fit.anchor_id} と check ${check.anchor_id} が同一点。兼用は許可されない。`,
          { source: check.source },
        );
        return failed;
      }
    }
  }

  let countsOk = true;
  if (fitAnchors.length < 3) {
    findings.error(
      'insufficient_fit_anchors',
      `フロア ${floor_id}: fit アンカーが ${fitAnchors.length} 点。3点以上が必要（E1-5）。仮値は作らない。`,
    );
    countsOk = false;
  }
  if (checkAnchors.length < 1) {
    findings.error(
      'insufficient_check_anchors',
      `フロア ${floor_id}: 独立した check アンカーが 0 点。1点以上が必要（E1-5）。`,
    );
    countsOk = false;
  }
  if (sorted.length < 4) {
    findings.error(
      'insufficient_anchors',
      `フロア ${floor_id}: アンカー合計が ${sorted.length} 点。同一フロアで4点以上が必要（E1-5）。`,
    );
    countsOk = false;
  }
  if (!countsOk) return failed;

  const fitPoints = fitAnchors.map((a) => {
    const enu = wgs84ToEnu(a.longitude, a.latitude, origin);
    return { x_m: a.local_x_m, y_m: a.local_y_m, east_m: enu.east_m, north_m: enu.north_m };
  });

  const degeneracy = inspectDegeneracy(fitPoints);
  if (degeneracy.degenerate) {
    findings.error('degenerate_anchor_layout', `フロア ${floor_id}: ${degeneracy.reason}`);
    return failed;
  }

  /** @type {import('./transform.mjs').SimilarityParams} */
  let params;
  try {
    params = fitSimilarity(fitPoints);
  } catch (error) {
    findings.error('similarity_fit_failed', `フロア ${floor_id}: ${(error instanceof Error ? error : new Error(String(error))).message}`);
    return failed;
  }

  /** @type {AnchorMetric[]} */
  const perAnchor = [];
  for (const anchor of sorted) {
    const measured = wgs84ToEnu(anchor.longitude, anchor.latitude, origin);
    const predicted = applySimilarity(anchor.local_x_m, anchor.local_y_m, params);
    const residual = Math.hypot(predicted.east_m - measured.east_m, predicted.north_m - measured.north_m);

    // 数値往復誤差: local -> ENU -> WGS84 -> ENU -> local を同じ確定パラメータで往復する。
    const unrounded = enuToWgs84(predicted.east_m, predicted.north_m, origin);
    const backEnu = wgs84ToEnu(unrounded.longitude, unrounded.latitude, origin);
    const backLocal = invertSimilarity(backEnu.east_m, backEnu.north_m, params);
    const roundtrip = Math.hypot(backLocal.x_m - anchor.local_x_m, backLocal.y_m - anchor.local_y_m);

    // 丸め誤差: 小数6桁へ丸めた後に同じ局所ENUで比較する。
    const rounded = wgs84ToEnu(
      roundCoordinate(unrounded.longitude),
      roundCoordinate(unrounded.latitude),
      origin,
    );
    const rounding = Math.hypot(rounded.east_m - backEnu.east_m, rounded.north_m - backEnu.north_m);

    perAnchor.push({
      anchor_id: anchor.anchor_id,
      role: anchor.role,
      residual_m: residual,
      roundtrip_m: roundtrip,
      rounding_m: rounding,
    });
  }

  const evaluation = checkTolerances(floor_id, perAnchor, findings);

  return {
    floor_id,
    building_id,
    origin,
    status: evaluation.pass ? 'ok' : 'failed',
    anchor_counts: { fit: fitAnchors.length, check: checkAnchors.length, total: sorted.length },
    params,
    metrics: evaluation.metrics,
    per_anchor: perAnchor,
  };
}

/**
 * 許容誤差の判定（E1-5「合格条件と許容誤差」）。
 *
 * 判定は丸め前の倍精度値で行い、1点でも上限を超えたら合格にしない。
 * 外れ値の無言除外や平均化による救済は行わない。
 *
 * @param {string} floor_id
 * @param {AnchorMetric[]} perAnchor
 * @param {import('./findings.mjs').Findings} findings
 * @returns {{pass: boolean, metrics: {fit_rms_m: number, fit_max_m: number, check_max_m: number, roundtrip_max_m: number, rounding_max_m: number}}}
 */
export function checkTolerances(floor_id, perAnchor, findings) {
  const fitMetrics = perAnchor.filter((metric) => metric.role === 'fit');
  const checkMetrics = perAnchor.filter((metric) => metric.role === 'check');
  const fitRms =
    fitMetrics.length === 0
      ? Number.NaN
      : Math.sqrt(fitMetrics.reduce((sum, metric) => sum + metric.residual_m ** 2, 0) / fitMetrics.length);
  const fitMax = fitMetrics.length === 0 ? Number.NaN : Math.max(...fitMetrics.map((metric) => metric.residual_m));
  const checkMax =
    checkMetrics.length === 0 ? Number.NaN : Math.max(...checkMetrics.map((metric) => metric.residual_m));
  const roundtripMax = Math.max(...perAnchor.map((metric) => metric.roundtrip_m));
  const roundingMax = Math.max(...perAnchor.map((metric) => metric.rounding_m));

  let pass = true;
  if (fitRms > TOLERANCES.fit_rms_max_m) {
    findings.error(
      'fit_rms_exceeded',
      `フロア ${floor_id}: fit 残差RMS ${fitRms.toFixed(3)} m が上限 ${TOLERANCES.fit_rms_max_m} m を超過。`,
    );
    pass = false;
  }
  for (const metric of fitMetrics) {
    if (metric.residual_m > TOLERANCES.fit_point_max_m) {
      findings.error(
        'fit_residual_exceeded',
        `フロア ${floor_id}: fit ${metric.anchor_id} の残差 ${metric.residual_m.toFixed(3)} m が上限 ${TOLERANCES.fit_point_max_m} m を超過。外れ値の無言除外や平均化による合格化は行わない。`,
      );
      pass = false;
    }
  }
  for (const metric of checkMetrics) {
    if (metric.residual_m > TOLERANCES.check_point_max_m) {
      findings.error(
        'check_error_exceeded',
        `フロア ${floor_id}: check ${metric.anchor_id} の誤差 ${metric.residual_m.toFixed(3)} m が上限 ${TOLERANCES.check_point_max_m} m を超過。`,
      );
      pass = false;
    }
  }
  for (const metric of perAnchor) {
    if (metric.roundtrip_m > TOLERANCES.roundtrip_max_m) {
      findings.error(
        'roundtrip_error_exceeded',
        `フロア ${floor_id}: ${metric.anchor_id} の数値往復誤差 ${metric.roundtrip_m.toFixed(4)} m が上限 ${TOLERANCES.roundtrip_max_m} m を超過。`,
      );
      pass = false;
    }
    if (metric.rounding_m > TOLERANCES.rounding_max_m) {
      findings.error(
        'rounding_error_exceeded',
        `フロア ${floor_id}: ${metric.anchor_id} の小数6桁丸め追加誤差 ${metric.rounding_m.toFixed(4)} m が上限 ${TOLERANCES.rounding_max_m} m を超過。`,
      );
      pass = false;
    }
  }

  return {
    pass,
    metrics: {
      fit_rms_m: fitRms,
      fit_max_m: fitMax,
      check_max_m: checkMax,
      roundtrip_max_m: roundtripMax,
      rounding_max_m: roundingMax,
    },
  };
}
