/**
 * GeoJSON payload 契約 2.0.0（E1-4 改訂1）の JSON Schema。
 *
 * CLI の既定スキーマはまだ v1 のため、ここでは v2 スキーマと正常例だけを直接検証する。
 * 異常系は正常例を1点だけ壊して、スキーマが拒否することを確かめる。
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { createSchemaValidator } from '../src/validate.mjs';
import { REPO_V2_EXAMPLE_PATH, REPO_V2_SCHEMA_PATH } from './helpers.mjs';

const validate = createSchemaValidator(REPO_V2_SCHEMA_PATH);

/** @returns {any} */
function example() {
  return JSON.parse(readFileSync(REPO_V2_EXAMPLE_PATH, 'utf8'));
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
