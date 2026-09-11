#!/usr/bin/env python3
"""Build a non-release ATT MoP category reference without shipping ATT data."""

from __future__ import annotations

import argparse
import base64
import json
import re
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen


REPOSITORY = "query-csharp/AllTheThings-MoP"
BASE_PATH = "contrib/Parser/DATAS"
CATEGORY_FILES = {
    "boss_drop": "14 - Mounts/Drop.lua",
    "achievement": "14 - Mounts/Achievement.lua",
    "vendor": "14 - Mounts/Vendor.lua",
    "crafted": "14 - Mounts/Profession.lua",
    "quest": "14 - Mounts/Quest.lua",
    "event": "14 - Mounts/World Event.lua",
    "store": "14 - Mounts/In-Game Shop.lua",
    "promotion": "14 - Mounts/Promotion.lua",
}
ITEM_RE = re.compile(r"\bi\((\d+)\)")


def fetch_file(path: str) -> str:
    encoded_path = quote(path, safe="")
    request = Request(
        f"https://api.github.com/repos/{REPOSITORY}/contents/{encoded_path}",
        headers={"Accept": "application/vnd.github+json", "User-Agent": "YiboMounts-reference-builder"},
    )
    with urlopen(request, timeout=30) as response:
        payload = json.load(response)
    return base64.b64decode(payload["content"]).decode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    mount_db = json.loads(fetch_file(f"{BASE_PATH}/00 - Item Database/MountsDB.json"))
    spell_by_item = {
        record["itemId"]: record["mountID"]
        for record in mount_db["mounts"]
        if isinstance(record.get("itemId"), int) and isinstance(record.get("mountID"), int)
    }
    categories_by_item: dict[int, set[str]] = {}
    for category, relative_path in CATEGORY_FILES.items():
        for item_id in map(int, ITEM_RE.findall(fetch_file(f"{BASE_PATH}/{relative_path}"))):
            categories_by_item.setdefault(item_id, set()).add(category)

    candidates = []
    for item_id, categories in sorted(categories_by_item.items()):
        spell_id = spell_by_item.get(item_id)
        if spell_id:
            candidates.append({
                "spellID": spell_id,
                "itemID": item_id,
                "categories": sorted(categories),
            })
    result = {
        "schemaVersion": 1,
        "purpose": "non-release research queue only; not runtime data",
        "sourceRepository": f"https://github.com/{REPOSITORY}",
        "fetchedAt": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "candidates": candidates,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {len(candidates)} categorized spellID candidates to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
