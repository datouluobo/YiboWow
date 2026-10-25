local Addon = _G.YiboVault
SLASH_YIBOVAULT1 = "/yva"
SlashCmdList.YIBOVAULT = function(message)
    if not Addon.initialized then Addon:PrintBootstrap(Addon:T("FOREVER.NOT_READY")); return end
    message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
    if message == "open" then Addon.AccountPage:Open()
    elseif message == "scan" or message == "" then
        local ok = Addon:ScanInitial("manual")
        if not ok then Addon:Print(Addon:T("FOREVER.SCAN_PENDING")) end
    elseif message == "status" then
        local current = Addon.Core.Characters:GetCurrentID()
        for _, source in ipairs({ "bags", "equipment", "bank", "mail", "auction", "guild-bank" }) do
            Addon:Print(Addon:T("FOREVER.SOURCE_STATUS", Addon.AccountPage:SourceLabel(source), Addon.AccountPage:StatusLabel(Addon.AccountPage:Status(source, current))))
        end
    else Addon:Print(Addon:T("TEXT.UNKNOWN_COMMAND_USAGE_YVA_OPEN_SCAN_STATUS_9C3553")) end
end
