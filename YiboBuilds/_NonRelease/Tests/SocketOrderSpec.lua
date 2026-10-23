-- Run from root: lua YiboBuilds/_NonRelease/Tests/SocketOrderSpec.lua
local Setup = dofile("YiboBuilds/_NonRelease/Tests/Core13Host.lua")
local function Find(fn, wanted, seen)
    seen = seen or {}
    if seen[fn] then return end
    seen[fn] = true
    for i = 1, 100 do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then return value end
        if type(value) == "function" then
            local found = Find(value, wanted, seen)
            if found then return found end
        end
    end
end
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
for _, language in ipairs({"zh", "en"}) do
    Setup(language)
    CreateFrame = nil
    local reader = YiboBuilds.SocketReader
    local lines = {}
    C_TooltipInfo = {GetInventoryItem = function() return {lines = lines} end}
    local labels = language == "zh" and {blue = "蓝色插槽", red = "红色插槽", yellow = "黄色插槽", prismatic = "棱彩插槽"}
        or {blue = "Blue Socket", red = "Red Socket", yellow = "Yellow Socket", prismatic = "Prismatic Socket"}
    GetItemStats = function() return {EMPTY_SOCKET_BLUE = 1, EMPTY_SOCKET_RED = 1, EMPTY_SOCKET_YELLOW = 1} end
    local function Rows(types)
        lines = {}
        for _, socketType in ipairs(types) do lines[#lines + 1] = {leftText = labels[socketType] or "Installed gem"} end
    end
    local function Order(slot, link, expected)
        local sockets = reader:Read(slot, link)
        Check(table.concat(sockets, ",") == expected, "unexpected socket order: " .. table.concat(sockets, ","))
    end
    -- Flamebane Helm's real ordered base sockets are BLUE, RED, YELLOW.
    -- Toggle every possible combination of filled holes; text APIs omit filled rows.
    for mask = 0, 7 do
        local visible = {}
        for index, socketType in ipairs({"blue", "red", "yellow"}) do
            if math.floor(mask / 2 ^ (index - 1)) % 2 == 0 then visible[#visible + 1] = socketType end
        end
        Rows(visible)
        Order(1, "item:23516:0:76640:0:0", "blue,red,yellow")
    end
    -- Fixed sequence also survives reversed, delayed, or missing tooltip rows/stats.
    Rows({"yellow", "red", "blue"})
    Order(1, "item:23516", "blue,red,yellow")
    GetItemStats = nil
    Rows({})
    Order(1, "item:23516", "blue,red,yellow")
    Check(reader:NativeCount("item:23516") == 3, "native count cannot depend on empty/filled state")
    Order(1, "item:29028", "meta,blue")
    Order(16, "item:87156", "sha")
    Order(3, "item:88845", "prismatic,prismatic,prismatic")
    -- Blacksmith socket remains THIRD even when only it appears in the tooltip.
    Rows({"prismatic"})
    Order(10, "item:23517", "blue,red,prismatic")
    Rows({"prismatic", "red", "blue"})
    Order(10, "item:23517", "blue,red,prismatic")
    Rows({"prismatic"})
    Order(16, "item:87156", "sha,prismatic")
    -- GemSocket metadata can be present but unknown for filled holes.
    Enum = {TooltipDataLineType = {GemSocket = 10}}
    lines = {{type = 10}, {type = 10}, {type = 10, socketType = "prismatic"}}
    Order(10, "item:23517", "blue,red,prismatic")
    Enum = nil
    -- Legacy scan keeps its own tooltip frame; frame and TooltipInfo can disagree.
    CreateFrame = function(_, name)
        _G[name .. "TextLeft1"] = {GetText = function() return labels.yellow end}
        _G[name .. "TextLeft2"] = {GetText = function() return labels.red end}
        return {SetOwner = function() end, ClearLines = function() end, SetInventoryItem = function() end,
            NumLines = function() return 2 end, Hide = function() end}
    end
    Rows({})
    Order(1, "item:23516", "blue,red,yellow")
    CreateFrame = nil
    -- A saved layout must never be returned by reference for callers to modify.
    Rows({})
    local previous = reader:Read(1, "item:23516")
    previous[1] = "red"
    Order(1, "item:23516", "blue,red,yellow")
    -- Exercise actual equipment snapshot indexes with a hole before an installed gem.
    dofile("YiboBuilds/Snapshot.lua")
    local readEquipment = assert(Find(YiboBuilds.Snapshot.CaptureSlot, "ReadEquipment"))
    GetInventoryItemLink = function(_, slot) return slot == 1 and "item:23516:0:0:76640:0" or nil end
    GetItemInfo = function() return "Item" end
    GetItemGem = function(_, index) if index == 2 then return "Gem", "item:76640" end end
    for _, visible in ipairs({{"blue", "yellow"}, {"yellow"}, {}}) do
        Rows(visible)
        local equipment = readEquipment("socket-order-test")
        local sockets = equipment.slots["1"].gems
        Check(#sockets == 3 and sockets[1].socketType == "blue" and not sockets[1].itemLink, "first empty socket moved")
        Check(sockets[2].socketType == "red" and sockets[2].itemID == 76640, "installed gem index moved")
        Check(sockets[3].socketType == "yellow" and not sockets[3].itemLink, "last empty socket moved")
    end
    GetItemGem, GetInventoryItemLink, GetItemInfo, C_TooltipInfo = nil, nil, nil, nil
end
print("SocketOrderSpec passed: " .. checks .. " checks (zh/en)")
