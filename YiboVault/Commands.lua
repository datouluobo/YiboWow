local Addon = _G.YiboVault

SLASH_YIBOVAULT1 = "/yva"
SlashCmdList.YIBOVAULT = function(message)
    message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
    if message == "open" then
        Addon.AccountPage:Open()
    elseif message == "scan" or message == "" then
        Addon:ScanInitial()
        if Addon.MailItems and Addon.MailItems:IsOpen() then
            local ok = Addon.MailItems:Scan("manual")
            if not ok and Addon.MailItems.lastStatus == "error" then
                Addon:Print(Addon:T("ERROR.MAIL_SCAN_FAILED", tostring(Addon.MailItems.lastResult)))
            end
        end
    elseif message == "status" then
        local current = Addon.Core.Characters:GetCurrent()
        local errors = {}
        for _, source in ipairs({ "bags", "equipment", "bank", "auction", "mail" }) do
            local coverage = current and Addon:GetCharacterCoverage(current.id, source) or {}
            for key, state in pairs(coverage) do
                if state.status == "error" then
                    errors[#errors + 1] = Addon:T("ERROR.SOURCE_READ_FAILED", source .. " " .. key, tostring(state.error or Addon:T("TEXT.READ_FAILED_D9F607")))
                end
            end
        end
        local guildKey = Addon:GetGuildIdentity(current)
        for tabID, state in pairs(guildKey and Addon:GetGuildCoverage(guildKey) or {}) do
            if state.status == "error" then
                errors[#errors + 1] = Addon:T("ERROR.GUILD_TAB_READ_FAILED", tabID, tostring(state.error or Addon:T("TEXT.READ_FAILED_D9F607")))
            end
        end
        for _, module in ipairs({ { Addon:T("TEXT.GUILD_BANK_973C01"), Addon.GuildBank },
            { Addon:T("TEXT.AUCTION_HOUSE_912272"), Addon.AuctionHouse }, { Addon:T("TEXT.MAILBOX_9ED627"), Addon.MailItems } }) do
            if module[2] and type(module[2].GetStatus) == "function" then
                local status, detail = module[2]:GetStatus()
                if status == "error" then
                    errors[#errors + 1] = Addon:T("ERROR.SOURCE_SCAN_FAILED", module[1], tostring(detail or Addon:T("TEXT.SCAN_FAILED_978790")))
                end
            end
        end
        if #errors > 0 then Addon:Print(Addon:T("ERROR.SCAN_ERRORS", table.concat(errors, Addon:T("TEXT.LIST_SEPARATOR")))) end
    else
        Addon:Print(Addon:T("TEXT.UNKNOWN_COMMAND_USAGE_YVA_OPEN_SCAN_STATUS_9C3553"))
    end
end
