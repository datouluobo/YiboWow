local _, ns = ...
if not ns.YBP_TARGET_OK then return end

-- Pure snapshot policy. Unverified observations can never replace saved data.
local Snapshot = {}
ns.OfflinePetSnapshot = Snapshot

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out = {}
    for k, v in pairs(value) do
        local kt, vt = type(k), type(v)
        if (kt == "string" or kt == "number") and
            (vt == "string" or vt == "number" or vt == "boolean" or vt == "table") then
            out[k] = Copy(v, seen)
        end
    end
    seen[value] = nil
    return out
end

function Snapshot.Copy(value) return Copy(value) end

local function ValidTime(value)
    return type(value) == "number" and value == value and value > 0 and value < math.huge
end

-- Persistence must reject unsupported, cyclic and metatable-backed values;
-- the permissive display copy above must never be used for writing snapshots.
local function CopyForStorage(value, seen, depth)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return value end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then error("invalid number") end
        return value
    end
    if kind ~= "table" or depth > 16 or getmetatable(value) ~= nil or seen[value] then
        error("invalid storage value")
    end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then error("invalid storage key") end
        if type(key) == "number" and (key ~= key or key == math.huge or key == -math.huge) then
            error("invalid numeric key")
        end
        result[key] = CopyForStorage(item, seen, depth + 1)
    end
    seen[value] = nil
    return result
end

local function ValidItems(items)
    local count, highest, seen = 0, 0, {}
    for index, pet in pairs(items) do
        if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or type(pet) ~= "table"
            or type(pet.slotID) ~= "number" or pet.slotID < 1 or pet.slotID % 1 ~= 0
            or type(pet.name) ~= "string" or seen[pet.slotID] then return false end
        seen[pet.slotID] = true
        count = count + 1
        if index > highest then highest = index end
    end
    return highest == count
end

function Snapshot.CheckStore(root, target)
    local matches = (target == "Retail" and type(_G.WOW_PROJECT_MAINLINE) == "number"
            and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)
        or (target == "Mists" and type(_G.WOW_PROJECT_MISTS_CLASSIC) == "number"
            and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MISTS_CLASSIC)
    if not matches then return false, "wrong-target" end
    if type(root) ~= "table" then return false, "invalid-root" end
    local store = root.offlinePets
    if store == nil then return true end
    if type(store) ~= "table" or store.schema ~= 1 or store.target ~= target
        or type(store.characters) ~= "table" then return false, "invalid-store" end
    return true
end

function Snapshot.IsCompleteGroup(group)
    if type(group) ~= "table" or type(group.items) ~= "table"
        or group.completeness ~= "complete" or not ValidTime(group.capturedAt)
        or type(group.coverage) ~= "string" or group.coverage == ""
        or type(group.sourceBuild) ~= "string" or group.sourceBuild == "" then return false end
    local ok, valid = pcall(ValidItems, group.items)
    return ok and valid == true
end

local function ValidRecord(record)
    if type(record) ~= "table" then return false end
    for key in pairs(record) do
        if key ~= "active" and key ~= "stable" and key ~= "lastAttempt" and key ~= "observation" then return false end
    end
    for _, group in ipairs({ "active", "stable" }) do
        local value = record[group]
        if value ~= nil and (type(value) ~= "table" or type(value.items) ~= "table"
            or not ValidTime(value.capturedAt)) then return false end
        if value ~= nil then
            for key in pairs(value) do
                if key ~= "items" and key ~= "capturedAt" and key ~= "completeness"
                    and key ~= "coverage" and key ~= "sourceBuild" and key ~= "captureID" then return false end
            end
            local ok, valid = pcall(ValidItems, value.items)
            if not ok or not valid then return false end
        end
    end
    if record.lastAttempt ~= nil then
        local attempt = record.lastAttempt
        if type(attempt) ~= "table" or (attempt.status ~= "unavailable" and attempt.status ~= "unverified")
            or not ValidTime(attempt.at) then return false end
        for key in pairs(attempt) do if key ~= "status" and key ~= "at" then return false end end
    end
    if record.observation ~= nil and not Snapshot.IsObservation(record.observation) then return false end
    local ok = pcall(CopyForStorage, record, {}, 0)
    return ok
end

