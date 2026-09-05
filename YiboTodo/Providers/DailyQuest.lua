local Addon = _G.YiboTodo
local Registry = Addon.Providers.Registry
local Provider = { id = "daily-quest", schemaVersion = 1, queued = {} }
local NOMI_NPC_ID = 64337

local function IsComplete(value)
    return value == true or value == 1
end

local function IsQuestLogComplete(questID, legacyValue)
    -- Some Classic clients expose an unreliable completion slot through
    -- GetQuestLogTitle while C_QuestLog.IsComplete is current. Prefer the
    -- quest-ID based API so an objective-complete quest remains visibly ready
    -- to turn in, then retain the legacy tuple as a compatibility fallback.
    local query = C_QuestLog and C_QuestLog.IsComplete
    if type(query) == "function" then
        local ok, complete = pcall(query, questID)
        if ok and complete ~= nil then return IsComplete(complete) end
    end
    return IsComplete(legacyValue)
end

local function FindQuest(definition, questID)
    questID = tonumber(questID)
    local function Matches(item)
        return questID ~= nil and tonumber(item.questID) == questID
    end
    for _, item in ipairs(definition.stages or {}) do if Matches(item) then return item, "lesson" end end
    if definition.graduation and Matches(definition.graduation) then return definition.graduation, "graduation" end
    if definition.daily and Matches(definition.daily) then return definition.daily, "daily" end
    for _, item in ipairs(definition.members or {}) do if Matches(item) then return item, "member" end end
end

local function QuestLogEntry(index)
    -- The structured API is authoritative on modern clients.  In particular,
    -- it avoids relying on positional return values from GetQuestLogTitle,
    -- whose completion field differs across supported Classic builds.
    if C_QuestLog and type(C_QuestLog.GetInfo) == "function" then
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        if ok and type(info) == "table" and info.questID then
            return info.isHeader, info.isComplete, info.questID, info.title
        end
    end
    if type(GetQuestLogTitle) ~= "function" then return nil end
    local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(index)
    return isHeader, isComplete, questID, title
end

local function ActiveQuest(definition)
    if type(GetNumQuestLogEntries) ~= "function" then return nil, "quest-log-unavailable" end
    for index = 1, tonumber(GetNumQuestLogEntries()) or 0 do
        local isHeader, isComplete, questID, title = QuestLogEntry(index)
        if not isHeader then
            local item, kind = FindQuest(definition, questID)
            if item then return { item = item, kind = kind, complete = IsQuestLogComplete(questID, isComplete) } end
        end
    end
    return nil, "no-tracked-quest-in-log"
end

local function AlreadyHandedIn(day, active)
    return day and day.state == "completed" and active and active.item
        and tonumber(day.questID) == tonumber(active.item.questID)
end

local function CreatureID(unit)
    if type(UnitGUID) ~= "function" then return nil end
    local guid = UnitGUID(unit)
    return guid and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")) or nil
end

local function IsNomiInteraction()
    -- GOSSIP_SHOW has no NPC argument.  The target remains available for the
    -- normal click-to-talk flow, while npc covers clients that expose it.
    return CreatureID("npc") == NOMI_NPC_ID or CreatureID("target") == NOMI_NPC_ID
end

local function AvailableNomiQuest(definition)
    if not (C_GossipInfo and type(C_GossipInfo.GetAvailableQuests) == "function") then return nil, "gossip-api-unavailable" end
    local ok, quests = pcall(C_GossipInfo.GetAvailableQuests)
    if not ok or type(quests) ~= "table" then return nil, "gossip-api-unavailable" end
    for _, quest in ipairs(quests) do
        local item, kind = FindQuest(definition, quest and quest.questID)
        if item then return { item = item, kind = kind }, "tracked-quest-offered" end
    end
    return nil, "no-tracked-quest-offered"
end

function Provider:GetDefinition()
    return Addon.Catalog.dailyActivities and Addon.Catalog.dailyActivities["mop.nomi"]
end

function Provider:GetCookingDefinition()
    return Addon.Catalog.dailyActivities and Addon.Catalog.dailyActivities["mop.halfhill.cooking-daily"]
end

function Provider:GetCurrentDay(characterID, now)
    local definition = self:GetDefinition()
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    if not (definition and record and record.days) then return nil, definition end
    return record.days[Addon.Model.Schedule:ServerDay(now, definition.resetHour)], definition
