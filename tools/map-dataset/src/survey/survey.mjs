/**
 * 現地測量（既知の点からの測距）の記録から、建物の Polygon を作る。
 *
 *   測量設定（JSON: 基準点・機材・建物の角の順序）
 *   + 野帳 CSV（距離の観測）
 *     -> WGS 84 を局所ENUへ（E1-5 と同じ変換）
 *     -> 距離の最小二乗で角の位置を求める（基準点は固定）
 *     -> 残差・精度を確かめる（超えたら再測定の対象）
 *     -> WGS 84 の小数6桁へ戻し、GeoJSON（map-dataset の geojson 原本と同じ形）を出す
 *
 * 手順と許容値の根拠: docs/map-data/campus-survey-plan.md
 * Apple・Google の地図の座標は、基準点にも初期値にも使わない（E1-4 改訂4）。
 */

import { parseCsv } from '../sources/csv-point-source.mjs';
import { enuToWgs84, wgs84ToEnu } from '../transform.mjs';
import { roundCoordinate } from '../geometry.mjs';
import { adjust, AdjustmentError } from './adjust.mjs';

export const SURVEY_VERSION = '1.0.0';

/** 既定の許容値。根拠は docs/map-data/campus-survey-plan.md §4.3。 */
export const DEFAULT_TOLERANCES = Object.freeze({
  /** 1つの観測の残差の上限 [m]。超えたら、その観測を測り直す。 */
  max_abs_residual_m: 0.3,
  /** 角の位置の標準偏差（水平, 1σ）の上限 [m]。0.4 m は 95% でおおむね 1 m。 */
  max_point_sigma_m: 0.4,
  /** 基準点どうしの、測った距離と国土地理院の座標から出した距離の差の上限 [m]。 */
  reference_check_m: 1.0,
  /** 1つの角を測る、その建物以外の点（基準点・仮の点・ほかの建物の角）の最小数。 */
  min_references_per_corner: 2,
  /** 1つの角に関わる観測（基準点からの距離・辺・対角線）の最小数。 */
  min_observations_per_corner: 3,
});

/** 野帳 CSV の列。field-sheet.csv と同じ並び。 */
export const OBSERVATION_COLUMNS = Object.freeze([
  'record_id',
  'building_id',
  'point_id',
  'from_point',
  'distance_m',
  'bearing_deg',
  'instrument_id',
  'measurer',
  'observed_at',
  'photo_ref',
  'notes',
  'void',
]);

/** 出典の記録（map-data/normalized/building-provenance.csv）の列。 */
export const PROVENANCE_COLUMNS = Object.freeze([
  'building_id',
  'display_name',
  'category',
  'geometry_source',
  'source_detail',
  'acquired_on',
  'method',
  'terms',
  'accuracy_m',
  'accuracy_basis',
  'apple_google_used',
  'checked_on',
  'record_ref',
  'notes',
]);

/**
 * @typedef {object} SurveyProject
 * @property {string} survey_version
 * @property {string} survey_id
 * @property {{longitude: number, latitude: number}} [origin]
 * @property {number} [magnetic_declination_deg] 偏角（東偏が正、西偏が負）。方位は初期値にだけ使う
 * @property {Record<string, {kind: string, sigma_m: number, sigma_per_m: number}>} instruments
 * @property {{id: string, longitude: number, latitude: number, building_id: string, source: string, source_detail?: string}[]} references
 * @property {{id: string, name?: string, corners: string[], survey_dates?: string[]}[]} buildings
 * @property {string[]} [auxiliary_points] 建物の角ではない仮の点（杭・チョークの印）。基準点から遠い建物をつなぐ
 * @property {Partial<typeof DEFAULT_TOLERANCES>} [tolerances]
 */

/**
 * @typedef {object} Flag
 * @property {'error'|'remeasure'} severity error: 計算できない / remeasure: 計算できたが測り直す
 * @property {string} code
 * @property {string} message
 * @property {string} [building_id]
 * @property {string[]} [record_ids]
 */

const ID_PATTERN = /^[A-Za-z0-9_.-]+$/;

