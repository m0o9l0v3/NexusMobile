/**
 * floor-local 座標 ↔ 局所ENU ↔ WGS 84 の変換。
 *
 * 契約: docs/decisions/E1-5-coordinate-reference-system.md
 *
 *   floor-local (x_m, y_m)
 *     -> 2D similarity transform
 *   local ENU (east_m, north_m)
 *     -> inverse topocentric conversion
 *   WGS 84 (longitude, latitude)
 *
 * 中間計算はすべて倍精度で行い、途中で丸めない。
 * 距離比較は必ず局所ENUのメートルで行う（度数差を距離として扱わない）。
 */

/** WGS 84 長半径 [m]。 */
const SEMI_MAJOR_AXIS_M = 6378137.0;
/** WGS 84 扁平率の逆数。 */
const INVERSE_FLATTENING = 298.257223563;
const FLATTENING = 1 / INVERSE_FLATTENING;
const ECCENTRICITY_SQUARED = FLATTENING * (2 - FLATTENING);

const DEG_TO_RAD = Math.PI / 180;
const RAD_TO_DEG = 180 / Math.PI;

/**
 * @typedef {object} GeodeticOrigin 局所接平面の基準点。
 * @property {number} longitude 10進度。
 * @property {number} latitude 10進度。
 */

/**
 * @typedef {object} SimilarityParams 2次元相似変換のパラメータ。
 * @property {number} translation_east_m tx_m
 * @property {number} translation_north_m ty_m
 * @property {number} rotation_rad theta
 * @property {number} scale 一様縮尺（無次元）。
 */

/**
 * @typedef {object} Enu
 * @property {number} east_m
 * @property {number} north_m
 * @property {number} up_m
 */

/**
 * 測地座標 -> ECEF。
 * @param {number} longitude 10進度
 * @param {number} latitude 10進度
 * @param {number} height_m 楕円体高
 * @returns {{x: number, y: number, z: number}}
 */
export function geodeticToEcef(longitude, latitude, height_m) {
  const lambda = longitude * DEG_TO_RAD;
  const phi = latitude * DEG_TO_RAD;
  const sinPhi = Math.sin(phi);
  const cosPhi = Math.cos(phi);
  const n = SEMI_MAJOR_AXIS_M / Math.sqrt(1 - ECCENTRICITY_SQUARED * sinPhi * sinPhi);
  return {
    x: (n + height_m) * cosPhi * Math.cos(lambda),
    y: (n + height_m) * cosPhi * Math.sin(lambda),
    z: (n * (1 - ECCENTRICITY_SQUARED) + height_m) * sinPhi,
  };
}

/**
 * ECEF -> 測地座標（Bowring 反復）。
 * @param {number} x
 * @param {number} y
 * @param {number} z
 * @returns {{longitude: number, latitude: number, height_m: number}}
 */
export function ecefToGeodetic(x, y, z) {
  const lambda = Math.atan2(y, x);
  const p = Math.hypot(x, y);
  let phi = Math.atan2(z, p * (1 - ECCENTRICITY_SQUARED));
  let height = 0;
  for (let i = 0; i < 8; i += 1) {
    const sinPhi = Math.sin(phi);
    const n = SEMI_MAJOR_AXIS_M / Math.sqrt(1 - ECCENTRICITY_SQUARED * sinPhi * sinPhi);
    height = p / Math.cos(phi) - n;
    phi = Math.atan2(z, p * (1 - (ECCENTRICITY_SQUARED * n) / (n + height)));
  }
  return { longitude: lambda * RAD_TO_DEG, latitude: phi * RAD_TO_DEG, height_m: height };
}

/**
 * WGS 84（高さ0m）-> 基準点まわりの局所ENU。
 * @param {number} longitude
 * @param {number} latitude
 * @param {GeodeticOrigin} origin
 * @returns {Enu}
 */
