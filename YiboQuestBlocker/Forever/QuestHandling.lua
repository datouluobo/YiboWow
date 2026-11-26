local YQB = _G.YQB
local QuestLog = C_QuestLog
local pending, results = {}, {}
local scheduled, verifying, autoAbandonRunning

local function Report(id, key)
    results[id] = key
    YQB.ReportMessage(YQB.T("FOREVER.ABANDON_REPORT", YQB.GetQuestName(id) or tostring(id), YQB.T(key)))
end

local function InteractionOpen()
    return (GossipFrame and GossipFrame:IsShown()) or (QuestFrame and QuestFrame:IsShown())
        or (InCombatLockdown and InCombatLockdown())
end

local function AbandonConfirmationOpen()
    return StaticPopup_FindVisible and (StaticPopup_FindVisible("ABANDON_QUEST")
        or StaticPopup_FindVisible("ABANDON_QUEST_WITH_ITEMS"))
end

local function TryAbandon(id)
    if YQB.GetQuestProtection(id) or not QuestLog.CanAbandonQuest or not QuestLog.CanAbandonQuest(id) then
        return "FOREVER.ABANDON_MANUAL"
    end
    if not (QuestLog.GetSelectedQuest and QuestLog.SetSelectedQuest and QuestLog.SetAbandonQuest
        and QuestLog.GetAbandonQuest and QuestLog.AbandonQuest) then
        return "FOREVER.ABANDON_MANUAL"
    end
    local selected = QuestLog.GetSelectedQuest()
    QuestLog.SetSelectedQuest(id)
    QuestLog.SetAbandonQuest()
    if QuestLog.GetAbandonQuest() ~= id then
        QuestLog.SetSelectedQuest(selected or 0)
        return "FOREVER.ABANDON_MANUAL"
    end
    local ok = pcall(QuestLog.AbandonQuest)
    QuestLog.SetSelectedQuest(selected or 0)
    if not ok then return "FOREVER.ABANDON_MANUAL" end
end

local Schedule
local function Drain()
    if verifying or not YQB.IsAutoAbandonEnabled() or InteractionOpen() then return end
    if AbandonConfirmationOpen() then
        Schedule(1)
        return
    end
    local id = next(pending)
    while id and (not YQB.IsQuestBlocked(id) or not YQB.IsQuestInLog(id)) do
        pending[id] = nil
        id = next(pending)
    end
    if not id then return end

    pending[id] = nil
    local ok, status = pcall(TryAbandon, id)
    if not ok or status then
        Report(id, ok and status or "FOREVER.ABANDON_MANUAL")
        YQB.NotifyCorePageChanged(true)
        Schedule()
        return
    end
    local attempt = { id = id }
    verifying = attempt
    C_Timer.After(1, function()
        if verifying ~= attempt then return end
        verifying = nil
        if YQB.IsQuestBlocked(id) then
            Report(id, YQB.IsQuestInLog(id) and "FOREVER.ABANDON_MANUAL" or "FOREVER.ABANDON_DONE")
        end
        YQB.NotifyCorePageChanged(true)
        Schedule()
    end)
end

Schedule = function(delay)
    if scheduled or verifying or not next(pending) then return end
    local ticket = {}
    scheduled = ticket
    C_Timer.After(delay or 0.35, function()
        if scheduled ~= ticket then return end
        scheduled = nil
        Drain()
    end)
end

local function Queue(id)
    if YQB.IsAutoAbandonEnabled() and YQB.IsQuestBlocked(id) then
        results[id] = nil
        pending[id] = true
        Schedule()
    end
end

local function QueueExistingRules()
    local db = YQB.GetDatabase()
    for id in pairs(db.globalBlocked) do if YQB.IsQuestInLog(id) then Queue(id) end end
    local character = db.characterData[YQB.GetCurrentCharacterID()]
    for id in pairs(character.blocked or {}) do if YQB.IsQuestInLog(id) then Queue(id) end end
end

function YQB.OnRuleChanged(id, characterID)
    if characterID and characterID ~= YQB.GetCurrentCharacterID() then return end
    if YQB.IsQuestInLog(id) then Queue(id) end
end

function YQB.OnModeChanged()
    YQB.UpdateQuestRejection()
    local enabled = YQB.IsAutoAbandonEnabled()
    if autoAbandonRunning == enabled then return end
    autoAbandonRunning = enabled
    pending, results, scheduled, verifying = {}, {}, nil, nil
    if enabled then QueueExistingRules() end
end

function YQB.GetQuestHandlingStatus(id)
    local result = results[id]
    if result ~= "FOREVER.ABANDON_DONE" and not YQB.IsQuestInLog(id) then return nil end
    return YQB.IsQuestBlocked(id) and result or nil
end

function YQB.OnQuestHandlingEvent(event, id)
    if event == "QUEST_ACCEPTED" then
        Queue(id)
    elseif event == "QUEST_TURNED_IN" then
        pending[id], results[id] = nil, nil
        if verifying and verifying.id == id then verifying = nil; Schedule() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        autoAbandonRunning = nil
        YQB.OnModeChanged()
    else
        Schedule()
    end
end
