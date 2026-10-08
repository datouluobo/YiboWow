-- Run from the repository root: lua YiboBuilds/_NonRelease/Tests/EquipmentAugmentSpec.lua
local function FindUpvalue(fn, wanted, visited)
    visited = visited or {}
    if visited[fn] then return end
    visited[fn] = true
    for index = 1, 100 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == wanted then return value end
        if type(value) == "function" then
            local found = FindUpvalue(value, wanted, visited)
            if found then return found end
        end
    end
end
YiboBuilds = {}
YiboCore = { UITheme = { Colors = {}, Font = {} } }
dofile("YiboBuilds/Data/EngineeringCatalog.lua")
dofile("YiboBuilds/Data/EngineeringApply.lua")
dofile("YiboBuilds/Data/ApplyTargets.lua")
dofile("YiboBuilds/Snapshot.lua")
dofile("YiboBuilds/AccountPage.lua")
local readEngineering = assert(FindUpvalue(YiboBuilds.Snapshot.CaptureSlot, "ReadEngineeringEnchantID"))
local candidates = assert(FindUpvalue(YiboBuilds.AccountPage.Refresh, "AugmentCandidates"))
local tooltipLines = {}
C_TooltipInfo = { GetInventoryItem = function() return { lines = tooltipLines } end }
local function Detect(slot, lines, expected)
    tooltipLines = lines
    assert(readEngineering(slot, { "99086", "4430" }, "item:99086:4430") == expected,
        "unexpected engineering detection for slot " .. slot)
end
Detect(10, { { leftText = "使用：使你的智力、敏捷或力量提高|cff00ff001,920|r点，持续 10 秒。(1分钟冷却)" } }, 4898)
Detect(15, { { leftText = "使用：降低你的坠落速度，持续 2 分钟。(3分钟冷却)" } }, 4897)
Detect(10, { { leftText = "Use: Increases your Strength by 1,920 for 10 sec." } }, 4898)
Detect(10, { { leftText = "Use: Increases your damage by 1920 for 10 sec." } }, nil)
Detect(10, { { leftText = "没有工程强化" } }, nil)
Detect(10, { { spellID = 141331, leftText = "使智力提高1920点，持续10秒" } }, 5063)
Detect(6, { { leftText = "降低你的坠落速度，持续2分钟" } }, nil)
-- Legacy GameTooltip fallback carries the same colored use text.
C_TooltipInfo = nil
local nativeText = "使用：使你的智力、敏捷或力量提高|cff00ff001,920|r点，持续 10 秒。"
CreateFrame = function()
    YiboBuildsEnchantScanTooltipTextLeft1 = { GetText = function() return nativeText end }
    return { SetOwner = function() end, ClearLines = function() end, SetInventoryItem = function() end,
        NumLines = function() return 1 end, Hide = function() end }
end
assert(readEngineering(10, {}, "item:99086:4430") == 4898)
nativeText = "使用：降低你的坠落速度，持续 2 分钟。(3分钟冷却)"
assert(readEngineering(15, {}, "item:89076:4421") == 4897)
CreateFrame = nil
-- A physical bag buckle needs no blacksmith profession or learned recipe.
GetItemInfo = function() return "Belt", nil, nil, nil, nil, nil, nil, nil, "INVTYPE_WAIST", nil, nil, 4, 3 end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemLink = function() return "item:90046" end,
    GetContainerItemInfo = function() return { stackCount = 1 } end,
}
local belt = { itemLink = "item:99100", beltBuckle = { state = "base-missing" } }
local available = candidates(6, belt)
assert(#available == 1 and available[1].source.itemID == 90046 and available[1].bag.count == 1)
belt.beltBuckle.state = "installed"
assert(#candidates(6, belt) == 0, "installed buckle must not offer another socket")
belt.beltBuckle.state = "base-missing"
C_Container.GetContainerNumSlots = function() return 0 end
assert(#candidates(6, belt) == 0, "absent bag buckle must not be offered")
-- Opening equipment details uses this production scheduler: preserve the
-- settled rescan even if another event schedules a glyph-only capture.
local pending, captures = {}, {}
C_Timer = { After = function(delay, callback) pending[#pending + 1] = { delay, callback } end }
YiboBuilds.Snapshot.Capture = function(_, reason, _, parts) captures[#captures + 1] = { reason, parts } end
YiboBuilds.Snapshot:ScheduleEquipmentCapture()
YiboBuilds.Snapshot:ScheduleCapture("glyph-update", 0.1, { glyphs = true })
pending[1][2]()
pending[3][2]()
assert(#captures == 1 and captures[1][2].equipment and captures[1][2].glyphs)
pending[2][2]()
pending[4][2]()
assert(#captures == 2 and captures[2][2].equipment)
-- Release requirements must stop initialization before registering any UI.
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
dofile("YiboBuilds/Bootstrap.lua")
dofile("YiboBuilds/CoreIntegration.lua")
local apiVersion, capable, registrations, definition = 9, true, 0
YiboCore.CheckAPIVersion = function(_, required) return apiVersion >= required end
YiboCore.HasCapability = function(_, name, version) return capable and name == "account-view" and version == 2 end
YiboCore.Characters = {}
YiboCore.RegisterAddon = function() registrations = registrations + 1; return true end
YiboCore.AccountView = { RegisterPage = function(_, _, value) definition = value; return {} end }
YiboCore.Entry = { RegisterBusinessEntry = function() return {} end }
YiboBuilds.AccountPage.GetFields = function() return {} end
local ok, err = YiboBuilds.CoreIntegration:Initialize()
assert(not ok and err:find("v10", 1, true) and registrations == 0)
apiVersion, capable = 10, false
assert(not YiboBuilds.CoreIntegration:Initialize() and registrations == 0)
capable = true
assert(YiboBuilds.CoreIntegration:Initialize() and registrations == 1 and definition.firstUseTip)
assert(YiboBuilds.CoreIntegration:Initialize() and registrations == 1, "registration must be idempotent")
print("EquipmentAugmentSpec passed: tooltip detection, bag buckle candidates, equipment rescan, Core requirements")
