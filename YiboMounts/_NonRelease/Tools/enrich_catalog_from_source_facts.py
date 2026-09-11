#!/usr/bin/env python3
"""Build readable alpha source paths from YMS numeric facts and SavedVariables.

This consumes only normalized YMS JSON plus client-resolved names.  It does
not execute, bundle, or reference ATT code at runtime.
"""
from __future__ import annotations

import argparse
import json
import runpy
from pathlib import Path


def load_names(saved_variables: Path) -> dict[int, dict[str, dict[int, str]]]:
    helper = runpy.run_path(str(Path(__file__).with_name("import_source_fact_names.py")))
    text = saved_variables.read_text(encoding="utf-8")
    start = text.find('["sourceFactNames"]')
    if start < 0:
        raise ValueError("sourceFactNames not found")
    root = helper["balanced_table"](text, start)
    result = {}
    for spell_id, body in helper["child_tables"](root).items():
        result[spell_id] = {}
        for field in helper["FIELDS"]:
            marker = '["' + field + '"]'
            field_at = body.find(marker)
            if field_at >= 0:
                result[spell_id][field] = helper["string_entries"](helper["balanced_table"](body, field_at))
    return result


def name_for(names, field, identifier):
    value = names.get(field, {}).get(identifier)
    return value if isinstance(value, str) and value else None


def node(kind, identifier, zh_name, fallback):
    return {
        "kind": kind,
        "refID": identifier,
        "labels": {"enUS": fallback, "zhCN": zh_name or fallback},
    }


def first_named(names, field, identifiers):
    for identifier in identifiers or []:
        value = name_for(names, field, identifier)
        if value:
            return identifier, value
    return None, None


def best_hint(existing_type, hints, names):
    def score(hint):
        score = 0
        if first_named(names, "achievementNames", hint.get("achievementIDs"))[1]: score += 100
        if first_named(names, "questNames", hint.get("questIDs"))[1]: score += 90
        if first_named(names, "professionNames", hint.get("professionIDs"))[1]: score += 80
        if first_named(names, "instanceNames", hint.get("instanceIDs"))[1] or first_named(names, "encounterNames", hint.get("encounterIDs"))[1]: score += 70
        if first_named(names, "npcNames", hint.get("npcIDs"))[1]: score += 50
        if first_named(names, "mapNames", hint.get("mapIDs"))[1]: score += 20
        if existing_type == "boss_drop" and (hint.get("instanceIDs") or hint.get("encounterIDs")): score += 40
        if existing_type == "achievement" and hint.get("achievementIDs"): score += 40
        if existing_type == "quest" and hint.get("questIDs"): score += 40
        if existing_type == "crafted" and hint.get("professionIDs"): score += 40
        return score
    return max(hints, key=score, default={})


def build_source(spell_id, existing_type, hints, names):
    hint = best_hint(existing_type, hints, names)
    instance_id, instance = first_named(names, "instanceNames", hint.get("instanceIDs"))
    encounter_id, encounter = first_named(names, "encounterNames", hint.get("encounterIDs"))
    npc_id, npc = first_named(names, "npcNames", hint.get("npcIDs"))
    map_id, map_name = first_named(names, "mapNames", hint.get("mapIDs"))
    achievement_id, achievement = first_named(names, "achievementNames", hint.get("achievementIDs"))
    quest_id, quest = first_named(names, "questNames", hint.get("questIDs"))
    profession_id, profession = first_named(names, "professionNames", hint.get("professionIDs"))

    if existing_type == "achievement" and achievement:
        source_type, path = "achievement", [node("achievement", achievement_id, achievement, "Achievement " + str(achievement_id))]
    elif existing_type == "quest" and quest:
        source_type, path = "quest", ([node("zone", map_id, map_name, "Map " + str(map_id))] if map_name else []) + [node("quest", quest_id, quest, "Quest " + str(quest_id))]
    elif existing_type == "crafted" and profession:
        source_type, path = "crafted", [node("profession", profession_id, profession, "Profession " + str(profession_id))]
    elif existing_type == "boss_drop" and (instance or encounter or npc):
        source_type, path = "boss_drop", []
        if instance: path.append(node("instance", instance_id, instance, "Instance " + str(instance_id)))
        elif map_name: path.append(node("zone", map_id, map_name, "Map " + str(map_id)))
        if encounter: path.append(node("boss", encounter_id, encounter, "Encounter " + str(encounter_id)))
        elif npc: path.append(node("boss", npc_id, npc, "NPC " + str(npc_id)))
    elif achievement:
        source_type, path = "achievement", [node("achievement", achievement_id, achievement, "Achievement " + str(achievement_id))]
    elif quest:
        source_type, path = "quest", ([node("zone", map_id, map_name, "Map " + str(map_id))] if map_name else []) + [node("quest", quest_id, quest, "Quest " + str(quest_id))]
    elif profession:
        source_type, path = "crafted", [node("profession", profession_id, profession, "Profession " + str(profession_id))]
    elif npc and map_name:
        source_type, path = "rare_drop", [node("zone", map_id, map_name, "Map " + str(map_id)), node("npc", npc_id, npc, "NPC " + str(npc_id))]
    elif npc:
        source_type, path = "vendor", [node("npc", npc_id, npc, "NPC " + str(npc_id))]
    elif instance or encounter:
        source_type, path = "boss_drop", []
        if instance: path.append(node("instance", instance_id, instance, "Instance " + str(instance_id)))
        if encounter: path.append(node("boss", encounter_id, encounter, "Encounter " + str(encounter_id)))
    else:
        return None

    return {
        "sourceID": "enriched-source-" + str(spell_id),
        "type": source_type,
        "priority": 10,
        "active": True,
        "availability": "unknown",
        "path": path,
        "requirements": {"difficulties": [], "reputation": None, "costs": [], "questID": quest_id, "achievementID": achievement_id, "eventKey": None, "notes": None},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--facts", type=Path, required=True)
    parser.add_argument("--saved-variables", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, required=True)
    args = parser.parse_args()
    facts = {record["spellID"]: record["hints"] for record in json.loads(args.facts.read_text(encoding="utf-8"))["mounts"]}
    names = load_names(args.saved_variables)
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    enriched = 0
    for mount in catalog["mounts"]:
        if not mount["mountKey"].startswith(("provisional-", "fact-")):
            continue
        spell_id = mount["ids"]["spellIDs"][0]
        existing = next((source for source in mount["sources"] if source["sourceID"] == mount["primarySourceID"]), mount["sources"][0])
        source = build_source(spell_id, existing["type"], facts.get(spell_id, []), names.get(spell_id, {}))
        if source:
            mount["sources"] = [source]
            mount["primarySourceID"] = source["sourceID"]
            enriched += 1
    args.catalog.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"enriched {enriched} candidate mount source paths")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
