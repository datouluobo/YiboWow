local _, ns = ...

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

function Snapshot.CheckStore(root, target)
    if type(root) ~= "table" then return false, "invalid-root" end
    local store = root.offlinePets
    if store == nil then return true end
    if type(store) ~= "table" or store.schema ~= 1 or store.target ~= target
        or type(store.characters) ~= "table" then return false, "invalid-store" end
    return true
end

-- An explicit proof is necessary but not sufficient: callers must pass the
-- target-specific verified policy. No current target has such a policy yet.
function Snapshot.Commit(root, target, characterID, observation, verifiedPolicy)
    local ok, reason = Snapshot.CheckStore(root, target)
    if not ok then return false, reason end
    if type(characterID) ~= "string" or characterID == "" then return false, "identity-unknown" end
    if type(observation) ~= "table" or type(verifiedPolicy) ~= "function"
        or verifiedPolicy(observation) ~= true then return false, "unverified" end
    if type(observation.active) ~= "table" or type(observation.stable) ~= "table"
        or type(observation.capturedAt) ~= "number" then return false, "invalid-observation" end
    local active, stable = Copy(observation.active), Copy(observation.stable)
    if not active or not stable then return false, "invalid-observation" end
    local store = root.offlinePets
    if not store then store = { schema = 1, target = target, characters = {} }; root.offlinePets = store end
    store.characters[characterID] = {
        active = { items = active, capturedAt = observation.capturedAt },
        stable = { items = stable, capturedAt = observation.capturedAt },
    }
    return true
end

function Snapshot.Delete(root, target, characterID, context)
    local ok, reason = Snapshot.CheckStore(root, target)
    if not ok then return false, reason end
    local store = root.offlinePets
    local record = store and store.characters[characterID]
    if type(record) ~= "table" then return true end
    if not context or not context.replay then store.characters[characterID] = nil; return true end
    if type(context.deletedAt) ~= "number" then return false, "invalid-deletion" end
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
    if not record.active and not record.stable then store.characters[characterID] = nil end
    return true
end
