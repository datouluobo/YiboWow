if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB, Core = _G.YAB, _G.YiboCore
local Targets = {}
YAB.CustomTargets = Targets

local function Text(key, ...)
    return Core.Locale:Get("YiboAltoBoss", key, ...)
end

function Targets:Add(directory, input, name, reset)
    local id = tonumber(input)
    if not id or id <= 0 then return nil, Text("UI.ENTER_A_VALID_NPC_ID") end
    local key = tostring(id)
    if directory[key] then return nil, Text("UI.THIS_NPC_ID_ALREADY_EXISTS") end
    local target = {
        key = "custom:" .. key, id = id, group = "custom", reset = reset,
        name = type(name) == "string" and name ~= "" and name or (Text("UI.CUSTOM_TARGET") .. key),
    }
    directory[key] = target
    return target
end

function Targets:Remove(directory, input)
    local id = tonumber(input)
    if not id or id <= 0 then return nil, Text("UI.ENTER_THE_NPC_ID_TO_REMOVE") end
    local key = tostring(id)
    local target = directory[key]
    if not target then return nil, Text("UI.CUSTOM_NPC_NOT_FOUND") end
    directory[key] = nil
    return target, Text("UI.REMOVED_CUSTOM_TARGET") .. key
end

function Targets:IsActive(record, now, duration)
    if not record or not record.killed then return false end
    local expiresAt = tonumber(record.expiresAt)
    local killedAt = tonumber(record.updatedAt) or 0
    if not expiresAt and duration and killedAt > 0 then
        expiresAt = killedAt + duration
        record.expiresAt = expiresAt
    end
    if expiresAt then return expiresAt > now end
    return duration == nil
end

function Targets:List(directory)
    local targets = {}
    for _, target in pairs(directory) do targets[#targets + 1] = target end
    table.sort(targets, function(a, b) return a.id < b.id end)
    return targets
end
