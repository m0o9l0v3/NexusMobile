/**
 * 基盤地図情報 GML → GeoJSON（fgd-to-geojson）のテスト。合成した最小の GML だけを使う。
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

import { fgdToGeoJson, parseBBox } from '../src/fgd.mjs';
import { run } from '../src/fgd-cli.mjs';
import { buildInDir, makeWorkspace, minimalCase } from './helpers.mjs';

/** @param {string} id @param {string} posList @param {string} [srs] @param {string} [interior] */
function bldA(id, posList, srs = 'fguuid:jgd2024.bl', interior = '') {
  return `<BldA gml:id="${id}">
<fid>fid-${id}</fid>
<lfSpanFr gml:id="${id}-1"><gml:timePosition>2026-06-25</gml:timePosition></lfSpanFr>
<devDate gml:id="${id}-2"><gml:timePosition>2026-06-26</gml:timePosition></devDate>
<orgGILvl>2500</orgGILvl>
<area><gml:Surface gml:id="${id}-g" srsName="${srs}"><gml:patches><gml:PolygonPatch>
<gml:exterior><gml:Ring><gml:curveMember><gml:Curve gml:id="${id}-3"><gml:segments><gml:LineStringSegment>
<gml:posList>
${posList}
</gml:posList>
</gml:LineStringSegment></gml:segments></gml:Curve></gml:curveMember></gml:Ring></gml:exterior>${interior}
</gml:PolygonPatch></gml:patches></gml:Surface></area>
<type>普通建物</type>
</BldA>`;
}

const SQUARE = '42.780 141.620\n42.780 141.621\n42.781 141.621\n42.781 141.620\n42.780 141.620';
const FAR = '43.000 142.000\n43.000 142.001\n43.001 142.001\n43.000 142.000';
const HOLE = `
<gml:interior><gml:Ring><gml:curveMember><gml:Curve gml:id="h"><gml:segments><gml:LineStringSegment>
<gml:posList>42.7802 141.6202 42.7802 141.6204 42.7804 141.6204 42.7802 141.6202</gml:posList>
</gml:LineStringSegment></gml:segments></gml:Curve></gml:curveMember></gml:Ring></gml:interior>`;

/** @param {string} body */
const dataset = (body) => `<?xml version="1.0" encoding="utf-8"?>
<Dataset xmlns:gml="http://www.opengis.net/gml/3.2" xmlns="http://fgd.gsi.go.jp/spec/2008/FGD_GMLSchema" gml:id="Dataset1">
${body}
</Dataset>`;

const io = { log: () => {}, error: () => {} };

test('BldA を Polygon にし、緯度 経度 を [経度, 緯度] に並べ替える', () => {
  const fc = fgdToGeoJson(dataset(bldA('A1', SQUARE)), { sourceFile: 'x.xml' });
  assert.equal(fc.features.length, 1);
  const f = /** @type {any} */ (fc.features[0]);
  assert.equal(f.geometry.type, 'Polygon');
  assert.deepEqual(f.geometry.coordinates[0][0], [141.62, 42.78]);
  assert.deepEqual(f.geometry.coordinates[0][1], [141.621, 42.78]);
  assert.deepEqual(f.properties, {
    gml_id: 'A1', fgd_class: 'BldA', fid: 'fid-A1', type: '普通建物', orgGILvl: '2500',
    lfSpanFr: '2026-06-25', devDate: '2026-06-26', crs: 'jgd2024.bl', source_file: 'x.xml',
  });
});

test('穴（interior）も環として残す', () => {
  const fc = fgdToGeoJson(dataset(bldA('A1', SQUARE, 'fguuid:jgd2024.bl', HOLE)));
  assert.equal(/** @type {any} */ (fc.features[0]).geometry.coordinates.length, 2);
});

test('--bbox の外の建物は出さない', () => {
  const fc = fgdToGeoJson(dataset(bldA('A1', SQUARE) + bldA('A2', FAR)), { bbox: parseBBox('141.6,42.7,141.7,42.8') });
  assert.deepEqual(fc.features.map((f) => /** @type {any} */ (f.properties).gml_id), ['A1']);
});

