/**
 * 依存ゼロの読み取り専用 XLSX リーダー。
 *
 * Node 標準の `zlib.inflateRawSync` と ZIP central directory 解析だけで
 * `.xlsx`（Office Open XML SpreadsheetML）からセル値を取り出す。
 *
 * 方針:
 * - 原本を書き換えない（読み取りのみ）。
 * - セル値を勝手に型変換しない。日付書式のセルは生のシリアル値と
 *   `date_formatted` 種別を返し、解釈は呼び出し側の明示設定に委ねる。
 * - 想定外の構造は握りつぶさず例外にする。
 *
 * 外部ライブラリを採用しなかった理由は docs/e1-6-map-dataset-conversion.md を参照。
 */

import { inflateRawSync } from 'node:zlib';

const SIGNATURE_END_OF_CENTRAL_DIRECTORY = 0x06054b50;
const SIGNATURE_CENTRAL_FILE_HEADER = 0x02014b50;
const COMPRESSION_STORED = 0;
const COMPRESSION_DEFLATE = 8;

/**
 * @typedef {object} ZipEntry
 * @property {string} name
 * @property {number} compressionMethod
 * @property {number} compressedSize
 * @property {number} localHeaderOffset
 */

/**
 * ZIP central directory を読み、エントリ名 -> 展開済み Buffer の取得器を返す。
 * @param {Buffer} buffer
 * @returns {{names: string[], read: (name: string) => Buffer}}
 */
function openZip(buffer) {
  let eocd = -1;
  const searchStart = Math.max(0, buffer.length - 22 - 0xffff);
  for (let i = buffer.length - 22; i >= searchStart; i -= 1) {
    if (buffer.readUInt32LE(i) === SIGNATURE_END_OF_CENTRAL_DIRECTORY) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw new Error('ZIP の end of central directory が見つからない。xlsx ファイルではない可能性がある。');

  const entryCount = buffer.readUInt16LE(eocd + 10);
  const centralDirectoryOffset = buffer.readUInt32LE(eocd + 16);
  if (entryCount === 0xffff || centralDirectoryOffset === 0xffffffff) {
    throw new Error('ZIP64 形式の xlsx には未対応。通常形式で保存し直してから再実行する。');
  }

  /** @type {Map<string, ZipEntry>} */
  const entries = new Map();
  let cursor = centralDirectoryOffset;
  for (let i = 0; i < entryCount; i += 1) {
    if (buffer.readUInt32LE(cursor) !== SIGNATURE_CENTRAL_FILE_HEADER) {
      throw new Error(`ZIP central directory の署名が不正（entry ${i}）。`);
    }
    const compressionMethod = buffer.readUInt16LE(cursor + 10);
    const compressedSize = buffer.readUInt32LE(cursor + 20);
    const nameLength = buffer.readUInt16LE(cursor + 28);
    const extraLength = buffer.readUInt16LE(cursor + 30);
    const commentLength = buffer.readUInt16LE(cursor + 32);
    const localHeaderOffset = buffer.readUInt32LE(cursor + 42);
    const name = buffer.toString('utf8', cursor + 46, cursor + 46 + nameLength);
    entries.set(name, { name, compressionMethod, compressedSize, localHeaderOffset });
    cursor += 46 + nameLength + extraLength + commentLength;
  }

  /** @param {string} name */
  const read = (name) => {
    const entry = entries.get(name);
    if (!entry) throw new Error(`xlsx 内に ${name} が存在しない。`);
    const nameLength = buffer.readUInt16LE(entry.localHeaderOffset + 26);
    const extraLength = buffer.readUInt16LE(entry.localHeaderOffset + 28);
    const start = entry.localHeaderOffset + 30 + nameLength + extraLength;
    const raw = buffer.subarray(start, start + entry.compressedSize);
    if (entry.compressionMethod === COMPRESSION_STORED) return Buffer.from(raw);
    if (entry.compressionMethod === COMPRESSION_DEFLATE) return inflateRawSync(raw);
    throw new Error(`未対応の ZIP 圧縮方式 ${entry.compressionMethod}（${name}）。`);
  };

  return { names: [...entries.keys()], read };
}

/**
 * XML の実体参照を復元する。
 * @param {string} text
 */
function decodeXmlText(text) {
  return text.replace(/&(#x?[0-9a-fA-F]+|amp|lt|gt|quot|apos);/g, (match, entity) => {
    switch (entity) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
      default:
        if (entity.startsWith('#x') || entity.startsWith('#X')) {
          return String.fromCodePoint(Number.parseInt(entity.slice(2), 16));
        }
        if (entity.startsWith('#')) {
          return String.fromCodePoint(Number.parseInt(entity.slice(1), 10));
        }
        return match;
    }
  });
}

