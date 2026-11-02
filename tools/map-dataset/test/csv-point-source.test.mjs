/**
 * csv_points ソース：正規化済み CSV の経度・緯度から Point を作る。
 */

import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { parseCsv } from '../src/sources/csv-point-source.mjs';
import { REPO_SCHEMA_PATH, buildInDir, errorCodes, makeWorkspace, minimalCase, runCli } from './helpers.mjs';

const HEADER = 'canonical_id,photo_longitude,photo_latitude,status,notes';

/**
 * 建物1件の最小構成に、CSV のランドマークを1件足した設定を作る。
 * @param {string} csv
 * @param {Record<string, unknown>} [sourceOverrides]
 */
function landmarkCase(csv, sourceOverrides = {}) {
  const { source, config } = minimalCase();
  config.sources.points = {
    kind: 'csv_points',
    path: 'points.csv',
    id_column: 'canonical_id',
    longitude_column: 'photo_longitude',
    latitude_column: 'photo_latitude',
    row_filter: { column: 'status', equals: 'adopted_photo' },
    ...sourceOverrides,
  };
  config.features.push({
    source: 'points',
    source_id: 'campus_lm_001',
    decision: 'include',
    feature_type: 'landmark',
    canonical_id: 'campus_lm_001',
    properties: { scope: 'campus' },
  });
  return { source, config, csv };
}

test('parseCsv: 引用符・エスケープ・CRLF・BOM を扱う', () => {
  assert.deepEqual(parseCsv('﻿a,b\r\n"x,1","say ""hi"""\r\n'), [
    ['a', 'b'],
    ['x,1', 'say "hi"'],
  ]);
  assert.deepEqual(parseCsv('a\n\n'), [['a']]);
});

test('csv_points: 採用行の経度・緯度をそのまま Point にし、絞り込みで外れた行は対応設定に求めない', async () => {
  const { source, config, csv } = landmarkCase(
    `${HEADER}\ncampus_lm_001,141.62205500,42.78600333,adopted_photo,"写真位置、採用"\ncampus_lm_002,141.6,42.7,needs_review,\n`,
  );
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config, 'points.csv': csv });
  const outPath = path.join(dir, 'out.geojson');
  const reportPath = path.join(dir, 'report.json');
  const result = await runCli([
    'generate', '--config', path.join(dir, 'config.json'), '--input-root', dir,
    '--out', outPath, '--report', reportPath, '--schema', REPO_SCHEMA_PATH,
  ]);
  assert.equal(result.code, 0, result.stderr);
  const dataset = JSON.parse(readFileSync(outPath, 'utf8'));
  const landmark = dataset.features.find((/** @type {any} */ feature) => feature.id === 'campus_lm_001');
  // 座標は他の原本と同じく小数第6位に丸めて出力する（geometry.mjs）。
  assert.deepEqual(landmark.geometry, { type: 'Point', coordinates: [141.622055, 42.786003] });
  assert.deepEqual(landmark.properties, { feature_type: 'landmark', scope: 'campus' });
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  const input = report.inputs.find((/** @type {any} */ item) => item.key === 'points');
  assert.match(input.sha256, /^[0-9a-f]{64}$/);
});

test('csv_points: relative_to=config は対応設定のフォルダを基準に読む（--input-root の外の正規化CSV）', async () => {
  const { source, config, csv } = landmarkCase(`${HEADER}\ncampus_lm_001,141.622,42.786,adopted_photo,\n`, {
    path: '../normalized/points.csv',
    relative_to: 'config',
  });
  const root = makeWorkspace({});
  const inputRoot = path.join(root, 'originals');
  const configDir = path.join(root, 'config');
  for (const dir of [inputRoot, configDir, path.join(root, 'normalized')]) mkdirSync(dir);
  writeFileSync(path.join(inputRoot, 'source.geojson'), JSON.stringify(source));
  writeFileSync(path.join(configDir, 'config.json'), JSON.stringify(config));
  writeFileSync(path.join(root, 'normalized', 'points.csv'), csv);

  const { loadConfig } = await import('../src/config.mjs');
  const { buildDataset } = await import('../src/build.mjs');
  const built = buildDataset(loadConfig({ configPath: path.join(configDir, 'config.json'), inputRoot }));
  assert.deepEqual(errorCodes(built.findings), []);
  assert.ok(built.dataset);
});

test('csv_points: 経度・緯度が数値として読めない行は推定せず失敗にする', async () => {
  const { source, config, csv } = landmarkCase(`${HEADER}\ncampus_lm_001,,42.786,adopted_photo,\n`);
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config, 'points.csv': csv });
  const built = await buildInDir(dir);
  assert.ok(errorCodes(built.findings).includes('invalid_coordinate'));
});

test('csv_points: 指定した列が CSV に無ければ失敗にする', async () => {
  const { source, config, csv } = landmarkCase(`${HEADER}\ncampus_lm_001,141.622,42.786,adopted_photo,\n`, {
    latitude_column: 'lat',
  });
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config, 'points.csv': csv });
  const built = await buildInDir(dir);
  assert.ok(errorCodes(built.findings).includes('missing_csv_column'));
});

test('実データの対応設定：航空神社 campus_lm_001 は正規化CSVの写真の撮影位置から作る', async () => {
  const { loadConfig } = await import('../src/config.mjs');
  const { readCsvPointSource } = await import('../src/sources/csv-point-source.mjs');
  const { Findings } = await import('../src/findings.mjs');
  const configPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../config/campus-buildings.config.json');
  // 原本はリポジトリ外にあるため、--input-root はダミーでよい（正規化CSVは対応設定のフォルダ基準で読む）。
  const loaded = loadConfig({ configPath, inputRoot: makeWorkspace({}) });
  const spec = loaded.config.sources.landmark_coordinates;
  assert.equal(spec.kind, 'csv_points');
  const findings = new Findings();
  const records = readCsvPointSource(/** @type {any} */ (spec), loaded.resolveSource(/** @type {any} */ (spec)), findings);
  assert.deepEqual(errorCodes(findings), []);
  assert.deepEqual(
    records.map((record) => [record.source_id, record.geometry.coordinates]),
    [['campus_lm_001', [141.622055, 42.78600333]]],
  );
  const entry = loaded.config.features.find((feature) => feature.canonical_id === 'campus_lm_001');
  assert.equal(entry?.source, 'landmark_coordinates');
  assert.equal(entry?.decision, 'include');
});
