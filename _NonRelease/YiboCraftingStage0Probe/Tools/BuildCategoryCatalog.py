"""Build a recipe-to-native-category lookup from the pinned client catalog.

Category names come from local, player-observed profession lists. Only spell IDs
and game category labels enter the generated addon file; character/account data
and third-party addon code are never copied.
"""

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re


def observed_categories(paths):
    observations = defaultdict(Counter)
    for path in paths:
        profession = category = None
        in_crafts = False
        for raw in Path(path).read_text(encoding="utf-8-sig").splitlines():
            line = raw.strip()
            if not in_crafts:
                match = re.fullmatch(r'\["Name"\] = "(.*)",', line)
                if match:
                    profession = match.group(1)
                if line == '["Crafts"] = {':
                    in_crafts = True
                    category = None
                continue
            if line == "},":
                in_crafts = False
                continue
            match = re.fullmatch(r'"(\d+)\|(.*)",', line)
            if not match:
                continue
            rank, value = match.groups()
            if rank == "0":
                category = value if value not in {"全部", "搜索", "All", "Search"} else None
            elif category and value.isdecimal() and profession:
                observations[(profession, int(value))][category] += 1
    return observations


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("observations", nargs="+", type=Path)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    observed = observed_categories(args.observations)
    labels = defaultdict(Counter)
    for profession in catalog["professions"]:
        name, profession_id = profession["name"], profession["skillLineID"]
        for recipe in profession["recipes"]:
            category_ids = recipe.get("categoryIDs") or []
            if len(category_ids) != 1:
                continue
            for category_name, count in observed[(name, recipe["spellID"])].items():
                labels[(profession_id, category_ids[0])][category_name] += count
    resolved = {key: next(iter(counts)) for key, counts in labels.items() if len(counts) == 1}
    grouped = defaultdict(lambda: defaultdict(list))
    unresolved_categories = defaultdict(lambda: defaultdict(list))
    unresolved = 0
    for profession in catalog["professions"]:
        name, profession_id = profession["name"], profession["skillLineID"]
        for recipe in profession["recipes"]:
            category_ids = recipe.get("categoryIDs") or []
            category_name = resolved.get((profession_id, category_ids[0])) if len(category_ids) == 1 else None
            if not category_name:
                directly_observed = observed[(name, recipe["spellID"])]
                if len(directly_observed) == 1:
                    category_name = next(iter(directly_observed))
            if category_name:
                grouped[profession_id][category_name].append(recipe["spellID"])
            else:
                unresolved += 1
                if len(category_ids) == 1 and category_ids[0] > 0:
                    unresolved_categories[profession_id][category_ids[0]].append(recipe["spellID"])
    lines = [
        "-- Generated from pinned 5.5.4.69934 SkillLineAbility categories and",
        "-- local client-observed profession category labels (DataStore_Crafts SavedVariables).",
        "-- No character identifiers or third-party addon code are included. Classification only:",
        "-- these entries do not establish that any character learned a recipe.",
        "local catalog = {",
    ]
    for profession_id in sorted(grouped):
        lines.append(f"    [{profession_id}] = {{")
        for name in sorted(grouped[profession_id]):
            ids = sorted(set(grouped[profession_id][name]))
            lines.append(f"        [{json.dumps(name, ensure_ascii=False)}] = {{")
            for start in range(0, len(ids), 12):
                lines.append("            " + ", ".join(str(value) for value in ids[start:start + 12]) + ",")
            lines.append("        },")
        lines.append("    },")
    lines.append("}")
    lines.append("local unresolved = {")
    for profession_id in sorted(unresolved_categories):
        lines.append(f"    [{profession_id}] = {{")
        for category_id in sorted(unresolved_categories[profession_id]):
            ids = sorted(set(unresolved_categories[profession_id][category_id]))
            lines.append(f"        [{category_id}] = {{" + ", ".join(str(value) for value in ids) + "},")
        lines.append("    },")
    lines.extend([
        "}",
        "local lookup, categoryIDLookup, categoryNameCache = {}, {}, {}",
        "for professionID, categories in pairs(catalog) do",
        "    lookup[professionID] = {}",
        "    for name, ids in pairs(categories) do",
        "        for _, recipeID in ipairs(ids) do lookup[professionID][recipeID] = name end",
        "    end",
        "end",
        "for professionID, categories in pairs(unresolved) do",
        "    categoryIDLookup[professionID] = {}",
        "    for categoryID, ids in pairs(categories) do",
        "        for _, recipeID in ipairs(ids) do categoryIDLookup[professionID][recipeID] = categoryID end",
        "    end",
        "end",
        "_G.YiboCrafting.CategoryCatalog = {",
        "    Get = function(_, professionID, recipeID)",
        "        local recipes = lookup[professionID]",
        "        if recipes and recipes[recipeID] then return recipes[recipeID] end",
        "        local categoryIDs = categoryIDLookup[professionID]",
        "        local categoryID = categoryIDs and categoryIDs[recipeID]",
        "        if not categoryID then return nil end",
        "        if categoryNameCache[categoryID] then return categoryNameCache[categoryID] end",
        "        local api = C_TradeSkillUI and C_TradeSkillUI.GetCategoryInfo",
        "        if type(api) ~= \"function\" then return nil end",
        "        local ok, info = pcall(api, categoryID)",
        "        local name = ok and (type(info) == \"table\" and info.name or info)",
        "        if type(name) == \"string\" and name ~= \"\" then",
        "            categoryNameCache[categoryID] = name",
        "            return name",
        "        end",
        "    end,",
        "}",
        "",
    ])
    args.output.write_text("\n".join(lines), encoding="utf-8")
    print(f"classified={sum(len(ids) for categories in grouped.values() for ids in categories.values())} unresolved={unresolved} categoryLabels={len(resolved)}")


if __name__ == "__main__":
    main()
