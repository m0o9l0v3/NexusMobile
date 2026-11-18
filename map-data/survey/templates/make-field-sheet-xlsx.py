#!/usr/bin/env python3
"""スマートフォンで記入する野帳（Google スプレッドシート用）`field-sheet.xlsx` を生成する。

Google ドライブにアップロードして Google スプレッドシートに変換して使う
（計画: docs/map-data/campus-survey-plan.md、紙の野帳: docs/map-data/field-sheet.html）。

    python3 -m pip install openpyxl   # 初回のみ（このスクリプトだけが使う）
    python3 map-data/survey/templates/make-field-sheet-xlsx.py
    # 国土地理院の古い棟の形（fgd-to-geojson --assign の出力）から、角と辺の長さを入れる版:
    python3 map-data/survey/templates/make-field-sheet-xlsx.py --gsi gsi-buildings.geojson --out field-sheet-gsi.xlsx

--gsi を付けた版は国土地理院の座標から作るので、利用手続の答えが出るまでリポジトリに置かない（計画書 §2.2）。

シート:
- 使い方   当日の流れと決まりごと
- 表紙     測量 ID・日付・役割（頭文字）・機材・偏角・許可
- 観測     当日の記入（選択式の列が多い）。右端の「確認」が OK でない行を直す
- 点       選べる点の一覧（新しい棟の角・古い棟の角・ノード・入口・折れ点・仮の点・照合点）と観測の数
- 基線     支距の基線（ルート1〜4 のノードの間。起点が累積距離 0）
- 照合     古い棟の辺: 国土地理院の長さと測った長さの差（±0.5 m）
- 棟ごと   新しい棟の直角の確かめ（対角線² ≈ 辺1² ＋ 辺2²）
- CSV      survey.mjs が読む野帳 CSV の形（自動）。このシートを CSV でダウンロードする
"""

import argparse
import json
import math
from pathlib import Path

from openpyxl import Workbook
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

DEFAULT_OUT = Path(__file__).with_name("field-sheet.xlsx")

OLD = ["ab", "aptr", "ar", "dh", "lbh", "mb", "ptb"]
NEW = ["amh", "ctc_main", "ctc2", "dvh", "hgr_a", "hgr_b", "sab"]
NAMES = {
    "ab": "管理棟", "aptr": "機体実習室", "ar": "アリーナ", "dh": "食堂", "lbh": "男子寮", "mb": "教室棟", "ptb": "実習棟",
    "amh": "女子寮", "ctc_main": "CTC", "ctc2": "CTC2", "dvh": "Da Vinci Hall", "hgr_a": "格納庫A", "hgr_b": "格納庫B", "sab": "技能審査棟",
}
NODES = [
    ("campus_n_001", "N01 正門"), ("campus_n_002", "N02 正門前広場"), ("campus_n_003", "N03 男子寮前"),
    ("campus_n_004", "N04 食堂・女子寮前"), ("campus_n_005", "N05 Da Vinci Hall前"), ("campus_n_006", "N06 アリーナ・CTC2前"),
    ("campus_n_007", "N07 CTC・管理棟前"), ("campus_n_008", "N08 教室棟前"), ("campus_n_009", "N09 東側外周北分岐"),
    ("campus_n_010", "N10 格納庫北分岐"), ("campus_n_011", "N11 格納庫A・B前"), ("campus_n_012", "N12 エプロン南分岐"),
    ("campus_n_013", "N13 技能審査棟前"),
]
# ルート1〜4（計画書 §5.1）をノードの間の基線に分ける。
ROUTES = {
    "R1": ["campus_n_001", "campus_n_002", "campus_n_006", "campus_n_007", "campus_n_008", "campus_n_010"],
    "R2": ["campus_n_010", "campus_n_011", "campus_n_012", "campus_n_013"],
    "R3": ["campus_n_010", "campus_n_009", "campus_n_004", "campus_n_003", "campus_n_002"],
    "R4": ["campus_n_002", "campus_n_005", "campus_n_007"],
}
NEW_CORNERS = 10
OLD_CORNERS_DEFAULT = 20
OLD_SPARE_CORNERS = 10
# 国土地理院にあるかが決まっていない古い棟（計画書 §3.2）。現地で全部の角を測ることになっても足りる数を用意する。
UNCERTAIN_SPARE_CORNERS = {"mb": 24, "ptb": 14}
BENDS = 30
AUX = 10
CHECKS = 3
OBS_ROWS = 600
INSTRUMENTS = ["LD1", "TP1", "WM1"]

