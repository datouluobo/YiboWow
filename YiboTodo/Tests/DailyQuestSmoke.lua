_G.YiboTodo = nil
local clock, gameHour, gameMinute = 1725105600, 12, 0
GetServerTime = function() return clock end
time = GetServerTime
GetGameTime = function() return gameHour, gameMinute end
date = function(format, value)
    if format == "%Y-%m-%d" then return string.format("2024-09-%02d", 1 + math.floor(((value or clock) - 1725105600) / 86400)) end
    return ""
end

local log = {}
GetNumQuestLogEntries = function() return #log end
GetQuestLogTitle = function(index)
    local entry = log[index]
    return entry and entry.label, 90, nil, false, false, entry and entry.complete or false, 1, entry and entry.id
end

dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Database.lua")
dofile("YiboTodo/Catalog/ActivityCatalog.lua")
dofile("YiboTodo/Catalog/DailyActivityCatalog_MoP.lua")
dofile("YiboTodo/Catalog/Validator.lua")
dofile("YiboTodo/Model/Schedule.lua")
dofile("YiboTodo/Model/Snapshot.lua")
dofile("YiboTodo/Providers/Registry.lua")
dofile("YiboTodo/Providers/DailyQuest.lua")

local Addon = _G.YiboTodo
_G.YiboTodoDB = {}
Addon.Database:Initialize()
Addon.Settings = { GetMode = function() return "display" end }
Addon.Core = {
    Characters = {
        GetCurrent = function() return { id = "nomi-character" } end,
        GetAll = function() return { { id = "nomi-character" } } end,
    },
}

local provider = assert(Addon.Providers.Registry:Get("daily-quest"))
log = { { id = 31333, label = "第2课", complete = false } }
assert(provider:Observe("nomi-character"), "daily provider observes a lesson in the quest log")
local day = assert(provider:GetCurrentDay("nomi-character", clock))
assert(day.questID == 31333 and day.kind == "lesson" and day.state == "actionable", "lesson IDs are tracked as repeating dailies")
local project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "actionable" and project.label == "第2课：方便面", "Nomi has a separate snapshot project")

log = { { id = 31337, label = "感谢的礼物", complete = true } }
assert(provider:Observe("nomi-character"), "daily provider observes the final daily")
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "completed" and project.questID == 31337, "final daily completion is projected")

log = {}
assert(provider:RecordTurnIn("nomi-character", 31337), "turn-in persists completion after the quest leaves the log")
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "completed", "turn-in completion remains visible for the server day")
assert(Addon.Database:GetProvider("nomi-character", "daily-quest", false).nomiEligible.questID == 31337, "a completed repeating daily permanently establishes Nomi eligibility")

clock, gameHour, gameMinute = clock + 86400 * 4, 12, 0
Addon.Snapshot:Invalidate()
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "actionable" and project.inferredFromEligibility, "Nomi eligibility remains actionable across later server days")

local graduationCharacter = "graduation-only"
assert(provider:RecordTurnIn(graduationCharacter, 31820), "graduation turn-in is stored")
assert(not provider:GetEligibility(graduationCharacter), "one-time graduation never establishes repeatable Nomi eligibility")

print("YiboTodo daily quest smoke passed")
