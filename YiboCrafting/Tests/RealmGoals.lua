-- Realm assignment is persisted on the goal and enforced by the source.
dofile("YiboCrafting/Tests/EnchantGoals.lua")
local Core, Addon, Hub = YiboCore, YiboCrafting, YiboTaskHub
local targets = Addon.GoalTargets
local localeGet = Core.Locale.Get
Core.Locale.Get = function(self, owner, key, ...)
    if key == "SCOPED_GOAL_TITLE" then local title, realm = ...; return title .. " · " .. realm end
    return localeGet(self, owner, key, ...)
end
local characters = {
    { id = "A", name = "A", realm = "Realm One" },
    { id = "B", name = "B", realm = "Realm One" },
    { id = "C", name = "C", realm = "Realm Two" },
}
local current = characters[1]
Core.Characters.GetAll = function() return characters end
Core.Characters.GetCurrent = function() return current end
Core.Characters.Get = function(_, id) for _, c in ipairs(characters) do if c.id == id then return c end end end
Addon.Store.GetRecipeState = function() return "learned" end
Addon.Store.db.goalCraftCounts = { A = {}, B = {}, C = {} }
Hub.db.goals = { byID = {}, nextID = 0, revision = 0 }
local stocks, queried = {}, {}
local vault = { providerID = "YiboVault:targets" }
Core.Contracts.List = function() return { targets.ref, vault } end
Core.Contracts.Call = function(_, _, ref, method, r)
    if ref == vault then
        local goal = r.goals[1]
        local id = goal.intent.scope.characterID
        queried[id] = true
        return { evaluations = { [goal.id] = { task = {
            state = (stocks[id] or 0) >= 2 and "completed" or "active",
            freshness = { state = "known", observedAt = 1 }, item = { quantity = stocks[id] or 0 },
        } } } }
    end
    return targets[method](targets, r)
end
local base = {
    providerID = targets.PROVIDER, objectID = 104427, scope = { mode = "account" },
    conditions = { professionID = 333, executorMode = "any", quantity = 2, mode = "craft-times" },
}
local pending = assert(Hub.Goals:Add(base))
assert(pending.needsConfiguration and Hub.db.goals.nextID == 0,
    "new account goals must confirm a realm before saving")
