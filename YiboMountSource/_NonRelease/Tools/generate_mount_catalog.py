#!/usr/bin/env python3
"""Validate YiboMountSource source data and generate its runtime Lua catalog."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


KEY_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SOURCE_TYPES = {
    "boss_drop", "rare_drop", "achievement", "reputation_vendor", "vendor",
    "quest", "class_reward", "holiday", "event", "promotion", "store", "crafted", "research",
}
AVAILABILITY = {"obtainable", "limited_time", "rotation", "unavailable", "unknown"}
STATUSES = {"candidate", "verified", "rejected"}


class ValidationError(Exception):
    pass


def fail(path: str, message: str) -> None:
    raise ValidationError(f"{path}: {message}")


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value:
        fail(path, "must be a non-empty string")
    return value


def require_positive_integer(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        fail(path, "must be a positive integer")
    return value


def validate_labels(labels: Any, path: str, channel: str) -> None:
    if not isinstance(labels, dict):
        fail(path, "must be an object")
    require_string(labels.get("enUS"), path + ".enUS")
    if channel == "release":
        require_string(labels.get("zhCN"), path + ".zhCN")


def validate_catalog(root: Any, channel: str) -> list[str]:
    warnings: list[str] = []
    if not isinstance(root, dict):
        fail("$", "must be an object")
    if root.get("schemaVersion") != 1:
        fail("$.schemaVersion", "must equal 1")
    require_string(root.get("catalogVersion"), "$.catalogVersion")
    target = root.get("target")
    if not isinstance(target, dict):
        fail("$.target", "must be an object")
    if target.get("flavor") != "MISTS_CLASSIC":
        fail("$.target.flavor", "must equal MISTS_CLASSIC")
    if target.get("gameVersion") != "5.5.4":
        fail("$.target.gameVersion", "must equal 5.5.4")
    if target.get("interface") != 50504:
        fail("$.target.interface", "must equal 50504")

    mounts = root.get("mounts")
    if not isinstance(mounts, list) or not mounts:
        fail("$.mounts", "must be a non-empty array")

    keys: set[str] = set()
    spell_ids: set[int] = set()
    for index, mount in enumerate(mounts):
        path = f"$.mounts[{index}]"
        if not isinstance(mount, dict):
            fail(path, "must be an object")
        mount_key = require_string(mount.get("mountKey"), path + ".mountKey")
        if not KEY_RE.fullmatch(mount_key):
            fail(path + ".mountKey", "must use lower kebab-case ASCII")
        if mount_key in keys:
            fail(path + ".mountKey", f"duplicates {mount_key}")
        keys.add(mount_key)

        status = mount.get("status")
        if status not in STATUSES:
            fail(path + ".status", "must be candidate, verified, or rejected")
        if channel == "release" and status != "verified":
            fail(path + ".status", "release catalogs only permit verified records")
        if status == "candidate":
            warnings.append(f"{mount_key}: candidate record included")

        ids = mount.get("ids")
        if not isinstance(ids, dict):
            fail(path + ".ids", "must be an object")
        mount_spells = ids.get("spellIDs")
        if not isinstance(mount_spells, list) or not mount_spells:
            fail(path + ".ids.spellIDs", "must be a non-empty array")
        local_spells: set[int] = set()
        for spell_index, spell_id in enumerate(mount_spells):
            spell_path = f"{path}.ids.spellIDs[{spell_index}]"
            require_positive_integer(spell_id, spell_path)
            if spell_id in local_spells or spell_id in spell_ids:
                fail(spell_path, f"duplicates spellID {spell_id}")
            local_spells.add(spell_id)
            spell_ids.add(spell_id)
        for item_index, item_id in enumerate(ids.get("itemIDs", [])):
            require_positive_integer(item_id, f"{path}.ids.itemIDs[{item_index}]")

        identity = mount.get("identity")
        if not isinstance(identity, dict):
            fail(path + ".identity", "must be an object")
        validate_labels(identity.get("names"), path + ".identity.names", channel)

        primary_source_id = require_string(mount.get("primarySourceID"), path + ".primarySourceID")
        sources = mount.get("sources")
        if not isinstance(sources, list) or not sources:
            fail(path + ".sources", "must be a non-empty array")
        source_ids: set[str] = set()
        found_primary = False
        for source_index, source in enumerate(sources):
            source_path = f"{path}.sources[{source_index}]"
            if not isinstance(source, dict):
                fail(source_path, "must be an object")
            source_id = require_string(source.get("sourceID"), source_path + ".sourceID")
            if not KEY_RE.fullmatch(source_id) or source_id in source_ids:
                fail(source_path + ".sourceID", "must be unique lower kebab-case ASCII")
            source_ids.add(source_id)
            found_primary = found_primary or source_id == primary_source_id
            if source.get("type") not in SOURCE_TYPES:
                fail(source_path + ".type", "uses an unsupported source type")
            availability = source.get("availability")
            if availability not in AVAILABILITY:
                fail(source_path + ".availability", "uses an unsupported availability state")
            if channel == "release" and availability == "unknown":
                fail(source_path + ".availability", "unknown availability cannot ship in a release")
            path_nodes = source.get("path")
            if not isinstance(path_nodes, list) or not path_nodes:
                fail(source_path + ".path", "must be a non-empty array")
            for node_index, node in enumerate(path_nodes):
                node_path = f"{source_path}.path[{node_index}]"
                if not isinstance(node, dict):
                    fail(node_path, "must be an object")
                require_string(node.get("kind"), node_path + ".kind")
                validate_labels(node.get("labels"), node_path + ".labels", channel)
            requirements = source.get("requirements")
            if not isinstance(requirements, dict):
                fail(source_path + ".requirements", "must be an object")
            for cost_index, cost in enumerate(requirements.get("costs", [])):
                cost_path = f"{source_path}.requirements.costs[{cost_index}]"
                if not isinstance(cost, dict) or cost.get("type") not in {"money", "currency", "item"}:
                    fail(cost_path, "must be a money, currency, or item cost")
                if cost["type"] == "money":
                    require_positive_integer(cost.get("amountCopper"), cost_path + ".amountCopper")
                else:
                    require_positive_integer(cost.get("amount"), cost_path + ".amount")
                    require_positive_integer(cost.get("currencyID" if cost["type"] == "currency" else "itemID"), cost_path)
            if availability == "unavailable" and not path_nodes:
                fail(source_path, "unavailable sources require a historical path")
        if not found_primary:
            fail(path + ".primarySourceID", "does not refer to a source")
    return warnings


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lua_value(value: Any, indent: int = 0) -> str:
    pad = " " * indent
    child_pad = " " * (indent + 2)
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return lua_quote(value)
    if isinstance(value, list):
        if not value:
            return "{}"
        entries = [child_pad + lua_value(item, indent + 2) for item in value]
        return "{\n" + ",\n".join(entries) + "\n" + pad + "}"
    if isinstance(value, dict):
        if not value:
            return "{}"
        entries = []
        for key in sorted(value):
            if isinstance(key, int) and not isinstance(key, bool):
                key_text = f"[{key}]"
            elif isinstance(key, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                key_text = key
            else:
                key_text = "[" + lua_quote(str(key)) + "]"
            entries.append(child_pad + key_text + " = " + lua_value(value[key], indent + 2))
        return "{\n" + ",\n".join(entries) + "\n" + pad + "}"
    raise TypeError(f"unsupported Lua value: {type(value)!r}")


def build_runtime_data(root: dict[str, Any]) -> dict[str, Any]:
    mounts: dict[str, Any] = {}
    spell_index: dict[int, str] = {}
    for mount in sorted(root["mounts"], key=lambda entry: entry["mountKey"]):
        # Numeric extraction is non-release evidence only.  It deliberately
        # remains in mounts.json for the resolver, but must never become a
        # player-facing tooltip until names and source roles are normalized.
        source = next((item for item in mount["sources"] if item["sourceID"] == mount["primarySourceID"]), None)
        if mount["mountKey"].startswith(("provisional-", "fact-")):
            labels = [node.get("labels", {}).get("zhCN", "") for node in (source or {}).get("path", [])]
            if not source or source.get("type") == "research" or not labels or any("#" in label for label in labels):
                continue
        record = dict(mount)
        record["ids"] = dict(record["ids"])
        record["ids"].pop("spellIDs", None)
        mounts[mount["mountKey"]] = record
        for spell_id in mount["ids"]["spellIDs"]:
            spell_index[spell_id] = mount["mountKey"]
    return {
        "schemaVersion": root["schemaVersion"],
        "catalogVersion": root["catalogVersion"],
        "mounts": mounts,
        "mountKeyBySpellID": dict(sorted(spell_index.items())),
    }


def write_lua(root: dict[str, Any], output: Path) -> None:
    runtime_data = build_runtime_data(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    contents = "-- GENERATED FILE — DO NOT EDIT.\n-- Source: _NonRelease/Data/mounts.json\nlocal _, NS = ...\n\nNS.Data = " + lua_value(runtime_data) + "\n"
    output.write_text(contents, encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--channel", choices=("alpha", "release"), default="alpha")
    args = parser.parse_args()
    try:
        root = json.loads(args.input.read_text(encoding="utf-8"))
        warnings = validate_catalog(root, args.channel)
        write_lua(root, args.output)
    except (OSError, json.JSONDecodeError, ValidationError, TypeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)
    print(f"generated {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
