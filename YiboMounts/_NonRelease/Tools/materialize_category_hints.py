#!/usr/bin/env python3
"""Turn previously imported source categories into readable alpha placeholders."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


TYPE_BY_CATEGORY = {"achievement": "achievement", "vendor": "vendor", "crafted": "crafted", "quest": "quest", "event": "event", "promotion": "promotion", "store": "store", "boss_drop": "boss_drop"}
PENDING = {"enUS": "Location pending verification", "zhCN": "详细地点待核实"}


def player_facing(source):
    labels = [node.get("labels", {}).get("zhCN", "") for node in source.get("path", [])]
    return source.get("type") != "research" and labels and not any("#" in label for label in labels)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    reference = json.loads(args.reference.read_text(encoding="utf-8"))
    categories = {row["spellID"]: next((TYPE_BY_CATEGORY[item] for item in row["categories"] if item in TYPE_BY_CATEGORY), None) for row in reference["candidates"]}
    changed = 0
    for mount in catalog["mounts"]:
        spell_id = mount["ids"]["spellIDs"][0]
        source_type = categories.get(spell_id)
        primary = next((source for source in mount["sources"] if source["sourceID"] == mount["primarySourceID"]), None)
        if not source_type or not primary or player_facing(primary):
            continue
        source_id = "category-hint-" + str(spell_id)
        mount["primarySourceID"] = source_id
        mount["sources"] = [{"sourceID": source_id, "type": source_type, "priority": 1, "active": True, "availability": "unknown", "path": [{"kind": "research", "refID": None, "labels": PENDING}], "requirements": {"difficulties": [], "reputation": None, "costs": [], "questID": None, "achievementID": None, "eventKey": None, "notes": None}}]
        changed += 1
    args.catalog.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"materialized {changed} category-only alpha source hints")


if __name__ == "__main__":
    main()
