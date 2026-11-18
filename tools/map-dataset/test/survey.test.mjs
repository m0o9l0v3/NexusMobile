/**
 * 現地測量 → 建物 Polygon（survey）のテスト。
 *
 * 実測の値は使わない。局所ENU上に正解の形を置き、そこから距離を合成して
 * 「正解に戻るか」「測り違いを見つけるか」を確かめる。
 */

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import { adjust, circleIntersections, initialPositions } from '../src/survey/adjust.mjs';
import { parseObservations, parseProject, provenanceRows, runSurvey, OBSERVATION_COLUMNS, OPTIONAL_OBSERVATION_COLUMNS, PROVENANCE_COLUMNS } from '../src/survey/survey.mjs';
import { run } from '../src/survey/cli.mjs';
import { enuToWgs84, wgs84ToEnu } from '../src/transform.mjs';
import { isRounded } from '../src/geometry.mjs';
import { validateDataset } from '../src/validate.mjs';
import { buildInDir, makeWorkspace, minimalCase, REPO_SCHEMA_PATH } from './helpers.mjs';

const ORIGIN = { longitude: 141.62, latitude: 42.78 };

/** 基準点（古い建物の角の想定）。ENU [m]。 */
const REFS = { R1: [0, 0], R2: [40, 0], R3: [0, 30], R4: [45, 35] };
/** 新しい建物の正解（ENU [m]、外周を回る順）。 */
const TRUE_CORNERS = { 'nb-P1': [12, 8], 'nb-P2': [30, 8], 'nb-P3': [30, 20], 'nb-P4': [12, 20] };

/** @param {number[]} a @param {number[]} b */
const dist = (a, b) => Math.hypot(b[0] - a[0], b[1] - a[1]);

function projectFixture() {
  return {
    survey_version: '1.0.0',
    survey_id: 'test-survey',
    origin: ORIGIN,
    magnetic_declination_deg: 0,
    instruments: { LD1: { kind: 'laser_rangefinder', sigma_m: 0.03, sigma_per_m: 0.0005 } },
    references: Object.entries(REFS).map(([id, [e, n]]) => {
      const g = enuToWgs84(e, n, ORIGIN);
      return { id, longitude: g.longitude, latitude: g.latitude, building_id: 'old', source: 'gsi_fgd' };
    }),
    buildings: [{ id: 'nb', name: '新しい棟', corners: Object.keys(TRUE_CORNERS) }],
  };
}

/**
 * 計画どおりの観測（各角に基準点2〜3点・全辺・対角線1本）。
 * @param {Record<string, number>} [errors] record_id -> 足す誤差 [m]
 */
function observationRows(errors = {}) {
  /** @type {[string, string][]} */
  const pairs = [
    ['R1', 'nb-P1'], ['R3', 'nb-P1'], ['R2', 'nb-P1'],
    ['R2', 'nb-P2'], ['R1', 'nb-P2'], ['R4', 'nb-P2'],
    ['R4', 'nb-P3'], ['R2', 'nb-P3'],
    ['R3', 'nb-P4'], ['R4', 'nb-P4'],
    ['nb-P1', 'nb-P2'], ['nb-P2', 'nb-P3'], ['nb-P3', 'nb-P4'], ['nb-P4', 'nb-P1'],
    ['nb-P1', 'nb-P3'],
  ];
  /** @type {Record<string, number[]>} */
  const all = { ...REFS, ...TRUE_CORNERS };
  return pairs.map(([from, to], i) => {
    const id = `T${String(i + 1).padStart(3, '0')}`;
    const d = dist(all[from], all[to]) + (errors[id] ?? 0);
    return [id, 'nb', to, from, d.toFixed(3), '', 'LD1', 'A', '2026-12-01T10:00', `IMG_${i}`, '', ''];
  });
}

/** @param {string[][]} rows */
function toCsv(rows) {
  return [OBSERVATION_COLUMNS.join(','), ...rows.map((r) => r.join(','))].join('\n') + '\n';
}

/** @param {Record<string, number>} [errors] */
function solve(errors) {
  const { project, flags } = parseProject(projectFixture());
  assert.deepEqual(flags, []);
  const parsed = parseObservations(toCsv(observationRows(errors)));
  assert.deepEqual(parsed.flags, []);
  return runSurvey(project, parsed.rows);
}

test('2つの円の交点を2つ返す', () => {
  const pts = circleIntersections({ east_m: 0, north_m: 0 }, 5, { east_m: 8, north_m: 0 }, 5);
  assert.equal(pts.length, 2);
  for (const p of pts) {
    assert.ok(Math.abs(p.east_m - 4) < 1e-9);
    assert.ok(Math.abs(Math.abs(p.north_m) - 3) < 1e-9);
  }
});

test('誤差の無い距離から、角の位置を mm 以下で復元する', () => {
  const out = solve();
  assert.equal(out.ok, true, JSON.stringify(out.flags));
  const b = /** @type {any} */ (out.buildings[0]);
  for (const c of b.corners) {
    const truth = /** @type {Record<string, number[]>} */ (TRUE_CORNERS)[c.id];
    assert.ok(Math.abs(c.east_m - truth[0]) < 0.001 && Math.abs(c.north_m - truth[1]) < 0.001, c.id);
  }
  assert.ok(b.max_abs_residual_m < 0.001);
  assert.equal(/** @type {any} */ (out.adjustment).degrees_of_freedom, 15 - 8);
});

