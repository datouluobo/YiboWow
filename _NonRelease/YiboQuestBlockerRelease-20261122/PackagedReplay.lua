-- YiboQuestBlocker 3.2.0 Mists packaged replay against published Core Mists 1.13.0.
-- Run from repo root: lua _NonRelease/YiboQuestBlockerRelease-20261122/PackagedReplay.lua [source]
local Spec = dofile("_NonRelease/BusinessReleaseHarness-20261122/Spec.lua")
local ALT = "Player-4800-00000002"
local ok = Spec({
    addon = "YiboQuestBlocker", version = "3.2.0", dir = "_NonRelease/YiboQuestBlockerRelease-20261122",
    roots = arg[1] == "source" and { { "source", "YiboQuestBlocker" } }
        or arg[1] == "previous" and { { "previous-release", "_NonRelease/YiboQuestBlockerRelease-20261122/Previous-Mists/YiboQuestBlocker" } } or nil,
    wrongOnly = arg[1] == "previous",
    savedVariables = { "YiboQuestBlockerDB" }, createdOnFresh = { "YiboQuestBlockerDB" }, pageID = "quest-blocker",
    previousStore = function()
        return { YiboQuestBlockerDB = { schemaVersion = 3, marker = "qb-keep",
            globalBlocked = { [31337] = true }, globalCache = { [31337] = { title = "Kept quest" } },
            characterData = { [ALT] = { blocked = { [777] = true }, cache = {} } },
            filters = { showDaily = true, showNormal = true, hideComplete = true, reportChat = true, autoAbandon = false, levelExpr = "85" },
            settings = { previewColumns = { global = true, characters = false }, runtime = { processMode = "abandon" } },
            diagnostics = {} } }
    end,
    preserved = function(env)
        local db = env.YiboQuestBlockerDB
        return type(db) == "table" and db.marker == "qb-keep" and db.globalBlocked[31337] == true
            and db.characterData[ALT] and db.characterData[ALT].blocked[777] == true
            and db.filters.levelExpr == "85" and db.settings.previewColumns.characters == false
            and db.settings.runtime.processMode == "abandon"
    end,
    initialized = function(env) return env.YQB and env.YQB.CoreCompatible == true and env.YQB.CoreIntegration and env.YQB.CoreIntegration.initialized == true end,
    reinitialize = function(env) return env.YQB.CoreIntegration:Initialize() end,
    upgradePatterns = { "API 14", "API v14" },
})
os.exit(ok and 0 or 1)
