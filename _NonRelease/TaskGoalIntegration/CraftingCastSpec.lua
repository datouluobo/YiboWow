-- Actual Core event bus/contracts and Hub cached snapshot completion chain.
dofile("_NonRelease/TaskGoalIntegration/GoalsSpec.lua")
local Core, Hub = YiboCore, YiboTaskHub
local character = { id = "enchanter", name = "Enchanter", realm = "Test Realm" }
Core.Characters.GetAll = function() return { Core.Defaults:Copy(character) } end
Core.Characters.GetCurrent = function() return Core.Defaults:Copy(character) end
Core.Characters.Get = function(_, id) if id == character.id then return Core.Defaults:Copy(character) end end
Core.DataDomains.Get = function() return { state = "known", data = { professions = { { id = 333 } } } } end
Hub.db.goals = { byID = {}, nextID = 0, revision = 0 }
Hub.Goals.ref = assert(Core.Contracts:Register(Hub.NAME, Hub.Goals.definition))
Hub.Contracts:Invalidate()
assert(Core:RegisterAddon("YiboCrafting", { version = "test", requiredAPI = 13 }))
YiboCrafting = { NAME = "YiboCrafting", Store = {
    db = {}, GetRecipeState = function() return "learned" end,
} }
dofile("YiboCrafting/Locales/Interface.lua")
dofile("YiboCrafting/Locales/Targets.lua")
dofile("YiboCrafting/Mists/RecipeCatalog.lua")
dofile("YiboCrafting/Mists/GoalTargets.lua")
local targets, db = YiboCrafting.GoalTargets, YiboCrafting.Store.db
assert(targets:Initialize())
local ids = {}
for _, executor in ipairs({ "any", "character" }) do
    local intent = { providerID = targets.PROVIDER, objectID = 104389,
        scope = executor == "any" and { mode = "account" } or { mode = "character", characterID = character.id },
        conditions = { professionID = 333, executorMode = executor, realmScope = "realm:Test Realm", mode = "craft-times", quantity = 1 },
    }
    local saved = assert(Hub.Goals:Add(intent))
    ids[#ids + 1] = assert(saved.id)
end
assert(Hub.Snapshot:Build({ character }).uniqueCount == 2)
assert(Hub.Contracts.goalCache[targets.PROVIDER], "prime the real source cache before crafting")
local actions, controls = Core.BusinessItemActions, {}
for _, scope in ipairs({ {}, { characterID = character.id } }) do
    local control = CreateFrame("Button")
    actions:Bind(control, { owner = "YiboCrafting", GetIntent = function()
        return { providerID = targets.PROVIDER, objectID = 104389, scope = scope }
    end })
    controls[#controls + 1] = control
end
actions:RefreshMarkers()
for _, control in ipairs(controls) do assert(control.yiboGoalMarkerH.shown, "unfinished goals mark recipe and character controls") end
local before = db.goalRevision or 0
targets.frame.scripts.OnEvent(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-enchant", 104389, 7)
assert(db.goalCraftCounts[character.id][104389] == 1 and db.goalRevision == before + 1)
assert(not Hub.Contracts.goalCache[targets.PROVIDER], "Core change event must invalidate Hub's source cache")
local snapshot = Hub.Snapshot:Build({ character })
assert(snapshot.uniqueCount == 0 and not snapshot.byCharacter[character.id], "finished goals leave the actual Hub view")
for _, id in ipairs(ids) do
    local goal = Hub.db.goals.byID[id]
    assert(goal.state == "completed" and #goal.history == 1)
end
assert(Hub.Snapshot:Build({ character }).uniqueCount == 0, "re-reading cannot restore completed tasks")
actions:RefreshMarkers()
for _, control in ipairs(controls) do
    assert(not control.yiboGoalMarkerH.shown and not control.yiboGoalMarkerV.shown,
        "completed goals must clear both recipe and character goal markers")
    local status = actions.bindings[control].itemStatus
    assert(status.completed == 2 and status.active == 0, "completed history remains queryable")
end
local reopened = Hub.db.goals.byID[ids[1]]
assert(Hub.Goals:Update(reopened.id, reopened.revision, { state = "active", reopen = true }))
actions:RefreshMarkers()
assert(controls[1].yiboGoalMarkerH.shown, "an unfinished goal keeps the marker even alongside completed history")
reopened = Hub.db.goals.byID[ids[1]]
assert(Hub.Goals:Update(reopened.id, reopened.revision, { state = "paused" }))
actions:RefreshMarkers()
assert(controls[1].yiboGoalMarkerH.shown, "paused unfinished goals retain membership feedback")
reopened = Hub.db.goals.byID[ids[1]]
assert(Hub.Goals:Update(reopened.id, reopened.revision, { state = "removed" }))
actions:RefreshMarkers()
assert(not controls[1].yiboGoalMarkerH.shown, "completed history alone does not restore a cleared marker")
print("CraftingCastSpec OK: castBarID payload -> correct recipe -> Core change -> Hub cache invalidation -> completion history -> no task rows")