end

function Provider:GetCurrentCookingDay(characterID, now)
    local definition = self:GetCookingDefinition()
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    if not (definition and record and record.cookingDays) then return nil, definition end
    return record.cookingDays[Addon.Model.Schedule:ServerDay(now, definition.resetHour)], definition
end

function Provider:GetCurrentActivityDay(characterID, activityID, now)
    local definition = Addon.Catalog.dailyActivities and Addon.Catalog.dailyActivities[activityID]
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    if not (definition and record and record.activityDays) then return nil, definition end
    local days = record.activityDays[activityID]
    return days and days[Addon.Model.Schedule:ServerDay(now, definition.resetHour)], definition
end

local function LatestExpiredDay(days, currentKey)
    local latestKey, latest
    for dayKey, day in pairs(days or {}) do
        if tostring(dayKey) < tostring(currentKey) and (not latestKey or tostring(dayKey) > latestKey) then
            latestKey, latest = tostring(dayKey), day
        end
    end
    return latest
end

function Provider:GetLatestExpiredCookingDay(characterID, now)
    local definition = self:GetCookingDefinition()
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    if not (definition and record and record.cookingDays) then return nil, definition end
    return LatestExpiredDay(record.cookingDays, Addon.Model.Schedule:ServerDay(now, definition.resetHour)), definition
end

function Provider:GetLatestExpiredActivityDay(characterID, activityID, now)
    local definition = Addon.Catalog.dailyActivities and Addon.Catalog.dailyActivities[activityID]
    local record = Addon.Database:GetProvider(characterID, self.id, false)
    local days = record and record.activityDays and record.activityDays[activityID]
    if not (definition and days) then return nil, definition end
    return LatestExpiredDay(days, Addon.Model.Schedule:ServerDay(now, definition.resetHour)), definition
end

function Provider:ObserveActivity(characterID, definition)
    if not (characterID and definition and definition.members) then return false end
    local now = Addon:Now()
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    record.activityDays = record.activityDays or {}
    local days = record.activityDays[definition.id] or {}; record.activityDays[definition.id] = days
    local dayKey = Addon.Model.Schedule:ServerDay(now, definition.resetHour)
    local day = days[dayKey] or {}; days[dayKey] = day
    local active, reason = ActiveQuest(definition)
    day.observedAt, day.nextResetAt = now, Addon.Model.Schedule:NextResetAt(now, definition.resetHour)
    if active and not AlreadyHandedIn(day, active) then
        day.questID, day.label, day.kind = active.item.questID, active.item.label, active.kind
        day.state = active.complete and "in-progress" or "actionable"
    elseif not active and day.state ~= "completed" and day.state ~= "in-progress" then
        day.state, day.reason = "unknown", reason
    end
    record.revision = (tonumber(record.revision) or 0) + 1
    record.lastAttemptAt, record.lastSuccessAt, record.state, record.errorCode = now, now, "available", nil
    return true, day.state
end

local function IsLegacyActivity(definition)
    return definition and definition.members and definition.id ~= "mop.halfhill.cooking-daily"
end

function Provider:ObserveLegacyActivities(characterID)
    local observed = 0
    for _, definition in pairs(Addon.Catalog.dailyActivities or {}) do
        if IsLegacyActivity(definition) then
            local ok = self:ObserveActivity(characterID, definition)
            if ok then observed = observed + 1 end
        end
    end
    return observed > 0, observed
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
        if not AlreadyHandedIn(day, active) then
            day.questID, day.label, day.kind = active.item.questID, active.item.label, active.kind
            -- The quest is still in the log at this point, so its objectives
            -- are done but the player has not handed it in yet.
            day.state = active.complete and "in-progress" or "actionable"
            if active.complete then day.readyToTurnInAt = now end
        end
    elseif day.state == "ready-to-turn-in" or day.state == "in-progress" then
        -- A transient quest-log refresh must not hide a quest that still
        -- needs to be handed in.
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

local function IsQuestCompleted(questID)
    local query = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
    if type(query) ~= "function" then return nil end
    local ok, completed = pcall(query, questID)
    return ok and completed == true or false
end