/**
 * @param {unknown} raw
 * @returns {{project: SurveyProject, flags: Flag[]}}
 */
export function parseProject(raw) {
  /** @type {Flag[]} */
  const flags = [];
  /** @param {string} code @param {string} message */
  const err = (code, message) => flags.push({ severity: 'error', code, message });
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    err('invalid_project', '測量設定がオブジェクトではない。');
    return { project: /** @type {SurveyProject} */ ({}), flags };
  }
  const p = /** @type {SurveyProject} */ (raw);
  if (p.survey_version !== SURVEY_VERSION) err('unsupported_version', `survey_version は ${SURVEY_VERSION} にする。`);
  if (typeof p.survey_id !== 'string' || p.survey_id === '') err('missing_survey_id', 'survey_id が無い。');
  if (!p.instruments || typeof p.instruments !== 'object') err('missing_instruments', 'instruments が無い。');
  else {
    for (const [id, inst] of Object.entries(p.instruments)) {
      if (!(inst.sigma_m > 0) || !(inst.sigma_per_m >= 0)) {
        err('invalid_instrument', `機材 ${id}: sigma_m（>0）と sigma_per_m（>=0）を数で書く。`);
      }
    }
  }
  if (!Array.isArray(p.references) || p.references.length < 2) err('too_few_references', '基準点を2点以上書く。');
  else {
    const seen = new Set();
    for (const r of p.references) {
      if (typeof r.id !== 'string' || !ID_PATTERN.test(r.id)) err('invalid_reference_id', `基準点 ID が不正: ${String(r.id)}`);
      if (seen.has(r.id)) err('duplicate_reference_id', `基準点 ID が重複: ${r.id}`);
      seen.add(r.id);
      if (!Number.isFinite(r.longitude) || !Number.isFinite(r.latitude) || Math.abs(r.latitude) > 90 || Math.abs(r.longitude) > 180) {
        err('invalid_reference_coordinate', `基準点 ${r.id}: longitude / latitude を10進度の数で書く。`);
      }
      if (typeof r.source !== 'string' || r.source === '') {
        err('missing_reference_source', `基準点 ${r.id}: source（どの資料の座標か）が無い。`);
      } else if (/apple|google/i.test(`${r.source} ${r.source_detail ?? ''}`)) {
        err('forbidden_reference_source', `基準点 ${r.id}: Apple・Google の地図を基準点の資料にしない（E1-4 改訂4 §3.1）。`);
      }
    }
  }
  if (!Array.isArray(p.buildings) || p.buildings.length === 0) err('missing_buildings', 'buildings が無い。');
  else {
    for (const b of p.buildings) {
      if (typeof b.id !== 'string' || !ID_PATTERN.test(b.id)) err('invalid_building_id', `建物 ID が不正: ${String(b.id)}`);
      if (!Array.isArray(b.corners) || b.corners.length < 3) err('too_few_corners', `建物 ${b.id}: corners を3つ以上、外周を回る順に書く。`);
      else if (new Set(b.corners).size !== b.corners.length) err('duplicate_corner', `建物 ${b.id}: corners に同じ点が2回ある。`);
    }
  }
  if (p.auxiliary_points !== undefined) {
    if (!Array.isArray(p.auxiliary_points) || p.auxiliary_points.some((id) => typeof id !== 'string' || !ID_PATTERN.test(id))) {
      err('invalid_auxiliary_points', 'auxiliary_points は点 ID の配列にする。');
    }
  }
  return { project: p, flags };
}

/**
 * @typedef {object} ObservationRow
 * @property {string} record_id
 * @property {string} building_id
 * @property {string} point_id
 * @property {string} from_point
 * @property {number} distance_m
 * @property {number|null} bearing_deg 磁北基準
 * @property {string} instrument_id
 * @property {string} measurer
 * @property {string} observed_at
 * @property {string} photo_ref
 * @property {string} notes
 * @property {boolean} void
 * @property {number} line CSV の行番号（1始まり、見出しが1行目）
 */

/**
 * @param {string} text
 * @returns {{rows: ObservationRow[], flags: Flag[]}}
 */