test('GeoJSON は小数6桁・閉じた反時計回りの環で、出典を properties に持つ', () => {
  const out = solve();
  const f = /** @type {any} */ (out.geojson).features[0];
  assert.equal(f.id, 'nb');
  assert.equal(f.properties.id, 'nb');
  assert.equal(f.properties.geometry_source, 'field_survey');
  assert.deepEqual(f.properties.reference_point_ids, ['R1', 'R2', 'R3', 'R4']);
  assert.deepEqual(f.properties.survey_dates, ['2026-12-01']);
  const ring = f.geometry.coordinates[0];
  assert.equal(ring.length, 5);
  assert.deepEqual(ring[0], ring[4]);
  for (const [lon, lat] of ring) assert.ok(isRounded(lon) && isRounded(lat));
  let area = 0;
  for (let i = 0; i < 4; i += 1) {
    const a = wgs84ToEnu(ring[i][0], ring[i][1], ORIGIN);
    const c = wgs84ToEnu(ring[i + 1][0], ring[i + 1][1], ORIGIN);
    area += a.east_m * c.north_m - c.east_m * a.north_m;
  }
  assert.ok(area > 0, '反時計回り');
});

test('数 cm の誤差では許容値内に収まる', () => {
  const out = solve({ T001: 0.04, T005: -0.03, T011: 0.05, T015: -0.04 });
  assert.equal(out.ok, true, JSON.stringify(out.flags));
});

test('1 m の測り違いを残差で見つけ、再測定の対象にする', () => {
  const out = solve({ T004: 1.0 });
  assert.equal(out.ok, false);
  const codes = out.flags.map((f) => f.code);
  assert.ok(codes.includes('residual_too_large'), codes.join(','));
  assert.ok(out.flags.every((f) => f.severity !== 'error'));
});

test('基準点が2点しかない角は、冗長性が足りないとして再測定の対象にする', () => {
  const { project } = parseProject(projectFixture());
  const rows = observationRows().filter((r) => !(r[2] === 'nb-P1' && r[3] === 'R3'))
    .filter((r) => !(r[2] === 'nb-P1' && r[3] === 'R2'));
  const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
  assert.ok(out.flags.some((f) => f.code === 'insufficient_redundancy' && f.message.includes('nb-P1')));
});

test('基準点どうしの距離が国土地理院の座標と合わなければ知らせ、調整には入れない', () => {
  const { project } = parseProject(projectFixture());
  const rows = observationRows();
  rows.push(['C001', 'old', 'R2', 'R1', '41.500', '', 'LD1', 'A', '2026-12-01T09:00', '', '', '']);
  rows.push(['C002', 'old', 'R3', 'R1', '30.200', '', 'LD1', 'A', '2026-12-01T09:05', '', '', '']);
  const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
  assert.equal(out.reference_checks.length, 2);
  assert.equal(out.reference_checks.find((c) => c.record_id === 'C001')?.ok, false);
  assert.equal(out.reference_checks.find((c) => c.record_id === 'C002')?.ok, true);
  assert.ok(out.flags.some((f) => f.code === 'reference_mismatch'));
  assert.equal(/** @type {any} */ (out.adjustment).observation_count, 15);
});

test('void を付けた行は計算に入れない', () => {
  const rows = observationRows({ T004: 1.0 });
  rows[3][11] = '再測定 T016';
  const d = dist(REFS.R2, TRUE_CORNERS['nb-P2']).toFixed(3);
  rows.push(['T016', 'nb', 'nb-P2', 'R2', d, '', 'LD1', 'A', '2026-12-01T11:00', '', '', '']);
  const { project } = parseProject(projectFixture());
  const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
  assert.equal(out.ok, true, JSON.stringify(out.flags));
});

test('2つの距離だけで鏡像を決められない点は、方位があれば決まる', () => {
  const fixed = new Map([['A', { east_m: 0, north_m: 0 }], ['B', { east_m: 10, north_m: 0 }]]);
  const base = { sigma_m: 0.03, bearing_true_deg: /** @type {number|null} */ (null), kind: /** @type {'distance'} */ ('distance') };
  const obs = [
    { ...base, record_id: '1', points: ['A', 'X'], value_m: Math.hypot(5, 4) },
    { ...base, record_id: '2', points: ['B', 'X'], value_m: Math.hypot(5, 4) },
  ];
  assert.throws(() => initialPositions(fixed, ['X'], obs), /位置の見当がつけられない/);
  const withBearing = [{ ...obs[0], bearing_true_deg: 180 }, obs[1]];
  const init = initialPositions(fixed, ['X'], withBearing);
  assert.ok(/** @type {any} */ (init.get('X')).north_m < 0, '南側の候補を選ぶ');
  const res = adjust(fixed, withBearing);
  assert.ok(Math.abs(/** @type {any} */ (res.points.get('X')).north_m + 4) < 1e-6);
});

test('Apple・Google の地図を基準点の資料にした設定は拒否する', () => {
  const p = projectFixture();
  p.references[0].source = 'google_maps';
  const { flags } = parseProject(p);
  assert.ok(flags.some((f) => f.code === 'forbidden_reference_source'));
});

test('野帳の必須列・測った人・日時が無い行は拒否する', () => {
  const rows = observationRows();
  rows[0][7] = '';
  const { flags } = parseObservations(toCsv(rows));
  assert.ok(flags.some((f) => f.code === 'missing_measurer'));
  assert.ok(parseObservations('record_id,distance_m\n1,2\n').flags.some((f) => f.code === 'missing_columns'));
});

