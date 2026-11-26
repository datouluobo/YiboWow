local YQB = _G.YQB
local Core = _G.YiboCore
local ADDON_NAME = ...

function YQB.StartQuestRuntime()
    local recentBlockNotices = {}
    local autoAbandonQueue = {}
    local autoAbandonSet = {}
    local autoAbandonTimerToken = 0
    local autoAbandonTimerActive = false
    local autoAbandonWaitingForClose = false
    local autoAbandonProcessing = false
    local reportedUnabandonable = {}
    local syncThrottleUntil = 0
    local MaybeStartAutoAbandonTimer
    local directRejectActions = {}
    local interactionSerial = 0
    local activeBatch
    local guardedFunctions = {}
    local selectionGuards = {}
    local knownAutomation = {
        ["Questie"] = {
            label = "Questie",
            continuationVerified = false,
            continuationStatus = "incompatible",
            continuationNote = _G.YQB.T("CHAT.TURN_OFF_AUTO_ACCEPT"),
        },
        -- !Pig enumerates every available quest in a single QUEST_GREETING pass.
        -- Filtering SelectAvailableQuest is a verified selection-layer adapter:
        -- it retains !Pig's own non-trivial filter while preventing blocked IDs
        -- from replacing the allowed quest detail later in that same loop.
        ["!Pig"] = {
            label = "!Pig",
            continuationVerified = true,
            continuationStatus = "supported",
            continuationNote = _G.YQB.T("CHAT.AUTO_ACCEPT_SUPPORTED"),
        },
        ["NDui"] = {
            label = "NDui QuickQuest",
            continuationVerified = true,
            continuationStatus = "supported",
            continuationNote = _G.YQB.T("CHAT.AUTO_ACCEPT_SUPPORTED"),
        },
        ["Leatrix_Plus"] = {
            label = "Leatrix Plus",
            continuationVerified = false,
            continuationStatus = "incompatible",
            continuationNote = _G.YQB.T("CHAT.TURN_OFF_AUTO_ACCEPT"),
        },
        ["Blitz"] = { label = "Blitz", continuationVerified = false },
    }
    local function IsKnownAddonLoaded(addonName)
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            return C_AddOns.IsAddOnLoaded(addonName) == true
        end
        return IsAddOnLoaded and IsAddOnLoaded(addonName) == true
    end

    local function GetKnownAddonVersion(addonName)
        if C_AddOns and C_AddOns.GetAddOnMetadata then
            return C_AddOns.GetAddOnMetadata(addonName, "Version")
        end
        return GetAddOnMetadata and GetAddOnMetadata(addonName, "Version") or nil
    end

    YQB.GetAutomationAdapters = function()
        local result = {}
        for addonName, adapter in pairs(knownAutomation) do
            local loaded = IsKnownAddonLoaded(addonName)
            result[#result + 1] = {
                addon = addonName, label = adapter.label, loaded = loaded,
                version = loaded and GetKnownAddonVersion(addonName) or nil,
                continuationVerified = adapter.continuationVerified,
                continuationStatus = adapter.continuationStatus or (adapter.continuationVerified and "supported" or "unverified"),
                continuationNote = adapter.continuationNote,
            }
        end
        table.sort(result, function(a, b) return a.label < b.label end)
        return result
    end
    local function CurrentInteractionIdentity()
        if UnitGUID then
            local guid = UnitGUID("npc")
            if guid then return guid end
        end
        return "unknown-npc"
    end

    local function EndQuestBatch(reason)
        if activeBatch and reason then YQB.AddDiagnostic(_G.YQB.T("STATUS.AUTO_CONTINUE_STOPPED"), activeBatch.expectedQuestID, reason) end
        if activeBatch then
            local prefix = tostring(activeBatch.serial) .. ":"
            for key in pairs(directRejectActions) do
                if string.sub(key, 1, #prefix) == prefix then directRejectActions[key] = nil end
            end
        end
        activeBatch = nil
    end

    local function StartRejectedBatch(questID)
        local identity = CurrentInteractionIdentity()
        if not activeBatch or activeBatch.identity ~= identity or activeBatch.characterID ~= YQB.GetCurrentCharacterID() then
            interactionSerial = interactionSerial + 1
            activeBatch = {
                identity = identity, characterID = YQB.GetCurrentCharacterID(), serial = interactionSerial,
                rejected = {}, maxActions = 1, actions = 0,
            }
        end
        if activeBatch.rejected[questID] then return false end
        activeBatch.rejected[questID] = true
        activeBatch.expectedQuestID = questID
        activeBatch.actions = activeBatch.actions + 1
        return true
    end

    local function IsQuestInteractionVisible()
        return (QuestFrame and QuestFrame:IsShown())
            or (GossipFrame and GossipFrame:IsShown())
    end

    local function IsQuestStillInLog(questID)
        local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
        return idx and idx > 0
    end

    local function RemoveAutoAbandonQuest(questID)
        if not questID or not autoAbandonSet[questID] then
            return
        end

        autoAbandonSet[questID] = nil
        for index = #autoAbandonQueue, 1, -1 do
            if autoAbandonQueue[index] == questID then
                table.remove(autoAbandonQueue, index)
            end
        end
    end

    local function PruneAutoAbandonQueue()
        for index = #autoAbandonQueue, 1, -1 do
            local questID = autoAbandonQueue[index]
            if not questID or not YQB.IsQuestBlocked(questID) or not IsQuestStillInLog(questID) then
                autoAbandonSet[questID] = nil
                table.remove(autoAbandonQueue, index)
            end
        end
    end

    local function EnqueueAutoAbandonQuest(questID)
        if not questID or autoAbandonSet[questID] then
            return false
        end

        autoAbandonSet[questID] = true
        autoAbandonQueue[#autoAbandonQueue + 1] = questID
        return true
    end

    local function ResetAutoAbandonState()
        autoAbandonTimerToken = autoAbandonTimerToken + 1
        autoAbandonTimerActive = false
        autoAbandonWaitingForClose = false
        autoAbandonProcessing = false
        wipe(autoAbandonQueue)
        wipe(autoAbandonSet)
    end

    local function HasRejectedQuestInLog()
        local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
        for idx = 1, numEntries do
            local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(idx)
            if not isHeader and questID and YQB.IsQuestBlocked(questID) then
                return true
            end
        end
        return false
    end

    local function SyncRejectedQuestsToQueue(force)
        if not YQB.IsAutoAbandonEnabled() then
            wipe(autoAbandonQueue)
            wipe(autoAbandonSet)
            autoAbandonWaitingForClose = false
            syncThrottleUntil = 0
            return 0
        end

        -- 节流：非强制调用时，2秒内不重复扫描
        if not force and GetTime() < syncThrottleUntil then
            return -1
        end
        syncThrottleUntil = GetTime() + 2

        local queued = 0
        local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
        for idx = 1, numEntries do
            local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(idx)
            if not isHeader and questID and YQB.IsQuestBlocked(questID) then
                if EnqueueAutoAbandonQuest(questID) then
                    queued = queued + 1
                end
                YQB.RememberQuestName(questID, title)
            end
        end
        PruneAutoAbandonQueue()
        MaybeStartAutoAbandonTimer()
        return queued
    end

    YQB.HasRejectedQuestInLog = HasRejectedQuestInLog
    YQB.SyncRejectedQuestsToQueue = SyncRejectedQuestsToQueue
    YQB.CancelAutoAbandonTimer = ResetAutoAbandonState

    local function ReportQueuedQuest(scope, questID, name, confirmType)
        local key = table.concat({
            tostring(scope or "unknown"),
            tostring(questID or 0),
            "queued",
        }, ":")

        if recentBlockNotices[key] then
            return
        end

        recentBlockNotices[key] = true

        local messageKey
        if scope == "global" then
            messageKey = confirmType and "STATUS.QUEUED_GLOBAL_CONFIRM" or "STATUS.QUEUED_GLOBAL"
        else
            messageKey = confirmType and "STATUS.QUEUED_CHARACTER_CONFIRM" or "STATUS.QUEUED_CHARACTER"
        end
        YQB.ReportMessage(_G.YQB.T(messageKey, name), true)
    end

    local function QueueRejectedQuest(questID, scope, confirmType)
        if not questID or not YQB.IsQuestBlocked(questID) then
            return false
        end

        if not YQB.IsAutoAbandonEnabled() then
            return false
        end

        local name = YQB.GetQuestName(questID) or ("ID: " .. questID)
        if EnqueueAutoAbandonQuest(questID) then
            ReportQueuedQuest(scope, questID, name, confirmType)
            YQB.PersistDB()
            MaybeStartAutoAbandonTimer()
            return true
        end
        return false
    end

    local function ConfirmVisibleAbandonPopup()
        for index = 1, 4 do
            local popup = _G["StaticPopup" .. index]
            if popup and popup:IsShown() then
                local which = popup.which
                if which == "ABANDON_QUEST" or which == "ABANDON_QUEST_WITH_ITEMS" then
                    StaticPopup_OnClick(popup, 1)
                    return true
                end
            end
        end
        return false
    end

    local function CanAbandonQuestByID(questID)
        if not questID then
            return nil
        end

        if C_QuestLog and C_QuestLog.CanAbandonQuest then
            local ok, canAbandon = pcall(C_QuestLog.CanAbandonQuest, questID)
            if ok and canAbandon ~= nil then
                return not not canAbandon
            end
        end

        if CanAbandonQuest then
            local ok, canAbandon = pcall(CanAbandonQuest, questID)
            if ok and canAbandon ~= nil then
                return not not canAbandon
            end

            ok, canAbandon = pcall(CanAbandonQuest)
            if ok and canAbandon ~= nil then
                return not not canAbandon
            end
        end

        return nil
    end

    local function RunAbandonQuestFlow(idx, questID)
        if not idx or idx <= 0 then
            return false
        end

        local lastSelection = GetQuestLogSelection and GetQuestLogSelection() or nil

        SelectQuestLogEntry(idx)
        SetAbandonQuest()
        AbandonQuest()
        ConfirmVisibleAbandonPopup()

        if lastSelection and lastSelection > 0 and lastSelection ~= idx then
            SelectQuestLogEntry(lastSelection)
        end

        return true
    end

    local function TryAutoAbandonQuest(questID)
        local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
        if not idx or idx <= 0 then
            RemoveAutoAbandonQuest(questID)
            return false, "missing"
        end

        local canAbandon = CanAbandonQuestByID(questID)
        if canAbandon == false then
            return false, "locked"
        end

        RunAbandonQuestFlow(idx, questID)
        return true, "abandoned"
    end

    MaybeStartAutoAbandonTimer = function()
        if autoAbandonTimerActive or autoAbandonProcessing then
            return
        end

        if not YQB.IsAutoAbandonEnabled() then
            return
        end

        if #autoAbandonQueue == 0 then
            autoAbandonWaitingForClose = false
            return
        end

        if IsQuestInteractionVisible() then
            autoAbandonWaitingForClose = true
            return
        end

        autoAbandonWaitingForClose = false
        autoAbandonTimerActive = true
        autoAbandonTimerToken = autoAbandonTimerToken + 1

        local token = autoAbandonTimerToken
        C_Timer.After(3, function()
            if token ~= autoAbandonTimerToken then
                return
            end
            autoAbandonTimerActive = false
            if not YQB.IsAutoAbandonEnabled() then
                return
            end
            autoAbandonProcessing = true

            PruneAutoAbandonQueue()
            local questID = autoAbandonQueue[1]
            if not questID then
                autoAbandonProcessing = false
                MaybeStartAutoAbandonTimer()
                return
            end

            local ok, reason = TryAutoAbandonQuest(questID)
            if ok then
                RemoveAutoAbandonQuest(questID)
            elseif reason == "locked" then
                RemoveAutoAbandonQuest(questID)
                if not reportedUnabandonable[questID] then
                    reportedUnabandonable[questID] = true
                    YQB.ReportMessage(_G.YQB.T("STATUS.CANNOT_ABANDON", YQB.GetQuestName(questID) or ("ID: " .. questID)), true)
                end
            end

            autoAbandonProcessing = false
            YQB.PersistDB()
            MaybeStartAutoAbandonTimer()
        end)
    end

    function YQB.AbandonQuest(questID)
        local idx = GetQuestLogIndexByID(questID)
        if idx and idx > 0 then
            RunAbandonQuestFlow(idx, questID)
        end
    end

    function YQB.AbandonRejectedQuestsInLog()
        if YQB.IsProcessingPaused() then
            return 0
        end
        local abandoned = 0
        local numEntries = GetNumQuestLogEntries()
        local lastSelection = GetQuestLogSelection and GetQuestLogSelection() or nil

        ResetAutoAbandonState()

        for idx = numEntries, 1, -1 do
            local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(idx)
            if not isHeader and questID and YQB.IsQuestBlocked(questID) then
                local canAbandon = CanAbandonQuestByID(questID)
                if canAbandon ~= false and RunAbandonQuestFlow(idx, questID) then
                    abandoned = abandoned + 1
                    RemoveAutoAbandonQuest(questID)
                end
            end
        end

        if lastSelection and lastSelection > 0 then
            SelectQuestLogEntry(lastSelection)
        end

        return abandoned
    end

    local function RejectCurrentQuest(questID, scope, confirmType)
        if not questID or not YQB.IsAutoRejectEnabled() then return false end
        StartRejectedBatch(questID)
        local actionKey = tostring(activeBatch and activeBatch.serial or interactionSerial) .. ":" .. tostring(questID)
        if directRejectActions[actionKey] then return true end
        directRejectActions[actionKey] = true
        local name = YQB.GetQuestName(questID) or ("ID: " .. tostring(questID))
        if DeclineQuest then
            DeclineQuest()
            YQB.AddDiagnostic(_G.YQB.T("DIAGNOSTIC.DIRECT_REJECTED"), questID, scope == "global" and _G.YQB.T("DIAGNOSTIC.GLOBAL_RULE") or _G.YQB.T("DIAGNOSTIC.CHARACTER_RULE"))
            YQB.ReportMessage(_G.YQB.T("STATUS.DIRECT_REJECTED", scope == "global" and _G.YQB.T("STATUS.GLOBAL") or _G.YQB.T("STATUS.PERSONAL"), name), true)
        else
            YQB.AddDiagnostic(_G.YQB.T("DIAGNOSTIC.CANNOT_HANDLE"), questID, _G.YQB.T("DIAGNOSTIC.NO_DECLINE_API"))
            -- Keep the legacy recovery layer available only when direct rejection
            -- cannot be invoked on this client.
            QueueRejectedQuest(questID, scope, confirmType)
        end
        YQB.PersistDB()
        return true
    end

    local function SkipBlockedQuestSelection(questID)
        if not questID or not YQB.IsAutoRejectEnabled() then return false end
        local scope = YQB.GetBlockScope(questID)
        if not scope then return false end

        StartRejectedBatch(questID)
        local actionKey = tostring(activeBatch and activeBatch.serial or interactionSerial) .. ":select:" .. tostring(questID)
        if directRejectActions[actionKey] then return true end
        directRejectActions[actionKey] = true
        YQB.AddDiagnostic(_G.YQB.T("DIAGNOSTIC.SKIPPED"), questID, scope == "global" and _G.YQB.T("DIAGNOSTIC.GLOBAL_RULE") or _G.YQB.T("DIAGNOSTIC.CHARACTER_RULE"))
        YQB.ReportMessage(_G.YQB.T("STATUS.SKIPPED", scope == "global" and _G.YQB.T("STATUS.GLOBAL") or _G.YQB.T("STATUS.PERSONAL"), YQB.GetQuestName(questID) or ("ID: " .. tostring(questID))), true)
        YQB.PersistDB()
        return true
    end

    local function InstallDirectRejectGuard(functionName, confirmType)
        local current = _G[functionName]
        local guard = guardedFunctions[functionName]
        if guard and current == guard.wrapper then return end
        if type(current) ~= "function" then return end
        guard = { original = current }
        guard.wrapper = function(...)
            local questID = GetQuestID and GetQuestID()
            local scope = YQB.GetBlockScope(questID)
            if scope and RejectCurrentQuest(questID, scope, confirmType) then return end
            return guard.original(...)
        end
        guardedFunctions[functionName] = guard
        _G[functionName] = guard.wrapper
    end

    local function InstallSelectionGuard(host, functionName)
        if type(host) ~= "table" then return end
        local current = host[functionName]
        local key = tostring(host) .. ":" .. functionName
        local guard = selectionGuards[key]
        if guard and current == guard.wrapper then return end
        if type(current) ~= "function" then return end
        guard = { original = current }
        guard.wrapper = function(questID, ...)
            if SkipBlockedQuestSelection(questID) then return end
            return guard.original(questID, ...)
        end
        selectionGuards[key] = guard
        host[functionName] = guard.wrapper
    end

    local function InstallDirectRejectGuards()
        InstallDirectRejectGuard("AcceptQuest", false)
        InstallDirectRejectGuard("ConfirmAcceptQuest", true)
        -- This is the selection-layer companion to the final AcceptQuest guard.
        -- It fixes multi-quest loops such as !Pig without guessing which allowed
        -- quest an automation addon should choose next.
        InstallSelectionGuard(C_GossipInfo, "SelectAvailableQuest")
        InstallSelectionGuard(_G, "SelectAvailableQuest")
    end

    InstallDirectRejectGuards()

    -- ==================== 事件监听 ====================
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("QUEST_DETAIL")
    frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_FINISHED")
    frame:RegisterEvent("GOSSIP_CLOSED")
    frame:RegisterEvent("QUEST_GREETING")
    frame:RegisterEvent("GOSSIP_SHOW")

    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" then
            local addonName = ...
            -- Add-ons loaded after YQB can replace global quest API functions.
            -- Reinstall our final guard after every load without inspecting their
            -- tables or SavedVariables.
            InstallDirectRejectGuards()
            if addonName ~= ADDON_NAME then return end
            YQB.BindCurrentCharacter()
            YQB.PersistDB()
            if YQB and YQB.SyncUIBindings then
                YQB.SyncUIBindings()
            end

        elseif event == "PLAYER_ENTERING_WORLD" then
            Core.Characters:RefreshCurrent()
            YQB.BindCurrentCharacter()
            if YQB and YQB.SyncUIBindings then
                YQB.SyncUIBindings()
            end
            ResetAutoAbandonState()
            wipe(reportedUnabandonable)
            wipe(recentBlockNotices)
            wipe(directRejectActions)
            activeBatch = nil
            InstallDirectRejectGuards()
            SyncRejectedQuestsToQueue(true)
            YQB.PersistDB()
            if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end

        elseif event == "PLAYER_LOGOUT" then
            YQB.PersistDB()

        elseif event == "PLAYER_LEVEL_UP" then
            Core.Characters:RefreshCurrent()
            if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged() end

        elseif event == "QUEST_DETAIL" then
            local questID = GetQuestID()
            if questID then YQB.RememberQuestName(questID, YQB.ReadQuestTitle(questID)) end

        elseif event == "QUEST_ACCEPT_CONFIRM" then
            local questID = GetQuestID()
            if questID then
                YQB.RememberQuestName(questID, YQB.ReadQuestTitle(questID))
            end

        elseif event == "QUEST_LOG_UPDATE" then
            if YQB.IsAutoAbandonEnabled() then
                SyncRejectedQuestsToQueue()
            end
            if YQB.NotifyCorePageChanged then YQB.NotifyCorePageChanged(true) end

        elseif event == "QUEST_GREETING" or event == "GOSSIP_SHOW" then
            -- A new natural list is a new client interaction boundary.  We never
            -- choose another quest here; adapters must explicitly earn that role.
            if activeBatch and activeBatch.identity ~= CurrentInteractionIdentity() then EndQuestBatch() end

        elseif event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
            if event == "GOSSIP_CLOSED" then EndQuestBatch() end
            if YQB.IsAutoAbandonEnabled() and autoAbandonWaitingForClose then
                MaybeStartAutoAbandonTimer()
            end
        end
    end)

    function YQB.OnRuleChanged(questID, characterID)
        if characterID and characterID ~= YQB.GetCurrentCharacterID() then return end
        if YQB.IsQuestBlocked(questID) and IsQuestStillInLog(questID) and YQB.IsAutoAbandonEnabled() then
            EnqueueAutoAbandonQuest(questID)
            MaybeStartAutoAbandonTimer()
        else
            RemoveAutoAbandonQuest(questID)
        end
    end

    function YQB.OnModeChanged()
        YQB.GetRuntimeSettings().directReject = YQB.IsAutoRejectEnabled()
        if not YQB.IsAutoAbandonEnabled() then ResetAutoAbandonState() end
    end

    YQB.GetRejectMode, YQB.SetRejectMode = YQB.GetProcessMode, YQB.SetProcessMode
    function YQB.SetRuntimeSetting(key, value)
        if key == "directReject" then return YQB.SetProcessMode(value and "direct" or "abandon") end
        return false
    end
    YQB.RefreshQuestNames()
end