export function parseObservations(text) {
  /** @type {Flag[]} */
  const flags = [];
  const table = parseCsv(text);
  if (table.length === 0) {
    flags.push({ severity: 'error', code: 'empty_observations', message: '野帳 CSV が空。' });
    return { rows: [], flags };
  }
  const header = table[0].map((h) => h.trim());
  const missing = OBSERVATION_COLUMNS.filter((c) => !header.includes(c));
  if (missing.length > 0) {
    flags.push({ severity: 'error', code: 'missing_columns', message: `野帳 CSV に列が無い: ${missing.join(', ')}` });
    return { rows: [], flags };
  }
  const col = Object.fromEntries(header.map((h, i) => [h, i]));
  /** @type {ObservationRow[]} */
  const rows = [];
  const seen = new Set();
  table.slice(1).forEach((cells, i) => {
    const line = i + 2;
    /** @param {string} name */
    const get = (name) => (cells[col[name]] ?? '').trim();
    if (cells.every((c) => c.trim() === '')) return;
    const recordId = get('record_id');
    const distance = Number(get('distance_m'));
    const bearingText = get('bearing_deg');
    const bearing = bearingText === '' ? null : Number(bearingText);
    /** @param {string} code @param {string} message */
    const err = (code, message) =>
      flags.push({ severity: 'error', code, message: `野帳 ${line} 行目（${recordId || '記録番号なし'}）: ${message}`, record_ids: recordId ? [recordId] : [] });
    if (recordId === '') return err('missing_record_id', 'record_id が無い。');
    if (seen.has(recordId)) return err('duplicate_record_id', 'record_id が重複している。');
    seen.add(recordId);
    const isVoid = get('void') !== '';
    if (isVoid) {
      rows.push(rowOf());
      return;
    }
    if (!ID_PATTERN.test(get('point_id')) || !ID_PATTERN.test(get('from_point'))) return err('invalid_point_id', 'point_id / from_point が空か、使えない文字を含む。');
    if (get('point_id') === get('from_point')) return err('same_point', 'point_id と from_point が同じ。');
    if (!(distance > 0) || get('distance_m') === '') return err('invalid_distance', 'distance_m を正の数（メートル、水平距離）で書く。');
    if (bearing !== null && !(Number.isFinite(bearing) && bearing >= 0 && bearing < 360)) return err('invalid_bearing', 'bearing_deg は 0 以上 360 未満の度で書く（空欄可）。');
    if (get('instrument_id') === '') return err('missing_instrument', 'instrument_id が無い。');
    if (get('measurer') === '') return err('missing_measurer', 'measurer（役割か頭文字）が無い。');
    if (get('observed_at') === '') return err('missing_observed_at', 'observed_at（日時）が無い。');
    rows.push(rowOf());

    /** @returns {ObservationRow} */
    function rowOf() {
      return {
        record_id: recordId,
        building_id: get('building_id'),
        point_id: get('point_id'),
        from_point: get('from_point'),
        distance_m: distance,
        bearing_deg: bearing,
        instrument_id: get('instrument_id'),
        measurer: get('measurer'),
        observed_at: get('observed_at'),
        photo_ref: get('photo_ref'),
        notes: get('notes'),
        void: isVoid,
        line,
      };
    }
  });
  return { rows, flags };
}

/**
 * @param {SurveyProject} project
 * @param {ObservationRow[]} rows
 */
