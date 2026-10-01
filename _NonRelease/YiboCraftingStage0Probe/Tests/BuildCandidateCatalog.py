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
    EXPECTED_SHA256,
    LEGACY_PROFESSIONS,
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


def build_catalog(skill_lines, abilities, reagents, effects, samples, legacy=None, spell_names=None):
    parents = {int(row["ID"]): int(row["ParentSkillLineID"]) for row in skill_lines}
    names = {int(row["ID"]): row["DisplayName_lang"] for row in skill_lines}
    reagent_ids = {int(row["SpellID"]) for row in reagents}
    spell_names = {int(row["ID"]): row["Name_lang"] for row in (spell_names or [])}
    effect_types = defaultdict(set)
    for row in effects:
        effect_types[int(row["SpellID"])].add(int(row["Effect"]))

    def root(skill_line):
        visited = set()
        while parents.get(skill_line, 0):
            if skill_line in visited:
                raise ValueError(f"cycle in SkillLine parents: {skill_line}")
            visited.add(skill_line)
            skill_line = parents[skill_line]
        return skill_line

    evidence = defaultdict(lambda: defaultdict(lambda: {"skillLines": set(), "categoryIDs": set()}))
    for row in abilities:
        if int(row["TrivialSkillLineRankHigh"] or 0) <= 0:
            continue
        skill_line = int(row["SkillLine"])
        parent = root(skill_line)
        spell = int(row["Spell"])
        entry = evidence[parent][spell]
        entry["skillLines"].add(skill_line)
        entry["categoryIDs"].add(int(row["TradeSkillCategoryID"] or 0))

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
        "build": BUILD,
        "interface": 50504,
        "sourceSha256": {name: EXPECTED_SHA256[name] for name in (
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
        branch_unlocks = []
        quarantined = []
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
                continue
            recipes.append({
                "spellID": spell,
                "name": spell_names.get(spell),
                "skillLines": sorted(entry["skillLines"]),
                "categoryIDs": sorted(entry["categoryIDs"]),
                "hasReagentRecord": spell in reagent_ids,
                "effectTypes": sorted(effect_types[spell]),
                "observed": spell in observed[skill_line],
            })
        old = legacy.get(skill_line, set()) if legacy else set()
        legacy_only = old - candidates.keys() if legacy else set()
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
            "candidateCount": len(recipes),
            "observedCount": len(observed[skill_line]),
            "reagentBackedCount": sum(recipe["hasReagentRecord"] for recipe in recipes),
            "noReagentIDs": [recipe["spellID"] for recipe in recipes if not recipe["hasReagentRecord"]],
            "reagentBackedLegacyMissingIDs": sorted(
                spell for spell in candidates.keys() - old
                if spell in reagent_ids and spell not in ALL_EXCLUDED_IDS
            ) if legacy else [],
            "resolvedLegacyItemUseIDs": sorted(legacy_only & RESOLVED_LEGACY_ITEM_USE_IDS),
            "legacyOnlyIDs": sorted(legacy_only - RESOLVED_LEGACY_ITEM_USE_IDS),
            "recipes": recipes,
        })
    return result


def markdown_report(catalog):
    lines = [
        f"# {catalog['build']} 配方候选目录核对",
        "",
        "> 阶段 0 诊断产物；不是可发布目录。候选未见于角色样本不等于未学。",
        "",
        "| 专业 | DB2 宽候选 | 排除非配方 | 已移除旧配方 | 保留分支 | 暂隔离 | 当前配方候选 | 有材料表 | 客户端见过 | 样本数 | 旧目录待核查 |",
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
            f"{profession['sampleCount']} | {len(profession['legacyOnlyIDs'])} |"
        )
    lines += [
        "",
        "## 待人工判定的边界",
        "",
        "- 用户已确认 `818`（烹饪用火）与 `110955`（释放灵魂）不是配方；另按固定构建的名称和效果把 `104115`（释放火焰之灵）、`105518`（打开箱子）、`13262`（分解）归为通用操作技能。它们只保留在排除记录中，不进入 `recipes`。",
        "- 用户确认 `413897` 与 `414814` 的旧雕文配方在当前客户端已移除；其历史名称不用于填充当前目录。",
        "- 没有材料表的候选不自动排除；符文熔铸的客户端已见 ID 均无材料表。",
        "- `TradeSkillCategoryID = 0` 不自动排除；已有制皮和锻造的正向样本落在此类。",
        "- 半山烹饪六分支保留为 `branchUnlocks`，其子技能线的可制作菜谱仍在 `recipes` 中。",
        "- 同时缺少名称、材料表、效果记录且未在客户端见过的 ID 暂隔离在 `quarantinedIDs`，不作为可显示配方；它们尚未被判定为无效。",
        "- 旧目录 `19566` 是使用筛盐器处理盐的效果；制作筛盐器的工程配方是 `19567`，已在客户端样本中见到。",
        "- 其它旧目录独有 ID 仅为历史核查线索，不能直接合并入目标构建目录。",
        "- 首轮炼金及高等级裁缝没有留存去身份的全量 ID 样本，表中的客户端见过数量不代表其实际已学数量。",
        "- 当前客户端分类折叠可使旧版 API 漏行，`isExpanded` 返回位不可用；完整扫描仍未证明。",
        "",
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
                f"- {profession['name']}暂隔离无名称/材料/效果记录："
                + ", ".join(f"`{spell}`" for spell in profession["quarantinedIDs"])
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
                + ", ".join(f"`{spell}`" for spell in profession["reagentBackedLegacyMissingIDs"])
            )
    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("samples", nargs="+", type=pathlib.Path)
    parser.add_argument("--legacy-catalog", type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--report", required=True, type=pathlib.Path)
    args = parser.parse_args()
    if args.output.resolve() == args.report.resolve():
        raise ValueError("catalog and report paths must differ")

    catalog = build_catalog(
        fetch_table("SkillLine"), fetch_table("SkillLineAbility"),
        fetch_table("SpellReagents"), fetch_table("SpellEffect"),
        load_samples(args.samples),
        load_legacy_catalog(args.legacy_catalog) if args.legacy_catalog else None,
        fetch_table("SpellName"),
    )
    catalog["sampleSha256"] = {
        path.name: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(args.samples, key=lambda path: path.name)
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    args.report.write_text(markdown_report(catalog), encoding="utf-8")
    print(f"candidate catalog: {args.output}")
    print(f"comparison report: {args.report}")


if __name__ == "__main__":
    main()
