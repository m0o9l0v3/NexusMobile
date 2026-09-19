import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

import { buildDataset } from '../src/build.mjs';
import { loadConfig } from '../src/config.mjs';
import { collectPositions, isRounded, signedArea } from '../src/geometry.mjs';
import { sha256 } from '../src/report.mjs';
import { stringifyDeterministic } from '../src/serialize.mjs';
import { validateDataset } from '../src/validate.mjs';
import { FIXTURES_DIR, REPO_EXAMPLE_PATH, REPO_SCHEMA_PATH, makeWorkspace, runCli } from './helpers.mjs';

const CONFIG_PATH = path.join(FIXTURES_DIR, 'campus.config.json');

function build() {
  return buildDataset(loadConfig({ configPath: CONFIG_PATH, inputRoot: FIXTURES_DIR }));
}

test('GeoJSON 原本と Excel レジストリから正しい FeatureCollection を生成する', () => {
  const result = build();
  assert.ok(result.findings.ok, result.findings.errors.map((f) => f.message).join('\n'));
  const dataset = /** @type {any} */ (result.dataset);
  assert.equal(dataset.type, 'FeatureCollection');
  assert.equal(dataset.nexus.schema_version, '1.0.0');
  assert.deepEqual(dataset.nexus.floors, [{ id: 'mb_1f', building_id: 'mb', name: '1F' }]);
  assert.deepEqual(
    dataset.features.map((/** @type {any} */ feature) => feature.id),
    ['campus_e_001', 'campus_n_001', 'campus_n_002', 'mb', 'mb_1f_e_001', 'mb_1f_n_001', 'mb_1f_n_002', 'mb_ent_001'],
    'canonical ID のコードポイント順に安定ソートされる',
  );
  assert.deepEqual(result.counts, { source_records: 9, included: 8, excluded: 1, failed: 0 });
});

test('生成物が既存 JSON Schema に適合する', () => {
  const result = build();
  const findings = validateDataset(result.dataset, { schemaPath: REPO_SCHEMA_PATH });
  assert.ok(findings.ok, findings.errors.map((f) => f.message).join('\n'));
});

test('canonical ID は Feature 直下の id だけに置き、properties.id は出力しない', () => {
  const dataset = /** @type {any} */ (build().dataset);
  for (const feature of dataset.features) {
    assert.equal(typeof feature.id, 'string');
    assert.ok(!Object.prototype.hasOwnProperty.call(feature.properties, 'id'));
  }
  const building = dataset.features.find((/** @type {any} */ f) => f.id === 'mb');
  assert.equal(building.properties.feature_type, 'building');
  assert.equal(building.properties.name, '教室棟');
});

test('原本の未知プロパティ・表示用スタイル属性を MapDataset へ持ち込まない', () => {
  const result = build();
  const dataset = /** @type {any} */ (result.dataset);
  const building = dataset.features.find((/** @type {any} */ f) => f.id === 'mb');
  assert.deepEqual(Object.keys(building.properties), ['feature_type', 'name']);

  const traced = result.trace.find((entry) => entry.canonical_id === 'mb');
  assert.ok(traced);
  assert.deepEqual(traced.dropped_properties, ['fill', 'id', 'legacy_code', 'name', 'stroke-width']);
});

test('座標は2次元かつ小数6桁で、Polygon の環は閉じて向きが正規化される', () => {
  const dataset = /** @type {any} */ (build().dataset);
  for (const feature of dataset.features) {
    for (const position of collectPositions(feature.geometry)) {
      assert.equal(position.length, 2);
      assert.ok(isRounded(position[0]) && isRounded(position[1]));
    }
  }
  const building = dataset.features.find((/** @type {any} */ f) => f.id === 'mb');
  const rings = building.geometry.coordinates;
  assert.equal(rings.length, 2);
  for (const ring of rings) {
    assert.deepEqual(ring[0], ring[ring.length - 1]);
  }
  assert.ok(signedArea(rings[0]) > 0, '外環は反時計回り');
  assert.ok(signedArea(rings[1]) < 0, '内環は時計回り');
});

