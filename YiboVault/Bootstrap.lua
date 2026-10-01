local Addon = _G.YiboVault

function Addon:Initialize()
    if self.initialized then return end
    self:InitializeDatabase()
    if not self:RegisterWithCore() then return end
    if self.Items.WarmPersonalCountsIndex then self.Items:WarmPersonalCountsIndex() end
    if self.Tooltip then self.Tooltip:Install() end
    self.initialized = true
    self.Frame:RegisterEvent("PLAYER_LOGIN")
    self.Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.Frame:RegisterEvent("BAG_UPDATE")
    self.Frame:RegisterEvent("BAG_UPDATE_DELAYED")
    self.Frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self.Frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.Frame:RegisterEvent("BANKFRAME_OPENED")
    self.Frame:RegisterEvent("BANKFRAME_CLOSED")
    self.Frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    self.Frame:RegisterEvent("GUILDBANKFRAME_OPENED")
    self.Frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
    self.Frame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    self.Frame:RegisterEvent("AUCTION_HOUSE_SHOW")
    self.Frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    self.Frame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
    self.Frame:RegisterEvent("MAIL_SHOW")
    self.Frame:RegisterEvent("MAIL_CLOSED")
    self.Frame:RegisterEvent("MAIL_INBOX_UPDATE")
    self.GuildBank:InstallFrameHooks()
    self.MailItems:InstallFrameHooks()
end

Addon.Frame:RegisterEvent("ADDON_LOADED")
Addon.Frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == Addon.NAME then Addon:Initialize() end
        if Addon.initialized and Addon.GuildBank then Addon.GuildBank:OnAddonLoaded(loadedAddon) end
        if Addon.initialized and loadedAddon == "Blizzard_MailUI" then Addon.MailItems:InstallFrameHooks() end
        return
    end
    if Addon.initialized then
        if (event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD") and Addon.Tooltip then
            Addon.Tooltip:Install()
        end
        Addon:OnEvent(event, ...)
        if Addon.GuildBank then Addon.GuildBank:OnEvent(event, ...) end
        if Addon.AuctionHouse then Addon.AuctionHouse:OnEvent(event, ...) end
        if Addon.MailItems then Addon.MailItems:OnEvent(event, ...) end
    end
end)
