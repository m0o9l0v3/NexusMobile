# 現地測量の記録

構内の建物の現地測量（[`docs/map-data/campus-survey-plan.md`](../../docs/map-data/campus-survey-plan.md)）の記録の置き場所。

| パス | 内容 |
|---|---|
| `templates/field-sheet.csv` | 野帳の CSV のひな形（列は計画書 §6.3） |
| `templates/survey-project.template.json` | 測量設定のひな形（基準点・機材・建物の角の順・仮の点） |
| `<測量日>/` | 測量のあとに作る。野帳の CSV・測量設定・ツールのレポート（`survey.mjs --report`）を置く |

- 野帳には人の名前を書かない（役割名か頭文字）。
- 写真の原本はリポジトリに置かない。ファイル名と SHA-256 だけを記録する（`map-data/README.md` の「写真原本」と同じ）。
- 基準点の座標は国土地理院の基盤地図情報から取る。利用手続の答えが出るまで（計画書 §2.2）、`<測量日>/` を公開のリポジトリにコミットするかはオーナーが決める。
- 建物の GeoJSON（`survey.mjs --out`）はリポジトリの外の原本フォルダに置く（計画書 §6.4）。
