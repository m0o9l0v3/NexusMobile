#!/usr/bin/env node
/**
 * fgd-to-geojson CLI エントリ（基盤地図情報 GML → GeoJSON）。実体は src/fgd-cli.mjs。
 */
import { run } from './src/fgd-cli.mjs';

process.exitCode = run(process.argv.slice(2), {
  log: (line) => process.stdout.write(`${line}\n`),
  error: (line) => process.stderr.write(`${line}\n`),
});
