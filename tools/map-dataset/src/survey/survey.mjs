/**
 * 現地測量（既知の点からの測距・道路の基線からの支距）の記録から、
 * 建物の Polygon・経路の点・歩行経路の線を作る。
 *
 *   測量設定（JSON: 基準点・機材・建物の角・点・基線・照合点）
 *   + 野帳 CSV（観測）
 *     -> WGS 84 を局所ENUへ（E1-5 と同じ変換）
 *     -> 斜距離を水平距離へ、機材の目盛りの補正
 *     -> 最小二乗で点の位置を求める（基準点は固定）
 *     -> 残差・精度・冗長性・照合を確かめる（超えたら再測定の対象）
 *     -> WGS 84 の小数6桁へ戻し、GeoJSON を出す
 *
 * 手順と許容値の根拠: docs/map-data/campus-survey-plan.md
 * Apple・Google の地図の座標は、基準点にも初期値にも使わない（E1-4 改訂4）。
 */

import { parseCsv } from '../sources/csv-point-source.mjs';
import { enuToWgs84, wgs84ToEnu } from '../transform.mjs';
import { roundCoordinate } from '../geometry.mjs';
import { adjust, AdjustmentError } from './adjust.mjs';

export const SURVEY_VERSION = '1.1.0';
const ACCEPTED_VERSIONS = new Set(['1.0.0', SURVEY_VERSION]);

/** 既定の許容値。根拠は docs/map-data/campus-survey-plan.md §3.3・§4.3。 */
export const DEFAULT_TOLERANCES = Object.freeze({
  /** 1つの観測の残差の上限 [m]。超えたら、その観測を測り直す。 */
  max_abs_residual_m: 0.3,
  /** 点の位置の標準偏差（水平, 1σ）の上限 [m]。0.4 m は 95% でおおむね 1 m。 */
  max_point_sigma_m: 0.4,
  /** 別の建物の基準点どうしの、測った距離と国土地理院の座標からの距離の差の上限 [m]。 */
  reference_check_m: 1.0,
  /** 同じ建物の基準点どうし（辺・対角線）の差の上限 [m]。計画書 §3.3。 */
  reference_side_check_m: 0.5,
  /** 1つの点を測る、その建物以外の点（基準点・仮の点・基線の端・ほかの建物の角）の最小数。 */
  min_references_per_corner: 2,
  /** 1つの点に関わる観測の最小数（折れ点は2）。 */
  min_observations_per_corner: 3,
  /** 支距の上限の目安 [m]。直角の誤差 2° で 20 m なら約 0.7 m ずれる。超えたら注意として知らせる。 */
  max_offset_m: 15,
});

/** 野帳 CSV の必ず要る列。 */
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

/** 野帳 CSV の任意の列（1.1.0 で追加。無ければ空欄とみなす）。 */
export const OPTIONAL_OBSERVATION_COLUMNS = Object.freeze([
  'obs_type',
  'physical_point',
  'baseline_id',
  'chainage_m',
  'offset_m',
  'offset_side',
  'offset_instrument_id',
  'slope_deg',
  'height_diff_m',
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
  'absolute_accuracy',
  'apple_google_used',
  'checked_on',
  'record_ref',
  'notes',
]);

const POINT_KINDS = new Set(['aux', 'node', 'entrance', 'bend']);

/**
 * @typedef {object} Instrument
 * @property {string} kind
 * @property {number} sigma_m
 * @property {number} sigma_per_m
 * @property {number} [scale_factor] 校正の結果（表示 ÷ 真の長さ）。測った値をこれで割る
 */

/**
 * @typedef {object} SurveyProject
 * @property {string} survey_version
 * @property {string} survey_id
 * @property {{longitude: number, latitude: number}} [origin]
 * @property {number} [magnetic_declination_deg] 偏角（東偏が正、西偏が負）。方位は初期値にだけ使う
 * @property {number} [right_angle_sigma_deg] 支距の直角の誤差（1σ, 度）。直角プリズムなら 0.5、3-4-5 で確かめたなら 1
 * @property {Record<string, Instrument>} instruments
 * @property {{id: string, longitude: number, latitude: number, building_id: string, source: string, source_detail?: string}[]} references
 * @property {{id: string, name?: string, corners: string[], survey_dates?: string[]}[]} buildings
 * @property {string[]} [auxiliary_points] 1.0.0 の書き方。points の kind=aux と同じ
 * @property {{id: string, kind: string, building_id?: string, name?: string}[]} [points] 建物の角以外の点（仮の点・経路のノード・入口・折れ点）
 * @property {{id: string, from: string, to: string}[]} [baselines] 支距の基線（from が累積距離 0）
 * @property {{id: string, longitude: number, latitude: number, source: string, source_detail?: string}[]} [check_points] 調整に入れない照合点（公共基準点など）
 * @property {{id: string, points: string[]}[]} [edges] 歩行経路（端のノードと途中の折れ点の順）
 * @property {{id: string, points: string[]}[]} [loops] 閉合を確かめる点の輪
 * @property {Partial<typeof DEFAULT_TOLERANCES>} [tolerances]
 */

