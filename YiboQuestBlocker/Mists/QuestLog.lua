local YQB = _G.YQB

local DAILY_OVERRIDE_IDS = {
    [29433] = true,
    [91710] = true,
    [32642] = true,
    [32643] = true,
    [32645] = true,
    [32646] = true,
    [32647] = true,
    [32648] = true,
    [32649] = true,
    [32650] = true,
    [32653] = true,
    [32657] = true,
    [32658] = true,
    [32659] = true,
    [32942] = true,
    [32943] = true,
    [32944] = true,
    [32945] = true,
}
local function GetQuestFrequencyData(idx)
    local frequency = select(7, GetQuestLogTitle(idx))
    local isRecurring = frequency and frequency > 1
    local isDaily = frequency == 2
    return frequency, isRecurring, isDaily
end

local function GetQuestTypeFlags(questID, idx)
    local frequency, isRecurring, isDaily = GetQuestFrequencyData(idx)
    local isWeekly = frequency == 3
    local isRepeatable = false
    local isMonthly = false

    if DAILY_OVERRIDE_IDS[questID] then
        isDaily = true
        isRecurring = true
    end

    if QuestieDB then
        if QuestieDB.IsDailyQuest and QuestieDB.IsDailyQuest(questID) then
            isDaily = true
            isRecurring = true
        end
        if QuestieDB.IsWeeklyQuest and QuestieDB.IsWeeklyQuest(questID) then
            isWeekly = true
            isRecurring = true
        end
        if QuestieDB.IsRepeatable and QuestieDB.IsRepeatable(questID) then
            isRepeatable = true
            isRecurring = true
        end
        if QuestieDB.IsMonthlyQuest and QuestieDB.IsMonthlyQuest(questID) then
            isMonthly = true
            isRecurring = true
        end
        if QuestieDB.QueryQuestSingle then
            local questFlags = QuestieDB.QueryQuestSingle(questID, "questFlags") or 0
            local specialFlags = QuestieDB.QueryQuestSingle(questID, "specialFlags") or 0

            if questFlags > 0 then
                if QuestieDB.IsDailyQuest and QuestieDB.IsDailyQuest(questID) then
                    isDaily = true
                end
                if QuestieDB.IsWeeklyQuest and QuestieDB.IsWeeklyQuest(questID) then
                    isWeekly = true
                end
                if QuestieDB.IsMonthlyQuest and QuestieDB.IsMonthlyQuest(questID) then
                    isMonthly = true
                end
            end
            if specialFlags > 0 then
                isRepeatable = isRepeatable or (bit.band(specialFlags, 1) ~= 0)
            end
        end
    end

    return {
        frequency = frequency,
        isRecurring = isRecurring or isDaily or isWeekly or isMonthly or isRepeatable,
        isDaily = isDaily,
        isWeekly = isWeekly,
        isMonthly = isMonthly,
        isRepeatable = isRepeatable,
    }
end

function YQB.ReadQuestLog()
    local rows = {}
    for index = 1, GetNumQuestLogEntries() do
        local title, level, _, isHeader, _, complete, _, questID = GetQuestLogTitle(index)
        if not title then break end
        if not isHeader and questID and questID > 0 then
            local row = GetQuestTypeFlags(questID, index)
            row.id, row.name, row.level = questID, title, level
            row.isComplete = complete and complete ~= 0 or false
            rows[#rows + 1] = row
        end
    end
    return rows
end

function YQB.ReadQuestTitle(questID)
    local index = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
    return index and index > 0 and GetQuestLogTitle(index) or nil
end
