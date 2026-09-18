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
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("LOOT_CLOSED")
frame:RegisterEvent("CHAT_MSG_LOOT")
-- A trade-skill update can arrive immediately before a character switch while
-- its deferred scan runs just after the new character enters the world. Keep
-- the pending work bound to the character that raised the update: a cooldown
-- observation belongs to that character only and must never be written under
-- whoever happens to be logged in when the timer fires.
local scanQueuedByCharacter = {}
local function IsTrackedProfessionSpell(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    for _, recipe in ipairs(Addon:GetActiveRecipes()) do
        if tonumber(recipe.recipeSpellID) == spellID then return true end
    end
    return false
end

local function QueueProfessionScan(refreshTarget)
    if not Addon.initialized then return end
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
    local characterID = current and current.id
    if not characterID then return end
    local pending = scanQueuedByCharacter[characterID]
    if pending then
        pending.refreshTarget = refreshTarget or pending.refreshTarget
        return
    end
    pending = { refreshTarget = refreshTarget }
    scanQueuedByCharacter[characterID] = pending
    local function Scan()
        scanQueuedByCharacter[characterID] = nil
        local active = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        if not active or active.id ~= characterID then return end
        -- A successful spellcast already wrote the authoritative daily
        -- lockout.  Do not immediately overwrite it with the target client's
        -- transient zero cooldown response.
        if pending.confirmedDirectCraft then return end
        local provider = Addon.Providers.Registry:Get("profession-cooldown")
        if provider then provider:ObserveWindow(characterID, pending.refreshTarget) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, Scan) else Scan() end
end

-- A secure macro click can complete without delivering the normal spellcast
-- event to this addon.  The Todo icon therefore requests the same debounced
-- verification scan after a direct craft.  We still derive the state from the
-- profession window instead of optimistically changing the icon, so failed
-- crafts remain actionable and repeated clicks never create extra scans.
function Addon:QueueProfessionCooldownRefresh(refreshTarget)
    QueueProfessionScan(refreshTarget)
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
            local special = Addon.Providers.Registry:Get("special-activity")
            local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
            if special and current then special:ObserveCharacter(current.id) end
            Addon:NotifyChanged()
        end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_UPDATE" then
        QueueProfessionScan()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and Addon.initialized then
        local _, _, spellID = ...
        local provider = Addon.Providers.Registry:Get("farm-operation-observation")
        if provider then
            local changed = provider:RecordSucceededCast(...)
            if changed then Addon:NotifyChanged() end
        end
        if IsTrackedProfessionSpell(spellID) then
            local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
            local characterID = current and current.id
            local pending = characterID and scanQueuedByCharacter[characterID]
            local cooldowns = Addon.Providers.Registry:Get("profession-cooldown")
            if cooldowns and characterID and cooldowns:RecordSuccessfulCraft(characterID, spellID) then
                if pending then pending.confirmedDirectCraft = true end
                Addon:NotifyChanged(true, pending and pending.refreshTarget)
            else
                Addon:QueueProfessionCooldownRefresh(pending and pending.refreshTarget)
            end
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
        local special = Addon.Providers.Registry:Get("special-activity")
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        if special and current then special:ObserveCharacter(current.id) end
    elseif event == "QUEST_TURNED_IN" and Addon.initialized then
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local provider = Addon.Providers.Registry:Get("daily-quest")
        if provider and current then provider:RecordTurnIn(current.id, ...) end
        local special = Addon.Providers.Registry:Get("special-activity")
        if special and current then special:RecordTurnIn(current.id, ...) end
        if provider then provider:QueueObserve() end
    elseif event == "CHAT_MSG_LOOT" and Addon.initialized then
        local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
        local special = Addon.Providers.Registry:Get("special-activity")
        if special and current then special:RecordLoot(current.id, ...) end
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