function Snapshot.IsObservation(value)
    if type(value) ~= "table" or value.completeness ~= "unverified" or not ValidTime(value.capturedAt)
        or type(value.sourceBuild) ~= "string" or value.sourceBuild == ""
        or type(value.coverage) ~= "string" or value.coverage == ""
        or type(value.active) ~= "table" or type(value.stable) ~= "table" then return false end
    for key in pairs(value) do
        if key ~= "active" and key ~= "stable" and key ~= "completeness" and key ~= "capturedAt"
            and key ~= "sourceBuild" and key ~= "coverage" then return false end
    end
    local ok, valid = pcall(function()
        if not ValidItems(value.active) or not ValidItems(value.stable)
            or (#value.active + #value.stable == 0) then return false end
        local seen = {}
        for _, pet in ipairs(value.active) do seen[pet.slotID] = true end
        for _, pet in ipairs(value.stable) do if seen[pet.slotID] then return false end end
        return true
    end)
    if not ok or not valid then return false end
    local safe = pcall(CopyForStorage, value, {}, 0)
    return safe
end

function Snapshot.SaveObservation(root, target, characterID, candidate, capturedAt)
    local ok, reason = Snapshot.CheckStore(root, target)
    if not ok then return false, reason end
    if type(characterID) ~= "string" or characterID == "" then return false, "identity-unknown" end
    if type(candidate) ~= "table" or candidate.completeness ~= "unverified" then return false, "invalid-observation" end
    local value = { active = candidate.active, stable = candidate.stable, capturedAt = capturedAt,
        completeness = "unverified", sourceBuild = candidate.sourceBuild, coverage = candidate.coverage }
    if not Snapshot.IsObservation(value) then return false, "invalid-observation" end
    local existing = root.offlinePets and root.offlinePets.characters[characterID]
    if existing ~= nil and not ValidRecord(existing) then return false, "invalid-record" end
    if existing and existing.observation and existing.observation.capturedAt > capturedAt then return false, "older-observation" end
    local copied, stored = pcall(CopyForStorage, value, {}, 0)
    if not copied then return false, "invalid-observation" end
    local valid, why = Snapshot.CheckStore(root, target)
    if not valid then return false, why end
    if (root.offlinePets and root.offlinePets.characters[characterID]) ~= existing then return false, "record-changed" end
    local store = root.offlinePets
    if not store then store = { schema = 1, target = target, characters = {} }; root.offlinePets = store end
    if not existing then existing = {}; store.characters[characterID] = existing end
    existing.observation = stored
    return true
end

-- An explicit proof is necessary but not sufficient: callers must pass the
-- target-specific verified policy. No current target has such a policy yet.
function Snapshot.Commit(root, target, characterID, observation, verifiedPolicy)
    local ok, reason = Snapshot.CheckStore(root, target)
    if not ok then return false, reason end
    if type(characterID) ~= "string" or characterID == "" then return false, "identity-unknown" end
    if type(observation) ~= "table" or type(verifiedPolicy) ~= "function" then return false, "unverified" end
    local policyOK, verified = pcall(verifiedPolicy, observation)
    if not policyOK or verified ~= true then return false, "unverified" end
    if type(observation.active) ~= "table" or type(observation.stable) ~= "table"
        or observation.completeness ~= "complete"
        or type(observation.coverage) ~= "string" or observation.coverage == ""
        or type(observation.sourceBuild) ~= "string" or observation.sourceBuild == ""
        or not ValidTime(observation.capturedAt) then
        return false, "invalid-observation"
    end
    local itemsOK, validItems = pcall(function()
        if not ValidItems(observation.active) or not ValidItems(observation.stable) then return false end
        local occupied = {}
        for _, pet in ipairs(observation.active) do occupied[pet.slotID] = true end
        for _, pet in ipairs(observation.stable) do
            if occupied[pet.slotID] then return false end
        end
        return true
    end)
    if not itemsOK or not validItems then
        return false, "invalid-observation"
    end
    local existing = root.offlinePets and root.offlinePets.characters[characterID]
    if existing ~= nil and not ValidRecord(existing) then return false, "invalid-record" end
    if existing then
        for _, name in ipairs({ "active", "stable" }) do
            local previous = existing[name]
            if previous and previous.capturedAt > observation.capturedAt then return false, "older-observation" end
        end
    end
    local okActive, active = pcall(CopyForStorage, observation.active, {}, 0)
    local okStable, stable = pcall(CopyForStorage, observation.stable, {}, 0)
    if not okActive or not okStable then return false, "invalid-observation" end
    local stillValid, changedReason = Snapshot.CheckStore(root, target)
    if not stillValid then return false, changedReason end
    local current = root.offlinePets and root.offlinePets.characters[characterID]
    if current ~= existing then return false, "record-changed" end
    local store = root.offlinePets
    if not store then store = { schema = 1, target = target, characters = {} }; root.offlinePets = store end
    store.characters[characterID] = {
        active = { items = active, capturedAt = observation.capturedAt, completeness = "complete",
            coverage = observation.coverage, sourceBuild = observation.sourceBuild },
        stable = { items = stable, capturedAt = observation.capturedAt, completeness = "complete",
            coverage = observation.coverage, sourceBuild = observation.sourceBuild },
        observation = existing and existing.observation or nil,
    }
    return true
end

-- A failed or unverified read may annotate an existing snapshot, but must not
-- create a character, a store, an empty group, or change a successful time.
function Snapshot.RecordAttempt(root, target, characterID, status, attemptedAt)
    local ok, reason = Snapshot.CheckStore(root, target)
    if not ok then return false, reason end
    if type(characterID) ~= "string" or characterID == "" then return false, "identity-unknown" end
    if (status ~= "unavailable" and status ~= "unverified")
        or not ValidTime(attemptedAt) then return false, "invalid-attempt" end
    local store = root.offlinePets
    local record = store and store.characters[characterID]
    if record == nil then return false, "no-snapshot" end
    if not ValidRecord(record) then return false, "invalid-record" end
    if not Snapshot.IsCompleteGroup(record.stable) then return false, "no-snapshot" end
    record.lastAttempt = { status = status, at = attemptedAt }
    return true
end

function Snapshot.Delete(root, target, characterID, context)
    local ok, reason = Snapshot.CheckStore(root, target)
    if not ok then return false, reason end
    local store = root.offlinePets
    local record = store and store.characters[characterID]
    if record == nil then return true end
    if type(record) ~= "table" then return false, "invalid-record" end
    if not context or not context.replay then store.characters[characterID] = nil; return true end
    if not ValidTime(context.deletedAt) then return false, "invalid-deletion" end
    if not ValidRecord(record) then return false, "invalid-record" end
    for _, group in ipairs({ "active", "stable" }) do
        local value = record[group]
        if value ~= nil and (type(value) ~= "table" or type(value.capturedAt) ~= "number") then
            return false, "unknown-capture-time"
        end
    end
    for _, group in ipairs({ "active", "stable" }) do
        local value = record[group]
        if type(value) == "table" and type(value.capturedAt) == "number"
            and value.capturedAt <= context.deletedAt then record[group] = nil end
    end
    if record.observation and record.observation.capturedAt <= context.deletedAt then record.observation = nil end
    if not record.active and not record.stable and not record.observation then store.characters[characterID] = nil end
    return true
end
