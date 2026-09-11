/**
 * validate コマンドの検査範囲。
 *
 * geojson.io などで手編集した GeoJSON を戻したときに、丸め・環の向き・参照整合が
 * 崩れていないかを確認できることを担保する。
 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { validateDataset } from '../src/validate.mjs';
import { compareIds, stringifyDeterministic } from '../src/serialize.mjs';
import { REPO_SCHEMA_PATH } from './helpers.mjs';

/** 参照整合まで満たした最小の正常データ。 */
function baseDataset() {
  return {
    type: 'FeatureCollection',
    nexus: { schema_version: '1.0.0', floors: [{ id: 'mb_1f', building_id: 'mb' }] },
    features: [
      {
        type: 'Feature',
        id: 'mb',
        geometry: {
          type: 'Polygon',
          coordinates: [
            [
              [141.62, 42.78],
              [141.621, 42.78],
              [141.621, 42.781],
              [141.62, 42.781],
              [141.62, 42.78],
            ],
          ],
        },
        properties: { feature_type: 'building' },
      },
      {
        type: 'Feature',
        id: 'campus_n_001',
        geometry: { type: 'Point', coordinates: [141.6205, 42.7805] },
        properties: { feature_type: 'outdoor_node', scope: 'campus', node_kind: 'entrance_approach' },
      },
      {
        type: 'Feature',
        id: 'mb_1f_n_001',
        geometry: { type: 'Point', coordinates: [141.6206, 42.7805] },
        properties: { feature_type: 'indoor_node', building_id: 'mb', floor_id: 'mb_1f', node_kind: 'junction' },
      },
      {
        type: 'Feature',
        id: 'mb_1f_n_002',
        geometry: { type: 'Point', coordinates: [141.6207, 42.7805] },
        properties: { feature_type: 'indoor_node', building_id: 'mb', floor_id: 'mb_1f', node_kind: 'destination' },
      },
      {
        type: 'Feature',
        id: 'mb_1f_e_001',
        geometry: {
          type: 'LineString',
          coordinates: [
            [141.6206, 42.7805],
            [141.6207, 42.7805],
          ],
        },
        properties: {
          feature_type: 'walking_path',
          scope: 'indoor',
          building_id: 'mb',
          floor_id: 'mb_1f',
          from_node_id: 'mb_1f_n_001',
          to_node_id: 'mb_1f_n_002',
          path_kind: 'corridor',
          bidirectional: true,
          accessibility: 'accessible',
          distance_m: 8.2,
          estimated_seconds: 8,
        },
      },
      {
        type: 'Feature',
        id: 'mb_ent_001',
        geometry: { type: 'Point', coordinates: [141.62055, 42.7805] },
        properties: {
          feature_type: 'formal_entrance',
          building_id: 'mb',
          floor_id: 'mb_1f',
          outside_node_id: 'campus_n_001',
          inside_node_id: 'mb_1f_n_001',
          is_primary: true,
          accessibility: 'accessible',
        },
      },
    ],
  };
}

/**
 * @param {(dataset: any) => void} [mutate]
 */
function check(mutate) {
  const dataset = baseDataset();
  if (mutate) mutate(dataset);
  const findings = validateDataset(dataset, { schemaPath: REPO_SCHEMA_PATH });
  return findings.errors.map((finding) => finding.code);
}

test('参照整合まで満たしたデータは合格する', () => {
  assert.deepEqual(check(), []);
});

test('Polygon の環が閉じていなければ拒否する', () => {
  const codes = check((dataset) => {
    dataset.features[0].geometry.coordinates[0].pop();
  });
  assert.ok(codes.includes('unclosed_ring') || codes.includes('schema_violation'));
});

test('外環の向きが時計回りなら拒否する', () => {
  const codes = check((dataset) => {
    dataset.features[0].geometry.coordinates[0].reverse();
  });
  assert.deepEqual(codes, ['ring_orientation']);
});

test('小数6桁を超える座標を拒否する', () => {
  const codes = check((dataset) => {
    dataset.features[1].geometry.coordinates = [141.62051234, 42.7805];
  });
  assert.ok(codes.includes('coordinate_not_rounded'));
});

test('canonical ID を properties.id へ複製していたら拒否する', () => {
  const codes = check((dataset) => {
    dataset.features[0].properties.id = 'mb';
  });
  assert.ok(codes.includes('schema_violation'), '未知プロパティとしてスキーマが拒否する');
});

test('Feature id の重複を拒否する', () => {
  const codes = check((dataset) => {
    dataset.features[3].id = 'mb_1f_n_001';
  });
  assert.ok(codes.includes('duplicate_canonical_id'));
});

test('経路の端点がノード座標と一致しなければ拒否する', () => {
  const codes = check((dataset) => {
    dataset.features[4].geometry.coordinates[0] = [141.6209, 42.7805];
  });
  assert.deepEqual(codes, ['path_endpoint_mismatch']);
});

test('始点と終点が同じ経路を拒否する', () => {
  const codes = check((dataset) => {
    dataset.features[4].properties.to_node_id = 'mb_1f_n_001';
  });
  assert.ok(codes.includes('self_loop_path'));
});

test('入口の内側ノードが別フロアなら拒否する', () => {
  const codes = check((dataset) => {
    dataset.nexus.floors.push({ id: 'mb_2f', building_id: 'mb' });
    dataset.features[5].properties.floor_id = 'mb_2f';
  });
  assert.ok(codes.includes('entrance_inside_node_floor_mismatch'));
});

test('floor id の接頭辞が building_id と一致しなければ拒否する', () => {
  const codes = check((dataset) => {
    dataset.nexus.floors[0] = { id: 'ptb_1f', building_id: 'mb' };
  });
  assert.ok(codes.includes('floor_building_prefix_mismatch'));
});

test('屋外経路の端点に屋内ノードを指定したら拒否する', () => {
  const codes = check((dataset) => {
    dataset.features.push({
      type: 'Feature',
      id: 'campus_e_001',
      geometry: {
        type: 'LineString',
        coordinates: [
          [141.6205, 42.7805],
          [141.6206, 42.7805],
        ],
      },
      properties: {
        feature_type: 'walking_path',
        scope: 'campus',
        from_node_id: 'campus_n_001',
        to_node_id: 'campus_n_002',
        path_kind: 'walkway',
        bidirectional: true,
        accessibility: 'accessible',
        distance_m: 8.2,
        estimated_seconds: 8,
      },
    });
    return dataset;
  });
  assert.ok(codes.includes('undefined_reference'));
});

test('決定的シリアライズの書式を固定する', () => {
  const text = stringifyDeterministic({ type: 'Feature', coordinates: [141.62, 42.78], nested: { a: 1 } });
  assert.equal(
    text,
    '{\n  "type": "Feature",\n  "coordinates": [141.62, 42.78],\n  "nested": {\n    "a": 1\n  }\n}\n',
  );
});

test('ID 比較はロケールに依存しないコードポイント順', () => {
  const ids = ['mb_1f_n_010', 'mb', 'campus_n_002', 'MB', 'mb_1f_n_002'];
  assert.deepEqual([...ids].sort(compareIds), [
    'MB',
    'campus_n_002',
    'mb',
    'mb_1f_n_002',
    'mb_1f_n_010',
  ]);
});
