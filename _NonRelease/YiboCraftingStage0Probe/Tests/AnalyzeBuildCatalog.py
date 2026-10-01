"""Compare anonymized probe samples with one pinned client-build DB2 catalog.

Read-only diagnostic. It downloads CSVs in memory and does not create or ship a
recipe catalog. A SkillLineAbility entry is a candidate, not proof that a recipe
is visible, obtainable, or safe to mark unlearned in the client.
"""

import argparse
import csv
import hashlib
import io
import pathlib
import re
import urllib.request
from collections import defaultdict


BUILD = "5.5.4.69934"
EXPECTED_SHA256 = {
    "SkillLine": "6a0213cfc8a3ad069a7daeaa3e009c8ea9d199f6d76400dd7c585ff1c6d32779",
    "SkillLineAbility": "b37c77c2efe1190e9a1cede4b2a4fce9e268e2f3203bfd4be3917612c7ad2d0a",
    "SpellReagents": "9f075bab589e966a7f2000c6245438e0c5bebb4f2482feab5960875c80dce634",
    "SpellEffect": "989479ac28d50f0b62da725de12e217f2e6f9709e66b30452b79370e8f0fd656",
    "SpellName": "b70700fa0e6d0610416ac930e3bc5784ddc26748c96abcf32cb13dfdc76e6c1e",
    "ResearchProject": "bead485ce15774f044a9a7dedfd5371799e17f2d70cd650e908d9a0ec008a15d",
    "ResearchBranch": "3f7cd589fe66b02e6c0c4cfc95f818dbbdbd26d94c37f84ef5b0a3ceb5b4c4fe",
}
PROFESSIONS = {
    "急救": 129,
    "锻造": 164,
    "制皮": 165,
    "炼金术": 171,
    "烹饪": 185,
    "采矿": 186,
    "裁缝": 197,
    "工程学": 202,
    "附魔": 333,
    "珠宝加工": 755,
    "铭文": 773,
    "符文熔铸": 960,
}
LEGACY_PROFESSIONS = {
    1: 129, 2: 164, 3: 165, 4: 171, 6: 185, 7: 186,
    8: 197, 9: 202, 10: 333, 15: 755, 16: 773,
}
SAMPLE_PATTERN = re.compile(
    r"\{\s*session\s*=\s*(\d+).*?build\s*=\s*\"(\d+)\""
    r".*?profession\s*=\s*\"([^\"]+)\""
    r".*?recipeIDs\s*=\s*\{([^}]*)\}",
    re.DOTALL,
)


