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
local completedQuestIDs = {}
local questLogCompleteIDs = {}
local completionQueryCount = 0
GetNumQuestLogEntries = function() return #log end
GetQuestLogTitle = function(index)
    local entry = log[index]
    return entry and entry.label, 90, nil, false, false, entry and entry.complete or false, 1, entry and entry.id
end
IsQuestFlaggedCompleted = function(questID)
    completionQueryCount = completionQueryCount + 1
    return completedQuestIDs[questID] == true
end
local targetNPCID = 64337
UnitGUID = function(unit)
    if unit == "target" then return string.format("Creature-0-0-0-0-%d-0000000001", targetNPCID) end
end
C_GossipInfo = { GetAvailableQuests = function() return {} end }
C_QuestLog = {
    IsComplete = function(questID) return questLogCompleteIDs[questID] end,
    GetInfo = function(index)
        local entry = log[index]
        return entry and { questID = entry.infoQuestID or entry.id, title = entry.label, isHeader = false, isComplete = entry.complete } or nil
    end,
}

dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Database.lua")
dofile("YiboTodo/Catalog/ActivityCatalog.lua")
dofile("YiboTodo/Catalog/DailyActivityCatalog_MoP.lua")
dofile("YiboTodo/Catalog/DailyActivityCatalog_Legacy.lua")
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
        GetAll = function() return { { id = "nomi-character", level = 90 } } end,
    },
}

local provider = assert(Addon.Providers.Registry:Get("daily-quest"))
log = { { id = 31333, label = "第2课", complete = false } }
assert(provider:Observe("nomi-character"), "daily provider observes a lesson in the quest log")
local day = assert(provider:GetCurrentDay("nomi-character", clock))
assert(day.questID == 31333 and day.kind == "lesson" and day.state == "actionable", "lesson IDs are tracked as repeating dailies")
local project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "actionable" and project.label == "诺米" and project.dailyTaskLabel == "第2课：方便面", "Nomi keeps a stable group title and exposes today's lesson separately")
local cookingProject = assert(Addon.Snapshot:GetCharacter("nomi-character")).cookingProjects[1]
assert(cookingProject.state == "actionable" and cookingProject.iconKind == "currency" and cookingProject.icon == 402, "cooking group uses the Ironpaw Token currency icon")

log = {}
completedQuestIDs[31333] = true
provider:QueueObserve()
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "completed" and project.questID == 31333, "quest updates record a handed-in daily completion without gossip")
completedQuestIDs[31333] = nil

targetNPCID, completedQuestIDs[30331] = 58714, true
local queriesBeforeCookingReconcile = completionQueryCount
assert(provider:ObserveTargetCompletion("cooking-reconcile"), "the matching Ironpaw master reconciles a completed cooking daily")
local reconciledCooking = assert(provider:GetCurrentCookingDay("cooking-reconcile"))
assert(reconciledCooking.state == "completed", "matching Ironpaw target records the cooking hand-in")
assert(completionQueryCount == queriesBeforeCookingReconcile + 1, "the matching master checks only its own daily")
assert(provider:ObserveTargetCompletion("cooking-reconcile"), "a completed cooking day is already reconciled")
assert(completionQueryCount == queriesBeforeCookingReconcile + 1, "successful cooking reconciliation is not queried again that day")
completedQuestIDs[30331] = nil
targetNPCID = 64337

log = { { id = 30331, label = "高地美味", complete = true } }
assert(provider:ObserveCooking("nomi-character"), "cooking provider observes a completed rotating member")
cookingProject = assert(Addon.Snapshot:GetCharacter("nomi-character")).cookingProjects[1]
assert(cookingProject.state == "in-progress" and cookingProject.label == "MOP 半山烹饪日常", "completed cooking objectives remain visibly ready to turn in")

