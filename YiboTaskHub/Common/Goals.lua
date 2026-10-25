local Addon = _G.YiboTaskHub
local Goals = {}
Addon.Goals = Goals
local function Copy(v) return Addon.Core.Defaults:Copy(v) end
local function Root() return Addon.db.goals end
local function SameIdentity(identity, normalized)
    if identity == normalized.identity then return true end
    for _, alias in ipairs(normalized.identityAliases or {}) do if identity == alias then return true end end
    return false
end
function Goals:Changed(providerID)
    if Addon.BossTargets then Addon.BossTargets.view = nil end
    local db = Root(); db.revision = db.revision + 1
    if self.ref then Addon.Core.Contracts:NotifyChanged(Addon.NAME, self.ref, { revision = db.revision, reason = "goals-changed" }) end
    if Addon.BossTargets and Addon.BossTargets.ref and (not providerID or providerID == "YiboAltoBoss:targets") then
        Addon.Core.Contracts:NotifyChanged(Addon.NAME, Addon.BossTargets.ref, { revision = db.revision, reason = "boss-goals-changed" })
    end
    Addon.Contracts:Invalidate(providerID)
end
function Goals:List(includeRemoved, options)
    local result = {}
    for _, goal in pairs(Root().byID) do if includeRemoved or goal.state ~= "removed" then
        if options and options.omitHistory then
            local projection = {}
            for key, value in pairs(goal) do if key ~= "history" then projection[key] = Copy(value) end end
            result[#result + 1] = projection
        else result[#result + 1] = Copy(goal) end
    end end
    table.sort(result, function(a, b) if a.priority ~= b.priority then return a.priority > b.priority end; return a.id < b.id end)
    return result
end
function Goals:Normalize(intent, restart)
    if type(intent) ~= "table" or type(intent.providerID) ~= "string" then return nil, "invalid-intent" end
    local descriptor
    for _, ref in ipairs(Addon.Core.Contracts:List("action.targets", { major = 1 })) do
        if ref.providerID == intent.providerID then descriptor = ref; break end
    end
    if not descriptor then return nil, Addon:T("TEXT.GOAL_SOURCE_IS_NOT_READY_ENABLE_A_CO.6C513C") end
    local normalized, err = Addon.Core.Contracts:Call(Addon.NAME, descriptor, "Normalize", { intent = intent, restart = restart == true })
    if type(normalized) ~= "table" then return nil, err or "invalid-target" end
    if normalized.needsConfiguration then return normalized end
    if type(normalized.identity) ~= "string" or normalized.identity == "" or type(normalized.intent) ~= "table"
        or normalized.intent.providerID ~= intent.providerID or type(normalized.title) ~= "string"
        or not ({ once = true, recurring = true, maintain = true })[normalized.intent.repeatPolicy] then return nil, "invalid-target" end
    if normalized.identityAliases ~= nil then
        if type(normalized.identityAliases) ~= "table" then return nil, "invalid-target" end
        for _, alias in ipairs(normalized.identityAliases) do if type(alias) ~= "string" or alias == "" then return nil, "invalid-target" end end
    end
    local scope = normalized.intent.scope
    if type(scope) ~= "table" or (scope.mode ~= "character" and scope.mode ~= "account") then return nil, "invalid-scope" end
    if scope.mode == "character" then
        if type(scope.characterID) ~= "string" or scope.characterID == "" then return nil, "invalid-scope" end
    else
        if type(scope.characterIDs) ~= "table" or #scope.characterIDs == 0 then return nil, "invalid-scope" end
        for _, id in ipairs(scope.characterIDs) do if type(id) ~= "string" or id == "" then return nil, "invalid-scope" end end
    end
    return normalized
end
function Goals:Lookup(intent)
    if type(intent) ~= "table" then return nil end
    local clean = self:Normalize(intent)
    if not clean or clean.needsConfiguration then return nil end
    for _, goal in pairs(Root().byID) do
        if goal.state ~= "removed" and goal.intent.providerID == clean.intent.providerID then
            local identity = goal.identity
            if not identity then local old = self:Normalize(goal.intent); identity = old and old.identity end
            if SameIdentity(identity, clean) then return { id = goal.id, state = goal.state, revision = goal.revision } end
        end
    end
end
-- Project membership is intentionally broader than exact Add/Lookup identity:
-- source controls often have not chosen a quantity or completion mode yet.
function Goals:LookupItems(intents)
    local db = Root()
    if self.itemIndexRoot ~= db or self.itemIndexRevision ~= db.revision then
        self.itemIndex, self.itemIndexRoot, self.itemIndexRevision = {}, db, db.revision
        for _, goal in pairs(db.byID) do
            local intent = goal.intent
            if goal.state ~= "removed" and intent.objectID ~= nil then
                local provider = self.itemIndex[intent.providerID] or {}; self.itemIndex[intent.providerID] = provider
                local key = type(intent.objectID) .. ":" .. tostring(intent.objectID)
                provider[key] = provider[key] or {}; provider[key][#provider[key] + 1] = goal
            end
        end
    end
    local items, currentScopes = {}, {}
    for i, intent in ipairs(intents or {}) do
        local summary = { count = 0, active = 0, paused = 0, completed = 0 }
        local provider = self.itemIndex[intent.providerID]
        local key = type(intent.objectID) .. ":" .. tostring(intent.objectID)
        local scope = intent.scope or {}
        for _, goal in ipairs(provider and provider[key] or {}) do
            local targetScope, matches = goal.intent.scope, not scope.characterID
            if scope.characterID then
                if targetScope.mode == "account" then
                    -- Ask the owner for current eligibility; the saved candidate
                    -- snapshot may predate realm selection or recipe changes.
                    if currentScopes[goal.id] == nil then
                        local normalized = self:Normalize(goal.intent)
                        currentScopes[goal.id] = normalized and not normalized.needsConfiguration and normalized.intent.scope or false
                    end
                    targetScope = currentScopes[goal.id]
                end
                matches = targetScope and targetScope.characterID == scope.characterID or false
                for _, id in ipairs(targetScope and targetScope.characterIDs or {}) do if id == scope.characterID then matches = true end end
            end
            if matches then
                summary.count = summary.count + 1
                summary[goal.state] = (summary[goal.state] or 0) + 1
            end
        end
        items[i] = summary
    end
    return { items = items, revision = db.revision }
end
function Goals:Add(intent)
    local clean, err = self:Normalize(intent)
    if not clean then return nil, err end
    if clean.needsConfiguration then return clean end
    local db = Root()
    for _, goal in pairs(db.byID) do
        if not goal.identity and goal.intent.providerID == intent.providerID and goal.state ~= "removed" then
            local previous = self:Normalize(goal.intent)
            if previous and previous.identity then goal.identity = previous.identity end
        end
        if goal.intent.providerID == clean.intent.providerID and SameIdentity(goal.identity, clean) and goal.state ~= "removed" then return { id = goal.id, existing = true } end
    end
    db.nextID = db.nextID + 1
    local id, now = "goal:" .. db.nextID, Addon:Now()
    db.byID[id] = { id = id, identity = clean.identity, intent = Copy(clean.intent), title = clean.title,
        state = "active", priority = 0, revision = 1, createdAt = now, updatedAt = now, history = {} }
    self:Changed(clean.intent.providerID)
    return { id = id }
end
function Goals:Update(id, revision, patch)
    local goal = Root().byID[id]
    if not goal or goal.state == "removed" then return nil, Addon:T("TEXT.GOAL_WAS_REMOVED.88D805") end
    if revision ~= goal.revision then return nil, Addon:T("TEXT.GOAL_CHANGED_REFRESH_BEFORE_EDITING.EAAC83") end
    local copy = Copy(goal)
    if patch.intent then
        local clean, err = self:Normalize(patch.intent)
        if not clean or clean.needsConfiguration then return nil, err or Addon:T("TEXT.COMPLETE_THE_REQUIRED_GOAL_OPTIONS.7F6EBD") end
        for otherID, other in pairs(Root().byID) do
            if otherID ~= id and other.intent.providerID == clean.intent.providerID and SameIdentity(other.identity, clean) and other.state ~= "removed" then return nil, Addon:T("TEXT.GOAL_ALREADY_EXISTS.4BE99B") end
        end
        copy.intent, copy.identity, copy.title, copy.sourceEpoch = Copy(clean.intent), clean.identity, clean.title, nil
    end
    if patch.state then
        if not ({ active = true, paused = true, removed = true })[patch.state] then return nil, "invalid-state" end
        if goal.state == "completed" and patch.state == "active" then
            if patch.reopen ~= true then return nil, Addon:T("TEXT.CONFIRM_THAT_YOU_WANT_TO_RUN_THIS_GO.B2BCBC") end
            local clean, err = self:Normalize(copy.intent, true)
            if not clean or clean.needsConfiguration then return nil, err or Addon:T("TEXT.THE_SOURCE_IS_NOT_READY_SO_THIS_GOAL.7734A5") end
            copy.intent, copy.identity, copy.title, copy.sourceEpoch = Copy(clean.intent), clean.identity, clean.title, nil
            copy.lastCompletedCycle = nil
            copy.history[#copy.history + 1] = { state = "reopened", at = Addon:Now() }
        end
        copy.state = patch.state
    end
    if patch.priority ~= nil then
        if type(patch.priority) ~= "number" or patch.priority % 1 ~= 0 or math.abs(patch.priority) > 100 then return nil, "invalid-priority" end
        copy.priority = patch.priority
    end
    copy.revision, copy.updatedAt = copy.revision + 1, Addon:Now()
    Root().byID[id] = copy
    if goal.intent.providerID ~= copy.intent.providerID then Addon.Contracts:Invalidate(goal.intent.providerID) end
    self:Changed(copy.intent.providerID); return { id = id }
end
function Goals:PreviewCopy(goalIDs, destinations)
    local entries, seen, added, existing = {}, {}, 0, 0
    for _, id in ipairs(goalIDs or {}) do
        local goal = Root().byID[id]
        if not goal or goal.state == "removed" or goal.intent.scope.mode ~= "character" then return nil, Addon:T("TEXT.ONLY_VALID_CHARACTER_SPECIFIC_GOALS_.599366") end
        for _, characterID in ipairs(destinations or {}) do
            if characterID ~= goal.intent.scope.characterID then
                local intent = Copy(goal.intent); intent.scope.characterID = characterID
                local normalized, err = self:Normalize(intent)
                if not normalized or normalized.needsConfiguration then return nil, err or Addon:T("TEXT.THE_DESTINATION_CHARACTER_NEEDS_ADDI.4D7526") end
                local seenKey = normalized.intent.providerID .. ":" .. normalized.identity
                if not seen[seenKey] then
                    seen[seenKey] = true
                    local found
                    for _, old in pairs(Root().byID) do
                        local identity = old.identity
                        if not identity and old.intent.providerID == intent.providerID then
                            local clean = self:Normalize(old.intent); identity = clean and clean.identity
                        end
                        if old.state ~= "removed" and old.intent.providerID == normalized.intent.providerID and SameIdentity(identity, normalized) then found = old.id; break end
                    end
                    entries[#entries + 1] = { normalized = normalized, state = goal.state == "paused" and "paused" or "active", existingID = found }
                    if found then existing = existing + 1 else added = added + 1 end
                end
            end
        end
    end
    self.copySequence = (self.copySequence or 0) + 1
    local token = tostring(self.copySequence)
    self.pendingCopies = { [token] = { revision = Root().revision, entries = entries } }
    return { token = token, added = added, existing = existing, destinations = Copy(destinations), revision = Root().revision }
end
function Goals:ApplyCopy(token)
    local pending = self.pendingCopies and self.pendingCopies[token]
    if not pending or pending.revision ~= Root().revision then return nil, Addon:T("TEXT.GOAL_CHANGED_PREVIEW_THE_COPY_AGAIN.54D9B0") end
    local staged, nextID, providers = Copy(Root().byID), Root().nextID, {}
    for _, entry in ipairs(pending.entries) do
        local clean, err = self:Normalize(entry.normalized.intent)
        if not clean or clean.needsConfiguration or clean.identity ~= entry.normalized.identity then return nil, err or Addon:T("TEXT.THE_SOURCE_CHANGED_PREVIEW_THE_OPERA.6BADB0") end
        if not entry.existingID then
            nextID = nextID + 1
            local id = "goal:" .. nextID
            staged[id] = { id = id, identity = clean.identity, intent = Copy(clean.intent), title = clean.title, state = entry.state,
                priority = 0, revision = 1, createdAt = Addon:Now(), updatedAt = Addon:Now(), history = {} }
            providers[clean.intent.providerID] = true
        end
    end
    Root().byID, Root().nextID = staged, nextID
    self.pendingCopies = {}
    for providerID in pairs(providers) do self:Changed(providerID) end
    return true
end
function Goals:Observe(id, evaluation)
    local goal = Root().byID[id]
    if not goal or goal.state ~= "active" then return end
    if type(evaluation.sourceEpoch) ~= "string" then return nil, Addon:T("TEXT.SOURCE_IDENTITY_IS_MISSING.B6BBDB") end
    if goal.sourceEpoch and goal.sourceEpoch ~= evaluation.sourceEpoch then return nil, Addon:T("TEXT.THE_SOURCE_DATA_VERSION_CHANGED_EDIT.2FDF37") end
    goal.sourceEpoch = evaluation.sourceEpoch
    local task = evaluation.task
    if not task or not task.freshness or task.freshness.state ~= "known"
        or (task.freshness.validUntil and task.freshness.validUntil <= Addon:Now()) then return true end
    local changed
    if evaluation.invalid == true then
        changed = true
        goal.state, goal.updatedAt, goal.revision = "paused", Addon:Now(), goal.revision + 1
        goal.history[#goal.history + 1] = { state = "invalid", at = Addon:Now(), reason = evaluation.reason }
    elseif task.state == "completed" then
        local cycle = task.temporal and task.temporal.cycleKey or "once"
        if goal.lastCompletedCycle ~= cycle then
            goal.history[#goal.history + 1] = { state = "completed", at = Addon:Now(), cycle = cycle }
            goal.lastCompletedCycle, goal.revision, changed = cycle, goal.revision + 1, true
        end
        if goal.intent.repeatPolicy == "once" then goal.state = "completed" end
    elseif goal.intent.repeatPolicy == "maintain" then
        goal.lastCompletedCycle = nil
    end
    if changed then
        if Addon.BossTargets then Addon.BossTargets.view = nil end
        self.pendingSources = self.pendingSources or {}; self.pendingSources[goal.intent.providerID] = true
        if not self.observationQueued then
            self.observationQueued = true
            local generation = self.generation
            local function Flush()
                if generation ~= Goals.generation then return end
                Goals.observationQueued = false
                local pending = Goals.pendingSources; Goals.pendingSources = {}
                for providerID in pairs(pending) do Goals:Changed(providerID) end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, Flush) else Flush() end
        end
    end
    return true
end
function Goals:Initialize()
    if self.ref then return true end
    self.definition = self.definition or { name = "action.demands", kind = "service", providerID = Addon.NAME .. ":demands", version = { major = 1, minor = 1 }, methods = {
        Add = function(r) return Goals:Add(r.intent) end,
        Lookup = function(r) return Goals:Lookup(r.intent) end,
        LookupItems = function(r) return Goals:LookupItems(r.intents) end,
        Update = function(r) return Goals:Update(r.id, r.revision, r.patch or {}) end,
        Query = function() return { revision = Root().revision, goals = Goals:List() } end,
        PreviewCopy = function(r) return Goals:PreviewCopy(r.goalIDs, r.destinations) end,
        ApplyCopy = function(r) return Goals:ApplyCopy(r.token) end,
        Configure = function(r) return Addon.GoalEditor:Configure(r.intent) end,
        Locate = function(r) return Addon.GoalEditor:Locate(r.id) end,
    } }
    Addon.Core.Events:Register("CHARACTER_ID_CHANGED", self, function(_, oldID, newID)
        local changed
        for _, goal in pairs(Root().byID) do
            local scope, touched = goal.intent.scope, false
            if scope.characterID == oldID then scope.characterID, touched = newID, true end
            for i, id in ipairs(scope.characterIDs or {}) do if id == oldID then scope.characterIDs[i], touched = newID, true end end
            if touched then goal.identity, goal.revision, changed = nil, goal.revision + 1, true end
        end
        if changed then Goals:Changed() end
    end)
    self.ref = Addon.Core.Contracts:Register(Addon.NAME, self.definition)
    if not self.ref then self:Shutdown() end
    return self.ref ~= nil
end

function Goals:Shutdown()
    self.generation = (self.generation or 0) + 1
    self.itemIndex, self.itemIndexRoot, self.itemIndexRevision = nil, nil, nil
    self.pendingSources, self.observationQueued, self.pendingCopies = {}, false, {}
    Addon.Core.Events:Unregister("CHARACTER_ID_CHANGED", self)
    if self.ref then Addon.Core.Contracts:Unregister(Addon.NAME, self.ref); self.ref = nil end
end
