local YQB = _G.YQB
local QuestLog = C_QuestLog
local Frequency = Enum and Enum.QuestFrequency

function YQB.CanReadQuestLog()
    return Frequency and QuestLog and QuestLog.GetInfo and QuestLog.GetNumQuestLogEntries
        and QuestLog.IsComplete and QuestLog.IsRepeatableQuest and QuestLog.IsOnQuest and QuestLog.GetTitleForQuestID
        and C_GossipInfo and C_GossipInfo.GetAvailableQuests and GetQuestID and GetTitleText
end

function YQB.ReadQuestTitle(id)
    return QuestLog.GetTitleForQuestID(id)
end

local function LogRow(info)
    if not info or info.isHeader or info.isHidden or not info.questID or info.questID <= 0 then return end
    local id = info.questID
    local frequency = info.frequency
    local repeatable = QuestLog.IsRepeatableQuest(id)
    local isRecurring
    if repeatable or frequency == Frequency.Daily or frequency == Frequency.Weekly
        or frequency == Frequency.ResetByScheduler then
        isRecurring = true
    elseif frequency == Frequency.Default then
        isRecurring = false
    end
    return {
        id = id, name = info.title, level = info.level,
        isComplete = QuestLog.IsComplete(id), isRecurring = isRecurring,
        isDaily = frequency == Frequency.Daily, isWeekly = frequency == Frequency.Weekly,
    }
end

function YQB.ReadQuestLog()
    local rows, hasCollapsed = {}, false
    for index = 1, QuestLog.GetNumQuestLogEntries() do
        local info = QuestLog.GetInfo(index)
        if info and info.isHeader and info.isCollapsed then hasCollapsed = true end
        local row = LogRow(info)
        if row then rows[#rows + 1] = row end
    end
    return rows, hasCollapsed
end

function YQB.IsQuestInLog(id)
    return QuestLog.IsOnQuest(id)
end
