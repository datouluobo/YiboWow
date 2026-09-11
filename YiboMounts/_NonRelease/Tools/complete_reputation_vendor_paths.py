#!/usr/bin/env python3
"""Normalize the level 60–90 exalted-reputation mount vendors.

Existing vendor paths already carry the authoritative faction, NPC, location,
and price.  This pass makes the purchase requirement machine-readable and
turns those rows into ``reputation_vendor`` sources without affecting the
Pandaren racial turtle vendor, where exalted reputation is only an alternative
to being a Pandaren.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


PANDAREN_TURTLES = {
    120395, 120822, 127286, 127287, 127288, 127289, 127290,
    127293, 127295, 127302, 127308, 127310,
}


def labels(text: str) -> dict[str, str]:
    return {"enUS": text, "zhCN": text}


def primary_source(mount: dict) -> dict:
    return next(source for source in mount["sources"] if source["sourceID"] == mount["primarySourceID"])


def first_faction(source: dict) -> str | None:
    for node in source.get("path", []):
        if node.get("kind") == "faction":
            return node.get("labels", {}).get("zhCN")
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    changed = 0
    for mount in catalog["mounts"]:
        spell_id = mount["ids"]["spellIDs"][0]
        if spell_id in PANDAREN_TURTLES:
            continue
        source = primary_source(mount)
        faction = first_faction(source)
        if source.get("type") != "vendor" or not faction or "崇拜" not in faction:
            continue
        source["type"] = "reputation_vendor"
        source["availability"] = "obtainable"
        source["requirements"]["reputation"] = {
            "faction": faction.removesuffix("（崇拜）"),
            "standing": "EXALTED",
        }
        changed += 1

    # The prior vendor pass gave the Azure Water Strider a retired Kalu'ak
    # location.  In this target version Nat Pagle sells it for The Anglers.
    mount = next(mount for mount in catalog["mounts"] if mount["ids"]["spellIDs"][0] == 118089)
    source = primary_source(mount)
    source["type"] = "reputation_vendor"
    source["availability"] = "obtainable"
    source["path"] = [
        {"kind": "faction", "refID": None, "labels": labels("垂钓翁（崇拜）")},
        {"kind": "zone", "refID": None, "labels": labels("卡桑琅丛林 > 垂钓翁码头")},
        {"kind": "npc", "refID": 63721, "labels": labels("纳特·帕格尔")},
    ]
    source["requirements"]["reputation"] = {"faction": "垂钓翁", "standing": "EXALTED"}
    source["requirements"]["price"] = labels("4,000金币")
    source["requirements"]["notes"] = labels("需垂钓翁崇拜购买。")

    args.catalog.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"normalized {changed} exalted reputation-vendor mount sources")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
