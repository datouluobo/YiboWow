local _, P = ...
P.VERSION, P.MAX_SAMPLES = "0.1.0", 4
local function Pack(...) return { n = select("#", ...), ... } end
function P.Secret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result == true
end
function P.Integer(value, minimum, maximum)
    return not P.Secret(value) and type(value) == "number" and value == value
        and value >= minimum and value <= maximum and value % 1 == 0
end
local function Clean(value, depth, seen)
    if P.Secret(value) then return "<restricted>" end
    local kind = type(value)
    if kind == "nil" then return "<nil>" end
    if kind == "string" then return #value > 2048 and value:sub(1, 2048) .. "<truncated>" or value end
    if kind == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge and value or "<non-finite>"
    end
    if kind == "boolean" then return value end
    if kind ~= "table" then return "<" .. kind .. ">" end
    if depth >= 6 then return "<depth-limit>" end
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local result, count = {}, 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 512 then result.__truncated = true; break end
        if not P.Secret(key) and (type(key) == "string" or type(key) == "number") then
            result[key] = Clean(item, depth + 1, seen)
        end
    end
    seen[value] = nil
    return result
end
function P.Safe(value)
    local ok, result = pcall(Clean, value, 0, {})
    if ok then return result end
    return "<unreadable>"
end
function P.Resolve(path)
    local value = _G
    for segment in path:gmatch("[^.]+") do
        if P.Secret(value) or type(value) ~= "table" then return nil end
        value = value[segment]
    end
    return value
end
-- Only these fixed read-only APIs can be invoked. Operations are inventoried
-- separately and cannot pass this whitelist, even through the test hook.
local READS = {
    "GetBuildInfo", "GetServerTime", "GetTime", "IsLoggedIn", "UnitGUID", "UnitClass", "UnitLevel",
    "InCombatLockdown", "UnitIsDeadOrGhost", "UnitInVehicle", "UnitCastingInfo", "UnitChannelInfo",
    "C_GameRules.GetActiveGameMode", "C_ClassTalents.GetActiveConfigID",
    "C_SpecializationInfo.GetSpecialization", "C_Traits.GetConfigInfo", "C_Traits.GetTreeInfo",
    "C_Traits.GetTreeNodes", "C_Traits.GetTreeCurrencyInfo", "C_Traits.GetNodeInfo",
    "C_Traits.GetNodeCost", "C_Traits.GetEntryInfo", "C_Traits.GetDefinitionInfo", "C_Traits.GetConditionInfo",
    "C_Container.GetContainerNumSlots", "C_Container.GetContainerNumFreeSlots",
    "C_Container.GetContainerItemInfo", "C_Container.GetContainerItemID", "C_Container.GetContainerItemLink",
    "C_Container.GetContainerItemCooldown", "C_Item.GetItemInfo", "C_Item.GetItemSpell", "C_Item.GetItemCount",
    "C_TooltipInfo.GetBagItem",
}
P.reads = {}
for _, path in ipairs(READS) do P.reads[path] = true end
function P.Call(path, ...)
    if not P.reads[path] then return { status = "not_allowlisted" } end
    local fn = P.Resolve(path)
    if type(fn) ~= "function" then return { status = "missing" } end
    local raw = Pack(pcall(fn, ...))
    if not raw[1] then return { status = "error", error = P.Safe(raw[2]) } end
    local result = { status = "returned_unverified", count = raw.n - 1, values = {}, types = {} }
    for index = 2, raw.n do
        result.values[index - 1] = P.Safe(raw[index])
        result.types[index - 1] = P.Secret(raw[index]) and "restricted" or type(raw[index])
    end
    return result
end
function P.First(result)
    if type(result) == "table" and type(result.values) == "table" then return result.values[1] end
end
function P.IDs(value, limit)
    local ids, seen, truncated = {}, {}, false
    if type(value) ~= "table" then return ids, "unreadable" end
    for index = 1, #value do
        local id = value[index]
        if P.Integer(id, 1, 2147483647) and not seen[id] then
            if #ids >= limit then truncated = true; break end
            ids[#ids + 1], seen[id] = id, true
        end
    end
    return ids, value.__truncated and "source_truncated" or truncated and "limit_reached" or "bounded_observation"
end
function P.Target()
    local build = P.Call("GetBuildInfo")
    return P.Integer(WOW_PROJECT_ID, 18, 18) and build.values and build.values[4] == 16001
end
function P.Begin(kind)
    if not P.db then P.Say("blocked", "store_unavailable"); return end
    if not P.inWorld or P.First(P.Call("IsLoggedIn")) ~= true then P.Say("blocked", "world_not_ready"); return end
    if not P.Target() then P.Say("blocked", "target_mismatch"); return end
    local sample = {
        kind = kind, probeVersion = P.VERSION, target = "Forever", semantics = "unverified",
        session = P.db.sessions, build = P.Call("GetBuildInfo"), time = P.Call("GetServerTime"),
        clock = P.Call("GetTime"), guid = P.Call("UnitGUID", "player"), class = P.Call("UnitClass", "player"),
        level = P.Call("UnitLevel", "player"), gameMode = P.Call("C_GameRules.GetActiveGameMode"),
        events = P.Safe(P.events), registration = P.Safe(P.registration), calls = {},
        consistency = "point-in-time observations; no atomic or complete snapshot claim",
    }
    return sample
end
function P.Finish(sample)
    sample.guidAfter = P.Call("UnitGUID", "player")
    sample.sameGUID = type(P.First(sample.guid)) == "string" and sample.guid.types[1] == "string"
        and P.First(sample.guid) == P.First(sample.guidAfter) and sample.guidAfter.types[1] == "string"
    sample.worldAfter = P.inWorld == true and P.First(P.Call("IsLoggedIn")) == true
    P.db.nextSample = P.db.nextSample + 1
    sample.id = P.db.nextSample
    P.db.samples[#P.db.samples + 1] = sample
    while #P.db.samples > P.MAX_SAMPLES do table.remove(P.db.samples, 1) end
    P.Say("sampled", sample.kind, sample.id)
    return sample
end
local function Serialize(value)
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    if kind ~= "table" then return "nil" end
    local keys, parts = {}, { "{" }
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. Serialize(key) .. "]=" .. Serialize(value[key]) .. ",\n" end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end
function P.ReportText()
    if not P.db or #P.db.samples == 0 then return nil end
    return "-- Read-only evidence; includes character GUID. API semantics unverified.\nreturn " .. Serialize({
        schema = 1, probeVersion = P.VERSION, sessions = P.db.sessions, samples = P.db.samples,
        currentEvents = P.Safe(P.events),
    })
end
