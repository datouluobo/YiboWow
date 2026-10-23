"""Generate the Mists socketable item set from ItemSparse.Gem_properties.

Usage: python YiboBuilds/_NonRelease/Tools/GenerateGemCatalog.py [ItemSparse.csv]
Without a CSV path, fetch the pinned client table from wago.tools.
"""
import csv
import io
import sys
import urllib.request
from pathlib import Path

BUILD = "5.5.4.69934"
URL = f"https://wago.tools/db2/ItemSparse/csv?build={BUILD}"
ROOT = Path(__file__).resolve().parents[2]


def main():
    if len(sys.argv) > 1:
        source = Path(sys.argv[1]).read_text(encoding="utf-8-sig")
    else:
        with urllib.request.urlopen(URL, timeout=60) as response:
            source = response.read().decode("utf-8-sig")
    rows = list(csv.DictReader(io.StringIO(source)))
    gems = sorted({int(row["ID"]) for row in rows if int(row["Gem_properties"]) > 0})
    if not gems:
        raise ValueError("No socketable items found")
    lines = [
        f"-- Generated from ItemSparse.Gem_properties, Mists build {BUILD}.",
        f"-- Source: {URL}",
        "-- Nonzero gem properties identify socketable items, including non-crafted gems.",
        "local gems = {",
    ]
    for start in range(0, len(gems), 10):
        lines.append("    " + ", ".join(f"[{item_id}] = true" for item_id in gems[start:start + 10]) + ",")
    lines.extend(["}", "_G.YiboBuilds.GemCatalog = gems", ""])
    output = ROOT / "Mists" / "Data" / "GemCatalog.lua"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {len(gems)} socketable items: {output}")


if __name__ == "__main__":
    main()
