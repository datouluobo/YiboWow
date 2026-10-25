-- Run from repository root: lua YiboAltoBoss/_NonRelease/Tests/LockoutProjectionSpec.lua
local checks, resources = 0, {}
local function check(value, label) checks = checks + 1; assert(value, label) end
GetServerTime = function() return 1000 end
time, date = os.time, os.date
GetRealmName = function() return "Realm" end
GetDifficultyInfo = function(id) return "Difficulty " .. id end
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
YiboCore = {
    IsInitialized = function() return true end,
    CheckAPIVersion = function() return true end,
    HasCapability = function() return true end,
    Characters = { ResolveLegacyKey = function(_, key) return key end },
    Locale = {
        Register = function(_, owner, lang, values)
            if lang == "en" then for key, value in pairs(values) do resources[key] = value end end
        end,
        Get = function(_, owner, key, ...) return string.format(assert(resources[key], key), ...) end,
    },
}
YAB = {
    GetBossList = function() return {} end,
    GetAccountCharacterKeys = function() return { "A", "B" } end,
}
dofile("YiboAltoBoss/Locale.lua")
dofile("YiboAltoBoss/LockoutLocale.lua")
dofile("YiboAltoBoss/InstanceLockouts.lua")
local saved = { instanceID = 580, name = "Sunwell Plateau", difficultyID = 4,
    difficultyName = "25 Player", resetAt = 2000, bossCount = 1, bosses = { { killed = true } } }
YiboAltoBossDB = { settings = {}, characters = {
    A = { instanceLockoutsObservedAt = 1000 },
    B = { instanceLockoutsObservedAt = 1000, instanceLockouts = { raid = saved } },
} }
local baseColumn = { key = "legacy:580", mapID = 580, instanceID = 580, name = "Sunwell Plateau", isRaid = true }
local ordinaryColumns = { baseColumn, { key = "stocks", mapID = 34, instanceID = 34, name = "The Stockade" } }
YAB.GetLockoutColumns = function() return ordinaryColumns end
local goal = { active = true, kind = "instance", catalogID = "instance:580", difficultyID = 4,
    difficultyName = "25 Player", title = "Sunwell Plateau", scope = "all", encounterIDs = {} }
local config = { targets = { A = { goal }, B = {} } }
YAB.PlannedTargets = {
    VisibleConfiguration = function() return config end,
    Progress = function() return { state = "ready", reason = "0/1 target" } end,
}
YAB.TargetCatalog = { Get = function() return { mapID = 580, isRaid = true, aliases = { "SWP" } } end }
dofile("YiboAltoBoss/Common/TargetProjection.lua")
-- Override the contract reader only; exercise actual projection/status/tooltip code.
YAB.PlannedTargets.VisibleConfiguration = function() return config end
for _, context in ipairs({ {}, { preview = true } }) do
    local columns = YAB.GetLockoutColumns(context)
    check(#columns == 2, "goal and ordinary Sunwell columns merge in both surfaces")
    check(columns[1].plannedCatalogID == "instance:580" and columns[2].mapID == 34, "unrelated dungeon retained")
    local state, label = YAB.GetLockoutStatus("A", columns[1])
    check(state == "open" and label == "0/1 target", "goal character uses goal progress")
    check(YAB.GetLockoutStatus("B", columns[1]) == "clear", "other character retains ordinary lockout")
    check(type(YAB.GetLockoutTooltip("B", columns[1])[1]) == "table", "other character retains ordinary tooltip")
end
local columns = YAB.GetLockoutColumns()
saved.difficultyID = 3
check(YAB.GetLockoutStatus("B", columns[1]) == "open", "other difficulty does not leak into merged column")
saved.difficultyID = 4
config.targets.B = { goal }
check(#YAB.GetLockoutColumns() == 2, "same goal from multiple characters appears once")
config.targets.B = { { active = true, kind = "instance", catalogID = "instance:580", difficultyID = 3,
    difficultyName = "10 Player", title = "Sunwell Plateau" } }
check(#YAB.GetLockoutColumns() == 3, "different goal difficulties remain separate")
config = nil
check(YAB.GetLockoutColumns()[1] == baseColumn, "missing or disabled integration restores ordinary column")
config = { targets = { A = { goal } } }
ordinaryColumns = {}
columns = YAB.GetLockoutColumns({ preview = true })
check(#columns == 1 and YAB.GetLockoutStatus("B", columns[1]) == "not-applicable", "goal-only preview retains admission")
check(baseColumn.difficultyID == nil and saved.difficultyID == 4, "projection does not mutate input or snapshot")
-- Alias IDs and multiple catalog entry points still describe one map/difficulty.
YAB.TargetCatalog.CanonicalDifficulty = function(_, _, difficulty) return difficulty == 4 and 176 or difficulty end
ordinaryColumns = { baseColumn }
config = { targets = { A = {
    { active = true, kind = "instance", catalogID = "instance:580", difficultyID = 4, difficultyName = "Old 25",
        title = "Sunwell Plateau", scope = "boss", encounterIDs = { "boss1" } },
    { active = true, kind = "instance", catalogID = "journal:12", difficultyID = 176, difficultyName = "25 Player",
        title = "Sunwell Plateau", scope = "boss", encounterIDs = { "boss2" } },
}, B = {} } }
columns = YAB.GetLockoutColumns({ preview = true })
check(#columns == 1 and columns[1].plannedDifficultyID == 176, "catalog and difficulty aliases share one column")
YAB.PlannedTargets.Progress = function(_, _, target)
    check(target.difficultyID == 176 and #target.encounterIDs == 2, "same character goals aggregate all selected bosses")
    return { state = "ready", reason = "0/2" }
end
check(YAB.GetLockoutStatus("A", columns[1]) == "open", "merged column uses owner progress")
saved.difficultyID = 176
check(YAB.GetLockoutStatus("B", columns[1]) == "clear", "native ordinary lockout remains visible for other characters")
print("LockoutProjectionSpec: " .. checks .. " checks passed")
