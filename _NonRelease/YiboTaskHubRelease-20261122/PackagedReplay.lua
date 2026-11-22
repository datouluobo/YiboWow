-- YiboTaskHub 0.7.0 Mists packaged replay against published Core Mists 1.13.0.
-- Business sources (Todo/AltoBoss/Mail...) are optional and deliberately absent.
-- Run from repo root: lua _NonRelease/YiboTaskHubRelease-20261122/PackagedReplay.lua [source]
local Spec = dofile("_NonRelease/BusinessReleaseHarness-20261122/Spec.lua")
local ALT = "Player-4800-00000002"
local ok = Spec({
    addon = "YiboTaskHub", version = "0.7.0", dir = "_NonRelease/YiboTaskHubRelease-20261122",
    roots = arg[1] == "source" and { { "source", "YiboTaskHub" } }
        or arg[1] == "previous" and { { "previous-release", "_NonRelease/YiboTaskHubRelease-20261122/Previous-Mists/YiboTaskHub" } } or nil,
    wrongOnly = arg[1] == "previous",
    savedVariables = { "YiboTaskHubDB" }, createdOnFresh = { "YiboTaskHubDB" }, pageID = "taskhub",
    previousStore = function()
        return { YiboTaskHubDB = { schemaVersion = 4, marker = "hub-keep",
            settings = { sourceFilter = "all", hiddenWork = {}, workFilter = "all",
                previewColumns = { work = true, beneficiary = false, source = true, status = true },
                hudEnabled = false, showOtherCharacters = false, bossTargetsAutoDisplay = true,
                hudLocked = true, reminderMode = "list", hudRows = 8 },
            bossTargets = { byCharacter = {}, sourceEpoch = "targets:1792330000:123456", revision = 0, nextID = 0 },
            goals = { revision = 1, nextID = 1, byID = { ["goal:1"] = { id = "goal:1", title = "Kept goal", state = "paused",
                priority = 0, revision = 1, createdAt = 1792330000, updatedAt = 1792330000, history = {},
                intent = { providerID = "YiboTodo:targets", objectID = "mop.nomi", targetType = "activity",
                    scope = { mode = "character", characterID = ALT }, repeatPolicy = "recurring" } } } } } }
    end,
    preserved = function(env)
        local db = env.YiboTaskHubDB
        local goal = type(db) == "table" and db.goals and db.goals.byID["goal:1"]
        return type(db) == "table" and db.marker == "hub-keep" and db.schemaVersion == 4
            and db.settings.hudEnabled == false and db.settings.reminderMode == "list" and db.settings.hudRows == 8
            and db.settings.previewColumns.beneficiary == false and db.settings.showOtherCharacters == false
            and goal and goal.title == "Kept goal" and goal.state == "paused"
            and goal.intent.scope.characterID == ALT
    end,
    initialized = function(env) return env.YiboTaskHub and env.YiboTaskHub.CoreIntegration.initialized == true end,
    reinitialize = function(env) return env.YiboTaskHub.CoreIntegration:Initialize() end,
    upgradePatterns = { "API 14" },
    -- Omitted for the "previous" comparison run: 0.6.4 predates the fix.
    wrongTargetPatterns = arg[1] ~= "previous" and { "YiboTaskHub 熊猫人之谜版本", "YiboTaskHub package for Mists" } or nil,
})
os.exit(ok and 0 or 1)