test('floor-local 座標が相似変換で WGS 84 へ変換され、経路端点がノード座標と一致する', () => {
  const result = build();
  assert.equal(result.transforms.length, 1);
  assert.equal(result.transforms[0].status, 'ok');

  const dataset = /** @type {any} */ (result.dataset);
  /** @param {string} id */
  const find = (id) => dataset.features.find((/** @type {any} */ f) => f.id === id);
  const edge = find('mb_1f_e_001');
  assert.deepEqual(edge.geometry.coordinates[0], find('mb_1f_n_001').geometry.coordinates);
  assert.deepEqual(edge.geometry.coordinates[1], find('mb_1f_n_002').geometry.coordinates);

  const traced = result.trace.find((entry) => entry.canonical_id === 'mb_1f_n_001');
  assert.ok(traced?.notes.some((note) => note.includes('相似変換')));
});

test('除外した地物は理由付きで検証レポートへ残る', () => {
  const result = build();
  const excluded = result.trace.filter((entry) => entry.result === 'excluded');
  assert.equal(excluded.length, 1);
  assert.equal(excluded[0].reason_code, 'out_of_scope_feature_type');
  assert.equal(excluded[0].source.feature_index, 4);
  assert.equal(excluded[0].source.source_property_id, 'pk_visitor01');
});

test('同じ入力・設定から2回生成した出力はバイト列も SHA-256 も一致する', () => {
  const first = stringifyDeterministic(/** @type {any} */ (build().dataset));
  const second = stringifyDeterministic(/** @type {any} */ (build().dataset));
  assert.equal(first, second);
  assert.equal(sha256(first), sha256(second));
  assert.ok(first.endsWith('}\n'), '末尾に改行1つ');
  assert.ok(!first.includes('\r'), 'LF のみ');
});

test('CLI generate が出力と検証レポートを書き、決定的生成を確認できる', async () => {
  const dir = makeWorkspace({});
  const outPath = path.join(dir, 'out.geojson');
  const reportPath = path.join(dir, 'report.json');
  const { code, stdout } = await runCli([
    'generate',
    '--config',
    CONFIG_PATH,
    '--input-root',
    FIXTURES_DIR,
    '--out',
    outPath,
    '--report',
    reportPath,
    '--schema',
    REPO_SCHEMA_PATH,
    '--check-determinism',
  ]);
  assert.equal(code, 0, stdout);
  assert.ok(existsSync(outPath));

  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  assert.equal(report.status, 'ok');
  assert.equal(report.deterministic_generation_checked, true);
  assert.equal(report.output.sha256, sha256(readFileSync(outPath, 'utf8')));
  assert.equal(report.trace.length, 9);
  assert.equal(report.transforms[0].status, 'ok');
  // レポートは実行時刻や絶対パスを含めないので、経路が違っても内容が安定する。
  assert.equal(report.output.file, 'out.geojson');
  assert.ok(report.inputs.every((/** @type {any} */ input) => !path.isAbsolute(input.path)));
});

test('CLI validate が生成物を再検証できる', async () => {
  const dir = makeWorkspace({});
  const outPath = path.join(dir, 'out.geojson');
  await runCli([
    'generate',
    '--config',
    CONFIG_PATH,
    '--input-root',
    FIXTURES_DIR,
    '--out',
    outPath,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  const { code } = await runCli(['validate', '--input', outPath, '--schema', REPO_SCHEMA_PATH]);
  assert.equal(code, 0);
});

test('CLI が help を表示する', async () => {
  const { code, stdout } = await runCli(['--help']);
  assert.equal(code, 0);
  assert.ok(stdout.includes('generate'));
  assert.ok(stdout.includes('validate'));
});

test('リポジトリ同梱の example が既存スキーマで検証できる', () => {
  const example = JSON.parse(readFileSync(REPO_EXAMPLE_PATH, 'utf8'));
  const findings = validateDataset(example, { schemaPath: REPO_SCHEMA_PATH });
  assert.ok(findings.ok, findings.errors.map((f) => f.message).join('\n'));
});
