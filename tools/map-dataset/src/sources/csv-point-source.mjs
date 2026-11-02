/**
 * CSV 点座標入力アダプター。
 *
 * 正規化済みの CSV（例 `map-data/normalized/landmark-coordinate-review.csv`）の1行を、
 * 経度・緯度の列から作る WGS 84 の Point として読む。
 * どの列を ID・経度・緯度に使うか、どの行を採るかは対応設定だけが決める。
 */

import { readFileSync } from 'node:fs';

/**
 * @typedef {object} CsvPointSourceSpec
 * @property {'csv_points'} kind
 * @property {string} path
 * @property {'input_root'|'config'} [relative_to] `path` の基準。既定は `--input-root`。`config` は対応設定ファイルのフォルダ。
 * @property {string} id_column canonical 候補を持つ列。
 * @property {string} longitude_column
 * @property {string} latitude_column
 * @property {{column: string, equals: string}} [row_filter]
 */

/**
 * @typedef {object} CsvPointSourceRecord
 * @property {string} source_id
 * @property {{type: 'Point', coordinates: [number, number]}} geometry
 * @property {Record<string, string>} values
 * @property {import('../findings.mjs').SourceRef} source
 */

/**
 * RFC 4180 の範囲で CSV を行・セルに分ける（二重引用符の囲みと `""` のエスケープに対応）。
 *
 * @param {string} text
 * @returns {string[][]}
 */
export function parseCsv(text) {
  /** @type {string[][]} */
  const rows = [];
  /** @type {string[]} */
  let row = [];
  let cell = '';
  let quoted = false;
  const body = text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
  for (let i = 0; i < body.length; i += 1) {
    const ch = body[i];
    if (quoted) {
      if (ch === '"' && body[i + 1] === '"') {
        cell += '"';
        i += 1;
      } else if (ch === '"') {
        quoted = false;
      } else {
        cell += ch;
      }
    } else if (ch === '"') {
      quoted = true;
    } else if (ch === ',') {
      row.push(cell);
      cell = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && body[i + 1] === '\n') i += 1;
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
    } else {
      cell += ch;
    }
  }
  if (cell !== '' || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows.filter((cells) => !(cells.length === 1 && cells[0] === ''));
}

/**
 * @param {CsvPointSourceSpec} spec
 * @param {string} absolutePath
 * @param {import('../findings.mjs').Findings} findings
 * @returns {CsvPointSourceRecord[]}
 */
export function readCsvPointSource(spec, absolutePath, findings) {
  /** @type {string} */
  let text;
  try {
    text = readFileSync(absolutePath, 'utf8');
  } catch (error) {
    findings.error('source_unreadable', `${spec.path}: 読み込めない（${String(error)}）。`, { source: { file: spec.path } });
    return [];
  }
  const [header, ...lines] = parseCsv(text);
  if (header === undefined) {
    findings.error('invalid_csv', `${spec.path}: 見出し行がない。`, { source: { file: spec.path } });
    return [];
  }
  const required = [spec.id_column, spec.longitude_column, spec.latitude_column];
  if (spec.row_filter) required.push(spec.row_filter.column);
  const missing = required.filter((column) => !header.includes(column));
  if (missing.length > 0) {
    findings.error('missing_csv_column', `${spec.path}: 列 ${missing.join(', ')} がない。`, { source: { file: spec.path } });
    return [];
  }

  /** @type {CsvPointSourceRecord[]} */
  const records = [];
  lines.forEach((cells, index) => {
    // 見出し行を1行目として数える。
    const line = index + 2;
    /** @type {import('../findings.mjs').SourceRef} */
    const source = { file: spec.path, row: line };
    if (cells.length !== header.length) {
      findings.error('invalid_csv', `${spec.path}: ${line}行目の列数が見出しと一致しない。`, { source });
      return;
    }
    /** @type {Record<string, string>} */
    const values = Object.fromEntries(header.map((column, i) => [column, cells[i]]));
    if (spec.row_filter && values[spec.row_filter.column] !== spec.row_filter.equals) return;

    const id = values[spec.id_column].trim();
    // 座標は文字列のまま数値として読み、推定や丸めをしない。
    const longitude = Number(values[spec.longitude_column]);
    const latitude = Number(values[spec.latitude_column]);
    if (id === '') {
      findings.error('missing_source_id', `${spec.path}: ${line}行目の ${spec.id_column} が空。`, { source });
      return;
    }
    if (
      values[spec.longitude_column].trim() === '' ||
      values[spec.latitude_column].trim() === '' ||
      !Number.isFinite(longitude) ||
      !Number.isFinite(latitude) ||
      Math.abs(longitude) > 180 ||
      Math.abs(latitude) > 90
    ) {
      findings.error('invalid_coordinate', `${spec.path}: ${line}行目（${id}）の経度・緯度が数値として不正。`, { source });
      return;
    }
    records.push({ source_id: id, geometry: { type: 'Point', coordinates: [longitude, latitude] }, values, source });
  });
  return records;
}