# 観測シートの列（見出し・幅・CSV の列名）
OBS = [
    ("no", "番号", 7), ("type", "種類", 7), ("building", "建物", 10), ("point", "測った点", 14), ("physical", "何の点か", 16),
    ("from", "どこから（距離）", 14), ("dist", "距離 m", 9), ("slope", "傾斜°（斜距離のとき）", 8), ("dh", "高低差 m（斜距離のとき）", 8),
    ("bearing", "方位°（磁北・任意）", 8), ("baseline", "基線（支距）", 9), ("chainage", "累積距離 m（支距）", 9),
    ("offset", "支距 m", 8), ("side", "左右（支距）", 6), ("inst", "機材", 7), ("offinst", "支距の機材", 7), ("measurer", "測った人", 7),
    ("day", "日", 7), ("time", "時刻", 8), ("photo", "写真", 12), ("notes", "メモ", 18), ("void", "無効（理由→新番号）", 16),
    ("check", "確認", 14),
]
COL = {key: get_column_letter(i) for i, (key, _, _) in enumerate(OBS, start=1)}
CSV_COLUMNS = [
    ("record_id", "no"), ("obs_type", None), ("building_id", "building"), ("point_id", "point"), ("physical_point", "physical"),
    ("from_point", "from"), ("distance_m", "dist"), ("slope_deg", "slope"), ("height_diff_m", "dh"), ("bearing_deg", "bearing"),
    ("baseline_id", "baseline"), ("chainage_m", "chainage"), ("offset_m", "offset"), ("offset_side", None),
    ("instrument_id", "inst"), ("offset_instrument_id", "offinst"), ("measurer", "measurer"), ("observed_at", None),
    ("photo_ref", "photo"), ("notes", "notes"), ("void", "void"),
]

HEAD_FONT = Font(bold=True, size=12)
HEAD_FILL = PatternFill("solid", fgColor="DDE7F0")
BODY_FONT = Font(size=12)
WRAP = Alignment(wrap_text=True, vertical="top")
RED = PatternFill("solid", fgColor="F8D0D0")
GREEN = PatternFill("solid", fgColor="D6EFD6")
GRAY = PatternFill("solid", fgColor="E6E6E6")


def header(ws, labels, widths):
    for i, (label, width) in enumerate(zip(labels, widths), start=1):
        cell = ws.cell(row=1, column=i, value=label)
        cell.font = HEAD_FONT
        cell.fill = HEAD_FILL
        cell.alignment = Alignment(wrap_text=True, vertical="center")
        ws.column_dimensions[cell.column_letter].width = width
    ws.row_dimensions[1].height = 44
    ws.freeze_panes = "A2"


def list_validation(ws, formula, cell_range):
    dv = DataValidation(type="list", formula1=formula, allow_blank=True, showDropDown=False)
    dv.error = "一覧から選ぶ"
    dv.showErrorMessage = True
    ws.add_data_validation(dv)
    dv.add(cell_range)


def decimal_validation(ws, lo, hi, cell_range, message):
    dv = DataValidation(type="decimal", operator="between", formula1=str(lo), formula2=str(hi), allow_blank=True)
    dv.error = message
    dv.showErrorMessage = True
    ws.add_data_validation(dv)
    dv.add(cell_range)


def ok_ng(ws, cell_range, first_cell, bad, good="OK"):
    ws.conditional_formatting.add(cell_range, FormulaRule(formula=[f'AND({first_cell}<>"",{first_cell}<>"{good}")' if bad is None else f'{first_cell}="{bad}"'], fill=RED))
    ws.conditional_formatting.add(cell_range, FormulaRule(formula=[f'{first_cell}="{good}"'], fill=GREEN))


def enu_length(a, b):
    lat0 = math.radians((a[1] + b[1]) / 2)
    return math.hypot((b[0] - a[0]) * 111320 * math.cos(lat0), (b[1] - a[1]) * 110574)


