import assert from 'node:assert/strict';
import { test } from 'node:test';

import { Findings } from '../src/findings.mjs';
import { checkTolerances, evaluateFloorTransform, normalizeAnchor, TOLERANCES } from '../src/anchors.mjs';
import { applySimilarity, enuToWgs84 } from '../src/transform.mjs';

const ORIGIN = { longitude: 141.62, latitude: 42.78 };
const TRUTH = { translation_east_m: 10, translation_north_m: 20, rotation_rad: Math.PI / 6, scale: 1 };
const SPEC = { floor_id: 'mb_1f', building_id: 'mb', origin: ORIGIN };

/**
 * E1-5 が要求する項目をすべて埋めた合成アンカー。
 * @param {string} id
 * @param {string} role
 * @param {number} x_m
 * @param {number} y_m
 * @param {[number, number]} [offset] 局所ENU上のずれ [m]。
 * @returns {Record<string, any>}
 */
function baseAnchor(id, role, x_m, y_m, offset = [0, 0]) {
  const enu = applySimilarity(x_m, y_m, TRUTH);
  const wgs84 = enuToWgs84(enu.east_m + offset[0], enu.north_m + offset[1], ORIGIN);
  return {
    anchor_id: id,
    building_id: 'mb',
    floor_id: 'mb_1f',
    role,
    local_x_m: x_m,
    local_y_m: y_m,
    longitude: wgs84.longitude,
    latitude: wgs84.latitude,
    point_description: `合成アンカー ${id}`,
    source_file: 'fixture',
    source_location: `test/anchors.test.mjs#${id}`,
    measurement_method: 'synthetic',
    measured_at: '2026-01-01',
    measured_by: 'fixture',
    reported_accuracy_m: 0.01,
    approved_at: '2026-01-02',
    approved_by: 'fixture',
  };
}

/**
 * fit 3点 + check 1点の合格セット。
 * @returns {Record<string, any>[]}
 */
function validSet() {
  return [
    baseAnchor('a_001', 'fit', 0, 0),
    baseAnchor('a_002', 'fit', 60, 0),
    baseAnchor('a_003', 'fit', 0, 60),
    baseAnchor('c_001', 'check', 60, 60),
  ];
}

/**
 * fit 5点 + check 1点（残差の分布を作れるセット）。
 * @param {Record<string, [number, number]>} [offsets]
 * @returns {Record<string, any>[]}
 */
function wideSet(offsets = {}) {
  return [
    baseAnchor('a_001', 'fit', 0, 0, offsets.a_001),
    baseAnchor('a_002', 'fit', 60, 0, offsets.a_002),
    baseAnchor('a_003', 'fit', 0, 60, offsets.a_003),
    baseAnchor('a_004', 'fit', 60, 60, offsets.a_004),
    baseAnchor('a_005', 'fit', 30, 30, offsets.a_005),
    baseAnchor('c_001', 'check', 20, 45, offsets.c_001),
  ];
}

/**
 * @param {Record<string, any>[]} raw
 * @param {Findings} findings
 * @returns {import('../src/anchors.mjs').Anchor[]}
 */
function normalizeAll(raw, findings) {
  return raw
    .map((anchor) => normalizeAnchor(anchor, { findings, source: { file: 'fixture' }, floor_id: 'mb_1f', building_id: 'mb' }))
    .filter((anchor) => anchor !== null);
}

/**
 * @param {Record<string, any>[]} raw
 */
function evaluate(raw) {
  const findings = new Findings();
  const anchors = normalizeAll(raw, findings);
  const result = evaluateFloorTransform(SPEC, anchors, findings);
  return { findings, result, codes: findings.errors.map((finding) => finding.code) };
}

test('契約を満たすアンカーから変換を確定し、誤差条件に合格する', () => {
  const { findings, result } = evaluate(validSet());
  assert.ok(findings.ok, findings.errors.map((f) => f.message).join('\n'));
  assert.equal(result.status, 'ok');
  assert.deepEqual(result.anchor_counts, { fit: 3, check: 1, total: 4 });
  assert.ok(result.params !== null);
  assert.ok(Math.abs(result.params.scale - TRUTH.scale) < 1e-6);
  assert.ok(Math.abs(result.params.rotation_rad - TRUTH.rotation_rad) < 1e-6);
  const metrics = result.metrics;
  assert.ok(metrics !== null);
  assert.ok(metrics.fit_rms_m <= TOLERANCES.fit_rms_max_m);
  assert.ok(metrics.check_max_m <= TOLERANCES.check_point_max_m);
  assert.ok(metrics.roundtrip_max_m <= TOLERANCES.roundtrip_max_m);
  assert.ok(metrics.rounding_max_m <= TOLERANCES.rounding_max_m);
});

