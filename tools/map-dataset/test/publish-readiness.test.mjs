/**
 * publish_readiness の既定動作。
 *
 * Issue #15 の「未確認値を推定せず検出」を満たすため、未解消の blocker が残る状態は
 * 既定で失敗させる。暫定出力は --allow-draft を明示したときだけ許可する。
 */

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

import { REPO_SCHEMA_PATH, makeWorkspace, minimalCase, runCli } from './helpers.mjs';

/**
 * blocker を宣言した最小ワークスペースを作る。
 * @param {{withBlockers: boolean}} options
 */
function workspace(options) {
  const { source, config } = minimalCase();
  if (options.withBlockers) {
    config.publish_readiness = {
      blockers: [
        { code: 'building_geometry_unmeasured', description: '建物外形が未実測。', owner: '#16' },
        { code: 'indoor_anchors_missing', description: '実アンカーが未登録。', owner: '#36' },
      ],
    };
  }
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config });
  return { dir, configPath: path.join(dir, 'config.json'), outPath: path.join(dir, 'out.geojson'), reportPath: path.join(dir, 'report.json') };
}

/**
 * @param {{dir: string, configPath: string, outPath: string, reportPath: string}} ws
 * @param {string[]} extra
 */
function argv(ws, extra = []) {
  return [
    'generate',
    '--config',
    ws.configPath,
    '--input-root',
    ws.dir,
    '--out',
    ws.outPath,
    '--report',
    ws.reportPath,
    '--schema',
    REPO_SCHEMA_PATH,
    ...extra,
  ];
}

test('blocker が残る状態は既定で失敗し、出力を書き出さない', async () => {
  const ws = workspace({ withBlockers: true });
  const { code, stderr } = await runCli(argv(ws));
  assert.equal(code, 1);
  assert.equal(existsSync(ws.outPath), false, '完成品として出力しない');
  assert.match(stderr, /未解消の publish blocker が 2 件/);
  assert.match(stderr, /--allow-draft/);

  const report = JSON.parse(readFileSync(ws.reportPath, 'utf8'));
  assert.equal(report.status, 'failed');
  assert.equal(report.publish_readiness.ready, false);
  assert.equal(report.draft_accepted, false);
  assert.deepEqual(
    report.errors.map((/** @type {any} */ e) => e.code),
    ['publish_readiness_blocked', 'publish_readiness_blocked'],
  );
});

test('--allow-draft を付けたときだけ暫定出力を許可し、ready は false のまま', async () => {
  const ws = workspace({ withBlockers: true });
  const { code, stdout } = await runCli(argv(ws, ['--allow-draft']));
  assert.equal(code, 0);
  assert.ok(existsSync(ws.outPath));
  assert.match(stdout, /DRAFT: --allow-draft により blocker 2 件を残したまま暫定出力した/);
  assert.match(stdout, /publish_readiness: blocked/);

  const report = JSON.parse(readFileSync(ws.reportPath, 'utf8'));
  assert.equal(report.draft_accepted, true, '暫定出力であることをレポートに残す');
  assert.equal(report.publish_readiness.ready, false, 'blocker がある限り ready にしない');
  assert.equal(report.errors.length, 0);
  assert.deepEqual(
    report.warnings.map((/** @type {any} */ w) => w.code),
    ['publish_readiness_blocked', 'publish_readiness_blocked'],
  );
});

test('blocker が無ければ既定で成功し、draft 扱いにならない', async () => {
  const ws = workspace({ withBlockers: false });
  const { code } = await runCli(argv(ws));
  assert.equal(code, 0);
  const report = JSON.parse(readFileSync(ws.reportPath, 'utf8'));
  assert.equal(report.publish_readiness.ready, true);
  assert.equal(report.draft_accepted, false);
});

test('--allow-draft は検証エラーまでは見逃さない', async () => {
  const { source, config } = minimalCase();
  // 契約違反（3次元座標）を1点だけ混ぜる。
  source.features[0].geometry.coordinates = [
    [
      [141.62, 42.78, 0],
      [141.621, 42.78, 0],
      [141.621, 42.781, 0],
      [141.62, 42.781, 0],
      [141.62, 42.78, 0],
    ],
  ];
  config.publish_readiness = { blockers: [{ code: 'x', description: 'y' }] };
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config });
  const outPath = path.join(dir, 'out.geojson');
  const { code } = await runCli([
    'generate',
    '--config',
    path.join(dir, 'config.json'),
    '--input-root',
    dir,
    '--out',
    outPath,
    '--schema',
    REPO_SCHEMA_PATH,
    '--allow-draft',
  ]);
  assert.equal(code, 1, '契約違反は --allow-draft でも通さない');
  assert.equal(existsSync(outPath), false);
});
