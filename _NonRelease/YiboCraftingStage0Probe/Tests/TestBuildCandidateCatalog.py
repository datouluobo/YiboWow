"""Offline checks for candidate evidence and conservative handling of missing IDs."""

import unittest

from BuildCandidateCatalog import PROFESSIONS, build_catalog


class CandidateCatalogTests(unittest.TestCase):
    def test_child_skill_line_and_absence_stay_diagnostic(self):
        skill_lines = [
            {"ID": str(skill_line), "ParentSkillLineID": "0", "DisplayName_lang": name}
            for name, skill_line in PROFESSIONS.items()
        ]
        skill_lines.append({"ID": "975", "ParentSkillLineID": "185", "DisplayName_lang": "Way of the Grill"})
        abilities = [
            {"SkillLine": "975", "Spell": "100", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "0"},
            {"SkillLine": "975", "Spell": "124694", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "0"},
            {"SkillLine": "185", "Spell": "101", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "7"},
            {"SkillLine": "185", "Spell": "102", "TrivialSkillLineRankHigh": "0", "TradeSkillCategoryID": "7"},
            {"SkillLine": "185", "Spell": "818", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "0"},
            {"SkillLine": "165", "Spell": "110955", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "0"},
            {"SkillLine": "333", "Spell": "13262", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "0"},
            {"SkillLine": "755", "Spell": "66587", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "172"},
            {"SkillLine": "773", "Spell": "405005", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "0"},
            {"SkillLine": "773", "Spell": "413897", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "0"},
            {"SkillLine": "773", "Spell": "414814", "TrivialSkillLineRankHigh": "5", "TradeSkillCategoryID": "0"},
        ]
        result = build_catalog(
            skill_lines, abilities, [{"SpellID": "101"}],
            [{"SpellID": "100", "Effect": "68"}],
            [("sample.lua", "1", "烹饪", {100})],
            {165: {19566}},
        )
        cooking = next(p for p in result["professions"] if p["skillLineID"] == 185)
        self.assertEqual(cooking["candidateCount"], 2)
        self.assertEqual(cooking["rawCandidateCount"], 4)
        self.assertEqual(cooking["excludedNonRecipeIDs"], [818])
        self.assertEqual(cooking["branchUnlocks"], [{"unlockSpellID": 124694, "skillLineID": 975, "name": None}])
        self.assertEqual(cooking["observedCount"], 1)
        self.assertEqual(cooking["recipes"][0]["skillLines"], [975])
        self.assertTrue(cooking["recipes"][0]["observed"])
        self.assertFalse(cooking["recipes"][0]["hasReagentRecord"])
        self.assertFalse(cooking["recipes"][1]["observed"])
        leatherworking = next(p for p in result["professions"] if p["skillLineID"] == 165)
        self.assertEqual(leatherworking["legacyOnlyIDs"], [])
        self.assertEqual(leatherworking["resolvedLegacyItemUseIDs"], [19566])
        self.assertEqual(leatherworking["excludedNonRecipeIDs"], [110955])
        self.assertEqual(leatherworking["recipes"], [])
        enchanting = next(p for p in result["professions"] if p["skillLineID"] == 333)
        self.assertEqual(enchanting["excludedNonRecipeIDs"], [13262])
        jewelcrafting = next(p for p in result["professions"] if p["skillLineID"] == 755)
        self.assertEqual(jewelcrafting["quarantinedIDs"], [66587])
        inscription = next(p for p in result["professions"] if p["skillLineID"] == 773)
        self.assertEqual(inscription["removedRecipeIDs"], [413897, 414814])
        self.assertEqual(inscription["quarantinedIDs"], [405005])
        self.assertEqual(result["status"], "candidate-only")

    def test_observed_id_outside_build_is_rejected(self):
        skill_lines = [
            {"ID": str(skill_line), "ParentSkillLineID": "0", "DisplayName_lang": name}
            for name, skill_line in PROFESSIONS.items()
        ]
        with self.assertRaisesRegex(ValueError, "outside DB2 candidates"):
            build_catalog(skill_lines, [], [], [], [("sample.lua", "1", "烹饪", {999})])


if __name__ == "__main__":
    unittest.main()
