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

local function TradeSkillCooldownRemaining(index)
    if type(GetTradeSkillCooldown) ~= "function" then return nil end
    local ok, remaining = pcall(GetTradeSkillCooldown, index)
    if not ok or remaining == nil then return nil end
    -- The legacy trade-skill API returns remaining seconds.  Its optional
    -- second return is an isDayCooldown flag, not a start/duration pair.
    return math.max(0, tonumber(remaining) or 0)
end

local function SpellCooldownRemaining(spellID)
    local start, duration
    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and type(info) == "table" then
            start, duration = info.startTime, info.duration
        end
    elseif type(GetSpellCooldown) == "function" then
        local ok, value, length = pcall(GetSpellCooldown, spellID)
        if ok then start, duration = value, length end
    end
    start, duration = tonumber(start) or 0, tonumber(duration) or 0
    if start <= 0 or duration <= 0 then return nil end
    local now = type(GetTime) == "function" and GetTime() or 0
    return math.max(0, start + duration - now)
end

local function RemainingCooldown(index, spellID)
    local tradeSkill = TradeSkillCooldownRemaining(index)
    local spell = SpellCooldownRemaining(spellID)
    -- Some MoP-era clients report 0 from GetTradeSkillCooldown immediately
    -- after a protected DoTradeSkill macro, while the spell cooldown has
    -- already advanced.  Prefer the longer authoritative remaining value.
    if spell and (not tradeSkill or spell > tradeSkill) then return spell end
    return tradeSkill
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

local function CurrentProfessionID(domain)
    -- A legacy trade-skill window only exposes one profession.  Its title is
    -- the reliable boundary that lets us distinguish an absent recipe from a
    -- recipe belonging to the character's other profession.
    if type(GetTradeSkillLine) ~= "function" then return nil end
    local ok, name = pcall(GetTradeSkillLine)
    if not ok or type(name) ~= "string" or name == "" then return nil end
    for _, profession in ipairs(domain.data.primaryProfessions or {}) do
        if profession.name == name then return tonumber(profession.id) end
    end
    return nil
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
    local currentProfessionID = CurrentProfessionID(domain)
    self.loadedCharacterID = current.id
    self.loadedProfessionID = currentProfessionID
    local observations = {}
    for _, recipe in ipairs(active) do
        local index = indexes[recipe.recipeSpellID]
        local recipeProfessionID = tonumber(recipe.professionID)
        -- When the open window identifies its profession, every catalog
        -- recipe for that profession has a meaningful result: present means
        -- learned, absent means not learned.  Without that boundary retain
        -- the conservative legacy behavior and only record recipes observed
        -- in the list, never guessing about another profession.
        if owned[recipeProfessionID]
            and (not currentProfessionID or recipeProfessionID == currentProfessionID)
            and (index or recipeProfessionID == currentProfessionID) then
            local group = observations[recipe.cooldownGroupID] or {
            provider = self.id, providerSchemaVersion = self.schemaVersion, catalogVersion = Addon.CATALOG_VERSION,
            rulesetID = Addon.RULESET_ID, observedAt = now, sourceState = "known", source = reason,
            recipes = {},
            }
            if index then
                local remaining = RemainingCooldown(index, recipe.recipeSpellID)
                group.recipes[recipe.recipeSpellID] = {
                    learned = true, cooldownKnown = remaining ~= nil,
                    remainingAtScan = remaining, readyAt = remaining and (now + remaining) or nil,
                    craftable = RecipeCraftable(index),
                }
            else
                group.recipes[recipe.recipeSpellID] = { learned = false }
            end
            observations[recipe.cooldownGroupID] = group
        end
    end
    return observations, reason
end

function Provider:IsProfessionLoaded(characterID, professionID)
    return characterID ~= nil and characterID == self.loadedCharacterID
        and tonumber(professionID) == tonumber(self.loadedProfessionID)
end

function Provider:MarkUnavailable(characterID, reason)
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    record.lastAttemptAt, record.state, record.errorCode = Addon:Now(), "unavailable", reason
end

-- UNIT_SPELLCAST_SUCCEEDED is the authoritative completion signal for a
-- direct craft.  On the target client the trade-skill cooldown APIs may lag
-- behind that event (or briefly report zero), so record the daily lockout
-- from the successful cast instead of waiting for a later list refresh.
function Provider:RecordSuccessfulCraft(characterID, spellID)
    spellID = tonumber(spellID)
    if not characterID or not spellID then return false end
    local recipe
    for _, candidate in ipairs(Addon:GetActiveRecipes()) do
        local action = candidate.action or {}
        if tonumber(candidate.recipeSpellID) == spellID or tonumber(action.castSpellID) == spellID then
            recipe = candidate
            break
        end
    end
    if not recipe then return false end
    local recipeSpellID = tonumber(recipe.recipeSpellID) or spellID
    local group = Addon.Catalog.groups[recipe.cooldownGroupID]
    if not group then return false end
    local now = Addon:Now()
    local readyAt = group.resetKind == "daily-07" and Addon.Model.Schedule:NextResetAt(now, group.resetHour) or now
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    record.revision = (tonumber(record.revision) or 0) + 1
    record.lastAttemptAt, record.lastSuccessAt, record.state, record.errorCode = now, now, "known", nil
    record.observations = record.observations or {}
    local observation = record.observations[recipe.cooldownGroupID] or { recipes = {} }
    observation.provider, observation.providerSchemaVersion = self.id, self.schemaVersion
    observation.catalogVersion, observation.rulesetID = Addon.CATALOG_VERSION, Addon.RULESET_ID
    observation.observedAt, observation.sourceState, observation.source = now, "known", "spellcast-success"
    observation.recipes = observation.recipes or {}
    local value = observation.recipes[recipeSpellID] or {}
    value.learned, value.craftable, value.cooldownKnown = true, true, true
    value.remainingAtScan, value.readyAt = math.max(0, readyAt - now), readyAt
    observation.recipes[recipeSpellID] = value
    -- A shared group becomes unavailable as one unit.  Preserve which
    -- recipes are learned, but advance every known member to the same reset
    -- so the state model cannot see a contradictory ready sibling.
    for _, known in pairs(observation.recipes) do
        if known.learned and known.craftable ~= false then
            known.cooldownKnown, known.remainingAtScan, known.readyAt = true, math.max(0, readyAt - now), readyAt
        end
    end
    record.observations[recipe.cooldownGroupID] = observation
    return true
end

function Provider:CollectForCurrentCharacter(expectedCharacterID, refreshTarget)
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character then return false, "character-unavailable" end
    if expectedCharacterID and character.id ~= expectedCharacterID then
        -- Deferred UI events from a previous login are stale. Do not let their
        -- still-visible profession window overwrite the current character.
        return false, "character-changed"
    end
    local observations, reason = self:Collect()
    if not observations then self:MarkUnavailable(character.id, reason); Addon:NotifyChanged(true, refreshTarget); return false, reason end
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
    Addon:NotifyChanged(true, refreshTarget)
    return true, reason
end

function Provider:ObserveWindow(expectedCharacterID, refreshTarget)
    local allowed, reason = self:CanCollect()
    Addon.db.diagnostics.lastWindow = { at = Addon:Now(), source = reason, own = allowed == true, recipeCount = allowed and (tonumber(GetNumTradeSkills()) or 0) or 0, characterID = expectedCharacterID }
    return self:CollectForCurrentCharacter(expectedCharacterID, refreshTarget)
end

Registry:Register(Provider)
