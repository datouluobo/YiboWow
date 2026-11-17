-- Shared, side-effect-free native currency discovery. Target adapters supply
-- normalized rows and details; this module does not own saved variables.
local Addon = _G.YiboCurrency
local Discovery = {}
Addon.NativeDiscovery = Discovery

local function ValidID(id)
    if type(issecretvalue) == "function" and issecretvalue(id) then return false end
    return type(id) == "number" and id > 0 and id <= 2147483647 and id % 1 == 0
end

local function ValidCount(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

local function ValidIdentity(row)
    return type(row) == "table" and ValidID(row.id) and type(row.name) == "string" and row.name ~= ""
end

-- Existing entries are copied so a failed or partial scan cannot remove them.
-- Adapter:List() returns rows, complete; Adapter:Detail(id) returns a row or nil.
-- The caller chooses when and where the returned delta is committed.
function Discovery:Collect(adapter, existing, stamp)
    assert(type(adapter) == "table" and type(adapter.List) == "function" and type(adapter.Detail) == "function")
    assert(ValidCount(stamp))
    local directory, observations = {}, {}
    for id, entry in pairs(existing or {}) do
        if ValidID(id) and ValidIdentity(entry) and entry.id == id then
            local copy = {}; for key, value in pairs(entry) do copy[key] = value end
            directory[id] = copy
        end
    end
    local ok, rows, complete = pcall(adapter.List, adapter)
    if not ok or type(rows) ~= "table" then rows, complete = {}, false end
    for _, row in ipairs(rows) do
        if ValidIdentity(row) then
            local entry = directory[row.id] or { id = row.id, discoveredAt = stamp }
            entry.name, entry.icon, entry.updatedAt = row.name, row.icon or entry.icon, stamp
            directory[row.id] = entry
        elseif type(row) ~= "table" or row.isHeader ~= true then
            complete = false
        end
    end
    for id, entry in pairs(directory) do
        local detailOK, detail = pcall(adapter.Detail, adapter, id)
        if detailOK and ValidIdentity(detail) and detail.id == id then
            entry.name, entry.icon, entry.updatedAt = detail.name, detail.icon or entry.icon, stamp
            if ValidCount(detail.quantity) then
                observations[id] = { quantity = detail.quantity, observedAt = stamp, state = "known" }
            end
        end
    end
    return directory, observations, complete == true
end

-- Commit only valid observations for the selected character. Callers persist
-- the returned copy under Core's character ID; absent values remain history.
function Discovery:MergeSnapshot(previous, observations)
    local result = {}
    for id, row in pairs(previous or {}) do
        if ValidID(id) and type(row) == "table" then
            local copy = {}; for key, value in pairs(row) do copy[key] = value end
            result[id] = copy
        end
    end
    for id, row in pairs(observations or {}) do
        if ValidID(id) and type(row) == "table" and ValidCount(row.quantity)
            and ValidCount(row.observedAt) and row.state == "known" then
            local prior = result[id]
            if not prior or not ValidCount(prior.observedAt) or row.observedAt >= prior.observedAt then
                result[id] = { quantity = row.quantity, observedAt = row.observedAt, state = "known" }
            end
        end
    end
    return result
end

-- A saved observation is fresh only when the current scan actually read it.
-- Directory membership or a successful empty list never implies zero.
function Discovery:GetValue(snapshot, observations, id)
    if not ValidID(id) then return nil, "unknown" end
    local value = type(snapshot) == "table" and snapshot[id]
    if type(value) ~= "table" or not ValidCount(value.quantity) or not ValidCount(value.observedAt) then
        return nil, "unknown"
    end
    local current = type(observations) == "table" and observations[id]
    if type(current) == "table" and current.state == "known" and ValidCount(current.quantity)
        and ValidCount(current.observedAt) and current.observedAt == value.observedAt
        and current.quantity == value.quantity then
        return value.quantity, "known", value.observedAt
    end
    return value.quantity, "stale", value.observedAt
end

-- Import is intentionally additive: old fixed-catalog entries are eligible
-- only when the adapter can supply valid observed facts, including zero.
function Discovery:ImportObserved(directory, characterSnapshots, stamp)
    assert(ValidCount(stamp))
    local result, imported = {}, {}
    for id, entry in pairs(directory or {}) do
        if ValidID(id) and ValidIdentity(entry) and entry.id == id then
            local copy = {}; for key, value in pairs(entry) do copy[key] = value end
            result[id] = copy
        end
    end
    for _, snapshot in pairs(characterSnapshots or {}) do
        if type(snapshot) == "table" then
            for id, row in pairs(snapshot) do
                if ValidID(id) and type(row) == "table" and ValidCount(row.quantity)
                    and ValidCount(row.observedAt) and type(row.name) == "string" and row.name ~= ""
                    and (not result[id] or (imported[id] and row.observedAt > result[id].updatedAt)) then
                    local first = result[id] and result[id].discoveredAt or row.observedAt
                    result[id] = { id = id, name = row.name, icon = row.icon,
                        discoveredAt = math.min(first, row.observedAt), updatedAt = row.observedAt }
                    imported[id] = true
                elseif imported[id] and type(row) == "table" and ValidCount(row.quantity)
                    and ValidCount(row.observedAt) and type(row.name) == "string" and row.name ~= "" then
                    result[id].discoveredAt = math.min(result[id].discoveredAt, row.observedAt)
                end
            end
        end
    end
    return result
end
