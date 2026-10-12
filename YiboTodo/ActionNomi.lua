local Addon = _G.YiboTodo
local Action = { GROUP = "mop.nomi", PROVIDER = "YiboTodo:nomi",
    METADATA_KEY = "actionNomi" }
Addon.ActionNomi = Action

-- Reuse only envelope/version/cache operations. Each adapter owns its own
-- metadata and in-memory fields; Nomi's business state comes from its model.
Action.GetMetadata = Addon.ActionTodo.GetMetadata
Action.Commit = Addon.ActionTodo.Commit
Action.Query = Addon.ActionTodo.Query

function Action:DisplayGroups()
    local definition = Addon.Catalog.dailyActivities[self.GROUP]
    return definition and { { id = self.GROUP, title = definition.label or self.GROUP } } or {}
end

function Action:Project(characterID, snapshot, now, epoch, groupID, explicit)
    local definition = Addon.Catalog.dailyActivities[self.GROUP]
    local provider = Addon.Providers.Registry:Get("daily-quest")
    if not definition or not provider then
        return nil, { state = "unavailable", reason = "nomi-source-unavailable" }
    end
    if not explicit and not Addon.Settings:IsMonitoringItemEnabled("nomi", self.GROUP, "activity", definition.defaultMode) then
        return nil, { state = "known-empty", reason = "not-monitored" }
    end
    local project
    for _, entry in ipairs(snapshot and snapshot.nomiProjects or {}) do
        if entry.groupID == self.GROUP then project = entry; break end
    end
    if not project then return nil, { state = "partial", reason = "activity-unavailable" } end
    local observedAt = tonumber(project.observedAt)
    local nextReset = project.nextResetAt
    local freshness = observedAt and observedAt > 0 and "known" or "not-yet-scanned"
    local state, readiness, reason = "active", "unknown", Addon:T("ACTION.NOMI_UNKNOWN")
    if project.state == "actionable" then
        readiness, reason = "actionable", project.questID and Addon:T("ACTION.NOMI_READY") or Addon:T("ACTION.NOMI_ACCEPT")
    elseif project.state == "in-progress" or project.state == "ready-to-turn-in" then
        readiness, reason = "actionable", Addon:T("ACTION.NOMI_TURN_IN")
    elseif project.state == "completed" then
        state, readiness, reason = "completed", "not-applicable", Addon:T("ACTION.NOMI_DONE")
    else
        freshness = observedAt and observedAt > 0 and "partial" or "not-yet-scanned"
    end
    -- Historical repeatable eligibility remains valid by the source's own
    -- daily rule. Never replace its timestamp with query time or re-evaluate it.
    local key = characterID .. ":" .. self.GROUP
    local title = project.label or definition.label
    if project.dailyTaskLabel then title = title .. "·" .. project.dailyTaskLabel end
    local task = {
        itemKey = key,
        businessRef = { capability = "action.todo", providerID = self.PROVIDER, sourceEpoch = epoch, key = key },
        title = title, summary = project.statusText, reason = reason,
        displayGroup = { id = self.GROUP, title = definition.label or self.GROUP },
        execution = { mode = "self", characterID = characterID },
        beneficiary = { mode = "character", characterID = characterID },
        state = state, readiness = readiness, sourceState = project.state,
        questID = project.questID, questKind = project.questKind,
        temporal = { kind = "daily", cycleKey = Addon.Model.Schedule:ServerDay(now, definition.resetHour), nextChangeAt = nextReset },
        freshness = { state = freshness, observedAt = observedAt, validUntil = nextReset, clockSource = "server" },
        nextAction = { kind = "open-page", title = Addon:T("ACTION.OPEN_TODO"), pageID = "todo" },
        item = project.iconKind == "item" and { itemID = project.icon } or nil,
        icon = project.iconKind ~= "item" and (project.iconKind == "texture" and project.icon or project.fallbackIcon) or nil,
    }
    return task, { state = freshness, observedAt = observedAt, validUntil = nextReset,
        nextChangeAt = nextReset, clockSource = "server", reason = reason }
end
