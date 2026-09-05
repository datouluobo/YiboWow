local Addon = _G.YiboTodo
local Snapshot = { dirty = true }
Addon.Snapshot = Snapshot

function Snapshot:Invalidate() self.dirty = true end

function Snapshot:ScheduleTransitionRefresh(at)
    self.transitionAt = at
    if not (C_Timer and C_Timer.After and at and at > Addon:Now()) then return end
    local delay = math.max(0.1, at - Addon:Now() + 0.1)
    C_Timer.After(delay, function()
        if self.transitionAt == at and Addon:Now() >= at then
            self.dirty = true
            Addon:NotifyChanged()
        end
    end)
end

-- Keep the model usable by older SavedVariables and the isolated smoke-test
-- harnesses while the settings panel migrates to monitoring groups.
local function MonitoringItemEnabled(groupID, itemID, legacyKind, fallback)
    if Addon.Settings and type(Addon.Settings.IsMonitoringItemEnabled) == "function" then
        return Addon.Settings:IsMonitoringItemEnabled(groupID, itemID)
    end
    return not (Addon.Settings and Addon.Settings.GetMode and Addon.Settings:GetMode(legacyKind, itemID, fallback) == "hidden")
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

local function ProjectPriority(project)
    local priority = { ["ready-to-turn-in"] = 1, ["in-progress"] = 1, actionable = 2, estimated = 3, cooldown = 4, ["skill-insufficient"] = 5, unknown = 6 }
    return priority[project.state] or 99
end

local function SortProjects(left, right)
    local leftPriority, rightPriority = ProjectPriority(left), ProjectPriority(right)
    if leftPriority ~= rightPriority then return leftPriority < rightPriority end
    if (left.order or 999) ~= (right.order or 999) then return (left.order or 999) < (right.order or 999) end
    return tostring(left.groupID or "") < tostring(right.groupID or "")
end

local function SortDailyProjects(left, right)
    local leftPriority, rightPriority = ProjectPriority(left), ProjectPriority(right)
    if leftPriority ~= rightPriority then return leftPriority < rightPriority end
    if (left.order or 999) ~= (right.order or 999) then return (left.order or 999) < (right.order or 999) end
    return SortProjects(left, right)
end

local function BuildFarmProject(characterID, now)
    local provider = Addon.Providers.Registry:Get("farm-operation-observation")
    local day, eligibility, definition
    if provider then day, definition = provider:GetCurrentDay(characterID, now) end
    if not definition or not MonitoringItemEnabled("farm", definition.id, "activity", definition.defaultMode) then return nil, false end
    local operations = day and day.operations or {}
    local kinds = {}
    for _, operation in ipairs(operations) do kinds[operation.kind] = true end
    local previousDay
    if #operations == 0 and provider then previousDay = provider:GetLatestExpiredDay(characterID, now) end
    local previousKinds = {}
    for _, operation in ipairs(previousDay and previousDay.operations or {}) do previousKinds[operation.kind] = true end
    local plantedToday = kinds.till or kinds.plant or kinds.growing
    local harvestedToday = kinds.harvest
    -- Mouseover confirmation of a growing crop is also a reliable indication
    -- that the previous day's planting completed. It must project to today's
    -- harvest-ready state even when no till/plant cast was captured.
    local readyFromPreviousPlant = #operations == 0 and (previousKinds.till or previousKinds.plant or previousKinds.growing)
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
    if not definition or not MonitoringItemEnabled("nomi", definition.id, "activity", definition.defaultMode) then return nil, false end
    -- A historical Nomi completion establishes access to the repeatable
    -- content. Once the server day changes, that proof is enough to reset the
    -- group to actionable; the exact rotating lesson is still filled in when
    -- the quest log or Nomi gossip is observed.
    local eligibility = provider and provider:GetEligibility(characterID)
    local observedState = day and day.state
    local state = observedState and observedState ~= "unknown" and observedState
        or (eligibility and "actionable" or "unknown")
    local statusText
    if state == "ready-to-turn-in" or state == "in-progress" then statusText = "任务目标已完成，待交付"
    elseif state == "actionable" then statusText = observedState == "actionable" and "任务日志已确认，可处理" or "已满足诺米日常条件，今日已重置，可处理"
    elseif state == "completed" then statusText = "本服务器日已完成"
    elseif eligibility then statusText = "已满足诺米日常条件，等待今日任务日志确认"
    else statusText = "尚未在任务日志中确认当前诺米日常"
    end
    return {
        groupID = definition.id, label = definition.label, order = 1, state = state,
        iconKind = definition.iconItemID and "item" or "texture", icon = definition.iconItemID or definition.icon, fallbackIcon = definition.icon,
        observedAt = (day and day.observedAt) or (eligibility and eligibility.confirmedAt),
        nextResetAt = day and day.nextResetAt or Addon.Model.Schedule:NextResetAt(now, definition.resetHour),
        questID = day and day.questID, questKind = day and day.kind, dailyTaskLabel = day and day.label,
        eligibilityKnown = eligibility ~= nil,
        statusText = statusText, reason = day and day.reason,
        providerState = day and "available" or (eligibility and "available" or "not-yet-observed"),
    }, true
