/**
 * テスト補助。
 *
 * 異常系は「契約を1点だけ壊した最小合成データ」で確認する。
 * 実測原本の値は複製しない。
 */

import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

export const FIXTURES_DIR = path.resolve(here, 'fixtures');
export const REPO_SCHEMA_PATH = path.resolve(here, '../../../docs/schemas/map-dataset-geojson-v1.schema.json');
export const REPO_EXAMPLE_PATH = path.resolve(
  here,
  '../../../docs/schemas/examples/map-dataset-geojson-v1.example.json',
);

/**
 * 一時ディレクトリを作り、渡した内容を書き出す。
 * @param {Record<string, unknown|string>} files 相対パス -> JSON 値または文字列。
 * @returns {string} 一時ディレクトリの絶対パス。
 */
export function makeWorkspace(files) {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'map-dataset-test-'));
  for (const [name, content] of Object.entries(files)) {
    const target = path.join(dir, name);
    writeFileSync(target, typeof content === 'string' ? content : `${JSON.stringify(content, null, 2)}\n`, 'utf8');
  }
  return dir;
}

/**
 * fixtures 配下の JSON を読み込んで複製する。
 * @param {string} name
 * @returns {any}
 */
export function loadFixture(name) {
  return JSON.parse(readFileSync(path.join(FIXTURES_DIR, name), 'utf8'));
}

/**
 * 最小の正常系設定（建物1件のみ）を作る。異常系テストはこれを1点だけ壊して使う。
 * @returns {{source: any, config: any}}
 */
export function minimalCase() {
  const source = {
    type: 'FeatureCollection',
    features: [
      {
        type: 'Feature',
        geometry: {
          type: 'Polygon',
          coordinates: [
            [
              [141.62, 42.78],
              [141.621, 42.78],
              [141.621, 42.781],
              [141.62, 42.781],
              [141.62, 42.78],
            ],
          ],
        },
        properties: { id: 'mb', name: '教室棟' },
      },
    ],
  };
  const config = {
    config_version: '1.0.0',
    dataset_name: 'minimal',
    sources: { src: { kind: 'geojson', path: 'source.geojson', source_id_property: 'id' } },
    floors: [],
    features: [
      {
        source: 'src',
        source_id: 'mb',
        decision: 'include',
        feature_type: 'building',
        canonical_id: 'mb',
        name: { policy: 'from_source' },
      },
    ],
  };
  return { source, config };
}

/**
 * CLI を関数として実行し、出力と終了コードを返す。
 * @param {string[]} argv
 */
export async function runCli(argv) {
  const { run } = await import('../src/cli.mjs');
  /** @type {string[]} */
  const out = [];
  /** @type {string[]} */
  const err = [];
  const code = run(argv, { log: (line) => out.push(line), error: (line) => err.push(line) });
  return { code, stdout: out.join('\n'), stderr: err.join('\n') };
}

/**
 * 生成を実行し、findings を返す（ファイルは書き出さない）。
 * @param {string} dir
 * @param {string} configName
 */
export async function buildInDir(dir, configName = 'config.json') {
  const { loadConfig } = await import('../src/config.mjs');
  const { buildDataset } = await import('../src/build.mjs');
  const loaded = loadConfig({ configPath: path.join(dir, configName), inputRoot: dir });
  return buildDataset(loaded);
}

/**
 * findings に指定コードのエラーが含まれるか。
 * @param {import('../src/findings.mjs').Findings} findings
 * @param {string} code
 */
export function hasError(findings, code) {
  return findings.errors.some((finding) => finding.code === code);
}

/**
 * @param {import('../src/findings.mjs').Findings} findings
 */
export function errorCodes(findings) {
  return findings.errors.map((finding) => finding.code);
}
