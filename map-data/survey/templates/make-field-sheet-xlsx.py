#!/usr/bin/env python3
"""スマートフォンで記入する野帳（Google スプレッドシート用）`field-sheet.xlsx` を生成する。

Google ドライブにアップロードして Google スプレッドシートに変換して使う
（計画: docs/map-data/campus-survey-plan.md、紙の野帳: docs/map-data/field-sheet.html）。

    python3 -m pip install openpyxl   # 初回のみ（このスクリプトだけが使う）
    python3 map-data/survey/templates/make-field-sheet-xlsx.py

シート:
- 使い方   当日の流れと決まりごと
- 表紙     測量 ID・日付・役割（頭文字）・機材・偏角・許可
- 基準点   下見で決めた基準点（古い棟の角）と照合の結果
- 点       選べる点の一覧（新しい棟の角・仮の点・基準点）と観測数
- 観測     当日の記入（選択式の列が多い）。右端の「確認」が OK でない行を直す
- 棟ごと   直角の角の確かめ（対角線² ≈ 辺1² ＋ 辺2²）
- CSV      survey.mjs が読む野帳 CSV の形（自動）。このシートを CSV でダウンロードする
"""

from pathlib import Path

from openpyxl import Workbook
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

OUT = Path(__file__).with_name("field-sheet.xlsx")

OLD = ["ab", "aptr", "ar", "dh", "lbh", "mb", "ptb"]
NEW = ["amh", "ctc_main", "ctc2", "dvh", "hgr_a", "hgr_b", "sab"]
NEW_NAMES = {
    "amh": "女子寮", "ctc_main": "CTC", "ctc2": "CTC2", "dvh": "Da Vinci Hall",
    "hgr_a": "格納庫A", "hgr_b": "格納庫B", "sab": "技能審査棟",
}
CORNERS_PER_BUILDING = 10
AUX_POINTS = 6
REF_ROWS = 40
OBS_ROWS = 400
CSV_COLUMNS = [
    "record_id", "building_id", "point_id", "from_point", "distance_m", "bearing_deg",
    "instrument_id", "measurer", "observed_at", "photo_ref", "notes", "void",
]

HEAD_FONT = Font(bold=True, size=12)
HEAD_FILL = PatternFill("solid", fgColor="DDE7F0")
BODY_FONT = Font(size=12)
WRAP = Alignment(wrap_text=True, vertical="top")
RED = PatternFill("solid", fgColor="F8D0D0")
GREEN = PatternFill("solid", fgColor="D6EFD6")


def header(ws, labels, widths):
    for i, (label, width) in enumerate(zip(labels, widths), start=1):
        cell = ws.cell(row=1, column=i, value=label)
        cell.font = HEAD_FONT
        cell.fill = HEAD_FILL
        cell.alignment = Alignment(wrap_text=True, vertical="center")
        ws.column_dimensions[cell.column_letter].width = width
    ws.row_dimensions[1].height = 34
    ws.freeze_panes = "A2"


def list_validation(ws, formula, cell_range, prompt=None, allow_blank=True):
    dv = DataValidation(type="list", formula1=formula, allow_blank=allow_blank, showDropDown=False)
    dv.error = "一覧から選ぶ"
    dv.showErrorMessage = True
    if prompt:
        dv.prompt = prompt
        dv.showInputMessage = True
    ws.add_data_validation(dv)
    dv.add(cell_range)


