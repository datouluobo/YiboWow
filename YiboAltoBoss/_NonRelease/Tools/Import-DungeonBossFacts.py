"""Import numeric game identifiers, never executable addon code."""
import argparse
import pathlib
import re

parser = argparse.ArgumentParser()
parser.add_argument("addons", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
args = parser.parse_args()

def applies(line):
    for mode, games in re.findall(r"\[(AllowLoadGameType|ExcludeLoadGameType) ([^\]]+)\]", line):
        includes = "mists" in games.replace(",", " ").split()
        if (mode == "AllowLoadGameType" and not includes) or (mode == "ExcludeLoadGameType" and includes):
            return False
    return True

rows = {}
excluded = []
for era in ("Vanilla", "BC", "WotLK", "Cataclysm", "MoP"):
    folder = args.addons / ("DBM-Party-" + era)
    toc = (folder / (folder.name + ".toc")).read_text(encoding="utf-8-sig")
    categories = []
    for line in toc.splitlines():
        if line.startswith("## X-DBM-Mod-SubCategoriesID:") and applies(line):
            categories = [int(x) for x in re.findall(r"(?:^|,)\s*(\d+)", line.split(":", 1)[1])]
            break
    for line in toc.splitlines():
        relative = line.split(" [")[0].strip().replace("\\", "/")
        # MoP uses the original versions of these three dungeons.
        original = era == "Vanilla" and relative.startswith("Classic/") and any(
            "/" + name + "/" in relative for name in ("BlackfathomDeeps", "RazorfenDowns", "RazorfenKraul"))
        if not applies(line) and not original:
            continue
        if not relative.endswith(".lua") or relative.startswith("#"):
            continue
        path = folder / relative
        if not path.is_file():
            continue
        source = path.read_text(encoding="utf-8-sig")
        source = re.sub(r"--\[\[.*?\]\]", "", source, flags=re.S)
        source = re.sub(r"--[^\n]*", "", source)
        creature_calls = re.findall(r":SetCreatureID\(([^)]+)\)", source)
        if not creature_calls:
            continue
        creature_ids = re.findall(r"\d+", ",".join(creature_calls))
        encounter_call = re.search(r":SetEncounterID\(([^)]+)\)", source)
        encounter_ids = re.findall(r"\d+", encounter_call[1]) if encounter_call else []
        if len(creature_ids) != 1 or len(encounter_ids) > 1 or re.search(
                r":RegisterKill\(|function\s+\w+:UNIT_DIED|:SetMinCombatTime\(", source):
            excluded.append(era + "/" + relative)
            continue
        mod = re.search(r":NewMod\([^,]+,[^,]+,\s*(\d+)", source)
        zone = re.search(r":SetZone\((\d+)\)", source)
        map_id = int(zone[1]) if zone else (
            categories[int(mod[1]) - 1] if mod and 0 < int(mod[1]) <= len(categories) else None)
        if original:
            map_id = {"BlackfathomDeeps": 48, "RazorfenDowns": 129, "RazorfenKraul": 47}[relative.split("/")[1]]
        if not map_id or (era == "Vanilla" and relative.startswith("Retail/") and map_id in (48, 129, 47)):
            continue
        if relative.endswith(("/Snowdrift.lua", "/TaranZhu.lua", "/Vanessa.lua")):
            excluded.append(era + "/" + relative)
            continue
        npc_id = int(creature_ids[0])
        key = (map_id, npc_id)
        value = (int(encounter_ids[0]) if encounter_ids else 0, era + "/" + relative)
        if key in rows and rows[key][0] != value[0]:
            raise ValueError("Conflicting numeric facts: " + str(key))
        rows[key] = value

lines = ["if _G.YAB and _G.YAB.CoreReady == false then return end",
         "-- MoP Classic single-creature death facts; see Docs/FivePlayerBossRecording.md.",
         "-- Zero means no verified DungeonEncounterID; identity is still map/NPC ID.",
         "local YAB = _G.YAB", "local bosses = {"]
for map_id in sorted({key[0] for key in rows}):
    lines.append("    [%d] = {" % map_id)
    for (m, npc_id), (encounter_id, reference) in sorted(rows.items()):
        if m == map_id:
            lines.append("        [%d] = %d, -- %s" % (npc_id, encounter_id, reference))
    lines.append("    },")
lines.extend(["}", "YAB.DungeonBossCatalog = bosses", ""])
args.output.write_text("\n".join(lines), encoding="utf-8")
print("Imported %d numeric boss identities in %d maps; %d complex candidates excluded." % (
    len(rows), len({key[0] for key in rows}), len(excluded)))
print("Native completion required: " + ", ".join(sorted(excluded)))