end

local function BuildCookingProject(characterID, characterLevel, now)
    local provider = Addon.Providers.Registry:Get("daily-quest")
    local definition = provider and provider:GetCookingDefinition()
    if not definition or not MonitoringItemEnabled("cooking-daily", definition.id, "activity", definition.defaultMode) then return nil, false end
    if (tonumber(characterLevel) or 0) < 90 then return nil, true end
    local day = provider:GetCurrentCookingDay(characterID, now)
    local previousDay = (not day or day.state == "unknown") and provider.GetLatestExpiredCookingDay
        and provider:GetLatestExpiredCookingDay(characterID, now) or nil
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
    local isCurrentCharacter = current and current.id == characterID
    local observedState = day and day.state
    local state = observedState and observedState ~= "unknown" and observedState
        or (previousDay and "actionable" or (isCurrentCharacter and "actionable" or "unknown"))
    local iconKind = definition.iconCurrencyID and "currency" or (definition.iconItemID and "item" or "texture")
    local icon = definition.iconCurrencyID or definition.iconItemID or definition.icon
    if not definition.iconCurrencyID and not definition.iconItemID then
        local core = Addon.Core
        local domain = core and core.DataDomains and core.DataDomains:Get(characterID, "professions")
        for _, profession in ipairs(domain and domain.data and domain.data.professions or {}) do
            if tonumber(profession.id) == 185 then icon = profession.icon or icon; break end
        end
    end
    return {
        groupID = definition.id, label = definition.label, order = 1, state = state,
        iconKind = iconKind, icon = icon, fallbackIcon = definition.icon,
        observedAt = day and day.observedAt,
        nextResetAt = day and day.nextResetAt or Addon.Model.Schedule:NextResetAt(now, definition.resetHour),
        dailyTaskLabel = day and day.label,
        statusText = (state == "ready-to-turn-in" or state == "in-progress") and "任务目标已完成，待交付"
            or state == "completed" and "本服务器日已完成"
            or observedState == "actionable" and "任务日志已确认，可处理"
            or "每日重置，可处理",
        providerState = observedState and observedState ~= "unknown" and "available"
            or (previousDay and "available" or (isCurrentCharacter and "available" or "not-yet-observed")),
    }, true
end

