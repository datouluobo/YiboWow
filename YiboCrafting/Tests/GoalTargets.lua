-- Run from the repository root with Lua 5.1.
local recipeStates = { Learned = "learned", Unlearned = "unlearned", Unknown = "unknown" }
local goalNotifications = 0
local characters = {
    { id = "Learned", name = "Learned" },
    { id = "Unlearned", name = "Unlearned" },
    { id = "Unknown", name = "Unknown" },
}
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[Copy(key)] = Copy(item) end
    return result
end
local function CharacterHasProfession(id)
    return id == "Learned" or id == "Unlearned" or id == "Unknown"
end

YiboCore = {
    Defaults = { Copy = function(_, value) return Copy(value) end },
    Locale = { Get = function(_, _, key) return key end },
    Characters = {
        GetAll = function() return characters end,
        Get = function(_, id) for _, character in ipairs(characters) do if character.id == id then return character end end end,
        GetCurrent = function() return { id = "Learned" } end,
        FormatName = function(_, character) return character.name end,
    },
    DataDomains = { Get = function(_, id)
        return CharacterHasProfession(id) and { state = "known", data = { professions = { { id = 197 } } } } or nil
    end },
    Contracts = {
        List = function() return {} end,
        NotifyChanged = function(_, owner, ref, detail)
            assert(owner == "YiboCrafting" and ref == YiboCrafting.GoalTargets.ref)
            assert(detail.reason == "recipe-learning-changed" and detail.characterID == "Learned")
            goalNotifications = goalNotifications + 1
        end,
    },
    ItemResolver = { GetInfo = function(_, id) return { name = "Product " .. id } end },
}
YiboCrafting = {
    NAME = "YiboCrafting",
    RecipeCatalog = { professions = { [197] = { [500] = { outputItemIDs = { 600 } } } } },
    Store = {
        db = { goalCraftCounts = {}, goalRevision = 0, goalSourceEpoch = "fixture", goalObservedAt = 1 },
        GetRecipeState = function(_, id) return recipeStates[id] end,
    },
}
function GetServerTime() return 1 end
dofile("YiboCrafting/GoalTargets.lua")

local base = {
    providerID = "YiboCrafting:targets", objectID = 500, scope = { mode = "account" },
    conditions = { professionID = 197, executorMode = "any", quantity = 1, mode = "craft-times", outputItemID = 600 },
}
local normalized = assert(YiboCrafting.GoalTargets:Normalize({ intent = base }))
assert(#normalized.intent.scope.characterIDs == 1 and normalized.intent.scope.characterIDs[1] == "Learned",
    "account execution candidates require a confirmed learned recipe")
local evaluation = YiboCrafting.GoalTargets:Evaluate({ goals = { { id = "goal", intent = normalized.intent } } })
local task = evaluation.evaluations.goal.task
assert(#task.execution.candidateCharacterIDs == 1 and task.execution.candidateCharacterIDs[1] == "Learned",
    "unlearned and unknown recipe characters are omitted from Hub projection")

recipeStates.Learned = "unlearned"
local noEligible = assert(YiboCrafting.GoalTargets:Normalize({ intent = base }))
assert(#noEligible.intent.scope.characterIDs == 0, "profession alone cannot produce an execution candidate")
local emptyEvaluation = YiboCrafting.GoalTargets:Evaluate({ goals = { { id = "empty", intent = noEligible.intent } } })
assert(#emptyEvaluation.evaluations.empty.task.execution.candidateCharacterIDs == 0,
    "a goal with no known recipe learners has no Hub rows")

local specific = Copy(base)
specific.scope = { mode = "character", characterID = "Unlearned" }
specific.conditions.executorMode = "character"
local rejected, reason = YiboCrafting.GoalTargets:Normalize({ intent = specific })
assert(not rejected and reason == "RECIPE_NOT_LEARNED", "specific unlearned recipe executor is rejected")
YiboCrafting.GoalTargets.ref = {}
YiboCrafting.GoalTargets:RecipeStatesChanged("Learned", 197)
assert(goalNotifications == 1 and YiboCrafting.Store.db.goalRevision == 1,
    "a changed recipe snapshot invalidates Hub's cached goal projection")
print("GoalTargets OK: only confirmed recipe learners are projected as crafting candidates")
