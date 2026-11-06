"""Build an evidence-labelled, non-release recipe candidate catalog for one client build.

The output is diagnostic data. Neither a DB2 row nor an absent client sample ID
proves that a recipe is obtainable or unlearned by a character.
"""

import argparse
import hashlib
import json
import pathlib
from collections import defaultdict

from AnalyzeBuildCatalog import (
    BUILD,
    LEGACY_PROFESSIONS,
    PINNED_BUILD_HASHES,
    PROFESSIONS,
    fetch_table,
    load_legacy_catalog,
    load_samples,
)

EXCLUDED_NON_RECIPE_IDS = {818, 110955}  # User-confirmed: Cooking Fire, Release Spirit.
UTILITY_NON_RECIPE_IDS = {104115, 105518, 13262}  # Release Fire Spirit, Open Box, Disenchant.
ALL_NON_RECIPE_IDS = EXCLUDED_NON_RECIPE_IDS | UTILITY_NON_RECIPE_IDS
USER_CONFIRMED_REMOVED_IDS = {413897, 414814}  # Former WotLK glyph recipes, absent in this client.
ALL_EXCLUDED_IDS = ALL_NON_RECIPE_IDS | USER_CONFIRMED_REMOVED_IDS
COOKING_BRANCH_UNLOCKS = {
    124694: 975, 125584: 976, 125586: 977,
    125587: 978, 125588: 979, 125589: 980,
}
RESOLVED_LEGACY_ITEM_USE_IDS = {19566}  # Salt Shaker use; engineering craft is 19567.