function Provider:ObserveLegacyCompletions(characterID)
    if not characterID then return false, "missing-character" end
    -- QUEST_TURNED_IN is not consistently emitted for the legacy dailies on
    -- every supported client.  Their daily completion flags persist through
    -- hand-in, so reconcile the cached in-progress state on each log refresh.
    for _, definition in pairs(Addon.Catalog.dailyActivities or {}) do
        if IsLegacyActivity(definition) then
            local day = self:GetCurrentActivityDay(characterID, definition.id)
            if not (day and day.state == "completed") then
                for _, item in ipairs(definition.members or {}) do
                    if IsQuestCompleted(item.questID) then
                        return self:RecordTurnIn(characterID, item.questID)
                    end
                end
            end
        end
    end
    return false, "no-candidate-daily-completion"
end

function Provider:ObserveNomiCompletion(characterID)
    if not characterID then return false, "missing-character" end
    local definition = self:GetDefinition()
    if not definition then return false, "missing-definition" end
    local day = self:GetCurrentDay(characterID)
    -- A successful reconciliation is persisted on the current server day.
    -- Do not query completion flags again when the player retargets Nomi.
    if day and day.state == "completed" then return true, "already-reconciled" end

    -- The completed-quest flag survives handing in the quest (and daily flags
    -- reset with the server day), unlike the very brief completed-in-log state.
    -- It is therefore the authoritative post-turn-in check.
    for _, item in ipairs(definition.stages or {}) do
        if IsQuestCompleted(item.questID) then
            local day = self:GetCurrentDay(characterID)
            if day and day.state == "completed" and day.questID == item.questID then return true, "already-recorded" end
            return self:RecordTurnIn(characterID, item.questID)
        end
    end
    if definition.daily and IsQuestCompleted(definition.daily.questID) then
        local day = self:GetCurrentDay(characterID)
        if day and day.state == "completed" and day.questID == definition.daily.questID then return true, "already-recorded" end
        return self:RecordTurnIn(characterID, definition.daily.questID)
    end
    return false, "no-nomi-daily-completion"
end

function Provider:ObserveCookingCompletion(characterID)
    if not characterID then return false, "missing-character" end
    local definition = self:GetCookingDefinition()
    if not definition then return false, "missing-definition" end
    local day = self:GetCurrentCookingDay(characterID)
    -- One successful cooking turn-in completes the shared daily group.  Its
    -- saved state is the per-server-day cache for target-based reconciliation.
    if day and day.state == "completed" then return true, "already-reconciled" end
    local targetID = CreatureID("target")
    if not targetID then return false, "not-cooking-target" end
    for _, item in ipairs(definition.members or {}) do
        if tonumber(item.turnInNPCID) == targetID then
            if IsQuestCompleted(item.questID) then return self:RecordTurnIn(characterID, item.questID) end
            return false, "not-completed"
        end
    end
    return false, "not-cooking-target"
end

function Provider:ObserveNomiTarget(characterID)
    if CreatureID("target") ~= NOMI_NPC_ID then return false, "not-nomi-target" end
    return self:ObserveNomiCompletion(characterID)
end

function Provider:ObserveTargetCompletion(characterID)
    local completed = self:ObserveNomiTarget(characterID)
    if completed then return true, "nomi" end
    return self:ObserveCookingCompletion(characterID)
end

function Provider:RecordTurnIn(characterID, questID)
    local definition = self:GetDefinition()
    local item, kind
    if definition then item, kind = FindQuest(definition, questID) end
    local cooking = self:GetCookingDefinition()
    if not item and cooking then
        item, kind = FindQuest(cooking, questID)
        if item then definition = cooking end
    end
    if not item then
        for _, activity in pairs(Addon.Catalog.dailyActivities or {}) do
            if IsLegacyActivity(activity) then
                local found, foundKind = FindQuest(activity, questID)
                if found then item, kind, definition = found, foundKind, activity; break end
            end
        end
    end
    if not item or not characterID then return false, "untracked-quest" end
    local now = Addon:Now()
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    local dayKey = Addon.Model.Schedule:ServerDay(now, definition.resetHour)
    local days
    if definition == cooking then days = record.cookingDays or {}; record.cookingDays = days
    elseif IsLegacyActivity(definition) then
        record.activityDays = record.activityDays or {}; days = record.activityDays[definition.id] or {}; record.activityDays[definition.id] = days
    else days = record.days or {}; record.days = days end
    local day = days[dayKey] or {}
    days[dayKey] = day
    day.questID, day.label, day.kind, day.state = item.questID, item.label, kind, "completed"
    day.observedAt, day.completedAt, day.nextResetAt = now, now, Addon.Model.Schedule:NextResetAt(now, definition.resetHour)
    if definition == self:GetDefinition() then MarkEligible(record, item, kind, now) end
    record.revision = (tonumber(record.revision) or 0) + 1
    record.lastAttemptAt, record.lastSuccessAt, record.state, record.errorCode = now, now, "available", nil
    Addon:NotifyChanged()
    return true
