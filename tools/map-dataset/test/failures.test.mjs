/**
 * 異常系。契約を1点だけ壊した最小合成データで、黙って通さないことを確認する。
 */

import assert from 'node:assert/strict';
import { copyFileSync, existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

import { ConfigError, loadConfig } from '../src/config.mjs';
import { FIXTURES_DIR, REPO_SCHEMA_PATH, makeWorkspace, minimalCase, runCli } from './helpers.mjs';

/**
 * 一時ワークスペースを用意して generate を実行する。
 * @param {(base: {source: any, config: any}) => {source: any, config: any}} mutate
 * @param {{copyWorkbook?: boolean}} [options]
 */
async function generate(mutate, options = {}) {
  const { source, config } = mutate(minimalCase());
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config });
  if (options.copyWorkbook === true) {
    copyFileSync(path.join(FIXTURES_DIR, 'id-master.xlsx'), path.join(dir, 'id-master.xlsx'));
  }
  const outPath = path.join(dir, 'out.geojson');
  const reportPath = path.join(dir, 'report.json');
  const result = await runCli([
    'generate',
    '--config',
    path.join(dir, 'config.json'),
    '--input-root',
    dir,
    '--out',
    outPath,
    '--report',
    reportPath,
    '--schema',
    REPO_SCHEMA_PATH,
  ]);
  const report = existsSync(reportPath) ? JSON.parse(readFileSync(reportPath, 'utf8')) : null;
  return { ...result, outPath, outputWritten: existsSync(outPath), report };
}

/**
 * @param {{report: any}} result
 */
function codes(result) {
  return (result.report?.errors ?? []).map((/** @type {any} */ error) => error.code);
}

test('正常系の最小ケースは成功する（比較の基準）', async () => {
  const result = await generate((base) => base);
  assert.equal(result.code, 0, result.stderr);
  assert.ok(result.outputWritten);
  assert.equal(result.report.status, 'ok');
});

test('対応設定にない原本地物を黙って除外しない', async () => {
  const result = await generate((base) => {
    base.source.features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [141.6205, 42.7805] },
      properties: { id: 'lm_statue', name: '記念碑' },
    });
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('unmapped_source_feature'));
  assert.equal(result.outputWritten, false, '不完全な入力で出力を書き出さない');
  const traced = result.report.trace.find((/** @type {any} */ entry) => entry.source.feature_index === 1);
  assert.equal(traced.result, 'failed');
});

