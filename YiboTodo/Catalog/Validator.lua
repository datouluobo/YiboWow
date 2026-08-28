local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

local function Add(result, level, code)
    result[level][#result[level] + 1] = code
end

function Addon:ValidateCatalog()
    local result, spells = { errors = {}, warnings = {}, activeRecipes = {} }, {}
    local rules = Catalog.rulesets[self.RULESET_ID]
    for id, group in pairs(Catalog.groups) do
        if group.active and (not group.activityID or not Catalog.activities[group.activityID]) then Add(result, "errors", "missing-activity:" .. id) end
    end
    for id, recipe in pairs(Catalog.recipes) do
        if recipe.active then
            if recipe.verificationStatus ~= "verified" or not recipe.verifiedBuild or not recipe.evidence then Add(result, "errors", "unverified-active:" .. id)
            elseif spells[recipe.recipeSpellID] then Add(result, "errors", "duplicate-spell:" .. tostring(recipe.recipeSpellID))
            elseif not Catalog.groups[recipe.cooldownGroupID] then Add(result, "errors", "missing-group:" .. id)
            elseif not (rules and rules.activeGroups and rules.activeGroups[recipe.cooldownGroupID]) then Add(result, "errors", "ruleset-disabled:" .. id)
            else spells[recipe.recipeSpellID] = id; result.activeRecipes[#result.activeRecipes + 1] = recipe end
        elseif recipe.verificationStatus == "candidate" then Add(result, "warnings", "candidate:" .. id) end
    end
    self.catalogValidation = result
    return result
end

function Addon:GetActiveRecipes()
    return (self:ValidateCatalog()).activeRecipes
end
