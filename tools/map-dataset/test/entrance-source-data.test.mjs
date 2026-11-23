/**
 * 実測入口の正規化ソースおよび構内歩行ネットワーク下書きを検証する。
 *
 * 配布 formal_entrance に必要なフロア・屋内ノードおよび現地測量座標が未確定のため、
 * ここでは座標・canonical ID・証拠写真・outside_node_id の先行対応・下書きの整合を検証する。
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

/**
 * @param {Record<string, string>[]} nodes
 * @param {Record<string, string>[]} edges
 * @param {(edge: Record<string, string>) => boolean} predicate
 * @returns {Set<string>}
 */
function collectReachable(nodes, edges, predicate) {
  const activeNodeIds = new Set(nodes.filter((n) => n.status !== 'retired').map((n) => n.node_id));
  /** @type {Map<string, Set<string>>} */
  const adj = new Map([...activeNodeIds].map((id) => [id, new Set()]));
  for (const edge of edges) {
    if (edge.status === 'retired' || !predicate(edge)) continue;
    adj.get(edge.from_node_id)?.add(edge.to_node_id);
    if (edge.bidirectional === 'true') {
      adj.get(edge.to_node_id)?.add(edge.from_node_id);
    }
  }
  const visited = new Set(['campus_n_001']);
  const queue = ['campus_n_001'];
  while (queue.length > 0) {
    const current = /** @type {string} */ (queue.pop());
    for (const next of adj.get(current) ?? []) {
      if (!visited.has(next)) {
        visited.add(next);
        queue.push(next);
      }
    }
  }
  return visited;
}

test('屋外直結12棟の入口座標・証拠写真・outside_node_id先行対応が一意に整合する', () => {
  const entrances = readCsv('map-data/normalized/entrances.csv');
  const rawPhotos = readCsv('map-data/raw/2026-09-19/entrance-photo-metadata.csv');
  const draftNodes = readCsv('map-data/drafts/campus_nodes_draft.csv');
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

  const nodeById = new Map(draftNodes.map((row) => [row.node_id, row]));
  const rawByPhoto = new Map(rawPhotos.map((row) => [row.photo_file, row]));

  for (const row of entrances) {
    assert.match(row.entrance_id, new RegExp(`^${row.building_id}_ent_[0-9]{3}$`));
    assert.ok(Number.isFinite(Number(row.longitude)) && Number(row.longitude) >= -180 && Number(row.longitude) <= 180);
    assert.ok(Number.isFinite(Number(row.latitude)) && Number(row.latitude) >= -90 && Number(row.latitude) <= 90);
    assert.equal(row.accessibility, 'unknown');
    assert.equal(row.is_primary, '');
    assert.equal(row.floor_id, '');
    assert.match(row.outside_node_id, /^campus_n_[0-9]{3}$/);
    assert.equal(row.inside_node_id, '');
    assert.notEqual(row.status, 'published');

    const outsideNode = nodeById.get(row.outside_node_id);
    assert.ok(outsideNode, `${row.entrance_id}: outside_node_id ${row.outside_node_id} が下書きノードにない`);
    assert.notEqual(outsideNode.status, 'retired', `${row.entrance_id}: retired ノード ${row.outside_node_id} を参照している`);
    assert.equal(outsideNode.node_kind, 'entrance_approach', `${row.entrance_id}: ${row.outside_node_id} が entrance_approach ではない`);
    const connected = outsideNode.connected_buildings.split('|').filter(Boolean);
    assert.ok(
      connected.includes(row.building_id),
      `${row.entrance_id}: ${row.outside_node_id} の connected_buildings (${outsideNode.connected_buildings}) に ${row.building_id} がない`,
    );

    const raw = rawByPhoto.get(row.source_photo);
    assert.ok(raw, `${row.entrance_id}: 証拠写真 ${row.source_photo} がraw台帳にない`);
    assert.equal(raw.sha256, row.source_photo_sha256);
    assert.match(row.source_photo_sha256, /^[0-9a-f]{64}$/);
  }

  assert.equal(targetBuildings.has('ptb'), false);
  assert.equal(targetBuildings.has('aptr'), false);
});

test('格納庫A/Bは建物・入口ID・outside_node_idを分離し、旧共有写真のメタデータ整合を保つ', () => {
  const entrances = readCsv('map-data/normalized/entrances.csv');
  const hgrA = entrances.find((row) => row.building_id === 'hgr_a');
  const hgrB = entrances.find((row) => row.building_id === 'hgr_b');

  assert.ok(hgrA);
  assert.ok(hgrB);
  assert.notEqual(hgrA.entrance_id, hgrB.entrance_id);
  assert.equal(hgrA.outside_node_id, 'campus_n_020');
  assert.equal(hgrB.outside_node_id, 'campus_n_021');
  assert.notEqual(hgrA.outside_node_id, hgrB.outside_node_id);
  assert.equal(hgrA.route_approach_group, '');
  assert.equal(hgrB.route_approach_group, '');
  assert.equal(hgrA.longitude, hgrB.longitude);
  assert.equal(hgrA.latitude, hgrB.latitude);
  assert.equal(hgrA.source_photo, hgrB.source_photo);
});