def build_catalog(skill_lines, abilities, reagents, effects, samples, legacy=None, spell_names=None, build=BUILD):
    parents = {int(row["ID"]): int(row["ParentSkillLineID"]) for row in skill_lines}
    names = {int(row["ID"]): row["DisplayName_lang"] for row in skill_lines}
    reagent_ids = {int(row["SpellID"]) for row in reagents}
    reagent_details = defaultdict(list)
    for row in reagents:
        for index in range(8):
            item_id = int(row.get(f"Reagent_{index}") or 0)
            quantity = int(row.get(f"ReagentCount_{index}") or 0)
            if item_id > 0:
                reagent_details[int(row["SpellID"])].append({"itemID": item_id, "quantity": quantity})
    spell_names = {int(row["ID"]): row["Name_lang"] for row in (spell_names or [])}
    effect_types = defaultdict(set)
    effect_details = defaultdict(list)
    for row in effects:
        spell = int(row["SpellID"])
        effect = int(row["Effect"])
        effect_types[spell].add(effect)
        effect_details[spell].append({
            "effect": effect,
            "effectItemType": int(row.get("EffectItemType") or 0),
            "effectMiscValue0": int(row.get("EffectMiscValue_0") or 0),
            "effectMiscValue1": int(row.get("EffectMiscValue_1") or 0),
        })

    def root(skill_line):
        visited = set()
        while parents.get(skill_line, 0):
            if skill_line in visited:
                raise ValueError(f"cycle in SkillLine parents: {skill_line}")
            visited.add(skill_line)
            skill_line = parents[skill_line]
        return skill_line

    evidence = defaultdict(lambda: defaultdict(lambda: {
        "skillLines": set(), "categoryIDs": set(), "rankRanges": set(), "supersedesSpellIDs": set(),
    }))
    for row in abilities:
        if int(row["TrivialSkillLineRankHigh"] or 0) <= 0:
            continue
        skill_line = int(row["SkillLine"])
        parent = root(skill_line)
        spell = int(row["Spell"])
        entry = evidence[parent][spell]
        entry["skillLines"].add(skill_line)
        entry["categoryIDs"].add(int(row["TradeSkillCategoryID"] or 0))
        entry["rankRanges"].add((
            skill_line,
            int(row["MinSkillLineRank"] or 0),
            int(row["TrivialSkillLineRankLow"] or 0),
            int(row["TrivialSkillLineRankHigh"] or 0),
        ))
        supersedes = int(row["SupercedesSpell"] or 0)
        if supersedes > 0:
            entry["supersedesSpellIDs"].add(supersedes)

    superseded_by = defaultdict(lambda: defaultdict(set))
    for profession, spells in evidence.items():
        for spell, entry in spells.items():
            for old_spell in entry["supersedesSpellIDs"]:
                superseded_by[profession][old_spell].add(spell)

    observed = defaultdict(set)
    sample_counts = defaultdict(int)
    for _, _, profession, ids in samples:
        if profession not in PROFESSIONS:
            raise ValueError(f"unknown sample profession: {profession}")
        skill_line = PROFESSIONS[profession]
        observed[skill_line].update(ids)
        sample_counts[skill_line] += 1

    result = {
        "status": "candidate-only",
        "build": build,
        "interface": 50504,
        "legacyComparisonProvided": legacy is not None,
        "sourceSha256": {name: PINNED_BUILD_HASHES[build][name] for name in (
            "SkillLine", "SkillLineAbility", "SpellReagents", "SpellEffect", "SpellName"
        )},
        "meaning": {
            "candidate": "SkillLineAbility rank-high > 0, grouped by root SkillLine, minus explicit non-recipe exclusions",
            "branchUnlock": "Halfhill cooking branch kept as a profession branch, not a craftable dish recipe",
            "observed": "Positive recipe ID seen in anonymized client samples",
            "hasReagentRecord": "SpellReagents contains this spell ID; diagnostic only",
            "missing": "Not observed is not evidence of unlearned or unobtainable",
        },
        "exclusionDecision": {
            "userConfirmedIDs": sorted(EXCLUDED_NON_RECIPE_IDS),
            "utilityIDs": sorted(UTILITY_NON_RECIPE_IDS),
            "userConfirmedRemovedIDs": sorted(USER_CONFIRMED_REMOVED_IDS),
        },
        "professions": [],
    }
    for profession, skill_line in sorted(PROFESSIONS.items(), key=lambda item: item[1]):
        candidates = evidence[skill_line]
        outside = sorted(observed[skill_line] - candidates.keys())
        if outside:
            raise ValueError(f"{profession}: observed IDs outside DB2 candidates: {outside[:12]}")
        excluded_observed = sorted(observed[skill_line] & ALL_EXCLUDED_IDS)
        if excluded_observed:
            raise ValueError(f"{profession}: excluded IDs in client recipe sample: {excluded_observed}")
        excluded = sorted(candidates.keys() & ALL_NON_RECIPE_IDS)
        removed = sorted(candidates.keys() & USER_CONFIRMED_REMOVED_IDS)
        old = legacy.get(skill_line, set()) if legacy is not None else set()
        branch_unlocks = []
        quarantined = []
        quarantined_details = []
        recipes = []
        for spell in sorted(candidates):
            if spell in ALL_EXCLUDED_IDS:
                continue
            entry = candidates[spell]
            if skill_line == 185 and spell in COOKING_BRANCH_UNLOCKS:
                child = COOKING_BRANCH_UNLOCKS[spell]
                if child not in entry["skillLines"] or parents.get(child) != 185:
                    raise ValueError(f"cooking branch mapping changed: {spell} -> {child}")
                branch_unlocks.append({
                    "unlockSpellID": spell,
                    "skillLineID": child,
                    "name": spell_names.get(spell),
                })
                continue
            if not spell_names.get(spell) and spell not in reagent_ids and not effect_types[spell] and spell not in observed[skill_line]:
                quarantined.append(spell)
                quarantined_details.append({
                    "spellID": spell,
                    "skillLines": sorted(entry["skillLines"]),
                    "categoryIDs": sorted(entry["categoryIDs"]),
                    "rankRanges": [
                        {
                            "skillLineID": skill,
                            "minSkillLineRank": minimum,
                            "trivialSkillLineRankLow": low,
                            "trivialSkillLineRankHigh": high,
                        }
                        for skill, minimum, low, high in sorted(entry["rankRanges"])
                    ],
                    "hasSpellName": False,
                    "hasReagentRecord": False,
                    "effectTypes": [],
                    "reason": "SkillLineAbility candidate without SpellName, SpellReagents, SpellEffect, or client-observed evidence",
                })
                continue
            recipes.append({
                "spellID": spell,
                "name": spell_names.get(spell),
                "skillLines": sorted(entry["skillLines"]),
                "categoryIDs": sorted(entry["categoryIDs"]),
                "rankRanges": [
                    {
                        "skillLineID": skill,
                        "minSkillLineRank": minimum,
                        "trivialSkillLineRankLow": low,
                        "trivialSkillLineRankHigh": high,
                    }
                    for skill, minimum, low, high in sorted(entry["rankRanges"])
                ],
                "supersedesSpellIDs": sorted(entry["supersedesSpellIDs"]),
                "supersededBySpellIDs": sorted(superseded_by[skill_line][spell]),
                "hasReagentRecord": spell in reagent_ids,
                "reagents": reagent_details[spell],
                "effectTypes": sorted(effect_types[spell]),
                "effects": effect_details[spell],
                "createdItemIDs": sorted({
                    effect["effectItemType"] for effect in effect_details[spell]
                    if effect["effect"] in (24, 157) and effect["effectItemType"] > 0
                }),
                "inLegacyCatalog": spell in old if legacy is not None else None,
                "observed": spell in observed[skill_line],
            })
        legacy_only = old - candidates.keys() if legacy is not None else None
        result["professions"].append({
            "name": profession,
            "skillLineID": skill_line,
            "skillLineName": names[skill_line],
            "sampleCount": sample_counts[skill_line],
            "rawCandidateCount": len(candidates),
            "excludedNonRecipeIDs": excluded,
            "removedRecipeIDs": removed,
            "branchUnlocks": branch_unlocks,
            "quarantinedIDs": quarantined,
            "quarantinedDetails": quarantined_details,
            "candidateCount": len(recipes),
            "observedCount": len(observed[skill_line]),
            "reagentBackedCount": sum(recipe["hasReagentRecord"] for recipe in recipes),
            "noReagentIDs": [recipe["spellID"] for recipe in recipes if not recipe["hasReagentRecord"]],
            "reagentBackedLegacyMissingIDs": sorted(
                spell for spell in candidates.keys() - old
                if spell in reagent_ids and spell not in ALL_EXCLUDED_IDS
            ) if legacy is not None else None,
            "resolvedLegacyItemUseIDs": sorted(legacy_only & RESOLVED_LEGACY_ITEM_USE_IDS) if legacy_only is not None else None,
            "legacyOnlyIDs": sorted(legacy_only - RESOLVED_LEGACY_ITEM_USE_IDS) if legacy_only is not None else None,
            "recipes": recipes,
        })
    return result


