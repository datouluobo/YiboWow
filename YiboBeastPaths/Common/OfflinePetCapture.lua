local _, ns = ...
if not ns.YBP_TARGET_OK then return end

local Snapshot = ns.OfflinePetSnapshot
local Capture = {}
ns.OfflinePetCapture = Capture

-- Freeze each read before waiting; a native API may reuse mutable tables.
-- Reject rather than silently strip values that cannot be persisted safely.
local function Freeze(value, seen, depth)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return value end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then error("invalid number") end
        return value
    end
    if kind ~= "table" or depth > 16 or getmetatable(value) ~= nil then error("invalid value") end
    if seen[value] then error("cyclic value") end
    seen[value] = true
    local copy = {}
    for key, item in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then error("invalid key") end
        copy[key] = Freeze(item, seen, depth + 1)
    end
    seen[value] = nil
    return copy
end

local function Equal(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] then return false end
    seen[left] = true
    for key, value in pairs(left) do
        if not Equal(value, right[key], seen) then seen[left] = nil; return false end
    end
    for key in pairs(right) do
        if left[key] == nil then seen[left] = nil; return false end
    end
    seen[left] = nil
    return true
end

-- A production target must explicitly provide a verified completeness policy.
-- Without one, do not schedule repeated scans or submit any candidate.
function Capture.New(options)
    local self = { generation = 0 }
    local function report(id, status)
        if not options.Valid(id) then return end
        local timestamp = options.Now()
        local changed = Snapshot.RecordAttempt(options.Root(), options.target, id, status, timestamp)
        if changed then options.Notify() end
    end
    local function read()
        local ok, candidate, reason = pcall(function()
            local value, state = options.Read()
            if type(value) ~= "table" then return nil, state end
            return Freeze(value, {}, 0), state
        end)
        if not ok or type(candidate) ~= "table" then return nil, "unavailable" end
        if type(candidate.active) ~= "table" or type(candidate.stable) ~= "table" then
            return nil, "unavailable"
        end
        return candidate, reason
    end
    function self:Invalidate()
        self.generation = self.generation + 1
    end
    function self:Attempt(id)
        self:Invalidate()
        if type(id) ~= "string" or id == "" or not options.Valid(id) then return false end
        local generation = self.generation
        local first = read()
        if generation ~= self.generation or not options.Valid(id) then return false end
        if not first then report(id, "unavailable"); return false end
        if type(options.VerifiedPolicy) ~= "function" and not options.SaveObservations then
            report(id, "unverified")
            return false
        end
        if type(options.Schedule) ~= "function" then report(id, "unavailable"); return false end
        local scheduled = pcall(options.Schedule, function()
            if generation ~= self.generation or not options.Valid(id) then return end
            -- Even if a scheduler mistakenly fires the same callback twice,
            -- only one completion may touch business data.
            self:Invalidate()
            local completionGeneration = self.generation
            local second = read()
            if completionGeneration ~= self.generation or not options.Valid(id) then return end
            if not second then report(id, "unavailable"); return end
            if not Equal(first, second) then report(id, "unverified"); return end
            local candidate = Snapshot.Copy(second)
            if type(candidate) ~= "table" then report(id, "unavailable"); return end
            candidate.capturedAt = options.Now()
            if type(options.VerifiedPolicy) ~= "function" then
                local ok, saved = pcall(Snapshot.SaveObservation, options.Root(), options.target,
                    id, candidate, candidate.capturedAt)
                if ok and saved then options.Notify() else report(id, "unverified") end
                return
            end
            local ok, committed = pcall(Snapshot.Commit, options.Root(), options.target,
                id, candidate, options.VerifiedPolicy)
            if ok and committed then options.Notify() else report(id, "unverified") end
        end)
        if not scheduled then report(id, "unavailable"); return false end
        return true
    end
    return self
end
