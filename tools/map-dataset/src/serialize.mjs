/**
 * 決定的なJSON書き出し。
 *
 * 同じ入力・設定からバイト単位で同じ出力を得るため、次を固定する。
 * - プロパティ順: 呼び出し側が組み立てたオブジェクトの挿入順をそのまま使う。
 * - インデント: 半角スペース2。
 * - 改行: LF。末尾に改行1つ。
 * - 数値だけの配列（position / bbox など）は1行へインライン展開する。
 */

/**
 * @param {unknown} value
 * @returns {boolean}
 */
function isNumberArray(value) {
  return Array.isArray(value) && value.length > 0 && value.every((item) => typeof item === 'number');
}

/**
 * @param {unknown} value
 * @param {string} indent
 * @returns {string}
 */
function format(value, indent) {
  if (value === null) return 'null';
  const type = typeof value;
  if (type === 'number') {
    if (!Number.isFinite(/** @type {number} */ (value))) {
      throw new Error(`有限でない数値は出力できない: ${String(value)}`);
    }
    return JSON.stringify(value);
  }
  if (type === 'boolean' || type === 'string') return JSON.stringify(value);

  const inner = `${indent}  `;
  if (Array.isArray(value)) {
    if (value.length === 0) return '[]';
    if (isNumberArray(value)) {
      return `[${value.map((item) => format(item, inner)).join(', ')}]`;
    }
    const items = value.map((item) => `${inner}${format(item, inner)}`);
    return `[\n${items.join(',\n')}\n${indent}]`;
  }
  if (type === 'object') {
    const entries = Object.entries(/** @type {Record<string, unknown>} */ (value)).filter(
      ([, item]) => item !== undefined,
    );
    if (entries.length === 0) return '{}';
    const items = entries.map(([key, item]) => `${inner}${JSON.stringify(key)}: ${format(item, inner)}`);
    return `{\n${items.join(',\n')}\n${indent}}`;
  }
  throw new Error(`出力できない値の型: ${type}`);
}

/**
 * 決定的なJSON文字列（末尾改行つき）を返す。
 * @param {unknown} value
 * @returns {string}
 */
export function stringifyDeterministic(value) {
  return `${format(value, '')}\n`;
}

/**
 * コードポイント順の比較関数。ロケール依存の localeCompare は使わない。
 * @param {string} a
 * @param {string} b
 */
export function compareIds(a, b) {
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}
