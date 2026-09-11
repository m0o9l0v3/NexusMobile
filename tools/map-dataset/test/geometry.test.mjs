import assert from 'node:assert/strict';
import { test } from 'node:test';

import { Findings } from '../src/findings.mjs';
import { collectPositions, isRounded, normalizeGeometry, roundCoordinate, signedArea } from '../src/geometry.mjs';

test('経緯度は小数6桁へ丸める', () => {
  assert.equal(roundCoordinate(141.6232394999), 141.623239);
  assert.equal(roundCoordinate(42.7837365), 42.783737);
  assert.equal(roundCoordinate(-0.0000001), 0);
  assert.ok(Object.is(roundCoordinate(-0.0000001), 0));
  assert.ok(isRounded(141.623239));
  assert.ok(!isRounded(141.6232394999));
});

test('Polygon の環を閉じ、外環を反時計回り・内環を時計回りへ正規化する', () => {
  const findings = new Findings();
  const result = normalizeGeometry(
    {
      type: 'Polygon',
      coordinates: [
        // 外環: 時計回り・未閉鎖
        [
          [141.62, 42.78],
          [141.62, 42.781],
          [141.621, 42.781],
          [141.621, 42.78],
        ],
        // 内環: 反時計回り・未閉鎖
        [
          [141.6203, 42.7803],
          [141.6207, 42.7803],
          [141.6207, 42.7807],
          [141.6203, 42.7807],
        ],
      ],
    },
    'Polygon',
    { findings },
  );
  assert.ok(findings.ok, findings.errors.map((f) => f.message).join('\n'));
  const rings = /** @type {[number, number][][]} */ (result.geometry?.coordinates);
  for (const ring of rings) {
    assert.deepEqual(ring[0], ring[ring.length - 1], '環が閉じている');
  }
  assert.ok(signedArea(rings[0]) > 0, '外環は反時計回り');
  assert.ok(signedArea(rings[1]) < 0, '内環は時計回り');
  assert.equal(result.notes.length, 4, '閉鎖と反転の両方が記録される');
});

test('3次元 position を拒否する', () => {
  const findings = new Findings();
  const result = normalizeGeometry({ type: 'Point', coordinates: [141.62, 42.78, 0] }, 'Point', { findings });
  assert.equal(result.geometry, null);
  assert.deepEqual(
    findings.errors.map((f) => f.code),
    ['three_dimensional_position'],
  );
});

test('経緯度の逆転・範囲外を拒否する', () => {
  const swapped = new Findings();
  normalizeGeometry({ type: 'Point', coordinates: [42.78, 141.62] }, 'Point', { findings: swapped });
  assert.deepEqual(
    swapped.errors.map((f) => f.code),
    ['latitude_out_of_range'],
  );

  const outOfRange = new Findings();
  normalizeGeometry({ type: 'Point', coordinates: [200, 42.78] }, 'Point', { findings: outOfRange });
  assert.deepEqual(
    outOfRange.errors.map((f) => f.code),
    ['longitude_out_of_range'],
  );
});

test('geometry 型が feature_type の要求と違えば拒否する', () => {
  const findings = new Findings();
  const result = normalizeGeometry({ type: 'Point', coordinates: [141.62, 42.78] }, 'Polygon', { findings });
  assert.equal(result.geometry, null);
  assert.deepEqual(
    findings.errors.map((f) => f.code),
    ['geometry_type_mismatch'],
  );
});

test('面積0の環を拒否する', () => {
  const findings = new Findings();
  normalizeGeometry(
    {
      type: 'Polygon',
      coordinates: [
        [
          [141.62, 42.78],
          [141.621, 42.78],
          [141.622, 42.78],
          [141.62, 42.78],
        ],
      ],
    },
    'Polygon',
    { findings },
  );
  assert.deepEqual(
    findings.errors.map((f) => f.code),
    ['degenerate_ring'],
  );
});

test('collectPositions が入れ子の座標をすべて拾う', () => {
  const positions = collectPositions({
    type: 'Polygon',
    coordinates: [
      [
        [1, 2],
        [3, 4],
        [5, 6],
        [1, 2],
      ],
    ],
  });
  assert.equal(positions.length, 4);
});