def sheet_usage(wb):
    ws = wb.active
    ws.title = "使い方"
    lines = [
        "野帳（現地測量）— スマートフォンで記入する",
        "",
        "前日まで",
        "1. 「表紙」に測量 ID・日付・2人の頭文字（名前は書かない）・機材・偏角を入れる。",
        "",
        "当日",
        "2. 下見: 新しい棟を回って角を数え、外周を回る順に P1, P2, … と番号を振る（写真にも残す）。",
        "   使う基準点（古い棟の角）を決め、「基準点」に ID（例: ar-G1）を入れる。",
        "3. 古い棟の照合（計画書 §3）: 辺・対角線・建物どうしの距離を「観測」に入れる。",
        "   どちらの端も基準点（〜-G1 など）の行が照合になる。結果を「基準点」の『照合』で選ぶ。",
        "4. 新しい棟（計画書 §4.2）: 各角を基準点（か仮の点 T1…）2点以上から、全辺、対角線、方位1つ。",
        "5. 1行ごとに右端の『確認』が OK になっているか見る。",
        "6. 1棟終わったら「棟ごと」で直角の角を確かめる。『測り直す』が出たら、その場で測り直す。",
        "7. 「点」で、角ごとの『観測数』が3以上か見る。",
        "",
        "決まりごと",
        "- 距離は水平距離（m）。読み上げ → 記入 → 読み返し。",
        "- 測り直した行は消さない。『無効』に「再測定 → R031」のように理由と新しい番号を書く。",
        "- 点は一覧から選ぶ。一覧に無い点は「点」の下の空いた行に足す。",
        "- 人の名前・顔の写る写真は残さない。Apple・Google の地図は見ない。",
        "- 行を並べ替えたり削除したりしない（番号 R001… は行の位置で決まる）。",
        "",
        "あとで（Mac）",
        "8. 「CSV」シートを開き、ファイル → ダウンロード → カンマ区切り形式（.csv）で保存する。",
        "9. npm run mapdata:survey -- --project <測量設定.json> --observations <保存した.csv> --report <レポート.json>",
    ]
    for i, line in enumerate(lines, start=1):
        cell = ws.cell(row=i, column=1, value=line)
        cell.font = Font(bold=(i == 1 or line in ("前日まで", "当日", "決まりごと", "あとで（Mac）")), size=12)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
    ws.column_dimensions["A"].width = 60


def sheet_cover(wb):
    ws = wb.create_sheet("表紙")
    header(ws, ["項目", "記入"], [20, 28])
    rows = [
        ("測量 ID", "campus-survey-"),
        ("1日目", ""),
        ("2日目", ""),
        ("3日目", ""),
        ("測る人の頭文字", ""),
        ("記録する人の頭文字", ""),
        ("天気・気温", ""),
        ("LD1 レーザー距離計（型番）", ""),
        ("TP1 巻尺 50 m", ""),
        ("偏角（度、西偏は負）", ""),
        ("学校の許可を持参", ""),
        ("当日の担当へ連絡", ""),
        ("授業・行事の時間を避けた", ""),
    ]
    for r, (label, value) in enumerate(rows, start=2):
        ws.cell(row=r, column=1, value=label).font = BODY_FONT
        c = ws.cell(row=r, column=2, value=value)
        c.font = BODY_FONT
        if label.endswith("日目"):
            c.number_format = "yyyy-mm-dd"
    list_validation(ws, '"はい,いいえ"', "B12:B14")


def sheet_references(wb):
    ws = wb.create_sheet("基準点")
    header(ws, ["基準点 ID（例 ar-G1）", "建物", "どの角か（言葉で）", "国土地理院の頂点番号", "照合", "見通せる新しい棟", "メモ"],
           [18, 10, 22, 14, 12, 18, 24])
    list_validation(ws, '"' + ",".join(OLD) + '"', f"B2:B{REF_ROWS + 1}")
    list_validation(ws, '"未,合う,合わない"', f"E2:E{REF_ROWS + 1}")
    for r in range(2, REF_ROWS + 2):
        for c in range(1, 8):
            ws.cell(row=r, column=c).font = BODY_FONT
    ws.conditional_formatting.add(f"E2:E{REF_ROWS + 1}", FormulaRule(formula=['E2="合わない"'], fill=RED))
    ws.conditional_formatting.add(f"E2:E{REF_ROWS + 1}", FormulaRule(formula=['E2="合う"'], fill=GREEN))