test('対応設定が指す地物が原本にない場合は失敗する', async () => {
  const result = await generate((base) => {
    base.config.features[0].source_id = 'ptb';
    base.config.features[0].canonical_id = 'ptb';
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('missing_source_feature'));
});

test('Feature id と properties.id が不一致なら canonical ID へ移行しない', async () => {
  const result = await generate((base) => {
    base.source.features[0].id = '0064FF8DD040AF6BCD40';
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('feature_id_conflict'));
  assert.equal(result.outputWritten, false);
});

test('ID不一致は対応設定で明示解決したときだけ許可する', async () => {
  const result = await generate((base) => {
    base.source.features[0].id = '0064FF8DD040AF6BCD40';
    base.config.features[0].resolve_id_conflict = {
      use: 'property_id',
      reason: 'KML由来の内部IDであり canonical ID ではない。',
    };
    return base;
  });
  assert.equal(result.code, 0, result.stderr);
  const traced = result.report.trace.find((/** @type {any} */ entry) => entry.canonical_id === 'mb');
  assert.ok(traced.notes.some((/** @type {string} */ note) => note.includes('resolve_id_conflict')));
  assert.equal(traced.source.source_feature_id, '0064FF8DD040AF6BCD40');
  assert.equal(traced.source.source_property_id, 'mb');
});

test('canonical ID の重複を拒否する', async () => {
  const result = await generate((base) => {
    base.source.features.push({
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [
          [
            [141.63, 42.79],
            [141.631, 42.79],
            [141.631, 42.791],
            [141.63, 42.791],
            [141.63, 42.79],
          ],
        ],
      },
      properties: { id: 'mb_duplicate', name: '教室棟' },
    });
    base.config.features.push({
      source: 'src',
      source_id: 'mb_duplicate',
      decision: 'include',
      feature_type: 'building',
      canonical_id: 'mb',
      name: { policy: 'from_source' },
    });
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('duplicate_canonical_id'));
});

test('Feature 種別に存在しないプロパティを設定したら拒否する', async () => {
  const result = await generate((base) => {
    base.config.features[0].properties = { scope: 'campus' };
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('unknown_configured_property'));
});

test('3次元座標を拒否する', async () => {
  const result = await generate((base) => {
    base.source.features[0].geometry.coordinates = [
      [
        [141.62, 42.78, 0],
        [141.621, 42.78, 0],
        [141.621, 42.781, 0],
        [141.62, 42.781, 0],
        [141.62, 42.78, 0],
      ],
    ];
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('three_dimensional_position'));
});

test('経緯度が逆転した座標を拒否する', async () => {
  const result = await generate((base) => {
    base.source.features[0].geometry.coordinates = [
      [
        [42.78, 141.62],
        [42.78, 141.621],
        [42.781, 141.621],
        [42.781, 141.62],
        [42.78, 141.62],
      ],
    ];
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('latitude_out_of_range'));
});

test('未知の canonical ID はスキーマ検証で拒否される', async () => {
  const result = await generate((base) => {
    base.config.features[0].canonical_id = 'unknown_building';
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('schema_violation'));
});

test('表示名が原本間で食い違うときは推定採用しない', async () => {
  const result = await generate((base) => {
    base.source.features[0].properties.name = '本棟';
    base.config.sources.registry = {
      kind: 'excel',
      path: 'id-master.xlsx',
      sheet: '登録',
      header_row: 1,
      columns: { category: '区分', source_id: 'コード', display_name: '名称' },
      row_filter: { column: 'category', equals: '建物' },
    };
    base.config.building_registry = { source: 'registry', id_column: 'source_id', name_column: 'display_name' };
    base.config.features[0].name = { policy: 'require_agreement' };
    return base;
  }, { copyWorkbook: true });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('display_name_conflict'));
  assert.equal(result.outputWritten, false);
});

test('未定義の floor / building 参照を拒否する', async () => {
  const result = await generate((base) => {
    base.source.features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [141.6205, 42.7805] },
      properties: { id: 'node_a' },
    });
    base.config.features.push({
      source: 'src',
      source_id: 'node_a',
      decision: 'include',
      feature_type: 'indoor_node',
      canonical_id: 'ptb_1f_n_001',
      properties: { building_id: 'ptb', floor_id: 'ptb_1f', node_kind: 'junction' },
    });
    return base;
  });
  assert.equal(result.code, 1);
  const found = codes(result).filter((/** @type {string} */ code) => code === 'undefined_reference');
  assert.equal(found.length, 2, 'building_id と floor_id の両方が未定義として報告される');
});

test('予約済み識別子との衝突を拒否する', async () => {
  const result = await generate((base) => {
    base.config.reserved_ids = ['mb'];
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('reserved_id_collision'));
});

test('アンカーが不足しているフロアの屋内座標は出力しない', async () => {
  const result = await generate((base) => {
    base.config.floors = [{ id: 'mb_1f', building_id: 'mb' }];
    base.config.sources.indoor = {
      kind: 'inline',
      origin_note: '合成テスト用の floor-local 座標。',
      records: [
        { source_id: 'n1', floor_id: 'mb_1f', geometry_local: { type: 'Point', coordinates: [1, 2] } },
      ],
    };
    base.config.indoor_transforms = [
      {
        floor_id: 'mb_1f',
        building_id: 'mb',
        origin: { longitude: 141.62, latitude: 42.78 },
        anchors: [],
      },
    ];
    base.config.features.push({
      source: 'indoor',
      source_id: 'n1',
      decision: 'include',
      feature_type: 'indoor_node',
      canonical_id: 'mb_1f_n_001',
      properties: { building_id: 'mb', floor_id: 'mb_1f', node_kind: 'junction' },
    });
    return base;
  });
  assert.equal(result.code, 1);
  const found = codes(result);
  assert.ok(found.includes('insufficient_fit_anchors'));
  assert.ok(found.includes('insufficient_check_anchors'));
  assert.ok(found.includes('unusable_indoor_transform'));
  assert.equal(result.outputWritten, false);
});

test('変換設定のないフロアの屋内座標は出力しない', async () => {
  const result = await generate((base) => {
    base.config.floors = [{ id: 'mb_1f', building_id: 'mb' }];
    base.config.sources.indoor = {
      kind: 'inline',
      origin_note: '合成テスト用の floor-local 座標。',
      records: [
        { source_id: 'n1', floor_id: 'mb_1f', geometry_local: { type: 'Point', coordinates: [1, 2] } },
      ],
    };
    base.config.features.push({
      source: 'indoor',
      source_id: 'n1',
      decision: 'include',
      feature_type: 'indoor_node',
      canonical_id: 'mb_1f_n_001',
      properties: { building_id: 'mb', floor_id: 'mb_1f', node_kind: 'junction' },
    });
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('missing_indoor_transform'));
});

test('対応設定がスキーマに合わなければ実行前に止まる', () => {
  const dir = makeWorkspace({
    'config.json': { config_version: '1.0.0', dataset_name: 'x', sources: {}, floors: [], features: [] },
  });
  assert.throws(
    () => loadConfig({ configPath: path.join(dir, 'config.json'), inputRoot: dir }),
    ConfigError,
  );
});

test('exclude エントリに理由コードと理由が無ければ実行前に止まる', () => {
  const { source, config } = minimalCase();
  config.features[0] = { source: 'src', source_id: 'mb', decision: 'exclude' };
  const dir = makeWorkspace({ 'source.geojson': source, 'config.json': config });
  assert.throws(
    () => loadConfig({ configPath: path.join(dir, 'config.json'), inputRoot: dir }),
    ConfigError,
  );
});

test('廃止された crs メンバーを持つ原本は座標系を推定せず失敗させる', async () => {
  const result = await generate((base) => {
    base.source.crs = { type: 'name', properties: { name: 'urn:ogc:def:crs:EPSG::4326' } };
    return base;
  });
  assert.equal(result.code, 1);
  assert.ok(codes(result).includes('legacy_crs_member'));
});
