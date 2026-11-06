local ADDON_NAME, NS = ...
local frame = CreateFrame("Frame")
local initialized = false
local activeCapture

local EVENTS = {
    QUEST_ACCEPTED = true, QUEST_TURNED_IN = true, QUEST_LOG_UPDATE = true,
    GOSSIP_SHOW = true, PLAYER_TARGET_CHANGED = true, LOOT_OPENED = true,
    LOOT_CLOSED = true, CHAT_MSG_LOOT = true, UNIT_SPELLCAST_SUCCEEDED = true,
}

local function Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. NS:T("prefix") .. tostring(text)) end
end

local function IsSupportedClient()
    return type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then return { available = false, reason = "missing" } end
    local result = { pcall(callback, ...) }
    local ok = table.remove(result, 1)
    if not ok then return { available = false, reason = tostring(result[1]) } end
    local value = result[1]
    return { available = value ~= nil, value = value }
end

local function Capture()
    if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
    local version, build, buildDate, interface = GetBuildInfo()
    local quests = { available = false, entries = {} }
    if type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
        quests.available = true
        local count = tonumber(GetNumQuestLogEntries()) or 0
        for index = 1, count do
            local title, level, tag, isHeader, _, complete, frequency, questID = GetQuestLogTitle(index)
            if not isHeader then
                quests.entries[#quests.entries + 1] = { id = questID, title = title, level = level, tag = tag, complete = complete, frequency = frequency }
            end
        end
    end
    local completedCount
    if type(GetQuestsCompleted) == "function" then
        local values = {}
        local ok = pcall(GetQuestsCompleted, values)
        if ok then for _, completed in pairs(values) do if completed then completedCount = (completedCount or 0) + 1 end end end
    end
    local mapID = SafeCall(C_Map and C_Map.GetBestMapForUnit, "player")
    local snapshot = {
        capturedAt = date and date("!%Y-%m-%dT%H:%M:%SZ") or nil,
        version = version, build = build, buildDate = buildDate, interface = tonumber(interface),
        locale = GetLocale and GetLocale() or "unknown", projectID = WOW_PROJECT_ID,
        gameTime = { GetGameTime() }, questLog = quests, completedQuestCount = completedCount,
        mapID = mapID, targetExists = type(UnitExists) == "function" and UnitExists("target") or false,
        mouseoverExists = type(UnitExists) == "function" and UnitExists("mouseover") or false,
        apiTypes = {
            garrisonInfo = type(C_Garrison and C_Garrison.GetGarrisonInfo),
            garrisonPlots = type(C_Garrison and C_Garrison.GetPlots),
            farmPlots = type(GetNumFarmPlots),
            taskQuests = type(C_TaskQuest and C_TaskQuest.GetQuestsForPlayerByMapID),
            questsOnMap = type(C_QuestLog and C_QuestLog.GetQuestsOnMap),
            scenarioStep = type(C_Scenario and C_Scenario.GetStepInfo),
            spellInfo = type(GetSpellInfo),
        },
    }
    if mapID.available and tonumber(mapID.value) then
        snapshot.questsOnMap = SafeCall(C_QuestLog and C_QuestLog.GetQuestsOnMap, tonumber(mapID.value))
        snapshot.taskQuests = SafeCall(C_TaskQuest and C_TaskQuest.GetQuestsForPlayerByMapID, tonumber(mapID.value))
    end
    if activeCapture then
        snapshot.eventCount = #activeCapture.events
        snapshot.events = activeCapture.events
        activeCapture.snapshots[#activeCapture.snapshots + 1] = snapshot
    end
    YiboTodoProbeDB = YiboTodoProbeDB or {}
    YiboTodoProbeDB.lastCapture = snapshot
    Print(NS:T("saved"))
    return snapshot
end

local function OnSlash(message)
    local command = tostring(message or ""):match("^%s*(%S+)") or ""
    if command == "report" then
        local last = YiboTodoProbeDB and YiboTodoProbeDB.lastCapture
        if not last then Print(NS:T("empty")); return end
        Print(string.format("Interface=%s, quests=%d, completed=%s, map=%s, events=%s",
            tostring(last.interface), #(last.questLog.entries or {}), tostring(last.completedQuestCount),
            tostring(last.mapID and last.mapID.value), tostring(last.eventCount or 0)))
    elseif command == "start" then
        if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
        activeCapture = { startedAt = date and date("!%Y-%m-%dT%H:%M:%SZ") or nil, events = {}, snapshots = {} }
        Capture()
        Print(NS:T("started"))
    elseif command == "snapshot" then
        if not activeCapture then Print(NS:T("noCapture")); return end
        Capture()
    elseif command == "finish" then
        if not activeCapture then Print(NS:T("noCapture")); return end
        local capture = activeCapture
        Capture()
        capture.finishedAt = date and date("!%Y-%m-%dT%H:%M:%SZ") or nil
        capture.events = activeCapture.events
        YiboTodoProbeDB = YiboTodoProbeDB or {}
        YiboTodoProbeDB.lastEventCapture = capture
        activeCapture = nil
        Print(string.format(NS:T("finished"), #capture.events))
    else Print(NS:T("help")) end
end

local function Initialize()
    if initialized then return end
    initialized = true
    SLASH_YIBOTODOPROBE1 = "/ytp"
    SlashCmdList.YIBOTODOPROBE = OnSlash
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
        Initialize()
        for probeEvent in pairs(EVENTS) do frame:RegisterEvent(probeEvent) end
    elseif activeCapture and EVENTS[event] then
        activeCapture.events[#activeCapture.events + 1] = { event = event }
        if #activeCapture.events > 100 then table.remove(activeCapture.events, 1) end
        if event == "QUEST_LOG_UPDATE" then Capture() end
    end
end)
