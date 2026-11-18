/**
 * 現地測量 → 建物 Polygon（survey）のテスト。
 *
 * 実測の値は使わない。局所ENU上に正解の形を置き、そこから距離を合成して
 * 「正解に戻るか」「測り違いを見つけるか」を確かめる。
 */

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

import { adjust, circleIntersections, initialPositions } from '../src/survey/adjust.mjs';
import { parseObservations, parseProject, provenanceRows, runSurvey, OBSERVATION_COLUMNS } from '../src/survey/survey.mjs';
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
  const base = { sigma_m: 0.03, bearing_true_deg: null };
  const obs = [
    { ...base, record_id: '1', from: 'A', to: 'X', distance_m: Math.hypot(5, 4) },
    { ...base, record_id: '2', from: 'B', to: 'X', distance_m: Math.hypot(5, 4) },
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