def load_gsi(path):
    """fgd-to-geojson --assign の出力から、建物ごとの頂点（閉じの点を除く）を読む。"""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    out = {}
    for f in data["features"]:
        bid = f["properties"].get("id")
        if bid not in OLD:
            raise SystemExit(f"--gsi: properties.id が古い7棟の ID でない: {bid}")
        ring = f["geometry"]["coordinates"][0][:-1]
        out[bid] = ring
    return out


def sheet_usage(wb, with_gsi):
    ws = wb.active
    ws.title = "使い方"
    lines = [
        "野帳（現地測量）— スマートフォンで記入する",
        "",
        "前日まで",
        "1. 「表紙」に測量 ID・日付・2人の頭文字（名前は書かない）・機材・偏角を入れる。",
        "2. ウォーキングメジャーを校正する（計画書 §6）。結果は測量設定の scale_factor に書く。",
        "",
        "当日",
        "3. 下見: 新しい棟の角を数え、外周を回る順に P1, P2, … と番号を振る（写真にも残す）。",
        "   古い棟の角は国土地理院の頂点の順に G1, G2, …（" + ("「点」に入っている" if with_gsi else "国土地理院の図で番号を振る") + "）。",
        "   mb・ptb は国土地理院にあるかが決まっていない（計画書 §3.2）。照合で合わなければ、新しい棟と同じく mb-P1, ptb-P1, … で測る。",
        "4. 古い棟の照合（計画書 §3）: 辺・対角線・建物どうしの距離を「観測」に入れ、「照合」で合否を見る。",
        "5. 経路（計画書 §5）: 「基線」のノードの間をウォーキングメジャーで進み、ノード・分岐・入口前・支距を下ろす点で",
        "   累積距離を読む。種類を「支距」にして、基線・累積距離・支距・左右を入れる。支距は直角に（プリズムか 3-4-5）。",
        "   各ノードは、古い棟の角からの距離（巻尺・レーザー）を1本以上足す。",
        "6. 新しい棟（計画書 §4.2〜§4.4）: 手前2角の支距、W×D・対角線、3本目の距離、入口。",
        "7. 1行ごとに右端の『確認』が OK か見る。「棟ごと」「照合」で『測り直す』が出たら、その場で測り直す。",
        "8. 「点」で、点ごとの『観測の数』が3以上か見る（折れ点は2）。",
        "",
        "決まりごと",
        "- 距離は水平距離（m）。傾いたところで測ったら、傾斜°か高低差 m を書く（ツールが直す）。",
        "- ウォーキングメジャーは舗装面の経路の長さだけ。角・分岐・入口は巻尺かレーザー。",
        "- 支距は 15 m まで。それより長いときは、別の点からの距離を1本足す。",
        "- 読み上げ → 記入 → 読み返し。測り直した行は消さず、『無効』に「残差 0.45 m → R031」のように書く。",
        "- 点は一覧から選ぶ。一覧に無い点は「点」の下の空いた行に足す。",
        "- 人の名前・顔の写る写真は残さない。Apple・Google の地図は見ない。",
        "- 行を並べ替えたり削除したりしない（番号 R001… は行の位置で決まる）。",
        "",
        "あとで（Mac）",
        "9. 「CSV」シートを開き、ファイル → ダウンロード → カンマ区切り形式（.csv）で保存する。",
        "10. npm run mapdata:survey -- --project <測量設定.json> --observations <保存した.csv> --report <レポート.json>",
    ]
    for i, line in enumerate(lines, start=1):
        cell = ws.cell(row=i, column=1, value=line)
        cell.font = Font(bold=(i == 1 or line in ("前日まで", "当日", "決まりごと", "あとで（Mac）")), size=12)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
    ws.column_dimensions["A"].width = 64


