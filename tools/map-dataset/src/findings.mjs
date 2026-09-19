/**
 * 検証所見（エラー・警告）の収集。
 *
 * 変換処理は最初のエラーで停止せず、可能な限り全件を集めてから失敗させる。
 * 原本のどこ由来かを必ず `source` に残し、生成物だけを見ても追跡できるようにする。
 */

/**
 * @typedef {object} SourceRef 原本内の位置。
 * @property {string} file 原本ファイル（--input-root からの相対パス）。
 * @property {string} [sheet] Excelのシート名。
 * @property {number} [row] Excelの行番号（1始まり、ファイル上の実行番号）。
 * @property {number} [feature_index] GeoJSONのFeature index（0始まり）。
 * @property {string|null} [source_feature_id] 原本のFeature直下 `id`。
 * @property {string|null} [source_property_id] 原本の `properties.id`。
 */

/**
 * @typedef {object} Finding
 * @property {'error'|'warning'} severity
 * @property {string} code 機械可読な理由コード。
 * @property {string} message 日本語の説明。
 * @property {SourceRef} [source]
 * @property {string} [canonical_id]
 */

export class Findings {
  constructor() {
    /** @type {Finding[]} */
    this.items = [];
  }

  /**
   * @param {string} code
   * @param {string} message
   * @param {{source?: SourceRef, canonical_id?: string}} [ctx]
   */
  error(code, message, ctx = {}) {
    this.items.push({ severity: 'error', code, message, ...ctx });
  }

  /**
   * @param {string} code
   * @param {string} message
   * @param {{source?: SourceRef, canonical_id?: string}} [ctx]
   */
  warn(code, message, ctx = {}) {
    this.items.push({ severity: 'warning', code, message, ...ctx });
  }

  get errors() {
    return this.items.filter((f) => f.severity === 'error');
  }

  get warnings() {
    return this.items.filter((f) => f.severity === 'warning');
  }

  get ok() {
    return this.errors.length === 0;
  }

  /** @param {Findings} other */
  merge(other) {
    this.items.push(...other.items);
  }
}