test('出典の行は building-provenance.csv の列で出る', () => {
  const out = solve();
  const { project } = parseProject(projectFixture());
  const csv = provenanceRows(out, project, 'field-2026-12-01.csv');
  const [header, row] = csv.trim().split('\n');
  assert.ok(header.startsWith('building_id,display_name,category,geometry_source'));
  assert.ok(row.startsWith('nb,新しい棟,new_field_survey,field_survey'));
  assert.ok(row.includes(',no,'));
});

test('CLI: 出力した GeoJSON を map-dataset の geojson 原本として読み、スキーマに適合する', async () => {
  const dir = makeWorkspace({ 'project.json': projectFixture(), 'field.csv': toCsv(observationRows()) });
  const io = { log: () => {}, error: () => {} };
  const code = run(
    ['--project', path.join(dir, 'project.json'), '--observations', path.join(dir, 'field.csv'),
      '--report', path.join(dir, 'report.json'), '--out', path.join(dir, 'source.geojson'),
      '--provenance-out', path.join(dir, 'prov.csv')],
    io,
  );
  assert.equal(code, 0);
  assert.ok(existsSync(path.join(dir, 'prov.csv')));
  const report = JSON.parse(readFileSync(path.join(dir, 'report.json'), 'utf8'));
  assert.equal(report.ok, true);

  const { config } = minimalCase();
  config.features[0].source_id = 'nb';
  config.features[0].canonical_id = 'mb';
  const cfgDir = makeWorkspace({ 'config.json': config, 'source.geojson': readFileSync(path.join(dir, 'source.geojson'), 'utf8') });
  const result = await buildInDir(cfgDir);
  assert.ok(result.findings.ok, result.findings.errors.map((f) => f.message).join('\n'));
  const findings = validateDataset(result.dataset, { schemaPath: REPO_SCHEMA_PATH });
  assert.ok(findings.ok, findings.errors.map((f) => f.message).join('\n'));
});

test('CLI: 再測定の対象があれば終了コード1で、GeoJSON を書き出さない', () => {
  const dir = makeWorkspace({ 'project.json': projectFixture(), 'field.csv': toCsv(observationRows({ T004: 1.0 })) });
  const code = run(
    ['--project', path.join(dir, 'project.json'), '--observations', path.join(dir, 'field.csv'),
      '--report', path.join(dir, 'report.json'), '--out', path.join(dir, 'out.geojson')],
    { log: () => {}, error: () => {} },
  );
  assert.equal(code, 1);
  assert.ok(!existsSync(path.join(dir, 'out.geojson')));
  assert.ok(existsSync(path.join(dir, 'report.json')));
});

test('CLI: 出力先に入力を指定すると止まる', () => {
  const dir = makeWorkspace({ 'project.json': projectFixture(), 'field.csv': toCsv(observationRows()) });
  const code = run(
    ['--project', path.join(dir, 'project.json'), '--observations', path.join(dir, 'field.csv'),
      '--report', path.join(dir, 'field.csv')],
    { log: () => {}, error: () => {} },
  );
  assert.equal(code, 2);
});

test('基準点から遠い建物は、仮の点（auxiliary_points）を経由して求められる', () => {
  const p = /** @type {any} */ (projectFixture());
  p.auxiliary_points = ['T1', 'T2'];
  p.buildings = [{ id: 'far', corners: ['f-P1', 'f-P2', 'f-P3', 'f-P4'] }];
  /** @type {Record<string, number[]>} */
  const pts = { ...REFS, T1: [60, 10], T2: [62, 30], 'f-P1': [90, 5], 'f-P2': [110, 5], 'f-P3': [110, 25], 'f-P4': [90, 25] };
  /** @type {[string, string, string][]} */
  const pairs = [
    ['R2', 'T1', ''], ['R4', 'T1', ''], ['R1', 'T1', ''],
    ['R4', 'T2', ''], ['R2', 'T2', ''], ['T1', 'T2', ''],
    ['T1', 'f-P1', '95'], ['T2', 'f-P1', ''], ['T1', 'f-P2', ''], ['T2', 'f-P2', ''],
    ['T1', 'f-P3', ''], ['T2', 'f-P3', ''], ['T1', 'f-P4', ''], ['T2', 'f-P4', ''],
    ['f-P1', 'f-P2', ''], ['f-P2', 'f-P3', ''], ['f-P3', 'f-P4', ''], ['f-P4', 'f-P1', ''], ['f-P1', 'f-P3', ''],
  ];
  const rows = pairs.map(([from, to, bearing], i) => [`A${i}`, 'far', to, from, dist(pts[from], pts[to]).toFixed(3), bearing, 'LD1', 'A', '2026-12-01T10:00', '', '', '']);
  const { project, flags } = parseProject(p);
  assert.deepEqual(flags, []);
  const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
  assert.equal(out.ok, true, JSON.stringify(out.flags));
  const corners = /** @type {any} */ (out.buildings[0]).corners;
  assert.ok(Math.abs(corners[0].east_m - 90) < 0.01 && Math.abs(corners[0].north_m - 5) < 0.01);
});

// ---- 1.1.0: Codex の指摘（#212）と、支距・斜距離・照合点・輪・経路 ----