def sheet_cover(wb):
    ws = wb.create_sheet("表紙")
    header(ws, ["項目", "記入"], [22, 28])
    rows = [
        ("測量 ID", "campus-survey-"), ("1日目", ""), ("2日目", ""), ("3日目", ""),
        ("測る人の頭文字", ""), ("記録する人の頭文字", ""), ("天気・気温", ""),
        ("LD1 レーザー距離計（型番）", ""), ("TP1 巻尺 50 m", ""), ("WM1 ウォーキングメジャー（型番）", ""),
        ("WM1 校正: 50 m を行き（表示 m）", ""), ("WM1 校正: 50 m を帰り（表示 m）", ""),
        ("直角の確かめ方（プリズム / 3-4-5）", ""), ("偏角（度、西偏は負）", ""),
        ("学校の許可を持参", ""), ("当日の担当へ連絡", ""), ("授業・行事の時間を避けた", ""),
    ]
    for r, (label, value) in enumerate(rows, start=2):
        ws.cell(row=r, column=1, value=label).font = BODY_FONT
        c = ws.cell(row=r, column=2, value=value)
        c.font = BODY_FONT
        if label.endswith("日目"):
            c.number_format = "yyyy-mm-dd"
    ws.cell(row=len(rows) + 2, column=1, value="WM1 の scale_factor（自動）").font = BODY_FONT
    ws.cell(row=len(rows) + 2, column=2, value='=IF(OR(B12="",B13=""),"",ROUND((B12+B13)/2/50,4))').font = BODY_FONT
    list_validation(ws, '"プリズム,3-4-5"', "B14")
    list_validation(ws, '"はい,いいえ"', "B16:B18")


def sheet_points(wb, gsi):
    ws = wb.create_sheet("点")
    header(ws, ["点 ID", "種類", "建物・名前", "観測の数", "状態"], [16, 10, 18, 8, 10])
    rows = []
    for b in NEW:
        rows += [(f"{b}-P{i}", "角", f"{b}（{NAMES[b]}）") for i in range(1, NEW_CORNERS + 1)]
    for b in OLD:
        n = len(gsi[b]) if gsi and b in gsi else OLD_CORNERS_DEFAULT
        rows += [(f"{b}-G{i}", "古い棟の角", f"{b}（{NAMES[b]}）") for i in range(1, n + 1)]
    rows += [(nid, "ノード", name) for nid, name in NODES]
    for b in NEW + OLD:
        rows += [(f"{b}_ent_{i:03d}", "入口", f"{b}（{NAMES[b]}）") for i in (1, 2)]
    rows += [(f"B{i:02d}", "折れ点", "") for i in range(1, BENDS + 1)]
    rows += [(f"T{i}", "仮の点", "") for i in range(1, AUX + 1)]
    rows += [(f"K{i}", "照合点", "公共基準点など") for i in range(1, CHECKS + 1)]
    for b in OLD:
        n = UNCERTAIN_SPARE_CORNERS.get(b, OLD_SPARE_CORNERS)
        rows += [(f"{b}-P{i}", "角（作り直し）", f"{b}（{NAMES[b]}）照合で合わないとき") for i in range(1, n + 1)]
    for r, (pid, kind, name) in enumerate(rows, start=2):
        ws.cell(row=r, column=1, value=pid)
        ws.cell(row=r, column=2, value=kind)
        ws.cell(row=r, column=3, value=name)
    last = len(rows) + 1 + 30  # 足す点のための空き行
    n = OBS_ROWS + 1
    pt, frm, typ, void = (f"'観測'!${COL[k]}$2:${COL[k]}${n}" for k in ("point", "from", "type", "void"))
    for row in range(2, last + 1):
        ws.cell(row=row, column=4, value=(
            f'=IF(A{row}="","",COUNTIFS({pt},A{row},{void},"")+COUNTIFS({frm},A{row},{void},"")'
            f'+COUNTIFS({pt},A{row},{typ},"支距",{void},""))'))
        ws.cell(row=row, column=5, value=(
            f'=IF(OR(A{row}="",D{row}=0),"",IF(D{row}<IF(B{row}="折れ点",2,3),"足りない","OK"))'))
        for c in range(1, 6):
            ws.cell(row=row, column=c).font = BODY_FONT
    ok_ng(ws, f"E2:E{last}", "E2", "足りない")
    return last


