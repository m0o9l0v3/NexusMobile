/**
 * 距離の観測から点の位置を求める（局所ENU・メートル）。
 *
 * - 初期値: 既知点からの2つの円の交点（2候補）を、3つ目の距離か、大まかな方位で選ぶ。
 *   方位は初期値と鏡像の区別にだけ使い、調整（最小二乗）には入れない。
 * - 調整: 距離だけを観測とする重み付き最小二乗（Gauss-Newton）。基準点は固定。
 *
 * 契約: docs/map-data/campus-survey-plan.md §6
 */

/**
 * @typedef {{east_m: number, north_m: number}} Xy
 */

/**
 * @typedef {object} DistanceObservation
 * @property {string} record_id
 * @property {string} from 点 ID（基準点または未知点）
 * @property {string} to 点 ID
 * @property {number} distance_m 水平距離
 * @property {number} sigma_m この観測の標準偏差
 * @property {number|null} bearing_true_deg from から to への方位（真北基準、初期値用）。無ければ null
 */

/**
 * @typedef {object} ObservationResidual
 * @property {string} record_id
 * @property {string} from
 * @property {string} to
 * @property {number} observed_m
 * @property {number} computed_m
 * @property {number} residual_m 観測 − 計算
 * @property {number} sigma_m
 * @property {number} standardized |残差| / sigma
 */

/**
 * @typedef {object} PointResult
 * @property {string} id
 * @property {number} east_m
 * @property {number} north_m
 * @property {number} sigma_east_m
 * @property {number} sigma_north_m
 * @property {number} sigma_horizontal_m sqrt(σe² + σn²)
 * @property {number} observation_count この点に関わる観測の数
 */

/**
 * @typedef {object} AdjustmentResult
 * @property {Map<string, PointResult>} points
 * @property {ObservationResidual[]} residuals
 * @property {number} degrees_of_freedom
 * @property {number} sigma0 事後の単位重み標準偏差（自由度0のときは 1）
 * @property {number} iterations
 */

export class AdjustmentError extends Error {
  /**
   * @param {string} code
   * @param {string} message
   * @param {string[]} [pointIds]
   */
  constructor(code, message, pointIds = []) {
    super(message);
    this.code = code;
    this.pointIds = pointIds;
  }
}

const DEG_TO_RAD = Math.PI / 180;

/**
 * 2つの円の交点。交わらない（測り違いの可能性）ときは、近づいた点を1つ返す。
 * @param {Xy} c1
 * @param {number} r1
 * @param {Xy} c2
 * @param {number} r2
 * @returns {Xy[]}
 */
export function circleIntersections(c1, r1, c2, r2) {
  const dx = c2.east_m - c1.east_m;
  const dy = c2.north_m - c1.north_m;
  const d = Math.hypot(dx, dy);
  if (d < 1e-9) return [];
  const a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
  const h2 = r1 * r1 - a * a;
  const mx = c1.east_m + (a * dx) / d;
  const my = c1.north_m + (a * dy) / d;
  if (h2 <= 0) return [{ east_m: mx, north_m: my }];
  const h = Math.sqrt(h2);
  return [
    { east_m: mx - (h * dy) / d, north_m: my + (h * dx) / d },
    { east_m: mx + (h * dy) / d, north_m: my - (h * dx) / d },
  ];
}

/**
 * @param {Xy} from
 * @param {number} distance
 * @param {number} bearingTrueDeg 真北から時計回り
 * @returns {Xy}
 */
function polar(from, distance, bearingTrueDeg) {
  const t = bearingTrueDeg * DEG_TO_RAD;
  return { east_m: from.east_m + distance * Math.sin(t), north_m: from.north_m + distance * Math.cos(t) };
}

/** 2候補の差が、この値より小さいと「どちらか決められない」とする [m]。 */
export const AMBIGUITY_MARGIN_M = 0.5;

