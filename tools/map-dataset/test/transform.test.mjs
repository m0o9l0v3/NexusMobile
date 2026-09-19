import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  applySimilarity,
  ecefToGeodetic,
  enuToWgs84,
  fitSimilarity,
  geodeticToEcef,
  inspectDegeneracy,
  invertSimilarity,
  wgs84ToEnu,
} from '../src/transform.mjs';

const ORIGIN = { longitude: 141.62, latitude: 42.78 };

test('測地 -> ECEF -> 測地 が往復する', () => {
  const ecef = geodeticToEcef(141.623239, 42.783737, 0);
  const back = ecefToGeodetic(ecef.x, ecef.y, ecef.z);
  assert.ok(Math.abs(back.longitude - 141.623239) < 1e-9);
  assert.ok(Math.abs(back.latitude - 42.783737) < 1e-9);
  assert.ok(Math.abs(back.height_m) < 1e-6);
});

test('WGS 84 -> 局所ENU -> WGS 84 が往復する', () => {
  const enu = wgs84ToEnu(141.6235, 42.7841, ORIGIN);
  const back = enuToWgs84(enu.east_m, enu.north_m, ORIGIN);
  const check = wgs84ToEnu(back.longitude, back.latitude, ORIGIN);
  assert.ok(Math.hypot(check.east_m - enu.east_m, check.north_m - enu.north_m) < 0.001);
});

test('局所ENU のメートルは経緯度の度数差ではない', () => {
  // 同じ度数差でも、経度方向の距離は緯度方向より短い（北緯42度付近）。
  const east = wgs84ToEnu(141.63, 42.78, ORIGIN);
  const north = wgs84ToEnu(141.62, 42.79, ORIGIN);
  assert.ok(Math.abs(east.east_m) > 700 && Math.abs(east.east_m) < 900);
  assert.ok(Math.abs(north.north_m) > 1000 && Math.abs(north.north_m) < 1200);
});

test('合成アンカーから2次元相似変換のパラメータを復元できる', () => {
  const truth = { translation_east_m: 12.5, translation_north_m: -7.25, rotation_rad: Math.PI / 6, scale: 1.0 };
  const local = [
    [0, 0],
    [50, 0],
    [0, 50],
    [40, 30],
    [-20, 15],
  ];
  const points = local.map(([x_m, y_m]) => {
    const enu = applySimilarity(x_m, y_m, truth);
    return { x_m, y_m, east_m: enu.east_m, north_m: enu.north_m };
  });

  const fitted = fitSimilarity(points);
  assert.ok(Math.abs(fitted.scale - truth.scale) < 1e-12);
  assert.ok(Math.abs(fitted.rotation_rad - truth.rotation_rad) < 1e-12);
  assert.ok(Math.abs(fitted.translation_east_m - truth.translation_east_m) < 1e-9);
  assert.ok(Math.abs(fitted.translation_north_m - truth.translation_north_m) < 1e-9);
});

test('縮尺が1でない相似変換も復元できる', () => {
  const truth = { translation_east_m: -3, translation_north_m: 4, rotation_rad: -1.1, scale: 1.37 };
  const points = [
    [0, 0],
    [30, 5],
    [10, 40],
    [-25, 20],
  ].map(([x_m, y_m]) => {
    const enu = applySimilarity(x_m, y_m, truth);
    return { x_m, y_m, east_m: enu.east_m, north_m: enu.north_m };
  });
  const fitted = fitSimilarity(points);
  assert.ok(Math.abs(fitted.scale - truth.scale) < 1e-12);
  assert.ok(Math.abs(fitted.rotation_rad - truth.rotation_rad) < 1e-12);
});

test('相似変換の逆変換が往復する', () => {
  const params = { translation_east_m: 5, translation_north_m: -2, rotation_rad: 0.4, scale: 0.98 };
  const enu = applySimilarity(11.5, -7.25, params);
  const back = invertSimilarity(enu.east_m, enu.north_m, params);
  assert.ok(Math.abs(back.x_m - 11.5) < 1e-9);
  assert.ok(Math.abs(back.y_m + 7.25) < 1e-9);
});

test('共線・重複した配置を退化として検出する', () => {
  const collinear = inspectDegeneracy(
    [
      [0, 0],
      [10, 0],
      [20, 0],
      [30, 0],
    ].map(([x_m, y_m]) => ({ x_m, y_m, east_m: x_m, north_m: y_m })),
  );
  assert.equal(collinear.degenerate, true);

  const coincident = inspectDegeneracy(
    [
      [5, 5],
      [5, 5],
      [5, 5],
    ].map(([x_m, y_m]) => ({ x_m, y_m, east_m: x_m, north_m: y_m })),
  );
  assert.equal(coincident.degenerate, true);

  const spread = inspectDegeneracy(
    [
      [0, 0],
      [50, 0],
      [0, 50],
    ].map(([x_m, y_m]) => ({ x_m, y_m, east_m: x_m, north_m: y_m })),
  );
  assert.equal(spread.degenerate, false);
});

test('3点未満では相似変換を推定しない', () => {
  assert.throws(() =>
    fitSimilarity([
      { x_m: 0, y_m: 0, east_m: 0, north_m: 0 },
      { x_m: 1, y_m: 0, east_m: 1, north_m: 0 },
    ]),
  );
});
