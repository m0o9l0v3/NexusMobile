/**
 * survey CLI: 現地測量の記録から建物の Polygon を作る。
 *
 * 入力・出力のパスはすべて引数で指定する。入力（測量設定・野帳）は読むだけで変更しない。
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';

import { stringifyDeterministic } from '../serialize.mjs';
import { findPathCollisions } from '../paths.mjs';
import { parseObservations, parseProject, provenanceRows, runSurvey, SURVEY_VERSION } from './survey.mjs';

const HELP = `survey ${SURVEY_VERSION} — 現地測量（既知の点からの測距）から建物の Polygon を作る

使い方:
  survey --project <測量設定.json> --observations <野帳.csv> --report <レポート.json>
         [--out <建物.geojson>] [--provenance-out <出典の行.csv>] [--allow-remeasure]

  --report           残差・精度・再測定の対象を書いたレポート。常に書き出す。
  --out              建物の GeoJSON（map-dataset の geojson 原本と同じ形）。
                     再測定の対象が残っている間は書き出さない。
  --provenance-out   map-data/normalized/building-provenance.csv に足す行。
  --allow-remeasure  再測定の対象が残っていても --out を書き出す（下見・練習用）。

終了コード:
  0  すべて許容値内
  1  再測定の対象がある、または計算できない
  2  引数・入力ファイルの誤り

手順と許容値: docs/map-data/campus-survey-plan.md`;

/**
 * @param {string[]} argv
 * @param {{log: (line: string) => void, error: (line: string) => void}} io
 * @returns {number}
 */
export function run(argv, io) {
  /** @type {ReturnType<typeof parseArgs>} */
  let parsed;
  try {
    parsed = parseArgs({
      args: argv,
      options: {
        project: { type: 'string' },
        observations: { type: 'string' },
        report: { type: 'string' },
        out: { type: 'string' },
        'provenance-out': { type: 'string' },
        'allow-remeasure': { type: 'boolean', default: false },
        help: { type: 'boolean', default: false },
      },
      strict: true,
    });
  } catch (error) {
    io.error(String(error instanceof Error ? error.message : error));
    return 2;
  }
  const v = /** @type {Record<string, string|boolean|undefined>} */ (parsed.values);
  if (v.help) {
    io.log(HELP);
    return 0;
  }
  const projectPath = /** @type {string|undefined} */ (v.project);
  const obsPath = /** @type {string|undefined} */ (v.observations);
  const reportPath = /** @type {string|undefined} */ (v.report);
  if (!projectPath || !obsPath || !reportPath) {
    io.error('--project、--observations、--report は必須。--help を参照。');
    return 2;
  }
  const outPath = /** @type {string|undefined} */ (v.out);
  const provPath = /** @type {string|undefined} */ (v['provenance-out']);
  /** @type {{label: string, path: string}[]} */
  const outputs = [];
  if (reportPath) outputs.push({ label: '--report', path: path.resolve(reportPath) });
  if (outPath) outputs.push({ label: '--out', path: path.resolve(outPath) });
  if (provPath) outputs.push({ label: '--provenance-out', path: path.resolve(provPath) });
  const collisions = findPathCollisions(outputs, [
    { label: '--project', path: path.resolve(projectPath) },
    { label: '--observations', path: path.resolve(obsPath) },
  ]);
  if (collisions.length > 0) {
    for (const c of collisions) io.error(c);
    return 2;
  }

  let rawProject;
  let obsText;
  try {
    rawProject = JSON.parse(readFileSync(projectPath, 'utf8'));
    obsText = readFileSync(obsPath, 'utf8');
  } catch (error) {
    io.error(`入力を読めない: ${String(error)}`);
    return 2;
  }
  const { project, flags: projectFlags } = parseProject(rawProject);
  const { rows, flags: obsFlags } = parseObservations(obsText);
  const inputFlags = [...projectFlags, ...obsFlags];
  const outcome = inputFlags.length > 0 ? null : runSurvey(project, rows);
  const flags = outcome ? outcome.flags : inputFlags;
  const report = {
    tool: 'map-dataset/survey',
    survey_version: SURVEY_VERSION,
    survey_id: project.survey_id ?? null,
    ok: outcome ? outcome.ok : false,
    flags,
    ...(outcome
      ? {
          origin: outcome.origin,
          tolerances: outcome.tolerances,
          adjustment: outcome.adjustment,
          reference_checks: outcome.reference_checks,
          buildings: outcome.buildings,
        }
      : {}),
  };
  write(reportPath, stringifyDeterministic(report));

  for (const f of flags) io.error(`[${f.severity}] ${f.code}: ${f.message}`);
  if (!outcome) return 2;
  const hasError = flags.some((f) => f.severity === 'error');
  const writeOut = outcome.geojson && !hasError && (outcome.ok || v['allow-remeasure'] === true);
  if (outPath && writeOut) write(outPath, stringifyDeterministic(outcome.geojson));
  if (provPath && writeOut) write(provPath, provenanceRows(outcome, project, path.basename(obsPath)));
  if (outcome.ok) {
    io.log(`すべて許容値内（建物 ${outcome.buildings.length} 棟、自由度 ${outcome.adjustment?.degrees_of_freedom}）。`);
    return 0;
  }
  io.error(outPath && !writeOut ? '再測定の対象があるため、GeoJSON は書き出していない。' : '再測定の対象がある。');
  return 1;
}

/** @param {string} file @param {string} content */
function write(file, content) {
  mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
  writeFileSync(file, content);
}