export function runSurvey(project, rows) {
  const tolerances = { ...DEFAULT_TOLERANCES, ...(project.tolerances ?? {}) };
  /** @type {Flag[]} */
  const flags = [];
  const refById = new Map(project.references.map((r) => [r.id, r]));
  const origin = project.origin ?? {
    longitude: mean(project.references.map((r) => r.longitude)),
    latitude: mean(project.references.map((r) => r.latitude)),
  };
  /** @type {Map<string, {east_m: number, north_m: number}>} */
  const fixed = new Map(
    project.references.map((r) => {
      const enu = wgs84ToEnu(r.longitude, r.latitude, origin);
      return [r.id, { east_m: enu.east_m, north_m: enu.north_m }];
    }),
  );
  const declination = project.magnetic_declination_deg ?? 0;
  const cornerOwner = new Map(project.buildings.flatMap((b) => b.corners.map((c) => [c, b.id])));
  const auxiliary = new Set(project.auxiliary_points ?? []);
  /** @param {string} id */
  const isUnknownPoint = (id) => cornerOwner.has(id) || auxiliary.has(id);
  for (const c of [...cornerOwner.keys(), ...auxiliary]) {
    if (refById.has(c)) flags.push({ severity: 'error', code: 'corner_is_reference', message: `点 ${c} が基準点と建物の角の両方にある。` });
  }

  const active = rows.filter((r) => !r.void);
  /** @type {import('./adjust.mjs').DistanceObservation[]} */
  const observations = [];
  /** @type {{record_id: string, from: string, to: string, measured_m: number, from_reference_m: number, difference_m: number, ok: boolean}[]} */
  const referenceChecks = [];
  for (const row of active) {
    const inst = project.instruments[row.instrument_id];
    if (!inst) {
      flags.push({ severity: 'error', code: 'unknown_instrument', message: `記録 ${row.record_id}: 機材 ${row.instrument_id} が測量設定に無い。`, record_ids: [row.record_id] });
      continue;
    }
    for (const id of [row.point_id, row.from_point]) {
      if (!refById.has(id) && !isUnknownPoint(id)) {
        flags.push({ severity: 'error', code: 'unknown_point', message: `記録 ${row.record_id}: 点 ${id} が基準点・建物の角・仮の点のどれにも無い。`, record_ids: [row.record_id] });
      }
    }
    if (!refById.has(row.point_id) && !isUnknownPoint(row.point_id)) continue;
    if (!refById.has(row.from_point) && !isUnknownPoint(row.from_point)) continue;
    if (refById.has(row.point_id) && refById.has(row.from_point)) {
      const a = /** @type {{east_m: number, north_m: number}} */ (fixed.get(row.from_point));
      const b = /** @type {{east_m: number, north_m: number}} */ (fixed.get(row.point_id));
      const computed = Math.hypot(b.east_m - a.east_m, b.north_m - a.north_m);
      const diff = row.distance_m - computed;
      const ok = Math.abs(diff) <= tolerances.reference_check_m;
      referenceChecks.push({ record_id: row.record_id, from: row.from_point, to: row.point_id, measured_m: row.distance_m, from_reference_m: computed, difference_m: diff, ok });
      if (!ok) {
        flags.push({
          severity: 'remeasure',
          code: 'reference_mismatch',
          message: `基準点 ${row.from_point}–${row.point_id}: 測った距離と国土地理院の座標からの距離が ${diff.toFixed(2)} m 違う（許容 ±${tolerances.reference_check_m} m）。測り直し、それでも違えば、この基準点を使わない。`,
          record_ids: [row.record_id],
        });
      }
      continue;
    }
    observations.push({
      record_id: row.record_id,
      from: row.from_point,
      to: row.point_id,
      distance_m: row.distance_m,
      sigma_m: inst.sigma_m + inst.sigma_per_m * row.distance_m,
      bearing_true_deg: row.bearing_deg === null ? null : (((row.bearing_deg + declination) % 360) + 360) % 360,
    });
  }

  // 冗長性: 各角について、別の建物の点（基準点・仮の点・ほかの建物の角）の数と、観測の数を数える。
  for (const b of project.buildings) {
    const own = new Set(b.corners);
    for (const c of b.corners) {
      const touching = observations.filter((o) => o.from === c || o.to === c);
      const anchors = new Set(touching.map((o) => (o.from === c ? o.to : o.from)).filter((id) => !own.has(id)));
      if (touching.length === 0) {
        flags.push({ severity: 'error', code: 'corner_unobserved', message: `${b.id} の角 ${c} の観測が1つも無い。`, building_id: b.id });
      } else if (anchors.size < tolerances.min_references_per_corner || touching.length < tolerances.min_observations_per_corner) {
        flags.push({
          severity: 'remeasure',
          code: 'insufficient_redundancy',
          message: `${b.id} の角 ${c}: 基準点・仮の点 ${anchors.size} 点、観測 ${touching.length} 件（必要: ${tolerances.min_references_per_corner} 点以上・${tolerances.min_observations_per_corner} 件以上）。照合ができないので、足りない分を測る。`,
          building_id: b.id,
        });
      }
    }
  }
  for (const a of auxiliary) {
    const touching = observations.filter((o) => o.from === a || o.to === a);
    if (touching.length < tolerances.min_observations_per_corner) {
      flags.push({
        severity: touching.length === 0 ? 'error' : 'remeasure',
        code: touching.length === 0 ? 'corner_unobserved' : 'insufficient_redundancy',
        message: `仮の点 ${a}: 観測 ${touching.length} 件（必要: ${tolerances.min_observations_per_corner} 件以上）。`,
      });
    }
  }

  /** @type {import('./adjust.mjs').AdjustmentResult|null} */
  let result = null;
  if (!flags.some((f) => f.severity === 'error')) {
    try {
      result = adjust(fixed, observations);
    } catch (error) {
      if (error instanceof AdjustmentError) {
        flags.push({ severity: 'error', code: error.code, message: error.message });
      } else {
        throw error;
      }
    }
  }

  /** @type {Record<string, unknown>[]} */
  const buildingReports = [];
  /** @type {Record<string, unknown>[]} */
  const features = [];
  if (result) {
    const adjusted = result;
    for (const r of adjusted.residuals) {
      if (Math.abs(r.residual_m) > tolerances.max_abs_residual_m) {
        flags.push({
          severity: 'remeasure',
          code: 'residual_too_large',
          message: `記録 ${r.record_id}（${r.from}→${r.to}）: 残差 ${r.residual_m.toFixed(2)} m（許容 ±${tolerances.max_abs_residual_m} m）。この観測と、同じ角に関わる観測を測り直す。`,
          building_id: cornerOwner.get(r.to) ?? cornerOwner.get(r.from),
          record_ids: [r.record_id],
        });
      }
    }
    for (const b of project.buildings) {
      const corners = b.corners.map((id) => /** @type {import('./adjust.mjs').PointResult} */ (adjusted.points.get(id)));
      for (const c of corners) {
        if (c.sigma_horizontal_m > tolerances.max_point_sigma_m) {
          flags.push({
            severity: 'remeasure',
            code: 'point_sigma_too_large',
            message: `${b.id} の角 ${c.id}: 位置の標準偏差 ${c.sigma_horizontal_m.toFixed(2)} m（許容 ${tolerances.max_point_sigma_m} m）。別の方向の基準点からも測る。`,
            building_id: b.id,
          });
        }
      }
      const ring = corners.map((c) => ({ east_m: c.east_m, north_m: c.north_m }));
      if (signedAreaEnu(ring) < 0) ring.reverse();
      const coords = ring.map((p) => {
        const g = enuToWgs84(p.east_m, p.north_m, origin);
        return [roundCoordinate(g.longitude), roundCoordinate(g.latitude)];
      });
      coords.push([...coords[0]]);
      const ids = new Set(b.corners);
      const own = adjusted.residuals.filter((r) => ids.has(r.from) || ids.has(r.to));
      const maxResidual = Math.max(...own.map((r) => Math.abs(r.residual_m)));
      const maxSigma = Math.max(...corners.map((c) => c.sigma_horizontal_m));
      const refsUsed = [...new Set(own.flatMap((r) => [r.from, r.to]).filter((id) => refById.has(id)))].sort();
      const ownRows = active.filter((row) => ids.has(row.point_id) || ids.has(row.from_point));
      const dates = b.survey_dates ?? [...new Set(ownRows.map((row) => row.observed_at.slice(0, 10)))].sort();
      const provenance = {
        geometry_source: 'field_survey',
        method: 'distance_trilateration_least_squares',
        survey_id: project.survey_id,
        survey_dates: dates,
        reference_point_ids: refsUsed,
        reference_sources: [...new Set(refsUsed.map((id) => refById.get(id)?.source ?? ''))].sort(),
        accuracy_m_1sigma: round3(maxSigma),
        max_abs_residual_m: round3(maxResidual),
        observation_count: own.length,
      };
      features.push({
        type: 'Feature',
        id: b.id,
        geometry: { type: 'Polygon', coordinates: [coords] },
        properties: { id: b.id, ...(b.name ? { name: b.name } : {}), ...provenance },
      });
      buildingReports.push({
        building_id: b.id,
        ...provenance,
        corners: corners.map((c) => ({
          id: c.id,
          east_m: round3(c.east_m),
          north_m: round3(c.north_m),
          sigma_horizontal_m: round3(c.sigma_horizontal_m),
          observation_count: c.observation_count,
        })),
        residuals: own.map((r) => ({ ...r, computed_m: round3(r.computed_m), residual_m: round3(r.residual_m), standardized: round3(r.standardized) })),
      });
    }
  }

  const ok = !flags.some((f) => f.severity === 'error' || f.severity === 'remeasure');
  return {
    ok,
    flags,
    origin,
    tolerances,
    adjustment: result
      ? { degrees_of_freedom: result.degrees_of_freedom, sigma0: round3(result.sigma0), iterations: result.iterations, observation_count: observations.length }
      : null,
    reference_checks: referenceChecks.map((c) => ({ ...c, from_reference_m: round3(c.from_reference_m), difference_m: round3(c.difference_m) })),
    buildings: buildingReports,
    geojson: features.length > 0 ? { type: 'FeatureCollection', features } : null,
  };
}