/**
 * @typedef {object} Flag
 * @property {'error'|'remeasure'|'warning'} severity error: 計算できない / remeasure: 計算できたが測り直す / warning: 注意
 * @property {string} code
 * @property {string} message
 * @property {string} [building_id]
 * @property {string[]} [record_ids]
 */

const ID_PATTERN = /^[A-Za-z0-9_.-]+$/;

/** @param {unknown} v */
const isNumber = (v) => typeof v === 'number' && Number.isFinite(v);

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
  if (!ACCEPTED_VERSIONS.has(p.survey_version)) err('unsupported_version', `survey_version は ${SURVEY_VERSION} にする。`);
  if (typeof p.survey_id !== 'string' || p.survey_id === '') err('missing_survey_id', 'survey_id が無い。');
  if (!p.instruments || typeof p.instruments !== 'object') err('missing_instruments', 'instruments が無い。');
  else {
    for (const [id, inst] of Object.entries(p.instruments)) {
      if (!isNumber(inst.sigma_m) || inst.sigma_m <= 0 || !isNumber(inst.sigma_per_m) || inst.sigma_per_m < 0) {
        err('invalid_instrument', `機材 ${id}: sigma_m（>0）と sigma_per_m（>=0）を数（文字列でなく）で書く。`);
      }
      if (inst.scale_factor !== undefined && (!isNumber(inst.scale_factor) || inst.scale_factor < 0.9 || inst.scale_factor > 1.1)) {
        err('invalid_instrument', `機材 ${id}: scale_factor は校正の結果（表示 ÷ 真の長さ）を 0.9〜1.1 の数で書く。`);
      }
    }
  }
  if (p.right_angle_sigma_deg !== undefined && (!isNumber(p.right_angle_sigma_deg) || p.right_angle_sigma_deg < 0)) {
    err('invalid_right_angle_sigma', 'right_angle_sigma_deg は 0 以上の数で書く。');
  }
  /** @type {Set<string>} */
  const allIds = new Set();
  /** @param {string} id @param {string} what */
  const claim = (id, what) => {
    if (typeof id !== 'string' || !ID_PATTERN.test(id)) err('invalid_point_id', `${what} の ID が不正: ${String(id)}`);
    else if (allIds.has(id)) err('duplicate_point_id', `点 ID が重複: ${id}（基準点・角・点・照合点で1回だけ）`);
    allIds.add(id);
  };
  /** @param {{id: string, longitude: number, latitude: number, source: string, source_detail?: string}} r @param {string} what */
  const checkGeo = (r, what) => {
    if (!isNumber(r.longitude) || !isNumber(r.latitude) || Math.abs(r.latitude) > 90 || Math.abs(r.longitude) > 180) {
      err('invalid_reference_coordinate', `${what} ${r.id}: longitude / latitude を10進度の数で書く。`);
    }
    if (typeof r.source !== 'string' || r.source === '') {
      err('missing_reference_source', `${what} ${r.id}: source（どの資料の座標か）が無い。`);
    } else if (/apple|google/i.test(`${r.source} ${r.source_detail ?? ''}`)) {
      err('forbidden_reference_source', `${what} ${r.id}: Apple・Google の地図を資料にしない（E1-4 改訂4 §3.1）。`);
    }
  };
  if (!Array.isArray(p.references) || p.references.length < 2) err('too_few_references', '基準点を2点以上書く。');
  else {
    for (const r of p.references) {
      claim(r.id, '基準点');
      checkGeo(r, '基準点');
    }
  }
  if (!Array.isArray(p.buildings)) err('missing_buildings', 'buildings が無い（建物を測らないときは空の配列）。');
  else {
    for (const b of p.buildings) {
      if (typeof b.id !== 'string' || !ID_PATTERN.test(b.id)) err('invalid_building_id', `建物 ID が不正: ${String(b.id)}`);
      if (!Array.isArray(b.corners) || b.corners.length < 3) err('too_few_corners', `建物 ${b.id}: corners を3つ以上、外周を回る順に書く。`);
      else for (const c of b.corners) claim(c, `建物 ${b.id} の角`);
    }
  }
  if (p.auxiliary_points !== undefined) {
    if (!Array.isArray(p.auxiliary_points)) err('invalid_auxiliary_points', 'auxiliary_points は点 ID の配列にする。');
    else for (const id of p.auxiliary_points) claim(id, '仮の点');
  }
  if (p.points !== undefined) {
    if (!Array.isArray(p.points)) err('invalid_points', 'points は配列にする。');
    else {
      for (const pt of p.points) {
        claim(pt.id, '点');
        if (!POINT_KINDS.has(pt.kind)) err('invalid_point_kind', `点 ${pt.id}: kind は aux・node・entrance・bend のどれか。`);
        if (pt.kind === 'entrance' && !pt.building_id) err('invalid_point_kind', `入口 ${pt.id}: building_id を書く。`);
      }
    }
  }
  if (p.check_points !== undefined) {
    if (!Array.isArray(p.check_points)) err('invalid_check_points', 'check_points は配列にする。');
    else {
      for (const c of p.check_points) {
        claim(c.id, '照合点');
        checkGeo(c, '照合点');
      }
    }
  }
  /** @type {Set<string>} */
  const baselineIds = new Set();
  for (const bl of p.baselines ?? []) {
    if (typeof bl.id !== 'string' || !ID_PATTERN.test(bl.id) || baselineIds.has(bl.id)) err('invalid_baseline', `基線 ID が不正か重複: ${String(bl.id)}`);
    baselineIds.add(bl.id);
    if (!allIds.has(bl.from) || !allIds.has(bl.to) || bl.from === bl.to) err('invalid_baseline', `基線 ${bl.id}: from と to に、別々の登録済みの点を書く。`);
  }
  for (const list of [p.edges ?? [], p.loops ?? []]) {
    for (const e of list) {
      if (typeof e.id !== 'string' || !Array.isArray(e.points) || e.points.length < 2 || e.points.some((id) => !allIds.has(id))) {
        err('invalid_edge', `経路・輪 ${String(e.id)}: points に登録済みの点を2つ以上、順に書く。`);
      }
    }
  }
  return { project: p, flags };
}

