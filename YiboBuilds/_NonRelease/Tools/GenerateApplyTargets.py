"""Generate target masks for known enhancement application spells.

The source is the MoP Classic client SpellEquippedItems table. Records without
an explicit target row are intentionally omitted from executable candidates.
"""

import csv
import io
import re
from pathlib import Path

import requests


BUILD = "5.5.4.69934"
SOCKET_APPLICATION_SPELLS = {55628, 55641, 55655, 76168, 113263, 114112, 131467}
ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "Data" / "EnchantCatalog.lua"
ENGINEERING_CATALOG = ROOT / "Data" / "EngineeringCatalog.lua"
OUTPUT = ROOT / "Data" / "ApplyTargets.lua"
CRAFT_OUTPUT = ROOT / "Data" / "CraftSources.lua"
ENGINEERING_OUTPUT = ROOT / "Data" / "EngineeringApply.lua"
REAGENTS_OUTPUT = ROOT / "Data" / "RecipeReagents.lua"


def main():
    catalog = CATALOG.read_text(encoding="utf-8")
    applying_items = {
        int(item_id)
        for item_id in re.findall(r"catalog\[\d+\].*?itemID = (\d+)", catalog)
    }
    applying_items.update({41611, 55054, 90046})
    spell_ids = {
        int(spell_id)
        for spell_id in re.findall(r"catalog\[\d+\].*?spellID = (\d+)", catalog)
    }
    spell_ids.update(SOCKET_APPLICATION_SPELLS)
    url = f"https://wago.tools/db2/SpellEquippedItems/csv?build={BUILD}"
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    rows = csv.DictReader(io.StringIO(response.text))
    targets = {}
    all_targets = {}
    for row in rows:
        spell_id = int(row["SpellID"])
        target = (
            int(row["EquippedItemClass"]),
            int(row["EquippedItemInvTypes"]),
            int(row["EquippedItemSubclass"]),
        )
        all_targets[spell_id] = target
        if spell_id in spell_ids:
            targets[spell_id] = target
    lines = [
        f"-- Generated from SpellEquippedItems, MoP Classic client build {BUILD}.",
        "-- Key is the application spell ID; masks are class, inventory type, subclass.",
        "local targets = {}",
    ]
    for spell_id, (item_class, inventory_mask, subclass_mask) in sorted(targets.items()):
        lines.append(
            f"targets[{spell_id}] = {{ classID = {item_class}, inventoryMask = {inventory_mask}, subclassMask = {subclass_mask} }}"
        )
    lines.append("_G.YiboBuilds.ApplyTargets = targets")
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {len(targets)} target mappings to {OUTPUT}")

    item_response = requests.get(f"https://wago.tools/db2/Item/csv?build={BUILD}", timeout=45)
    item_response.raise_for_status()
    gem_subclasses = {
        int(row["ID"]): int(row["SubclassID"])
        for row in csv.DictReader(io.StringIO(item_response.text))
        if row["ClassID"] == "3"
    }
    effect_response = requests.get(f"https://wago.tools/db2/SpellEffect/csv?build={BUILD}", timeout=45)
    effect_response.raise_for_status()
    crafts = {}
    engineering = ENGINEERING_CATALOG.read_text(encoding="utf-8")
    engineering_ids = {int(value) for value in re.findall(r"catalog\[(\d+)\]", engineering)}
    engineering_spells = {}
    for row in csv.DictReader(io.StringIO(effect_response.text)):
        if row["Effect"] == "53":
            record_id = int(row["EffectMiscValue_0"] or 0)
            spell_id = int(row["SpellID"])
            if record_id in engineering_ids and spell_id in all_targets:
                engineering_spells.setdefault(record_id, set()).add(spell_id)
        if row["Effect"] != "24":
            continue
        item_id = int(row["EffectItemType"] or 0)
        if item_id not in applying_items and item_id not in gem_subclasses:
            continue
        spell_id = int(row["SpellID"])
        crafts.setdefault(item_id, set()).add(spell_id)
    skill_response = requests.get(f"https://wago.tools/db2/SkillLineAbility/csv?build={BUILD}", timeout=30)
    skill_response.raise_for_status()
    craft_spell_ids = {spell for recipes in crafts.values() for spell in recipes}
    known_professions = {164, 165, 197, 202, 333, 755, 773}
    recipe_skills = {}
    for row in csv.DictReader(io.StringIO(skill_response.text)):
        spell_id = int(row["Spell"])
        profession = int(row["SkillLine"])
        if spell_id in craft_spell_ids and profession in known_professions:
            recipe_skills[spell_id] = (profession, int(row["MinSkillLineRank"] or 0))
    craft_lines = [
        f"-- Generated from Item and SpellEffect, MoP Classic client build {BUILD}.",
        "-- Runtime still requires the current character to have learned the recipe.",
        "local sources = {}",
    ]
    for item_id, recipes in sorted(crafts.items()):
        subtype = gem_subclasses.get(item_id)
        recipe_list = ", ".join(str(recipe) for recipe in sorted(recipes))
        gem_part = f", gemSubclass = {subtype}" if subtype is not None else ""
        skill_list = ", ".join(
            f"[{recipe}] = {{ {recipe_skills[recipe][0]}, {recipe_skills[recipe][1]} }}"
            for recipe in sorted(recipes) if recipe in recipe_skills
        )
        craft_lines.append(
            f"sources[{item_id}] = {{ recipes = {{ {recipe_list} }}, skills = {{ {skill_list} }}{gem_part} }}"
        )
    craft_lines.append("_G.YiboBuilds.CraftSources = sources")
    CRAFT_OUTPUT.write_text("\n".join(craft_lines) + "\n", encoding="utf-8")
    print(f"wrote {len(crafts)} craft sources to {CRAFT_OUTPUT}")

    engineering_lines = [
        f"-- Generated from SpellEffect and SpellEquippedItems, MoP Classic client build {BUILD}.",
        "-- Each effect record lists only spells that actually apply it to equipment.",
        "local applications = {}",
    ]
    for record_id, spells in sorted(engineering_spells.items()):
        spell_list = ", ".join(
            "{ spellID = %d, classID = %d, inventoryMask = %d, subclassMask = %d }"
            % ((spell,) + all_targets[spell])
            for spell in sorted(spells)
        )
        engineering_lines.append(f"applications[{record_id}] = {{ {spell_list} }}")
    engineering_lines.append("_G.YiboBuilds.EngineeringApply = applications")
    ENGINEERING_OUTPUT.write_text("\n".join(engineering_lines) + "\n", encoding="utf-8")
    print(f"wrote {len(engineering_spells)} engineering applications to {ENGINEERING_OUTPUT}")

    relevant_spells = spell_ids | craft_spell_ids | {
        spell for spells in engineering_spells.values() for spell in spells
    }
    reagent_response = requests.get(f"https://wago.tools/db2/SpellReagents/csv?build={BUILD}", timeout=45)
    reagent_response.raise_for_status()
    reagents = {}
    for row in csv.DictReader(io.StringIO(reagent_response.text)):
        spell_id = int(row["SpellID"])
        if spell_id not in relevant_spells:
            continue
        entries = []
        for index in range(8):
            item_id = int(row[f"Reagent_{index}"] or 0)
            count = int(row[f"ReagentCount_{index}"] or 0)
            if item_id > 0 and count > 0:
                entries.append((item_id, count))
        if entries:
            reagents[spell_id] = entries
    reagent_lines = [
        f"-- Generated from SpellReagents, MoP Classic client build {BUILD}.",
        "-- Material counts are checked against the current character's bags at execution time.",
        "local reagents = {}",
    ]
    for spell_id, entries in sorted(reagents.items()):
        items = ", ".join(f"{{ {item_id}, {count} }}" for item_id, count in entries)
        reagent_lines.append(f"reagents[{spell_id}] = {{ {items} }}")
    reagent_lines.append("_G.YiboBuilds.RecipeReagents = reagents")
    REAGENTS_OUTPUT.write_text("\n".join(reagent_lines) + "\n", encoding="utf-8")
    print(f"wrote {len(reagents)} reagent records to {REAGENTS_OUTPUT}")


if __name__ == "__main__":
    main()
