_G.YiboTodo = nil

local clock = 1725105600
GetServerTime = function() return clock end
time = GetServerTime

local completed, questLog = {}, {}
GetQuestsCompleted = function(target)
    for questID, value in pairs(completed) do target[questID] = value end
end
GetNumQuestLogEntries = function() return #questLog end
GetQuestLogTitle = function(index)
    local entry = questLog[index]
    return entry and entry.label, 90, nil, false, false, entry and entry.complete or false, 3, entry and entry.id
end
UnitExists = function() return false end

dofile("YiboTodo/Namespace.lua")
local Addon = _G.YiboTodo
Addon.db = { diagnostics = {} }
Addon.Print = function() end
dofile("YiboTodo/Probe.lua")

strtrim = function(value) return value end
SlashCmdList = {}
dofile("YiboTodo/Commands.lua")

local Probe = Addon.Probe
local ok, started = Probe:StartSpecial("nat")
assert(ok and started.label == "纳特·帕格（纳格兰三条鱼）", "nat probe starts with the Nagrand three-fish label")
Probe:CaptureEvent("UPDATE_MOUSEOVER_UNIT")
assert(#Probe.specialCapture.eventTrace == 0, "unrelated events do not enter a special probe")
Probe:CaptureEvent("CHAT_MSG_LOOT", "你获得了物品：[大海鲱]。")
assert(#Probe.specialCapture.eventTrace == 0, "nat probe excludes unrelated loot messages")
questLog = { { id = 29512, label = "救治伤员", complete = false } }
Probe:CaptureEvent("QUEST_LOG_UPDATE")
assert(#Probe.specialCapture.snapshots == 2 and Probe.specialCapture.snapshots[2].questLogDelta.added[1] == "29512", "quest-log updates capture an accepted candidate task")
questLog[1].complete = true
Probe:CaptureEvent("QUEST_LOG_UPDATE")
assert(#Probe.specialCapture.snapshots == 3 and Probe.specialCapture.snapshots[3].questLogDelta.completed[1] == "29512", "quest-log updates capture completed objectives")
assert(#Probe.specialCapture.eventTrace == 2, "only relevant quest-log events enter a nat probe")
local finished, capture = Probe:FinishSpecial("nat")
assert(finished and capture.finishedAt and Probe.specialCapture == nil, "finishing stores diagnostics and clears the active nat session")
assert(Addon.db.diagnostics.specialActivityCapture == capture, "special probe writes diagnostics only")

completed[100] = true
assert(Probe:StartSpecial("nat"), "nat probe can start another capture session")
completed[101] = true
local snapOK, natSnapshot = Probe:SnapshotSpecial("nat")
assert(snapOK and natSnapshot.completedQuestDelta and #natSnapshot.completedQuestDelta.added == 1, "nat probe reports completed-quest deltas")
assert(Probe:FinishSpecial("nat"), "nat probe finishes")
assert(Probe:StartSpecial("brilltron"), "brilltron probe starts")
Probe:CaptureEvent("CHAT_MSG_LOOT", "你获得了物品：[布林顿礼包]。")
assert(#Probe.specialCapture.eventTrace == 1, "brilltron probe keeps loot messages")
assert(Probe:FinishSpecial("brilltron"), "brilltron probe finishes")
assert(not Probe:StartSpecial("unknown"), "unknown special probes are rejected")

SlashCmdList.YIBOTODO("probe nat-start")
assert(Probe.specialCapture and Probe.specialCapture.kind == "nat", "slash command starts a named special probe")
SlashCmdList.YIBOTODO("probe")
assert(Probe.specialCapture and Probe.specialCapture.kind == "nat", "generic probe command does not start a legacy diagnostic")
SlashCmdList.YIBOTODO("probe nat-finish")

print("YiboTodo special activity probe smoke passed")