def sheet_points(wb):
    ws = wb.create_sheet("点")
    header(ws, ["点 ID", "種類", "建物", "観測数", "状態"], [16, 10, 16, 8, 10])
    r = 2
    for b in NEW:
        for i in range(1, CORNERS_PER_BUILDING + 1):
            ws.cell(row=r, column=1, value=f"{b}-P{i}")
            ws.cell(row=r, column=2, value="角")
            ws.cell(row=r, column=3, value=f"{b}（{NEW_NAMES[b]}）")
            r += 1
    for i in range(1, AUX_POINTS + 1):
        ws.cell(row=r, column=1, value=f"T{i}")
        ws.cell(row=r, column=2, value="仮の点")
        r += 1
    for i in range(2, REF_ROWS + 2):
        ws.cell(row=r, column=1, value=f"=IF('基準点'!A{i}=\"\",\"\",'基準点'!A{i})")
        ws.cell(row=r, column=2, value=f"=IF('基準点'!A{i}=\"\",\"\",\"基準点\")")
        ws.cell(row=r, column=3, value=f"=IF('基準点'!A{i}=\"\",\"\",'基準点'!B{i})")
        r += 1
    last = r + 20  # 足す点のための空き行
    obs = f"'観測'!$C$2:$C${OBS_ROWS + 1}"
    frm = f"'観測'!$D$2:$D${OBS_ROWS + 1}"
    void = f"'観測'!$M$2:$M${OBS_ROWS + 1}"
    for row in range(2, last + 1):
        ws.cell(row=row, column=4, value=f'=IF(A{row}="","",COUNTIFS({obs},A{row},{void},"")+COUNTIFS({frm},A{row},{void},""))')
        ws.cell(row=row, column=5, value=f'=IF(OR(A{row}="",D{row}=0),"",IF(D{row}<3,"足りない","OK"))')
        for c in range(1, 6):
            ws.cell(row=row, column=c).font = BODY_FONT
    ws.conditional_formatting.add(f"E2:E{last}", FormulaRule(formula=['E2="足りない"'], fill=RED))
    ws.conditional_formatting.add(f"E2:E{last}", FormulaRule(formula=['E2="OK"'], fill=GREEN))
    return last


def sheet_observations(wb, points_last):
    ws = wb.create_sheet("観測")
    header(ws, ["番号", "建物", "測った点", "どこから", "距離 m（水平）", "方位°（磁北・任意）", "機材", "測った人",
                "日", "時刻", "写真", "メモ（何に当てたか）", "無効（理由→新番号）", "確認"],
           [7, 10, 13, 13, 10, 9, 7, 7, 7, 8, 12, 22, 16, 12])
    n = OBS_ROWS + 1
    list_validation(ws, '"' + ",".join(NEW + OLD) + '"', f"B2:B{n}")
    list_validation(ws, f"='点'!$A$2:$A${points_last}", f"C2:D{n}")
    dv = DataValidation(type="decimal", operator="between", formula1="0.01", formula2="500", allow_blank=True)
    dv.error = "0.01〜500 m の数"
    dv.showErrorMessage = True
    ws.add_data_validation(dv)
    dv.add(f"E2:E{n}")
    dv2 = DataValidation(type="decimal", operator="between", formula1="0", formula2="359.9", allow_blank=True)
    dv2.error = "0〜359.9 度"
    dv2.showErrorMessage = True
    ws.add_data_validation(dv2)
    dv2.add(f"F2:F{n}")
    list_validation(ws, '"LD1,TP1"', f"G2:G{n}")
    list_validation(ws, "='表紙'!$B$6:$B$7", f"H2:H{n}")
    list_validation(ws, '"1日目,2日目,3日目"', f"I2:I{n}")
    for r in range(2, n + 1):
        ws.cell(row=r, column=1, value=f'=IF(B{r}="","","R"&TEXT(ROW()-1,"000"))')
        ws.cell(row=r, column=5).number_format = "0.000"
        ws.cell(row=r, column=10).number_format = "hh:mm"
        ws.cell(row=r, column=14, value=(
            f'=IF(B{r}="","",IF(C{r}="","測った点が空",IF(D{r}="","どこからが空",IF(C{r}=D{r},"同じ点",'
            f'IF(E{r}="","距離が空",IF(G{r}="","機材が空",IF(H{r}="","測った人が空",IF(OR(I{r}="",J{r}=""),"日・時刻が空","OK"))))))))'
        ))
        for c in range(1, 15):
            ws.cell(row=r, column=c).font = BODY_FONT
    ws.conditional_formatting.add(f"N2:N{n}", FormulaRule(formula=['AND(N2<>"",N2<>"OK")'], fill=RED))
    ws.conditional_formatting.add(f"N2:N{n}", FormulaRule(formula=['N2="OK"'], fill=GREEN))
    ws.conditional_formatting.add(f"A2:M{n}", FormulaRule(formula=['$M2<>""'], fill=PatternFill("solid", fgColor="E6E6E6")))


