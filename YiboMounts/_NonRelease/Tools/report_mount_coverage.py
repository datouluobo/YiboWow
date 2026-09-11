#!/usr/bin/env python3
"""Report catalog coverage against the client-derived mount spellID baseline."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
    catalog_by_spell = {
        spell_id
        for mount in catalog["mounts"]
        for spell_id in mount["ids"]["spellIDs"]
    }
    records = inventory["mounts"]
    baseline_by_spell = {record["spellID"]: record for record in records}
    baseline_spells = set(baseline_by_spell)
    missing = [baseline_by_spell[spell_id] for spell_id in sorted(baseline_spells - catalog_by_spell)]
    extra = sorted(catalog_by_spell - baseline_spells)
    visible_records = [record for record in records if not record.get("shouldHideOnChar", False)]

    report = {
        "schemaVersion": 1,
        "baseline": {
            "rawTotal": len(records),
            "visibleForSnapshotCharacter": len(visible_records),
        },
        "catalog": {
            "covered": len(baseline_spells & catalog_by_spell),
            "missing": len(missing),
            "extraSpellIDs": extra,
        },
        "missingMounts": missing,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"coverage: {report['catalog']['covered']}/{report['baseline']['rawTotal']}; wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
