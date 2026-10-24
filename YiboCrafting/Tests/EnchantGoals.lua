-- Exercise the real provider, Hub save path, and successful-cast callback.
dofile("YiboCrafting/Tests/GoalTargets.lua")
local Core, Addon = YiboCore, YiboCrafting
Addon.RecipeCatalog.professions[197][501] = { outputItemIDs = {} }
Addon.RecipeCatalog.professions[197][502] = { outputItemIDs = { 601, 602 } }
Core.CheckAPIVersion = function() return true end
Core.HasCapability = function() return true end
Core.Events = { Register = function() end }
Core.BusinessItemActions = {}
Core.Characters.GetCurrent = function() return { id = "NewLearned" } end
local casts, registrations = nil, 0
function CreateFrame()
    return {
        RegisterEvent = function(_, event) assert(event == "UNIT_SPELLCAST_SUCCEEDED") end,
        SetScript = function(_, _, callback) casts = callback end,
    }
end
local targets = Addon.GoalTargets
targets.ref = nil
Core.Contracts.Register = function(_, _, definition)
    registrations = registrations + 1
    return definition
end
Core.Contracts.NotifyChanged = function() end
Core.Contracts.List = function() return { targets.ref } end
Core.Contracts.Call = function(_, _, _, method, request) return targets[method](targets, request) end
assert(targets:Initialize())
assert(targets:Initialize() and registrations == 1)
local handler = casts
dofile("YiboCrafting/GoalTargets.lua")
assert(casts == handler and registrations == 1 and Addon.GoalTargets == targets,
    "old overlay path must not execute or register a second provider")