/**
 * @typedef {object} ObservationRow
 * @property {string} record_id
 * @property {'distance'|'chainage_offset'} obs_type
 * @property {string} building_id
 * @property {string} point_id
 * @property {string} from_point
 * @property {number} distance_m 水平距離（斜距離は換算済み）。chainage_offset では NaN
 * @property {number|null} slope_distance_m 斜距離を書いたときの元の値
 * @property {number|null} bearing_deg 磁北基準
 * @property {string} baseline_id
 * @property {number} chainage_m
 * @property {number} offset_m 右手側が正
 * @property {string} instrument_id
 * @property {string} offset_instrument_id
 * @property {string} measurer
 * @property {string} observed_at
 * @property {string} physical_point
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
    const get = (name) => (col[name] === undefined ? '' : (cells[col[name]] ?? '').trim());
    /** @param {string} name */
    const num = (name) => (get(name) === '' ? NaN : Number(get(name)));
    if (cells.every((c) => c.trim() === '')) return;
    const recordId = get('record_id');
    /** @param {string} code @param {string} message */
    const err = (code, message) =>
      flags.push({ severity: 'error', code, message: `野帳 ${line} 行目（${recordId || '記録番号なし'}）: ${message}`, record_ids: recordId ? [recordId] : [] });
    if (recordId === '') return err('missing_record_id', 'record_id が無い。');
    if (seen.has(recordId)) return err('duplicate_record_id', 'record_id が重複している。');
    seen.add(recordId);
    const typeText = get('obs_type');
    const obsType = typeText === '' || typeText === 'distance' || typeText === '距離' ? 'distance'
      : typeText === 'chainage_offset' || typeText === '支距' ? 'chainage_offset' : null;
    const isVoid = get('void') !== '';
    const bearingText = get('bearing_deg');
    const bearing = bearingText === '' ? null : Number(bearingText);

    /** @type {ObservationRow} */
    const row = {
      record_id: recordId,
      obs_type: obsType ?? 'distance',
      building_id: get('building_id'),
      point_id: get('point_id'),
      from_point: get('from_point'),
      distance_m: NaN,
      slope_distance_m: null,
      bearing_deg: bearing,
      baseline_id: get('baseline_id'),
      chainage_m: num('chainage_m'),
      offset_m: NaN,
      instrument_id: get('instrument_id'),
      offset_instrument_id: get('offset_instrument_id') || get('instrument_id'),
      measurer: get('measurer'),
      observed_at: get('observed_at'),
      physical_point: get('physical_point'),
      photo_ref: get('photo_ref'),
      notes: get('notes'),
      void: isVoid,
      line,
    };
    if (isVoid) {
      rows.push(row);
      return;
    }
    if (obsType === null) return err('invalid_obs_type', 'obs_type は空欄・distance（距離）・chainage_offset（支距）のどれか。');
    if (!ID_PATTERN.test(row.point_id)) return err('invalid_point_id', 'point_id が空か、使えない文字を含む。');
    if (row.instrument_id === '') return err('missing_instrument', 'instrument_id が無い。');
    if (row.measurer === '') return err('missing_measurer', 'measurer（役割か頭文字）が無い。');
    if (row.observed_at === '') return err('missing_observed_at', 'observed_at（日時）が無い。');

    if (obsType === 'distance') {
      if (!ID_PATTERN.test(row.from_point)) return err('invalid_point_id', 'from_point が空か、使えない文字を含む。');
      if (row.point_id === row.from_point) return err('same_point', 'point_id と from_point が同じ。');
      const raw = num('distance_m');
      if (!(raw > 0)) return err('invalid_distance', 'distance_m を正の数（メートル）で書く。');
      if (bearing !== null && !(Number.isFinite(bearing) && bearing >= 0 && bearing < 360)) return err('invalid_bearing', 'bearing_deg は 0 以上 360 未満の度で書く（空欄可）。');
      const hasSlope = get('slope_deg') !== '';
      const hasDh = get('height_diff_m') !== '';
      const slope = num('slope_deg');
      const dh = num('height_diff_m');
      if (hasSlope && hasDh) return err('ambiguous_slope', 'slope_deg と height_diff_m は片方だけ書く。');
      // 「30°」「3m」のような数でない値を空欄と同じに扱うと、斜距離が水平距離として通ってしまう。
      if (hasSlope && !Number.isFinite(slope)) return err('invalid_slope', 'slope_deg は数（度）だけで書く（単位は書かない）。');
      if (hasDh && !Number.isFinite(dh)) return err('invalid_slope', 'height_diff_m は数（m）だけで書く（単位は書かない）。');
      if (hasSlope) {
        if (!(slope >= 0 && slope < 45)) return err('invalid_slope', 'slope_deg は 0 以上 45 未満の度で書く。');
        row.slope_distance_m = raw;
        row.distance_m = raw * Math.cos((slope * Math.PI) / 180);
      } else if (hasDh) {
        if (!(Math.abs(dh) < raw)) return err('invalid_slope', 'height_diff_m は斜距離より小さく書く。');
        row.slope_distance_m = raw;
        row.distance_m = Math.sqrt(raw * raw - dh * dh);
      } else {
        row.distance_m = raw;
      }
    } else {
      if (!ID_PATTERN.test(row.baseline_id)) return err('missing_baseline', '支距の行には baseline_id を書く。');
      if (!Number.isFinite(row.chainage_m)) return err('invalid_chainage', 'chainage_m（基線の起点からの累積距離 m）を数で書く。');
      const off = num('offset_m');
      const side = get('offset_side').toUpperCase();
      if (!(off >= 0)) return err('invalid_offset', 'offset_m（基線からの垂直距離 m）を 0 以上の数で書く。');
      if (off > 0 && side !== 'R' && side !== 'L' && side !== '右' && side !== '左') return err('invalid_offset', 'offset_side に R（右）か L（左）を書く（起点から終点へ歩いたときの向き）。');
      row.offset_m = side === 'L' || side === '左' ? -off : off;
    }
    rows.push(row);
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
  const rightAngleSigmaRad = ((project.right_angle_sigma_deg ?? 1.0) * Math.PI) / 180;
  const cornerOwner = new Map(project.buildings.flatMap((b) => b.corners.map((c) => [c, b.id])));
  /** @type {Map<string, {id: string, kind: string, building_id?: string, name?: string}>} */
  const otherPoints = new Map();
  for (const id of project.auxiliary_points ?? []) otherPoints.set(id, { id, kind: 'aux' });
  for (const pt of project.points ?? []) otherPoints.set(pt.id, pt);
  const checkById = new Map((project.check_points ?? []).map((c) => [c.id, c]));
  const baselineById = new Map((project.baselines ?? []).map((b) => [b.id, b]));
  /** @param {string} id */
  const isUnknownPoint = (id) => cornerOwner.has(id) || otherPoints.has(id) || checkById.has(id);
  /** @param {string} id */
  const known = (id) => refById.has(id) || isUnknownPoint(id);
  /** @param {string} id */
  const ownerOf = (id) => cornerOwner.get(id) ?? refById.get(id)?.building_id ?? otherPoints.get(id)?.building_id;

  const active = rows.filter((r) => !r.void);
  /** @type {import('./adjust.mjs').Observation[]} */
  const observations = [];
  /** @type {{record_id: string, from: string, to: string, same_building: boolean, measured_m: number, from_reference_m: number, difference_m: number, tolerance_m: number, ok: boolean}[]} */
  const referenceChecks = [];
  for (const row of active) {
    const inst = project.instruments[row.instrument_id];
    const offInst = project.instruments[row.offset_instrument_id];
    if (!inst || !offInst) {
      flags.push({ severity: 'error', code: 'unknown_instrument', message: `記録 ${row.record_id}: 機材 ${!inst ? row.instrument_id : row.offset_instrument_id} が測量設定に無い。`, record_ids: [row.record_id] });
      continue;
    }
    /** @param {number} d @param {Instrument} i */
    const sigmaOf = (d, i) => i.sigma_m + i.sigma_per_m * Math.abs(d);
    /** @param {number} d @param {Instrument} i */
    const corrected = (d, i) => d / (i.scale_factor ?? 1);

    if (row.obs_type === 'chainage_offset') {
      const bl = baselineById.get(row.baseline_id);
      if (!bl) {
        flags.push({ severity: 'error', code: 'unknown_baseline', message: `記録 ${row.record_id}: 基線 ${row.baseline_id} が測量設定に無い。`, record_ids: [row.record_id] });
        continue;
      }
      if (!known(row.point_id)) {
        flags.push({ severity: 'error', code: 'unknown_point', message: `記録 ${row.record_id}: 点 ${row.point_id} が測量設定に無い。`, record_ids: [row.record_id] });
        continue;
      }
      const chainage = corrected(row.chainage_m, inst);
      const offset = corrected(row.offset_m, offInst);
      if (Math.abs(offset) > tolerances.max_offset_m) {
        flags.push({
          severity: 'warning',
          code: 'long_offset',
          message: `記録 ${row.record_id}: 支距 ${Math.abs(offset).toFixed(1)} m は ${tolerances.max_offset_m} m を超える。直角の誤差が効く（2° で 20 m なら約 0.7 m）。直角プリズムか 3-4-5 で確かめ、別の点からの距離も1本測る。`,
          record_ids: [row.record_id],
        });
      }
      const pts = [bl.from, bl.to, row.point_id];
      const chainageSigma = Math.hypot(sigmaOf(chainage, inst), Math.abs(offset) * Math.tan(rightAngleSigmaRad));
      observations.push({ record_id: row.record_id, kind: 'chainage', points: pts, value_m: chainage, sigma_m: chainageSigma, bearing_true_deg: null });
      observations.push({ record_id: row.record_id, kind: 'offset', points: pts, value_m: offset, sigma_m: sigmaOf(offset, offInst), bearing_true_deg: null });
      continue;
    }

    for (const id of [row.point_id, row.from_point]) {
      if (!known(id)) {
        flags.push({ severity: 'error', code: 'unknown_point', message: `記録 ${row.record_id}: 点 ${id} が基準点・建物の角・点・照合点のどれにも無い。`, record_ids: [row.record_id] });
      }
    }
    if (!known(row.point_id) || !known(row.from_point)) continue;
    const distance = corrected(row.distance_m, inst);
    if (refById.has(row.point_id) && refById.has(row.from_point)) {
      const a = /** @type {{east_m: number, north_m: number}} */ (fixed.get(row.from_point));
      const b = /** @type {{east_m: number, north_m: number}} */ (fixed.get(row.point_id));
      const computed = Math.hypot(b.east_m - a.east_m, b.north_m - a.north_m);
      const diff = distance - computed;
      const sameBuilding = refById.get(row.from_point)?.building_id === refById.get(row.point_id)?.building_id;
      const tol = sameBuilding ? tolerances.reference_side_check_m : tolerances.reference_check_m;
      const ok = Math.abs(diff) <= tol;
      referenceChecks.push({ record_id: row.record_id, from: row.from_point, to: row.point_id, same_building: sameBuilding, measured_m: distance, from_reference_m: computed, difference_m: diff, tolerance_m: tol, ok });
      if (!ok) {
        flags.push({
          severity: 'remeasure',
          code: 'reference_mismatch',
          message: `基準点 ${row.from_point}–${row.point_id}（${sameBuilding ? '同じ建物の辺・対角線' : '建物どうし'}）: 測った距離と国土地理院の座標からの距離が ${diff.toFixed(2)} m 違う（許容 ±${tol} m）。測り直し、それでも違えば、この建物の角を基準点に使わない。`,
          record_ids: [row.record_id],
        });
      }
      continue;
    }
    observations.push({
      record_id: row.record_id,
      kind: 'distance',
      points: [row.from_point, row.point_id],
      value_m: distance,
      sigma_m: sigmaOf(distance, inst),
      bearing_true_deg: row.bearing_deg === null ? null : (((row.bearing_deg + declination) % 360) + 360) % 360,
    });
  }

  // 照合点は観測があるときだけ求める（調整では固定しない）。位置が決まらない照合点の観測は外す。
  /** @type {string[]} */
  const observedCheckIds = [];
  for (const id of checkById.keys()) {
    const touching = observations.filter((o) => o.points.includes(id));
    if (touching.length === 0) continue;
    const anchors = new Set(touching.flatMap((o) => o.points).filter((p) => p !== id));
    if (touching.length < 2 || anchors.size < 2) {
      flags.push({ severity: 'warning', code: 'check_point_underdetermined', message: `照合点 ${id}: 観測が足りず位置が決まらないので、照合に使わない（2つ以上の点から測る）。` });
      for (const o of touching) observations.splice(observations.indexOf(o), 1);
      continue;
    }
    observedCheckIds.push(id);
  }

  // 冗長性: 各点について、ほかの点（その建物以外）の数と、観測の数を数える。
  /** @param {string} id @param {Set<string>} own @param {number} minObs @param {string} label @param {string} [buildingId] */
  const checkRedundancy = (id, own, minObs, label, buildingId) => {
    const touching = observations.filter((o) => o.points.includes(id));
    const anchors = new Set(touching.flatMap((o) => o.points).filter((p) => p !== id && !own.has(p)));
    if (touching.length === 0) {
      flags.push({ severity: 'error', code: 'corner_unobserved', message: `${label} の観測が1つも無い。`, ...(buildingId ? { building_id: buildingId } : {}) });
    } else if (anchors.size < tolerances.min_references_per_corner || touching.length < minObs) {
      flags.push({
        severity: 'remeasure',
        code: 'insufficient_redundancy',
        message: `${label}: ほかの点 ${anchors.size} 点、観測 ${touching.length} 件（必要: ${tolerances.min_references_per_corner} 点以上・${minObs} 件以上）。照合ができないので、足りない分を測る。`,
        ...(buildingId ? { building_id: buildingId } : {}),
      });
    }
  };
  for (const b of project.buildings) {
    const own = new Set(b.corners);
    for (const c of b.corners) checkRedundancy(c, own, tolerances.min_observations_per_corner, `${b.id} の角 ${c}`, b.id);
  }
  for (const pt of otherPoints.values()) {
    const minObs = pt.kind === 'bend' ? 2 : tolerances.min_observations_per_corner;
    checkRedundancy(pt.id, new Set(), minObs, `${pointKindLabel(pt.kind)} ${pt.id}`);
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
  /** @type {Record<string, unknown>[]} */
  const pointFeatures = [];
  /** @type {Record<string, unknown>[]} */
  const routeFeatures = [];
  /** @type {Record<string, unknown>[]} */
  const loopChecks = [];
  /** @type {{status: 'unverified'|'checked', check_points: Record<string, unknown>[], max_difference_m: number|null}} */
  let absolute = { status: 'unverified', check_points: [], max_difference_m: null };
  if (result) {
    const adjusted = result;
    /** @param {string} id */
    const enuOf = (id) => fixed.get(id) ?? /** @type {import('./adjust.mjs').PointResult} */ (adjusted.points.get(id));
    /** @param {string} id */
    const lonLat = (id) => {
      const p = enuOf(id);
      const g = enuToWgs84(p.east_m, p.north_m, origin);
      return [roundCoordinate(g.longitude), roundCoordinate(g.latitude)];
    };

    for (const r of adjusted.residuals) {
      if (Math.abs(r.residual_m) > tolerances.max_abs_residual_m) {
        flags.push({
          severity: 'remeasure',
          code: 'residual_too_large',
          message: `記録 ${r.record_id}（${observationLabel(r.kind, r.points)}）: 残差 ${r.residual_m.toFixed(2)} m（許容 ±${tolerances.max_abs_residual_m} m）。その日のうちに、この観測と、同じ点に関わる観測を測り直す。`,
          building_id: r.points.map((id) => cornerOwner.get(id)).find(Boolean),
          record_ids: [r.record_id],
        });
      }
    }
    for (const [id, pt] of adjusted.points) {
      if (checkById.has(id)) continue;
      if (pt.sigma_horizontal_m > tolerances.max_point_sigma_m) {
        flags.push({
          severity: 'remeasure',
          code: 'point_sigma_too_large',
          message: `${id}: 位置の標準偏差 ${pt.sigma_horizontal_m.toFixed(2)} m（許容 ${tolerances.max_point_sigma_m} m）。別の方向の点からも測る。`,
          building_id: cornerOwner.get(id),
        });
      }
    }

    // 絶対精度の照合（調整に入れない照合点）
    if (observedCheckIds.length > 0) {
      const checks = observedCheckIds.map((id) => {
        const c = /** @type {{id: string, longitude: number, latitude: number, source: string}} */ (checkById.get(id));
        const truth = wgs84ToEnu(c.longitude, c.latitude, origin);
        const got = /** @type {import('./adjust.mjs').PointResult} */ (adjusted.points.get(id));
        const diff = Math.hypot(got.east_m - truth.east_m, got.north_m - truth.north_m);
        return { id, source: c.source, difference_m: round3(diff), sigma_horizontal_m: round3(got.sigma_horizontal_m) };
      });
      absolute = { status: 'checked', check_points: checks, max_difference_m: Math.max(...checks.map((c) => c.difference_m)) };
    }

    const graph = buildGraph(observations);
    for (const b of project.buildings) {
      const corners = b.corners.map((id) => /** @type {import('./adjust.mjs').PointResult} */ (adjusted.points.get(id)));
      const ring = corners.map((c) => ({ east_m: c.east_m, north_m: c.north_m }));
      if (signedAreaEnu(ring) < 0) ring.reverse();
      const coords = ring.map((p) => {
        const g = enuToWgs84(p.east_m, p.north_m, origin);
        return [roundCoordinate(g.longitude), roundCoordinate(g.latitude)];
      });
      coords.push([...coords[0]]);
      const ids = new Set(b.corners);
      const own = adjusted.residuals.filter((r) => r.points.some((id) => ids.has(id)));
      const maxResidual = Math.max(...own.map((r) => Math.abs(r.residual_m)));
      const maxSigma = Math.max(...corners.map((c) => c.sigma_horizontal_m));
      const refsUsed = reachableReferences(b.corners, graph, refById);
      const ownRows = active.filter((row) => ids.has(row.point_id) || ids.has(row.from_point));
      const dates = b.survey_dates ?? [...new Set(ownRows.map((row) => row.observed_at.slice(0, 10)))].sort();
      const provenance = {
        geometry_source: 'field_survey',
        method: 'field_survey_least_squares',
        survey_id: project.survey_id,
        survey_dates: dates,
        reference_point_ids: refsUsed,
        reference_sources: [...new Set(refsUsed.map((id) => refById.get(id)?.source ?? ''))].sort(),
        relative_accuracy_m_1sigma: round3(maxSigma),
        absolute_accuracy: absolute.status,
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
        residuals: own.map((r) => roundResidual(r)),
      });
    }

    for (const pt of [...otherPoints.values(), ...observedCheckIds.map((id) => ({ id, kind: 'check' }))]) {
      const got = adjusted.points.get(pt.id);
      if (!got) continue;
      pointFeatures.push({
        type: 'Feature',
        id: pt.id,
        geometry: { type: 'Point', coordinates: lonLat(pt.id) },
        properties: {
          id: pt.id,
          kind: pt.kind,
          ...('building_id' in pt && pt.building_id ? { building_id: pt.building_id } : {}),
          ...('name' in pt && pt.name ? { name: pt.name } : {}),
          geometry_source: 'field_survey',
          survey_id: project.survey_id,
          relative_accuracy_m_1sigma: round3(got.sigma_horizontal_m),
          absolute_accuracy: absolute.status,
          reference_point_ids: reachableReferences([pt.id], graph, refById),
        },
      });
    }

    for (const e of project.edges ?? []) {
      let length = 0;
      for (let i = 1; i < e.points.length; i += 1) {
        const a = enuOf(e.points[i - 1]);
        const c = enuOf(e.points[i]);
        length += Math.hypot(c.east_m - a.east_m, c.north_m - a.north_m);
      }
      routeFeatures.push({
        type: 'Feature',
        id: e.id,
        geometry: { type: 'LineString', coordinates: e.points.map((id) => lonLat(id)) },
        properties: {
          id: e.id,
          from_node_id: e.points[0],
          to_node_id: e.points[e.points.length - 1],
          distance_m: Math.round(length * 10) / 10,
          vertex_point_ids: e.points,
          geometry_source: 'field_survey',
          survey_id: project.survey_id,
        },
      });
    }

    for (const loop of project.loops ?? []) {
      const seq = [...loop.points, loop.points[0]];
      /** @type {Record<string, unknown>[]} */
      const legs = [];
      let observedSum = 0;
      let adjustedSum = 0;
      /** @type {string[]} */
      const unobserved = [];
      for (let i = 1; i < seq.length; i += 1) {
        const a = seq[i - 1];
        const c = seq[i];
        const pa = enuOf(a);
        const pc = enuOf(c);
        const adj = Math.hypot(pc.east_m - pa.east_m, pc.north_m - pa.north_m);
        // 基準点どうしの距離は調整に入れず referenceChecks に移している。輪の照合では、それも測った区間として使う。
        const measured = [
          ...observations.filter((o) => o.kind === 'distance' && o.points.includes(a) && o.points.includes(c)).map((o) => o.value_m),
          ...referenceChecks.filter((r) => (r.from === a && r.to === c) || (r.from === c && r.to === a)).map((r) => r.measured_m),
        ];
        const observed = measured.length > 0 ? mean(measured) : null;
        if (observed === null) unobserved.push(`${a}–${c}`);
        else {
          observedSum += observed;
          adjustedSum += adj;
        }
        legs.push({ from: a, to: c, observed_m: observed === null ? null : round3(observed), adjusted_m: round3(adj), residual_m: observed === null ? null : round3(observed - adj) });
      }
      loopChecks.push({
        id: loop.id,
        legs,
        observed_total_m: round3(observedSum),
        adjusted_total_m: round3(adjustedSum),
        misclosure_m: round3(observedSum - adjustedSum),
        unobserved_legs: unobserved,
      });
      if (Math.abs(observedSum - adjustedSum) > tolerances.max_abs_residual_m * Math.max(1, legs.length - unobserved.length) ** 0.5) {
        flags.push({
          severity: 'remeasure',
          code: 'loop_misclosure',
          message: `輪 ${loop.id}: 測った長さの合計と、調整後の形の長さの合計が ${(observedSum - adjustedSum).toFixed(2)} m 違う。どこかの区間の測り違い（ウォーキングメジャーの読み違い・目盛りの誤差）を疑う。`,
        });
      }
      if (unobserved.length > 0) {
        flags.push({ severity: 'warning', code: 'loop_unobserved_leg', message: `輪 ${loop.id}: 直接測っていない区間がある（${unobserved.join(', ')}）。` });
      }
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
    accuracy: {
      relative: '各点の標準偏差（1σ、最小二乗）。目標は 95% でおおむね 1 m（1σ 0.4 m 以下）。',
      absolute: absolute.status === 'checked'
        ? `調整に入れない照合点 ${absolute.check_points.length} 点との差の最大 ${absolute.max_difference_m} m。`
        : '確かめていない。基準点（国土地理院 地図情報レベル2500、標準偏差 1.75 m 以内とされる）の誤差がそのまま残る。公共基準点などの照合点を測ると確かめられる。',
      absolute_check: absolute,
    },
    reference_checks: referenceChecks.map((c) => ({ ...c, measured_m: round3(c.measured_m), from_reference_m: round3(c.from_reference_m), difference_m: round3(c.difference_m) })),
    loop_checks: loopChecks,
    slope_conversions: active
      .filter((r) => r.slope_distance_m !== null)
      .map((r) => ({ record_id: r.record_id, slope_m: r.slope_distance_m, horizontal_m: round3(r.distance_m) })),
    buildings: buildingReports,
    points: pointFeatures.map((f) => /** @type {any} */ (f).properties),
    geojson: features.length > 0 ? { type: 'FeatureCollection', features } : null,
    points_geojson: pointFeatures.length > 0 ? { type: 'FeatureCollection', features: pointFeatures } : null,
    routes_geojson: routeFeatures.length > 0 ? { type: 'FeatureCollection', features: routeFeatures } : null,
  };
}