/**
 * 未知点の初期値を、既知点から順に決める。
 * @param {Map<string, Xy>} fixed
 * @param {string[]} unknownIds
 * @param {DistanceObservation[]} observations
 * @returns {Map<string, Xy>}
 */
export function initialPositions(fixed, unknownIds, observations) {
  /** @type {Map<string, Xy>} */
  const known = new Map(fixed);
  /** @type {Map<string, Xy>} */
  const result = new Map();
  const pending = new Set(unknownIds);
  /** @type {string[]} */
  const ambiguous = [];

  let progressed = true;
  while (pending.size > 0 && progressed) {
    progressed = false;
    ambiguous.length = 0;
    for (const id of [...pending].sort()) {
      /** @type {{other: Xy, distance: number, bearingFromOther: number|null}[]} */
      const links = [];
      for (const obs of observations) {
        if (obs.to === id && known.has(obs.from)) {
          links.push({ other: /** @type {Xy} */ (known.get(obs.from)), distance: obs.distance_m, bearingFromOther: obs.bearing_true_deg });
        } else if (obs.from === id && known.has(obs.to)) {
          const back = obs.bearing_true_deg === null ? null : (obs.bearing_true_deg + 180) % 360;
          links.push({ other: /** @type {Xy} */ (known.get(obs.to)), distance: obs.distance_m, bearingFromOther: back });
        }
      }
      if (links.length === 0) continue;

      /** @type {Xy|null} */
      let approx = null;
      const withBearing = links.find((l) => l.bearingFromOther !== null);
      if (withBearing) {
        approx = polar(withBearing.other, withBearing.distance, /** @type {number} */ (withBearing.bearingFromOther));
      }

      /** @type {Xy|null} */
      let chosen = null;
      if (links.length >= 2) {
        const pair = bestPair(links);
        if (pair) {
          const candidates = circleIntersections(pair[0].other, pair[0].distance, pair[1].other, pair[1].distance);
          if (candidates.length === 1) {
            chosen = candidates[0];
          } else if (candidates.length === 2) {
            chosen = pickCandidate(candidates, links, approx);
            if (!chosen) {
              ambiguous.push(id);
              continue;
            }
          }
        }
      }
      if (!chosen && approx && links.length === 1) chosen = approx;
      if (!chosen && approx) chosen = approx;
      if (!chosen) {
        ambiguous.push(id);
        continue;
      }
      known.set(id, chosen);
      result.set(id, chosen);
      pending.delete(id);
      progressed = true;
    }
  }

  if (pending.size > 0) {
    const ids = [...pending].sort();
    throw new AdjustmentError(
      'initial_position_undetermined',
      `位置の見当がつけられない点がある: ${ids.join(', ')}。` +
        '既知の点からの距離が2つ未満か、2つの円の交点のどちらか決められない。' +
        '3つ目の距離を測るか、大まかな方位（bearing_deg）を1つ記入する。',
      ids,
    );
  }
  return result;
}

/**
 * 交点の角度がいちばん直角に近い2本を選ぶ（円の交わり方が浅いと初期値が不安定になる）。
 * @param {{other: Xy, distance: number}[]} links
 */
function bestPair(links) {
  /** @type {[typeof links[number], typeof links[number]]|null} */
  let best = null;
  let bestScore = -1;
  for (let i = 0; i < links.length; i += 1) {
    for (let j = i + 1; j < links.length; j += 1) {
      const d = Math.hypot(links[i].other.east_m - links[j].other.east_m, links[i].other.north_m - links[j].other.north_m);
      if (d < 1e-6) continue;
      const score = d / Math.max(links[i].distance + links[j].distance, 1e-6);
      if (score > bestScore) {
        bestScore = score;
        best = [links[i], links[j]];
      }
    }
  }
  return best;
}

/**
 * @param {Xy[]} candidates
 * @param {{other: Xy, distance: number}[]} links
 * @param {Xy|null} approx
 * @returns {Xy|null}
 */