export function wgs84ToEnu(longitude, latitude, origin) {
  const point = geodeticToEcef(longitude, latitude, 0);
  const base = geodeticToEcef(origin.longitude, origin.latitude, 0);
  const dx = point.x - base.x;
  const dy = point.y - base.y;
  const dz = point.z - base.z;
  const lambda0 = origin.longitude * DEG_TO_RAD;
  const phi0 = origin.latitude * DEG_TO_RAD;
  const sinLambda = Math.sin(lambda0);
  const cosLambda = Math.cos(lambda0);
  const sinPhi = Math.sin(phi0);
  const cosPhi = Math.cos(phi0);
  return {
    east_m: -sinLambda * dx + cosLambda * dy,
    north_m: -sinPhi * cosLambda * dx - sinPhi * sinLambda * dy + cosPhi * dz,
    up_m: cosPhi * cosLambda * dx + cosPhi * sinLambda * dy + sinPhi * dz,
  };
}

/**
 * 局所ENU（up=0）-> WGS 84。v1.0 は水平2次元のみを扱うため高さは返さない。
 * @param {number} east_m
 * @param {number} north_m
 * @param {GeodeticOrigin} origin
 * @returns {{longitude: number, latitude: number}}
 */
export function enuToWgs84(east_m, north_m, origin) {
  const base = geodeticToEcef(origin.longitude, origin.latitude, 0);
  const lambda0 = origin.longitude * DEG_TO_RAD;
  const phi0 = origin.latitude * DEG_TO_RAD;
  const sinLambda = Math.sin(lambda0);
  const cosLambda = Math.cos(lambda0);
  const sinPhi = Math.sin(phi0);
  const cosPhi = Math.cos(phi0);
  const x = base.x - sinLambda * east_m - sinPhi * cosLambda * north_m;
  const y = base.y + cosLambda * east_m - sinPhi * sinLambda * north_m;
  const z = base.z + cosPhi * north_m;
  const geodetic = ecefToGeodetic(x, y, z);
  return { longitude: geodetic.longitude, latitude: geodetic.latitude };
}

/**
 * floor-local -> 局所ENU（2次元相似変換）。
 * @param {number} x_m
 * @param {number} y_m
 * @param {SimilarityParams} params
 * @returns {{east_m: number, north_m: number}}
 */
export function applySimilarity(x_m, y_m, params) {
  const cos = Math.cos(params.rotation_rad);
  const sin = Math.sin(params.rotation_rad);
  return {
    east_m: params.translation_east_m + params.scale * (cos * x_m - sin * y_m),
    north_m: params.translation_north_m + params.scale * (sin * x_m + cos * y_m),
  };
}

/**
 * 局所ENU -> floor-local（相似変換の逆）。
 * @param {number} east_m
 * @param {number} north_m
 * @param {SimilarityParams} params
 * @returns {{x_m: number, y_m: number}}
 */
export function invertSimilarity(east_m, north_m, params) {
  const cos = Math.cos(params.rotation_rad);
  const sin = Math.sin(params.rotation_rad);
  const de = east_m - params.translation_east_m;
  const dn = north_m - params.translation_north_m;
  return {
    x_m: (cos * de + sin * dn) / params.scale,
    y_m: (-sin * de + cos * dn) / params.scale,
  };
}

/**
 * @typedef {object} SimilarityFitInput
 * @property {number} x_m floor-local X
 * @property {number} y_m floor-local Y
 * @property {number} east_m 目標 ENU East
 * @property {number} north_m 目標 ENU North
 */

/**
 * @typedef {object} DegeneracyReport
 * @property {boolean} degenerate
 * @property {string|null} reason
 * @property {number} perpendicular_spread_m 最良直線からの垂直方向RMS広がり [m]。
 * @property {number} principal_spread_m 主軸方向のRMS広がり [m]。
 */

/** 退化判定: 垂直広がりの絶対下限 [m]。相似変換の回転・縮尺を独立に決められない配置を弾く。 */
export const MIN_PERPENDICULAR_SPREAD_M = 1.0;
/** 退化判定: 主軸方向の広がりに対する垂直広がりの下限比。 */
export const MIN_SPREAD_RATIO = 0.05;

