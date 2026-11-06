local ADDON_NAME, NS = ...
local FRAME = CreateFrame("Frame")
local initialized = false

local function Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. text) end
end

local function IsSupportedClient()
    return type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then return { available = false, reason = "missing" } end
    local result = { pcall(callback, ...) }
    local ok = table.remove(result, 1)
    if not ok then return { available = false, reason = tostring(result[1]) } end
    return { available = result[1] ~= nil, value = result[1] }
end

local function Capture()
    if not IsSupportedClient() then Print(NS and NS:T("wrongClient") or "Mists Classic only."); return end
    local version, build, buildDate, interface = GetBuildInfo()
    local questIndexAPI = (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) or GetQuestLogIndexByID
    local questFlagAPI = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    local questIndex = SafeCall(questIndexAPI, 31488)
    local objectiveCount = { available = false }
    if questIndex.value and tonumber(questIndex.value) and tonumber(questIndex.value) > 0 then
        objectiveCount = SafeCall(GetNumQuestLeaderBoards, tonumber(questIndex.value))
    end
    local factionName = SafeCall(GetFactionInfoByID, 1359)
    local bindingCount = SafeCall(GetItemCount, 18563, true, false, true)
    local finalItemCount = SafeCall(GetItemCount, 19019, true, false, true)
    local equipmentID = SafeCall(GetInventoryItemID, "player", 16)
    local snapshot = {
        version = version, build = build, buildDate = buildDate, interface = tonumber(interface),
        locale = GetLocale and GetLocale() or "unknown",
        questLogIndexAPI = type(questIndexAPI) == "function",
        questCompletionAPI = type(questFlagAPI) == "function",
        quest31488 = { index = questIndex, objectiveCount = objectiveCount },
        blackPrinceFactionName = factionName,
        bindingItemCount = bindingCount, finalItemCount = finalItemCount,
        equipmentSlot16ItemID = equipmentID,
        equipmentAPI = type(GetInventoryItemID) == "function",
    }
    YiboLegendaryProbeDB = YiboLegendaryProbeDB or {}
    YiboLegendaryProbeDB.lastCapture = snapshot
    Print(string.format(NS:T("captured"), NS:T("quest") .. "/" .. NS:T("faction") .. "/" .. NS:T("items") .. "/" .. NS:T("equipment")))
end

local function ReportStatus()
    local snapshot = YiboLegendaryProbeDB and YiboLegendaryProbeDB.lastCapture
    if not snapshot then Print(NS:T("empty")); return end
    Print(string.format("Interface=%s, questIndex=%s, questCompletion=%s, faction=%s, itemCount=%s, equipment=%s",
        tostring(snapshot.interface), tostring(snapshot.questLogIndexAPI), tostring(snapshot.questCompletionAPI),
        tostring(snapshot.blackPrinceFactionName.value), tostring(snapshot.bindingItemCount.value), tostring(snapshot.equipmentAPI)))
end

local function Initialize()
    if initialized then return end
    initialized = true
    SLASH_YIBOLEGENDARYPROBE1 = "/yep"
    SlashCmdList.YIBOLEGENDARYPROBE = function(message)
        local command = tostring(message or ""):match("^%s*(%S+)") or ""
        if command == "capture" then Capture()
        elseif command == "status" then ReportStatus()
        else Print(NS:T("help")) end
    end
end

FRAME:RegisterEvent("ADDON_LOADED")
FRAME:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then return end
    if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
    Initialize()
end)