const ALL_COLUMNS = [...OBSERVATION_COLUMNS, ...OPTIONAL_OBSERVATION_COLUMNS];

/**
 * 列名で書いた観測の行を CSV にする。
 * @param {Record<string, string|number|undefined>[]} rows
 */
function toCsvNamed(rows) {
  const base = { instrument_id: 'LD1', measurer: 'A', observed_at: '2026-12-01T10:00' };
  return [ALL_COLUMNS.join(','), ...rows.map((r) => ALL_COLUMNS.map((c) => String(/** @type {any} */ ({ ...base, ...r })[c] ?? '')).join(','))].join('\n') + '\n';
}

/** @param {Record<string, number[]>} pts @param {string} a @param {string} b */
const d3 = (pts, a, b) => dist(pts[a], pts[b]).toFixed(3);

test('機材の sigma_m・sigma_per_m は数（文字列でない・有限）でなければ拒否する', () => {
  for (const bad of ['0.03', Number.NaN, Number.POSITIVE_INFINITY]) {
    const p = /** @type {any} */ (projectFixture());
    p.instruments.LD1.sigma_m = bad;
    assert.ok(parseProject(p).flags.some((f) => f.code === 'invalid_instrument'), String(bad));
  }
  const p = /** @type {any} */ (projectFixture());
  p.instruments.LD1.sigma_per_m = '0.001';
  assert.ok(parseProject(p).flags.some((f) => f.code === 'invalid_instrument'));
});

test('仮の点を経由した基準点も出典（reference_point_ids・reference_sources）に入る', () => {
  const p = /** @type {any} */ (projectFixture());
  p.auxiliary_points = ['T1', 'T2'];
  p.buildings = [{ id: 'far', corners: ['f-P1', 'f-P2', 'f-P3', 'f-P4'] }];
  /** @type {Record<string, number[]>} */
  const pts = { ...REFS, T1: [60, 10], T2: [62, 30], 'f-P1': [90, 5], 'f-P2': [110, 5], 'f-P3': [110, 25], 'f-P4': [90, 25] };
  const pairs = [['R2', 'T1'], ['R4', 'T1'], ['R1', 'T1'], ['R4', 'T2'], ['R2', 'T2'], ['T1', 'T2'],
    ['T1', 'f-P1'], ['T2', 'f-P1'], ['T1', 'f-P2'], ['T2', 'f-P2'], ['T1', 'f-P3'], ['T2', 'f-P3'], ['T1', 'f-P4'], ['T2', 'f-P4'],
    ['f-P1', 'f-P2'], ['f-P2', 'f-P3'], ['f-P3', 'f-P4'], ['f-P4', 'f-P1'], ['f-P1', 'f-P3']];
  const rows = pairs.map(([from, to], i) => ({ record_id: `A${i}`, building_id: 'far', point_id: to, from_point: from, distance_m: d3(pts, from, to), bearing_deg: i === 6 ? 99 : '' }));
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsvNamed(rows)).rows);
  assert.equal(out.ok, true, JSON.stringify(out.flags));
  const b = /** @type {any} */ (out.buildings[0]);
  assert.deepEqual(b.reference_point_ids, ['R1', 'R2', 'R4']);
  assert.deepEqual(b.reference_sources, ['gsi_fgd']);
  const csv = provenanceRows(out, project, 'x.csv');
  assert.ok(csv.includes('基準点 R1 R2 R4（gsi_fgd）'));
});

test('照合の許容値: 同じ建物の辺・対角線は ±0.5 m、建物どうしは ±1.0 m', () => {
  const p = /** @type {any} */ (projectFixture());
  p.references[1].building_id = 'old'; // R2 は R1 と同じ建物
  p.references[2].building_id = 'other'; // R3 は別の建物
  const { project } = parseProject(p);
  const rows = observationRows();
  rows.push(['C001', 'old', 'R2', 'R1', (40 + 0.75).toFixed(3), '', 'LD1', 'A', '2026-12-01T09:00', '', '', '']);
  rows.push(['C002', 'old', 'R3', 'R1', (30 + 0.75).toFixed(3), '', 'LD1', 'A', '2026-12-01T09:05', '', '', '']);
  const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
  const c1 = out.reference_checks.find((c) => c.record_id === 'C001');
  const c2 = out.reference_checks.find((c) => c.record_id === 'C002');
  assert.equal(c1?.same_building, true);
  assert.equal(c1?.tolerance_m, 0.5);
  assert.equal(c1?.ok, false);
  assert.equal(c2?.same_building, false);
  assert.equal(c2?.ok, true);
  assert.equal(out.ok, false);
});

