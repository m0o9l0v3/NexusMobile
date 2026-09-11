#!/usr/bin/env node
/**
 * map-dataset CLI エントリ。
 * 実体は src/cli.mjs。
 */
import { run } from './src/cli.mjs';

const code = run(process.argv.slice(2), {
  log: (line) => process.stdout.write(`${line}\n`),
  error: (line) => process.stderr.write(`${line}\n`),
});
process.exitCode = code;
