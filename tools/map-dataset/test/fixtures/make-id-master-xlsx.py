#!/usr/bin/env python3
"""テスト用の最小 xlsx フィクスチャ `id-master.xlsx` を生成する。

実測原本の値は複製せず、契約確認に必要な最小の合成データだけを入れる。
Python 標準ライブラリのみを使う。バイナリを差し替えるときは次を実行する。

    python3 test/fixtures/make-id-master-xlsx.py

シート `登録` の内容:

| 区分   | コード   | 名称       | 状態     | 日付ID          |
|--------|----------|------------|----------|-----------------|
| 建物   | mb       | 教室棟     | 確認済み |                 |
| 建物   | ptb      | 実習棟     | 確認済み |                 |
| 道路   | road_001 | 正門前道路 | 未確認   |                 |
| エリア | area_001 | （空欄）   | 未確認   | 46215（日付書式）|

最終行は「必須値が空欄」「セルが日付書式で生値の意味が確定しない」という
異常系を確認するために置いている。
"""

import os
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = os.path.join(HERE, "id-master.xlsx")

NAMESPACE_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NAMESPACE_RELS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

# (値, スタイル索引) のいずれか。スタイル索引 1 は組み込み日付書式 numFmtId=14。
ROWS = [
    [("区分", None), ("コード", None), ("名称", None), ("状態", None), ("日付ID", None)],
    [("建物", None), ("mb", None), ("教室棟", None), ("確認済み", None)],
    [("建物", None), ("ptb", None), ("実習棟", None), ("確認済み", None)],
    [("道路", None), ("road_001", None), ("正門前道路", None), ("未確認", None)],
    [("エリア", None), ("area_001", None), ("", None), ("未確認", None), (46215, 1)],
]


def escape(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def sheet_xml() -> str:
    parts = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        f'<worksheet xmlns="{NAMESPACE_MAIN}"><sheetData>',
    ]
    for row_index, cells in enumerate(ROWS, start=1):
        parts.append(f'<row r="{row_index}">')
        for column_index, (value, style) in enumerate(cells):
            if value == "":
                continue
            ref = chr(ord("A") + column_index) + str(row_index)
            style_attribute = f' s="{style}"' if style is not None else ""
            if isinstance(value, str):
                parts.append(
                    f'<c r="{ref}"{style_attribute} t="inlineStr">'
                    f"<is><t>{escape(value)}</t></is></c>"
                )
            else:
                parts.append(f'<c r="{ref}"{style_attribute}><v>{value}</v></c>')
        parts.append("</row>")
    parts.append("</sheetData></worksheet>")
    return "".join(parts)


FILES = {
    "[Content_Types].xml": (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        "</Types>"
    ),
    "_rels/.rels": (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        "</Relationships>"
    ),
    "xl/workbook.xml": (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<workbook xmlns="{NAMESPACE_MAIN}" xmlns:r="{NAMESPACE_RELS}">'
        '<sheets><sheet name="登録" sheetId="1" r:id="rId1"/></sheets></workbook>'
    ),
    "xl/_rels/workbook.xml.rels": (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        "</Relationships>"
    ),
    "xl/styles.xml": (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<styleSheet xmlns="{NAMESPACE_MAIN}">'
        '<cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="14" applyNumberFormat="1"/></cellXfs>'
        "</styleSheet>"
    ),
    "xl/worksheets/sheet1.xml": sheet_xml(),
}


def main() -> None:
    with zipfile.ZipFile(TARGET, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in FILES.items():
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, content.encode("utf-8"))
    print(f"wrote {TARGET} ({os.path.getsize(TARGET)} bytes)")


if __name__ == "__main__":
    main()