test('初期位置: 一直線に近い組で判別できなくても、交わる角のよい組で決まる（Codex の例）', () => {
  /** @type {Record<string, number[]>} */
  const pts = { Ra: [-10, 0], Rb: [10, 0], Rc: [0, 10], 'q-P1': [0, 0.1], 'q-P2': [3, 0.1], 'q-P3': [3, 3], 'q-P4': [0, 3] };
  const p = /** @type {any} */ (projectFixture());
  p.references = ['Ra', 'Rb', 'Rc'].map((id) => {
    const g = enuToWgs84(pts[id][0], pts[id][1], ORIGIN);
    return { id, longitude: g.longitude, latitude: g.latitude, building_id: 'old', source: 'gsi_fgd' };
  });
  p.buildings = [{ id: 'q', corners: ['q-P1', 'q-P2', 'q-P3', 'q-P4'] }];
  /** @type {Record<string, string|number>[]} */
  const rows = [];
  let n = 0;
  for (const c of ['q-P1', 'q-P2', 'q-P3', 'q-P4']) {
    for (const r of ['Ra', 'Rb', 'Rc']) rows.push({ record_id: `Q${(n += 1)}`, point_id: c, from_point: r, distance_m: dist(pts[r], pts[c]).toFixed(4) });
  }
  for (const [a, b] of [['q-P1', 'q-P2'], ['q-P2', 'q-P3'], ['q-P3', 'q-P4'], ['q-P4', 'q-P1'], ['q-P1', 'q-P3']]) {
    rows.push({ record_id: `Q${(n += 1)}`, point_id: b, from_point: a, distance_m: dist(pts[a], pts[b]).toFixed(4) });
  }
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsvNamed(rows)).rows);
  assert.ok(!out.flags.some((f) => f.code === 'initial_position_undetermined'), JSON.stringify(out.flags));
  const c = /** @type {any} */ (out.buildings[0]).corners[0];
  assert.ok(Math.abs(c.north_m - 0.1) < 0.01, JSON.stringify(c));
});

/** 支距のテスト用: 基線 R1→R2（東向き）。点は基線の左（北）側。 */
function chainageCase() {
  const p = /** @type {any} */ (projectFixture());
  p.survey_version = '1.1.0';
  p.instruments.WM1 = { kind: 'measuring_wheel', sigma_m: 0.1, sigma_per_m: 0.01 };
  p.instruments.TP1 = { kind: 'tape_50m', sigma_m: 0.03, sigma_per_m: 0.0005 };
  p.right_angle_sigma_deg = 0.5;
  p.baselines = [{ id: 'BL1', from: 'R1', to: 'R2' }];
  p.points = [{ id: 'campus_n_001', kind: 'node' }, { id: 'nb-E1', kind: 'entrance', building_id: 'nb' }];
  return p;
}

test('支距（基線上の累積距離と垂直距離）と辺から、角と入口とノードの位置を求める', () => {
  const p = chainageCase();
  /** @type {Record<string, number[]>} */
  const pts = { ...REFS, ...TRUE_CORNERS, campus_n_001: [21, 0], 'nb-E1': [21, 8] };
  /** @type {Record<string, string|number>[]} */
  const rows = [];
  let n = 0;
  for (const [c, [e, nn]] of Object.entries(TRUE_CORNERS)) {
    rows.push({ record_id: `S${(n += 1)}`, obs_type: 'chainage_offset', point_id: c, baseline_id: 'BL1', chainage_m: e, offset_m: nn, offset_side: 'L', instrument_id: 'WM1', offset_instrument_id: 'TP1' });
    rows.push({ record_id: `S${(n += 1)}`, point_id: c, from_point: c === 'nb-P1' || c === 'nb-P4' ? 'R1' : 'R2', distance_m: d3(pts, c === 'nb-P1' || c === 'nb-P4' ? 'R1' : 'R2', c) });
  }
  for (const [a, b] of [['nb-P1', 'nb-P2'], ['nb-P2', 'nb-P3'], ['nb-P3', 'nb-P4'], ['nb-P4', 'nb-P1'], ['nb-P1', 'nb-P3']]) {
    rows.push({ record_id: `S${(n += 1)}`, point_id: b, from_point: a, distance_m: d3(pts, a, b), instrument_id: 'TP1' });
  }
  rows.push({ record_id: `S${(n += 1)}`, obs_type: 'chainage_offset', point_id: 'campus_n_001', baseline_id: 'BL1', chainage_m: 21, offset_m: 0, instrument_id: 'WM1', offset_instrument_id: 'TP1' });
  rows.push({ record_id: `S${(n += 1)}`, point_id: 'campus_n_001', from_point: 'R3', distance_m: d3(pts, 'R3', 'campus_n_001') });
  rows.push({ record_id: `S${(n += 1)}`, obs_type: 'chainage_offset', point_id: 'nb-E1', baseline_id: 'BL1', chainage_m: 21, offset_m: 8, offset_side: 'L', instrument_id: 'WM1', offset_instrument_id: 'TP1' });
  rows.push({ record_id: `S${(n += 1)}`, point_id: 'nb-E1', from_point: 'nb-P1', distance_m: d3(pts, 'nb-P1', 'nb-E1'), instrument_id: 'TP1' });
  const { project, flags } = parseProject(p);
  assert.deepEqual(flags, []);
  const parsed = parseObservations(toCsvNamed(rows));
  assert.deepEqual(parsed.flags, []);
  const out = runSurvey(project, parsed.rows);
  assert.equal(out.ok, true, JSON.stringify(out.flags));
  for (const c of /** @type {any} */ (out.buildings[0]).corners) {
    const t = /** @type {Record<string, number[]>} */ (TRUE_CORNERS)[c.id];
    assert.ok(Math.abs(c.east_m - t[0]) < 0.01 && Math.abs(c.north_m - t[1]) < 0.01, c.id);
  }
  const kinds = Object.fromEntries(out.points.map((pt) => [/** @type {any} */ (pt).id, /** @type {any} */ (pt).kind]));
  assert.deepEqual(kinds, { campus_n_001: 'node', 'nb-E1': 'entrance' });
  assert.equal(/** @type {any} */ (out.points_geojson).features.length, 2);
});