YiboTaskHub = {
    NAME = "YiboTaskHub", Core = Core,
    db = { goals = { byID = {}, nextID = 0, revision = 0 } },
    Now = function() return 1 end,
    T = function(_, key) return key end,
    Contracts = { Invalidate = function() end },
}
dofile("YiboTaskHub/Common/Goals.lua")
local goals = {}
for _, mode in ipairs({ "any", "character" }) do
    local intent = {
        providerID = targets.PROVIDER, objectID = 501,
        scope = mode == "any" and { mode = "account" } or { mode = "character", characterID = "NewLearned" },
        conditions = { professionID = 197, executorMode = mode, realmScope = "all", quantity = 2, mode = "craft-times" },
    }
    local clean = assert(targets:Normalize({ intent = intent }))
    assert(not clean.needsConfiguration and not clean.intent.conditions.outputItemID)
    assert(#clean.fields == (mode == "any" and 4 or 3) and #clean.fields[3].options == 1)
    assert(clean.fields[3].options[1].value == "craft-times")
    local saved = assert(YiboTaskHub.Goals:Add(intent))
    assert(saved.id and not saved.needsConfiguration, "spell-only goal must save through Hub")
    local duplicate = assert(YiboTaskHub.Goals:Add(intent))
    assert(duplicate.existing and duplicate.id == saved.id)
    local goal = YiboTaskHub.db.goals.byID[saved.id]
    goals[#goals + 1] = goal
    assert(YiboTaskHub.Goals:Update(goal.id, goal.revision, { intent = goal.intent }))
    local holding = Core.Defaults:Copy(intent)
    holding.conditions.mode, holding.conditions.outputItemID = "holding", 999
    local corrected = assert(targets:Normalize({ intent = holding }))
    assert(corrected.intent.conditions.mode == "craft-times" and not corrected.intent.conditions.outputItemID)
end
local function Check(state, count)
    local evaluations = targets:Evaluate({ goals = goals }).evaluations
    for _, goal in ipairs(goals) do
        local task = assert(evaluations[goal.id].task)
        assert(task.state == state and task.item == nil)
    end
    assert((Addon.Store.db.goalCraftCounts.NewLearned[501] or 0) == count)
end
Check("active", 0)
casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "target", "cast", 501)
Check("active", 0)
casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 501)
Check("active", 1)
casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 501)
Check("completed", 2)
local product = Core.Defaults:Copy(goals[1].intent)
product.objectID = 500
product.conditions.mode = "holding"
local single = assert(targets:Normalize({ intent = product }))
assert(single.intent.conditions.outputItemID == 600 and #single.fields == 5)
assert(single.identity:find(":600:holding", 1, true), "existing product identity remains stable")
product.objectID = 502
assert(targets:Normalize({ intent = product }).needsConfiguration)
product.conditions.outputItemID = 999
local invalid, reason = targets:Normalize({ intent = product })
assert(not invalid and reason == "INVALID_PRODUCT_MODE")
print("EnchantGoals OK: both scopes save, edit, deduplicate and complete on successful casts; product validation preserved")

-- Load the shipped Mists data, not a hand-authored enchant fixture.
dofile("YiboCrafting/Mists/RecipeCatalog.lua")
local catalog = Addon.RecipeCatalog
dofile("YiboCrafting/RecipeCatalog.lua")
assert(Addon.RecipeCatalog == catalog, "old overlay catalog must remain inert")
assert(catalog.professions[333][7418].outputItemIDs[1] == 38679)
assert(catalog.professions[333][13620].outputItemIDs[1] == 38802)
assert(catalog.professions[333][104427].outputItemIDs[1] == 74724)
assert(#catalog.professions[333][103461].outputItemIDs == 0,
    "personal ring enchants have no scroll in the pinned client data")
Core.DataDomains.Get = function() return { state = "known", data = { professions = { { id = 333 } } } } end
local stock, vaultCalls = 0, 0
local vault = { providerID = "YiboVault:targets" }
Core.Contracts.List = function() return { targets.ref, vault } end
Core.Contracts.Call = function(_, _, ref, method, request)
    if ref == vault then
        vaultCalls = vaultCalls + 1
        local goal = request.goals[1]
        assert(goal.intent.objectID == 38679 or goal.intent.objectID == 74724,
            "inventory must receive the scroll item ID")
        return { evaluations = { [goal.id] = { task = {
            state = stock >= 2 and "completed" or "active",
            item = { quantity = stock }, freshness = { state = "known", observedAt = 1 },
        } } } }
    end
    return targets[method](targets, request)
end
for _, spellID in ipairs({ 7418, 104427 }) do
    local scrollID = catalog.professions[333][spellID].outputItemIDs[1]
    local castGoals, holdingGoals = {}, {}
    stock = 0
    for _, scopeMode in ipairs({ "any", "character" }) do
        for _, completion in ipairs({ "craft-times", "holding" }) do
            local intent = {
                providerID = targets.PROVIDER, objectID = spellID,
                scope = scopeMode == "any" and { mode = "account" } or { mode = "character", characterID = "NewLearned" },
                conditions = { professionID = 333, executorMode = scopeMode, realmScope = "all", quantity = 2, mode = completion },
            }
            local normalized = assert(targets:Normalize({ intent = intent }))
            assert(not normalized.needsConfiguration and normalized.intent.conditions.outputItemID == scrollID)
            assert(#normalized.fields == (scopeMode == "any" and 5 or 4) and #normalized.fields[3].options == 2)
            assert(normalized.fields[4].options[1].value == scrollID)
            local saved = assert(YiboTaskHub.Goals:Add(intent))
            assert(saved.id and not saved.needsConfiguration)
            assert(YiboTaskHub.Goals:Add(intent).existing)
            local goal = YiboTaskHub.db.goals.byID[saved.id]
            assert(YiboTaskHub.Goals:Update(goal.id, goal.revision, { intent = goal.intent }))
            local list = completion == "holding" and holdingGoals or castGoals
            list[#list + 1] = goal
        end
    end
    local function CheckGoals(list, state)
        local evaluations = targets:Evaluate({ goals = list }).evaluations
        for _, goal in ipairs(list) do assert(evaluations[goal.id].task.state == state) end
    end
    CheckGoals(castGoals, "active"); CheckGoals(holdingGoals, "active")
    stock = 2
    CheckGoals(holdingGoals, "completed"); CheckGoals(castGoals, "active")
    stock = 0
    casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", spellID)
    CheckGoals(castGoals, "active")
    casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", spellID)
    CheckGoals(castGoals, "completed"); CheckGoals(holdingGoals, "active")
end
assert(vaultCalls > 0)
print("Enchant scroll goals OK: shipped recipe mappings, both scopes and completion modes; inventory and casts stay independent")

-- Current Mists events may append castBarID after the recipe spell ID.
local extraPayloadIntent = {
    providerID = targets.PROVIDER, objectID = 104389, scope = { mode = "account" },
    conditions = { professionID = 333, executorMode = "any", realmScope = "all", quantity = 2, mode = "craft-times" },
}
local extraSaved = assert(YiboTaskHub.Goals:Add(extraPayloadIntent))
local extraGoal = assert(YiboTaskHub.db.goals.byID[extraSaved.id])
local priorOtherRecipe = Addon.Store.db.goalCraftCounts.NewLearned[104427]
casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-with-bar-1", 104389, 104427)
assert(Addon.Store.db.goalCraftCounts.NewLearned[104389] == 1,
    "spellID is the third payload argument even when castBarID names another catalog spell")
assert(Addon.Store.db.goalCraftCounts.NewLearned[104427] == priorOtherRecipe,
    "castBarID must never increment a different recipe")
assert(targets:Evaluate({ goals = { extraGoal } }).evaluations[extraGoal.id].task.state == "active")
casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-with-bar-2", 104389, 0)
local extraEvaluation = targets:Evaluate({ goals = { extraGoal } }).evaluations[extraGoal.id]
assert(extraEvaluation.task.state == "completed")
extraEvaluation.sourceEpoch = Addon.Store.db.goalSourceEpoch
assert(YiboTaskHub.Goals:Observe(extraGoal.id, extraEvaluation))
assert(YiboTaskHub.db.goals.byID[extraGoal.id].state == "completed",
    "Hub persists completion after real event parsing and provider evaluation")
casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "target", "other-unit", 104389, 4)
casts(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "missing-spell", nil, 104389)
assert(Addon.Store.db.goalCraftCounts.NewLearned[104389] == 2,
    "other units and missing spell IDs cannot manufacture evidence")
print("Craft event payload OK: trailing castBarID ignored, exact recipe counted, Hub completion observed")
