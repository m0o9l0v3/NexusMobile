/**
 * 国土地理院 基盤地図情報（基本項目, JPGIS GML）の建物を GeoJSON にする。
 *
 * - 対象: BldA（建築物, 面）と BldL（建築物の外周線, 線）。
 * - GML の posList は「緯度 経度」の順。GeoJSON は RFC 7946 の [経度, 緯度] に並べ替える。
 *   QGIS などで GML をそのまま開くと軸が入れ替わって別の場所に出ることがあるため、ここで明示的に変換する。
 * - 座標は原本の桁のまま（丸めない）。丸めは map-dataset が E1-5 の小数6桁で行う。
 * - 座標系は srsName（fguuid:jgd2024.bl / fguuid:jgd2011.bl）を properties.crs に記録する。
 *   緯度経度（.bl）以外は拒否する。JGD を WGS 84 と同じ値として扱う前提は
 *   docs/map-data/campus-survey-plan.md §2.1。
 *
 * Windows 専用の基盤地図情報ビューアの代わりに Mac・Linux で使う。
 */

const FEATURE_TAGS = Object.freeze(['BldA', 'BldL']);
const ACCEPTED_SRS = /^fguuid:jgd(2011|2024)\.bl$/;

export class FgdError extends Error {}

/**
 * @typedef {[number, number, number, number]} BBox minLon, minLat, maxLon, maxLat
 */

/**
 * @param {string} xml
 * @param {{sourceFile?: string, bbox?: BBox|null}} [options]
 * @returns {{type: 'FeatureCollection', features: Record<string, unknown>[]}}
 */
export function fgdToGeoJson(xml, options = {}) {
  const sourceFile = options.sourceFile ?? '';
  const bbox = options.bbox ?? null;
  /** @type {Record<string, unknown>[]} */
  const features = [];
  for (const tag of FEATURE_TAGS) {
    const re = new RegExp(`<${tag}\\s+gml:id="([^"]+)">([\\s\\S]*?)</${tag}>`, 'g');
    for (const m of xml.matchAll(re)) {
      const [, gmlId, body] = m;
      const srs = /srsName="([^"]+)"/.exec(body)?.[1] ?? '';
      if (!ACCEPTED_SRS.test(srs)) {
        throw new FgdError(`${tag} ${gmlId}: 座標系 ${srs || '(なし)'} は扱わない（緯度経度の JGD2011 / JGD2024 だけ）。`);
      }
      const geometry = tag === 'BldA' ? surfaceGeometry(body, gmlId) : curveGeometry(body, gmlId);
      if (bbox && !intersects(geometry, bbox)) continue;
      features.push({
        type: 'Feature',
        geometry,
        properties: {
          gml_id: gmlId,
          fgd_class: tag,
          fid: text(body, 'fid'),
          type: text(body, 'type'),
          orgGILvl: text(body, 'orgGILvl'),
          lfSpanFr: timePosition(body, 'lfSpanFr'),
          devDate: timePosition(body, 'devDate'),
          crs: srs.replace(/^fguuid:/, ''),
          source_file: sourceFile,
        },
      });
    }
  }
  return { type: 'FeatureCollection', features };
}

/** @param {string} body @param {string} name */
function text(body, name) {
  return new RegExp(`<${name}>([^<]*)</${name}>`).exec(body)?.[1].trim() ?? '';
}

/** @param {string} body @param {string} name */
function timePosition(body, name) {
  return new RegExp(`<${name}[^>]*>\\s*<gml:timePosition>([^<]*)</gml:timePosition>`).exec(body)?.[1].trim() ?? '';
}

/**
 * posList（緯度 経度 の並び）を [経度, 緯度] の配列にする。
 * @param {string} posList
 * @param {string} gmlId
 * @returns {[number, number][]}
 */
export function parsePosList(posList, gmlId) {
  const values = posList.trim().split(/\s+/).map(Number);
  if (values.length < 4 || values.length % 2 !== 0 || values.some((v) => !Number.isFinite(v))) {
    throw new FgdError(`${gmlId}: posList が「緯度 経度」の組になっていない。`);
  }
  /** @type {[number, number][]} */
  const out = [];
  for (let i = 0; i < values.length; i += 2) {
    const lat = values[i];
    const lon = values[i + 1];
    if (Math.abs(lat) > 90 || Math.abs(lon) > 180) throw new FgdError(`${gmlId}: 緯度経度の範囲外の値がある。`);
    out.push([lon, lat]);
  }
  return out;
}

/** @param {string} xml @param {string} gmlId */
function ringFrom(xml, gmlId) {
  const lists = [...xml.matchAll(/<gml:posList>([\s\S]*?)<\/gml:posList>/g)].map((m) => parsePosList(m[1], gmlId));
  /** @type {[number, number][]} */
  const ring = [];
  for (const part of lists) {
    for (const p of part) {
      const last = ring[ring.length - 1];
      if (!last || last[0] !== p[0] || last[1] !== p[1]) ring.push(p);
    }
  }
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (ring.length < 4 || first[0] !== last[0] || first[1] !== last[1]) {
    throw new FgdError(`${gmlId}: 外周が閉じていない。`);
  }
  return ring;
}

/** @param {string} body @param {string} gmlId */
function surfaceGeometry(body, gmlId) {
  const exterior = /<gml:exterior>([\s\S]*?)<\/gml:exterior>/.exec(body);
  if (!exterior) throw new FgdError(`${gmlId}: gml:exterior が無い。`);
  const rings = [ringFrom(exterior[1], gmlId)];
  for (const m of body.matchAll(/<gml:interior>([\s\S]*?)<\/gml:interior>/g)) rings.push(ringFrom(m[1], gmlId));
  return { type: 'Polygon', coordinates: rings };
}

/** @param {string} body @param {string} gmlId */
function curveGeometry(body, gmlId) {
  const lists = [...body.matchAll(/<gml:posList>([\s\S]*?)<\/gml:posList>/g)].map((m) => parsePosList(m[1], gmlId));
  if (lists.length === 0) throw new FgdError(`${gmlId}: posList が無い。`);
  return lists.length === 1
    ? { type: 'LineString', coordinates: lists[0] }
    : { type: 'MultiLineString', coordinates: lists };
}

/**
 * @param {{type: string, coordinates: any}} geometry
 * @param {BBox} bbox
 */
function intersects(geometry, bbox) {
  /** @type {[number, number][]} */
  const pts = geometry.type === 'Polygon' || geometry.type === 'MultiLineString' ? geometry.coordinates.flat() : geometry.coordinates;
  const lons = pts.map((p) => p[0]);
  const lats = pts.map((p) => p[1]);
  return !(Math.max(...lons) < bbox[0] || Math.min(...lons) > bbox[2] || Math.max(...lats) < bbox[1] || Math.min(...lats) > bbox[3]);
}

/**
 * @param {string} value "minLon,minLat,maxLon,maxLat"
 * @returns {BBox}
 */
export function parseBBox(value) {
  const parts = value.split(',').map(Number);
  if (parts.length !== 4 || parts.some((v) => !Number.isFinite(v)) || parts[0] >= parts[2] || parts[1] >= parts[3]) {
    throw new FgdError('--bbox は「最小経度,最小緯度,最大経度,最大緯度」の4つの数で書く。');
  }
  return /** @type {BBox} */ (parts);
}
