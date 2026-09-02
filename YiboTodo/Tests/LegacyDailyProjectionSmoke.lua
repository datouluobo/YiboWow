_G.YiboTodo = nil
local clock = 1725105600
GetServerTime = function() return clock end
time = GetServerTime
GetGameTime = function() return 12, 0 end
date = function() return "2024-09-01" end
GetNumQuestLogEntries = function() return 0 end
GetQuestLogTitle = function() return nil end

dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Database.lua")
dofile("YiboTodo/Catalog/MonitoringGroupCatalog.lua")
dofile("YiboTodo/Catalog/DailyActivityCatalog_MoP.lua")
dofile("YiboTodo/Catalog/DailyActivityCatalog_Legacy.lua")
dofile("YiboTodo/Model/Schedule.lua")
dofile("YiboTodo/Model/Snapshot.lua")
dofile("YiboTodo/Providers/Registry.lua")
dofile("YiboTodo/Providers/DailyQuest.lua")
dofile("YiboTodo/Settings.lua")

local Addon = _G.YiboTodo
_G.YiboTodoDB = {}
Addon.Database:Initialize()
Addon.Core = {
    Characters = {
        GetAll = function() return { { id = "cook", level = 90 } } end,
        GetCurrent = function() return { id = "cook" } end,
    },
    DataDomains = {
        Get = function()
            return { state = "known", data = { primaryProfessions = { [1] = { id = 171, name = "炼金", skillLevel = 600 } } } }
        end,
    },
}

local character = assert(Addon.Snapshot:GetCharacter("cook"))
local cooking = character.monitoringProjects["cooking-daily"]
assert(#cooking == 4, "cooking column projects CTM, MoP, WLK, and TBC entries")
assert(cooking[1].groupID == "mop.halfhill.cooking-daily" and cooking[2].groupID == "ctm.cooking-daily" and cooking[3].groupID == "wlk.cooking-daily" and cooking[4].groupID == "tbc.cooking-daily", "equal-status cooking entries follow their stable catalog order")
print("YiboTodo legacy daily projection smoke passed")
