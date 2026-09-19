/**
 * Excel 入力アダプター。
 *
 * シート名・ヘッダー行・列名を対応設定で**明示**したときだけ読む。
 * 列名の推測やハードコードはしない。原本ごとに書式が違う場合は、
 * 暗黙の分岐を増やさず対応設定側で別ソースとして分離する。
 */

import { readFileSync } from 'node:fs';
import { openWorkbook } from './xlsx.mjs';

/**
 * @typedef {object} ExcelSourceSpec
 * @property {'excel'} kind
 * @property {string} path --input-root からの相対パス。
 * @property {string} sheet
 * @property {number} header_row 1始まりのヘッダー行番号。
 * @property {Record<string, string>} columns 論理名 -> 原本の列見出し。
 * @property {{column: string, equals: string}} [row_filter] 論理名で指定する行フィルタ。
 * @property {string[]} [required_values] 空欄を許さない論理名。
 */

/**
 * @typedef {object} ExcelRow
 * @property {Record<string, string>} values 論理名 -> 文字列化した値。
 * @property {import('../findings.mjs').SourceRef} source
 */

/**
 * 明示した列だけを読み出す。
 *
 * @param {ExcelSourceSpec} spec
 * @param {string} absolutePath
 * @param {import('../findings.mjs').Findings} findings
 * @returns {ExcelRow[]}
 */
export function readExcelSource(spec, absolutePath, findings) {
  const workbook = openWorkbook(readFileSync(absolutePath));
  if (!workbook.sheetNames.includes(spec.sheet)) {
    findings.error(
      'missing_sheet',
      `${spec.path}: シート "${spec.sheet}" が存在しない。存在するシート: ${workbook.sheetNames.join(' / ')}`,
      { source: { file: spec.path } },
    );
    return [];
  }

  const rows = workbook.readSheet(spec.sheet);
  const headerRow = rows.find((row) => row.row === spec.header_row);
  if (!headerRow) {
    findings.error('missing_header_row', `${spec.path}::${spec.sheet}: ヘッダー行 ${spec.header_row} が空。`, {
      source: { file: spec.path, sheet: spec.sheet, row: spec.header_row },
    });
    return [];
  }

  /** @type {Map<string, string>} 見出し -> 列記号。 */
  const headerToColumn = new Map();
  for (const cell of headerRow.cells.values()) {
    const heading = String(cell.value).trim();
    if (heading === '') continue;
    if (headerToColumn.has(heading)) {
      findings.error(
        'duplicate_column_heading',
        `${spec.path}::${spec.sheet}: 見出し "${heading}" が複数の列にある。対応設定で一意に指定できない。`,
        { source: { file: spec.path, sheet: spec.sheet, row: spec.header_row } },
      );
      return [];
    }
    headerToColumn.set(heading, cell.column);
  }

  /** @type {Map<string, string>} 論理名 -> 列記号。 */
  const logicalToColumn = new Map();
  let columnsOk = true;
  for (const [logicalName, heading] of Object.entries(spec.columns)) {
    const column = headerToColumn.get(heading);
    if (column === undefined) {
      findings.error(
        'missing_column',
        `${spec.path}::${spec.sheet}: 対応設定が要求する列 "${heading}"（論理名 ${logicalName}）がヘッダー行にない。見出し: ${[...headerToColumn.keys()].join(' / ')}`,
        { source: { file: spec.path, sheet: spec.sheet, row: spec.header_row } },
      );
      columnsOk = false;
      continue;
    }
    logicalToColumn.set(logicalName, column);
  }
  if (!columnsOk) return [];

  if (spec.row_filter && !logicalToColumn.has(spec.row_filter.column)) {
    findings.error(
      'invalid_row_filter',
      `${spec.path}::${spec.sheet}: row_filter が未定義の論理名 ${spec.row_filter.column} を参照している。`,
      { source: { file: spec.path, sheet: spec.sheet } },
    );
    return [];
  }
  for (const logicalName of spec.required_values ?? []) {
    if (!logicalToColumn.has(logicalName)) {
      findings.error(
        'invalid_required_value',
        `${spec.path}::${spec.sheet}: required_values が未定義の論理名 ${logicalName} を参照している。`,
        { source: { file: spec.path, sheet: spec.sheet } },
      );
      return [];
    }
  }

  /** @type {ExcelRow[]} */
  const result = [];
  for (const row of rows) {
    if (row.row <= spec.header_row) continue;
    /** @type {import('../findings.mjs').SourceRef} */
    const source = { file: spec.path, sheet: spec.sheet, row: row.row };

    /** @type {Record<string, string>} */
    const values = {};
    let cellOk = true;
    let hasAnyValue = false;
    for (const [logicalName, column] of logicalToColumn) {
      const cell = row.cells.get(column);
      if (cell === undefined) {
        values[logicalName] = '';
        continue;
      }
      if (cell.kind === 'date_formatted') {
        findings.error(
          'ambiguous_cell_format',
          `${spec.path}::${spec.sheet}#${row.row}: セル ${cell.ref}（${logicalName}）が日付書式。生値 ${cell.value} をIDや数値として推定解釈しない。原本側で書式を確定する。`,
          { source },
        );
        cellOk = false;
        continue;
      }
      if (cell.kind === 'error') {
        findings.error(
          'error_cell_value',
          `${spec.path}::${spec.sheet}#${row.row}: セル ${cell.ref}（${logicalName}）がエラー値 ${cell.value}。`,
          { source },
        );
        cellOk = false;
        continue;
      }
      const text = typeof cell.value === 'string' ? cell.value.trim() : String(cell.value);
      values[logicalName] = text;
      if (text !== '') hasAnyValue = true;
    }
    if (!cellOk) continue;
    if (!hasAnyValue) continue;

    if (spec.row_filter && values[spec.row_filter.column] !== spec.row_filter.equals) continue;

    let requiredOk = true;
    for (const logicalName of spec.required_values ?? []) {
      if (values[logicalName] === '') {
        findings.error(
          'missing_required_value',
          `${spec.path}::${spec.sheet}#${row.row}: 必須値 ${logicalName} が空。空欄を推定で埋めない。`,
          { source },
        );
        requiredOk = false;
      }
    }
    if (!requiredOk) continue;

    result.push({ values, source });
  }

  return result;
}
