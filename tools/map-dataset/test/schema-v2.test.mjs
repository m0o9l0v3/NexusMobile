/**
 * GeoJSON payload 契約 2.x（E1-4 改訂1・改訂2）の JSON Schema。
 *
 * スキーマ単体の検証。参照整合（validator）は validate.test.mjs で確かめる。
 * 異常系は正常例を1点だけ壊して、スキーマが拒否することを確かめる。
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { createSchemaValidator } from '../src/validate.mjs';
import { REPO_EXAMPLE_PATH, REPO_SCHEMA_PATH } from './helpers.mjs';

const validate = createSchemaValidator(REPO_SCHEMA_PATH);

/** @returns {any} */
function example() {
  return JSON.parse(readFileSync(REPO_EXAMPLE_PATH, 'utf8'));
}

/**
 * @param {any} dataset
 * @param {string} id
 */
function feature(dataset, id) {
  const found = dataset.features.find((/** @type {any} */ item) => item.id === id);
  assert.ok(found, `例に Feature "${id}" がない`);
  return found;
}

/**
 * @param {string} label
 * @param {(dataset: any) => void} breakIt
 */
function rejects(label, breakIt) {
  test(`v2: ${label}を拒否する`, () => {
    const dataset = example();
    breakIt(dataset);
    assert.equal(validate(dataset), false);
  });
}

test('v2: 正常例はスキーマに適合する', () => {
  assert.equal(validate(example()), true, JSON.stringify(validate.errors));
});

test('v2: room・landmark の access_node_id と building の access_node_id は任意', () => {
  const dataset = example();
  delete feature(dataset, 'mb_1f_cl_001').properties.access_node_id;
  delete feature(dataset, 'campus_lm_001').properties.access_node_id;
  feature(dataset, 'mb').properties.access_node_id = 'mb_1f_n_005';
  assert.equal(validate(dataset), true, JSON.stringify(validate.errors));
});

rejects('schema_version 1.0.0 の payload', (dataset) => {
  dataset.nexus.schema_version = '1.0.0';
});

rejects('room の name', (dataset) => {
  feature(dataset, 'mb_1f_cl_001').properties.name = '電気装備教室';
});

rejects('landmark の name', (dataset) => {
  feature(dataset, 'campus_lm_001').properties.name = '航空神社';
});

rejects('Point 以外の room', (dataset) => {
  feature(dataset, 'mb_1f_cl_001').geometry = feature(dataset, 'mb').geometry;
});

rejects('Point 以外の landmark', (dataset) => {
  feature(dataset, 'campus_lm_001').geometry = feature(dataset, 'mb').geometry;
});

rejects('閉じた集合にない room_type', (dataset) => {
  feature(dataset, 'mb_1f_cl_001').properties.room_type = 'lab';
});

rejects('旧形式の部屋 ID（E1-7 の移行前）', (dataset) => {
  feature(dataset, 'mb_1f_cl_001').id = 'mb_f1_eec_1';
});

rejects('連番が3桁でない部屋 ID', (dataset) => {
  feature(dataset, 'mb_1f_cl_001').id = 'mb_1f_cl_1';
});

rejects('building_id のない room', (dataset) => {
  delete feature(dataset, 'mb_1f_cl_001').properties.building_id;
});

rejects('room の access_node_id に屋外ノード', (dataset) => {
  feature(dataset, 'mb_1f_cl_001').properties.access_node_id = 'campus_n_030';
});

rejects('表示名から作ったランドマーク ID', (dataset) => {
  feature(dataset, 'campus_lm_001').id = 'lm_koku_shrine';
});

rejects('連番 000 のランドマーク ID', (dataset) => {
  feature(dataset, 'campus_lm_001').id = 'campus_lm_000';
});

rejects('scope が campus でない landmark', (dataset) => {
  feature(dataset, 'campus_lm_001').properties.scope = 'indoor';
});

rejects('building_id を持つ landmark', (dataset) => {
  feature(dataset, 'campus_lm_001').properties.building_id = 'mb';
});

rejects('landmark の access_node_id に屋内ノード', (dataset) => {
  feature(dataset, 'campus_lm_001').properties.access_node_id = 'mb_1f_n_005';
});

rejects('building の access_node_id に屋外ノード', (dataset) => {
  feature(dataset, 'mb').properties.access_node_id = 'campus_n_030';
});

// E1-4 改訂2：構内の地面（campus_ground、2.1.0）

/** @returns {any} */
function campusGround() {
  return {
    type: 'Feature',
    id: 'campus_ground',
    geometry: {
      type: 'Polygon',
      coordinates: [
        [
          [141.68, 42.77],
          [141.69, 42.77],
          [141.69, 42.78],
          [141.68, 42.78],
          [141.68, 42.77],
        ],
      ],
    },
    properties: { feature_type: 'campus_ground', scope: 'campus' },
  };
}

/** @param {any} dataset */
function withGround(dataset) {
  dataset.nexus.schema_version = '2.1.0';
  dataset.features.push(campusGround());
  return dataset;
}

test('v2.1: campus_ground を含む 2.1.0 の payload はスキーマに適合する', () => {
  const dataset = withGround(example());
  assert.equal(validate(dataset), true, JSON.stringify(validate.errors));
});

test('v2.1: campus_ground の無い 2.1.0 の payload も適合する（地面は任意）', () => {
  const dataset = example();
  dataset.nexus.schema_version = '2.1.0';
  assert.equal(validate(dataset), true, JSON.stringify(validate.errors));
});

rejects('campus_ground を含む 2.0.0 の payload', (dataset) => {
  dataset.features.push(campusGround());
});

rejects('2つの campus_ground', (dataset) => {
  withGround(dataset).features.push(campusGround());
});

rejects('穴のある campus_ground', (dataset) => {
  const ground = feature(withGround(dataset), 'campus_ground');
  ground.geometry.coordinates.push([...ground.geometry.coordinates[0]].reverse());
});

rejects('Polygon 以外の campus_ground', (dataset) => {
  feature(withGround(dataset), 'campus_ground').geometry = feature(dataset, 'campus_lm_001').geometry;
});

rejects('campus_ground 以外の ID の地面', (dataset) => {
  feature(withGround(dataset), 'campus_ground').id = 'campus_ground_001';
});

rejects('scope の無い campus_ground', (dataset) => {
  delete feature(withGround(dataset), 'campus_ground').properties.scope;
});

rejects('name を持つ campus_ground', (dataset) => {
  feature(withGround(dataset), 'campus_ground').properties.name = '構内';
});

rejects('schema_version 2.2.0 の payload', (dataset) => {
  dataset.nexus.schema_version = '2.2.0';
});