/**
 * 開始タグの属性を取り出す。
 * @param {string} attributeSource
 * @returns {Record<string, string>}
 */
function parseAttributes(attributeSource) {
  /** @type {Record<string, string>} */
  const attributes = {};
  const pattern = /([A-Za-z_:][\w.:-]*)\s*=\s*"([^"]*)"/g;
  let match;
  while ((match = pattern.exec(attributeSource)) !== null) {
    attributes[match[1]] = decodeXmlText(match[2]);
  }
  return attributes;
}

/**
 * `<t>` 要素のテキストを連結する（リッチテキストの `<r><t>` も含む）。
 * @param {string} xml
 */
function joinTextNodes(xml) {
  let text = '';
  const pattern = /<t\b[^>]*?(?:\/>|>([\s\S]*?)<\/t>)/g;
  let match;
  while ((match = pattern.exec(xml)) !== null) {
    text += decodeXmlText(match[1] ?? '');
  }
  return text;
}

/** Office 組み込みの日付・時刻書式ID。 */
const BUILTIN_DATE_FORMAT_IDS = new Set([
  14, 15, 16, 17, 18, 19, 20, 21, 22, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 45, 46, 47, 50, 51, 52, 53, 54, 55, 56,
  57, 58,
]);

/**
 * 書式コードが日付・時刻を表すか。
 * @param {string} formatCode
 */
function looksLikeDateFormat(formatCode) {
  const withoutLiterals = formatCode.replace(/"[^"]*"/g, '').replace(/\[[^\]]*\]/g, '');
  return /[ymdhs]/i.test(withoutLiterals);
}

/**
 * @typedef {'shared_string'|'inline_string'|'string'|'number'|'boolean'|'error'|'date_formatted'} CellKind
 */

/**
 * @typedef {object} Cell
 * @property {string} ref A1 形式の参照。
 * @property {string} column 列記号（A, B, ...）。
 * @property {string|number|boolean} value
 * @property {CellKind} kind
 */

/**
 * @typedef {object} SheetRow
 * @property {number} row 1始まりの行番号（ファイル上の実番号）。
 * @property {Map<string, Cell>} cells 列記号 -> セル。
 */

/**
 * xlsx を開く。
 * @param {Buffer} buffer
 */
