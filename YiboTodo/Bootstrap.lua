local Addon = _G.YiboTodo
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
frame:RegisterEvent("TRADE_SKILL_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
-- A trade-skill update can arrive immediately before a character switch while
-- its deferred scan runs just after the new character enters the world. Keep
-- the pending work bound to the character that raised the update: a cooldown
-- observation belongs to that character only and must never be written under
-- whoever happens to be logged in when the timer fires.
local scanQueuedByCharacter = {}
local function QueueProfessionScan()
    if not Addon.initialized then return end
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
    local characterID = current and current.id
    if not characterID or scanQueuedByCharacter[characterID] then return end
    scanQueuedByCharacter[characterID] = true
    local function Scan()
        scanQueuedByCharacter[characterID] = nil
        local active = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        if not active or active.id ~= characterID then return end
        local provider = Addon.Providers.Registry:Get("profession-cooldown")
        if provider then provider:ObserveWindow(characterID) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, Scan) else Scan() end
end
frame:SetScript("OnEvent", function(_, event, ...)
    local name = ...
    if Addon.Probe and Addon.initialized then Addon.Probe:CaptureEvent(event, ...) end
    if event == "ADDON_LOADED" and name == Addon.NAME then
        Addon.Database:Initialize()
        Addon:ValidateCatalog()
    elseif event == "PLAYER_LOGIN" then
        local ok, err = Addon.CoreIntegration:Initialize()
        if not ok then Addon:Print("Core 接入失败：" .. tostring(err)) else
            Addon.initialized = true
            local provider = Addon.Providers.Registry:Get("daily-quest")
            if provider then provider:QueueObserve() end
            Addon:NotifyChanged()
        end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_UPDATE" then
        QueueProfessionScan()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and Addon.initialized then
        local provider = Addon.Providers.Registry:Get("farm-operation-observation")
        if provider then
            local changed = provider:RecordSucceededCast(...)
            if changed then Addon:NotifyChanged() end
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" and Addon.initialized then
        local provider = Addon.Providers.Registry:Get("farm-operation-observation")
        if provider then
            local changed = provider:RecordGrowingMouseover()
            if changed then Addon:NotifyChanged() end
        end
    elseif (event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "PLAYER_ENTERING_WORLD") and Addon.initialized then
        local provider = Addon.Providers.Registry:Get("daily-quest")
        if provider then provider:QueueObserve() end
    elseif event == "QUEST_TURNED_IN" and Addon.initialized then
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local provider = Addon.Providers.Registry:Get("daily-quest")
        if provider and current then provider:RecordTurnIn(current.id, ...) end
        if provider then provider:QueueObserve() end
    elseif event == "GOSSIP_SHOW" and Addon.initialized then
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local provider = Addon.Providers.Registry:Get("daily-quest")
        if provider and current then provider:ObserveNomiGossip(current.id) end
    elseif event == "PLAYER_TARGET_CHANGED" and Addon.initialized then
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local provider = Addon.Providers.Registry:Get("daily-quest")
        if provider and current then provider:ObserveTargetCompletion(current.id) end
    end
    if Addon.initialized and (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA") then
        Addon:NotifyChanged()
    end
end)
