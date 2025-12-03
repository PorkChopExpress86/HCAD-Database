import pdfplumber, json, re, csv
from pathlib import Path

PDF_PATH = Path("database_info/pdataCodebook.pdf")
OUT_JSON = Path("database_info/pdataCodebook_structured.json")
OUT_DIR = Path("database_info/codebook_tables")
OUT_DIR.mkdir(exist_ok=True)
LINE_Y_TOL = 2.0

if not PDF_PATH.exists():
    raise SystemExit(f"Missing PDF: {PDF_PATH}")


def group_words_into_lines(words, tol=LINE_Y_TOL):
    lines = []
    for w in sorted(words, key=lambda x: (x["top"], x["x0"])):
        y = w["top"]
        for line in lines:
            if abs(line["y"] - y) <= tol:
                line["words"].append(w)
                break
        else:
            lines.append({"y": y, "words": [w]})
    for line in lines:
        line["words"].sort(key=lambda x: x["x0"])
        line["text"] = " ".join(w["text"] for w in line["words"])
    return lines


def detect_boundaries(lines):
    for line in lines:
        t = line["text"].lower()
        if all(p in t for p in ["column", "data", "size", "allow", "description"]):
            centers = {}
            for w in line["words"]:
                lt = w["text"].lower()
                if lt in ["column", "name"]:
                    centers.setdefault("column", []).append(w["x0"])
                elif lt == "data":
                    centers.setdefault("data_type", []).append(w["x0"])
                elif lt == "size":
                    centers.setdefault("size", []).append(w["x0"])
                elif lt == "allow":
                    centers.setdefault("allow_null", []).append(w["x0"])
                elif lt.startswith("description"):
                    centers.setdefault("description", []).append(w["x0"])
            if len(centers) >= 5:
                ordered = sorted(
                    ((k, sum(v) / len(v)) for k, v in centers.items()),
                    key=lambda kv: kv[1],
                )
                return ordered
    return None


def classify_lines(lines, boundaries):
    centers = [x for _, x in boundaries]
    names = [n for n, _ in boundaries]
    out = []
    for line in lines:
        cells = {n: [] for n in names}
        for w in line["words"]:
            dists = [abs(w["x0"] - c) for c in centers]
            idx = dists.index(min(dists))
            cells[names[idx]].append(w["text"])
        out.append(
            {
                "y": line["y"],
                "cells": {k: " ".join(v).strip() for k, v in cells.items()},
                "raw": line["text"],
            }
        )
    return out


tables = []
current = None
expect_header = False
boundaries = None

with pdfplumber.open(str(PDF_PATH)) as pdf:
    for page_index, page in enumerate(pdf.pages, start=1):
        words = page.extract_words(use_text_flow=True)
        lines = group_words_into_lines(words)
        if not boundaries:
            boundaries = detect_boundaries(lines)
            if not boundaries:
                continue
        classified = classify_lines(lines, boundaries)
        for row in classified:
            cells = row["cells"]
            raw = row["raw"]
            # Match 'Text file:' plus filename base optionally with .txt present somewhere in raw
            m = re.search(r"Text file:\s*([A-Za-z0-9_]+)(?:\.txt)?", raw)
            if m:
                fname = m.group(1)
                # ensure .txt extension
                if not fname.lower().endswith(".txt"):
                    fname = fname + ".txt"
                if current and current.get("fields"):
                    tables.append(current)
                current = {"file": fname, "page_start": page_index, "fields": []}
                expect_header = True
                continue
            if expect_header:
                if cells.get("column", "").lower().startswith("column"):
                    expect_header = False
                continue
            if not current:
                continue
            col = cells.get("column", "").strip()
            if col and col.lower() != "column name":
                current["fields"].append(
                    {
                        "name": col,
                        "data_type": cells.get("data_type", "").strip(),
                        "size": cells.get("size", "").strip(),
                        "allow_null": cells.get("allow_null", "").strip(),
                        "description": cells.get("description", "").strip(),
                        "page": page_index,
                    }
                )
            else:
                if current["fields"] and cells.get("description", "").strip():
                    last = current["fields"][-1]
                    add = cells["description"].strip()
                    if add and add not in last["description"]:
                        last["description"] += " " + add

if current and current.get("fields"):
    tables.append(current)

# cleanup
for tbl in tables:
    for f in tbl["fields"]:
        f["description"] = re.sub(r"\s+", " ", f["description"]).strip()

OUT_JSON.write_text(json.dumps({"tables": tables}, indent=2))
print(f"Extracted {len(tables)} tables to {OUT_JSON}")

for tbl in tables:
    csv_path = OUT_DIR / f"{tbl['file'].replace('.txt','')}_columns.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(
            [
                "Column Name",
                "Data Type",
                "Size",
                "Allow Null",
                "Description",
                "Source Page",
            ]
        )
        for f in tbl["fields"]:
            w.writerow(
                [
                    f["name"],
                    f["data_type"],
                    f["size"],
                    f["allow_null"],
                    f["description"],
                    f["page"],
                ]
            )
print(
    f"Wrote {len(list(OUT_DIR.glob('*_columns.csv')))} per-table CSV files in {OUT_DIR}"
)
