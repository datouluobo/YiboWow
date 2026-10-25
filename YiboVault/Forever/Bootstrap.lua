local Addon = _G.YiboVault
function Addon:Initialize()
    if self.initialized then return true end
    if type(WOW_PROJECT_CAMELOT) ~= "number" or WOW_PROJECT_ID ~= WOW_PROJECT_CAMELOT then
        self:PrintBootstrap(self:T("FOREVER.CLIENT_MISMATCH")); return false
    end
    self.Core = self:CheckCoreRequirements()
    if not self.Core then return false end
    if not self.Core:HasCapability("account-surface-budget", 2) or not self.Core:HasCapability("account-character-admission", 1) then
        self:PrintBootstrap(self:T("BOOT.CORE_REQUIRED")); return false
    end
    local ok, reason = self:InitializeDatabase()
    if not ok then self:Print(reason); return false end
    if not self:RegisterWithCore() then return false end
    self.initialized = true
    if self.MailProvider then self.MailProvider:Install() end
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do self.Frame:RegisterEvent(event) end
    self._unsupportedEvents = {}
    for _, event in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BAG_CONTAINER_UPDATE", "BANK_TABS_CHANGED", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_UPDATE_TABS", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" }) do
        local registered, errorMessage = pcall(self.Frame.RegisterEvent, self.Frame, event)
        if not registered then self._unsupportedEvents[event] = tostring(errorMessage) end
    end
    return true
end
Addon.Frame:RegisterEvent("ADDON_LOADED")
Addon.Frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) == Addon.NAME then Addon:Initialize() end
    elseif Addon.initialized then Addon:OnEvent(event, ...) end
end)
local Core = _G.YiboCore
if Core and Core.Events then Core.Events:Register("CORE_READY", Addon, function() Addon:Initialize() end) end
