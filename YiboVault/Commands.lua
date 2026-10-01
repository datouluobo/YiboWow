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
                Addon:Print("邮箱附件扫描失败：" .. tostring(Addon.MailItems.lastResult) .. "。")
            end
        end
    elseif message == "status" then
        local current = Addon.Core.Characters:GetCurrent()
        local errors = {}
        for _, source in ipairs({ "bags", "equipment", "bank", "auction", "mail" }) do
            local coverage = current and Addon:GetCharacterCoverage(current.id, source) or {}
            for key, state in pairs(coverage) do
                if state.status == "error" then
                    errors[#errors + 1] = source .. " " .. key .. "：" .. tostring(state.error or "读取失败")
                end
            end
        end
        local guildKey = Addon:GetGuildIdentity(current)
        for tabID, state in pairs(guildKey and Addon:GetGuildCoverage(guildKey) or {}) do
            if state.status == "error" then
                errors[#errors + 1] = "公会银行 P" .. tabID .. "：" .. tostring(state.error or "读取失败")
            end
        end
        for _, module in ipairs({ { "公会银行", Addon.GuildBank },
            { "拍卖行", Addon.AuctionHouse }, { "邮箱", Addon.MailItems } }) do
            if module[2] and type(module[2].GetStatus) == "function" then
                local status, detail = module[2]:GetStatus()
                if status == "error" then
                    errors[#errors + 1] = module[1] .. "：" .. tostring(detail or "扫描失败")
                end
            end
        end
        if #errors > 0 then Addon:Print("扫描错误：" .. table.concat(errors, "；")) end
    else
        Addon:Print("未知命令。用法：/yva [open|scan|status]")
    end
end