assert(provider:RecordTurnIn("nomi-character", 30331), "turn-in recognizes the Ironpaw cooking daily")
assert(provider:ObserveCooking("nomi-character"), "cooking provider tolerates the stale pre-turn-in quest log")
cookingProject = assert(Addon.Snapshot:GetCharacter("nomi-character")).cookingProjects[1]
assert(cookingProject.state == "completed", "a stale quest log does not overwrite a cooking hand-in")

log = {}
assert(provider:ObserveCooking("nomi-character"), "cooking provider observes the quest leaving the log")
cookingProject = assert(Addon.Snapshot:GetCharacter("nomi-character")).cookingProjects[1]
assert(cookingProject.state == "completed", "cooking completion remains visible after the quest leaves the log")

Addon.Core.Characters.GetAll = function() return { { id = "low-level", level = 89 } } end
Addon.Snapshot:Invalidate()
local lowLevel = assert(Addon.Snapshot:GetCharacter("low-level"))
assert(#(lowLevel.cookingProjects or {}) == 0 and lowLevel.cookingColumn, "below-level characters show an unavailable cooking cell")
Addon.Core.Characters.GetAll = function() return { { id = "nomi-character", level = 90 } } end

log = { { id = 31337, label = "感谢的礼物", complete = true } }
assert(provider:Observe("nomi-character"), "daily provider observes the final daily")
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "in-progress" and project.questID == 31337, "completed Nomi objectives remain visibly ready to turn in")

log = {}
assert(provider:ObserveNomiGossip("nomi-character"), "Nomi gossip observes the ready-to-turn-in state")
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "in-progress", "Nomi gossip does not turn a pending hand-in into a completed daily")
log = { { id = 31337, label = "感谢的礼物", complete = true } }
assert(provider:RecordTurnIn("nomi-character", 31337), "turn-in persists completion after the quest leaves the log")
assert(provider:Observe("nomi-character"), "Nomi provider tolerates the stale pre-turn-in quest log")
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "completed", "a stale quest log does not overwrite a Nomi hand-in")
assert(Addon.Database:GetProvider("nomi-character", "daily-quest", false).nomiEligible, "a completed repeating daily permanently establishes Nomi eligibility")

clock, gameHour, gameMinute = clock + 86400 * 4, 12, 0
Addon.Snapshot:Invalidate()
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "actionable" and project.eligibilityKnown, "a historical Nomi completion resets to actionable after the server day changes")
log = {}
assert(provider:Observe("nomi-character"), "a post-reset quest-log scan completes")
Addon.Snapshot:Invalidate()
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "actionable" and project.eligibilityKnown, "an empty post-reset scan does not turn an eligible Nomi into unknown")
assert(provider:ObserveNomiGossip("nomi-character"), "talking to Nomi reconciles an established character")
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "completed", "Nomi offering no tracked daily confirms today's completion for an eligible character")

clock, gameHour, gameMinute = clock + 86400, 12, 0
C_GossipInfo.GetAvailableQuests = function() return { { questID = 31334 } } end
assert(provider:ObserveNomiGossip("nomi-character"), "talking to Nomi reads today's offered daily")
project = assert(Addon.Snapshot:GetCharacter("nomi-character")).nomiProjects[1]
assert(project.state == "actionable" and project.questID == 31334, "Nomi gossip makes only the offered lesson actionable")

local graduationCharacter = "graduation-only"
assert(provider:RecordTurnIn(graduationCharacter, 31820), "graduation turn-in is stored")
assert(not provider:GetEligibility(graduationCharacter), "one-time graduation never establishes repeatable Nomi eligibility")

