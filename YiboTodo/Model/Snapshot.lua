local Addon = _G.YiboTodo
local Snapshot = { dirty = true }
Addon.Snapshot = Snapshot

function Snapshot:Invalidate() self.dirty = true end

local function NextDailyReset(now, hour)
    hour = tonumber(hour) or 7
    local currentHour, currentMinute
    if GetGameTime then currentHour, currentMinute = GetGameTime() end
    if currentHour == nil then
        local localTime = date("*t", now)
        currentHour, currentMinute = localTime.hour, localTime.min
    end
    local todayStart = now - ((tonumber(currentHour) or 0) * 3600 + (tonumber(currentMinute) or 0) * 60)
    local resetAt = todayStart + hour * 3600
    if now >= resetAt then resetAt = resetAt + 86400 end
    return resetAt
end

local function BuildGroup(groupID)
    local group = Addon.Catalog.groups[groupID]
    group.members = {}
    for _, recipe in pairs(Addon.Catalog.recipes) do
        if recipe.catalogEnabled and recipe.cooldownGroupID == groupID then
            group.members[#group.members + 1] = recipe
        end
    end
    table.sort(group.members, function(left, right)
        if (left.order or 999) ~= (right.order or 999) then return (left.order or 999) < (right.order or 999) end
        return tostring(left.id) < tostring(right.id)
    end)
    return group
end

local function ProfessionSlots(characterID)
    local core = Addon.Core
    local domain = core and core.DataDomains and core.DataDomains:Get(characterID, "professions")
    if not (domain and domain.state == "known" and domain.data) then return nil end
    local slots = {}
    for slot = 1, 2 do
        local profession = domain.data.primaryProfessions and domain.data.primaryProfessions[slot]
        local professionID = profession and tonumber(profession.id)
        slots[slot] = professionID and { id = professionID, name = profession.name, icon = profession.icon, skillLevel = tonumber(profession.skillLevel) } or false
    end
    return slots
end

local function RecipeForGroup(group)
    local fallback
    for _, recipe in ipairs(group.members or {}) do
        fallback = fallback or recipe
        if recipe.resultItemID then return recipe end
    end
    return fallback
end

local function SortProjects(left, right)
    local priority = { actionable = 1, estimated = 2, cooldown = 3, ["skill-insufficient"] = 4, unknown = 5 }
    local leftPriority, rightPriority = priority[left.state] or 99, priority[right.state] or 99
    if leftPriority ~= rightPriority then return leftPriority < rightPriority end
    if (left.order or 999) ~= (right.order or 999) then return (left.order or 999) < (right.order or 999) end
    return tostring(left.groupID or "") < tostring(right.groupID or "")
end

local function BuildFarmProject(characterID, now)
    local provider = Addon.Providers.Registry:Get("farm-operation-observation")
    local day, eligibility, definition
    if provider then day, definition = provider:GetCurrentDay(characterID, now) end
    if not definition or Addon.Settings:GetMode("activity", definition.id, definition.defaultMode) == "hidden" then return nil, false end
    local operations = day and day.operations or {}
    local kinds = {}
    for _, operation in ipairs(operations) do kinds[operation.kind] = true end
    if #operations == 0 and provider then previousDay = provider:GetLatestExpiredDay(characterID, now) end
    local previousKinds = {}
    for _, operation in ipairs(previousDay and previousDay.operations or {}) do previousKinds[operation.kind] = true end
    local plantedToday = kinds.till or kinds.plant or kinds.growing
    local harvestedToday = kinds.harvest
    local readyFromPreviousPlant = #operations == 0 and (previousKinds.till or previousKinds.plant)
    if not plantedToday and not harvestedToday and not readyFromPreviousPlant then return nil, true end
    local labels = {}
    for _, kind in ipairs({ "harvest", "till", "plant", "weed", "pest", "care" }) do
        if kinds[kind] then labels[#labels + 1] = ({ harvest = "收获", till = "开垦", plant = "播种", weed = "除草", pest = "除虫", care = "照料" })[kind] end
    end
    return {
        groupID = definition.id, label = definition.label, order = 1,
        -- User-selected low-fidelity policy: one observed operation represents
        -- the full farm workflow. This is an optimistic projection, never a
        -- discovered 16-plot state.
        state = readyFromPreviousPlant and "actionable" or "completed",
        iconKind = "texture", icon = "Interface\\Icons\\inv_misc_basket_04.blp",
        fallbackIcon = "Interface\\Icons\\inv_misc_basket_04.blp",
        observedAt = (day and day.observedAt) or (previousDay and previousDay.observedAt),
        nextResetAt = (day and day.nextResetAt) or Addon.Model.Schedule:NextResetAt(now, definition.resetHour),
        operationObserved = #operations > 0, operationLabels = labels,
        optimisticFarm = true,
        statusText = kinds.growing and "已收菜并种菜（目视生长作物投影）"
            or plantedToday and "已种菜（一次操作按全农场投影）"
            or harvestedToday and "已收菜（一次操作按全农场投影）"
            or "可收菜（依据前日种菜投影）",
        providerState = (day or previousDay) and "available" or "not-yet-observed",
    }, true
end

local function BuildNomiProject(characterID, now)
    local provider = Addon.Providers.Registry:Get("daily-quest")
    local day, definition
    if provider then day, definition = provider:GetCurrentDay(characterID, now) end
    if not definition or Addon.Settings:GetMode("activity", definition.id, definition.defaultMode) == "hidden" then return nil, false end
    -- A historical Nomi completion only establishes that this character has
    -- accessed the repeatable content before.  It cannot prove which daily is
    -- offered today, so it must never turn a missing current quest-log signal
    -- into an actionable project during a character switch or snapshot rebuild.
    local eligibility = provider and provider:GetEligibility(characterID)
    local state = day and day.state or "unknown"
    local label = day and day.label or definition.label
    local statusText
    if state == "actionable" then statusText = "任务日志已确认，可处理"
    elseif state == "completed" then statusText = "本服务器日已完成"
    elseif eligibility then statusText = "曾完成诺米日常，等待今日任务日志确认"
    else statusText = "尚未在任务日志中确认当前诺米日常"
    end
    return {
        groupID = definition.id, label = label, order = 1, state = state,
        iconKind = "texture", icon = definition.icon, fallbackIcon = definition.icon,
        observedAt = (day and day.observedAt) or (eligibility and eligibility.confirmedAt),
        nextResetAt = day and day.nextResetAt or Addon.Model.Schedule:NextResetAt(now, definition.resetHour),
        questID = day and day.questID, questKind = day and day.kind,
        eligibilityKnown = eligibility ~= nil,
        statusText = statusText, reason = day and day.reason,
        providerState = day and "available" or "not-yet-observed",
    }, true
end

local function BuildCookingProject(characterID, characterLevel, now)
    local provider = Addon.Providers.Registry:Get("daily-quest")
    local definition = provider and provider:GetCookingDefinition()
    if not definition or Addon.Settings:GetMode("activity", definition.id, definition.defaultMode) == "hidden" then return nil, false end
    if (tonumber(characterLevel) or 0) < 90 then return nil, true end
    local day = provider:GetCurrentCookingDay(characterID, now)
    local state = day and day.state or "actionable"
    local icon = definition.icon
    local core = Addon.Core
    local domain = core and core.DataDomains and core.DataDomains:Get(characterID, "professions")
    for _, profession in ipairs(domain and domain.data and domain.data.professions or {}) do
        if tonumber(profession.id) == 185 then icon = profession.icon or icon; break end
    end
    return {
        groupID = definition.id, label = definition.label, order = 1, state = state,
        iconKind = "texture", icon = icon, fallbackIcon = definition.icon,
        observedAt = day and day.observedAt,
        nextResetAt = day and day.nextResetAt or Addon.Model.Schedule:NextResetAt(now, definition.resetHour),
        statusText = state == "completed" and "本服务器日已完成" or "可处理",
        providerState = day and "available" or "not-yet-observed",
    }, true
end

function Snapshot:Build()
    local now = Addon:Now()
    if not self.dirty and self.value and (not self.nextTransitionAt or now < self.nextTransitionAt) then return self.value end
    local value = { revision = (self.value and self.value.revision or 0) + 1, builtAt = now, characters = {}, accountActivities = {} }
    local nextTransitionAt
    local characters = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetAll() or {}
    for _, coreCharacter in ipairs(characters) do
        local characterID, slots = coreCharacter.id, ProfessionSlots(coreCharacter.id)
        local stored = (Addon.db.byCharacter or {})[characterID] or {}
        local farmProject, farmEnabled = BuildFarmProject(characterID, now)
        local nomiProject, nomiEnabled = BuildNomiProject(characterID, now)
        local cookingProject, cookingEnabled = BuildCookingProject(characterID, coreCharacter.level, now)
        if farmProject and farmProject.nextResetAt and farmProject.nextResetAt > now
            and (not nextTransitionAt or farmProject.nextResetAt < nextTransitionAt) then
            nextTransitionAt = farmProject.nextResetAt
        end
        if nomiProject and nomiProject.nextResetAt and nomiProject.nextResetAt > now
            and (not nextTransitionAt or nomiProject.nextResetAt < nextTransitionAt) then
            nextTransitionAt = nomiProject.nextResetAt
        end
        if cookingProject and cookingProject.nextResetAt and cookingProject.nextResetAt > now
            and (not nextTransitionAt or cookingProject.nextResetAt < nextTransitionAt) then
            nextTransitionAt = cookingProject.nextResetAt
        end
        if slots or farmEnabled or nomiEnabled or cookingEnabled then
            local provider = stored.providers and stored.providers["profession-cooldown"]
            local character = { updatedAt = provider and provider.lastSuccessAt or 0, providerState = provider and provider.state or "not-yet-scanned", activities = {}, professionSlots = slots or {}, summary = { todo = 0, actionable = 0, cooldown = 0, items = {} }, farmColumn = farmEnabled, farmProjects = farmProject and { farmProject } or {}, nomiColumn = nomiEnabled, nomiProjects = nomiProject and { nomiProject } or {}, cookingColumn = cookingEnabled, cookingProjects = cookingProject and { cookingProject } or {} }
            for groupID, group in pairs(Addon.Catalog.groups) do
                if slots and group.active and Addon.Settings:GetMode("cooldownGroup", groupID, group.defaultMode) ~= "hidden" then
                    local builtGroup, observation = BuildGroup(groupID), provider and provider.observations and provider.observations[groupID]
                    -- A recipe can only project into the Core-declared primary
                    -- profession slot.  Do not turn the catalog into a source
                    -- of profession ownership.
                    local slot
                    for index = 1, 2 do if slots[index] and slots[index].id == tonumber(builtGroup.professionID) then slot = index; break end end
                    local activity = Addon.Model.State:Evaluate(builtGroup, observation, value.builtAt, slot and slots[slot].skillLevel)
                    -- Core's profession domain is the source of ownership.
                    -- As soon as it confirms a matching profession, project
                    -- the verified group as actionable. Opening the profession
                    -- window only supplies a cooldown override.
                    if slot and activity.state ~= "locked" then
                        local recipe = RecipeForGroup(builtGroup)
                        if recipe then
                            activity.groupID, activity.slot, activity.label = groupID, slot, builtGroup.label or groupID
                            activity.iconKind = recipe.resultItemID and "item" or (recipe.recipeSpellID and "spell" or "texture")
                            activity.icon = recipe.resultItemID or recipe.recipeSpellID or slots[slot].icon
                            activity.fallbackIcon = slots[slot].icon
                            activity.fallbackSpellID = recipe.recipeSpellID
                            activity.order, activity.period = builtGroup.order, builtGroup.resetKind
                            activity.professionID, activity.professionName = builtGroup.professionID, slots[slot].name
                            local catalogActivity = Addon.Catalog.activities[builtGroup.activityID]
                            activity.sourceExpansion = catalogActivity and catalogActivity.sourceExpansion or recipe.introducedIn
                            activity.catalogPending = recipe.trackCooldown == false or recipe.recipeSpellID == nil
                            activity.observedAt = (observation and observation.observedAt) or (provider and provider.lastSuccessAt)
                            character.activities[groupID] = activity
                            if activity.state == "cooldown" then
                                local transitionAt = activity.readyAt
                                if builtGroup.resetKind == "daily-07" then
                                    transitionAt = NextDailyReset(value.builtAt, builtGroup.resetHour)
                                end
                                if transitionAt and transitionAt > value.builtAt
                                    and (not nextTransitionAt or transitionAt < nextTransitionAt) then
                                    nextTransitionAt = transitionAt
                                end
                            end
                        end
                    end
                    if slot then
                        if activity.state == "actionable" then character.summary.todo = character.summary.todo + 1; character.summary.actionable = character.summary.actionable + 1; character.summary.items[#character.summary.items + 1] = group.label or groupID
                        elseif activity.state == "estimated" then character.summary.todo = character.summary.todo + 1; character.summary.items[#character.summary.items + 1] = "预计：" .. (group.label or groupID)
                        elseif activity.state == "cooldown" then
                            character.summary.cooldown = character.summary.cooldown + 1
                            if not character.summary.nearestReady or activity.readyAt < character.summary.nearestReady then character.summary.nearestReady = activity.readyAt end
                        elseif activity.state == "unknown" then
                            character.summary.items[#character.summary.items + 1] = "待确认：" .. (group.label or groupID)
                        end
                    end
                end
            end
            -- The UI intentionally projects both primary professions into one
            -- compact column. Keep profession and expansion metadata on each
            -- activity so later rulesets can still group and explain entries
            -- without bringing back one permanent column per profession.
            character.professionProjects = {}
            for _, activity in pairs(character.activities) do
                character.professionProjects[#character.professionProjects + 1] = activity
            end
            table.sort(character.professionProjects, SortProjects)
            value.characters[characterID] = character
        end
    end
    self.value, self.dirty, self.nextTransitionAt = value, false, nextTransitionAt
    return value
end

function Snapshot:GetCharacter(id) return self:Build().characters[id] end