test('右（R）と左（L）の支距は基線の反対側に置かれる', () => {
  const p = chainageCase();
  p.points = [{ id: 'X', kind: 'aux' }];
  p.buildings = [];
  const rows = [
    { record_id: 'X1', obs_type: 'chainage_offset', point_id: 'X', baseline_id: 'BL1', chainage_m: 10, offset_m: 5, offset_side: 'R', instrument_id: 'WM1', offset_instrument_id: 'TP1' },
    { record_id: 'X2', point_id: 'X', from_point: 'R3', distance_m: dist([0, 30], [10, -5]).toFixed(3) },
  ];
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsvNamed(rows)).rows);
  const x = /** @type {any} */ (out.points_geojson).features[0];
  const enu = wgs84ToEnu(x.geometry.coordinates[0], x.geometry.coordinates[1], ORIGIN);
  assert.ok(Math.abs(enu.north_m + 5) < 0.05, `右は南: ${enu.north_m}`);
});

test('支距が長すぎると注意を出す（計算は止めない）', () => {
  const p = chainageCase();
  p.points = [{ id: 'X', kind: 'aux' }];
  p.buildings = [];
  const rows = [
    { record_id: 'X1', obs_type: 'chainage_offset', point_id: 'X', baseline_id: 'BL1', chainage_m: 10, offset_m: 20, offset_side: 'L', instrument_id: 'WM1', offset_instrument_id: 'TP1' },
    { record_id: 'X2', point_id: 'X', from_point: 'R3', distance_m: dist([0, 30], [10, 20]).toFixed(3) },
  ];
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsvNamed(rows)).rows);
  const warn = out.flags.find((f) => f.code === 'long_offset');
  assert.equal(warn?.severity, 'warning');
});

test('斜距離は水平距離に直す（傾斜角・高低差のどちらでも）', () => {
  const text = toCsvNamed([
    { record_id: 'L1', point_id: 'a', from_point: 'b', distance_m: 10, slope_deg: 30 },
    { record_id: 'L2', point_id: 'a', from_point: 'b', distance_m: 5, height_diff_m: 3 },
    { record_id: 'L3', point_id: 'a', from_point: 'b', distance_m: 5, height_diff_m: 6 },
  ]);
  const { rows, flags } = parseObservations(text);
  assert.ok(Math.abs(rows[0].distance_m - 10 * Math.cos(Math.PI / 6)) < 1e-9);
  assert.ok(Math.abs(rows[1].distance_m - 4) < 1e-9);
  assert.ok(flags.some((f) => f.code === 'invalid_slope'));
});

test('ウォーキングメジャーの校正（scale_factor）で、測った長さを割って直す', () => {
  const p = /** @type {any} */ (projectFixture());
  p.instruments.LD1.scale_factor = 1.02;
  const rows = observationRows().map((r) => {
    const out = [...r];
    out[4] = (Number(r[4]) * 1.02).toFixed(3);
    return out;
  });
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
  assert.equal(out.ok, true, JSON.stringify(out.flags));
  assert.ok(/** @type {any} */ (out.buildings[0]).max_abs_residual_m < 0.01);
});

test('照合点（調整に入れない基準点）を測れば絶対精度を確かめ、無ければ未確認と書く', () => {
  const out0 = solve();
  assert.equal(out0.accuracy.absolute_check.status, 'unverified');
  assert.equal(/** @type {any} */ (out0.buildings[0]).absolute_accuracy, 'unverified');

  const p = /** @type {any} */ (projectFixture());
  const truth = [20, 40];
  const g = enuToWgs84(truth[0], truth[1], ORIGIN);
  p.check_points = [{ id: 'K1', longitude: g.longitude, latitude: g.latitude, source: 'public_benchmark' }];
  const rows = observationRows();
  rows.push(['K01', '', 'K1', 'R3', dist(REFS.R3, truth).toFixed(3), '', 'LD1', 'A', '2026-12-01T12:00', '', '', '']);
  rows.push(['K02', '', 'K1', 'R4', dist(REFS.R4, truth).toFixed(3), '', 'LD1', 'A', '2026-12-01T12:05', '', '', '']);
  rows.push(['K03', '', 'K1', 'nb-P4', dist(TRUE_CORNERS['nb-P4'], truth).toFixed(3), '', 'LD1', 'A', '2026-12-01T12:10', '', '', '']);
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
  assert.equal(out.accuracy.absolute_check.status, 'checked');
  assert.ok(/** @type {number} */ (out.accuracy.absolute_check.max_difference_m) < 0.01);
});

test('輪（閉合）の食い違いを出し、経路の LineString の長さを出す', () => {
  const p = /** @type {any} */ (projectFixture());
  p.loops = [{ id: 'nb-loop', points: ['nb-P1', 'nb-P2', 'nb-P3', 'nb-P4'] }];
  p.edges = [{ id: 'campus_e_001', points: ['nb-P1', 'nb-P2', 'nb-P3'] }];
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsv(observationRows())).rows);
  const loop = /** @type {any} */ (out.loop_checks[0]);
  assert.equal(loop.legs.length, 4);
  assert.ok(Math.abs(loop.misclosure_m) < 0.01);
  assert.ok(Math.abs(loop.observed_total_m - 60) < 0.01);
  const route = /** @type {any} */ (out.routes_geojson).features[0];
  assert.equal(route.geometry.type, 'LineString');
  assert.equal(route.properties.distance_m, 30);
  assert.equal(route.properties.from_node_id, 'nb-P1');
});