assert(pending.fields[#pending.fields].id == "realmScope" and pending.fields[#pending.fields].default == "realm:Realm One")
local function Save(realm, mode)
    local intent = Core.Defaults:Copy(base)
    intent.conditions.realmScope, intent.conditions.mode = realm, mode or "craft-times"
    local result = assert(Hub.Goals:Add(intent))
    assert(result.id)
    return Hub.db.goals.byID[result.id]
end
local one, two = Save("realm:Realm One"), Save("realm:Realm Two")
assert(one.id ~= two.id and #one.intent.scope.characterIDs == 2 and #two.intent.scope.characterIDs == 1)
assert(one.intent.scope.characterIDs[1] == "A" and two.intent.scope.characterIDs[1] == "C")
assert(one.title ~= two.title, "goal titles must distinguish saved realm scopes")
local function Markers()
    local intents = {}
    for _, c in ipairs(characters) do
        intents[#intents + 1] = { providerID = targets.PROVIDER, objectID = base.objectID, scope = { characterID = c.id } }
    end
    return Hub.Goals:LookupItems(intents).items
end
local markers = Markers()
assert(markers[1].count == 1 and markers[2].count == 1 and markers[3].count == 1,
    "each realm's target marks only its own eligible characters")
Addon.Store.db.goalCraftCounts.C[104427] = 100
local result = targets:Evaluate({ goals = { one } }).evaluations[one.id].task
assert(result.state == "active" and #result.execution.candidateCharacterIDs == 2,
    "casts on another realm cannot complete this realm's target")
current = characters[3]
result = targets:Evaluate({ goals = { one } }).evaluations[one.id].task
assert(result.execution.candidateCharacterIDs[1] == "A", "changing login realm does not move the saved assignment")
local holding = Save("realm:Realm One", "holding")
stocks.C = 100
result = targets:Evaluate({ goals = { holding } }).evaluations[holding.id].task
assert(result.state == "active" and not queried.C and queried.A and queried.B,
    "cross-realm scroll inventory is not queried or counted")
stocks.A = 2
assert(targets:Evaluate({ goals = { holding } }).evaluations[holding.id].task.state == "completed")
local all = Save("all")
assert(#all.intent.scope.characterIDs == 3, "cross-realm assignment requires explicit all")
local specific = Core.Defaults:Copy(base)
specific.scope = { mode = "character", characterID = "C" }
specific.conditions.executorMode = "character"
local specificResult = assert(targets:Normalize({ intent = specific }))
assert(specificResult.intent.scope.characterID == "C" and not specificResult.needsConfiguration)
for _, field in ipairs(specificResult.fields) do assert(field.id ~= "realmScope") end
local legacy = Core.Defaults:Copy(one)
legacy.id, legacy.intent.conditions.realmScope = "legacy", nil
legacy.intent.scope.characterIDs = { "A", "B", "C" }
Hub.db.goals.byID.legacy = legacy
Hub.Goals:Changed(targets.PROVIDER)
local blocked = targets:Evaluate({ goals = { legacy } }).evaluations.legacy
assert(blocked.task.readiness == "unknown" and blocked.task.reason == "REALM_REQUIRED" and #blocked.task.execution.candidateCharacterIDs == 0)
local before = Markers()[3].count
legacy.state = "removed"; Hub.Goals:Changed(targets.PROVIDER)
assert(Markers()[3].count == before, "unconfigured legacy goals do not create cross-realm character markers")
characters[#characters + 1] = { id = "D", name = "D", realm = "Realm One" }
Addon.Store.db.goalCraftCounts.D = {}
assert(Markers()[4].count == 3, "late eligible characters use current normalized realm membership")
assert(#one.intent.scope.characterIDs == 2, "membership lookup does not mutate stored snapshots")
local bad = Core.Defaults:Copy(base); bad.conditions.realmScope = "bad"
local rejected, err = targets:Normalize({ intent = bad })
assert(not rejected and err == "REALM_REQUIRED")
local goalsObject = Hub.Goals
dofile("YiboTaskHub/Goals.lua")
assert(Hub.Goals == goalsObject, "old shared goal path remains inert on overlay updates")
dofile("YiboTaskHub/Snapshot.lua")
local projectedTask = blocked.task
projectedTask.itemKey = "legacy"
projectedTask.businessRef = { capability = "action.todo", providerID = targets.PROVIDER, sourceEpoch = "fixture", key = "legacy" }
Hub.Contracts.GetResults = function()
    return { { descriptor = { owner = Addon.NAME }, result = {
        providerID = targets.PROVIDER, sourceTitle = "Crafting", coverage = {}, data = { tasks = { projectedTask } },
    } } }
end
local snapshot = Hub.Snapshot:Build(characters)
assert(snapshot.uniqueCount == 0 and next(snapshot.byCharacter) == nil,
    "Hub must not project legacy unscoped goals to any character")
projectedTask = targets:Evaluate({ goals = { one } }).evaluations[one.id].task
projectedTask.itemKey = one.id
projectedTask.businessRef = { capability = "action.todo", providerID = targets.PROVIDER, sourceEpoch = "fixture", key = one.id }
snapshot = Hub.Snapshot:Build(characters)
assert(snapshot.byCharacter.A and snapshot.byCharacter.B and snapshot.byCharacter.D and not snapshot.byCharacter.C,
    "Hub snapshot uses only the source's realm-limited candidates")
print("RealmGoals OK: explicit realm assignment, both scopes, cross-realm cast/inventory isolation, legacy configuration and live markers")
