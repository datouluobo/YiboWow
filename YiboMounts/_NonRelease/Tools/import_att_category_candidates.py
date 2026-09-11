#!/usr/bin/env python3
"""Import non-release ATT category evidence as explicitly provisional V1 records.

This tool never imports ATT paths, display text, or Lua data.  It only combines
the pre-generated spell/item/category reference with the local client Mount
Journal capture.  Existing hand-authored records always win.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


TYPE_BY_CATEGORY = {
    "achievement": "achievement",
    "vendor": "vendor",
    "crafted": "crafted",
    "quest": "quest",
    "event": "event",
    "promotion": "promotion",
    "store": "store",
    "boss_drop": "boss_drop",
}

PREFERENCE = tuple(TYPE_BY_CATEGORY)
PENDING_LABELS = {
    "enUS": "Details pending verification",
    "zhCN": "详细地点待核实",
}


def choose_category(categories: list[str]) -> str | None:
    available = set(categories)
    return next((category for category in PREFERENCE if category in available), None)


def build_record(candidate: dict, mount: dict, category: str) -> dict:
    spell_id = candidate["spellID"]
    source_type = TYPE_BY_CATEGORY[category]
    source_id = f"provisional-category-{source_type.replace('_', '-')}"
    return {
        "mountKey": f"provisional-{spell_id}",
        "status": "candidate",
        "ids": {
            "spellIDs": [spell_id],
            "itemIDs": [candidate["itemID"]],
            "mountJournalID": mount["mountJournalID"],
        },
        # The English placeholder is not displayed by V1.  The in-game aura
        # supplies the localized mount name; zhCN here comes from the local API.
        "identity": {
            "iconFileID": mount.get("icon"),
            "names": {"enUS": f"Mount {spell_id}", "zhCN": mount["name"]},
        },
        "restrictions": {"factions": [], "classes": []},
        "primarySourceID": source_id,
        "sources": [{
            "sourceID": source_id,
            "type": source_type,
            "priority": 1,
            "active": True,
            "availability": "unknown",
            "path": [{"kind": "research", "refID": None, "labels": PENDING_LABELS}],
            "requirements": {
                "difficulties": [], "reputation": None, "costs": [],
                "questID": None, "achievementID": None, "eventKey": None,
                "notes": None,
            },
        }],
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

    existing_spells = {
        spell_id
        for record in catalog["mounts"]
        for spell_id in record["ids"]["spellIDs"]
    }
    inventory_by_spell = {record["spellID"]: record for record in inventory["mounts"]}

    additions = []
    for candidate in reference["candidates"]:
        spell_id = candidate["spellID"]
        category = choose_category(candidate["categories"])
        mount = inventory_by_spell.get(spell_id)
        if category and mount and spell_id not in existing_spells:
            additions.append(build_record(candidate, mount, category))

    additions.sort(key=lambda record: record["ids"]["spellIDs"][0])
    print(f"eligible provisional additions: {len(additions)}")
    if not args.apply:
        return 0

    normalized = 0
    for record in catalog["mounts"]:
        if not record["mountKey"].startswith(("att-candidate-", "provisional-")):
            continue
        if record["mountKey"].startswith("att-candidate-"):
            record["mountKey"] = record["mountKey"].replace("att-candidate-", "provisional-", 1)
            normalized += 1
        for source in record["sources"]:
            corrected = source["sourceID"].replace("att-category-", "provisional-category-").replace("_", "-")
            if corrected != source["sourceID"]:
                source["sourceID"] = corrected
                if record["primarySourceID"] != corrected:
                    record["primarySourceID"] = corrected
                normalized += 1
            source["requirements"]["notes"] = None
    catalog["mounts"].extend(additions)
    args.catalog.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"added {len(additions)} records; normalized {normalized} records in {args.catalog}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
