/**
 * 現地測量の観測から点の位置を求める（局所ENU・メートル）。
 *
 * 観測の種類:
 * - distance: 2点間の水平距離
 * - chainage: 基線 A→B に沿った、A からの距離（P を基線に下ろした足の位置）
 * - offset:   基線 A→B から P までの垂直距離（右手側が正）
 *
 * - 初期値: 既知点からの2つの円の交点（交わる角が直角に近い組から順に試す）、
 *   または基線上の累積距離と支距から直接求める。方位は初期値と鏡像の区別にだけ使う。
 * - 調整: 重み付き最小二乗（Gauss-Newton）。基準点は固定。
 *
 * 契約: docs/map-data/campus-survey-plan.md §6
 */

/**
 * @typedef {{east_m: number, north_m: number}} Xy
 */

/**
 * @typedef {object} Observation
 * @property {string} record_id
 * @property {'distance'|'chainage'|'offset'} kind
 * @property {string[]} points distance: [from, to]。chainage/offset: [A, B, P]
 * @property {number} value_m 観測値（distance は水平距離、chainage は A からの距離、offset は右手側が正）
 * @property {number} sigma_m この観測の標準偏差
 * @property {number|null} bearing_true_deg distance で、points[0] から points[1] への方位（真北基準、初期値用）
 */

/**
 * @typedef {object} ObservationResidual
 * @property {string} record_id
 * @property {'distance'|'chainage'|'offset'} kind
 * @property {string[]} points
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

/** 2候補の差が、この値より小さいと「どちらか決められない」とする [m]。 */
export const AMBIGUITY_MARGIN_M = 0.5;

/**
 * 観測の計算値。
 * @param {Observation} obs
 * @param {(id: string) => Xy} pos
 */
export function computeObservation(obs, pos) {
  if (obs.kind === 'distance') {
    const a = pos(obs.points[0]);
    const b = pos(obs.points[1]);
    return Math.hypot(b.east_m - a.east_m, b.north_m - a.north_m);
  }
  const a = pos(obs.points[0]);
  const b = pos(obs.points[1]);
  const p = pos(obs.points[2]);
  const ue = b.east_m - a.east_m;
  const un = b.north_m - a.north_m;
  const len = Math.max(Math.hypot(ue, un), 1e-9);
  const pe = p.east_m - a.east_m;
  const pn = p.north_m - a.north_m;
  if (obs.kind === 'chainage') return (pe * ue + pn * un) / len;
  // 右手側が正: 進行方向 u に対して、右は (un, -ue)。
  return (pe * un - pn * ue) / len;
}

/**
 * 基線上の累積距離と支距から点を置く。
 * @param {Xy} a
 * @param {Xy} b
 * @param {number} chainage
 * @param {number} offsetRight
 * @returns {Xy}
 */
export function pointFromChainage(a, b, chainage, offsetRight) {
  const ue = b.east_m - a.east_m;
  const un = b.north_m - a.north_m;
  const len = Math.hypot(ue, un);
  const ee = ue / len;
  const en = un / len;
  return { east_m: a.east_m + chainage * ee + offsetRight * en, north_m: a.north_m + chainage * en - offsetRight * ee };
}

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

/**
 * 交点での2本の円の交わる角の正弦（1 = 直角、0 = 接する・一直線）。
 * @param {Xy} p
 * @param {Xy} c1
 * @param {Xy} c2
 */
function intersectionQuality(p, c1, c2) {
  const ae = c1.east_m - p.east_m;
  const an = c1.north_m - p.north_m;
  const be = c2.east_m - p.east_m;
  const bn = c2.north_m - p.north_m;
  const la = Math.hypot(ae, an);
  const lb = Math.hypot(be, bn);
  if (la < 1e-9 || lb < 1e-9) return 0;
  return Math.abs(ae * bn - an * be) / (la * lb);
}

/**
 * 未知点の初期値を、既知点から順に決める。
 * @param {Map<string, Xy>} fixed
 * @param {string[]} unknownIds
 * @param {Observation[]} observations
 * @returns {Map<string, Xy>}
 */
export function initialPositions(fixed, unknownIds, observations) {
  /** @type {Map<string, Xy>} */
  const known = new Map(fixed);
  /** @type {Map<string, Xy>} */
  const result = new Map();
  const pending = new Set(unknownIds);

  let progressed = true;
  while (pending.size > 0 && progressed) {
    progressed = false;
    for (const id of [...pending].sort()) {
      const chosen = locate(id, known, observations);
      if (!chosen) continue;
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
        '既知の点からの距離が2つ未満か、どの2つの円の交点もどちらか決められない。' +
        '別の方向の点から3つ目の距離を測るか、大まかな方位（bearing_deg）を1つ記入する。',
      ids,
    );
  }
  return result;
}

