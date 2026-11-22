-- YiboLegendary 2.3.0 Mists packaged replay against published Core Mists 1.13.0.
-- Run from repo root: lua _NonRelease/YiboLegendaryRelease-20261122/PackagedReplay.lua [source]
local Spec = dofile("_NonRelease/BusinessReleaseHarness-20261122/Spec.lua")
local ALT = "Player-4800-00000002"
local ok = Spec({
    addon = "YiboLegendary", version = "2.3.0", dir = "_NonRelease/YiboLegendaryRelease-20261122",
    roots = arg[1] == "source" and { { "source", "YiboLegendary" } }
        or arg[1] == "previous" and { { "previous-release", "_NonRelease/YiboLegendaryRelease-20261122/Previous-Mists/YiboLegendary" } } or nil,
    wrongOnly = arg[1] == "previous",
    savedVariables = { "YiboLegendaryDB", "YiboCloakProgressDB" }, createdOnFresh = { "YiboLegendaryDB" }, pageID = "legendary",
    previousStore = function()
        return { YiboLegendaryDB = { schemaVersion = 2, marker = "leg-keep",
            settings = { phaseAvailability = {}, levelExpr = "88", selectedTargetId = "CLOAK", targetPage = "active",
                previewColumnsVersion = 7, previewColumns = { CLOAK = true, THUNDERFURY = false, SORIDAL = true } },
            byCharacter = { [ALT] = { characterID = ALT, lastSeenAt = 1792330000, marker = "alt-keep" } } } }
    end,
    preserved = function(env)
        local db = env.YiboLegendaryDB
        return type(db) == "table" and db.marker == "leg-keep" and db.settings.levelExpr == "88"
            and db.settings.previewColumns.THUNDERFURY == false and db.byCharacter[ALT]
            and db.byCharacter[ALT].marker == "alt-keep"
    end,
    initialized = function(env) return env.YiboLegendary and env.YiboLegendary.initialized == true end,
    reinitialize = function(env) return env.YiboLegendary:Initialize() end,
    upgradePatterns = { "API v14" },
})
os.exit(ok and 0 or 1)
