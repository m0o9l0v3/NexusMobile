/**
 * fgd-to-geojson CLI: 基盤地図情報（基本項目 GML）の建物を GeoJSON にする。
 * 入力の GML は読むだけで変更しない。
 */

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';

import { fgdToGeoJson, FgdError, parseBBox } from './fgd.mjs';
import { findPathCollisions } from './paths.mjs';

const HELP = `fgd-to-geojson — 基盤地図情報（基本項目, JPGIS GML）の建物を GeoJSON にする

使い方:
  fgd-to-geojson --input <FG-GML-...-BldA-....xml> [--input <...BldL...xml>] --out <出力.geojson>
                 [--bbox 最小経度,最小緯度,最大経度,最大緯度]
                 [--assign <gml:id>=<建物 ID> ...]

  BldA（建築物, 面）は Polygon、BldL（建築物の外周線）は LineString になる。
  GML の「緯度 経度」を GeoJSON の [経度, 緯度] に並べ替える。座標は丸めない。
  Windows 専用の基盤地図情報ビューアの代わりに使う。

  --assign  照合で現状と合った建物だけを、Nexus の建物 ID（properties.id）を付けて出す。
            形は国土地理院のまま（頂点を動かさない）。map-dataset の geojson 原本にそのまま使える。
            例: --assign K17_5094015390_2=ar

手順: docs/map-data/campus-survey-plan.md §2.1・§6.4`;

/**
 * @param {string[]} argv
 * @param {{log: (line: string) => void, error: (line: string) => void}} io
 * @returns {number}
 */
export function run(argv, io) {
  /** @type {any} */
  let parsed;
  try {
    parsed = parseArgs({
      args: argv,
      options: {
        input: { type: 'string', multiple: true },
        out: { type: 'string' },
        bbox: { type: 'string' },
        assign: { type: 'string', multiple: true },
        help: { type: 'boolean', default: false },
      },
      strict: true,
    });
  } catch (error) {
    io.error(String(error instanceof Error ? error.message : error));
    return 2;
  }
  const v = parsed.values;
  if (v.help) {
    io.log(HELP);
    return 0;
  }
  /** @type {string[]} */
  const inputs = v.input ?? [];
  if (inputs.length === 0 || !v.out) {
    io.error('--input と --out は必須。--help を参照。');
    return 2;
  }
  /** @type {Map<string, string>} */
  const assign = new Map();
  for (const a of /** @type {string[]} */ (v.assign ?? [])) {
    const m = /^([^=]+)=([A-Za-z0-9_]+)$/.exec(a);
    if (!m) {
      io.error(`--assign は <gml:id>=<建物 ID> の形で書く: ${a}`);
      return 2;
    }
    if (assign.has(m[1])) {
      io.error(`--assign: 国土地理院の形 ${m[1]} を2回割り当てている（${assign.get(m[1])} と ${m[2]}）。`);
      return 2;
    }
    if ([...assign.values()].includes(m[2])) {
      io.error(`--assign: 建物 ${m[2]} に2つの形を割り当てている。`);
      return 2;
    }
    assign.set(m[1], m[2]);
  }
  const collisions = findPathCollisions(
    [{ label: '--out', path: path.resolve(v.out) }],
    inputs.map((p) => ({ label: '--input', path: path.resolve(p) })),
  );
  if (collisions.length > 0) {
    for (const c of collisions) io.error(c);
    return 2;
  }
  try {
    const bbox = v.bbox ? parseBBox(v.bbox) : null;
    /** @type {Record<string, any>[]} */
    let features = [];
    for (const input of inputs) {
      const fc = fgdToGeoJson(readFileSync(input, 'utf8'), { sourceFile: path.basename(input), bbox });
      features.push(...fc.features);
    }
    if (assign.size > 0) {
      const found = new Set(features.map((f) => f.properties.gml_id));
      const missing = [...assign.keys()].filter((id) => !found.has(id));
      if (missing.length > 0) {
        io.error(`--assign の gml:id が入力に無い（--bbox の外か、別のファイル）: ${missing.join(', ')}`);
        return 1;
      }
      features = features
        .filter((f) => assign.has(f.properties.gml_id))
        .map((f) => ({
          ...f,
          properties: { id: assign.get(f.properties.gml_id), geometry_source: 'gsi_fgd', method: 'gsi_outline_as_is', ...f.properties },
        }))
        .sort((a, b) => (a.properties.id < b.properties.id ? -1 : 1));
    }
    mkdirSync(path.dirname(path.resolve(v.out)), { recursive: true });
    writeFileSync(v.out, `${JSON.stringify({ type: 'FeatureCollection', features }, null, 2)}\n`);
    io.log(`${features.length} 件を書き出した: ${v.out}`);
    return 0;
  } catch (error) {
    if (error instanceof FgdError) {
      io.error(error.message);
      return 1;
    }
    throw error;
  }
}
