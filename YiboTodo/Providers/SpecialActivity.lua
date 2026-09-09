local Addon = _G.YiboTodo
local Provider = { id = "special-activity", schemaVersion = 1 }

local function ServerDay(definition, now)
    return Addon.Model.Schedule:ServerDay(now, definition.resetHour or 7)
end

local function NextReset(definition, now)
    return Addon.Model.Schedule:NextResetAt(now, definition.resetHour or 7)
end

local function EventKey(now)
    return date and date("%Y-%W", now) or tostring(math.floor(now / 604800))
end

local function QuestInLog(questID)
    if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then return nil end
    local count = tonumber(GetNumQuestLogEntries()) or 0
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

local function IsDarkmoonOpen()
    if not (C_Calendar and type(C_Calendar.GetNumDayEvents) == "function" and type(C_Calendar.GetDayEvent) == "function") then return nil end
    local today = date and date("*t")
    if not today then return nil end
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, today.day)
    if not ok then return nil end
    for index = 1, tonumber(count) or 0 do
        local eventOK, event = pcall(C_Calendar.GetDayEvent, 0, today.day, index)
        local title = eventOK and event and string.lower(tostring(event.title or "")) or ""
        if string.find(title, "暗月", 1, true) or string.find(title, "darkmoon", 1, true) then return true end
    end
    return false
end

function Provider:ObserveCharacter(characterID)
    if not characterID then return false end
    local now, record = Addon:Now(), Addon.Database:GetProvider(characterID, self.id, true)
    record.days = record.days or {}
    for id, definition in pairs(Addon.Catalog.specialActivities or {}) do
        if definition.scope == "character" and definition.scheduleKind == "daily-07" then
            local days = record.days[id] or {}; record.days[id] = days
            local key, day = ServerDay(definition, now), nil
            day = days[key] or {}; days[key] = day
            local active = QuestInLog(definition.questID)
            day.observedAt, day.nextResetAt = now, NextReset(definition, now)
            if active ~= nil then day.state = active and "in-progress" or "actionable"
            elseif IsCompleted(definition.questID) then day.state, day.completedAt = "completed", now
            elseif day.state ~= "completed" then day.state = "actionable" end
        end
    end
    record.revision, record.lastSuccessAt, record.state = (tonumber(record.revision) or 0) + 1, now, "available"
    Addon:NotifyChanged()
    return true
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
                local key = definition.scheduleKind == "event-weekly" and EventKey(now) or ServerDay(definition, now)
                local days = record.days[id] or {}; record.days[id] = days
                local day = days[key] or {}; days[key] = day
                day.state, day.completedAt, day.observedAt, day.nextResetAt = "completed", now, now, NextReset(definition, now)
            end
            Addon:NotifyChanged()
            return true
        end
    end
    return false
end

function Provider:GetProject(characterID, definition, now)
    local iconKind = definition.iconItemID and "item" or "texture"
    local icon = definition.iconItemID or definition.icon
    if definition.scope == "account" then
        local stored = Addon.db.byAccount.specialActivities and Addon.db.byAccount.specialActivities[definition.id]
        local completed = stored and stored.serverDay == ServerDay(definition, now)
        local isOwner = completed and stored.completedByCharacterID == characterID
        return { groupID = definition.id, monitoringGroupID = definition.monitoringGroupID, label = definition.label, order = definition.order, state = completed and (isOwner and "completed" or "not-applicable") or "actionable", iconKind = iconKind, icon = icon, fallbackIcon = definition.icon, nextResetAt = completed and stored.nextResetAt or NextReset(definition, now), statusText = completed and (isOwner and "本账号今日已领取" or "本账号已由其它角色领取") or "本账号今日可领取" }
    end
    if definition.scheduleKind ~= "daily-07" then
        local open = IsDarkmoonOpen()
        local record = Addon.Database:GetProvider(characterID, self.id, false)
        local day = record and record.days and record.days[definition.id] and record.days[definition.id][EventKey(now)]
        return { groupID = definition.id, monitoringGroupID = definition.monitoringGroupID, label = definition.label, order = definition.order, state = day and day.state == "completed" and "completed" or (open == true and "actionable" or "unknown"), iconKind = iconKind, icon = icon, fallbackIcon = definition.icon, dailyTaskLabel = definition.taskLabel, statusText = day and day.state == "completed" and "本次暗月活动已完成" or open == true and "暗月马戏团正在开放" or open == false and "暗月马戏团当前未开放" or "等待暗月活动窗口状态确认" }
    end
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    local day = record and record.days and record.days[definition.id] and record.days[definition.id][ServerDay(definition, now)]
    return { groupID = definition.id, monitoringGroupID = definition.monitoringGroupID, label = definition.label, order = definition.order, state = day and day.state or "actionable", iconKind = iconKind, icon = icon, fallbackIcon = definition.icon, nextResetAt = day and day.nextResetAt or NextReset(definition, now), questID = definition.questID, statusText = day and day.state == "completed" and "本服务器日已完成" or "每日可完成" }
end

Addon.Providers.Registry:Register(Provider)
