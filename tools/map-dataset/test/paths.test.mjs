/**
 * 入出力パスの衝突検出。
 *
 * 「原本は絶対に変更しない」という契約を CLI 引数のレベルで守れることを確認する。
 * 文字列比較だけでは symlink とハードリンクを取りこぼすため、その2経路も試す。
 */

import assert from 'node:assert/strict';
import { existsSync, linkSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

import { findPathCollisions, identifyPath, isSamePath } from '../src/paths.mjs';
import { FIXTURES_DIR, REPO_SCHEMA_PATH, makeWorkspace, minimalCase, runCli } from './helpers.mjs';

test('同じファイルを別表記で指しても同一と判定する', () => {
  const dir = makeWorkspace({ 'a.json': { a: 1 } });
  const direct = identifyPath(path.join(dir, 'a.json'));
  const viaDot = identifyPath(path.join(dir, '.', 'a.json'));
  const viaParent = identifyPath(path.join(dir, 'sub', '..', 'a.json'));
  assert.ok(isSamePath(direct, viaDot));
  assert.ok(isSamePath(direct, viaParent));
});

test('symlink 経由の指定を同一と判定する', () => {
  const dir = makeWorkspace({ 'source.geojson': { type: 'FeatureCollection', features: [] } });
  const target = path.join(dir, 'source.geojson');
  const link = path.join(dir, 'link.geojson');
  symlinkSync(target, link);
  assert.ok(isSamePath(identifyPath(target), identifyPath(link)));
});

test('ハードリンク経由の指定を同一と判定する', () => {
  const dir = makeWorkspace({ 'source.geojson': { type: 'FeatureCollection', features: [] } });
  const target = path.join(dir, 'source.geojson');
  const hard = path.join(dir, 'hard.geojson');
  linkSync(target, hard);
  const a = identifyPath(target);
  const b = identifyPath(hard);
  assert.notEqual(a.real, b.real, 'パス文字列は異なる');
  assert.ok(isSamePath(a, b), 'inode で同一と判定できる');
});

test('無関係なパスは衝突しない', () => {
  const dir = makeWorkspace({ 'a.json': { a: 1 } });
  const collisions = findPathCollisions(
    [{ label: '--out', path: path.join(dir, 'out.geojson') }],
    [{ label: '原本', path: path.join(dir, 'a.json') }],
  );
  assert.deepEqual(collisions, []);
});

test('出力先どうしの衝突も検出する', () => {
  const dir = makeWorkspace({});
  const collisions = findPathCollisions(
    [
      { label: '--out', path: path.join(dir, 'same.json') },
      { label: '--report', path: path.join(dir, 'same.json') },
    ],
    [],
  );
  assert.equal(collisions.length, 1);
  assert.match(collisions[0], /--out.*--report/s);
});

/**
 * 最小の正常系ワークスペースを作る。
 * @returns {{dir: string, configPath: string, sourcePath: string}}
 */
function workspace() {
  const { source, config } = minimalCase();
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config });
  return { dir, configPath: path.join(dir, 'config.json'), sourcePath: path.join(dir, 'source.geojson') };
}

test('generate: --out に原本を指定したら実行前に止まり、原本を上書きしない', async () => {
  const { dir, configPath, sourcePath } = workspace();
  const before = readFileSync(sourcePath, 'utf8');
  const { code, stderr } = await runCli([
    'generate',
    '--config',
    configPath,
    '--input-root',
    dir,
    '--out',
    sourcePath,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  assert.equal(code, 2, stderr);
  assert.match(stderr, /出力先が入力と衝突している/);
  assert.equal(readFileSync(sourcePath, 'utf8'), before, '原本が変更されていない');
});

test('generate: --out に symlink 経由で原本を指定しても止まる', async () => {
  const { dir, configPath, sourcePath } = workspace();
  const before = readFileSync(sourcePath, 'utf8');
  const link = path.join(dir, 'alias.geojson');
  symlinkSync(sourcePath, link);
  const { code, stderr } = await runCli([
    'generate',
    '--config',
    configPath,
    '--input-root',
    dir,
    '--out',
    link,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  assert.equal(code, 2, stderr);
  assert.equal(readFileSync(sourcePath, 'utf8'), before);
});

test('generate: --report に対応設定を指定したら止まる', async () => {
  const { dir, configPath, sourcePath } = workspace();
  const before = readFileSync(configPath, 'utf8');
  const { code, stderr } = await runCli([
    'generate',
    '--config',
    configPath,
    '--input-root',
    dir,
    '--out',
    path.join(dir, 'out.geojson'),
    '--report',
    configPath,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  assert.equal(code, 2, stderr);
  assert.equal(readFileSync(configPath, 'utf8'), before, '対応設定が変更されていない');
  assert.equal(existsSync(path.join(dir, 'out.geojson')), false);
  assert.ok(sourcePath);
});

test('generate: --out と --report が同じでも止まる', async () => {
  const { dir, configPath } = workspace();
  const same = path.join(dir, 'same.json');
  const { code, stderr } = await runCli([
    'generate',
    '--config',
    configPath,
    '--input-root',
    dir,
    '--out',
    same,
    '--report',
    same,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  assert.equal(code, 2, stderr);
  assert.equal(existsSync(same), false);
});

test('generate: --out にスキーマを指定したら止まる', async () => {
  const { dir, configPath } = workspace();
  const before = readFileSync(REPO_SCHEMA_PATH, 'utf8');
  const { code } = await runCli([
    'generate',
    '--config',
    configPath,
    '--input-root',
    dir,
    '--out',
    REPO_SCHEMA_PATH,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  assert.equal(code, 2);
  assert.equal(readFileSync(REPO_SCHEMA_PATH, 'utf8'), before, 'スキーマが変更されていない');
});

test('generate: Excel 原本を --out に指定しても止まる', async () => {
  const { source, config } = minimalCase();
  config.sources.registry = {
    kind: 'excel',
    path: 'id-master.xlsx',
    sheet: '登録',
    header_row: 1,
    columns: { category: '区分', source_id: 'コード', display_name: '名称' },
    row_filter: { column: 'category', equals: '建物' },
  };
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config });
  const workbook = path.join(FIXTURES_DIR, 'id-master.xlsx');
  const before = readFileSync(workbook);
  const { code, stderr } = await runCli([
    'generate',
    '--config',
    path.join(dir, 'config.json'),
    '--input-root',
    FIXTURES_DIR,
    '--out',
    workbook,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  assert.equal(code, 2, stderr);
  assert.deepEqual(readFileSync(workbook), before, 'Excel 原本が変更されていない');
});

test('validate: --report に検証対象を指定したら止まり、対象を上書きしない', async () => {
  const dir = makeWorkspace({});
  const datasetPath = path.join(dir, 'dataset.geojson');
  writeFileSync(
    datasetPath,
    `${JSON.stringify({ type: 'FeatureCollection', nexus: { schema_version: '1.0.0', floors: [] }, features: [] }, null, 2)}\n`,
    'utf8',
  );
  const before = readFileSync(datasetPath, 'utf8');
  const { code, stderr } = await runCli([
    'validate',
    '--input',
    datasetPath,
    '--report',
    datasetPath,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  assert.equal(code, 2, stderr);
  assert.match(stderr, /出力先が入力と衝突している/);
  assert.equal(readFileSync(datasetPath, 'utf8'), before, '検証対象が変更されていない');
});
