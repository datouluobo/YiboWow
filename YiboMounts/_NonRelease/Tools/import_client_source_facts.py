#!/usr/bin/env python3
"""Turn a target-client Mount Journal source snapshot into Yibo candidates.

The input is the diagnostics snapshot emitted by this addon. It contains only
the game's IDs and Mount Journal source string; no other addon code, database
structure, branding, comments, or assets are read or emitted. Hand-authored
records always win, while earlier provisional records are upgraded in place.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


# `sourceType` is the MoP Classic Mount Journal category. Category-reference
# evidence wins when available because it distinguishes special categories.
TYPE_BY_CLIENT_SOURCE = {
    1: "boss_drop",
    2: "quest",
    3: "vendor",
    4: "crafted",
    5: "achievement",
    6: "promotion",
    7: "store",
}
TYPE_BY_REFERENCE_CATEGORY = {
    "achievement": "achievement",
    "boss_drop": "boss_drop",
    "crafted": "crafted",
    "event": "event",
    "promotion": "promotion",
    "quest": "quest",
    "store": "store",
    "vendor": "vendor",
}


def compact(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def reference_types(reference: dict) -> dict[int, str]:
    result: dict[int, str] = {}
    for candidate in reference.get("candidates", []):
        for category in candidate.get("categories", []):
            source_type = TYPE_BY_REFERENCE_CATEGORY.get(category)
            if source_type:
                result[int(candidate["spellID"])] = source_type
                break
    return result


def build_source(spell_id: int, source_type: str, text: str) -> dict:
    source_id = f"client-source-{spell_id}"
    return {
        "sourceID": source_id,
        "type": source_type,
        "priority": 10,
        "active": True,
        "availability": "unknown",
        "path": [{"kind": "custom", "refID": None, "labels": {"enUS": text, "zhCN": text}}],
        "requirements": {
            "difficulties": [], "reputation": None, "costs": [],
            "questID": None, "achievementID": None, "eventKey": None,
            "notes": None,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
    reference = json.loads(args.reference.read_text(encoding="utf-8"))
    category_by_spell = reference_types(reference)
    records_by_spell = {
        spell_id: record
        for record in catalog["mounts"]
        for spell_id in record["ids"]["spellIDs"]
    }

    planned, upgraded, skipped = 0, 0, 0
    for mount in inventory["mounts"]:
        spell_id = int(mount["spellID"])
        text = compact(str(mount.get("sourceText") or ""))
        source_type = category_by_spell.get(spell_id) or TYPE_BY_CLIENT_SOURCE.get(mount.get("sourceType"))
        record = records_by_spell.get(spell_id)
        if not text or not source_type or not record or not record["mountKey"].startswith("provisional-"):
            skipped += 1
            continue
        planned += 1
        if args.apply:
            source = build_source(spell_id, source_type, text)
            record["primarySourceID"] = source["sourceID"]
            record["sources"] = [source]
            upgraded += 1

    print(f"client-source candidates: {planned}; upgraded: {upgraded}; skipped: {skipped}")
    if args.apply:
        args.catalog.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
