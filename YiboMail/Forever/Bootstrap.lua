local Addon = _G.YiboMail
function Addon:Initialize()
    if self.initialized then return true end
    if not self.CLIENT_SUPPORTED then self:Print(self:T("FOREVER.WRONG_CLIENT")); return false end
    local core = _G.YiboCore
    local valid = core and type(core.CheckAPIVersion) == "function" and core:CheckAPIVersion(13)
        and type(core.IsInitialized) == "function" and core:IsInitialized() and type(core.HasCapability) == "function"
    if valid then
        for name, minimum in pairs({ localization = 1, ["business-services"] = 1, ["character-name-format"] = 1, ["item-resolver"] = 1,
            ["character-identity"] = 1, ["character-identity-cache"] = 1, characters = 1, ["character-cleanup"] = 1, ["account-view"] = 2,
            ["account-preview-characters"] = 1, ["account-character-admission"] = 1, ["account-surface-budget"] = 2, ["account-entry"] = 2 }) do
            if not core:HasCapability(name, minimum) then valid = false end
        end
    end
    valid = valid and core.Locale and type(core.Locale.Get) == "function" and core.Contracts and type(core.Contracts.Register) == "function"
        and type(core.Contracts.NotifyChanged) == "function" and core.Characters and type(core.Characters.GetCurrent) == "function"
        and type(core.Characters.FormatName) == "function" and type(core.Characters.GetAllCached) == "function"
        and core.AccountView and type(core.AccountView.RegisterPage) == "function"
        and type(core.AccountView.Toggle) == "function" and core.Entry and type(core.Entry.RegisterBusinessEntry) == "function"
        and core.CharacterCleanup and type(core.CharacterCleanup.RegisterOwner) == "function" and core.ItemResolver
        and type(core.ItemResolver.GetInfo) == "function" and type(core.ItemResolver.Request) == "function" and core.UITheme
    if not valid then
        if core and core.Print and not (core.Locale and core.Locale.Get) then core:Print("YiboMail requires a matching YiboCore build with API 13 and inbox capabilities.")
        else self:Print(self:T("FOREVER.CORE_REQUIRED")) end
        return false
    end
    self.Core = core
    local ok, err = self:InitializeDatabase()
    if not ok then self:Print(self:T("FOREVER.STORE_MISMATCH")); return false end
    for _, field in ipairs({ "sender", "subject", "attachments", "money", "cod" }) do
        if self.db.settings.previewColumns[field] == nil then self.db.settings.previewColumns[field] = true end
    end
    ok, err = core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = 13 })
    if not ok then self:Print(err); return false end
    ok, err = core.CharacterCleanup:RegisterOwner(self.NAME, {
        Inspect = function(character) return { hasData = Addon.db.byCharacter[character.id] ~= nil, label = Addon:T("FOREVER.TITLE") } end,
        Delete = function(character) return Addon:DeleteCharacter(character) end })
    if not ok then self:Print(err); return false end
    ok, err = self.AccountPage:Register(); if not ok then self:Print(err); return false end
    self.Items.GetTransfers = function() return nil, "unsupported-capability" end
    ok, err = self.Items:RegisterService(); if not ok then self:Print(err); return false end
    self.initialized = true
    self._unsupportedEvents = {}
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE" }) do
        local registered, reason = pcall(self.Frame.RegisterEvent, self.Frame, event)
        if not registered then self._unsupportedEvents[event] = tostring(reason) end
    end
    return true
end
SLASH_YIBOMAIL1 = "/yma"
SlashCmdList.YIBOMAIL = function(message)
    if not Addon.initialized then Addon:Print(Addon:T("FOREVER.NOT_READY")); return end
    local command = (message or ""):match("^%s*(%S*)")
    if command == "scan" then
        if not Addon.Scanner:Scan(true) then Addon:Print(Addon:T("FOREVER.PENDING")) end
    elseif command == "status" then Addon:Print(Addon.AccountPage:Status())
    else Addon.Core.AccountView:Toggle("mail-inbox") end
end
Addon.Frame:RegisterEvent("ADDON_LOADED")
Addon.Frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then if (...) == Addon.NAME then Addon:Initialize() end
    elseif Addon.initialized then Addon.Scanner:OnEvent(event, ...) end
end)
local core = _G.YiboCore
if core and core.Events then core.Events:Register("CORE_READY", Addon, function() Addon:Initialize() end) end