function pickCandidate(candidates, links, approx) {
  /** @param {Xy} c */
  const misfit = (c) =>
    Math.sqrt(
      links.reduce((sum, l) => {
        const r = Math.hypot(c.east_m - l.other.east_m, c.north_m - l.other.north_m) - l.distance;
        return sum + r * r;
      }, 0),
    );
  const m0 = misfit(candidates[0]);
  const m1 = misfit(candidates[1]);
  if (Math.abs(m0 - m1) > AMBIGUITY_MARGIN_M) return m0 < m1 ? candidates[0] : candidates[1];
  if (approx) {
    const d0 = Math.hypot(candidates[0].east_m - approx.east_m, candidates[0].north_m - approx.north_m);
    const d1 = Math.hypot(candidates[1].east_m - approx.east_m, candidates[1].north_m - approx.north_m);
    if (Math.abs(d0 - d1) > AMBIGUITY_MARGIN_M) return d0 < d1 ? candidates[0] : candidates[1];
  }
  return null;
}

/**
 * 重み付き最小二乗（Gauss-Newton）。基準点（fixed）は動かさない。
 * @param {Map<string, Xy>} fixed
 * @param {DistanceObservation[]} observations 両端が基準点の観測は含めない
 * @param {{maxIterations?: number, toleranceM?: number}} [options]
 * @returns {AdjustmentResult}
 */
export function adjust(fixed, observations, options = {}) {
  const maxIterations = options.maxIterations ?? 50;
  const toleranceM = options.toleranceM ?? 1e-7;

  const unknownIds = [
    ...new Set(observations.flatMap((o) => [o.from, o.to]).filter((id) => !fixed.has(id))),
  ].sort();
  const index = new Map(unknownIds.map((id, i) => [id, i]));
  const n = unknownIds.length * 2;
  const m = observations.length;
  if (unknownIds.length === 0) {
    throw new AdjustmentError('no_unknown_points', '求める点が無い。');
  }
  if (m < n) {
    throw new AdjustmentError(
      'underdetermined',
      `観測が足りない（観測 ${m} 件 < 未知数 ${n}）。各角を2つ以上の点から測る。`,
      unknownIds,
    );
  }

  const init = initialPositions(fixed, unknownIds, observations);
  const x = new Float64Array(n);
  unknownIds.forEach((id, i) => {
    const p = /** @type {Xy} */ (init.get(id));
    x[2 * i] = p.east_m;
    x[2 * i + 1] = p.north_m;
  });

  /** @param {string} id */
  const pos = (id) => {
    const f = fixed.get(id);
    if (f) return f;
    const i = /** @type {number} */ (index.get(id));
    return { east_m: x[2 * i], north_m: x[2 * i + 1] };
  };

  let iterations = 0;
  /** @type {number[][]} */
  let normalInverse = [];
  for (; iterations < maxIterations; iterations += 1) {
    const N = Array.from({ length: n }, () => new Float64Array(n));
    const u = new Float64Array(n);
    for (const obs of observations) {
      const a = pos(obs.from);
      const b = pos(obs.to);
      const de = b.east_m - a.east_m;
      const dn = b.north_m - a.north_m;
      const dist = Math.max(Math.hypot(de, dn), 1e-9);
      const w = 1 / (obs.sigma_m * obs.sigma_m);
      const misclosure = obs.distance_m - dist;
      /** @type {[number, number][]} */
      const row = [];
      const ia = index.get(obs.from);
      const ib = index.get(obs.to);
      if (ia !== undefined) row.push([2 * ia, -de / dist], [2 * ia + 1, -dn / dist]);
      if (ib !== undefined) row.push([2 * ib, de / dist], [2 * ib + 1, dn / dist]);
      for (const [r, vr] of row) {
        u[r] += w * vr * misclosure;
        for (const [c, vc] of row) N[r][c] += w * vr * vc;
      }
    }
    normalInverse = invert(N, unknownIds);
    let maxStep = 0;
    for (let r = 0; r < n; r += 1) {
      let dx = 0;
      for (let c = 0; c < n; c += 1) dx += normalInverse[r][c] * u[c];
      x[r] += dx;
      maxStep = Math.max(maxStep, Math.abs(dx));
    }
    if (maxStep < toleranceM) {
      iterations += 1;
      break;
    }
  }

  /** @type {ObservationResidual[]} */
  const residuals = [];
  let vtpv = 0;
  for (const obs of observations) {
    const a = pos(obs.from);
    const b = pos(obs.to);
    const computed = Math.hypot(b.east_m - a.east_m, b.north_m - a.north_m);
    const v = obs.distance_m - computed;
    vtpv += (v * v) / (obs.sigma_m * obs.sigma_m);
    residuals.push({
      record_id: obs.record_id,
      from: obs.from,
      to: obs.to,
      observed_m: obs.distance_m,
      computed_m: computed,
      residual_m: v,
      sigma_m: obs.sigma_m,
      standardized: Math.abs(v) / obs.sigma_m,
    });
  }
  const dof = m - n;
  const sigma0 = dof > 0 ? Math.sqrt(vtpv / dof) : 1;
  // 事前の精度より観測がよく合っていても、精度を事前値より小さく見積もらない。
  const scale = Math.max(sigma0, 1);

  /** @type {Map<string, PointResult>} */
  const points = new Map();
  unknownIds.forEach((id, i) => {
    const se = Math.sqrt(Math.max(normalInverse[2 * i][2 * i], 0)) * scale;
    const sn = Math.sqrt(Math.max(normalInverse[2 * i + 1][2 * i + 1], 0)) * scale;
    points.set(id, {
      id,
      east_m: x[2 * i],
      north_m: x[2 * i + 1],
      sigma_east_m: se,
      sigma_north_m: sn,
      sigma_horizontal_m: Math.hypot(se, sn),
      observation_count: observations.filter((o) => o.from === id || o.to === id).length,
    });
  });

  return { points, residuals, degrees_of_freedom: dof, sigma0, iterations };
}