def sheet_baselines(wb, points_last):
    ws = wb.create_sheet("基線")
    header(ws, ["基線 ID", "起点（累積 0 m）", "終点", "ルート"], [10, 16, 16, 10])
    r = 2
    for route, nodes in ROUTES.items():
        for i in range(1, len(nodes)):
            ws.cell(row=r, column=1, value=f"{route}-{i:02d}")
            ws.cell(row=r, column=2, value=nodes[i - 1])
            ws.cell(row=r, column=3, value=nodes[i])
            ws.cell(row=r, column=4, value=route)
            r += 1
    last = r + 20
    list_validation(ws, f"='点'!$A$2:$A${points_last}", f"B2:C{last}")
    for row in range(2, last + 1):
        for c in range(1, 5):
            ws.cell(row=row, column=c).font = BODY_FONT
    return last


def sheet_observations(wb, points_last, baselines_last):
    ws = wb.create_sheet("観測")
    header(ws, [label for _, label, _ in OBS], [w for _, _, w in OBS])
    n = OBS_ROWS + 1
    c = COL
    list_validation(ws, '"距離,支距"', f"{c['type']}2:{c['type']}{n}")
    list_validation(ws, '"' + ",".join(NEW + OLD) + '"', f"{c['building']}2:{c['building']}{n}")
    list_validation(ws, f"='点'!$A$2:$A${points_last}", f"{c['point']}2:{c['point']}{n}")
    list_validation(ws, f"='点'!$A$2:$A${points_last}", f"{c['from']}2:{c['from']}{n}")
    list_validation(ws, f"='基線'!$A$2:$A${baselines_last}", f"{c['baseline']}2:{c['baseline']}{n}")
    list_validation(ws, '"右,左"', f"{c['side']}2:{c['side']}{n}")
    list_validation(ws, '"' + ",".join(INSTRUMENTS) + '"', f"{c['inst']}2:{c['inst']}{n}")
    list_validation(ws, '"' + ",".join(INSTRUMENTS) + '"', f"{c['offinst']}2:{c['offinst']}{n}")
    list_validation(ws, "='表紙'!$B$6:$B$7", f"{c['measurer']}2:{c['measurer']}{n}")
    list_validation(ws, '"1日目,2日目,3日目"', f"{c['day']}2:{c['day']}{n}")
    decimal_validation(ws, 0.01, 500, f"{c['dist']}2:{c['dist']}{n}", "0.01〜500 m の数")
    decimal_validation(ws, 0, 44.9, f"{c['slope']}2:{c['slope']}{n}", "0〜44.9 度")
    decimal_validation(ws, -50, 50, f"{c['dh']}2:{c['dh']}{n}", "-50〜50 m")
    decimal_validation(ws, 0, 359.9, f"{c['bearing']}2:{c['bearing']}{n}", "0〜359.9 度")
    decimal_validation(ws, -5, 2000, f"{c['chainage']}2:{c['chainage']}{n}", "累積距離 m")
    decimal_validation(ws, 0, 100, f"{c['offset']}2:{c['offset']}{n}", "0〜100 m")
    for r in range(2, n + 1):
        g = {k: f"{v}{r}" for k, v in c.items()}
        ws[g["no"]] = f'=IF({g["point"]}="","","R"&TEXT(ROW()-1,"000"))'
        for k in ("dist", "dh", "chainage", "offset"):
            ws[g[k]].number_format = "0.000"
        ws[g["time"]].number_format = "hh:mm"
        common = (f'IF({g["inst"]}="","機材が空",IF({g["measurer"]}="","測った人が空",'
                  f'IF(OR({g["day"]}="",{g["time"]}=""),"日・時刻が空","OK")))')
        distance = (f'IF({g["from"]}="","どこからが空",IF({g["from"]}={g["point"]},"同じ点",IF({g["dist"]}="","距離が空",'
                    f'IF(AND({g["slope"]}<>"",{g["dh"]}<>""),"傾斜は片方だけ",{common}))))')
        chain = (f'IF({g["baseline"]}="","基線が空",IF({g["chainage"]}="","累積距離が空",IF({g["offset"]}="","支距が空",'
                 f'IF(AND({g["offset"]}>0,{g["side"]}=""),"左右が空",IF({g["offset"]}>15,"支距15m超: 距離を1本足す",{common})))))')
        ws[g["check"]] = (f'=IF({g["point"]}="","",IF({g["void"]}<>"","無効",IF({g["type"]}="支距",{chain},{distance})))')
        for col in range(1, len(OBS) + 1):
            ws.cell(row=r, column=col).font = BODY_FONT
    rng = f"{c['check']}2:{c['check']}{n}"
    ws.conditional_formatting.add(rng, FormulaRule(formula=[f'AND({c["check"]}2<>"",{c["check"]}2<>"OK",{c["check"]}2<>"無効")'], fill=RED))
    ws.conditional_formatting.add(rng, FormulaRule(formula=[f'{c["check"]}2="OK"'], fill=GREEN))
    ws.conditional_formatting.add(f"A2:{c['void']}{n}", FormulaRule(formula=[f'${c["void"]}2<>""'], fill=GRAY))


