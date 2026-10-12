local Addon = _G.YiboTaskHub
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED"); frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == Addon.NAME then
        local db, err = Addon.Database:Initialize()
        if not db then Addon:Print(err) end
    elseif event == "PLAYER_LOGIN" then
        if not Addon.db then return end
        local ok, err = Addon.CoreIntegration:Initialize()
        if not ok then Addon:Print(err) else Addon.Displays:Initialize() end
    elseif event == "PLAYER_REGEN_ENABLED" then Addon.Displays:ScheduleRefresh()
    end
end)

SLASH_YIBOTASKHUB1 = "/yth"
SlashCmdList.YIBOTASKHUB = function(command)
    if not Addon.CoreIntegration.initialized then
        local core = _G.YiboCore
        local message = core and core.Locale and type(core.Locale.Get) == "function"
            and Addon:T("BOOT.NOT_INITIALIZED") or "Action Hub did not initialize. Check YiboCore 1.12.0 / API 13."
        Addon:Print(message); return
    end
    if command == "refresh" then Addon.Contracts:Invalidate() end
    Addon.Core.AccountView:ShowPage(Addon.PAGE_ID)
end
