#!/usr/bin/env node
/**
 * survey CLI エントリ（現地測量 → 建物 Polygon）。実体は src/survey/cli.mjs。
 */
import { run } from './src/survey/cli.mjs';

process.exitCode = run(process.argv.slice(2), {
  log: (line) => process.stdout.write(`${line}\n`),
  error: (line) => process.stderr.write(`${line}\n`),
});
