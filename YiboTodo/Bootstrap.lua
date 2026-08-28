local Addon = _G.YiboTodo
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
frame:RegisterEvent("TRADE_SKILL_UPDATE")
local scanQueued = false
local function QueueProfessionScan()
    if scanQueued or not Addon.initialized then return end
    scanQueued = true
    local function Scan()
        scanQueued = false
        local provider = Addon.Providers.Registry:Get("profession-cooldown")
        if provider then provider:ObserveWindow() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.25, Scan) else Scan() end
end
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == Addon.NAME then
        Addon.Database:Initialize()
        Addon:ValidateCatalog()
    elseif event == "PLAYER_LOGIN" then
        local ok, err = Addon.CoreIntegration:Initialize()
        if not ok then Addon:Print("Core 接入失败：" .. tostring(err)) else Addon.initialized = true; Addon:NotifyChanged() end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_UPDATE" then
        QueueProfessionScan()
    end
end)
