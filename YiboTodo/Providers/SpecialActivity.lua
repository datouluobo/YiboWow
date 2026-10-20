local Addon = _G.YiboTodo
local Provider = { id = "special-activity", schemaVersion = 1 }

local function ServerDay(definition, now)
    return Addon.Model.Schedule:ServerDay(now, definition.resetHour or 7)
end

local function NextReset(definition, now)
    return Addon.Model.Schedule:NextResetAt(now, definition.resetHour or 7)
end

local EventPeriod = Addon.Darkmoon.EventPeriod
local EventObservation = Addon.Darkmoon.EventObservation
local IsDarkmoonOpen = Addon.Darkmoon.IsOpen

local function QuestInLog(questID)
    if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then return nil end
    -- GetNumQuestLogEntries may return a second value (for example, the
    -- number of quests). Capture only the entry count before converting it;
    -- otherwise Lua passes the second return value to tonumber as its base.
    local entryCount = GetNumQuestLogEntries()
    local count = tonumber(entryCount) or 0
    for index = 1, count do
        local _, _, _, header, _, complete, _, currentID = GetQuestLogTitle(index)
        if not header and tonumber(currentID) == tonumber(questID) then return complete == true or complete == 1 end
    end
    return nil
end

local function IsCompleted(questID)
    local query = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
    if type(query) ~= "function" then return false end
    local ok, value = pcall(query, questID)
    return ok and value == true
end

local function IsHolidayOpen(definition)
    if not (definition and C_Calendar and type(C_Calendar.GetNumDayEvents) == "function" and type(C_Calendar.GetDayEvent) == "function") then return false end
    local today = date and date("*t")
    if not today then return false end
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, today.day)
    if not ok then return false end
    for index = 1, tonumber(count) or 0 do
        local eventOK, event = pcall(C_Calendar.GetDayEvent, 0, today.day, index)
        local title = eventOK and event and string.lower(tostring(event.title or "")) or ""
        for _, alias in ipairs(definition.eventTitleAliases or {}) do
            if title == string.lower(tostring(alias)) then return true end
        end
    end
    return false
end

local function IsRegistered(definition)
    return definition and definition.registrationStatus ~= "pending-client-verification"
end

local function ActivityLabel(definition)
    if definition and definition.monitoringGroupID == "nat-pagle" and definition.iconItemID then
        return Addon:GetLocalizedGameName("item", definition.iconItemID, definition.label)
    end
    return definition and definition.label
end

local function ActivityTaskLabel(definition)
    return definition and Addon:GetLocalizedGameName("quest", definition.questID, definition.taskLabel)
end

function Provider:ObserveCharacter(characterID)
    if not characterID then return false end
    local now, record = Addon:Now(), Addon.Database:GetProvider(characterID, self.id, true)
    record.days = record.days or {}
    local changed = record.state ~= "available"
    for id, definition in pairs(Addon.Catalog.specialActivities or {}) do
        if definition.scope == "character" and (definition.scheduleKind == "daily-07" or (definition.scheduleKind == "event-daily-07" and IsRegistered(definition) and IsHolidayOpen(definition))) then
            local days = record.days[id] or {}; record.days[id] = days
            local key, day = ServerDay(definition, now), nil
            day = days[key] or {}; days[key] = day
            local previous = day.state
            local active = QuestInLog(definition.questID)
            if active ~= nil then day.state = active and "in-progress" or "actionable"
            elseif IsCompleted(definition.questID) then
                day.state = "completed"
                if previous ~= "completed" then day.completedAt = now end
            elseif day.state ~= "completed" then day.state = "actionable" end
            if previous ~= day.state or not day.observedAt then
                day.observedAt, day.nextResetAt = now, NextReset(definition, now)
                changed = true
            end
        end
    end
    if not changed then return false end
    record.revision, record.lastSuccessAt, record.state = (tonumber(record.revision) or 0) + 1, now, "available"
    Addon:NotifyChanged()
    return true
end

