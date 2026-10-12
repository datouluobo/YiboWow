local Addon = _G.YiboTodo
local Action = { PROVIDER = "YiboTodo:activities", METADATA_KEY = "actionActivities", SOURCE_TITLE = "日常与活动" }
Addon.ActionActivities = Action
Action.GetMetadata = Addon.ActionTodo.GetMetadata
Action.Commit = Addon.ActionTodo.Commit

function Action:DisplayGroups()
    local groups = {}
    for id in pairs(Addon.Catalog.monitoringGroups or {}) do
        if id ~= "profession-cooldown" and id ~= "nomi" and Addon.Settings.GetMonitoringItems then
            for _, item in ipairs(Addon.Settings:GetMonitoringItems(id)) do groups[#groups + 1] = { id = item.id, title = item.label } end
        end
    end
    table.sort(groups, function(a, b) return a.id < b.id end)
    return groups
end

-- Consume the same monitored, eligible projects as the Todo account view.
-- Cooldowns and Nomi retain their existing source identities.
function Action:ProjectAll(characterID, snapshot, now, epoch, explicit)
    local tasks, coverage, groups = {}, { state = "known-empty" }, {}
    for id in pairs(snapshot and snapshot.monitoringProjects or {}) do groups[#groups + 1] = id end
    table.sort(groups)
    for _, id in ipairs(groups) do
        if id ~= "profession-cooldown" and id ~= "nomi" then
            for _, project in ipairs(snapshot.monitoringProjects[id]) do
                if (project.state ~= "not-applicable" or explicit) and project.state ~= "locked" then
                    local completed = project.state == "completed"
                    local inactive = project.state == "not-applicable"
                    local ready = project.state == "actionable" or project.state == "in-progress" or project.state == "ready-to-turn-in"
                    local fresh = (ready or completed or inactive) and "known" or "partial"
                    local key = (project.scope == "account" and "account" or characterID) .. ":" .. project.groupID
                    local title = project.label or project.groupID
                    if project.dailyTaskLabel then title = title .. "·" .. project.dailyTaskLabel end
                    local at = project.nextChangeAt or project.nextResetAt
                    local task = {
                        itemKey = key,
                        businessRef = { capability = "action.todo", providerID = self.PROVIDER, sourceEpoch = epoch, key = key },
                        title = title, summary = project.statusText, reason = project.statusText,
                        displayGroup = { id = project.groupID, title = project.label or project.groupID },
                        state = completed and "completed" or "active", readiness = (completed or inactive) and "not-applicable" or (ready and "actionable" or "unknown"),
                        sourceState = project.state, questID = project.questID,
                        execution = { mode = "self", characterID = characterID },
                        beneficiary = { mode = "character", characterID = characterID },
                        temporal = { kind = project.period or "daily", cycleKey = project.cycleKey or Addon.Model.Schedule:ServerDay(now, 7), nextChangeAt = at },
                        freshness = { state = fresh, observedAt = project.observedAt, validUntil = at, clockSource = "server" },
                        nextAction = { kind = "open-page", title = "查看待办", pageID = "todo" },
                        item = project.iconKind == "item" and { itemID = project.icon } or nil,
                        icon = project.iconKind ~= "item" and (project.iconKind == "texture" and project.icon or project.fallbackIcon) or nil,
                    }
                    if project.scope == "account" then
                        task.execution = { mode = "account", candidateCharacterIDs = { characterID } }
                        task.beneficiary = { mode = "account" }
                    end
                    tasks[#tasks + 1] = task
                    if coverage.state == "known-empty" or fresh ~= "known" then coverage.state = fresh end
                    if at and (not coverage.nextChangeAt or at < coverage.nextChangeAt) then coverage.nextChangeAt = at end
                end
            end
        end
    end
    return tasks, coverage
end

function Action:Query(request)
    local result, err = Addon.ActionTodo.Query(self, request)
    if not result then return nil, err end
    local tasks, accounts = {}, {}
    for _, task in ipairs(result.data.tasks) do
        if task.execution.mode == "account" then
            local existing = accounts[task.itemKey]
            if existing then
                for _, id in ipairs(task.execution.candidateCharacterIDs) do
                    existing.execution.candidateCharacterIDs[#existing.execution.candidateCharacterIDs + 1] = id
                end
            else accounts[task.itemKey] = task; tasks[#tasks + 1] = task end
        else tasks[#tasks + 1] = task end
    end
    result.data.tasks = tasks
    return result
end
