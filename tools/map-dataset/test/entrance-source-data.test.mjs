/**
 * 実測入口の正規化ソースを検証する。
 *
 * 配布 formal_entrance に必要なフロア・内外ノードが未確定のため、ここでは
 * 座標・canonical ID・証拠写真・格納庫共通アプローチの整合だけを検証する。
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');

/**
 * @param {string} relativePath
 * @returns {Record<string, string>[]}
 */
function readCsv(relativePath) {
  const text = readFileSync(path.join(repoRoot, relativePath), 'utf8').trim();
  const [headerLine, ...lines] = text.split('\n');
  const headers = headerLine.split(',');
  return lines.map((line) => {
    const cells = line.split(',');
    assert.equal(cells.length, headers.length, `${relativePath}: CSV列数が一致しない行: ${line}`);
    return Object.fromEntries(headers.map((header, index) => [header, cells[index]]));
  });
}

test('屋外直結12棟の入口座標と証拠写真が一意に対応する', () => {
  const entrances = readCsv('map-data/normalized/entrances.csv');
  const rawPhotos = readCsv('map-data/raw/2026-09-19/entrance-photo-metadata.csv');
  const targetBuildings = new Set([
    'ab',
    'amh',
    'ar',
    'ctc2',
    'ctc_main',
    'dh',
    'dvh',
    'hgr_a',
    'hgr_b',
    'lbh',
    'mb',
    'sab',
  ]);

  assert.equal(entrances.length, 12);
  assert.deepEqual(new Set(entrances.map((row) => row.building_id)), targetBuildings);
  assert.equal(new Set(entrances.map((row) => row.entrance_id)).size, entrances.length);
  assert.equal(rawPhotos.length, 12);
  assert.equal(rawPhotos.some((row) => row.photo_file === 'IMG_2919.HEIC'), false);

  const rawByPhoto = new Map(rawPhotos.map((row) => [row.photo_file, row]));
  for (const row of entrances) {
    assert.match(row.entrance_id, new RegExp(`^${row.building_id}_ent_[0-9]{3}$`));
    assert.ok(Number.isFinite(Number(row.longitude)) && Number(row.longitude) >= -180 && Number(row.longitude) <= 180);
    assert.ok(Number.isFinite(Number(row.latitude)) && Number(row.latitude) >= -90 && Number(row.latitude) <= 90);
    assert.equal(row.accessibility, 'unknown');
    assert.equal(row.is_primary, '');
    assert.equal(row.floor_id, '');
    assert.equal(row.outside_node_id, '');
    assert.equal(row.inside_node_id, '');
    assert.notEqual(row.status, 'published');

    const raw = rawByPhoto.get(row.source_photo);
    assert.ok(raw, `${row.entrance_id}: 証拠写真 ${row.source_photo} がraw台帳にない`);
    assert.equal(raw.sha256, row.source_photo_sha256);
    assert.match(row.source_photo_sha256, /^[0-9a-f]{64}$/);
  }

  assert.equal(targetBuildings.has('ptb'), false);
  assert.equal(targetBuildings.has('aptr'), false);
});

test('格納庫A/Bは建物IDを分けたまま同じ案内アプローチを共有する', () => {
  const entrances = readCsv('map-data/normalized/entrances.csv');
  const hgrA = entrances.find((row) => row.building_id === 'hgr_a');
  const hgrB = entrances.find((row) => row.building_id === 'hgr_b');

  assert.ok(hgrA);
  assert.ok(hgrB);
  assert.notEqual(hgrA.entrance_id, hgrB.entrance_id);
  assert.equal(hgrA.longitude, hgrB.longitude);
  assert.equal(hgrA.latitude, hgrB.latitude);
  assert.equal(hgrA.source_photo, hgrB.source_photo);
  assert.equal(hgrA.route_approach_group, 'hgr_ab_shared');
  assert.equal(hgrB.route_approach_group, 'hgr_ab_shared');
});

test('教室棟入口はユーザー確認済みピンを使い、写真GPSとは分離する', () => {
  const entrances = readCsv('map-data/normalized/entrances.csv');
  const mb = entrances.find((row) => row.entrance_id === 'mb_ent_001');

  assert.ok(mb);
  assert.equal(mb.coordinate_source, 'user_confirmed_google_maps_pin');
  assert.equal(mb.longitude, '141.6227516');
  assert.equal(mb.latitude, '42.7841358');
  assert.equal(mb.source_photo, 'IMG_2922.HEIC');
});

test('航空神社の座標差は未解消として公開対象から分離する', () => {
  const landmarks = readCsv('map-data/normalized/landmark-coordinate-review.csv');
  assert.equal(landmarks.length, 1);
  assert.equal(landmarks[0].canonical_id, 'lm_koku_shrine');
  assert.equal(landmarks[0].status, 'needs_review');
  assert.ok(Number(landmarks[0].separation_m) > 100);
});