def dist_formula(x, y):
    n = OBS_ROWS + 1
    p, f, d, v, t = (f"'観測'!${COL[k]}$2:${COL[k]}${n}" for k in ("point", "from", "dist", "void", "type"))
    # 距離の行だけ（支距の行は除く）、無効でない行の平均。
    return (f'IFERROR((SUMIFS({d},{p},{x},{f},{y},{v},"",{t},"<>支距")+SUMIFS({d},{p},{y},{f},{x},{v},"",{t},"<>支距"))/'
            f'(COUNTIFS({p},{x},{f},{y},{v},"",{t},"<>支距")+COUNTIFS({p},{y},{f},{x},{v},"",{t},"<>支距")),"")')


def sheet_reference_check(wb, gsi):
    ws = wb.create_sheet("照合")
    header(ws, ["建物", "端1", "端2", "国土地理院 m", "測った m", "差 m", "判定"], [8, 10, 10, 11, 10, 8, 10])
    r = 2
    for b in OLD:
        ring = gsi.get(b) if gsi else None
        n = len(ring) if ring else 4
        for i in range(n):
            j = (i + 1) % n
            ws.cell(row=r, column=1, value=b)
            ws.cell(row=r, column=2, value=f"{b}-G{i + 1}")
            ws.cell(row=r, column=3, value=f"{b}-G{j + 1}")
            if ring:
                ws.cell(row=r, column=4, value=round(enu_length(ring[i], ring[j]), 2))
            r += 1
    last = r + 30  # 対角線・建物どうしの行を足す
    for row in range(2, last + 1):
        ws.cell(row=row, column=5, value=f'=IF(OR(B{row}="",C{row}=""),"",{dist_formula(f"B{row}", f"C{row}")})')
        ws.cell(row=row, column=6, value=f'=IF(OR(D{row}="",E{row}=""),"",ROUND(E{row}-D{row},2))')
        ws.cell(row=row, column=7, value=(
            f'=IF(F{row}="","",IF(ABS(F{row})>IF(LEFT(B{row},LEN(A{row})+2)=LEFT(C{row},LEN(A{row})+2),0.5,1),"測り直す","OK"))'))
        for col in (4, 5, 6):
            ws.cell(row=row, column=col).number_format = "0.00"
        for col in range(1, 8):
            ws.cell(row=row, column=col).font = BODY_FONT
    note = ws.cell(row=last + 2, column=1, value=(
        "同じ建物の辺・対角線は ±0.5 m、建物どうしは ±1.0 m（計画書 §3.4）。"
        + ("国土地理院の長さは --gsi のデータから入れた。" if gsi else "国土地理院の長さは、--gsi で作り直すか、手で入れる。")
        + "対角線や建物どうしの行は、空いた行に端1・端2・国土地理院の長さを書いて足す。"))
    note.alignment = WRAP
    ws.merge_cells(start_row=last + 2, start_column=1, end_row=last + 2, end_column=7)
    ws.row_dimensions[last + 2].height = 70
    ok_ng(ws, f"G2:G{last}", "G2", "測り直す")


