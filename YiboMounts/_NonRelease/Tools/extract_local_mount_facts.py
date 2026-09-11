#!/usr/bin/env python3
"""Extract only numeric, game-fact hints for target mount spells from Lua data files.

This is an offline research aid. It never executes the input Lua and it writes
only mount, item, instance, encounter, NPC, quest, achievement and profession
IDs. Names, comments, UI text, code, file contents and source layout are not
copied into the output. The resulting facts must still be normalized and
localized by Yibo before they can become tooltip records.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path


ITEM_RE = re.compile(r"\bitemID\s*=\s*(\d+)\b")
SIMPLE_PROPERTIES = {
    "mapIDs": re.compile(r"\bmaps?\s*=\s*\{([^}]*)\}", re.S),
    "npcIDs": re.compile(r"\bnpcID\s*=\s*(\d+)\b"),
    "achievementIDs": re.compile(r"\bachievementID\s*=\s*(\d+)\b"),
    "questIDs": re.compile(r"\bquestID\s*=\s*(\d+)\b"),
    "professionIDs": re.compile(r"\b(?:requireSkill|skillID)\s*=\s*(\d+)\b"),
    "factionIDs": re.compile(r"\b(?:factionID|faction)\s*=\s*(\d+)\b"),
}
FIELDS = {
    "inst": "instanceIDs",
    "e": "encounterIDs",
    "n": "npcIDs",
    "ach": "achievementIDs",
    "q": "questIDs",
    "prof": "professionIDs",
}


def read_call(text: str, offset: int) -> tuple[str | None, int | None]:
    """Return `name(number` metadata for an opening parenthesis."""
    index = offset - 1
    while index >= 0 and text[index].isspace():
        index -= 1
    end = index + 1
    while index >= 0 and (text[index].isalnum() or text[index] == "_"):
        index -= 1
    name = text[index + 1:end]
    if not name:
        return None, None
    index = offset + 1
    while index < len(text) and text[index].isspace():
        index += 1
    end_number = index
    while end_number < len(text) and text[end_number].isdigit():
        end_number += 1
    return name, int(text[index:end_number]) if end_number > index else None


def numbers(value: str) -> list[int]:
    return [int(number) for number in re.findall(r"\b\d+\b", value)]


def add_values(target: dict[str, list[int]], field: str, values: list[int]) -> None:
    if values:
        target.setdefault(field, [])
        target[field] = sorted(set(target[field]).union(values))


def paren_depth_at(text: str, position: int) -> int:
    """Return lexical parenthesis depth, ignoring quoted literals and comments."""
    depth = 0
    index = 0
    while index < position:
        char = text[index]
        if char in {"'", '"'}:
            quote = char
            index += 1
            while index < position:
                if text[index] == "\\":
                    index += 2
                elif text[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
            continue
        if text.startswith("--", index):
            newline = text.find("\n", index, position)
            index = position if newline == -1 else newline + 1
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        index += 1
    return depth


def direct_matches(body: str, pattern: re.Pattern[str]) -> list[re.Match[str]]:
    """Keep fields belonging to this call, not nested/sibling function calls."""
    return [match for match in pattern.finditer(body) if paren_depth_at(body, match.start()) == 1]


def properties(body: str) -> dict[str, list[int]]:
    result: dict[str, list[int]] = {}
    for field, pattern in SIMPLE_PROPERTIES.items():
        matches = [match.group(1) for match in direct_matches(body, pattern)]
        flattened: list[int] = []
        for match in matches:
            flattened.extend(numbers(match if isinstance(match, str) else str(match)))
        add_values(result, field, flattened)
    item_matches = direct_matches(body, ITEM_RE)
    if item_matches:
        add_values(result, "itemIDs", [int(match.group(1)) for match in item_matches])
    return result


def collect_mount_nodes(text: str) -> list[tuple[int, dict[str, list[int]], str]]:
    """Lex Lua enough to retain real call ancestors without executing input."""
    pending: list[tuple[dict, list[dict]]] = []
    stack: list[dict] = []
    index = 0
    while index < len(text):
        char = text[index]
        if char in {"'", '"'}:
            quote = char
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                elif text[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
            continue
        if text.startswith("--", index):
            newline = text.find("\n", index)
            index = len(text) if newline == -1 else newline + 1
            continue
        if char == "(":
            name, value = read_call(text, index)
            stack.append({"name": name, "value": value, "start": index, "end": None})
        elif char == ")" and stack:
            frame = stack.pop()
            frame["end"] = index
            if frame["name"] == "mnt" and isinstance(frame["value"], int):
                pending.append((frame, list(stack)))
        index += 1
    nodes: list[tuple[int, dict[str, list[int]], str]] = []
    for frame, ancestors in pending:
        hint = properties(text[frame["start"]:frame["end"] + 1])
        for parent in ancestors:
            field = FIELDS.get(parent["name"])
            if field and isinstance(parent["value"], int):
                add_values(hint, field, [parent["value"]])
            if parent["name"] in {"inst", "e", "n", "q", "ach", "r", "prof", "faction"} and parent["end"] is not None:
                for name, values in properties(text[parent["start"]:parent["end"] + 1]).items():
                    add_values(hint, name, values)
        nodes.append((frame["value"], hint, text[frame["start"]:frame["end"] + 1]))
    return nodes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
    wanted = {int(record["spellID"]) for record in inventory["mounts"]}
    facts: dict[int, list[dict]] = defaultdict(list)
    for path in sorted(args.source_root.rglob("*.lua")):
        if path.name in {"ReferenceDB.lua", "LocalizationDB.lua"}:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for spell_id, hint, _ in collect_mount_nodes(text):
            if spell_id not in wanted:
                continue
            if hint and hint not in facts[spell_id]:
                facts[spell_id].append(hint)

    records = [
        {"spellID": spell_id, "hints": hints}
        for spell_id, hints in sorted(facts.items())
    ]
    result = {
        "schemaVersion": 1,
        "purpose": "offline numeric game-fact research; not runtime data",
        "mountCount": len(records),
        "mounts": records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote numeric hints for {len(records)}/{len(wanted)} target mount spells to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