local function BuildLegacyDailyProject(characterID, definition, monitoringGroupID, now)
    if not MonitoringItemEnabled(monitoringGroupID, definition.id, "activity", definition.defaultMode) then return nil end
    local provider = Addon.Providers.Registry:Get("daily-quest")
    local day = provider and provider:GetCurrentActivityDay(characterID, definition.id, now)
    -- Legacy daily rotations have no tracked prerequisite, but a completely
    -- unobserved remote character must not be presented as reset after reload.
    -- A prior server-day record is the evidence that this activity is tracked.
    local previousDay = (not day or day.state == "unknown") and provider and provider.GetLatestExpiredActivityDay
        and provider:GetLatestExpiredActivityDay(characterID, definition.id, now) or nil
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
    local isCurrentCharacter = current and current.id == characterID
    local observedState = day and day.state
    local state = observedState and observedState ~= "unknown" and observedState
        or (previousDay and "actionable" or (isCurrentCharacter and "actionable" or "unknown"))
    local iconKind = definition.iconCurrencyID and "currency" or (definition.iconItemID and "item" or "texture")
    local icon = definition.iconCurrencyID or definition.iconItemID or definition.icon
    local statusText
    if state == "in-progress" then statusText = "任务目标已完成，待交付"
    elseif state == "actionable" then statusText = observedState == "actionable" and "任务日志已确认，可处理" or "每日重置，可处理"
    elseif state == "completed" then statusText = "本服务器日已完成"
    else statusText = "等待任务日志确认" end
    return {
        groupID = definition.id, monitoringGroupID = monitoringGroupID,
        label = definition.label, order = definition.order or 999,
        state = state, iconKind = iconKind, icon = icon, fallbackIcon = definition.icon,
        observedAt = day and day.observedAt,
        nextResetAt = day and day.nextResetAt or Addon.Model.Schedule:NextResetAt(now, definition.resetHour),
        questID = day and day.questID, dailyTaskLabel = day and day.label,
        statusText = statusText,
        providerState = observedState and observedState ~= "unknown" and "available"
            or (previousDay and "available" or (isCurrentCharacter and "available" or "not-yet-observed")), catalogPending = definition.verificationStatus == "needs-live-confirmation",
    }
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
            local character = { updatedAt = provider and provider.lastSuccessAt or 0, providerState = provider and provider.state or "not-yet-scanned", activities = {}, professionSlots = slots or {}, summary = { todo = 0, actionable = 0, cooldown = 0, items = {} }, monitoringProjects = {}, farmColumn = farmEnabled, farmProjects = farmProject and { farmProject } or {}, nomiColumn = nomiEnabled, nomiProjects = nomiProject and { nomiProject } or {}, cookingColumn = cookingEnabled, cookingProjects = cookingProject and { cookingProject } or {} }
            for groupID, group in pairs(Addon.Catalog.groups) do
                if slots and group.active and MonitoringItemEnabled("profession-cooldown", groupID, "cooldownGroup", group.defaultMode) then
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
                            activity.groupID, activity.monitoringGroupID, activity.slot, activity.label = groupID, "profession-cooldown", slot, builtGroup.label or groupID
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
                                    transitionAt = Addon.Model.Schedule:NextResetAt(value.builtAt, builtGroup.resetHour)
                                end
                                if transitionAt and transitionAt > value.builtAt
                                    and (not nextTransitionAt or transitionAt < nextTransitionAt) then
                                    nextTransitionAt = transitionAt
                                end
                            end
                        end
                    end
                    if slot then
                        if activity.state == "actionable" or activity.state == "in-progress" or activity.state == "ready-to-turn-in" then character.summary.todo = character.summary.todo + 1; character.summary.actionable = character.summary.actionable + 1; character.summary.items[#character.summary.items + 1] = group.label or groupID
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
            character.monitoringProjects["profession-cooldown"] = character.professionProjects
            character.monitoringProjects.farm = farmProject and { farmProject } or {}
            character.monitoringProjects.nomi = nomiProject and { nomiProject } or {}
            character.monitoringProjects["cooking-daily"] = cookingProject and { cookingProject } or {}
            if farmProject then farmProject.monitoringGroupID = "farm" end
            if nomiProject then nomiProject.monitoringGroupID = "nomi" end
            if cookingProject then cookingProject.monitoringGroupID = "cooking-daily" end
            for monitoringGroupID, monitoring in pairs(Addon.Catalog.monitoringGroups or {}) do
                if monitoring.memberKind == "daily-activity" then
                    local projects = character.monitoringProjects[monitoringGroupID] or {}
                    for _, activityID in ipairs(monitoring.members or {}) do
                        local definition = Addon.Catalog.dailyActivities[activityID]
                        local hasRequiredProfession = not definition or not definition.professionID
                        if definition and definition.professionID then
                            for slot = 1, 2 do
                                if slots and slots[slot] and slots[slot].id == tonumber(definition.professionID) then hasRequiredProfession = true; break end
                            end
                        end
                        if definition and hasRequiredProfession and definition.members and definition.id ~= "mop.halfhill.cooking-daily" then
                            local project = BuildLegacyDailyProject(characterID, definition, monitoringGroupID, now)
                            if project then projects[#projects + 1] = project end
                        end
                    end
                    table.sort(projects, SortDailyProjects)
                    character.monitoringProjects[monitoringGroupID] = projects
                end
            end
            value.characters[characterID] = character
        end
    end
    self.value, self.dirty, self.nextTransitionAt = value, false, nextTransitionAt
    self:ScheduleTransitionRefresh(nextTransitionAt)
    return value
end

function Snapshot:GetCharacter(id) return self:Build().characters[id] end
