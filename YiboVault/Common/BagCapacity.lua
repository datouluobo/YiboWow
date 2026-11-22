local Addon = _G.YiboVault
local Capacity = {}
Addon.BagCapacity = Capacity

-- Native MoP container family masks. Keep client identifiers in the target layer.
-- This is a label lookup, not a catalog of obtainable bags.
local families = {
    [0] = "GENERAL", [1] = "ARROWS", [2] = "BULLETS", [4] = "SOUL",
    [8] = "LEATHER", [16] = "INSCRIPTION", [32] = "HERBS", [64] = "ENCHANTING",
    [128] = "ENGINEERING", [256] = "KEYS", [512] = "GEMS", [1024] = "MINING",
    [2048] = "BOUND", [4096] = "PETS", [8192] = "TOKENS", [16384] = "QUEST",
    [32768] = "FISHING", [65536] = "COOKING",
}

local function ValidMask(value)
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

function Capacity:Format(area)
    if not area or not area.totalSlots then return "" end
    local prefix = area.completeCapacity and "" or Addon:T("TEXT.KNOWN_A96951")
    if area.freeSlots ~= nil then
        return Addon:T("CAPACITY.TOTAL_FREE", prefix, area.freeSlots, area.totalSlots)
    end
    return Addon:T("TEXT.S_TOTAL_SLOTS_D_E4410B", prefix, area.totalSlots)
end

function Capacity:Group(area, areaID)
    if type(area) ~= "table" then return {} end
    local grouped = {}
    local function Add(kind, count, order)
        if type(count) ~= "number" or count <= 0 or count % 1 ~= 0 then return end
        local key = "CAPACITY." .. kind
        local entry = grouped[key]
        if not entry then
            entry = { emptySlots = 0, emptyLabelKey = key, order = order }
            grouped[key] = entry
        end
        entry.emptySlots = entry.emptySlots + count
    end
    if areaID ~= "bags" and areaID ~= "bank" then
        Add("GENERAL", area.freeSlots, 0)
    elseif type(area.locations) == "table" then
        for _, location in ipairs(area.locations) do
            local cap = location.capacity
            if type(cap) == "table" and type(cap.totalSlots) == "number"
                and cap.totalSlots > 0 and type(cap.freeSlots) == "number"
                and cap.freeSlots <= cap.totalSlots then
                local mask = cap.bagType
                local valid = ValidMask(mask)
                local kind = valid and (families[mask] or "SPECIAL") or "UNKNOWN"
                Add(kind, cap.freeSlots, families[mask] and mask or (valid and 1000000000 or 1000000001))
            end
        end
    else
        -- Older snapshots can know a total without retaining its container types.
        Add("UNKNOWN", area.freeSlots, 1000000001)
    end
    local result = {}
    for _, entry in pairs(grouped) do result[#result + 1] = entry end
    table.sort(result, function(a, b) return a.order < b.order end)
    return result
end
