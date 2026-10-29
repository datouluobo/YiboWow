local Addon = _G.YiboTaskHub
local Connections = { providers = {}, cache = {}, listeners = {} }
Addon.Contracts = Connections
local NAME = "action.todo"

-- Keep an earlier wake when a source postpones expiry. Repeated invalidations
-- then share a timer; an earlier new deadline replaces it without delaying data.
function Connections:ScheduleExpiry(kind, deadline)
    self.expiryTimers = self.expiryTimers or {}
    local existing = self.expiryTimers[kind]
    if not deadline then
        if existing and existing.handle then existing.handle:Cancel() end
        self.expiryTimers[kind] = nil
        return
    end
    if existing and existing.at <= deadline then return end
    if not (C_Timer and C_Timer.After) then return end
    if existing and existing.handle then existing.handle:Cancel() end
    local ticket = { at = deadline }
    self.expiryTimers[kind] = ticket
    local function Wake()
        if Connections.expiryTimers[kind] ~= ticket then return end
        Connections.expiryTimers[kind] = nil
        if kind == "goals" then Connections.goalNextAt = nil else Connections.nextChange = nil end
        local now = Addon:Now()
        local buckets = kind == "goals" and Connections.goalCache or Connections.cache
        for _, bucket in pairs(buckets or {}) do for key, entry in pairs(bucket) do
            if entry.expiresAt and now >= entry.expiresAt then bucket[key] = nil end
        end end
        Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID)
        if Addon.Displays then Addon.Displays:ScheduleRefresh() end
    end
    local delay = math.max(0.1, deadline - Addon:Now() + 0.1)
    if C_Timer.NewTimer then ticket.handle = C_Timer.NewTimer(delay, Wake) else C_Timer.After(delay, Wake) end
end

function Connections:Invalidate(providerID)
    if self.goalCache then self.goalCache[providerID or ""] = nil; if not providerID then self.goalCache = {} end end
    if providerID then self.cache[providerID] = nil else self.cache = {} end
    if Addon.Core then Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID) end
    if Addon.Displays then Addon.Displays:ScheduleRefresh() end
end

function Connections:Discover()
    local list = Addon.Core.Contracts:List(NAME, { major = 1, minMinor = 0 }) or {}
    local providers = {}
    for _, descriptor in ipairs(list) do
        providers[descriptor.providerID] = descriptor
        local previous = self.providers[descriptor.providerID]
        if not previous or previous.registrationRef ~= descriptor.registrationRef then self.cache[descriptor.providerID] = nil end
    end
    for id in pairs(self.cache) do if not providers[id] then self.cache[id] = nil end end
    self.providers, self.list = providers, list
    return list
end

function Connections:Initialize()
    if self.initialized then return true end
    local core = Addon.Core
    -- Subscribe before discovery. Registration, removal and changes are only
    -- invalidation facts; requesting a snapshot never emits another broadcast.
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
        local callback = function(_, descriptor)
            if descriptor.name ~= NAME and descriptor.name ~= "action.targets" then return end
            self:Discover()
            self:Invalidate(descriptor.providerID)
        end
        self.listeners[event] = callback
        core.Events:Register(event, self, callback)
    end
    self:Discover()
    self.initialized = true
    return true
end

local function Scope(characters)
    local ids, seen = {}, {}
    for _, character in ipairs(characters or {}) do
        if type(character.id) == "string" and not seen[character.id] then ids[#ids + 1], seen[character.id] = character.id, true end
    end
    local keys = {}
    for _, id in ipairs(ids) do keys[#keys + 1] = #id .. ":" .. id end
    return ids, table.concat(keys, "|")
end

function Connections:GetResults(characters)
    if Addon.Goals and Addon.db.goals then return self:GetGoalResults(characters) end
    local ids, scopeKey = Scope(characters)
    local now, results, nextChange = Addon:Now(), {}, nil
    for _, descriptor in ipairs(self:Discover()) do
        local scopes = self.cache[descriptor.providerID] or {}
        self.cache[descriptor.providerID] = scopes
        local cached = scopes[scopeKey]
        if not cached or (cached.expiresAt and now >= cached.expiresAt) then
            local value, code = Addon.Core.Contracts:Call(Addon.NAME, descriptor, "Query", { scope = { characterIDs = ids } })
            local ok, valid, err = pcall(Addon.Snapshot.ValidateResult, Addon.Snapshot, value, descriptor, ids)
            if not ok then valid, err = nil, "invalid-result" end
            if not valid then value, code = nil, code or err end
            if value and (value.status == "error" or value.status == "pending") then value, code = nil, "source-not-ready" end
            cached = { scopeKey = scopeKey, result = value, error = code, descriptor = descriptor }
            if value then
                local function Boundary(at)
                    at = tonumber(at)
                    if at and at > now and (not cached.expiresAt or at < cached.expiresAt) then cached.expiresAt = at end
                end
                for _, task in ipairs(value.data.tasks) do
                    Boundary(task.temporal.nextChangeAt); Boundary(task.freshness.validUntil)
                end
                for _, coverage in pairs(value.coverage) do Boundary(coverage.nextChangeAt); Boundary(coverage.validUntil) end
            end
            scopes[scopeKey] = cached
        end
        self.access = (self.access or 0) + 1
        cached.access = self.access
        -- Keep current-character reminders and account/hover scopes together,
        -- with a bounded per-source cache when the user changes scope often.
        local count, oldestKey, oldest = 0
        for key, entry in pairs(scopes) do
            count = count + 1
            if key ~= scopeKey and (not oldest or entry.access < oldest) then oldestKey, oldest = key, entry.access end
        end
        if count > 4 then scopes[oldestKey] = nil end
        results[#results + 1] = cached
    end
    for _, scopes in pairs(self.cache) do for _, entry in pairs(scopes) do
        if entry.expiresAt and (not nextChange or entry.expiresAt < nextChange) then nextChange = entry.expiresAt end
    end end
    self.nextChange = nextChange
    self:ScheduleExpiry("tasks", nextChange)
    return results
end

function Connections:Shutdown()
    for _, timer in pairs(self.expiryTimers or {}) do if timer.handle then timer.handle:Cancel() end end
    self.expiryTimers = {}
    self.goalCache, self.goalNextAt = {}, nil
    self.goalTimer = (self.goalTimer or 0) + 1
    if Addon.Core then for event, callback in pairs(self.listeners) do Addon.Core.Events:Unregister(event, self, callback) end end
    self.listeners, self.providers, self.cache, self.list = {}, {}, {}, {}
    self.initialized, self.nextChange = false, nil
    self.timerToken = (self.timerToken or 0) + 1
end
