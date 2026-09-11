/**
 * map-dataset CLI。
 *
 *   generate  対応設定に従って MapDataset GeoJSON を決定的に生成する。
 *   validate  既存または生成済みの GeoJSON を検証する。
 *
 * 入力・出力・検証レポートのパスはすべて引数で指定する。
 * 絶対パスや特定利用者の環境をコードへ埋め込まない。
 */

import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';

import { ConfigError, loadConfig } from './config.mjs';
import { buildDataset } from './build.mjs';
import { validateDataset, validateDatasetFile, DEFAULT_SCHEMA_PATH } from './validate.mjs';
import { stringifyDeterministic } from './serialize.mjs';
import { baseName, buildReport, sha256, sha256File } from './report.mjs';
import { Findings } from './findings.mjs';
import { findPathCollisions } from './paths.mjs';

export const VERSION = '0.1.0';

const HELP = `map-dataset ${VERSION} — Nexus MapDataset GeoJSON の再生成・検証（E1-6 / Issue #15）

使い方:
  map-dataset generate --config <対応設定.json> --input-root <原本フォルダ> --out <出力.geojson>
                       [--report <検証レポート.json>] [--schema <スキーマ.json>]
                       [--check-determinism] [--allow-draft]
  map-dataset validate --input <対象.geojson> [--report <検証レポート.json>] [--schema <スキーマ.json>]
  map-dataset --help | --version

共通オプション:
  --schema <path>        MapDataset JSON Schema のパス。
                         既定: docs/schemas/map-dataset-geojson-v1.schema.json
  --report <path>        検証レポート（JSON）の出力先。省略時は書き出さない。

generate のオプション:
  --config <path>        対応設定（どの原本のどの地物をどの canonical ID で採用するか）。
  --input-root <dir>     対応設定内の相対パスを解決する原本フォルダ。原本は読み取りのみ。
  --out <path>           生成する MapDataset GeoJSON の出力先。
  --check-determinism    同じ入力から2回生成し、バイト単位で一致することを確認する。
  --allow-draft          publish_readiness に blocker が残っていても暫定出力を許可する。
                         既定では blocker が1件でもあれば失敗し、出力を書き出さない。
                         不完全な実データを完成品と誤認しないための既定値なので、
                         暫定確認のときだけ明示的に付ける。

validate のオプション:
  --input <path>         検証する GeoJSON。

終了コード:
  0  検証に合格した
  1  検証エラーまたは未解消の publish blocker がある（出力は書き出さない）
  2  引数または対応設定の誤り

出力先（--out / --report）に原本・対応設定・スキーマ・検証対象と同じ実体は指定できない。
symlink とハードリンク経由の指定も拒否する。

原本は絶対に変更しない。未確認値・座標系不明・単位不明の値は推定せず検証エラーにする。
詳細は docs/e1-6-map-dataset-conversion.md を参照。
`;

/**
 * @param {import('./findings.mjs').Findings} findings
 * @param {(line: string) => void} write
 */
function printFindings(findings, write) {
  for (const finding of findings.errors) {
    const where = finding.source ? ` [${describeSource(finding.source)}]` : '';
    write(`ERROR ${finding.code}: ${finding.message}${where}`);
  }
  for (const finding of findings.warnings) {
    const where = finding.source ? ` [${describeSource(finding.source)}]` : '';
    write(`WARN  ${finding.code}: ${finding.message}${where}`);
  }
}

/**
 * @param {import('./findings.mjs').SourceRef} source
 */
function describeSource(source) {
  const parts = [source.file];
  if (source.sheet !== undefined) parts.push(`::${source.sheet}`);
  if (source.row !== undefined) parts.push(`#${source.row}`);
  if (source.feature_index !== undefined) parts.push(`#feature[${source.feature_index}]`);
  return parts.join('');
}

/**
 * @param {string} filePath
 * @param {string} content
 */
function writeTextFile(filePath, content) {
  mkdirSync(path.dirname(path.resolve(filePath)), { recursive: true });
  writeFileSync(filePath, content, 'utf8');
}

/**
 * 出力先が入力と同じ実体を指していないことを確認する。衝突があれば実行前に止める。
 *
 * @param {import('./paths.mjs').LabeledPath[]} outputs
 * @param {import('./paths.mjs').LabeledPath[]} inputs
 */
function assertNoPathCollision(outputs, inputs) {
  const collisions = findPathCollisions(outputs, inputs);
  if (collisions.length > 0) {
    throw new ConfigError(`出力先が入力と衝突している:\n${collisions.map((line) => `  - ${line}`).join('\n')}`);
  }
}

