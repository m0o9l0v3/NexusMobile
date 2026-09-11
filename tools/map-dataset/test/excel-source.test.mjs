import assert from 'node:assert/strict';
import path from 'node:path';
import { test } from 'node:test';

import { Findings } from '../src/findings.mjs';
import { readExcelSource } from '../src/sources/excel-source.mjs';
import { FIXTURES_DIR } from './helpers.mjs';

const WORKBOOK = path.join(FIXTURES_DIR, 'id-master.xlsx');

/**
 * @param {Partial<import('../src/sources/excel-source.mjs').ExcelSourceSpec>} overrides
 */
function spec(overrides = {}) {
  return /** @type {import('../src/sources/excel-source.mjs').ExcelSourceSpec} */ ({
    kind: 'excel',
    path: 'id-master.xlsx',
    sheet: '登録',
    header_row: 1,
    columns: { category: '区分', source_id: 'コード', display_name: '名称', status: '状態' },
    ...overrides,
  });
}

test('明示したシート・列・行フィルタだけを読む', () => {
  const findings = new Findings();
  const rows = readExcelSource(spec({ row_filter: { column: 'category', equals: '建物' } }), WORKBOOK, findings);
  assert.ok(findings.ok, findings.errors.map((f) => f.message).join('\n'));
  assert.deepEqual(
    rows.map((row) => row.values.source_id),
    ['mb', 'ptb'],
  );
  assert.deepEqual(rows[0].values, {
    category: '建物',
    source_id: 'mb',
    display_name: '教室棟',
    status: '確認済み',
  });
  // 追跡情報にシート名と行番号が残る。
  assert.deepEqual(rows[0].source, { file: 'id-master.xlsx', sheet: '登録', row: 2 });
  assert.equal(rows[1].source.row, 3);
});

test('存在しないシートを指定したら失敗する', () => {
  const findings = new Findings();
  const rows = readExcelSource(spec({ sheet: 'IDマスター' }), WORKBOOK, findings);
  assert.deepEqual(rows, []);
  assert.deepEqual(
    findings.errors.map((f) => f.code),
    ['missing_sheet'],
  );
});

test('対応設定が要求する列が無ければ失敗する（列名を推測しない）', () => {
  const findings = new Findings();
  const rows = readExcelSource(
    spec({ columns: { category: '区分', source_id: 'ID/コード' } }),
    WORKBOOK,
    findings,
  );
  assert.deepEqual(rows, []);
  assert.deepEqual(
    findings.errors.map((f) => f.code),
    ['missing_column'],
  );
});

test('必須値が空欄なら行を採用せず失敗する', () => {
  const findings = new Findings();
  const rows = readExcelSource(
    spec({ row_filter: { column: 'category', equals: 'エリア' }, required_values: ['display_name'] }),
    WORKBOOK,
    findings,
  );
  assert.deepEqual(rows, []);
  assert.deepEqual(
    findings.errors.map((f) => f.code),
    ['missing_required_value'],
  );
  assert.equal(findings.errors[0].source?.row, 5);
});

test('日付書式のセルは推定解釈せず失敗させる', () => {
  const findings = new Findings();
  const rows = readExcelSource(
    spec({
      columns: { category: '区分', source_id: 'コード', legacy_id: '日付ID' },
      row_filter: { column: 'category', equals: 'エリア' },
    }),
    WORKBOOK,
    findings,
  );
  assert.deepEqual(rows, []);
  assert.deepEqual(
    findings.errors.map((f) => f.code),
    ['ambiguous_cell_format'],
  );
});

test('row_filter が未定義の論理名を指したら失敗する', () => {
  const findings = new Findings();
  readExcelSource(spec({ row_filter: { column: 'unknown', equals: '建物' } }), WORKBOOK, findings);
  assert.deepEqual(
    findings.errors.map((f) => f.code),
    ['invalid_row_filter'],
  );
});