test('輪の一辺を 1 m 読み違えると、食い違いと残差で見つかる', () => {
  const p = /** @type {any} */ (projectFixture());
  p.loops = [{ id: 'nb-loop', points: ['nb-P1', 'nb-P2', 'nb-P3', 'nb-P4'] }];
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsv(observationRows({ T011: 1.0 }))).rows);
  assert.equal(out.ok, false);
  assert.ok(Math.abs(/** @type {any} */ (out.loop_checks[0]).misclosure_m) > 0.1);
});

test('空欄でない傾斜・高低差が数でなければ拒否する（斜距離のまま通さない）', () => {
  const { rows, flags } = parseObservations(toCsvNamed([
    { record_id: 'L1', point_id: 'a', from_point: 'b', distance_m: 10, slope_deg: '30°' },
    { record_id: 'L2', point_id: 'a', from_point: 'b', distance_m: 10, height_diff_m: '3m' },
  ]));
  assert.equal(rows.length, 0);
  assert.deepEqual(flags.map((f) => f.code), ['invalid_slope', 'invalid_slope']);
});

test('輪の照合は、調整に入れない基準点どうしの実測距離も測った区間として使う', () => {
  const p = /** @type {any} */ (projectFixture());
  p.loops = [{ id: 'ref-loop', points: ['R1', 'R2', 'nb-P2', 'nb-P1'] }];
  const rows = observationRows();
  rows.push(['RR1', 'old', 'R2', 'R1', '40.000', '', 'LD1', 'A', '2026-12-01T11:00', '', '', '']);
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
  const loop = /** @type {any} */ (out.loop_checks[0]);
  assert.deepEqual(loop.unobserved_legs, []);
  assert.equal(loop.legs[0].observed_m, 40);
  assert.ok(Math.abs(loop.misclosure_m) < 0.01);
});

test('両端が同じ位置の基線は、向きが決まらないとして拒否する（NaN を出さない）', () => {
  const p = chainageCase();
  const g = enuToWgs84(0, 0, ORIGIN);
  p.references.push({ id: 'R5', longitude: g.longitude, latitude: g.latitude, building_id: 'old', source: 'gsi_fgd' });
  p.baselines = [{ id: 'BL0', from: 'R1', to: 'R5' }];
  p.points = [{ id: 'X', kind: 'aux' }];
  p.buildings = [];
  const rows = [
    { record_id: 'X1', obs_type: 'chainage_offset', point_id: 'X', baseline_id: 'BL0', chainage_m: 10, offset_m: 5, offset_side: 'L', instrument_id: 'WM1', offset_instrument_id: 'TP1' },
    { record_id: 'X2', point_id: 'X', from_point: 'R3', distance_m: dist([0, 30], [10, 5]).toFixed(3) },
  ];
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsvNamed(rows)).rows);
  assert.equal(out.ok, false);
  assert.ok(out.flags.some((f) => f.code === 'degenerate_baseline'), JSON.stringify(out.flags));
});

test('位置の求まらない点（測っていない照合点）を含む辺・輪は、落ちずに測り直しとして知らせる', () => {
  const p = /** @type {any} */ (projectFixture());
  const g = enuToWgs84(20, 40, ORIGIN);
  p.check_points = [{ id: 'K1', longitude: g.longitude, latitude: g.latitude, source: 'public_benchmark' }];
  p.edges = [{ id: 'campus_e_001', points: ['K1', 'nb-P1'] }, { id: 'campus_e_002', points: ['nb-P1', 'nb-P2'] }];
  p.loops = [{ id: 'k-loop', points: ['K1', 'nb-P1', 'nb-P2'] }];
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsv(observationRows())).rows);
  const codes = out.flags.map((f) => f.code);
  assert.ok(codes.includes('route_point_unresolved'), JSON.stringify(out.flags));
  assert.ok(codes.includes('loop_point_unresolved'), JSON.stringify(out.flags));
  assert.equal(out.ok, false);
  assert.deepEqual(/** @type {any} */ (out.routes_geojson).features.map((/** @type {any} */ f) => f.id), ['campus_e_002']);
  assert.equal(out.buildings.length, 1);
});

test('基線の終点までの累積距離は、起点からの距離として初期位置と輪の照合に使う（Codex の例）', () => {
  const p = chainageCase();
  p.points = [{ id: 'X', kind: 'node' }];
  p.buildings = [];
  p.baselines = [{ id: 'BL-X', from: 'R1', to: 'X' }];
  p.loops = [{ id: 'x-loop', points: ['R1', 'X', 'R3'] }];
  const X = [10, 10];
  const rows = [
    { record_id: 'C1', obs_type: 'chainage_offset', point_id: 'X', baseline_id: 'BL-X', chainage_m: dist([0, 0], X).toFixed(3), offset_m: 0, instrument_id: 'WM1', offset_instrument_id: 'TP1' },
    { record_id: 'C2', point_id: 'X', from_point: 'R2', distance_m: dist([40, 0], X).toFixed(3), instrument_id: 'TP1' },
    { record_id: 'C3', point_id: 'X', from_point: 'R3', distance_m: dist([0, 30], X).toFixed(3), instrument_id: 'TP1' },
    { record_id: 'C4', point_id: 'R3', from_point: 'R1', distance_m: '30.000', instrument_id: 'TP1' },
  ];
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsvNamed(rows)).rows);
  assert.ok(!out.flags.some((f) => f.severity === 'error'), JSON.stringify(out.flags));
  const x = /** @type {any} */ (out.points_geojson).features[0];
  const enu = wgs84ToEnu(x.geometry.coordinates[0], x.geometry.coordinates[1], ORIGIN);
  assert.ok(Math.abs(enu.east_m - 10) < 0.05 && Math.abs(enu.north_m - 10) < 0.05, JSON.stringify(enu));
  const loop = /** @type {any} */ (out.loop_checks[0]);
  assert.deepEqual(loop.unobserved_legs, []);
  assert.ok(Math.abs(loop.observed_total_m - (dist([0, 0], X) + dist(X, [0, 30]) + 30)) < 0.01, JSON.stringify(loop));

  const bad = parseObservations(toCsvNamed([{ ...rows[0], offset_m: 2, offset_side: 'L' }, ...rows.slice(1)])).rows;
  assert.ok(runSurvey(project, bad).flags.some((f) => f.code === 'baseline_end_offset'));
});