export function openWorkbook(buffer) {
  const zip = openZip(buffer);

  /** @type {string[]} */
  const sharedStrings = [];
  if (zip.names.includes('xl/sharedStrings.xml')) {
    const xml = zip.read('xl/sharedStrings.xml').toString('utf8');
    const pattern = /<si\b[^>]*?(?:\/>|>([\s\S]*?)<\/si>)/g;
    let match;
    while ((match = pattern.exec(xml)) !== null) {
      sharedStrings.push(joinTextNodes(match[1] ?? ''));
    }
  }

  /** @type {boolean[]} 各 cellXf が日付書式かどうか。 */
  const styleIsDate = [];
  if (zip.names.includes('xl/styles.xml')) {
    const xml = zip.read('xl/styles.xml').toString('utf8');
    /** @type {Map<number, string>} */
    const customFormats = new Map();
    const numFmtPattern = /<numFmt\b([^>]*)\/>/g;
    let numFmtMatch;
    while ((numFmtMatch = numFmtPattern.exec(xml)) !== null) {
      const attributes = parseAttributes(numFmtMatch[1]);
      const id = Number(attributes.numFmtId);
      if (Number.isInteger(id)) customFormats.set(id, attributes.formatCode ?? '');
    }
    const cellXfsMatch = /<cellXfs\b[^>]*>([\s\S]*?)<\/cellXfs>/.exec(xml);
    if (cellXfsMatch) {
      const xfPattern = /<xf\b([^>]*?)(?:\/>|>[\s\S]*?<\/xf>)/g;
      let xfMatch;
      while ((xfMatch = xfPattern.exec(cellXfsMatch[1])) !== null) {
        const attributes = parseAttributes(xfMatch[1]);
        const id = Number(attributes.numFmtId ?? '0');
        const custom = customFormats.get(id);
        styleIsDate.push(BUILTIN_DATE_FORMAT_IDS.has(id) || (custom !== undefined && looksLikeDateFormat(custom)));
      }
    }
  }

  const relationshipsXml = zip.read('xl/_rels/workbook.xml.rels').toString('utf8');
  /** @type {Map<string, string>} */
  const relationshipTargets = new Map();
  const relationshipPattern = /<Relationship\b([^>]*)\/>/g;
  let relationshipMatch;
  while ((relationshipMatch = relationshipPattern.exec(relationshipsXml)) !== null) {
    const attributes = parseAttributes(relationshipMatch[1]);
    if (attributes.Id && attributes.Target) relationshipTargets.set(attributes.Id, attributes.Target);
  }

  const workbookXml = zip.read('xl/workbook.xml').toString('utf8');
  /** @type {Map<string, string>} シート名 -> zip 内パス。 */
  const sheetPaths = new Map();
  /** @type {string[]} */
  const sheetNames = [];
  const sheetPattern = /<sheet\b([^>]*)\/>/g;
  let sheetMatch;
  while ((sheetMatch = sheetPattern.exec(workbookXml)) !== null) {
    const attributes = parseAttributes(sheetMatch[1]);
    const name = attributes.name;
    const relationshipId = attributes['r:id'];
    if (!name || !relationshipId) continue;
    const target = relationshipTargets.get(relationshipId);
    if (!target) throw new Error(`シート ${name} の関係先が workbook.xml.rels に存在しない。`);
    const path = target.startsWith('/') ? target.slice(1) : target.startsWith('xl/') ? target : `xl/${target}`;
    sheetNames.push(name);
    sheetPaths.set(name, path);
  }

  /**
   * シートの行を読む。空セルは cells に含めない。
   * @param {string} sheetName
   * @returns {SheetRow[]}
   */
  const readSheet = (sheetName) => {
    const path = sheetPaths.get(sheetName);
    if (!path) {
      throw new Error(`シート "${sheetName}" が存在しない。利用可能: ${sheetNames.join(' / ')}`);
    }
    const xml = zip.read(path).toString('utf8');
    /** @type {SheetRow[]} */
    const rows = [];
    const rowPattern = /<row\b([^>]*?)(?:\/>|>([\s\S]*?)<\/row>)/g;
    let rowMatch;
    while ((rowMatch = rowPattern.exec(xml)) !== null) {
      const rowAttributes = parseAttributes(rowMatch[1]);
      const rowNumber = Number(rowAttributes.r);
      if (!Number.isInteger(rowNumber)) continue;
      /** @type {Map<string, Cell>} */
      const cells = new Map();
      const body = rowMatch[2] ?? '';
      const cellPattern = /<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g;
      let cellMatch;
      while ((cellMatch = cellPattern.exec(body)) !== null) {
        const attributes = parseAttributes(cellMatch[1]);
        const ref = attributes.r ?? '';
        const column = ref.replace(/[0-9]/g, '');
        const inner = cellMatch[2] ?? '';
        const type = attributes.t ?? 'n';

        /** @type {string|number|boolean|null} */
        let value = null;
        /** @type {CellKind} */
        let kind = 'number';

        if (type === 'inlineStr') {
          const isMatch = /<is\b[^>]*>([\s\S]*?)<\/is>/.exec(inner);
          value = joinTextNodes(isMatch ? isMatch[1] : '');
          kind = 'inline_string';
        } else {
          const valueMatch = /<v\b[^>]*?(?:\/>|>([\s\S]*?)<\/v>)/.exec(inner);
          const rawValue = valueMatch ? decodeXmlText(valueMatch[1] ?? '') : null;
          if (rawValue === null || rawValue === '') {
            value = null;
          } else if (type === 's') {
            const index = Number(rawValue);
            value = sharedStrings[index] ?? '';
            kind = 'shared_string';
          } else if (type === 'str') {
            value = rawValue;
            kind = 'string';
          } else if (type === 'b') {
            value = rawValue === '1';
            kind = 'boolean';
          } else if (type === 'e') {
            value = rawValue;
            kind = 'error';
          } else {
            const numeric = Number(rawValue);
            if (!Number.isFinite(numeric)) {
              throw new Error(`セル ${ref} の数値 "${rawValue}" を解釈できない。`);
            }
            value = numeric;
            const styleIndex = Number(attributes.s ?? '0');
            kind = styleIsDate[styleIndex] === true ? 'date_formatted' : 'number';
          }
        }

        if (value === null || value === '') continue;
        cells.set(column, { ref, column, value, kind });
      }
      rows.push({ row: rowNumber, cells });
    }
    return rows;
  };

  return { sheetNames, readSheet };
}