/**
 * @param {string} id
 * @param {Map<string, Xy>} known
 * @param {Observation[]} observations
 * @returns {Xy|null}
 */
function locate(id, known, observations) {
  // 1. 基線上の累積距離＋支距（同じ記録の chainage と offset）
  for (const ch of observations) {
    if (ch.kind !== 'chainage' || ch.points[2] !== id) continue;
    const [a, b] = ch.points;
    if (!known.has(a) || !known.has(b)) continue;
    const off = observations.find((o) => o.kind === 'offset' && o.record_id === ch.record_id);
    if (!off) continue;
    return pointFromChainage(/** @type {Xy} */ (known.get(a)), /** @type {Xy} */ (known.get(b)), ch.value_m, off.value_m);
  }

  // 2. 距離
  /** @type {{other: Xy, distance: number, bearingFromOther: number|null}[]} */
  const links = [];
  for (const obs of observations) {
    if (obs.kind !== 'distance') continue;
    const [from, to] = obs.points;
    if (to === id && known.has(from)) {
      links.push({ other: /** @type {Xy} */ (known.get(from)), distance: obs.value_m, bearingFromOther: obs.bearing_true_deg });
    } else if (from === id && known.has(to)) {
      const back = obs.bearing_true_deg === null ? null : (obs.bearing_true_deg + 180) % 360;
      links.push({ other: /** @type {Xy} */ (known.get(to)), distance: obs.value_m, bearingFromOther: back });
    }
  }
  if (links.length === 0) return null;

  /** @type {Xy|null} */
  let approx = null;
  const withBearing = links.find((l) => l.bearingFromOther !== null);
  if (withBearing) approx = polar(withBearing.other, withBearing.distance, /** @type {number} */ (withBearing.bearingFromOther));

  if (links.length >= 2) {
    // 交わる角が直角に近い組から試し、判別できた最初の組を使う。
    /** @type {{score: number, candidates: Xy[]}[]} */
    const pairs = [];
    for (let i = 0; i < links.length; i += 1) {
      for (let j = i + 1; j < links.length; j += 1) {
        const candidates = circleIntersections(links[i].other, links[i].distance, links[j].other, links[j].distance);
        if (candidates.length === 0) continue;
        const score = intersectionQuality(candidates[0], links[i].other, links[j].other);
        pairs.push({ score, candidates });
      }
    }
    pairs.sort((x, y) => y.score - x.score);
    for (const pair of pairs) {
      if (pair.candidates.length === 1) return pair.candidates[0];
      const picked = pickCandidate(pair.candidates, links, approx);
      if (picked) return picked;
    }
  }
  return approx;
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
 * @param {Observation[]} observations 両端が基準点の distance は含めない
 * @param {{maxIterations?: number, toleranceM?: number}} [options]
 * @returns {AdjustmentResult}
 */
export function adjust(fixed, observations, options = {}) {
  const maxIterations = options.maxIterations ?? 50;
  const toleranceM = options.toleranceM ?? 1e-7;

  const unknownIds = [...new Set(observations.flatMap((o) => o.points).filter((id) => !fixed.has(id)))].sort();
  const index = new Map(unknownIds.map((id, i) => [id, i]));
  const n = unknownIds.length * 2;
  const m = observations.length;
  if (unknownIds.length === 0) {
    throw new AdjustmentError('no_unknown_points', '求める点が無い。');
  }
  if (m < n) {
    throw new AdjustmentError('underdetermined', `観測が足りない（観測 ${m} 件 < 未知数 ${n}）。各点を2つ以上の点から測る。`, unknownIds);
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

  const h = 1e-4;
  let iterations = 0;
  /** @type {number[][]} */
  let normalInverse = [];
  for (; iterations < maxIterations; iterations += 1) {
    const N = Array.from({ length: n }, () => new Float64Array(n));
    const u = new Float64Array(n);
    for (const obs of observations) {
      const w = 1 / (obs.sigma_m * obs.sigma_m);
      const misclosure = obs.value_m - computeObservation(obs, pos);
      /** @type {[number, number][]} */
      const row = [];
      for (const id of new Set(obs.points)) {
        const i = index.get(id);
        if (i === undefined) continue;
        for (const k of [2 * i, 2 * i + 1]) {
          const keep = x[k];
          x[k] = keep + h;
          const plus = computeObservation(obs, pos);
          x[k] = keep - h;
          const minus = computeObservation(obs, pos);
          x[k] = keep;
          row.push([k, (plus - minus) / (2 * h)]);
        }
      }
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
    const computed = computeObservation(obs, pos);
    const v = obs.value_m - computed;
    vtpv += (v * v) / (obs.sigma_m * obs.sigma_m);
    residuals.push({
      record_id: obs.record_id,
      kind: obs.kind,
      points: obs.points,
      observed_m: obs.value_m,
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
      observation_count: observations.filter((o) => o.points.includes(id)).length,
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