test('平面直角座標など、緯度経度でない座標系は拒否する', () => {
  assert.throws(() => fgdToGeoJson(dataset(bldA('A1', SQUARE, 'fguuid:jgd2011.R12'))), /座標系/);
});

test('閉じていない外周は拒否する', () => {
  assert.throws(() => fgdToGeoJson(dataset(bldA('A1', '42.78 141.62\n42.78 141.63\n42.79 141.63\n42.79 141.62'))), /閉じていない/);
});

test('BldL は LineString になる', () => {
  const xml = dataset(`<BldL gml:id="L1"><fid>f</fid><orgGILvl>2500</orgGILvl><loc><gml:Curve gml:id="L1-g" srsName="fguuid:jgd2011.bl"><gml:segments><gml:LineStringSegment><gml:posList>42.78 141.62 42.78 141.621</gml:posList></gml:LineStringSegment></gml:segments></gml:Curve></loc><type>普通建物</type></BldL>`);
  const f = /** @type {any} */ (fgdToGeoJson(xml).features[0]);
  assert.equal(f.geometry.type, 'LineString');
  assert.deepEqual(f.geometry.coordinates, [[141.62, 42.78], [141.621, 42.78]]);
  assert.equal(f.properties.crs, 'jgd2011.bl');
});

test('CLI: GML を読んで GeoJSON を書き出す。出力先に入力を指定すると止まる', () => {
  const dir = makeWorkspace({ 'in.xml': dataset(bldA('A1', SQUARE)) });
  assert.equal(run(['--input', path.join(dir, 'in.xml'), '--out', path.join(dir, 'out.geojson')], io), 0);
  const out = JSON.parse(readFileSync(path.join(dir, 'out.geojson'), 'utf8'));
  assert.equal(out.features.length, 1);
  assert.equal(out.crs, undefined);
  assert.equal(run(['--input', path.join(dir, 'in.xml'), '--out', path.join(dir, 'in.xml')], io), 2);
});

test('CLI --assign: 照合で合った建物だけを Nexus の ID 付きで出し、map-dataset がそのまま読める', async () => {
  const dir = makeWorkspace({ 'in.xml': dataset(bldA('A1', SQUARE) + bldA('A2', FAR)) });
  assert.equal(run(['--input', path.join(dir, 'in.xml'), '--out', path.join(dir, 'gsi.geojson'), '--assign', 'A1=mb'], io), 0);
  const out = JSON.parse(readFileSync(path.join(dir, 'gsi.geojson'), 'utf8'));
  assert.equal(out.features.length, 1);
  assert.equal(out.features[0].properties.id, 'mb');
  assert.equal(out.features[0].properties.geometry_source, 'gsi_fgd');

  const { config } = minimalCase();
  // 国土地理院の建物には名前が無いので、名前は対応設定で決める。
  config.features[0].name = { policy: 'explicit', value: '教室棟', reason: 'テスト' };
  const cfgDir = makeWorkspace({ 'config.json': config, 'source.geojson': readFileSync(path.join(dir, 'gsi.geojson'), 'utf8') });
  const result = await buildInDir(cfgDir);
  assert.ok(result.findings.ok, result.findings.errors.map((f) => f.message).join('\n'));

  assert.equal(run(['--input', path.join(dir, 'in.xml'), '--out', path.join(dir, 'x.geojson'), '--assign', 'NOPE=mb'], io), 1);
  assert.equal(run(['--input', path.join(dir, 'in.xml'), '--out', path.join(dir, 'x.geojson'), '--assign', 'A1=mb', '--assign', 'A2=mb'], io), 2);
  assert.equal(run(['--input', path.join(dir, 'in.xml'), '--out', path.join(dir, 'x.geojson'), '--assign', 'A1=mb', '--assign', 'A1=ar'], io), 2);
});