/**
 * 出典の記録（building-provenance.csv）に足す行を作る。
 * @param {ReturnType<typeof runSurvey>} outcome
 * @param {SurveyProject} project
 * @param {string} recordRef 野帳と測量設定の置き場所
 * @returns {string}
 */
export function provenanceRows(outcome, project, recordRef) {
  const names = new Map(project.buildings.map((b) => [b.id, b.name ?? '']));
  const lines = outcome.buildings.map((b) => {
    const r = /** @type {Record<string, any>} */ (b);
    const values = {
      building_id: r.building_id,
      display_name: names.get(r.building_id) ?? '',
      category: 'new_field_survey',
      geometry_source: 'field_survey',
      source_detail: `基準点 ${r.reference_point_ids.join(' ')}（${r.reference_sources.join(' ')}）からの測距`,
      acquired_on: r.survey_dates.join(' '),
      method: 'distance_trilateration_least_squares',
      terms: '自前の測量（学校の許可あり）。基準点の座標は国土地理院の基盤地図情報（利用手続は campus-survey-plan §2.2）',
      accuracy_m: String(r.accuracy_m_1sigma),
      accuracy_basis: `最小二乗の角の標準偏差（1σ）の最大。残差の最大 ${r.max_abs_residual_m} m。基準点そのものの誤差は含まない`,
      apple_google_used: 'no',
      checked_on: '',
      record_ref: recordRef,
      notes: '',
    };
    return PROVENANCE_COLUMNS.map((c) => csvCell(/** @type {Record<string, string>} */ (values)[c])).join(',');
  });
  return `${PROVENANCE_COLUMNS.join(',')}\n${lines.join('\n')}\n`;
}

/** @param {string} value */
function csvCell(value) {
  return /[",\n]/.test(value) ? `"${value.replace(/"/g, '""')}"` : value;
}

/** @param {number[]} values */
function mean(values) {
  return values.reduce((a, b) => a + b, 0) / values.length;
}

/** @param {number} v */
function round3(v) {
  return Math.round(v * 1000) / 1000;
}

/** @param {{east_m: number, north_m: number}[]} ring 閉じていない環 */
function signedAreaEnu(ring) {
  let s = 0;
  for (let i = 0; i < ring.length; i += 1) {
    const a = ring[i];
    const b = ring[(i + 1) % ring.length];
    s += a.east_m * b.north_m - b.east_m * a.north_m;
  }
  return s / 2;
}