/** @param {string} kind */
function pointKindLabel(kind) {
  return { aux: '仮の点', node: '経路のノード', entrance: '入口', bend: '折れ点' }[kind] ?? '点';
}

/** @param {string} kind @param {string[]} points */
function observationLabel(kind, points) {
  if (kind === 'distance') return `${points[0]}→${points[1]}`;
  return `${points[2]} の${kind === 'chainage' ? '累積距離' : '支距'}（基線 ${points[0]}→${points[1]}）`;
}

/** @param {import('./adjust.mjs').ObservationResidual} r */
function roundResidual(r) {
  return { ...r, computed_m: round3(r.computed_m), residual_m: round3(r.residual_m), standardized: round3(r.standardized), sigma_m: round3(r.sigma_m) };
}

/**
 * 観測でつながる点の隣接リスト。
 * @param {import('./adjust.mjs').Observation[]} observations
 */
function buildGraph(observations) {
  /** @type {Map<string, Set<string>>} */
  const graph = new Map();
  for (const o of observations) {
    for (const a of o.points) {
      for (const b of o.points) {
        if (a === b) continue;
        if (!graph.has(a)) graph.set(a, new Set());
        /** @type {Set<string>} */ (graph.get(a)).add(b);
      }
    }
  }
  return graph;
}

