local Addon = _G.YiboTaskHub
local Snapshot = {}
Addon.Snapshot = Snapshot
local modes = { self = true, assigned = true, open = true, account = true }
local states = { active = true, completed = true, paused = true, cancelled = true }
local readiness = { actionable = true, preparation = true, blocked = true, unknown = true, ["not-applicable"] = true }
local freshStates = { known = true, ["known-empty"] = true, partial = true, stale = true,
    ["not-yet-scanned"] = true, unavailable = true, error = true }
local function Text(value) return type(value) == "string" and value ~= "" end

function Snapshot:ValidateResult(value, descriptor, ids)
    if type(value) ~= "table" or value.providerID ~= descriptor.providerID or not Text(value.sourceEpoch)
        or type(value.revision) ~= "number" or value.revision < 0 or value.revision % 1 ~= 0
        or type(value.generatedAt) ~= "number" or not ({ ready = true, partial = true, pending = true, error = true })[value.status]
        or type(value.coverage) ~= "table" or type(value.data) ~= "table" or type(value.data.tasks) ~= "table" then
        return nil, "invalid-result"
    end
    local scope = {}
    for _, id in ipairs(ids) do
        scope[id] = true
        local coverage = value.coverage[id]
        if type(coverage) ~= "table" or not freshStates[coverage.state] then return nil, "invalid-coverage" end
    end
    for _, task in ipairs(value.data.tasks) do
        if type(task) ~= "table" then return nil, "invalid-task" end
        local ref, execution, beneficiary = task.businessRef, task.execution, task.beneficiary
        if not Text(task.itemKey) or not Text(task.title) or type(ref) ~= "table"
            or ref.capability ~= "action.todo" or ref.providerID ~= value.providerID or ref.sourceEpoch ~= value.sourceEpoch or ref.key ~= task.itemKey
            or type(execution) ~= "table" or not modes[execution.mode] or type(beneficiary) ~= "table"
            or not ({ character = true, account = true, unknown = true })[beneficiary.mode]
            or not states[task.state] or not readiness[task.readiness] or type(task.temporal) ~= "table"
            or not ({ daily = true, weekly = true, cooldown = true, persistent = true, other = true })[task.temporal.kind]
            or type(task.freshness) ~= "table" or not freshStates[task.freshness.state] then return nil, "invalid-task" end
        if task.temporal.cycleKey ~= nil and not Text(task.temporal.cycleKey) then return nil, "invalid-cycle" end
        for _, at in ipairs({ task.temporal.nextChangeAt or false, task.freshness.validUntil or false, task.freshness.observedAt or false }) do
            if at ~= false and (type(at) ~= "number" or at ~= at or at == math.huge or at == -math.huge) then return nil, "invalid-time" end
        end
        if beneficiary.mode == "character" and not Text(beneficiary.characterID) then return nil, "invalid-beneficiary" end
        if execution.mode == "self" or execution.mode == "assigned" then
            if not scope[execution.characterID] then return nil, "out-of-scope" end
            if execution.mode == "self" and (beneficiary.mode ~= "character" or beneficiary.characterID ~= execution.characterID) then return nil, "invalid-self" end
        else
            if type(execution.candidateCharacterIDs) ~= "table" then return nil, "invalid-candidates" end
            for _, id in ipairs(execution.candidateCharacterIDs) do if not Text(id) then return nil, "invalid-candidates" end end
        end
        if task.nextAction and (type(task.nextAction) ~= "table" or task.nextAction.kind ~= "open-page" or not Text(task.nextAction.pageID)) then return nil, "invalid-action" end
        if task.icon ~= nil and not ((type(task.icon) == "number" and task.icon > 0 and task.icon % 1 == 0 and task.icon < math.huge)
            or (Text(task.icon) and not task.icon:find("|", 1, true))) then return nil, "invalid-icon" end
    end
    return true
end

