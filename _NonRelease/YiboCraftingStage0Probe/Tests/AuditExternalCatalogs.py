"""Compare pinned third-party profession data with a local candidate catalog.

The script stores only source identifiers, source file hashes, and differences.
It does not copy third-party Lua files into the repository.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import pathlib
import re
import urllib.request
import urllib.parse
from datetime import datetime, timezone


ATLAS_REPO = "snowflame0/AtlasLootClassic_MoP"
ATLAS_COMMIT = "ecaa6bd7958fa43ebeb917a0bb330f3ba7c46841"
ATLAS_PATH = "AtlasLootClassic_Crafting/data-mop.lua"
ATT_REPO = "ATTWoWAddon/AllTheThings"
ATT_COMMIT = "694a22cd1ab2b7a56cb360e51b5a20e11f883540"
ATT_CATEGORY_PATHS = [
    "db/Vanilla/Categories/Professions.lua",
    "db/TBC/Categories/Professions.lua",
    "db/Wrath/Categories/Professions.lua",
    "db/Cata/Categories/Professions.lua",
    "db/Mists/Categories/Professions.lua",
]
ATT_CRAFTABLE_PATHS = [
    f"db/{expansion}/Categories/Craftables.lua"
    for expansion in ("Vanilla", "TBC", "Wrath", "Cata", "Mists")
]

PROFESSION_FILES = {
    "急救": ("First Aid", "FirstAid"),
    "锻造": ("Blacksmithing", "Blacksmithing"),
    "制皮": ("Leatherworking", "Leatherworking"),
    "炼金术": ("Alchemy", "Alchemy"),
    "烹饪": ("Cooking", "Cooking"),
    "采矿": ("Mining", "Mining"),
    "裁缝": ("Tailoring", "Tailoring"),
    "工程学": ("Engineering", "Engineering"),
    "附魔": ("Enchanting", "Enchanting"),
    "珠宝加工": ("Jewelcrafting", "Jewelcrafting"),
    "铭文": ("Inscription", "Inscription"),
    "符文熔铸": (None, None),
}
ATT_SKILLLINE_TO_ROOT = {
    9787: 164, 9788: 164,
    17039: 171, 17040: 171, 17041: 171,
    10656: 165, 10658: 165, 10660: 165,
}


def fetch(repo: str, revision: str, path: str) -> tuple[bytes, str]:
    url = f"https://raw.githubusercontent.com/{repo}/{revision}/{urllib.parse.quote(path, safe='/')}"
    request = urllib.request.Request(url, headers={"User-Agent": "YiboCraftingEvidenceAudit"})
    with urllib.request.urlopen(request, timeout=45) as response:
        raw = response.read()
    return raw, hashlib.sha256(raw).hexdigest()


def parse_atlas(raw: bytes) -> dict[str, set[int]]:
    text = raw.decode("utf-8-sig")
    starts = list(re.finditer(r'^data\["([^\"]+)"\]\s*=\s*\{', text, re.MULTILINE))
    result = {}
    for index, start in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        table = start.group(1)
        result[table] = {
            int(value)
            for value in re.findall(r"\{\s*\d+\s*,\s*(\d+)\s*\}", text[start.start():end])
        }
    return result


def extract_lua_table(text: str, open_brace: int) -> str:
    depth = 0
    quote = None
    escaped = False
    line_comment = False
    index = open_brace
    while index < len(text):
        char = text[index]
        following = text[index:index + 2]
        if line_comment:
            if char == "\n":
                line_comment = False
        elif quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif following == "--":
            line_comment = True
            index += 1
        elif char in "\"'":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[open_brace:index + 1]
        index += 1
    raise ValueError("unbalanced Lua braces while extracting ATT profession block")


def parse_att(raw: bytes) -> dict[int, set[int]]:
    text = raw.decode("utf-8-sig")
    result = {}
    for match in re.finditer(r"\bprof\((\d+)\s*,\s*\{", text):
        skill_line_id = int(match.group(1))
        open_brace = text.find("{", match.start())
        block = extract_lua_table(text, open_brace)
        result.setdefault(skill_line_id, set()).update(
            int(value) for value in re.findall(r"\br\((\d+)\b", block)
        )
    return result


def parse_recipe_refs(raw: bytes) -> set[int]:
    text = raw.decode("utf-8-sig")
    return {int(value) for value in re.findall(r"\br\((\d+)\b", text)}


def format_review_recipe(recipe: dict, spell_id: int, localized_items: dict) -> str:
    item_labels = []
    for item_id in recipe.get("createdItemIDs", []):
        localized = localized_items.get(str(item_id), {}).get("name_zhCN", "名称未解析")
        item_labels.append(f"{localized} [Item ID: {item_id}]")
    if not item_labels and spell_id == 1257682:
        item_labels.append("武器附魔：暴政（按英文法术名翻译；无产物 Item ID）")
    elif not item_labels:
        item_labels.append("无产物名称")
    spell_name = recipe.get("name") or "无英文 SpellName"
    return f"{'、'.join(item_labels)} / {spell_name} [Spell ID: {spell_id}]"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=pathlib.Path)
    parser.add_argument("--report", required=True, type=pathlib.Path)
    parser.add_argument("--csv", required=True, type=pathlib.Path)
    args = parser.parse_args()

    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    localized_path = args.catalog.with_name(args.catalog.stem + "-zhCN-item-names.json")
    localized_blob = localized_path.read_bytes() if localized_path.exists() else b"{}"
    localized_data = json.loads(localized_blob.decode("utf-8"))
    localized_items = localized_data.get("items", {})
    atlas_raw, atlas_hash = fetch(ATLAS_REPO, ATLAS_COMMIT, ATLAS_PATH)
    atlas_tables = parse_atlas(atlas_raw)
    att_by_skillline = {}
    att_craftable_ids = set()
    att_hashes = {}
    for path in ATT_CATEGORY_PATHS:
        raw, digest = fetch(ATT_REPO, ATT_COMMIT, path)
        for skill_line_id, recipe_ids in parse_att(raw).items():
            root_id = ATT_SKILLLINE_TO_ROOT.get(skill_line_id, skill_line_id)
            att_by_skillline.setdefault(root_id, set()).update(recipe_ids)
        att_hashes[path] = digest
    for path in ATT_CRAFTABLE_PATHS:
        raw, digest = fetch(ATT_REPO, ATT_COMMIT, path)
        att_craftable_ids.update(parse_recipe_refs(raw))
        att_hashes[path] = digest

    rows = []
    summaries = []
    db2_only = {}
    recipe_details = {}
    for profession in catalog["professions"]:
        name = profession["name"]
        atlas_name = PROFESSION_FILES[name][1]
        atlas_ids = atlas_tables.get(f"{atlas_name}MoP", set()) if atlas_name else set()
        candidates = {int(recipe["spellID"]) for recipe in profession["recipes"]}
        observed_ids = {
            int(recipe["spellID"]) for recipe in profession["recipes"] if recipe["observed"]
        }
        legacy_ids = {
            int(recipe["spellID"])
            for recipe in profession["recipes"]
            if recipe["inLegacyCatalog"] is True
        }
        att_ids = (
            att_by_skillline.get(int(profession["skillLineID"]), set())
            | (att_craftable_ids & candidates)
        )
        atlas_hits = candidates & atlas_ids
        att_hits = candidates & att_ids
        both_hits = atlas_hits & att_hits
        any_evidence = atlas_hits | att_hits | observed_ids | legacy_ids
        db2_only[name] = sorted(candidates - any_evidence)
        recipe_details[name] = {
            int(recipe["spellID"]): recipe
            for recipe in profession["recipes"]
        }
        summaries.append(
            f"| {name} | {len(candidates)} | {len(observed_ids)} | {len(legacy_ids)} | "
            f"{len(atlas_hits)} | {len(att_hits)} | {len(both_hits)} | "
            f"{len(candidates - any_evidence)} | "
            f"{len(atlas_ids - candidates)} | {len(att_ids - candidates)} |"
        )
        for spell_id in sorted(candidates | atlas_ids):
            rows.append({
                "profession": name,
                "recipeSpellID": spell_id,
                "recipeName_enUS": recipe_details[name].get(spell_id, {}).get("name", ""),
                "createdItemIDs_ItemID": ";".join(
                    str(item_id)
                    for item_id in recipe_details[name].get(spell_id, {}).get("createdItemIDs", [])
                ),
                "createdItemNames_zhCN": ";".join(
                    localized_items.get(str(item_id), {}).get("name_zhCN", "")
                    for item_id in recipe_details[name].get(spell_id, {}).get("createdItemIDs", [])
                ),
                "candidate70032": spell_id in candidates,
                "clientObserved": spell_id in observed_ids,
                "legacyMopCatalog": spell_id in legacy_ids,
                "atlasLootMop": spell_id in atlas_ids,
                "attExpansionProfessionData": spell_id in att_ids,
            })
    candidate_by_id = {
        int(recipe["spellID"]): profession["name"]
        for profession in catalog["professions"]
        for recipe in profession["recipes"]
    }
    att_all_ids = att_craftable_ids | set().union(*att_by_skillline.values())
    external_only = (set().union(*atlas_tables.values()) | att_all_ids) - set(candidate_by_id)
    for skill_ids in att_by_skillline.values():
        external_only.update(skill_ids - set(candidate_by_id))
    for spell_id in sorted(external_only):
        atlas_hit = any(spell_id in ids for ids in atlas_tables.values())
        att_hit = spell_id in att_all_ids
        rows.append({
            "profession": "外部源独有/待映射",
            "recipeSpellID": spell_id,
            "recipeName_enUS": "",
            "createdItemIDs_ItemID": "",
            "createdItemNames_zhCN": "",
            "candidate70032": False,
            "clientObserved": False,
            "legacyMopCatalog": False,
            "atlasLootMop": atlas_hit,
            "attExpansionProfessionData": att_hit,
        })

    args.csv.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.csv.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["profession", "recipeSpellID", "recipeName_enUS", "createdItemIDs_ItemID", "createdItemNames_zhCN", "candidate70032", "clientObserved", "legacyMopCatalog", "atlasLootMop", "attExpansionProfessionData"],
        )
        writer.writeheader()
        writer.writerows(rows)

    lines = [
        f"# {catalog['build']} 外部配方目录交叉核对",
        "",
        f"> 生成时间：{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}。此报告是候选证据对账，不代表任何单一来源完整或权威。",
        "",
        "## 固定来源与提取范围",
        "",
        f"- AtlasLootClassic MoP `{ATLAS_COMMIT}`：`{ATLAS_PATH}`，SHA-256 `{atlas_hash}`。仅提取 `data-mop.lua` 各专业表中的 `{{rank, spellID}}` 记录。",
        f"- 本机旧 MoP 目录 `{catalog.get('legacyCatalogName')}`，SHA-256 `{catalog.get('legacyCatalogSha256')}`：使用候选 JSON 已保存的逐项 membership，不重复复制该文件。",
        f"- ATT `{ATT_COMMIT}`：从下列按资料片拆分的专业目录提取 `r(spellID)` 调用，并合并为旧至 MoP 的配方 ID 交叉集；逐文件 SHA-256 见下表。",
        "- ATT 另合并五个扩展的 Crafted Items 目录中的 `r(spellID)`，用于弥补只看专业导航树的缺项；职业定制记录不在本次范围内。没有被这些文件提取到不表示 ATT 整体没有该数据。",
        f"- CSV 列 `recipeSpellID` 是配方/制作法术 ID，`createdItemIDs_ItemID` 是制作产物物品 ID，`createdItemNames_zhCN` 是产物中文名。中文物品名称取自固定于本次报告的 Wowhead zhCN item 页面快照 `{localized_path.name}`（SHA-256 `{hashlib.sha256(localized_blob).hexdigest()}`）；名称是配方产物标签，不据此判断当前可取得。",
        "- 未被 AtlasLoot/ATT 收录不能单独证明 DB2 候选无效；需与目标 build 的技能线、效果、材料、分支和动作类别一起审查。无法定性的项目可按约定标 `provisional/unknown`，不静默丢弃。",
        "",
        "## 逐专业对照",
        "",
        "| 专业 | 70032 候选 | 客户端实见 | 旧目录命中 | AtlasLoot 命中 | ATT 命中 | AtlasLoot/ATT 均命中 | 四类证据均未命中 | AtlasLoot 独有 | ATT 独有 |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
        *summaries,
        "",
        "## 未命中本次四类交叉对照源的候选项目",
        "",
        "> 这些候选未命中本次角色正向样本、旧 MoP 目录、AtlasLoot MoP 或 ATT 四类交叉对照文件。后来确认了其中 54 个配方族的 CTM 专业供应商/材料兑换来源线索（见下节），但来源图样与当前候选 Spell ID 的一对一教授关系仍须核验。它们保留在候选集中，缺少四类对照命中不能单独判无效。",
        "",
        "| 专业 | 数量 | 简体中文产物名 / Item ID（产物） / 英文配方法术名 / Spell ID（配方） |",
        "|---|---:|---|",
        *[
            f"| {name} | {len(ids)} | " + ("；".join(
                format_review_recipe(recipe_details[name][spell], spell, localized_items)
                for spell in ids
            ) or "无") + " |"
            for name, ids in db2_only.items()
        ],
        "",
        "## 新发现的来源线索（不等同于 Spell ID 已逐条映射）",
        "",
        "> 用户提供的三张游戏截图显示铁炉堡裁缝供应商博兰纳·雪衣的购买页列有 CTM 裁缝图样；这与下列固定资料来源一致。来源说明的是图样/配方族如何取得。CTM 4.2/4.3 的 Bloodied→Bloodthirsty→Vicious 替换可能改变图样教授的法术，因此每个 vendor item 到当前客户端 Spell ID 的映射仍应按 recipe item 的“使用：教你制作……”数据核实。",
        "",
        "| 候选组 | 来源与兑换物 | 对当前审查的含义 |",
        "|---|---|---|",
        "| 锻造 16 项（Bloodied/Ornate Pyrium） | CTM 锻造供应商出售 Plans；按图样类别消耗淬硬源质锭或燃钢锭。来源：[Cataclysm Blacksmithing Guide](https://overgear.com/guides/cataclysm-classic/blacksmithing-profession-guide/) | 确认属于 CTM 供应商图样族；历史替换关系及逐 ID 教授法术映射待核。 |",
        "| 制皮 32 项（Bloodied 系列） | CTM 制皮供应商出售 Pattern，以重 Savage 皮革兑换；城市供应商/暮光高地供应商。来源：[Cataclysm Leatherworking Guide](https://overgear.com/guides/cataclysm-classic/leatherworking-profession-guide/)；单项示例与供应商、4.2 替换记录：[Bloodthirsty Wyrmhide Bracers](https://warcraft.wiki.gg/wiki/Pattern%3A_Bloodthirsty_Wyrmhide_Bracers) | 确认属于 CTM 供应商图样族；部分图样在 4.2 被替换，逐 ID 当前映射待核。 |",
        "| 裁缝 6 项（Fireweave/Emberfire） | 用户截图显示铁炉堡 NPC 博兰纳·雪衣供应裁缝图样；CTM 裁缝供应商图样可用烬丝布卷兑换：[Cataclysm Tailoring Recipes](https://www.wowhead.com/cata/guide/professions/tailoring/recipes)；NPC 名单与价格：[Poranna Snowbraid](https://www.wowhead.com/cata/npc=5154/poranna-snowbraid) | 确认来源类别和对应图样族；替换版本与目标 build 法术映射待核。 |",
        "| 附魔 1 项（Enchant Weapon - Tyranny） | 这是 MoP PvP 供应商配方，公开记录为 4000 Honor；不是 CTM 专业材料兑换来源：[Formula: Enchant Weapon - Tyranny](https://www.wowhead.com/mop-classic/item=254315/formula-enchant-weapon-tyranny) | 单独标记 MoP 来源，不与 54 项 CTM 配方混为一组。 |",
        "",
        "## ATT 文件哈希",
        "",
        "| 路径 | SHA-256 |",
        "|---|---|",
        *[f"| `{path}` | `{digest}` |" for path, digest in sorted(att_hashes.items())],
        "",
        f"逐 ID 明细：[CSV](5.5.4.70032-external-source-diff.csv)。中文名称映射：[zhCN 快照](5.5.4.70032-zhCN-item-names.json)，其中 `itemID` 明确为产物物品 ID，并列出关联的配方 `recipeSpellIDs`。固定客户端候选：[JSON](5.5.4.70032.json)。",
    ]
    args.report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"comparison report: {args.report}")
    print(f"ID difference rows: {len(rows)}")


if __name__ == "__main__":
    main()