/**
 * fit アンカーの平面配置が退化していないかを調べる。
 * 「同一直線上へ偏らせない」（E1-5 アンカー契約）を機械判定するための追加ガードであり、
 * E1-5 の合格条件を緩めるものではない。
 *
 * @param {SimilarityFitInput[]} points
 * @returns {DegeneracyReport}
 */
export function inspectDegeneracy(points) {
  const n = points.length;
  const meanX = points.reduce((sum, p) => sum + p.x_m, 0) / n;
  const meanY = points.reduce((sum, p) => sum + p.y_m, 0) / n;
  let cxx = 0;
  let cyy = 0;
  let cxy = 0;
  for (const p of points) {
    const dx = p.x_m - meanX;
    const dy = p.y_m - meanY;
    cxx += dx * dx;
    cyy += dy * dy;
    cxy += dx * dy;
  }
  const trace = cxx + cyy;
  const diff = Math.hypot(cxx - cyy, 2 * cxy);
  const maxEigen = (trace + diff) / 2;
  const minEigen = Math.max((trace - diff) / 2, 0);
  const principal = Math.sqrt(maxEigen / n);
  const perpendicular = Math.sqrt(minEigen / n);

  if (trace === 0) {
    return {
      degenerate: true,
      reason: 'fit アンカーが1点に重なっている。',
      perpendicular_spread_m: perpendicular,
      principal_spread_m: principal,
    };
  }
  if (perpendicular < MIN_PERPENDICULAR_SPREAD_M) {
    return {
      degenerate: true,
      reason: `fit アンカーがほぼ同一直線上にある（垂直広がり ${perpendicular.toFixed(3)} m < ${MIN_PERPENDICULAR_SPREAD_M} m）。`,
      perpendicular_spread_m: perpendicular,
      principal_spread_m: principal,
    };
  }
  if (perpendicular < principal * MIN_SPREAD_RATIO) {
    return {
      degenerate: true,
      reason: `fit アンカーの配置が細長すぎる（垂直/主軸 = ${(perpendicular / principal).toFixed(4)} < ${MIN_SPREAD_RATIO}）。`,
      perpendicular_spread_m: perpendicular,
      principal_spread_m: principal,
    };
  }
  return { degenerate: false, reason: null, perpendicular_spread_m: perpendicular, principal_spread_m: principal };
}

/**
 * 最小二乗で2次元相似変換を推定する（閉形式・Umeyama）。
 * 入力順に依存しない決定的な計算。
 *
 * @param {SimilarityFitInput[]} points
 * @returns {SimilarityParams}
 */
export function fitSimilarity(points) {
  const n = points.length;
  if (n < 3) throw new Error(`相似変換の推定には3点以上が必要（受領 ${n} 点）。`);
  const meanX = points.reduce((sum, p) => sum + p.x_m, 0) / n;
  const meanY = points.reduce((sum, p) => sum + p.y_m, 0) / n;
  const meanE = points.reduce((sum, p) => sum + p.east_m, 0) / n;
  const meanN = points.reduce((sum, p) => sum + p.north_m, 0) / n;

  let sxx = 0;
  let sxy = 0;
  let denominator = 0;
  for (const p of points) {
    const dx = p.x_m - meanX;
    const dy = p.y_m - meanY;
    const de = p.east_m - meanE;
    const dn = p.north_m - meanN;
    sxx += dx * de + dy * dn;
    sxy += dx * dn - dy * de;
    denominator += dx * dx + dy * dy;
  }
  if (denominator === 0) throw new Error('fit アンカーが1点に重なっており相似変換を推定できない。');

  const rotation = Math.atan2(sxy, sxx);
  const scale = Math.hypot(sxx, sxy) / denominator;
  if (!Number.isFinite(scale) || scale <= 0) {
    throw new Error('推定した縮尺が正の有限値にならない。アンカー配置を確認する。');
  }
  const cos = Math.cos(rotation);
  const sin = Math.sin(rotation);
  return {
    translation_east_m: meanE - scale * (cos * meanX - sin * meanY),
    translation_north_m: meanN - scale * (sin * meanX + cos * meanY),
    rotation_rad: rotation,
    scale,
  };
}