local candidateCharacter = "legacy-candidate"
assert(provider:RecordTurnIn(candidateCharacter, 11665), "legacy fishing turn-in is stored")
local candidateRecord = Addon.Database:GetProvider(candidateCharacter, "daily-quest", false)
local candidateDay = candidateRecord.activityDays["tbc.fishing-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "completed" and candidateDay.questID == 11665, "legacy candidate completion uses its own activity-day cache")
assert(Addon.Catalog.dailyActivities["tbc.fishing-daily"].iconItemID == 35348, "TBC fishing uses the Bag of Fishing Treasures item icon")

log = { { id = 11668, label = "巨型淡水虾", complete = false } }
assert(provider:ObserveLegacyActivities(candidateCharacter), "legacy observer sees the accepted TBC shrimp fishing daily")
candidateDay = candidateRecord.activityDays["tbc.fishing-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "actionable" and candidateDay.questID == 11668, "TBC shrimp daily is detected from its quest ID")

log = { { id = 13833, label = "任意本地化名称", complete = false } }
assert(provider:ObserveLegacyActivities(candidateCharacter), "legacy observer sees the accepted WLK fishing daily")
candidateDay = candidateRecord.activityDays["wlk.fishing-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "actionable" and candidateDay.questID == 13833, "WLK fishing stages are detected by stable quest ID")
assert(Addon.Catalog.dailyActivities["wlk.fishing-daily"].iconItemID == 46007, "WLK fishing uses the blue Bag of Fishing Treasures icon")

log = { { id = 26177, label = "捕捉螃蟹", complete = false } }
assert(provider:ObserveLegacyActivities(candidateCharacter), "legacy observer sees the accepted Stormwind cooking daily")
candidateDay = candidateRecord.activityDays["ctm.cooking-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "actionable" and candidateDay.questID == 26177, "CTM capital cooking is detected by its stable quest ID")

log = { { id = 26543, label = "Clammy Hands", complete = false } }
assert(provider:ObserveLegacyActivities(candidateCharacter), "legacy observer sees an accepted Orgrimmar fishing daily")
candidateDay = candidateRecord.activityDays["ctm.fishing-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "actionable" and candidateDay.questID == 26543, "CTM capital fishing is detected by its stable quest ID")
assert(Addon.Catalog.dailyActivities["ctm.fishing-daily"].iconItemID == 67414, "CTM capital fishing uses its reward-bag icon")

log = { { id = 12961, label = "货单：精致龙骨雕像", complete = false } }
assert(provider:ObserveLegacyActivities(candidateCharacter), "legacy observer scans WLK jewelcrafting daily quest log entries")
candidateDay = candidateRecord.activityDays["wlk.jewelcrafting-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "actionable" and candidateDay.questID == 12961, "WLK intricate bone figurine is detected from the quest log")

log = { { id = 12961, label = "货单：精致龙骨雕像", complete = false } }
questLogCompleteIDs[12961] = true
assert(provider:ObserveLegacyActivities(candidateCharacter), "legacy observer refreshes WLK jewelcrafting completion")
candidateDay = candidateRecord.activityDays["wlk.jewelcrafting-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "in-progress", "quest-ID completion API overrides a stale legacy quest-log completion flag")
questLogCompleteIDs[12961] = nil

log = { { id = 13113, label = "任意本地化名称", complete = false } }
assert(provider:ObserveLegacyActivities(candidateCharacter), "legacy observer sees the active WLK cooking daily")
candidateDay = candidateRecord.activityDays["wlk.cooking-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "actionable" and candidateDay.questID == 13113, "WLK Convention at the Legerdemain is detected as an accepted daily")

log = { { label = "魔术旅馆的集会", complete = false, infoQuestID = 0 } }
assert(provider:ObserveLegacyActivities(candidateCharacter), "legacy observer ignores a task name when its quest ID is absent")
candidateDay = candidateRecord.activityDays["wlk.cooking-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "unknown", "a localized task name never maps to a tracked daily without its quest ID")

log = {}
completedQuestIDs[13113] = true
assert(provider:ObserveLegacyCompletions(candidateCharacter), "legacy cooking hand-in reconciles from the daily completion flag")
candidateDay = candidateRecord.activityDays["wlk.cooking-daily"][Addon.Model.Schedule:ServerDay(Addon:Now(), 7)]
assert(candidateDay.state == "completed" and candidateDay.questID == 13113, "WLK cooking hand-in is no longer left ready to turn in")
completedQuestIDs[13113] = nil

print("YiboTodo daily quest smoke passed")
