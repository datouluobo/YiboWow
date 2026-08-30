local Addon = _G.YiboTodo
local Registry = Addon.Providers.Registry
local Provider = { id = "profession-cooldown", schemaVersion = 1, activityKinds = { "profession-cooldown" } }

local function CallBoolean(owner, name)
    local fn = owner and owner[name]
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn)
    return ok and value == true
end

local function SourceIsOwnWindow()
    -- Both legacy and C_TradeSkillUI paths are checked.  A linked or guild
    -- window must never be allowed to overwrite the current character.
    if CallBoolean(_G, "IsTradeSkillLinked") or CallBoolean(_G, "IsTradeSkillGuild") then
        return false, "foreign-tradeskill-window"
    end
    if CallBoolean(C_TradeSkillUI, "IsTradeSkillLinked") or CallBoolean(C_TradeSkillUI, "IsTradeSkillGuild") then
        return false, "foreign-tradeskill-window"
    end
    if type(GetNumTradeSkills) ~= "function" or (tonumber(GetNumTradeSkills()) or 0) <= 0 then
        return false, "tradeskill-not-ready"
    end
    return true, "own-tradeskill-window"
end

function Provider:CanCollect()
    return SourceIsOwnWindow()
end

local function RecipeIndex()
    local found = {}
    for index = 1, tonumber(GetNumTradeSkills()) or 0 do
        local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(index)
        -- Classic clients have used spell, enchant and trade link families
        -- for the same recipe list over time; the numeric payload is stable.
        local spellID = link and tonumber(link:match("|H[^:]+:(%d+)"))
        if spellID then found[spellID] = index end
    end
    return found
end

local function RemainingCooldown(index)
    if type(GetTradeSkillCooldown) ~= "function" then return nil end
    local ok, first, second = pcall(GetTradeSkillCooldown, index)
    if not ok or first == nil then return nil end
    -- MoP's legacy API normally returns remaining seconds.  The second branch
    -- keeps the normalizer safe should the client expose start/duration.
    if tonumber(second) and tonumber(second) > 0 then
        return math.max(0, (tonumber(first) or 0) + tonumber(second) - Addon:Now())
    end
    return math.max(0, tonumber(first) or 0)
end

local function RecipeCraftable(index)
    if type(GetTradeSkillInfo) ~= "function" then return nil end
    local ok, _, difficulty = pcall(GetTradeSkillInfo, index)
    if not ok or difficulty == nil then return nil end
    -- Legacy trade-skill lists expose recipes below the current skill
    -- requirement as "none".  Keep nil distinct: an unavailable API must
    -- never be interpreted as a confirmed skill-point shortfall.
    return difficulty ~= "none"
end

function Provider:Collect()
    local allowed, reason = self:CanCollect()
    if not allowed then return nil, reason end
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
    local domain = current and Addon.Core.DataDomains:Get(current.id, "professions")
    if not (domain and domain.state == "known" and domain.data) then return nil, "core-professions-unavailable" end
    local owned = {}
    for _, profession in ipairs(domain.data.primaryProfessions or {}) do
        local professionID = tonumber(profession.id)
        if professionID then owned[professionID] = true end
    end
    local now, indexes, active = Addon:Now(), RecipeIndex(), Addon:GetActiveRecipes()
    local observations = {}
    for _, recipe in ipairs(active) do
        local index = indexes[recipe.recipeSpellID]
        -- Do not manufacture a "not learned" result for an unrelated open
        -- profession.  A group enters this scan only after its own recipe has
        -- appeared in the player's current recipe list.
        if index and owned[tonumber(recipe.professionID)] then
            local group = observations[recipe.cooldownGroupID] or {
            provider = self.id, providerSchemaVersion = self.schemaVersion, catalogVersion = Addon.CATALOG_VERSION,
            rulesetID = Addon.RULESET_ID, observedAt = now, sourceState = "known", source = reason,
            recipes = {},
            }
            local remaining = RemainingCooldown(index)
            group.recipes[recipe.recipeSpellID] = {
                learned = true, cooldownKnown = remaining ~= nil,
                remainingAtScan = remaining, readyAt = remaining and (now + remaining) or nil,
                craftable = RecipeCraftable(index),
            }
            observations[recipe.cooldownGroupID] = group
        end
    end
    return observations, reason
end

function Provider:MarkUnavailable(characterID, reason)
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    record.lastAttemptAt, record.state, record.errorCode = Addon:Now(), "unavailable", reason
end

function Provider:CollectForCurrentCharacter()
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character then return false, "character-unavailable" end
    local observations, reason = self:Collect()
    if not observations then self:MarkUnavailable(character.id, reason); Addon:NotifyChanged(); return false, reason end
    -- A formal activity snapshot is only committed for catalog entries that
    -- have already passed the shipped verification gate.
    if #Addon:GetActiveRecipes() == 0 then return true, "baseline-window-observed" end
    if not next(observations) then return true, "no-tracked-recipe-in-window" end
    local record = Addon.Database:GetProvider(character.id, self.id, true)
    record.revision = (tonumber(record.revision) or 0) + 1
    record.lastAttemptAt, record.lastSuccessAt, record.state, record.errorCode = Addon:Now(), Addon:Now(), "known", nil
    -- Each profession window only exposes that profession's recipe list.
    -- Merge its groups into the character record instead of erasing the
    -- observations collected from the other primary profession.
    record.observations = record.observations or {}
    for groupID, observation in pairs(observations) do record.observations[groupID] = observation end
    Addon:NotifyChanged()
    return true, reason
end

function Provider:ObserveWindow()
    local allowed, reason = self:CanCollect()
    Addon.db.diagnostics.lastWindow = { at = Addon:Now(), source = reason, own = allowed == true, recipeCount = allowed and (tonumber(GetNumTradeSkills()) or 0) or 0 }
    return self:CollectForCurrentCharacter()
end

Registry:Register(Provider)