def markdown_report(catalog):
    lines = [
        f"# {catalog['build']} 配方候选目录核对",
        "",
        "> 阶段 0 诊断产物；不是可发布目录。候选未见于角色样本不等于未学。",
        "",
        "| 专业 | DB2 宽候选 | 排除非配方 | 已移除旧配方 | 保留分支 | 暂隔离 | 当前配方候选 | 有材料表 | 本 build 样本见过 | 样本数 | 旧目录独有待核查 |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for profession in catalog["professions"]:
        lines.append(
            f"| {profession['name']} | {profession['rawCandidateCount']} | "
            f"{len(profession['excludedNonRecipeIDs'])} | {len(profession['removedRecipeIDs'])} | "
            f"{len(profession['branchUnlocks'])} | "
            f"{len(profession['quarantinedIDs'])} | "
            f"{profession['candidateCount']} | "
            f"{profession['reagentBackedCount']} | {profession['observedCount']} | "
            f"{profession['sampleCount']} | "
            f"{len(profession['legacyOnlyIDs']) if catalog['legacyComparisonProvided'] else '未比较'} |"
        )
    lines += [
        "",
        "## 待人工判定的边界",
        "",
        "- 用户已确认 `818`（烹饪用火）与 `110955`（释放灵魂）不是配方；另按固定构建的名称和效果把 `104115`（释放火焰之灵）、`105518`（打开箱子）、`13262`（分解）归为通用操作技能。它们只保留在排除记录中，不进入 `recipes`。",
        "- 用户确认 `413897` 与 `414814` 的旧雕文配方在当前客户端已移除；其历史名称不用于填充当前目录。",
        "- 符文熔铸 10 项均无 `SpellReagents` 行，但均有技能线 `960`、符文法术名称和效果类型 `53`；build `5.5.4.69934` 落盘样本曾见到全部 10 项。build `70032` 本次候选输入未包含符文熔铸样本，因此本 build 样本数为 0 仅表示未纳入该次样本输入，不表示客户端列表没有这些配方。",
        "- `TradeSkillCategoryID = 0` 不自动排除；已有制皮和锻造的正向样本落在此类。",
        "- 半山烹饪六分支保留为 `branchUnlocks`，其子技能线的可制作菜谱仍在 `recipes` 中。",
        "- 同时缺少名称、材料表、效果记录且未在客户端见过的 ID 暂隔离在 `quarantinedIDs`，不作为可显示配方；它们尚未被判定为无效。",
        "- 旧目录 `19566` 是使用筛盐器处理盐的效果；制作筛盐器的工程配方是 `19567`，已在客户端样本中见到。",
        "- 其它旧目录独有 ID 仅为历史核查线索，不能直接合并入目标构建目录。",
        "- 炼金与裁缝已有去身份的正向 ID 样本；这些样本仅表示客户端列表见过的配方，不能代表目录完整，也不能替代完整扫描基线。",
        "- Current client category folding can truncate the legacy API list; isExpanded is unavailable, so scan completeness is unproven.",
        "## 证据能证明什么",
        "",
        "- `SkillLineAbility` 专业归属/等级、`SpellName`、材料与效果/产物关系可证明目标 build 存在专业技能候选及其数据形态；不能单独证明玩家当前仍可取得、客户端 UI 会列出，或完整目录已覆盖。材料、产物效果和第三方旧目录命中是相互补强的候选证据，不等于取得来源。",
        "- 发布目录不要求在游戏内实际取得每个未学配方。目标 build 客户端数据、角色已取得 ID、AtlasLootClassic MoP 与 ATT 的固定版本数据可共同用于目录交叉核对；已取得角色样本是客户端正向证据，AtlasLoot/ATT 条目证明其数据集收录及记录的来源，但单一第三方来源不证明当前来源仍有效。取得状态无当前版本来源佐证时标为未知，不阻止目录收录。",
        "- 已移除/不可取得需有目标 build 的明确移除证据（例如客户端明确标记不可用，或已验证来源/法术在该 build 中失效）；单纯查不到来源、名称或样本不能证明已移除。历史配方可保留在历史目录，并与当前可取得状态分开。",
        "- 首版目录覆盖以固定 build 的 DB2 候选为骨架，再和角色已取得 ID、AtlasLootClassic MoP、ATT 按 ID 交叉核对；固定上游版本/提交、文件哈希、ID 映射和全部差异。已归类但证据冲突的条目可随目录发布并标 provisional/unknown；未分类候选不可静默丢弃，所在专业维持 partial。角色样本和第三方数据均非单独的全集证明。",
        "- `SupercedesSpell` 只证明数据中的关联边；只有逐项证实旧法术已从目标版本可学习路径移除、没有独立保留用途且新法术承接同一配方后，才可将旧项标为被替代/不可取得；若它仍有来源或客户端样本，则继续保留。",
        "",
        "",
    ]
    if not catalog["legacyComparisonProvided"]:
        lines.insert(len(lines) - 1, "- 本次未提供旧候选目录输入；旧目录差异栏为“未比较”，不代表差异为 0。")
    else:
        digest = catalog.get("legacyCatalogSha256")
        source = catalog.get("legacyCatalogName", "unknown")
        lines.insert(len(lines) - 1, f"- 本次旧目录只读比较输入 `{source}`，SHA-256 `{digest}`；旧目录差异仅用于定位需复核的版本边界。")
    delta_rows = []
    for profession in catalog["professions"]:
        by_id = {recipe["spellID"]: recipe for recipe in profession["recipes"]}
        for spell in profession["reagentBackedLegacyMissingIDs"] or []:
            recipe = by_id[spell]
            rank = ", ".join(
                f"{row['skillLineID']}:{row['trivialSkillLineRankLow']}-{row['trivialSkillLineRankHigh']}"
                for row in recipe["rankRanges"]
            )
            effects = "; ".join(
                f"Effect={row['effect']}, ItemType={row['effectItemType']}, Misc={row['effectMiscValue0']}/{row['effectMiscValue1']}"
                for row in recipe["effects"]
            ) or "无效果行"
            reagents = ", ".join(
                f"{row['itemID']}×{row['quantity']}" for row in recipe["reagents"]
            ) or "无材料项"
            outputs = ", ".join(map(str, recipe["createdItemIDs"])) or "无 Effect 24/157 物品产物"
            delta_rows.append(
                f"| {profession['name']} | `{spell}` {recipe['name'] or '无 SpellName'} | {rank} | {effects}；产物 {outputs} | {reagents} |"
            )
    if delta_rows:
        lines += [
            "",
            "## 目标构建 DB2 有材料、旧目录缺少的逐条证据",
            "",
            "> 以下证据支持这些 ID 是制作型配方候选，不单独证明当前客户端可取得或可见。`Effect=24/157` 且 `EffectItemType > 0` 时列出物品产物 ID；附魔等非造物品效果保留原始效果字段。",
            "",
            "| 专业 | 法术 ID / 名称 | 技能线 / 产物等级 | 效果记录 / 物品产物 | 材料记录（物品 ID × 数量） |",
            "|---|---|---|---|---|",
            *delta_rows,
        ]
    non_item_actions = []
    for profession in catalog["professions"]:
        for recipe in profession["recipes"]:
            if recipe["createdItemIDs"] or 53 in recipe["effectTypes"]:
                continue
            rank = ", ".join(
                f"{row['skillLineID']}:{row['trivialSkillLineRankLow']}-{row['trivialSkillLineRankHigh']}"
                for row in recipe["rankRanges"]
            )
            effects = "; ".join(
                f"Effect={row['effect']}, ItemType={row['effectItemType']}, Misc={row['effectMiscValue0']}/{row['effectMiscValue1']}"
                for row in recipe["effects"]
            ) or "无效果行"
            reagents = ", ".join(
                f"{row['itemID']}×{row['quantity']}" for row in recipe["reagents"]
            ) or "无材料项"
            non_item_actions.append(
                f"| {profession['name']} | `{recipe['spellID']}` {recipe['name'] or '无 SpellName'} | {rank} | {effects} | {reagents} |"
            )
    if non_item_actions:
        lines += [
            "",
            "## 无固定物品产物且非附魔效果的边界候选",
            "",
            "> 这些候选虽有关联专业和材料，但没有 `Effect=24/157` 的物品产物，也没有 `Effect=53` 附魔效果。先作为专业动作/研究候选单独复核，不自动并入或排除正式配方目录。",
            "",
            "| 专业 | 法术 ID / 名称 | 技能线 / 等级 | 效果记录 | 材料记录（物品 ID × 数量） |",
            "|---|---|---|---|---|",
            *non_item_actions,
        ]
    supersession_rows = []
    for profession in catalog["professions"]:
        by_id = {recipe["spellID"]: recipe for recipe in profession["recipes"]}
        for recipe in profession["recipes"]:
            for old_spell in recipe["supersedesSpellIDs"]:
                old = by_id.get(old_spell)
                old_label = f"`{old_spell}` {old['name']}" if old else f"`{old_spell}` (not in recipe candidates)"
                old_sample = str(old["observed"]) if old else "unknown"
                old_legacy = str(old["inLegacyCatalog"]) if old else "unknown"
                supersession_rows.append(
                    f"| {profession['name']} | {old_label} | `{recipe['spellID']}` {recipe['name'] or '无 SpellName'} | "
                    f"{old_sample} → {recipe['observed']} | {old_legacy} → {recipe['inLegacyCatalog']} |"
                )
    if supersession_rows:
        lines += [
            "",
            "## DB2 配方替代关系（不自动删除旧项）",
            "",
            "> `SkillLineAbility.SupercedesSpell` 用于显示新旧关联。它本身不证明旧项已无法学习或必须从完整目录删除；需结合当前 build 样本和历史可取得性逐项决策。样本列只统计本报告输入的 build。",
            "",
            "| 专业 | 被替代 ID / 名称 | 新 ID / 名称 | 本 build 样本见过：旧 → 新 | 旧目录收录：旧 → 新 |",
            "|---|---|---|---|---|",
            *supersession_rows,
        ]
    lines += ["## 逐专业例外", ""]
    for profession in catalog["professions"]:
        by_id = {recipe["spellID"]: recipe for recipe in profession["recipes"]}
        if profession["excludedNonRecipeIDs"]:
            lines.append(
                f"- {profession['name']}已排除非配方："
                + ", ".join(f"`{spell}`" for spell in profession["excludedNonRecipeIDs"])
            )
        if profession["removedRecipeIDs"]:
            lines.append(
                f"- {profession['name']}用户确认当前客户端已移除的旧配方："
                + ", ".join(f"`{spell}`" for spell in profession["removedRecipeIDs"])
            )
        if profession["branchUnlocks"]:
            lines.append(
                f"- {profession['name']}保留分支："
                + "、".join(
                    f"`{branch['unlockSpellID']}` → 技能线 `{branch['skillLineID']}` ({branch['name']})"
                    for branch in profession["branchUnlocks"]
                )
            )
        if profession["quarantinedIDs"]:
            lines.append(
                f"- {profession['name']}暂隔离候选："
                + "; ".join(
                    f"`{detail['spellID']}`（技能线 {','.join(map(str, detail['skillLines']))}，分类 {','.join(map(str, detail['categoryIDs']))}，"
                    + "技能范围 " + "/".join(
                        f"{rank['trivialSkillLineRankLow']}-{rank['trivialSkillLineRankHigh']}"
                        for rank in detail["rankRanges"]
                    )
                    + "；无 SpellName、材料或效果记录，且未在角色样本见到）"
                    for detail in profession["quarantinedDetails"]
                )
            )
        no_reagents = [
            f"`{spell}` ({by_id[spell]['name'] or '无 SpellName'})"
            for spell in profession["noReagentIDs"]
        ]
        lines.append(f"- {profession['name']}：无材料表候选 " + ("、".join(no_reagents) or "无") + "。")
        if profession["legacyOnlyIDs"]:
            lines.append(
                f"- {profession['name']}旧目录独有："
                + ", ".join(f"`{spell}`" for spell in profession["legacyOnlyIDs"])
            )
        if profession["resolvedLegacyItemUseIDs"]:
            lines.append(
                f"- {profession['name']}旧目录的使用物品效果："
                + ", ".join(f"`{spell}`" for spell in profession["resolvedLegacyItemUseIDs"])
                + "；不并入专业配方。"
            )
        if profession["reagentBackedLegacyMissingIDs"]:
            lines.append(
                f"- {profession['name']}目标构建有材料表、旧目录缺少："
                + ", ".join(
                    f"`{spell}` ({by_id[spell]['name'] or '无 SpellName'})"
                    for spell in profession["reagentBackedLegacyMissingIDs"]
                )
            )
    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("samples", nargs="+", type=pathlib.Path)
    parser.add_argument("--legacy-catalog", type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--report", required=True, type=pathlib.Path)
    parser.add_argument("--build", choices=sorted(PINNED_BUILD_HASHES), default=BUILD)
    args = parser.parse_args()
    if args.output.resolve() == args.report.resolve():
        raise ValueError("catalog and report paths must differ")

    catalog = build_catalog(
        fetch_table("SkillLine", args.build), fetch_table("SkillLineAbility", args.build),
        fetch_table("SpellReagents", args.build), fetch_table("SpellEffect", args.build),
        load_samples(args.samples, args.build),
        load_legacy_catalog(args.legacy_catalog) if args.legacy_catalog else None,
        fetch_table("SpellName", args.build), args.build,
    )
    catalog["sampleSha256"] = {
        path.name: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(args.samples, key=lambda path: path.name)
    }
    catalog["legacyCatalogName"] = args.legacy_catalog.name if args.legacy_catalog else None
    catalog["legacyCatalogSha256"] = (
        hashlib.sha256(args.legacy_catalog.read_bytes()).hexdigest()
        if args.legacy_catalog else None
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    args.report.write_text(markdown_report(catalog), encoding="utf-8")
    print(f"candidate catalog: {args.output}")
    print(f"comparison report: {args.report}")


if __name__ == "__main__":
    main()