/**
 * @param {import('./config.mjs').LoadedConfig} loaded
 */
function describeInputs(loaded) {
  return Object.entries(loaded.config.sources).map(([key, spec]) => ({
    key,
    kind: spec.kind,
    path: spec.kind === 'inline' ? `(inline: ${spec.origin_note})` : spec.path,
    sha256: spec.kind === 'inline' ? '' : sha256File(loaded.resolveInput(spec.path)),
  }));
}

/**
 * @param {Record<string, string|boolean|undefined>} values
 * @param {string} name
 * @returns {string}
 */
function requireOption(values, name) {
  const value = values[name];
  if (typeof value !== 'string' || value === '') {
    throw new ConfigError(`--${name} は必須。`);
  }
  return value;
}

/**
 * @param {string[]} argv
 * @param {{log: (line: string) => void, error: (line: string) => void}} io
 * @returns {number} 終了コード
 */
export function run(argv, io) {
  /** @type {import('node:util').ParseArgsConfig['options']} */
  const options = {
    help: { type: 'boolean', short: 'h' },
    version: { type: 'boolean' },
    config: { type: 'string' },
    'input-root': { type: 'string' },
    out: { type: 'string' },
    input: { type: 'string' },
    report: { type: 'string' },
    schema: { type: 'string' },
    'check-determinism': { type: 'boolean' },
    'allow-draft': { type: 'boolean' },
  };

  /** @type {{values: Record<string, string|boolean|undefined>, positionals: string[]}} */
  let parsed;
  try {
    parsed = /** @type {any} */ (parseArgs({ args: argv, options, allowPositionals: true }));
  } catch (error) {
    io.error(String(error instanceof Error ? error.message : error));
    io.error(HELP);
    return 2;
  }

  const { values, positionals } = parsed;
  const command = positionals[0];

  if (values.version === true) {
    io.log(VERSION);
    return 0;
  }
  if (values.help === true) {
    io.log(HELP);
    return 0;
  }
  if (command === undefined) {
    io.error('コマンドを指定する（generate または validate）。');
    io.error(HELP);
    return 2;
  }

  const schemaPath = typeof values.schema === 'string' ? values.schema : DEFAULT_SCHEMA_PATH;

  try {
    if (command === 'generate') return runGenerate(values, schemaPath, io);
    if (command === 'validate') return runValidate(values, schemaPath, io);
  } catch (error) {
    if (error instanceof ConfigError) {
      io.error(String(error.message));
      return 2;
    }
    throw error;
  }

  io.error(`未知のコマンド: ${command}`);
  io.error(HELP);
  return 2;
}

/**
 * @param {Record<string, string|boolean|undefined>} values
 * @param {string} schemaPath
 * @param {{log: (line: string) => void, error: (line: string) => void}} io
 */