/**
 * 対称な正規行列の逆行列（部分ピボット付き Gauss-Jordan）。
 * 特異なら、形が決まらない（観測の配置が悪い）として失敗させる。
 * @param {Float64Array[]} matrix
 * @param {string[]} unknownIds
 * @returns {number[][]}
 */
function invert(matrix, unknownIds) {
  const n = matrix.length;
  const a = matrix.map((row, i) => {
    const out = new Array(2 * n).fill(0);
    for (let j = 0; j < n; j += 1) out[j] = row[j];
    out[n + i] = 1;
    return out;
  });
  const scale = Math.max(...matrix.map((row, i) => Math.abs(row[i])), 1e-30);
  for (let col = 0; col < n; col += 1) {
    let pivot = col;
    for (let r = col + 1; r < n; r += 1) if (Math.abs(a[r][col]) > Math.abs(a[pivot][col])) pivot = r;
    if (Math.abs(a[pivot][col]) < scale * 1e-12) {
      const id = unknownIds[Math.floor(col / 2)];
      throw new AdjustmentError(
        'singular_geometry',
        `点 ${id} の位置が観測から1つに決まらない。基準点と一直線上にある、または観測がつながっていない。別の方向の点からも測る。`,
        [id],
      );
    }
    [a[col], a[pivot]] = [a[pivot], a[col]];
    const p = a[col][col];
    for (let j = 0; j < 2 * n; j += 1) a[col][j] /= p;
    for (let r = 0; r < n; r += 1) {
      if (r === col) continue;
      const f = a[r][col];
      if (f === 0) continue;
      for (let j = 0; j < 2 * n; j += 1) a[r][j] -= f * a[col][j];
    }
  }
  return a.map((row) => row.slice(n));
}
