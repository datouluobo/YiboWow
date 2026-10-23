"""Generate ordered Mists base sockets from the pinned ItemSparse table.

Usage: python YiboBuilds/_NonRelease/Tools/GenerateSocketCatalog.py [ItemSparse.csv]
"""
import csv
import io
import sys
import urllib.request
from pathlib import Path

BUILD = "5.5.4.69934"
URL = f"https://wago.tools/db2/ItemSparse/csv?build={BUILD}"
ROOT = Path(__file__).resolve().parents[2]
# ItemSparse stores socket type indexes, not GemProperties color bitmasks.
TYPES = {0: "", 1: "m", 2: "r", 3: "y", 4: "b", 5: "s", 6: "u", 7: "p"}


def main():
    if len(sys.argv) > 1:
        source = Path(sys.argv[1]).read_text(encoding="utf-8-sig")
    else:
        with urllib.request.urlopen(URL, timeout=60) as response:
            source = response.read().decode("utf-8-sig")
    groups = {}
    for row in csv.DictReader(io.StringIO(source)):
        sockets = [int(row[f"SocketType_{index}"]) for index in range(3)]
        if not any(sockets):
            continue
        last = max(index for index, socket in enumerate(sockets) if socket)
        layout = "".join(TYPES[socket] or "u" for socket in sockets[:last + 1])
        groups.setdefault(layout, set()).add(int(row["ID"]))
    if not groups:
        raise ValueError("No socket layouts found")
    lines = [
        f"-- Generated from ordered ItemSparse.SocketType_0..2, Mists build {BUILD}.",
        f"-- Source: {URL}",
        "-- m=meta, r=red, y=yellow, b=blue, p=prismatic, s=sha, u=unknown.",
        "local layouts = {}",
        "local function Add(layout, ids)",
        "    for _, id in ipairs(ids) do layouts[id] = layout end",
        "end",
    ]
    for layout, ids in sorted(groups.items()):
        lines.append(f'Add("{layout}", {{')
        ids = sorted(ids)
        for start in range(0, len(ids), 15):
            lines.append("    " + ", ".join(map(str, ids[start:start + 15])) + ",")
        lines.append("})")
    lines.extend(["_G.YiboBuilds.SocketCatalog = layouts", ""])
    output = ROOT / "Mists" / "Data" / "SocketCatalog.lua"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {sum(map(len, groups.values()))} layouts in {len(groups)} groups: {output}")


if __name__ == "__main__":
    main()
