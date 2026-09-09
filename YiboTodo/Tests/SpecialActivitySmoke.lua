_G.YiboTodo = nil
local clock = 1725105600
GetServerTime = function() return clock end
time = GetServerTime
date = function(format, value)
    if format == "%Y-%m-%d" then return "2024-09-01" end
    if format == "%H" then return "12" end
    if format == "%M" then return "00" end
    return ""
end
local questLog, completed = {}, {}
GetNumQuestLogEntries = function() return #questLog end
GetQuestLogTitle = function(index)
    local entry = questLog[index]
    return entry and entry.label, 90, nil, false, false, entry and entry.complete or false, 3, entry and entry.id
end
IsQuestFlaggedCompleted = function(id) return completed[id] == true end

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

questLog = { { id = 31443, label = "飞行虎皮丝足鱼", complete = false } }
assert(provider:ObserveCharacter("fish-character"), "special provider observes the active first fish")
local first = Addon.Catalog.specialActivities["mop.nat-pagle.flying-tiger-gourami"]
assert(first.iconItemID == 86542 and first.defaultEnabled == true, "first Nat fish defaults on with its verified item icon")
assert(provider:GetProject("fish-character", first, clock).state == "actionable", "first fish is independently actionable")
assert(provider:RecordTurnIn("fish-character", 31443), "first fish turn-in is recognized")
assert(provider:GetProject("fish-character", first, clock).state == "completed", "first fish completion is retained")
local second = Addon.Catalog.specialActivities["mop.nat-pagle.spinefish-alpha"]
assert(second.iconItemID == 86544, "second Nat fish uses its verified item icon")
assert(provider:GetProject("fish-character", second, clock).state == "actionable", "second fish is not completed with the first fish")
assert(Addon.Catalog.specialActivities["mop.nat-pagle.mimic-octopus"].iconItemID == 86545, "third Nat fish uses its verified item icon")

local brilltron = Addon.Catalog.specialActivities["mop.brilltron-4000"]
assert(provider:RecordTurnIn("first-character", 31752), "brilltron turn-in is recognized")
assert(provider:GetProject("first-character", brilltron, clock).state == "completed", "owner sees brlltron completed")
assert(provider:GetProject("second-character", brilltron, clock).state == "not-applicable", "other characters do not receive duplicate account work")
print("YiboTodo special activity smoke passed")
