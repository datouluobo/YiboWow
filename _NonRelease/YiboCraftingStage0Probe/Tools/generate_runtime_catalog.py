#!/usr/bin/env python3
"""Generate the provisional YiboCrafting runtime catalog from reviewed evidence."""

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CANDIDATES = ROOT / "_NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032.json"
SOURCES = ROOT / "_NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032-external-source-diff.csv"
REPLACEMENTS = ROOT / "_NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032-ctm-replacement-map.csv"
ITEM_NAMES = ROOT / "_NonRelease/YiboCraftingStage0Probe/Candidates/5.5.4.70032-zhCN-item-names.json"
OUTPUT = ROOT / "YiboCrafting/Mists/RecipeCatalog.lua"
PROBE_ITEM_INDEX = ROOT / "_NonRelease/YiboCraftingStage0Probe/RecipeItemIndex.lua"

SOURCE_FIELDS = (
    ("clientObserved", "client"),
    ("legacyMopCatalog", "legacy"),
    ("atlasLootMop", "atlas"),
    ("attExpansionProfessionData", "att"),
)
# Spell 1257682 is an enchantment record with no CreatedItem row in the pinned
# client DB2. The linked enchant vellum (254314) was manually cross-referenced.
MANUAL = {1257682: {"outputItemIDs": [254314], "evidence": ["manual"]}}
BOUNDARY_ACTIONS = {
    55628: "professionAction",
    55641: "professionAction",
    113263: "professionAction",
    114112: "professionAction",
    60893: "researchAction",
    61177: "researchAction",
    61288: "researchAction",
    82207: "combatAction",
}
HISTORICAL_SKILL_ENTRIES = {
    405005: {
        "professionID": 773,
        "name_en": "Unknown Inscription recipe (removed in 4.0.3)",
        "evidence": "Pinned ATT 5.3.15 WotLK Profession data lists this as r(405005,{learnedAt=390,requireSkill=773,rwp=40003,u=31}); rwp=40003 means removed in patch 4.0.3. Build 70032 has no SpellName, SpellReagents, or SpellEffect row and no output-item mapping, so this is historical, not a current MoP recipe.",
    },
    66587: {
        "professionID": 755,
        "outputItemID": 40159,
        "name_en": "Stark Ametrine",
        "evidence": "Pinned ATT 5.3.15 Mists profession data preserves this as an older Jewelcrafting recipe (learnedAt=440, rwp=40003), and older WotLK/Cata alaTradeSkill data maps it to output item 40159 (Stark Ametrine). Build 70032 has no SpellName, SpellReagents, or SpellEffect row; it is a historical skill, not a current MoP recipe.",
    },
    # External-source-only history: this spell has no SkillLineAbility row in
    # the target build, so it is outside the DB2 candidate partition above.
    53979: {
        "professionID": 755,
        "outputItemID": 40043,
        "name_en": "Deadly Monarch Topaz",
        "name_zhCN": "致命帝黄晶",
        "evidence": "Pinned ATT 5.3.15 Mists data records this Jewelcrafting spell at skill 390 and marks it removed in 4.0.3 (rwp=40003). Older profession data names it Deadly Monarch Topaz; target build 70032 SpellName/Reagents/Effect identifies output item 40043. No SkillLineAbility row exists in the target build, so this is external historical evidence, not a current MoP recipe candidate.",
        "sourceOnly": True,
    },
}


def lua_array(values):
    return "{" + ",".join(str(int(value)) for value in values) + "}"


