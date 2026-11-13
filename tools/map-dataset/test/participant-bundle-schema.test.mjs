/**
 * 参加者向け bundle（E2-5 §5、schema_version 2.0.0・2.1.0）の JSON Schema。
 *
 * bundle の map.geojson は GeoJSON payload 契約 2.0.0 を参照するため、同じ ajv の設定で
 * 両方のスキーマを読み込んで検証する。異常系は正常例を1点だけ壊して、スキーマが拒否することを確かめる。
 * 配列をまたぐ不変条件（E2-5 §5.3）は Schema では表せないため、ここでは扱わない。
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import Ajv2020Module from 'ajv/dist/2020.js';

import { REPO_BUNDLE_EXAMPLE_PATH, REPO_BUNDLE_SCHEMA_PATH, REPO_SCHEMA_PATH } from './helpers.mjs';

/** @type {any} */
const Ajv2020 = /** @type {any} */ (Ajv2020Module).default ?? Ajv2020Module;

const ajv = new Ajv2020({ strict: true, allErrors: true });
ajv.addSchema(JSON.parse(readFileSync(REPO_SCHEMA_PATH, 'utf8')));
const validate = ajv.compile(JSON.parse(readFileSync(REPO_BUNDLE_SCHEMA_PATH, 'utf8')));

/** @returns {any} */
function example() {
  return JSON.parse(readFileSync(REPO_BUNDLE_EXAMPLE_PATH, 'utf8'));
}

/**
 * @param {any} bundle
 * @param {string} id
 */
function spot(bundle, id) {
  const found = bundle.spots.find((/** @type {any} */ item) => item.id === id);
  assert.ok(found, `例に spot "${id}" がない`);
  return found;
}

/**
 * @param {string} label
 * @param {(bundle: any) => void} change
 */
function accepts(label, change) {
  test(`bundle: ${label}`, () => {
    const bundle = example();
    change(bundle);
    assert.equal(validate(bundle), true, JSON.stringify(validate.errors));
  });
}

/**
 * @param {string} label
 * @param {(bundle: any) => void} breakIt
 */
function rejects(label, breakIt) {
  test(`bundle: ${label}を拒否する`, () => {
    const bundle = example();
    breakIt(bundle);
    assert.equal(validate(bundle), false);
  });
}

accepts('正常例はスキーマに適合する', () => {});

accepts('公開中の地図がなければ map は null', (bundle) => {
  bundle.map = null;
  for (const item of bundle.spots) item.placement = null;
});

accepts('spots・id_aliases は空でもよい', (bundle) => {
  bundle.spots = [];
  bundle.id_aliases = [];
});

accepts('id_aliases は alias と canonical_id の組', (bundle) => {
  bundle.id_aliases = [{ alias: 'mb_1f_classroom', canonical_id: 'mb_1f_cl_001' }];
});

accepts('建物の到達ノードは屋内ノードを指せる（E1-4 改訂1 §4.4）', (bundle) => {
  spot(bundle, 'mb').placement.access_node_id = 'mb_1f_n_005';
});

accepts('published_at は +00:00 の表記も UTC として受け付ける', (bundle) => {
  bundle.nexus_bundle.published_at = '2026-11-01T09:00:00.123+00:00';
});

rejects('schema_version 2.0.0・2.1.0 以外', (bundle) => {
  bundle.nexus_bundle.schema_version = '1.0.0';
});

rejects('bundle_version 0', (bundle) => {
  bundle.nexus_bundle.bundle_version = 0;
});

rejects('UTC 以外の published_at', (bundle) => {
  bundle.nexus_bundle.published_at = '2026-11-01T18:00:00+09:00';
});

rejects('payload への bundle 自身のハッシュの同梱', (bundle) => {
  bundle.nexus_bundle.sha256 = 'a'.repeat(64);
});

rejects('種別 exhibit（E2-5 O-2b）', (bundle) => {
  spot(bundle, 'mb_1f_cl_001').kind = 'exhibit';
});

rejects('kind の欠落（null は可だが項目は必須）', (bundle) => {
  delete spot(bundle, 'mb').kind;
});

rejects('空文字の description（未作成は null）', (bundle) => {
  spot(bundle, 'mb').description = '';
});

rejects('withdrawn の spot', (bundle) => {
  spot(bundle, 'mb').utilization = 'withdrawn';
});

rejects('空文字の name', (bundle) => {
  spot(bundle, 'mb').name = '';
});

rejects('建物の placement に point（重心などを推測して埋めない）', (bundle) => {
  spot(bundle, 'mb').placement.point = [141.6815, 42.7715];
});

rejects('ランドマークの placement に building_id', (bundle) => {
  spot(bundle, 'campus_lm_001').placement.building_id = 'mb';
});

rejects('部屋の placement に floor_id がない', (bundle) => {
  spot(bundle, 'mb_1f_cl_001').placement.floor_id = null;
});

rejects('部屋の placement の access_node_id の項目の欠落（null は可）', (bundle) => {
  delete spot(bundle, 'mb_1f_cl_001').placement.access_node_id;
});