def sheet_per_building(wb):
    ws = wb.create_sheet("棟ごと")
    header(ws, ["建物", "角1", "角2（直角の角）", "角3", "辺1 m", "辺2 m", "対角線 m", "差 m", "判定"], [10, 6, 9, 6, 9, 9, 9, 8, 10])
    r = 2
    for b in NEW + list(UNCERTAIN_SPARE_CORNERS):
        for corners in (("P1", "P2", "P3"), ("P3", "P4", "P1")):
            ws.cell(row=r, column=1, value=b)
            for k, p in enumerate(corners, start=2):
                ws.cell(row=r, column=k, value=p)
            a1, a2, a3 = (f'$A{r}&"-"&{col}{r}' for col in ("B", "C", "D"))
            ws.cell(row=r, column=5, value=f"={dist_formula(a1, a2)}")
            ws.cell(row=r, column=6, value=f"={dist_formula(a2, a3)}")
            ws.cell(row=r, column=7, value=f"={dist_formula(a1, a3)}")
            ws.cell(row=r, column=8, value=f'=IF(OR(E{r}="",F{r}="",G{r}=""),"",ROUND(G{r}-SQRT(E{r}^2+F{r}^2),3))')
            ws.cell(row=r, column=9, value=f'=IF(H{r}="","",IF(ABS(H{r})>0.3,"測り直す","OK"))')
            for col in (5, 6, 7, 8):
                ws.cell(row=r, column=col).number_format = "0.000"
            for col in range(1, 10):
                ws.cell(row=r, column=col).font = BODY_FONT
            r += 1
    note = ws.cell(row=r + 1, column=1, value=(
        "角2 が直角の角のときだけ使える。直角でない角や、コの字の棟は、角の番号を書き換えるか行を足す。"
        "差が ±0.3 m を超えたら、3本のうちどれかの読み違いを疑って測り直す（計画書 §4.4・§4.8）。"))
    note.alignment = WRAP
    ws.merge_cells(start_row=r + 1, start_column=1, end_row=r + 1, end_column=9)
    ws.row_dimensions[r + 1].height = 60
    ok_ng(ws, f"I2:I{r}", "I2", "測り直す")


def sheet_csv(wb):
    ws = wb.create_sheet("CSV")
    for i, (name, _) in enumerate(CSV_COLUMNS, start=1):
        ws.cell(row=1, column=i, value=name)
    for r in range(2, OBS_ROWS + 2):
        o = {k: f"'観測'!{v}{r}" for k, v in COL.items()}
        blank = f'{o["point"]}=""'
        for i, (name, key) in enumerate(CSV_COLUMNS, start=1):
            if name == "obs_type":
                f = f'=IF({blank},"",IF({o["type"]}="支距","chainage_offset","distance"))'
            elif name == "offset_side":
                f = f'=IF({blank},"",IF({o["side"]}="右","R",IF({o["side"]}="左","L","")))'
            elif name == "observed_at":
                f = (f'=IF({blank},"",IFERROR(TEXT(VLOOKUP({o["day"]},\'表紙\'!$A$3:$B$5,2,FALSE),"yyyy-mm-dd"),"")'
                     f'&"T"&TEXT({o["time"]},"hh:mm"))')
            else:
                f = f'=IF({blank},"",{o[key]}&"")'
            ws.cell(row=r, column=i, value=f)
    ws.freeze_panes = "A2"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--gsi", help="fgd-to-geojson --assign の出力（古い棟の国土地理院の形）")
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    args = parser.parse_args()
    gsi = load_gsi(args.gsi) if args.gsi else None
    if gsi and Path(args.out).resolve() == DEFAULT_OUT.resolve():
        raise SystemExit("--gsi の版はリポジトリのひな形に上書きしない。--out で別の場所を指定する。")

    wb = Workbook()
    sheet_usage(wb, bool(gsi))
    sheet_cover(wb)
    points_last = sheet_points(wb, gsi)
    baselines_last = sheet_baselines(wb, points_last)
    sheet_observations(wb, points_last, baselines_last)
    sheet_reference_check(wb, gsi)
    sheet_per_building(wb)
    sheet_csv(wb)
    wb.move_sheet("観測", offset=-(wb.sheetnames.index("観測") - 1))
    wb.active = wb.sheetnames.index("観測")
    wb.save(args.out)
    print(args.out)


if __name__ == "__main__":
    main()