/**
 * 点から観測をたどって届く基準点（固定点）。基準点の先へはたどらない。
 * 仮の点・ノード・ほかの建物の角を経由した基準点も含める。
 * @param {string[]} start
 * @param {Map<string, Set<string>>} graph
 * @param {Map<string, unknown>} refById
 * @returns {string[]}
 */
function reachableReferences(start, graph, refById) {
  const seen = new Set(start);
  const queue = [...start];
  /** @type {Set<string>} */
  const refs = new Set();
  while (queue.length > 0) {
    const id = /** @type {string} */ (queue.shift());
    for (const next of graph.get(id) ?? []) {
      if (seen.has(next)) continue;
      seen.add(next);
      if (refById.has(next)) refs.add(next);
      else queue.push(next);
    }
  }
  return [...refs].sort();
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
  const absolute = outcome.accuracy.absolute_check;
  const lines = outcome.buildings.map((b) => {
    const r = /** @type {Record<string, any>} */ (b);
    const values = {
      building_id: r.building_id,
      display_name: names.get(r.building_id) ?? '',
      category: 'new_field_survey',
      geometry_source: 'field_survey',
      source_detail: `基準点 ${r.reference_point_ids.join(' ')}（${r.reference_sources.join(' ')}）からの測距・支距`,
      acquired_on: r.survey_dates.join(' '),
      method: 'field_survey_least_squares',
      terms: '自前の測量（学校の許可あり）。基準点の座標は国土地理院の基盤地図情報（利用手続は campus-survey-plan §2.2）',
      accuracy_m: String(r.relative_accuracy_m_1sigma),
      accuracy_basis: `相対精度: 最小二乗の角の標準偏差（1σ）の最大。残差の最大 ${r.max_abs_residual_m} m。基準点そのものの誤差は含まない`,
      absolute_accuracy: absolute.status === 'checked' ? `照合点との差の最大 ${absolute.max_difference_m} m` : '未確認（基準点の精度に従う）',
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