test('必須項目が欠けたアンカーを拒否する', () => {
  const raw = validSet();
  raw[0].measurement_method = '';
  raw[1].approved_by = '';
  const { codes, result } = evaluate(raw);
  assert.ok(codes.filter((code) => code === 'missing_required_anchor_field').length >= 2);
  assert.equal(result.status, 'failed');
});

test('reported_accuracy_m が unknown のアンカーを拒否する', () => {
  const raw = validSet();
  raw[0].reported_accuracy_m = 'unknown';
  const { codes } = evaluate(raw);
  assert.ok(codes.includes('unknown_reported_accuracy'));
});

test('role が fit / check 以外なら拒否する', () => {
  const raw = validSet();
  raw[0].role = 'reference';
  const { codes } = evaluate(raw);
  assert.ok(codes.includes('invalid_anchor_role'));
});

test('fit が3点未満なら失敗する', () => {
  const raw = [baseAnchor('a_001', 'fit', 0, 0), baseAnchor('a_002', 'fit', 60, 0), baseAnchor('c_001', 'check', 0, 60), baseAnchor('c_002', 'check', 60, 60)];
  const { codes, result } = evaluate(raw);
  assert.ok(codes.includes('insufficient_fit_anchors'));
  assert.equal(result.status, 'failed');
  assert.equal(result.params, null);
});

test('独立した check が無ければ失敗する', () => {
  const raw = [
    baseAnchor('a_001', 'fit', 0, 0),
    baseAnchor('a_002', 'fit', 60, 0),
    baseAnchor('a_003', 'fit', 0, 60),
    baseAnchor('a_004', 'fit', 60, 60),
  ];
  const { codes } = evaluate(raw);
  assert.ok(codes.includes('insufficient_check_anchors'));
});

test('合計4点未満なら失敗する', () => {
  const raw = [
    baseAnchor('a_001', 'fit', 0, 0),
    baseAnchor('a_002', 'fit', 60, 0),
    baseAnchor('a_003', 'fit', 0, 60),
  ];
  const { codes } = evaluate(raw);
  assert.ok(codes.includes('insufficient_anchors'));
});

test('fit と check を同じ点で兼用したら失敗する', () => {
  const raw = validSet();
  raw.push(baseAnchor('c_002', 'check', 0, 0));
  const { codes, result } = evaluate(raw);
  assert.ok(codes.includes('fit_check_shared_point'));
  assert.equal(result.status, 'failed');
});

test('anchor_id の重複を拒否する', () => {
  const raw = validSet();
  raw.push({ ...baseAnchor('a_001', 'check', 30, 30) });
  const { codes } = evaluate(raw);
  assert.ok(codes.includes('duplicate_anchor_id'));
});

test('退化した（ほぼ共線の）fit 配置を拒否する', () => {
  const raw = [
    baseAnchor('a_001', 'fit', 0, 0),
    baseAnchor('a_002', 'fit', 30, 0),
    baseAnchor('a_003', 'fit', 60, 0),
    baseAnchor('c_001', 'check', 90, 0),
  ];
  const { codes, result } = evaluate(raw);
  assert.ok(codes.includes('degenerate_anchor_layout'));
  assert.equal(result.status, 'failed');
});

test('fit 残差が各点上限を超えたら失敗する', () => {
  const { codes, result } = evaluate(wideSet({ a_001: [20, 0] }));
  assert.ok(codes.includes('fit_residual_exceeded'));
  assert.equal(result.status, 'failed');
});

test('各点上限内でも fit 残差RMSが上限を超えたら失敗する', () => {
  /** @type {Record<string, [number, number]>} */
  const offsets = { a_001: [0, 3], a_002: [0, -3], a_003: [0, 3], a_004: [0, -3], a_005: [0, 3] };
  const { codes, result } = evaluate(wideSet(offsets));
  assert.ok(codes.includes('fit_rms_exceeded'));
  assert.ok(!codes.includes('fit_residual_exceeded'), '各点は上限内であること');
  assert.equal(result.status, 'failed');
});

test('check 誤差が上限を超えたら失敗する（fit だけで合格にしない）', () => {
  const { codes, result } = evaluate(wideSet({ c_001: [5, 0] }));
  assert.ok(codes.includes('check_error_exceeded'));
  assert.ok(!codes.includes('fit_rms_exceeded'));
  assert.equal(result.status, 'failed');
});

