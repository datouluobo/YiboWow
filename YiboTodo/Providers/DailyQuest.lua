local Addon = _G.YiboTodo
local Registry = Addon.Providers.Registry
local Provider = { id = "daily-quest", schemaVersion = 1, queued = {} }

local function IsComplete(value)
    return value == true or value == 1
end

local function FindQuest(definition, questID)
    questID = tonumber(questID)
    for _, item in ipairs(definition.stages or {}) do if tonumber(item.questID) == questID then return item, "lesson" end end
    if definition.graduation and tonumber(definition.graduation.questID) == questID then return definition.graduation, "graduation" end
    if definition.daily and tonumber(definition.daily.questID) == questID then return definition.daily, "daily" end
end

local function ActiveQuest(definition)
    if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then return nil, "quest-log-unavailable" end
    for index = 1, tonumber(GetNumQuestLogEntries()) or 0 do
        local _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(index)
        if not isHeader then
            local item, kind = FindQuest(definition, questID)
            if item then return { item = item, kind = kind, complete = IsComplete(isComplete) } end
        end
    end
    return nil, "no-tracked-quest-in-log"
end

function Provider:GetDefinition()
    return Addon.Catalog.dailyActivities and Addon.Catalog.dailyActivities["mop.nomi"]
end

function Provider:GetCurrentDay(characterID, now)
    local definition = self:GetDefinition()
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    if not (definition and record and record.days) then return nil, definition end
    return record.days[Addon.Model.Schedule:ServerDay(now, definition.resetHour)], definition
end

local function IsRepeatableNomiDaily(kind)
    return kind == "lesson" or kind == "daily"
end

local function MarkEligible(record, item, kind, now)
    if not IsRepeatableNomiDaily(kind) then return false end
    record.nomiEligible = record.nomiEligible or { confirmedAt = now, questID = item.questID, kind = kind }
    return true
end

function Provider:GetEligibility(characterID)
    local definition = self:GetDefinition()
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    if not (definition and record) then return nil, definition end
    if record.nomiEligible then return record.nomiEligible, definition end
    -- Adopt observations collected before this permanent eligibility marker
    -- was introduced. Graduation is intentionally excluded: only a completed
    -- repeating lesson or the final daily proves ongoing access.
    for _, day in pairs(record.days or {}) do
        if day.state == "completed" and IsRepeatableNomiDaily(day.kind) then
            return { confirmedAt = day.completedAt or day.observedAt, questID = day.questID, kind = day.kind, legacy = true }, definition
        end
    end
    return nil, definition
end

function Provider:Observe(characterID)
    local definition = self:GetDefinition()
    if not definition or not characterID then return false, "missing-definition-or-character" end
    local now = Addon:Now()
    local dayKey = Addon.Model.Schedule:ServerDay(now, definition.resetHour)
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    record.days = record.days or {}
    local day = record.days[dayKey] or {}
    record.days[dayKey] = day
    local active, reason = ActiveQuest(definition)
    day.observedAt, day.nextResetAt = now, Addon.Model.Schedule:NextResetAt(now, definition.resetHour)
    if active then
        day.questID, day.label, day.kind = active.item.questID, active.item.label, active.kind
        day.state = active.complete and "completed" or "actionable"
        if active.complete then day.completedAt = now end
    elseif day.state ~= "completed" then
        day.state, day.reason = "unknown", reason
        day.questID, day.label, day.kind = nil, nil, nil
    end
    record.revision = (tonumber(record.revision) or 0) + 1
    record.providerVersion, record.catalogVersion, record.rulesetID = self.schemaVersion, Addon.CATALOG_VERSION, Addon.RULESET_ID
    record.lastAttemptAt, record.lastSuccessAt, record.state, record.errorCode = now, now, "available", nil
    Addon:NotifyChanged()
    return true, day.state
end

function Provider:RecordTurnIn(characterID, questID)
    local definition = self:GetDefinition()
    local item, kind
    if definition then item, kind = FindQuest(definition, questID) end
    if not item or not characterID then return false, "untracked-quest" end
    local now = Addon:Now()
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    record.days = record.days or {}
    local dayKey = Addon.Model.Schedule:ServerDay(now, definition.resetHour)
    local day = record.days[dayKey] or {}
    record.days[dayKey] = day
    day.questID, day.label, day.kind, day.state = item.questID, item.label, kind, "completed"
    day.observedAt, day.completedAt, day.nextResetAt = now, now, Addon.Model.Schedule:NextResetAt(now, definition.resetHour)
    MarkEligible(record, item, kind, now)
    record.revision = (tonumber(record.revision) or 0) + 1
    record.lastAttemptAt, record.lastSuccessAt, record.state, record.errorCode = now, now, "available", nil
    Addon:NotifyChanged()
    return true
end

function Provider:QueueObserve()
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
    local characterID = current and current.id
    if not characterID or self.queued[characterID] then return end
    self.queued[characterID] = true
    local function Run()
        self.queued[characterID] = nil
        local active = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        if active and active.id == characterID then self:Observe(characterID) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, Run) else Run() end
end

Registry:Register(Provider)