rejects('正式入口の placement に access_node_id（端末が規則で求める）', (bundle) => {
  spot(bundle, 'mb_ent_001').placement.access_node_id = 'mb_1f_n_004';
});

rejects('目的地種別でない feature_type の placement', (bundle) => {
  spot(bundle, 'mb_1f_cl_001').placement.feature_type = 'indoor_node';
});

rejects('3次元の placement.point', (bundle) => {
  spot(bundle, 'mb_1f_cl_001').placement.point = [141.6813, 42.7715, 10];
});

rejects('id_aliases の未知の項目', (bundle) => {
  bundle.id_aliases = [{ alias: 'mb_1f_classroom', canonical_id: 'mb_1f_cl_001', state: 'alias' }];
});

rejects('64桁でない dataset_sha256', (bundle) => {
  bundle.map.dataset_sha256 = 'abc';
});

rejects('GeoJSON payload 契約 1.0.0 の地図（E1-4 改訂1 §3）', (bundle) => {
  bundle.map.geojson.nexus.schema_version = '1.0.0';
});

rejects('名前を持つ room を含む地図', (bundle) => {
  const room = bundle.map.geojson.features.find((/** @type {any} */ item) => item.id === 'mb_1f_cl_001');
  room.properties.name = '電気装備教室';
});

accepts('published_at の T・Z は小文字でもよい（RFC 3339 §5.6）', (bundle) => {
  bundle.nexus_bundle.published_at = '2026-11-01t09:00:00z';
});

rejects('範囲外の月・日・時刻の published_at', (bundle) => {
  bundle.nexus_bundle.published_at = '2026-99-99T99:99:99Z';
});

rejects('13月の published_at', (bundle) => {
  bundle.nexus_bundle.published_at = '2026-13-01T09:00:00Z';
});

accepts('description に契約にない最大長を課さない', (bundle) => {
  spot(bundle, 'mb').description = 'あ'.repeat(201);
});

rejects('大文字を含む spot の id（E1-3 規則1）', (bundle) => {
  spot(bundle, 'mb').id = 'SPOT-001';
});

rejects('空白を含む spot の id', (bundle) => {
  spot(bundle, 'mb').id = 'mb 1f';
});

rejects('ASCII 以外を含む spot の id', (bundle) => {
  spot(bundle, 'mb').id = '教室棟';
});

rejects('lower_snake_case でない alias の解決先', (bundle) => {
  bundle.id_aliases = [{ alias: 'mb_1f_classroom', canonical_id: 'MB_1F_CL_001' }];
});

accepts('alias（旧ID）には正規形を課さない', (bundle) => {
  bundle.id_aliases = [{ alias: 'MB-1F-Classroom', canonical_id: 'mb_1f_cl_001' }];
});

// E2-5 改訂1（2.1.0）：categories・occurrences・events。

accepts('2.0.0 の bundle（categories・occurrences・events なし）', (bundle) => {
  bundle.nexus_bundle.schema_version = '2.0.0';
  delete bundle.categories;
  delete bundle.occurrences;
  delete bundle.events;
});

accepts('categories・occurrences・events は空でもよい', (bundle) => {
  bundle.categories = [];
  bundle.occurrences = [];
  bundle.events = [];
});

accepts('一般公開時間の無い開催日（null）', (bundle) => {
  bundle.occurrences[0].days[0].public_start = null;
  bundle.occurrences[0].days[0].public_end = null;
});

accepts('カテゴリの無いイベント（null）', (bundle) => {
  bundle.events[0].category_id = null;
});

rejects('カテゴリの内部項目 selectable', (bundle) => {
  bundle.categories[0].selectable = true;
});

rejects('時刻の無い枠（終日も射影時に時刻を入れる）', (bundle) => {
  bundle.events[0].slots[1].start = null;
});

rejects('HH:mm でない時刻', (bundle) => {
  bundle.events[0].slots[0].start = '10:30:00';
});

rejects('24時以降の時刻', (bundle) => {
  bundle.events[0].slots[0].end = '24:00';
});

rejects('YYYY-MM-DD でない日付', (bundle) => {
  bundle.events[0].slots[0].date = '2027/08/01';
});

rejects('未知の time_mode', (bundle) => {
  bundle.events[0].slots[0].time_mode = 'all_day';
});

rejects('未知の participation', (bundle) => {
  bundle.events[0].slots[0].participation = 'at_start';
});

rejects('未知の status', (bundle) => {
  bundle.events[0].slots[0].status = 'scheduled';
});

rejects('会場の無い枠', (bundle) => {
  bundle.events[0].slots[0].venues = [];
});

rejects('枠の無いイベント', (bundle) => {
  bundle.events[0].slots = [];
});

rejects('空文字の中止案内（無いときは null）', (bundle) => {
  bundle.events[0].slots[1].cancel_note = '';
});

rejects('lower_snake_case でない会場の spot_id', (bundle) => {
  bundle.events[0].slots[0].venues[0].spot_id = 'MB_1F_CL_001';
});

rejects('uuid でないイベントの id', (bundle) => {
  bundle.events[0].id = 'event-1';
});
