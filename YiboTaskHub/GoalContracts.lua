local Addon = _G.YiboTaskHub
local Connections = Addon.Contracts
local function Unknown(goal, reason, epoch)
    local scope = goal.intent.scope or {}
    return { itemKey = goal.id, title = goal.title or Addon:T("TEXT.UNVERIFIED_GOAL.0A640A"), goalID = goal.id,
        businessRef = { capability = "action.todo", providerID = goal.intent.providerID, sourceEpoch = epoch or "unavailable", key = goal.id },
        execution = scope.mode == "account" and { mode = "account", candidateCharacterIDs = scope.characterIDs or {} }
            or { mode = "self", characterID = scope.characterID },
        beneficiary = scope.mode == "account" and { mode = "account" } or { mode = "character", characterID = scope.characterID },
        state = "active", readiness = "unknown", reason = reason or Addon:T("TEXT.SOURCE_NOT_READY.C34F17"), summary = reason,
        temporal = { kind = "persistent" }, freshness = { state = "unavailable" } }
end
function Connections:GetGoalResults(characters)
    local allowed, ids = {}, {}
    for _, c in ipairs(characters or {}) do allowed[c.id] = true; ids[#ids + 1] = c.id end
    local groups, descriptors, results, now = {}, {}, {}, Addon:Now()
    for _, d in ipairs(Addon.Core.Contracts:List("action.targets", { major = 1 })) do descriptors[d.providerID] = d end
    for _, goal in ipairs(Addon.Goals:List(false, { omitHistory = true })) do
        local scope = goal.intent.scope or {}
        if goal.state == "active" and (scope.mode == "account" or allowed[scope.characterID]) then
            local id = goal.intent.providerID
            groups[id] = groups[id] or {}; groups[id][#groups[id] + 1] = goal
        end
    end
    for providerID, goals in pairs(groups) do
        local descriptor = descriptors[providerID]
        local key = (descriptor and descriptor.registrationRef or "missing") .. "|scope:" .. table.concat(ids, ",")
        for _, goal in ipairs(goals) do key = key .. "|" .. goal.id .. ":" .. goal.revision end
        local bucket = self.goalCache and self.goalCache[providerID]
        local cached = bucket and bucket[key]
        if not cached or cached.key ~= key or now >= cached.expiresAt then
            local response, err
            if descriptor then response, err = Addon.Core.Contracts:Call(Addon.NAME, descriptor, "Evaluate", { goals = goals }) end
            if type(response) ~= "table" or type(response.evaluations) ~= "table" or type(response.sourceEpoch) ~= "string" then
                response, err = nil, err or Addon:T("TEXT.SOURCE_TEMPORARILY_UNAVAILABLE.99F872")
            end
            local result = { providerID = providerID, sourceEpoch = response and response.sourceEpoch or "unavailable",
                revision = response and response.revision or 0, generatedAt = now, sourceTitle = response and response.sourceTitle or providerID,
                status = "partial", coverage = {}, data = { tasks = {} } }
            local expiresAt = now + 60
            for _, id in ipairs(ids) do result.coverage[id] = { state = "known" } end
            for _, goal in ipairs(goals) do
                local evaluation = response and response.evaluations[goal.id]
                if type(evaluation) ~= "table" then evaluation = nil end
                local task = type(evaluation) == "table" and evaluation.task
                if task then
                    evaluation.sourceEpoch = response.sourceEpoch
                    local candidate = Addon.Core.Defaults:Copy(task)
                    candidate.itemKey, candidate.goalID = goal.id, goal.id
                    candidate.businessRef = { capability = "action.todo", providerID = providerID, sourceEpoch = result.sourceEpoch, key = goal.id }
                    local check = { providerID = providerID, sourceEpoch = result.sourceEpoch, revision = result.revision,
                        generatedAt = now, status = "partial", coverage = result.coverage, data = { tasks = { candidate } } }
                    local ok = Addon.Snapshot:ValidateResult(check, { providerID = providerID }, ids)
                    if ok then
                        if candidate.state == "completed" and (candidate.freshness.state ~= "known"
                            or (candidate.freshness.validUntil and candidate.freshness.validUntil <= now)) then
                            candidate.state, candidate.readiness = "active", "unknown"
                            candidate.reason = Addon:T("TEXT.COMPLETION_EVIDENCE_EXPIRED_REFRESH_.81C038")
                            candidate.summary = candidate.reason
                        end
                        local observed, reason = Addon.Goals:Observe(goal.id, evaluation)
                        task = observed and candidate or Unknown(goal, reason, result.sourceEpoch)
                    else task = Unknown(goal, Addon:T("TEXT.THE_SOURCE_RETURNED_AN_INVALID_GOAL_.9A35AC"), result.sourceEpoch) end
                else
                    task = Unknown(goal, evaluation and evaluation.reason or err, result.sourceEpoch)
                    local display = evaluation and evaluation.display
                    if type(display) == "table" then
                        task.item = type(display.item) == "table" and Addon.Core.Defaults:Copy(display.item) or nil
                        task.icon = (type(display.icon) == "string" or type(display.icon) == "number") and display.icon or nil
                    end
                end
                local saved = Addon.db.goals.byID[goal.id]
                if saved and saved.state == "active" then result.data.tasks[#result.data.tasks + 1] = task end
                for _, at in ipairs({ task.temporal.nextChangeAt or false, task.freshness.validUntil or false }) do
                    if at and at > now then expiresAt = math.min(expiresAt, at) end
                end
            end
            cached = { key = key, expiresAt = expiresAt, result = result,
                descriptor = descriptor or { providerID = providerID, owner = providerID } }
            self.goalCache = self.goalCache or {}
            bucket = bucket or {}; local count = 0; for _ in pairs(bucket) do count = count + 1 end
            if count >= 24 then bucket = {} end
            bucket[key] = cached; self.goalCache[providerID] = bucket
        end
        results[#results + 1] = cached
    end
    -- A single timer bounds stale projections across all four surfaces.
    local nextAt
    for _, bucket in pairs(self.goalCache or {}) do for _, entry in pairs(bucket) do
        if not nextAt or entry.expiresAt < nextAt then nextAt = entry.expiresAt end
    end end
    self.goalNextAt = nextAt
    self:ScheduleExpiry("goals", nextAt)
    return results
end
