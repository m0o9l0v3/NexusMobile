/**
 * 検証レポートの組み立て。
 *
 * レポート自体もバイト決定的にするため、実行時刻や絶対パスを含めない。
 * 原本の所在は対応設定に書かれた相対パスで、出力先はファイル名だけで記録する。
 */

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';

import { compareIds } from './serialize.mjs';
import { TOLERANCES } from './anchors.mjs';

export const REPORT_VERSION = '1.0.0';
export const TOOL_NAME = 'map-dataset';

/**
 * @param {string|Buffer} content
 * @returns {string}
 */
export function sha256(content) {
  return createHash('sha256').update(content).digest('hex');
}

/**
 * @param {string} filePath
 * @returns {string}
 */
export function sha256File(filePath) {
  return sha256(readFileSync(filePath));
}

/**
 * メートル値をレポート用に丸める（比較・判定は丸め前の値で行う）。
 * @param {number} value
 */
function meters(value) {
  return Number(value.toFixed(6));
}

/**
 * @param {import('./anchors.mjs').FloorTransformResult} transform
 */
function formatTransform(transform) {
  return {
    floor_id: transform.floor_id,
    building_id: transform.building_id,
    status: transform.status,
    origin: { longitude: transform.origin.longitude, latitude: transform.origin.latitude },
    anchor_counts: transform.anchor_counts,
    params:
      transform.params === null
        ? null
        : {
            translation_east_m: meters(transform.params.translation_east_m),
            translation_north_m: meters(transform.params.translation_north_m),
            rotation_rad: Number(transform.params.rotation_rad.toFixed(12)),
            scale: Number(transform.params.scale.toFixed(12)),
          },
    metrics:
      transform.metrics === null
        ? null
        : {
            fit_rms_m: meters(transform.metrics.fit_rms_m),
            fit_max_m: meters(transform.metrics.fit_max_m),
            check_max_m: meters(transform.metrics.check_max_m),
            roundtrip_max_m: meters(transform.metrics.roundtrip_max_m),
            rounding_max_m: meters(transform.metrics.rounding_max_m),
          },
    tolerances: TOLERANCES,
    per_anchor: transform.per_anchor.map((metric) => ({
      anchor_id: metric.anchor_id,
      role: metric.role,
      residual_m: meters(metric.residual_m),
      roundtrip_m: meters(metric.roundtrip_m),
      rounding_m: meters(metric.rounding_m),
    })),
  };
}

/**
 * @param {import('./findings.mjs').Finding} finding
 */
function formatFinding(finding) {
  /** @type {Record<string, unknown>} */
  const value = { code: finding.code, message: finding.message };
  if (finding.canonical_id !== undefined) value.canonical_id = finding.canonical_id;
  if (finding.source !== undefined) value.source = finding.source;
  return value;
}

/**
 * @typedef {object} ReportInput
 * @property {string} command
 * @property {boolean} ok
 * @property {{path: string, sha256: string}|null} config
 * @property {{key: string, kind: string, path: string, sha256: string}[]} inputs
 * @property {{file: string, sha256: string, bytes: number}|null} output
 * @property {{source_records: number, included: number, excluded: number, failed: number}|null} counts
 * @property {{code: string, description: string, owner?: string}[]} blockers
 * @property {import('./anchors.mjs').FloorTransformResult[]} transforms
 * @property {import('./build.mjs').TraceEntry[]} trace
 * @property {import('./findings.mjs').Findings} findings
 * @property {boolean} [determinismChecked]
 * @property {boolean} [draftAccepted] --allow-draft で blocker を残したまま出力したか。
 */

/**
 * @param {ReportInput} input
 * @returns {Record<string, unknown>}
 */
export function buildReport(input) {
  const blockers = [...input.blockers].sort((a, b) => compareIds(a.code, b.code));
  return {
    report_version: REPORT_VERSION,
    tool: TOOL_NAME,
    command: input.command,
    status: input.ok ? 'ok' : 'failed',
    deterministic_generation_checked: input.determinismChecked ?? false,
    draft_accepted: input.draftAccepted ?? false,
    config: input.config,
    inputs: [...input.inputs].sort((a, b) => compareIds(a.key, b.key)),
    output: input.output,
    counts: input.counts,
    publish_readiness: {
      // 実データの不足を成功として扱わないため、blocker が1件でもあれば false。
      ready: input.ok && blockers.length === 0,
      blockers,
    },
    transforms: input.transforms.map(formatTransform),
    trace: input.trace,
    errors: input.findings.errors.map(formatFinding),
    warnings: input.findings.warnings.map(formatFinding),
  };
}

/**
 * @param {string} filePath
 */
export function baseName(filePath) {
  return path.basename(filePath);
}
