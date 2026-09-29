local Addon = _G.YiboVault

SLASH_YIBOVAULT1 = "/yva"
SlashCmdList.YIBOVAULT = function(message)
    message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
    if message == "open" then
        Addon.AccountPage:Open()
    elseif message == "scan" or message == "" then
        Addon:ScanInitial()
        Addon:Print("已重新扫描当前角色的背包与装备。")
        if Addon.MailItems and Addon.MailItems:IsOpen() then Addon.MailItems:Scan("manual") end
    elseif message == "status" then
        local result = Addon.Items:Query({ scope = nil, sources = { "bags", "equipment", "bank", "auction", "mail" } })
        local current = Addon.Core.Characters:GetCurrent()
        local bank = current and Addon:GetCharacterCoverage(current.id, "bank") or {}
        local known, stale, errors = 0, 0, 0
        for _, coverage in pairs(bank) do
            if coverage.status == "known" or coverage.status == "known-empty" then known = known + 1
            elseif coverage.status == "stale" then stale = stale + 1
            elseif coverage.status == "error" then errors = errors + 1 end
        end
        local guildKey = Addon:GetGuildIdentity(current)
        local guildCoverage = guildKey and Addon:GetGuildCoverage(guildKey) or {}
        local guildKnown, guildStale, guildErrors = 0, 0, 0
        for _, coverage in pairs(guildCoverage) do
            if coverage.status == "known" or coverage.status == "known-empty" then guildKnown = guildKnown + 1
            elseif coverage.status == "stale" then guildStale = guildStale + 1
            elseif coverage.status == "error" then guildErrors = guildErrors + 1 end
        end
        local guildStatus, guildDetail = Addon.GuildBank:GetStatus()
        local auctionCoverage = current and Addon:GetCharacterCoverage(current.id, "auction") or {}
        local auctionState = auctionCoverage.auction and auctionCoverage.auction.status or "not-yet-scanned"
        local auctionStatus, auctionDetail = Addon.AuctionHouse:GetStatus()
        local mailCoverage = current and Addon:GetCharacterCoverage(current.id, "mail") or {}
        local mailState = mailCoverage.inbox and mailCoverage.inbox.status or "not-yet-scanned"
        local mailStatus, mailDetail = Addon.MailItems:GetStatus()
        Addon:Print(string.format("API v%d；修订 %d；角色记录 %d 条、缓存量 %d（实体 %d / AH 上架 %d / 邮件 %d）；个人银行位置 已知 %d / 陈旧 %d / 错误 %d；公会银行页签 已知 %d / 陈旧 %d / 错误 %d；AH 快照 %s，扫描 %s（%s）；邮箱快照 %s，扫描 %s（%s）；公会扫描 %s（%s）。", Addon.API_VERSION, result.revision, #result.records, result.totals.totalQuantity, result.totals.physicalQuantity, result.totals.listedQuantity, result.totals.externalQuantity, known, stale, errors, guildKnown, guildStale, guildErrors, tostring(auctionState), tostring(auctionStatus), tostring(auctionDetail), tostring(mailState), tostring(mailStatus), tostring(mailDetail), tostring(guildStatus), tostring(guildDetail)))
    else
        Addon:Print("用法：/yva [open|scan|status]")
    end
end
