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
        if recipe.catalogEnabled then
            if not Catalog.groups[recipe.cooldownGroupID] then
                Add(result, "errors", "missing-group:" .. id)
            elseif not (rules and rules.activeGroups and rules.activeGroups[recipe.cooldownGroupID]) then
                Add(result, "errors", "ruleset-disabled:" .. id)
            elseif recipe.trackCooldown == false or not recipe.recipeSpellID then
                Add(result, "warnings", "pending-index:" .. id)
            elseif recipe.verificationStatus ~= "verified" and recipe.verificationStatus ~= "user-confirmed" then
                Add(result, "errors", "unapproved-active:" .. id)
            elseif spells[recipe.recipeSpellID] then
                Add(result, "errors", "duplicate-spell:" .. tostring(recipe.recipeSpellID))
            else
                spells[recipe.recipeSpellID] = id
                result.activeRecipes[#result.activeRecipes + 1] = recipe
            end
        elseif recipe.verificationStatus == "excluded-no-cooldown" then
            Add(result, "warnings", "excluded-no-cooldown:" .. id)
        end
    end
    for id, farm in pairs(Catalog.farmOperations or {}) do
        if farm.provider ~= "farm-operation-observation" then
            Add(result, "errors", "invalid-farm-provider:" .. tostring(id))
        elseif farm.scope ~= "character" or tonumber(farm.mapID) == nil then
            Add(result, "errors", "invalid-farm-scope:" .. tostring(id))
        else
            local spellSeen = {}
            for spellID, rule in pairs(farm.rules or {}) do
                if tonumber(spellID) == nil or type(rule) ~= "table" or type(rule.kind) ~= "string" then
                    Add(result, "errors", "invalid-farm-rule:" .. tostring(id) .. ":" .. tostring(spellID))
                elseif spellSeen[spellID] then
                    Add(result, "errors", "duplicate-farm-spell:" .. tostring(spellID))
                elseif rule.verificationStatus ~= "user-observed" then
                    Add(result, "errors", "unapproved-farm-rule:" .. tostring(spellID))
                else
                    spellSeen[spellID] = true
                end
            end
        end
    end
    for id, activity in pairs(Catalog.dailyActivities or {}) do
        if activity.provider ~= "daily-quest" then
            Add(result, "errors", "invalid-daily-provider:" .. tostring(id))
        elseif activity.scope ~= "character" or activity.scheduleKind ~= "daily-07" then
            Add(result, "errors", "invalid-daily-scope-or-schedule:" .. tostring(id))
        elseif (type(activity.daily) ~= "table" or tonumber(activity.daily.questID) == nil) and type(activity.members) ~= "table" then
            Add(result, "errors", "missing-daily-quest:" .. tostring(id))
        else
            local questIDs = {}
            for _, lesson in ipairs(activity.stages or {}) do
                local questID = tonumber(lesson.questID)
                if not questID or questIDs[questID] then Add(result, "errors", "invalid-or-duplicate-lesson:" .. tostring(id) .. ":" .. tostring(lesson.questID))
                else questIDs[questID] = true end
            end
            if type(activity.daily) == "table" then
                if #((activity.stages) or {}) ~= 5 then Add(result, "errors", "unexpected-lesson-count:" .. tostring(id)) end
            elseif #activity.members ~= 6 then
                Add(result, "errors", "unexpected-member-count:" .. tostring(id))
            else
                for _, member in ipairs(activity.members) do
                    local questID = tonumber(member.questID)
                    if not questID or questIDs[questID] then Add(result, "errors", "invalid-or-duplicate-member:" .. tostring(id) .. ":" .. tostring(member.questID)) else questIDs[questID] = true end
                end
            end
        end
    end
    self.catalogValidation = result
    return result
end

function Addon:GetActiveRecipes()
    return (self:ValidateCatalog()).activeRecipes
end