function runGenerate(values, schemaPath, io) {
  const configPath = requireOption(values, 'config');
  const inputRoot = requireOption(values, 'input-root');
  const outPath = requireOption(values, 'out');
  const reportPath = typeof values.report === 'string' ? values.report : null;

  const loaded = loadConfig({ configPath, inputRoot });

  // 原本・対応設定・スキーマを出力先に指定できないようにする（原本は読み取り専用）。
  /** @type {import('./paths.mjs').LabeledPath[]} */
  const inputPaths = [
    { label: '--config', path: configPath },
    { label: '--schema', path: schemaPath },
  ];
  for (const [key, spec] of Object.entries(loaded.config.sources)) {
    if (spec.kind === 'inline') continue;
    inputPaths.push({ label: `原本 ${key}`, path: loaded.resolveInput(spec.path) });
  }
  /** @type {import('./paths.mjs').LabeledPath[]} */
  const outputPaths = [{ label: '--out', path: outPath }];
  if (reportPath !== null) outputPaths.push({ label: '--report', path: reportPath });
  assertNoPathCollision(outputPaths, inputPaths);

  const built = buildDataset(loaded);

  const findings = new Findings();
  findings.merge(built.findings);

  /** @type {string|null} */
  let serialized = null;
  if (built.dataset !== null) {
    // 生成物は書き出す前に validate と同じ検証経路へ通す。
    findings.merge(
      validateDataset(built.dataset, { schemaPath, reservedIds: loaded.config.reserved_ids ?? [] }),
    );
    serialized = stringifyDeterministic(built.dataset);
  }

  let determinismChecked = false;
  if (values['check-determinism'] === true && serialized !== null) {
    const second = buildDataset(loadConfig({ configPath, inputRoot }));
    if (second.dataset === null) {
      findings.error('determinism_check_failed', '2回目の生成が失敗した。');
    } else {
      const secondSerialized = stringifyDeterministic(second.dataset);
      if (secondSerialized !== serialized) {
        findings.error('determinism_check_failed', '同じ入力・設定から2回生成した結果がバイト単位で一致しない。');
      } else {
        determinismChecked = true;
      }
    }
  }

  // 既定は厳格。未解消の blocker がある状態を成功として扱わない（Issue #15）。
  // 暫定出力が必要なときだけ --allow-draft で明示的に降格する。
  const blockers = built.blockers;
  const allowDraft = values['allow-draft'] === true;
  for (const blocker of blockers) {
    const message = `${blocker.code}: ${blocker.description}`;
    if (allowDraft) {
      findings.warn('publish_readiness_blocked', message);
    } else {
      findings.error('publish_readiness_blocked', message);
    }
  }

  const ok = findings.ok;
  if (ok && serialized !== null) {
    writeTextFile(outPath, serialized);
  }

  const report = buildReport({
    command: 'generate',
    ok,
    config: { path: baseName(configPath), sha256: sha256File(configPath) },
    inputs: describeInputs(loaded),
    output:
      ok && serialized !== null
        ? { file: baseName(outPath), sha256: sha256(serialized), bytes: Buffer.byteLength(serialized, 'utf8') }
        : null,
    counts: built.counts,
    blockers,
    transforms: built.transforms,
    trace: built.trace,
    findings,
    determinismChecked,
    draftAccepted: allowDraft && blockers.length > 0,
  });
  if (reportPath !== null) writeTextFile(reportPath, stringifyDeterministic(report));

  printFindings(findings, ok ? io.log : io.error);
  io.log(
    `counts: source_records=${built.counts.source_records} included=${built.counts.included} excluded=${built.counts.excluded} failed=${built.counts.failed}`,
  );
  for (const transform of built.transforms) {
    io.log(
      `transform ${transform.floor_id}: ${transform.status} (fit=${transform.anchor_counts.fit} check=${transform.anchor_counts.check})`,
    );
  }
  const readiness = /** @type {{ready: boolean, blockers: {code: string, description: string}[]}} */ (
    report.publish_readiness
  );
  io.log(`publish_readiness: ${readiness.ready ? 'ready' : 'blocked'}`);
  for (const blocker of readiness.blockers) {
    io.log(`  blocker ${blocker.code}: ${blocker.description}`);
  }

  if (!ok) {
    if (blockers.length > 0 && !allowDraft) {
      io.error(
        `未解消の publish blocker が ${blockers.length} 件ある。実データが揃うまで完成品として出力しない。暫定出力が必要なら --allow-draft を付ける。`,
      );
    }
    io.error('生成に失敗した。出力は書き出していない。');
    return 1;
  }
  if (blockers.length > 0) {
    io.log(`DRAFT: --allow-draft により blocker ${blockers.length} 件を残したまま暫定出力した。公開はできない。`);
  }
  io.log(`wrote: ${outPath}`);
  if (reportPath !== null) io.log(`report: ${reportPath}`);
  return 0;
}

/**
 * @param {Record<string, string|boolean|undefined>} values
 * @param {string} schemaPath
 * @param {{log: (line: string) => void, error: (line: string) => void}} io
 */
function runValidate(values, schemaPath, io) {
  const inputPath = requireOption(values, 'input');
  const reportPath = typeof values.report === 'string' ? values.report : null;

  assertNoPathCollision(
    reportPath === null ? [] : [{ label: '--report', path: reportPath }],
    [
      { label: '--input', path: inputPath },
      { label: '--schema', path: schemaPath },
    ],
  );

  const { findings } = validateDatasetFile(inputPath, { schemaPath });
  const ok = findings.ok;

  const report = buildReport({
    command: 'validate',
    ok,
    config: null,
    inputs: [{ key: 'dataset', kind: 'geojson', path: baseName(inputPath), sha256: sha256File(inputPath) }],
    output: null,
    counts: null,
    blockers: [],
    transforms: [],
    trace: [],
    findings,
  });
  if (reportPath !== null) writeTextFile(reportPath, stringifyDeterministic(report));

  printFindings(findings, ok ? io.log : io.error);
  if (!ok) {
    io.error(`検証に失敗した: ${inputPath}`);
    return 1;
  }
  io.log(`valid: ${inputPath}`);
  if (reportPath !== null) io.log(`report: ${reportPath}`);
  return 0;
}
