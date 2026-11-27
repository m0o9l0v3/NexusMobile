# 現地測量の記録

構内の建物の現地測量（[`docs/map-data/campus-survey-plan.md`](../../docs/map-data/campus-survey-plan.md)）の記録の置き場所。

| パス | 内容 |
|---|---|
| `templates/field-sheet.csv` | 野帳の CSV のひな形（列は計画書 §8.3。距離と支距の両方） |
| `templates/field-sheet.xlsx` | スマートフォンで記入する野帳（Google スプレッドシートで開く）。シート「CSV」が上の CSV と同じ列になる |
| `templates/make-field-sheet-xlsx.py` | `field-sheet.xlsx` を作り直すスクリプト（openpyxl が要る）。`--gsi` を付けた版（古い棟の角と国土地理院の辺の長さ入り）は `--out` でリポジトリの外に書き、コミットしない |
| `templates/survey-project.template.json` | 測量設定のひな形 v1.1.0（基準点・確かめの点・機材と校正・建物・ノード・入口・曲がり角・基線・辺・輪） |
| `<測量日>/` | 測量のあとに作る。野帳の CSV・測量設定・ツールのレポート（`survey.mjs --report`）を置く |

- 野帳には人の名前を書かない（役割名か頭文字）。
- 写真の原本はリポジトリに置かない。ファイル名と SHA-256 だけを記録する（`map-data/README.md` の「写真原本」と同じ）。
- 基準点の座標は国土地理院の基盤地図情報から取る。利用手続の答えが出るまで（計画書 §2.2）、`<測量日>/` を公開のリポジトリにコミットするかはオーナーが決める。
- 建物の GeoJSON（`survey.mjs --out`）はリポジトリの外の原本フォルダに置く（計画書 §8.4）。