end

function Provider:ObserveCooking(characterID)
    local definition = self:GetCookingDefinition()
    if not definition or not characterID then return false, "missing-definition-or-character" end
    local now = Addon:Now()
    local dayKey = Addon.Model.Schedule:ServerDay(now, definition.resetHour)
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    record.cookingDays = record.cookingDays or {}
    local day = record.cookingDays[dayKey] or {}
    record.cookingDays[dayKey] = day
    local active, reason = ActiveQuest(definition)
    day.observedAt, day.nextResetAt = now, Addon.Model.Schedule:NextResetAt(now, definition.resetHour)
    if active then
        if not AlreadyHandedIn(day, active) then
            day.questID, day.label, day.kind = active.item.questID, active.item.label, active.kind
            -- Keep the visible distinction between a completed objective and
            -- a completed daily: only QUEST_TURNED_IN calls RecordTurnIn.
            day.state = active.complete and "in-progress" or "actionable"
            if active.complete then day.readyToTurnInAt = now end
        end
    elseif day.state == "ready-to-turn-in" or day.state == "in-progress" then
        -- A ready-to-turn-in quest may not appear in GetAvailableQuests.
        -- Do not turn that absence into a false hand-in confirmation.
    elseif day.state ~= "completed" then
        day.state, day.reason = "actionable", reason
    end
    record.revision = (tonumber(record.revision) or 0) + 1
    record.providerVersion, record.catalogVersion, record.rulesetID = self.schemaVersion, Addon.CATALOG_VERSION, Addon.RULESET_ID
    record.lastAttemptAt, record.lastSuccessAt, record.state, record.errorCode = now, now, "available", nil
    Addon:NotifyChanged()
    return true, day.state
end

function Provider:ObserveNomiGossip(characterID)
    local definition = self:GetDefinition()
    if not (definition and characterID and IsNomiInteraction()) then return false, "not-nomi" end
    local now = Addon:Now()
    local record = Addon.Database:GetProvider(characterID, self.id, true)
    record.days = record.days or {}
    local dayKey = Addon.Model.Schedule:ServerDay(now, definition.resetHour)
    local day = record.days[dayKey] or {}
    record.days[dayKey] = day
    local offered, reason = AvailableNomiQuest(definition)
    day.observedAt, day.nextResetAt = now, Addon.Model.Schedule:NextResetAt(now, definition.resetHour)
    if offered then
        day.questID, day.label, day.kind, day.state = offered.item.questID, offered.item.label, offered.kind, "actionable"
        day.reason = reason
    elseif day.state == "ready-to-turn-in" or day.state == "in-progress" then
        -- The available-quest list excludes a quest waiting to be handed in.
    elseif day.state ~= "completed" and self:GetEligibility(characterID) then
        -- The gossip list is authoritative only while talking to Nomi.  For a
        -- character that has already proven repeatable Nomi access, no offered
        -- tracked daily at that moment means today's daily was already done.
        day.state, day.reason = "completed", reason
        day.completedAt = now
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

function Provider:QueueObserve()
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
    local characterID = current and current.id
    if not characterID or self.queued[characterID] then return end
    self.queued[characterID] = true
    local function Run()
        self.queued[characterID] = nil
        local active = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        if active and active.id == characterID then
            self:Observe(characterID)
            self:ObserveCooking(characterID)
            self:ObserveLegacyActivities(characterID)
            self:ObserveLegacyCompletions(characterID)
            self:ObserveNomiCompletion(characterID)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, Run) else Run() end
end

Registry:Register(Provider)
