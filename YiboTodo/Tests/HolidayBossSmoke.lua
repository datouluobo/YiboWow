_G.YiboTodo = nil

local clock, completed = 1725105600, {}
GetServerTime = function() return clock end
time = GetServerTime
GetGameTime = function() return 12, 0 end
date = function(format)
    if format == "%Y-%m-%d" then return "2024-09-01" end
    if format == "*t" then return { day = 20, hour = 12, min = 0 } end
    return ""
end
IsQuestFlaggedCompleted = function(questID) return completed[questID] == true end
UnitName = function() return "测试角色" end
C_Calendar = {
    GetNumDayEvents = function() return 1 end,
    GetDayEvent = function() return { title = "美酒节" } end,
}

dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Database.lua")
dofile("YiboTodo/Catalog/MonitoringGroupCatalog.lua")
dofile("YiboTodo/Catalog/SpecialActivityCatalog_MoP.lua")
dofile("YiboTodo/Model/Schedule.lua")
dofile("YiboTodo/Providers/Registry.lua")
dofile("YiboTodo/Providers/SpecialActivity.lua")

local Addon = _G.YiboTodo
_G.YiboTodoDB = {}
Addon.Database:Initialize()
Addon.NotifyChanged = function() end
local provider = assert(Addon.Providers.Registry:Get("special-activity"))
local coren = Addon.Catalog.specialActivities["mop.brewfest.coren-direbrew"]

assert(provider:GetProject("test", coren, clock) == nil, "unverified holiday candidate never appears")
coren.registrationStatus, coren.verificationStatus, coren.rewardItemIDs = "registered", "verified", { 999001 }
local project = assert(provider:GetProject("test", coren, clock))
assert(project.state == "actionable" and project.statusText == "尚未观察，按可领取提醒", "an open holiday begins as an actionable reminder")

completed[25483] = true
assert(provider:ObserveCharacter("test"), "quest reconciliation observes the current character")
project = assert(provider:GetProject("test", coren, clock))
assert(project.state == "completed", "the Dungeon Finder completion reconciles the daily holiday reward")

completed[25483] = false
clock = clock + 86400
assert(provider:RecordLoot("test", "你获得了物品：|Hitem:999001:0:0:0|h[节日奖励]|h。", "测试角色"), "the verified reward item marks the current character complete immediately")
project = assert(provider:GetProject("test", coren, clock))
assert(project.state == "completed", "loot evidence uses the independent 07:00 server-day key")
assert(not provider:RecordLoot("test", "你获得了物品：|Hitem:999001:0:0:0|h[节日奖励]|h。", "其他角色"), "another recipient cannot complete the current character")

print("YiboTodo holiday boss smoke passed")
