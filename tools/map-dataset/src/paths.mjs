/**
 * 入力と出力のパス衝突検出。
 *
 * 原本は絶対に変更しない、という契約をCLI引数のレベルで守るための防具。
 * `--out` / `--report` に原本・対応設定・スキーマ・検証対象と同じ実体を
 * 指定できないようにする。
 *
 * 文字列としてのパス比較だけでは symlink とハードリンクを取りこぼすため、
 * `realpath` で正規化したうえで、実在するファイルは inode（dev:ino）でも比較する。
 */

import { realpathSync, statSync } from 'node:fs';
import path from 'node:path';

/**
 * @typedef {object} PathIdentity
 * @property {string} given 利用者が指定したパス。
 * @property {string} real symlink を解決した正規パス。未作成なら親ディレクトリを解決して合成する。
 * @property {string|null} inode `dev:ino`。実在しない場合は null。
 */

/**
 * パスの同一性判定に使う識別情報を求める。
 * @param {string} candidate
 * @returns {PathIdentity}
 */
export function identifyPath(candidate) {
  const resolved = path.resolve(candidate);
  /** @type {string} */
  let real;
  try {
    real = realpathSync(resolved);
  } catch {
    // 未作成の出力先は、実在する親ディレクトリを解決してから合成する。
    try {
      real = path.join(realpathSync(path.dirname(resolved)), path.basename(resolved));
    } catch {
      real = resolved;
    }
  }
  /** @type {string|null} */
  let inode = null;
  try {
    const stats = statSync(real);
    inode = `${stats.dev}:${stats.ino}`;
  } catch {
    inode = null;
  }
  return { given: candidate, real, inode };
}

/**
 * 2つのパスが同じ実体を指すか。
 * @param {PathIdentity} a
 * @param {PathIdentity} b
 */
export function isSamePath(a, b) {
  if (a.real === b.real) return true;
  return a.inode !== null && a.inode === b.inode;
}

/**
 * @typedef {object} LabeledPath
 * @property {string} label エラーメッセージに出す名前（`--out`、原本キーなど）。
 * @property {string} path
 */

/**
 * 出力先が入力のいずれか、または他の出力先と衝突していないかを調べる。
 *
 * @param {LabeledPath[]} outputs 書き込み先。
 * @param {LabeledPath[]} inputs 読み取り元。
 * @returns {string[]} 衝突の説明（空なら衝突なし）。
 */
export function findPathCollisions(outputs, inputs) {
  /** @type {string[]} */
  const collisions = [];
  const outputIdentities = outputs.map((entry) => ({ ...entry, identity: identifyPath(entry.path) }));
  const inputIdentities = inputs.map((entry) => ({ ...entry, identity: identifyPath(entry.path) }));

  for (const output of outputIdentities) {
    for (const input of inputIdentities) {
      if (isSamePath(output.identity, input.identity)) {
        collisions.push(
          `${output.label} (${output.path}) が入力 ${input.label} (${input.path}) と同じ実体を指している。原本・設定・検証対象を出力先にできない。`,
        );
      }
    }
  }

  for (let i = 0; i < outputIdentities.length; i += 1) {
    for (let j = i + 1; j < outputIdentities.length; j += 1) {
      if (isSamePath(outputIdentities[i].identity, outputIdentities[j].identity)) {
        collisions.push(
          `${outputIdentities[i].label} (${outputIdentities[i].path}) と ${outputIdentities[j].label} (${outputIdentities[j].path}) が同じ実体を指している。`,
        );
      }
    }
  }

  return collisions;
}
