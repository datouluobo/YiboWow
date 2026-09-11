#!/usr/bin/env python3
"""Convert the Alpha client inventory snapshot into the catalog coverage baseline."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


TABLE_RE = re.compile(r"\{(?P<body>[^{}]*)\}", re.DOTALL)
NUMBER_FIELD_RE = r'\["{field}"\]\s*=\s*(\d+)'
STRING_FIELD_RE = r'\["{field}"\]\s*=\s*"((?:\\.|[^"])*)"'
BOOLEAN_FIELD_RE = r'\["{field}"\]\s*=\s*(true|false)'


def lua_unescape(value: str) -> str:
    return value.replace(r'\\"', '"').replace(r"\\\\", "\\")


def parse_snapshot(contents: str) -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    seen_spell_ids: set[int] = set()
    for match in TABLE_RE.finditer(contents):
        body = match["body"]
        mount_journal_id = re.search(NUMBER_FIELD_RE.format(field="mountJournalID"), body)
        spell_id_match = re.search(NUMBER_FIELD_RE.format(field="spellID"), body)
        name = re.search(STRING_FIELD_RE.format(field="name"), body)
        if not (mount_journal_id and spell_id_match and name):
            continue
        icon = re.search(NUMBER_FIELD_RE.format(field="icon"), body)
        spell_id = int(spell_id_match.group(1))
        if spell_id in seen_spell_ids:
            raise ValueError(f"duplicate spellID in snapshot: {spell_id}")
        seen_spell_ids.add(spell_id)
        record: dict[str, object] = {
            "mountJournalID": int(mount_journal_id.group(1)),
            "spellID": spell_id,
            "icon": int(icon.group(1)) if icon else None,
            "name": lua_unescape(name.group(1)),
        }
        for field in ("isCollected", "isFactionSpecific", "isUsable", "shouldHideOnChar"):
            boolean = re.search(BOOLEAN_FIELD_RE.format(field=field), body)
            if boolean:
                record[field] = boolean.group(1) == "true"
        for field in ("sourceType", "mountType", "faction"):
            number = re.search(NUMBER_FIELD_RE.format(field=field), body)
            if number:
                record[field] = int(number.group(1))
        for field in ("description", "sourceText"):
            string = re.search(STRING_FIELD_RE.format(field=field), body)
            if string:
                record[field] = lua_unescape(string.group(1))
        records.append(record)
    if not records:
        raise ValueError("no mountInventory records found; run /yms inventory, then fully exit the game before importing")
    return sorted(records, key=lambda record: int(record["spellID"]))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--saved-variables", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    try:
        records = parse_snapshot(args.saved_variables.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        parser.error(str(error))

    output = {
        "schemaVersion": 1,
        "source": "YiboMountSourceDiagnostics.mountInventory",
        "mountCount": len(records),
        "mounts": records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {len(records)} mount spellIDs to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