def fetch_table(name):
    url = f"https://wago.tools/db2/{name}/csv?build={BUILD}"
    request = urllib.request.Request(
        url, headers={"User-Agent": "Mozilla/5.0", "Accept": "text/csv"}
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        raw = response.read()
        content_type = response.headers.get("Content-Type", "")
    if "text/csv" not in content_type or not raw:
        raise ValueError(f"unexpected response for {name}: {content_type}")
    rows = list(csv.DictReader(io.StringIO(raw.decode("utf-8-sig"))))
    if not rows:
        raise ValueError(f"empty CSV for {name}")
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SHA256[name]:
        raise ValueError(f"{name} changed for pinned build {BUILD}: sha256={digest}")
    print(f"source={name} rows={len(rows)} sha256={digest}")
    return rows


def load_samples(paths):
    for path in paths:
        source = path.read_text(encoding="utf-8")
        matches = list(SAMPLE_PATTERN.finditer(source))
        if not matches:
            raise ValueError(f"no anonymized samples in {path}")
        for match in matches:
            if match.group(2) != BUILD.rsplit(".", 1)[1]:
                raise ValueError(f"sample build differs from pinned build: {path}")
            yield path.name, match.group(1), match.group(3), {
                int(value) for value in re.findall(r"\d+", match.group(4))
            }


def load_legacy_catalog(path):
    source = path.read_text(encoding="utf-8")
    if "local T_Recipe_Data = {" not in source:
        raise ValueError(f"no recipe catalog in {path}")
    section = source.split("local T_Recipe_Data = {", 1)[1].split("\n};", 1)[0]
    records = re.findall(
        r"^\s*\[(\d+)\]\s*=\s*\{\s*\d+\s*,\s*\d+\s*,\s*(\d+)",
        section, re.MULTILINE,
    )
    if not records:
        raise ValueError(f"no recipe records in {path}")
    catalog = defaultdict(set)
    for spell, profession in records:
        if int(profession) in LEGACY_PROFESSIONS:
            catalog[LEGACY_PROFESSIONS[int(profession)]].add(int(spell))
    return catalog


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("samples", nargs="+", type=pathlib.Path)
    parser.add_argument("--legacy-catalog", type=pathlib.Path)
    parser.add_argument("--archaeology-sample", type=pathlib.Path)
    args = parser.parse_args()

    skill_lines = fetch_table("SkillLine")
    abilities = fetch_table("SkillLineAbility")
    reagents = fetch_table("SpellReagents")
    effects = fetch_table("SpellEffect")
    parents = {int(row["ID"]): int(row["ParentSkillLineID"]) for row in skill_lines}
    names = {int(row["ID"]): row["DisplayName_lang"] for row in skill_lines}
    reagent_spell_ids = {int(row["SpellID"]) for row in reagents}
    effect_types = defaultdict(set)
    for row in effects:
        effect_types[int(row["SpellID"])].add(int(row["Effect"]))

    def root(skill_line):
        visited = set()
        while parents.get(skill_line, 0) and skill_line not in visited:
            visited.add(skill_line)
            skill_line = parents[skill_line]
        return skill_line

    candidates = defaultdict(set)
    uncategorized = defaultdict(set)
    for row in abilities:
        if int(row["TrivialSkillLineRankHigh"] or 0) > 0:
            skill_line, spell = root(int(row["SkillLine"])), int(row["Spell"])
            candidates[skill_line].add(spell)
            if int(row["TradeSkillCategoryID"] or 0) == 0:
                uncategorized[skill_line].add(spell)

    total_missing = 0
    for filename, session, profession, observed in load_samples(args.samples):
        skill_line = PROFESSIONS.get(profession)
        if skill_line is None:
            raise ValueError(f"unknown sample profession: {profession}")
        catalog = candidates[skill_line]
        missing = sorted(observed - catalog)
        observed_effects = {frozenset(effect_types[spell]) for spell in observed}
        unusual_effects = sorted(
            spell for spell in (catalog - observed) & reagent_spell_ids
            if frozenset(effect_types[spell]) not in observed_effects
        )
        total_missing += len(missing)
        print(
            f"sample={filename} session={session} profession={names[skill_line]} "
            f"skillLine={skill_line} observed={len(observed)} "
            f"candidate={len(catalog)} observedOutsideCandidate={len(missing)} "
            f"observedWithReagents={len(observed & reagent_spell_ids)} "
            f"candidateWithReagents={len(catalog & reagent_spell_ids)} "
            f"observedUncategorized={len(observed & uncategorized[skill_line])} "
            f"candidateUnusualEffects={len(unusual_effects)} "
            f"unusualIDs={','.join(map(str, unusual_effects[:8])) or '-'} "
            f"candidateNotObserved={len(catalog - observed)} "
            f"outsideIDs={','.join(map(str, missing[:12])) or '-'}"
        )
    if total_missing:
        raise SystemExit(f"observed IDs missing from candidate catalog: {total_missing}")

    if args.legacy_catalog:
        legacy = load_legacy_catalog(args.legacy_catalog)
        for skill_line in sorted(LEGACY_PROFESSIONS.values()):
            catalog = candidates[skill_line] & reagent_spell_ids
            newer = sorted(catalog - legacy[skill_line])
            older = sorted(legacy[skill_line] - catalog)
            print(
                f"legacyComparison profession={names[skill_line]} "
                f"legacy={len(legacy[skill_line])} db2WithReagents={len(catalog)} "
                f"db2Only={len(newer)} legacyOnly={len(older)} "
                f"db2OnlyIDs={','.join(map(str, newer[:8])) or '-'} "
                f"legacyOnlyIDs={','.join(map(str, older[:8])) or '-'}"
            )

    if args.archaeology_sample:
        source = args.archaeology_sample.read_text(encoding="utf-8")
        match = re.search(r'build\s*=\s*"(\d+)".*?projectSpellIDs\s*=\s*\{([^}]*)\}', source, re.DOTALL)
        if not match or match.group(1) != BUILD.rsplit(".", 1)[1]:
            raise ValueError("archaeology sample has no matching build")
        observed = {int(value) for value in re.findall(r"\d+", match.group(2))}
        projects = fetch_table("ResearchProject")
        branches = fetch_table("ResearchBranch")
        branch_names = {int(row["ID"]): row["Name_lang"] for row in branches}
        by_branch = defaultdict(set)
        for row in projects:
            by_branch[int(row["Field_1_15_8_63829_005"])].add(
                int(row["Field_1_15_8_63829_004"])
            )
        # This build's anonymous _004 column matches the artifact spell IDs
        # returned by GetArtifactInfoByRace. Keep this as a verified mapping,
        # not an assumption about future DB2 layouts.
        project_spells = {
            int(row["Field_1_15_8_63829_004"]) for row in projects
            if int(row["Field_1_15_8_63829_004"]) > 0
        }
        outside = sorted(observed - project_spells)
        archaeology_abilities = candidates[794]
        print(
            f"archaeology observed={len(observed)} researchProjectRows={len(projects)} "
            f"researchProjectSpellIDs={len(project_spells)} "
            f"researchBranches={len(branches)} unassignedProjectRows={sum(int(row['Field_1_15_8_63829_005']) == 0 for row in projects)} "
            f"observedOutsideResearchProject={len(outside)} "
            f"observedOutsideSkillLineAbility={len(observed - archaeology_abilities)} "
            f"outsideIDs={','.join(map(str, outside[:12])) or '-'}"
        )
        if outside:
            raise SystemExit(f"observed archaeology IDs missing from ResearchProject: {len(outside)}")
        for branch_id in sorted(set(branch_names) | set(by_branch)):
            spells = by_branch[branch_id]
            print(
                f"archaeologyBranch id={branch_id} name={branch_names.get(branch_id, 'Unassigned')} "
                f"catalogSpellIDs={len(spells)} observed={len(spells & observed)} "
                f"notObserved={len(spells - observed)}"
            )


if __name__ == "__main__":
    main()