test('教室棟入口はユーザー確認済みピンを使い、写真GPSとは分離する', () => {
  const entrances = readCsv('map-data/normalized/entrances.csv');
  const mb = entrances.find((row) => row.entrance_id === 'mb_ent_001');

  assert.ok(mb);
  assert.equal(mb.coordinate_source, 'user_confirmed_google_maps_pin');
  assert.equal(mb.longitude, '141.6227516');
  assert.equal(mb.latitude, '42.7841358');
  assert.equal(mb.source_photo, 'IMG_2922.HEIC');
  assert.equal(mb.outside_node_id, 'campus_n_008');
});

test('構内歩行ネットワーク下書き（30ノード・37辺）の整合性・到達性・非漏洩を満たす', () => {
  const nodes = readCsv('map-data/drafts/campus_nodes_draft.csv');
  const edges = readCsv('map-data/drafts/campus_edges_draft.csv');
  const readmeText = readFileSync(path.join(repoRoot, 'map-data/drafts/README.md'), 'utf8');

  assert.equal(nodes.length, 30);
  assert.equal(new Set(nodes.map((n) => n.node_id)).size, 30);
  const retiredNodes = nodes.filter((n) => n.status === 'retired').map((n) => n.node_id).sort();
  const activeNodes = nodes.filter((n) => n.status === 'needs_measurement');
  assert.deepEqual(retiredNodes, ['campus_n_011', 'campus_n_016', 'campus_n_018', 'campus_n_019', 'campus_n_025']);
  assert.equal(activeNodes.length, 25);

  assert.equal(edges.length, 37);
  assert.equal(new Set(edges.map((e) => e.edge_id)).size, 37);
  const retiredEdges = edges.filter((e) => e.status === 'retired').map((e) => e.edge_id).sort();
  const activeEdges = edges.filter((e) => e.status === 'needs_measurement');
  assert.deepEqual(retiredEdges, [
    'campus_e_007',
    'campus_e_014',
    'campus_e_016',
    'campus_e_019',
    'campus_e_021',
    'campus_e_022',
    'campus_e_026',
    'campus_e_031',
  ]);
  assert.equal(activeEdges.length, 29);

  const activeNodeSet = new Set(activeNodes.map((n) => n.node_id));
  const undirectedPairs = new Set();
  for (const edge of edges) {
    assert.equal(edge.distance_m, '', `${edge.edge_id}: 未測量段階では distance_m を空欄に保つ`);
    if (edge.status === 'retired') continue;

    assert.ok(activeNodeSet.has(edge.from_node_id), `${edge.edge_id}: from_node_id ${edge.from_node_id} が有効でない`);
    assert.ok(activeNodeSet.has(edge.to_node_id), `${edge.edge_id}: to_node_id ${edge.to_node_id} が有効でない`);
    assert.notEqual(edge.from_node_id, edge.to_node_id, `${edge.edge_id}: 自己ループ`);

    const pairKey = [edge.from_node_id, edge.to_node_id].sort().join('|');
    assert.equal(undirectedPairs.has(pairKey), false, `${edge.edge_id}: 重複辺 (${pairKey})`);
    undirectedPairs.add(pairKey);

    assert.equal(edge.bidirectional, 'true');
    if (edge.edge_id === 'campus_e_025') {
      assert.equal(edge.path_kind, 'stairs');
      assert.equal(edge.accessibility, 'not_accessible');
    } else {
      assert.equal(edge.path_kind, 'walkway');
      assert.equal(edge.accessibility, 'accessible');
    }
  }

  const reachableAll = collectReachable(nodes, edges, () => true);
  const reachableAccessible = collectReachable(nodes, edges, (edge) => edge.accessibility === 'accessible');
  assert.equal(reachableAll.size, 25);
  assert.equal(reachableAccessible.size, 25);

  for (const relPath of [
    'map-data/drafts/campus_nodes_draft.csv',
    'map-data/drafts/campus_edges_draft.csv',
    'map-data/drafts/README.md',
  ]) {
    const content = readFileSync(path.join(repoRoot, relPath), 'utf8');
    assert.equal(/-51\d{3}|-13[45]\d{3}/.test(content), false, `${relPath}: EPSG:6680 座標が混入している`);
    assert.equal(/141\.6\d+|42\.7\d+/.test(content), false, `${relPath}: WGS84 座標が混入している`);
    assert.equal(/K17_/.test(content), false, `${relPath}: K17_ 識別子が混入している`);
    assert.equal(/\/Users\/|\/private\/|\/tmp\//.test(content), false, `${relPath}: ローカルパスが混入している`);
  }
  assert.match(readmeText, /30 行/);
  assert.match(readmeText, /37 行/);
});

// 航空神社は E1-4 改訂3 H-5（2026-11-12）で地図から外した。座標の判断の記録として CSV は残す。
test('航空神社の座標の記録（campus_lm_001、写真の撮影位置）が残っている', () => {
  const landmarks = readCsv('map-data/normalized/landmark-coordinate-review.csv');
  assert.equal(landmarks.length, 1);
  assert.equal(landmarks[0].canonical_id, 'campus_lm_001');
  assert.equal(landmarks[0].legacy_id, 'lm_koku_shrine');
  assert.equal(landmarks[0].status, 'adopted_photo');
  assert.equal(landmarks[0].photo_latitude, '42.78600333');
  assert.equal(landmarks[0].photo_longitude, '141.62205500');
  assert.ok(Number(landmarks[0].separation_m) > 100);
});
