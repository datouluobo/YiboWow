-- YiboTodo 1.3.0 Mists packaged replay against published Core Mists 1.13.0.
-- Run from repo root: lua _NonRelease/YiboTodoRelease-20261122/PackagedReplay.lua [source]
local Spec = dofile("_NonRelease/BusinessReleaseHarness-20261122/Spec.lua")
local ALT = "Player-4800-00000002"
local ok = Spec({
    addon = "YiboTodo", version = "1.3.0", dir = "_NonRelease/YiboTodoRelease-20261122",
    roots = arg[1] == "source" and { { "source", "YiboTodo" } }
        or arg[1] == "previous" and { { "previous-release", "_NonRelease/YiboTodoRelease-20261122/Previous-Mists/YiboTodo" } } or nil,
    wrongOnly = arg[1] == "previous",
    savedVariables = { "YiboTodoDB" }, createdOnFresh = { "YiboTodoDB" }, pageID = "todo",
    previousStore = function()
        return { YiboTodoDB = { schemaVersion = 10, catalogVersion = 16, marker = "todo-keep",
            settings = { levelExpr = "85", monitoringGroups = { nomi = { enabled = false, items = {} } } },
            byCharacter = { [ALT] = { lastSeenAt = 1792330000, providers = { ["profession-cooldown"] = {
                revision = 3, lastAttemptAt = 1792330000, lastSuccessAt = 1792330000, state = "ok", observations = {} } } } } } }
    end,
    preserved = function(env)
        local db = env.YiboTodoDB
        local alt = type(db) == "table" and db.byCharacter and db.byCharacter[ALT]
        return type(db) == "table" and db.marker == "todo-keep" and db.settings.levelExpr == "85"
            and db.settings.monitoringGroups.nomi.enabled == false
            and alt and alt.providers["profession-cooldown"] and alt.providers["profession-cooldown"].revision == 3
    end,
    initialized = function(env) return env.YiboTodo and env.YiboTodo.initialized == true and env.YiboTodo.CoreIntegration.initialized == true end,
    reinitialize = function(env) return env.YiboTodo.CoreIntegration:Initialize() end,
    upgradePatterns = { "API v14", "API 14" },
    -- Omitted for the "previous" comparison run: 1.2.6 predates the fix.
    wrongTargetPatterns = arg[1] ~= "previous" and { "YiboTodo 熊猫人之谜版本", "YiboTodo package for Mists" } or nil,
})
os.exit(ok and 0 or 1)