function Provider:RecordLoot(characterID, message, recipient)
    if not characterID or type(message) ~= "string" then return false end
    local itemID = tonumber(string.match(message, "item:(%d+)"))
    if not itemID then return false end
    local currentName = UnitName and UnitName("player")
    local recipientName = type(recipient) == "string" and string.match(recipient, "^([^%-]+)") or recipient
    if recipientName and currentName and recipientName ~= currentName then return false end
    for id, definition in pairs(Addon.Catalog.specialActivities or {}) do
        if definition.scheduleKind == "event-daily-07" and IsRegistered(definition) and IsHolidayOpen(definition) then
            for _, rewardID in ipairs(definition.rewardItemIDs or {}) do
                if tonumber(rewardID) == itemID then
                    local now, record = Addon:Now(), Addon.Database:GetProvider(characterID, self.id, true)
                    record.days = record.days or {}
                    local days = record.days[id] or {}; record.days[id] = days
                    local key, day = ServerDay(definition, now), days[ServerDay(definition, now)] or {}
                    days[key] = day
                    day.state, day.completedAt, day.observedAt, day.nextResetAt = "completed", now, now, NextReset(definition, now)
                    Addon:NotifyChanged()
                    return true
                end
            end
        end
    end
    return false
end

function Provider:RecordTurnIn(characterID, questID)
    local now = Addon:Now()
    for id, definition in pairs(Addon.Catalog.specialActivities or {}) do
        local matches = tonumber(definition.questID) == tonumber(questID)
        for _, candidate in ipairs(definition.questIDs or {}) do if tonumber(candidate) == tonumber(questID) then matches = true; break end end
        if matches then
            if definition.scope == "account" then
                local account = Addon.db.byAccount.specialActivities or {}; Addon.db.byAccount.specialActivities = account
                account[id] = { state = "completed", serverDay = ServerDay(definition, now), completedAt = now, completedByCharacterID = characterID, nextResetAt = NextReset(definition, now) }
            else
                local record = Addon.Database:GetProvider(characterID, self.id, true)
                record.days = record.days or {}
                local key, resetAt
                if definition.scheduleKind == "event-weekly" then
                    local startAt
                    key, startAt, resetAt = EventPeriod(now)
                else key, resetAt = ServerDay(definition, now), NextReset(definition, now) end
                local days = record.days[id] or {}; record.days[id] = days
                local day = days[key] or {}; days[key] = day
                day.state, day.completedAt, day.observedAt, day.nextResetAt = "completed", now, now, resetAt
            end
            Addon:NotifyChanged()
            return true
        end
    end
    return false
end

