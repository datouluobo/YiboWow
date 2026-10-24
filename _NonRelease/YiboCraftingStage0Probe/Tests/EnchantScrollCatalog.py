"""Check all shipped enchant outputs against pinned target-build evidence."""
import importlib.util
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[3]
path = root / "_NonRelease/YiboCraftingStage0Probe/Tools/generate_runtime_catalog.py"
spec = importlib.util.spec_from_file_location("catalog_generator", path)
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)
source = json.loads(generator.CANDIDATES.read_text(encoding="utf-8"))
runtime = generator.OUTPUT.read_text(encoding="utf-8")
professions = {}
current = None
for line in runtime.split("    professions = {", 1)[-1].splitlines():
    profession = re.match(r"    \[(\d+)\] = \{", line)
    if profession:
        current = int(profession[1])
        professions[current] = {}
    recipe = re.match(r"        \[(\d+)\] = \{ outputItemIDs = \{([^}]*)\}", line)
    if recipe:
        professions[current][int(recipe[1])] = [int(x) for x in recipe[2].split(",") if x]

checked = scrolls = 0
for profession in source["professions"]:
    profession_id = int(profession["skillLineID"])
    for recipe in profession["recipes"]:
        spell_id = int(recipe["spellID"])
        actual = professions.get(profession_id, {}).get(spell_id)
        if actual is None:
            continue  # Generator separately validates candidate partitioning.
        expected = recipe.get("createdItemIDs", [])
        if profession_id == 333:
            effect_items = {int(effect["effectItemType"]) for effect in recipe["effects"]
                            if effect["effect"] == 53 and effect["effectItemType"] > 0}
            expected = sorted(set(expected) | effect_items)
            scrolls += bool(effect_items)
        if spell_id in generator.MANUAL:
            expected = generator.MANUAL[spell_id]["outputItemIDs"]
        assert actual == expected, (profession_id, spell_id, expected, actual)
        checked += 1
assert checked == 5275 and scrolls == 319, (checked, scrolls)
assert professions[333][7418] == [38679]
assert professions[333][104427] == [74724]
assert professions[333][103461] == []
print(f"EnchantScrollCatalog OK: {checked} recipe outputs checked; {scrolls} scroll mappings match pinned SpellEffect records")
