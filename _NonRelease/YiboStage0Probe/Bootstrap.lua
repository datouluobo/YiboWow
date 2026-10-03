local Addon = _G.YiboStage0Probe

local frame = CreateFrame("Frame")
Addon.EventFrame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

for _, eventName in ipairs(Addon.EVENT_NAMES) do
    pcall(frame.RegisterEvent, frame, eventName)
end

frame:SetScript("OnEvent", function(_, eventName, ...)
    if eventName == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName == Addon.NAME then Addon:InitializeDatabase() end
        return
    end
    if eventName == "PLAYER_LOGIN" then
        if not Addon.Session then Addon:InitializeDatabase() end
        Addon:Print("已加载只读阶段 0 探针。输入 /ysp help 查看命令。")
        return
    end
    if eventName == "BANKFRAME_OPENED" then Addon.Runtime.bankOpen = true end
    if eventName == "BANKFRAME_CLOSED" then Addon.Runtime.bankOpen = false end
    if eventName == "GUILDBANKFRAME_OPENED" then Addon.Runtime.guildBankOpen = true end
    if eventName == "GUILDBANKFRAME_CLOSED" then Addon.Runtime.guildBankOpen = false end
    if eventName == "AUCTION_HOUSE_SHOW" then Addon.Runtime.auctionHouseOpen = true end
    if eventName == "AUCTION_HOUSE_CLOSED" then
        Addon.Runtime.auctionHouseOpen = false
        Addon.OwnedAuctionState = nil
    end
    if eventName == "MAIL_SHOW" then Addon.Runtime.mailOpen = true end
    if eventName == "MAIL_CLOSED" then Addon.Runtime.mailOpen = false end
    Addon:AddEvent(eventName, ...)
    if eventName == "GUILDBANKBAGSLOTS_CHANGED" then Addon:HandleGuildBankSlotsChanged() end
    if eventName == "OWNED_AUCTIONS_UPDATED" then Addon:HandleOwnedAuctionsUpdated() end
    if eventName == "AUCTION_HOUSE_SHOW" then
        local start = function()
            if Addon.Runtime.auctionHouseOpen then Addon:StartOwnedAuctionProbe("auto-open") end
        end
        if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, start) else start() end
    end
end)