test('数値往復誤差と丸め誤差の上限を判定する', () => {
  const findings = new Findings();
  const evaluation = checkTolerances(
    'mb_1f',
    [
      { anchor_id: 'a_001', role: 'fit', residual_m: 0.1, roundtrip_m: 0.06, rounding_m: 0.01 },
      { anchor_id: 'a_002', role: 'fit', residual_m: 0.1, roundtrip_m: 0.01, rounding_m: 0.2 },
      { anchor_id: 'a_003', role: 'fit', residual_m: 0.1, roundtrip_m: 0.01, rounding_m: 0.01 },
      { anchor_id: 'c_001', role: 'check', residual_m: 0.1, roundtrip_m: 0.01, rounding_m: 0.01 },
    ],
    findings,
  );
  const codes = findings.errors.map((finding) => finding.code);
  assert.deepEqual(codes.sort(), ['rounding_error_exceeded', 'roundtrip_error_exceeded']);
  assert.equal(evaluation.pass, false);
});

test('許容値内なら合格する', () => {
  const findings = new Findings();
  const evaluation = checkTolerances(
    'mb_1f',
    [
      { anchor_id: 'a_001', role: 'fit', residual_m: 1.9, roundtrip_m: 0.05, rounding_m: 0.1 },
      { anchor_id: 'a_002', role: 'fit', residual_m: 1.9, roundtrip_m: 0.05, rounding_m: 0.1 },
      { anchor_id: 'a_003', role: 'fit', residual_m: 1.9, roundtrip_m: 0.05, rounding_m: 0.1 },
      { anchor_id: 'c_001', role: 'check', residual_m: 3.0, roundtrip_m: 0.05, rounding_m: 0.1 },
    ],
    findings,
  );
  assert.ok(findings.ok, findings.errors.map((f) => f.message).join('\n'));
  assert.equal(evaluation.pass, true);
});

test('アンカーの経度が範囲外なら拒否する（360度ずれを推定補正しない）', () => {
  const raw = validSet();
  // 141.62 + 360 = 501.62。数値としては有限だが WGS 84 の経度ではない。
  raw[0].longitude = 501.62;
  const { codes, result } = evaluate(raw);
  assert.ok(codes.includes('anchor_longitude_out_of_range'));
  assert.equal(result.status, 'failed');
  assert.equal(result.params, null);
});

test('アンカーの緯度が範囲外なら拒否する（経度・緯度の取り違え）', () => {
  const raw = validSet();
  raw[0].latitude = 141.62;
  const { codes, result } = evaluate(raw);
  assert.ok(codes.includes('anchor_latitude_out_of_range'));
  assert.equal(result.status, 'failed');
});

test('経緯度の境界値は受理する', () => {
  const findings = new Findings();
  for (const [longitude, latitude] of /** @type {[number, number][]} */ ([
    [-180, -90],
    [180, 90],
    [0, 0],
  ])) {
    const anchor = baseAnchor('a_001', 'fit', 0, 0);
    anchor.longitude = longitude;
    anchor.latitude = latitude;
    const normalized = normalizeAnchor(anchor, {
      findings,
      source: { file: 'fixture' },
      floor_id: 'mb_1f',
      building_id: 'mb',
    });
    assert.notEqual(normalized, null, `${longitude}, ${latitude} は範囲内`);
  }
  assert.ok(findings.ok, findings.errors.map((f) => f.message).join('\n'));
});

test('境界を1つでも超えたら拒否する', () => {
  for (const [longitude, latitude, expected] of /** @type {[number, number, string][]} */ ([
    [180.000001, 42.78, 'anchor_longitude_out_of_range'],
    [-180.000001, 42.78, 'anchor_longitude_out_of_range'],
    [141.62, 90.000001, 'anchor_latitude_out_of_range'],
    [141.62, -90.000001, 'anchor_latitude_out_of_range'],
  ])) {
    const findings = new Findings();
    const anchor = baseAnchor('a_001', 'fit', 0, 0);
    anchor.longitude = longitude;
    anchor.latitude = latitude;
    const normalized = normalizeAnchor(anchor, {
      findings,
      source: { file: 'fixture' },
      floor_id: 'mb_1f',
      building_id: 'mb',
    });
    assert.equal(normalized, null);
    assert.ok(
      findings.errors.map((finding) => finding.code).includes(expected),
      `${longitude}, ${latitude} -> ${expected}`,
    );
  }
});

test('アンカーの floor_id / building_id が対象と違えば拒否する', () => {
  const findings = new Findings();
  const anchor = baseAnchor('a_001', 'fit', 0, 0);
  anchor.floor_id = 'mb_2f';
  anchor.building_id = 'ptb';
  const normalized = normalizeAnchor(anchor, {
    findings,
    source: { file: 'fixture' },
    floor_id: 'mb_1f',
    building_id: 'mb',
  });
  assert.equal(normalized, null);
  const codes = findings.errors.map((finding) => finding.code);
  assert.ok(codes.includes('anchor_floor_mismatch'));
  assert.ok(codes.includes('anchor_building_mismatch'));
});