function Provider:BuildProject(characterID, definition, now)
    local iconKind = definition.iconItemID and "item" or "texture"
    local icon = definition.iconItemID or definition.icon
    if definition.scope == "account" then
        local stored = Addon.db.byAccount.specialActivities and Addon.db.byAccount.specialActivities[definition.id]
        local completed = stored and stored.serverDay == ServerDay(definition, now)
        local isOwner = completed and stored.completedByCharacterID == characterID
        return { groupID = definition.id, monitoringGroupID = definition.monitoringGroupID, label = ActivityLabel(definition), order = definition.order, state = completed and (isOwner and "completed" or "not-applicable") or "actionable", iconKind = iconKind, icon = icon, fallbackIcon = definition.icon, nextResetAt = completed and stored.nextResetAt or NextReset(definition, now), statusText = completed and (isOwner and Addon:T("STATUS.ACCOUNT_CLAIMED") or Addon:T("STATUS.OTHER_CLAIMED")) or Addon:T("STATUS.ACCOUNT_AVAILABLE") }
    end
    if definition.scheduleKind == "event-daily-07" then
        if not IsRegistered(definition) or not IsHolidayOpen(definition) then return nil end
        local record = Addon.Database:GetProvider(characterID, self.id, false)
        local day = record and record.days and record.days[definition.id] and record.days[definition.id][ServerDay(definition, now)]
        local completed = day and day.state == "completed"
        return { groupID = definition.id, monitoringGroupID = definition.monitoringGroupID, label = ActivityLabel(definition), order = definition.order, state = completed and "completed" or "actionable", iconKind = iconKind, icon = icon, fallbackIcon = definition.icon, nextResetAt = NextReset(definition, now), questID = definition.questID, observedAt = day and day.observedAt, statusText = completed and Addon:T("STATUS.HOLIDAY_CLAIMED") or (day and day.observedAt and Addon:T("STATUS.HOLIDAY_NOT_CLAIMED") or Addon:T("STATUS.CLAIM_UNOBSERVED")) }
    end
    if definition.scheduleKind ~= "daily-07" then
        local open = IsDarkmoonOpen(now)
        -- The fair is not a pending/unknown daily. Outside its confirmed
        -- window the whole monitoring group must disappear, rather than
        -- leaving a column of question-mark placeholders.
        if open ~= true then return nil end
        local record = Addon.Database:GetProvider(characterID, self.id, false)
        local day = EventObservation(record, definition, now)
        return { groupID = definition.id, monitoringGroupID = definition.monitoringGroupID, label = ActivityLabel(definition), order = definition.order, state = day and day.state == "completed" and "completed" or "actionable", iconKind = iconKind, icon = icon, fallbackIcon = definition.icon, dailyTaskLabel = ActivityTaskLabel(definition), statusText = day and day.state == "completed" and Addon:T("STATUS.DARKMOON_DONE") or Addon:T("STATUS.DARKMOON_OPEN") }
    end
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    local day = record and record.days and record.days[definition.id] and record.days[definition.id][ServerDay(definition, now)]
    return { groupID = definition.id, monitoringGroupID = definition.monitoringGroupID, label = ActivityLabel(definition), order = definition.order, state = day and day.state or "actionable", iconKind = iconKind, icon = icon, fallbackIcon = definition.icon, nextResetAt = day and day.nextResetAt or NextReset(definition, now), questID = definition.questID, statusText = day and day.state == "completed" and Addon:T("STATUS.DAILY_DONE") or Addon:T("STATUS.DAILY_AVAILABLE") }
end

-- Publish source-owned period/scope metadata alongside the same view model.
function Provider:GetProject(characterID, definition, now)
    local project = self:BuildProject(characterID, definition, now)
    if not project then return nil end
    project.scope = definition.scope
    project.period = definition.scheduleKind == "event-weekly" and "weekly" or "daily"
    if definition.scheduleKind == "event-weekly" then
        local key, _, resetAt = EventPeriod(now)
        project.cycleKey, project.nextResetAt = key, resetAt
    else project.cycleKey = ServerDay(definition, now) end
    -- Re-evaluate calendar visibility at midnight as well as the source reset.
    project.nextChangeAt = definition.scheduleKind == "event-weekly"
        and math.min(Addon.Model.Schedule:NextResetAt(now, 0), project.nextResetAt) or project.nextResetAt
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    local day = record and record.days and record.days[definition.id] and record.days[definition.id][project.cycleKey]
    if definition.scheduleKind == "event-weekly" then day = EventObservation(record, definition, now) end
    local account = definition.scope == "account" and Addon.db.byAccount.specialActivities and Addon.db.byAccount.specialActivities[definition.id]
    project.observedAt = day and day.observedAt or (account and account.serverDay == project.cycleKey and account.completedAt) or nil
    return project
end

-- Exact goals need to distinguish a closed event from missing observations.
-- Normal Todo views keep using GetProject and omit the closed event entirely.
function Provider:GetTargetProject(characterID, definition, now)
    local project = self:GetProject(characterID, definition, now)
    if project then return project end
    if definition.scheduleKind == "event-weekly" and IsDarkmoonOpen(now) == false then
        return { groupID = definition.id, label = ActivityLabel(definition), state = "not-applicable",
            scope = definition.scope, period = "weekly", cycleKey = EventPeriod(now),
            nextChangeAt = Addon.Model.Schedule:NextResetAt(now, 0), statusText = Addon:T("STATUS.ACTIVITY_CLOSED") }
    end
end

Addon.Providers.Registry:Register(Provider)