def sheet_per_building(wb):
    ws = wb.create_sheet("棟ごと")
    header(ws, ["建物", "角1", "角2（直角の角）", "角3", "辺1 m", "辺2 m", "対角線 m", "差 m", "判定"],
           [10, 6, 9, 6, 9, 9, 9, 8, 10])
    n = OBS_ROWS + 1
    c, d, e, m = (f"'観測'!$C$2:$C${n}", f"'観測'!$D$2:$D${n}", f"'観測'!$E$2:$E${n}", f"'観測'!$M$2:$M${n}")

    def dist(x, y):
        return (f'IFERROR((SUMIFS({e},{c},{x},{d},{y},{m},"")+SUMIFS({e},{c},{y},{d},{x},{m},""))/'
                f'(COUNTIFS({c},{x},{d},{y},{m},"")+COUNTIFS({c},{y},{d},{x},{m},"")),"")')

    r = 2
    for b in NEW:
        for corners in (("P1", "P2", "P3"), ("P3", "P4", "P1")):
            ws.cell(row=r, column=1, value=b)
            for k, p in enumerate(corners, start=2):
                ws.cell(row=r, column=k, value=p)
            a1, a2, a3 = (f'$A{r}&"-"&{col}{r}' for col in ("B", "C", "D"))
            ws.cell(row=r, column=5, value=f"={dist(a1, a2)}")
            ws.cell(row=r, column=6, value=f"={dist(a2, a3)}")
            ws.cell(row=r, column=7, value=f"={dist(a1, a3)}")
            ws.cell(row=r, column=8, value=f'=IF(OR(E{r}="",F{r}="",G{r}=""),"",ROUND(G{r}-SQRT(E{r}^2+F{r}^2),3))')
            ws.cell(row=r, column=9, value=f'=IF(H{r}="","",IF(ABS(H{r})>0.3,"測り直す","OK"))')
            for col in (5, 6, 7, 8):
                ws.cell(row=r, column=col).number_format = "0.000"
            for col in range(1, 10):
                ws.cell(row=r, column=col).font = BODY_FONT
            r += 1
    note = ws.cell(row=r + 1, column=1, value=(
        "角2 が直角の角のときだけ使える。直角でない角や、角が5つ以上の棟は、角の番号を書き換えるか行を足す。"
        "差が ±0.3 m を超えたら、3本のうちどれかの読み違いを疑って測り直す（計画書 §4.3）。"))
    note.alignment = WRAP
    ws.merge_cells(start_row=r + 1, start_column=1, end_row=r + 1, end_column=9)
    ws.row_dimensions[r + 1].height = 60
    ws.conditional_formatting.add(f"I2:I{r}", FormulaRule(formula=['I2="測り直す"'], fill=RED))
    ws.conditional_formatting.add(f"I2:I{r}", FormulaRule(formula=['I2="OK"'], fill=GREEN))


def sheet_csv(wb):
    ws = wb.create_sheet("CSV")
    for i, name in enumerate(CSV_COLUMNS, start=1):
        ws.cell(row=1, column=i, value=name)
    src = {"record_id": "A", "building_id": "B", "point_id": "C", "from_point": "D", "distance_m": "E",
           "bearing_deg": "F", "instrument_id": "G", "measurer": "H", "photo_ref": "K", "notes": "L", "void": "M"}
    for r in range(2, OBS_ROWS + 2):
        for i, name in enumerate(CSV_COLUMNS, start=1):
            if name == "observed_at":
                f = (f"=IF('観測'!$B{r}=\"\",\"\",IFERROR(TEXT(VLOOKUP('観測'!I{r},'表紙'!$A$3:$B$5,2,FALSE),\"yyyy-mm-dd\"),\"\")"
                     f"&\"T\"&TEXT('観測'!J{r},\"hh:mm\"))")
            else:
                f = f"=IF('観測'!$B{r}=\"\",\"\",'観測'!{src[name]}{r}&\"\")"
            ws.cell(row=r, column=i, value=f)
    ws.freeze_panes = "A2"


def main():
    wb = Workbook()
    sheet_usage(wb)
    sheet_cover(wb)
    sheet_references(wb)
    last = sheet_points(wb)
    sheet_observations(wb, last)
    sheet_per_building(wb)
    sheet_csv(wb)
    wb.active = wb.sheetnames.index("観測")
    wb.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