local function Identity(task)
    local ref = task.businessRef
    local parts = {}
    for _, value in ipairs({ ref.capability, ref.providerID, ref.sourceEpoch, task.itemKey, task.temporal.cycleKey or "" }) do
        parts[#parts + 1] = #value .. ":" .. value
    end
    return table.concat(parts, "|")
end

function Snapshot:Build(characters)
    local value = { tasks = {}, current = {}, others = {}, byCharacter = {}, sources = {}, errors = {},
        uniqueCount = 0, candidateCount = 0, unknownCount = 0, uncoveredCount = 0, providerCount = 0, inactiveGoals = {} }
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local currentID, now, allowed, seen = current and current.id, Addon:Now(), {}, {}
    for _, character in ipairs(characters or {}) do allowed[character.id] = character end
    for _, source in ipairs(Addon.Contracts:GetResults(characters)) do
        value.providerCount = value.providerCount + 1
        if source.error or not source.result then
            value.errors[#value.errors + 1] = { providerID = source.descriptor.providerID, code = source.error or "unavailable" }
        else
            local result = source.result
            value.sources[#value.sources + 1] = { id = result.providerID, title = result.sourceTitle or source.descriptor.owner }
            for _, coverage in pairs(result.coverage) do
                if coverage.state ~= "known" and coverage.state ~= "known-empty" then value.uncoveredCount = value.uncoveredCount + 1 end
            end
            for _, task in ipairs(result.data.tasks) do
                if task.goalID and task.state == "active" and task.readiness == "not-applicable" and task.freshness.state == "known"
                    and (not task.freshness.validUntil or task.freshness.validUntil > now) then
                    value.inactiveGoals[task.goalID] = true
                end
                local key = Identity(task)
                if not seen[key] and task.state == "active" and task.readiness ~= "not-applicable" then
                    seen[key] = true
                    local visible = not Addon.Settings or not Addon.Settings.IsWorkVisible or Addon.Settings:IsWorkVisible(task, result.providerID)
                    if visible then
                    local copy = Addon.Core.Defaults:Copy(task)
                    copy.identity, copy.sourceTitle, copy.providerID = key, result.sourceTitle or source.descriptor.owner, result.providerID
                    if copy.freshness.validUntil and now >= copy.freshness.validUntil then copy.freshness.state = "stale" end
                    if copy.freshness.state ~= "known" then copy.readiness = "unknown" end
                    local candidate = copy.execution.mode == "open" or copy.execution.mode == "account"
                    local targets = candidate and copy.execution.candidateCharacterIDs or { copy.execution.characterID }
                    local projected, localSeen = false, {}
                    for _, id in ipairs(targets) do
                        if allowed[id] and not localSeen[id] then
                            localSeen[id], projected = true, true
                            local row = { task = copy, character = allowed[id], candidate = candidate }
                            value.byCharacter[id] = value.byCharacter[id] or {}
                            table.insert(value.byCharacter[id], row)
                        end
                    end
                    if projected then
                        value.tasks[#value.tasks + 1] = copy
                        value.uniqueCount = value.uniqueCount + 1
                        if candidate then value.candidateCount = value.candidateCount + 1 end
                        if copy.readiness == "unknown" then value.unknownCount = value.unknownCount + 1 end
                    end
                    end
                end
            end
        end
    end
    local rank = { actionable = 1, preparation = 2, blocked = 4, unknown = 5 }
    for _, character in ipairs(characters or {}) do
        local rows = value.byCharacter[character.id] or {}
        table.sort(rows, function(a, b)
            if a.candidate ~= b.candidate then return not a.candidate end
            local ar, br = rank[a.task.readiness] or 9, rank[b.task.readiness] or 9
            if ar ~= br then return ar < br end
            return a.task.identity < b.task.identity
        end)
        for _, row in ipairs(rows) do
            local destination = character.id == currentID and value.current or value.others
            destination[#destination + 1] = row
        end
    end
    return value
end