def main():
    document = json.loads(CANDIDATES.read_text(encoding="utf-8"))
    localized_items = json.loads(ITEM_NAMES.read_text(encoding="utf-8"))["items"]
    profession_ids = {profession["name"]: int(profession["skillLineID"])
                      for profession in document["professions"]}
    source_by_spell = {}
    with SOURCES.open(encoding="utf-8-sig", newline="") as source_file:
        for row in csv.DictReader(source_file):
            if row["candidate70032"] != "True":
                continue
            source_by_spell[int(row["recipeSpellID"])] = row

    profession_rows = []
    included = set()
    source_matched = set()
    boundary_actions = {}
    for profession in document["professions"]:
        profession_id = int(profession["skillLineID"])
        recipes = []
        for recipe in profession["recipes"]:
            spell_id = int(recipe["spellID"])
            row = source_by_spell.get(spell_id)
            evidence = [label for column, label in SOURCE_FIELDS
                        if row and row[column] == "True"]
            if not evidence and spell_id not in MANUAL:
                continue
            if evidence:
                source_matched.add(spell_id)
            if spell_id in BOUNDARY_ACTIONS:
                boundary_actions[spell_id] = {
                    "profession_id": profession_id,
                    "name": recipe["name"],
                    "kind": BOUNDARY_ACTIONS[spell_id],
                    "evidence": evidence,
                }
                continue
            products = [int(item_id) for item_id in recipe.get("createdItemIDs", [])]
            # Enchanting spells encode the vellum result on permanent-enchant
            # effects (53), rather than on a create-item effect. Use the pinned
            # target-build record, not another addon's runtime catalog.
            if profession_id == 333:
                products = sorted(set(products) | {
                    int(effect["effectItemType"])
                    for effect in recipe.get("effects", [])
                    if int(effect.get("effect", 0)) == 53
                    and int(effect.get("effectItemType", 0)) > 0
                })
            manual = MANUAL.get(spell_id)
            if manual:
                products = manual["outputItemIDs"]
                evidence.extend(manual["evidence"])
            categories = [int(category_id) for category_id in recipe.get("categoryIDs", [])]
            names = {item_id: localized_items[str(item_id)]["name_zhCN"]
                     for item_id in products if str(item_id) in localized_items}
            recipes.append((spell_id, products, categories, evidence, names))
            included.add(spell_id)
        if recipes:
            profession_rows.append((profession_id, recipes))

    historical_rows = {}
    with REPLACEMENTS.open(encoding="utf-8-sig", newline="") as source_file:
        for row in csv.DictReader(source_file):
            profession_id = profession_ids[row["profession"]]
            historical_spell_id = int(row["historicalRecipeSpellID"])
            historical_rows.setdefault(profession_id, []).append({
                "spell_id": historical_spell_id,
                "name_en": row["historicalName_en"],
                "output_item_id": int(row["historicalProductItemID"]),
                "output_name_zh": row["historicalProduct_zhCN"],
                "replacement_spell_id": int(row["currentCandidateSpellID"]),
                "replacement_output_item_id": int(row["currentProductItemID"]),
                "replacement_name_zh": row["currentProduct_zhCN"],
                "evidence": row["relationshipEvidence"],
            })

    unresolved_rows = []
    quarantined_by_id = {}
    for profession in document["professions"]:
        for spell_id in profession.get("quarantinedIDs", []):
            quarantined_by_id[int(spell_id)] = int(profession["skillLineID"])
            if int(spell_id) not in HISTORICAL_SKILL_ENTRIES:
                unresolved_rows.append((int(profession["skillLineID"]), int(spell_id)))
    for spell_id, entry in HISTORICAL_SKILL_ENTRIES.items():
        is_recipe_candidate = any(
            int(recipe["spellID"]) == spell_id
            for profession in document["professions"]
            for recipe in profession["recipes"]
        )
        if entry.get("sourceOnly"):
            if spell_id in quarantined_by_id or is_recipe_candidate:
                raise ValueError(f"source-only historical skill entry {spell_id} overlaps build candidates")
            continue
        if quarantined_by_id.get(spell_id) != entry["professionID"] or is_recipe_candidate:
            raise ValueError(f"historical skill entry {spell_id} no longer matches the reviewed quarantine")

    candidate_ids = {int(recipe["spellID"])
                     for profession in document["professions"]
                     for recipe in profession["recipes"]}
    candidate_count = len(candidate_ids)
    historical_count = sum(len(rows) for rows in historical_rows.values())
    # The fixed-source comparison leaves the 54 historical CTM spells and the
    # manually cross-referenced Tyranny enchant as its 55 unmatched rows.
    # Keep the reconciliation visible in runtime metadata instead of implying
    # that unmatched source rows were silently dropped.
    source_unmatched_count = candidate_count - len(source_matched)
    reconciled_unmatched_count = historical_count + len(MANUAL)
    historical_ids = {row["spell_id"] for rows in historical_rows.values() for row in rows}
    reconciled_ids = historical_ids | set(MANUAL)
    unmatched_ids = candidate_ids - source_matched
    if historical_ids & set(MANUAL):
        raise ValueError("historical and manual classifications overlap")
    if not reconciled_ids <= candidate_ids:
        raise ValueError("a reviewed unmatched classification is not a build candidate")
    if reconciled_ids & source_matched:
        raise ValueError("a source-matched candidate was classified as unmatched")
    if unmatched_ids != reconciled_ids:
        raise ValueError(
            "unmatched candidate IDs are not exactly reconciled: "
            f"missing={sorted(unmatched_ids - reconciled_ids)}, "
            f"unexpected={sorted(reconciled_ids - unmatched_ids)}"
        )
    if set(boundary_actions) != set(BOUNDARY_ACTIONS):
        raise ValueError(
            "boundary action candidates changed: "
            f"missing={sorted(set(BOUNDARY_ACTIONS) - set(boundary_actions))}, "
            f"unexpected={sorted(set(boundary_actions) - set(BOUNDARY_ACTIONS))}"
        )
    for spell_id in BOUNDARY_ACTIONS:
        candidate = next((recipe for profession in document["professions"]
                          for recipe in profession["recipes"] if int(recipe["spellID"]) == spell_id), None)
        if not candidate or candidate.get("createdItemIDs"):
            raise ValueError(f"boundary action {spell_id} now has a fixed product; review its classification")
    if candidate_count != len(included) + len(boundary_actions) + historical_count:
        raise ValueError(
            "build candidates are not partitioned into runtime recipes, actions, and historical spells: "
            f"{candidate_count} != {len(included)} + {len(boundary_actions)} + {historical_count}"
        )

    lines = [
        "-- Generated by _NonRelease/YiboCraftingStage0Probe/Tools/generate_runtime_catalog.py.",
        "-- Pinned client evidence build: 5.5.4.70032 / interface 50504.",
        "-- Provisional cross-reference; this catalog does not prove availability or completeness.",
        "-- Evidence labels: client (observed client spell), legacy (legacy MoP catalog),",
        "-- atlas (AtlasLootClassic MoP), att (ATT expansion data), manual (reviewed mapping).",
        "local Addon = _G.YiboCrafting",
        "Addon.RecipeCatalog = { build = \"5.5.4.70032\", catalogVersion = \"mop-5.5.4.70032-r5\", status = \"provisional\",",
        f"    audit = {{ candidateCount = {candidate_count}, sourceMatchedCount = {len(source_matched)}, sourceUnmatchedCount = {source_unmatched_count}, reconciledUnmatchedCount = {reconciled_unmatched_count}, runtimeRecipeCount = {len(included)}, boundaryActionCount = {len(boundary_actions)}, manualCount = {len(MANUAL)}, historicalReplacementCount = {historical_count}, historicalSkillEntryCount = {len(HISTORICAL_SKILL_ENTRIES)}, sourceOnlyHistoricalCount = {sum(1 for entry in HISTORICAL_SKILL_ENTRIES.values() if entry.get('sourceOnly'))}, unresolvedSkillEntryCount = {len(unresolved_rows)} }},",
        "    unresolvedSkillEntries = {",
    ]
    for profession_id, spell_id in sorted(unresolved_rows):
        lines.append(f"        {{ professionID = {profession_id}, spellID = {spell_id}, status = \"unresolved\" }},")
    lines.extend(["    },", "    historicalSkillEntries = {"])
    for spell_id, entry in sorted(HISTORICAL_SKILL_ENTRIES.items()):
        fields = [f"professionID = {entry['professionID']}"]
        if entry.get("outputItemID"):
            fields.append(f"outputItemID = {entry['outputItemID']}")
        fields.extend([
            f"name_en = {json.dumps(entry['name_en'])}",
            *( [f"name_zhCN = {json.dumps(entry['name_zhCN'], ensure_ascii=False)}"] if entry.get("name_zhCN") else [] ),
            'status = "historicalCandidate"',
            *( ['sourceOnly = true'] if entry.get("sourceOnly") else [] ),
            f"evidence = {json.dumps(entry['evidence'])}",
        ])
        lines.append(
            f"        [{spell_id}] = {{ {', '.join(fields)} }},"
        )
    lines.extend(["    },", "    boundaryActions = {"])
    for spell_id, action in sorted(boundary_actions.items()):
        evidence_text = "{" + ",".join(json.dumps(label) for label in action["evidence"]) + "}"
        lines.append(
            f"        [{spell_id}] = {{ professionID = {action['profession_id']}, "
            f"name_en = {json.dumps(action['name'])}, kind = {json.dumps(action['kind'])}, "
            f"evidence = {evidence_text} }},"
        )
    lines.extend(["    },", "    historicalReplacements = {"])
    for profession_id, rows in sorted(historical_rows.items()):
        lines.append(f"        [{profession_id}] = {{")
        for row in rows:
            lines.append(
                f"            [{row['spell_id']}] = {{ name_en = {json.dumps(row['name_en'], ensure_ascii=False)}, "
                f"outputItemID = {row['output_item_id']}, outputName_zhCN = {json.dumps(row['output_name_zh'], ensure_ascii=False)}, "
                f"replacementSpellID = {row['replacement_spell_id']}, replacementOutputItemID = {row['replacement_output_item_id']}, "
                f"replacementName_zhCN = {json.dumps(row['replacement_name_zh'], ensure_ascii=False)}, "
                f"evidence = {json.dumps(row['evidence'], ensure_ascii=False)} }},"
            )
        lines.append("        },")
    lines.extend(["    },", "    professions = {"])
    for profession_id, recipes in profession_rows:
        lines.append(f"    [{profession_id}] = {{")
        for spell_id, products, categories, evidence, names in recipes:
            evidence_text = "{" + ",".join(json.dumps(label) for label in evidence) + "}"
            names_text = "{" + ",".join(
                f"[{int(item_id)}]={json.dumps(name, ensure_ascii=False)}"
                for item_id, name in sorted(names.items())
            ) + "}"
            lines.append(
                f"        [{spell_id}] = {{ outputItemIDs = {lua_array(products)}, "
                f"outputItemNames = {names_text}, categoryIDs = {lua_array(categories)}, "
                f"evidence = {evidence_text} }},"
            )
        lines.append("    },")
    lines.extend(["} }", ""])
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    item_to_recipes = {}
    for _, recipes in profession_rows:
        for spell_id, products, _, _, _ in recipes:
            for item_id in products:
                item_to_recipes.setdefault(item_id, set()).add(spell_id)
    index_lines = [
        "-- Generated by _NonRelease/YiboCraftingStage0Probe/Tools/generate_runtime_catalog.py.",
        "-- Product Item ID to recipe Spell ID index for offline learning-API probes.",
        "_G.YiboCraftingStage0RecipeItemIndex = { build = \"5.5.4.70032\", catalogVersion = \"mop-5.5.4.70032-r5\", itemToRecipeIDs = {",
    ]
    for item_id, spell_ids in sorted(item_to_recipes.items()):
        index_lines.append(f"    [{item_id}] = {lua_array(sorted(spell_ids))},")
    index_lines.extend(["} }", ""])
    PROBE_ITEM_INDEX.write_text("\n".join(index_lines), encoding="utf-8", newline="\n")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}: {len(included)} recipes across {len(profession_rows)} professions")
    print(f"Wrote {PROBE_ITEM_INDEX.relative_to(ROOT)}: {len(item_to_recipes)} product item IDs")


if __name__ == "__main__":
    main()