test('照合点どうしの観測を外したあとも、残った照合点を見直す（登録順によらない）', () => {
  for (const order of [['K1', 'K2', 'K3'], ['K3', 'K2', 'K1']]) {
    const p = /** @type {any} */ (projectFixture());
    p.check_points = order.map((id, i) => {
      const g = enuToWgs84(20 + i, 40, ORIGIN);
      return { id, longitude: g.longitude, latitude: g.latitude, source: 'public_benchmark' };
    });
    const rows = observationRows();
    rows.push(['K01', '', 'K2', 'K1', '1.000', '', 'LD1', 'A', '2026-12-01T12:00', '', '', '']);
    rows.push(['K02', '', 'K3', 'K1', '2.000', '', 'LD1', 'A', '2026-12-01T12:05', '', '', '']);
    const { project } = parseProject(p);
    const out = runSurvey(project, parseObservations(toCsv(rows)).rows);
    assert.equal(out.accuracy.absolute_check.status, 'unverified', JSON.stringify(out.flags));
    assert.equal(out.flags.filter((f) => f.code === 'check_point_underdetermined').length, 3);
  }
});

test('支距の行に傾斜・高低差が書かれていれば、斜距離のまま使わずに拒否する（Codex の例）', () => {
  const base = { record_id: 'S1', obs_type: 'chainage_offset', point_id: 'B01', baseline_id: 'BL1', chainage_m: 50.7713, offset_m: 0, instrument_id: 'WM1' };
  for (const extra of [{ slope_deg: 10 }, { height_diff_m: 8.8 }]) {
    const { rows, flags } = parseObservations(toCsvNamed([{ ...base, ...extra }]));
    assert.equal(rows.length, 0);
    assert.deepEqual(flags.map((f) => f.code), ['slope_on_chainage']);
  }
});

test('2本の距離だけで鏡像を決められない照合点は外し、測量全体は止めない（Codex の例）', () => {
  const p = chainageCase();
  p.points = [{ id: 'X', kind: 'node' }];
  p.buildings = [];
  const g = enuToWgs84(20, 40, ORIGIN);
  p.check_points = [{ id: 'K', longitude: g.longitude, latitude: g.latitude, source: 'public_benchmark' }];
  const X = [10, 10];
  const K = [20, 40];
  const rows = [
    { record_id: 'D1', point_id: 'X', from_point: 'R1', distance_m: dist([0, 0], X).toFixed(3), instrument_id: 'TP1' },
    { record_id: 'D2', point_id: 'X', from_point: 'R2', distance_m: dist([40, 0], X).toFixed(3), instrument_id: 'TP1' },
    { record_id: 'D3', point_id: 'X', from_point: 'R3', distance_m: dist([0, 30], X).toFixed(3), instrument_id: 'TP1' },
    { record_id: 'K1', point_id: 'K', from_point: 'R1', distance_m: dist([0, 0], K).toFixed(3), instrument_id: 'TP1' },
    { record_id: 'K2', point_id: 'K', from_point: 'R2', distance_m: dist([40, 0], K).toFixed(3), instrument_id: 'TP1' },
  ];
  const { project } = parseProject(p);
  const out = runSurvey(project, parseObservations(toCsvNamed(rows)).rows);
  assert.ok(!out.flags.some((f) => f.severity === 'error'), JSON.stringify(out.flags));
  assert.ok(out.flags.some((f) => f.code === 'check_point_underdetermined'));
  assert.equal(out.accuracy.absolute_check.status, 'unverified');
  assert.deepEqual(out.points.map((pt) => /** @type {any} */ (pt).id), ['X']);
});

test('ひな形（測量設定・野帳 CSV）と出典の記録の列が、ツールの契約と合っている', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
  const template = JSON.parse(readFileSync(path.join(root, 'map-data/survey/templates/survey-project.template.json'), 'utf8'));
  assert.deepEqual(parseProject(template).flags, []);
  const header = readFileSync(path.join(root, 'map-data/survey/templates/field-sheet.csv'), 'utf8').trim().split(',');
  for (const c of [...OBSERVATION_COLUMNS, ...OPTIONAL_OBSERVATION_COLUMNS]) assert.ok(header.includes(c), c);
  const prov = readFileSync(path.join(root, 'map-data/normalized/building-provenance.csv'), 'utf8').split('\n')[0].split(',');
  assert.deepEqual(prov, [...PROVENANCE_COLUMNS]);
});
