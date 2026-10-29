local Addon = _G.YiboBuilds
function Addon:Initialize()
    if self.initialized then return true end
    if type(WOW_PROJECT_CAMELOT) ~= "number" or WOW_PROJECT_ID ~= WOW_PROJECT_CAMELOT then
        local locale = _G.YiboCore and _G.YiboCore.Locale
        self:Print(locale and locale.Get and self:T("FOREVER.WRONG_CLIENT") or "This YiboBuilds manifest requires Forever."); return false
    end
    local core = _G.YiboCore
    local valid = core and type(core.CheckAPIVersion) == "function" and core:CheckAPIVersion(13)
        and type(core.IsInitialized) == "function" and core:IsInitialized() and type(core.HasCapability) == "function"
    if valid then
        for name, version in pairs({ localization = 1, ["item-resolver"] = 1, ["character-name-format"] = 1, ["character-identity"] = 1,
            characters = 1, ["character-cleanup"] = 2, ["account-view"] = 2, ["account-entry"] = 2,
            ["account-preview-characters"] = 1, ["account-character-admission"] = 1, ["account-surface-budget"] = 2 }) do
            if not core:HasCapability(name, version) then valid = false end
        end
    end
    for _, group in ipairs({ { core, "RegisterAddon" }, { core and core.Locale, "Get" },
        { core and core.Characters, "GetCurrentID", "GetCurrent", "FormatName" },
        { core and core.AccountView, "RegisterPage", "NotifyPageChanged", "Toggle" },
        { core and core.Entry, "RegisterBusinessEntry" }, { core and core.CharacterCleanup, "RegisterOwner" },
        { core and core.ItemResolver, "GetInfo", "Parse" }, { core and core.Defaults, "Copy" }, { core and core.UITheme, "CreateText", "CreateButton", "CreateScrollFrame" } }) do
        for index = 2, #group do if type(group[1]) ~= "table" or type(group[1][group[index]]) ~= "function" then valid = false end end
    end
    if not valid then
        if core and core.Locale and core.Locale.Get then self:Print(self:T("FOREVER.CORE_REQUIRED"))
        else self:Print("YiboBuilds requires a matching YiboCore build with API 13 and current-character capabilities.") end
        return false
    end
    self.Core = core
    if not self.Store:Initialize() then self:Print(self:T("FOREVER.STORE_MISMATCH")); return false end
    local ok, err = core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = 13 })
    if not ok then self:Print(err); return false end
    ok, err = core.CharacterCleanup:RegisterOwner(self.NAME, {
        Inspect = function(character) return { hasData = Addon.Store.db.characters[character.id] ~= nil, label = Addon:T("FOREVER.TITLE") } end,
        Delete = function(character, _, context) return Addon.Store:Delete(character, context) end })
    if not ok then self:Print(err); return false end
    ok, err = self.AccountPage:Register(); if not ok then self:Print(err); return false end
    self.initialized, self._unsupportedEvents = true, {}
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "UNIT_INVENTORY_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
        local registered, reason = pcall(self.Frame.RegisterEvent, self.Frame, event)
        if not registered then self._unsupportedEvents[event] = tostring(reason) end
    end
    return true
end
SLASH_YIBOBUILDS1 = "/ybb"
SlashCmdList.YIBOBUILDS = function(message)
    if not Addon.initialized then
        local core = _G.YiboCore
        Addon:Print(core and core.Locale and core.Locale.Get and Addon:T("FOREVER.CORE_REQUIRED") or "YiboBuilds requires YiboCore API 13."); return
    end
    local command = string.lower((message or ""):match("^%s*(%S*)") or "")
    if command == "scan" then Addon.Scanner:Scan(true); Addon:Print(Addon.AccountPage:Status())
    elseif command == "status" then Addon:Print(Addon.AccountPage:Status())
    else Addon.Core.AccountView:Toggle(Addon.PAGE_ID) end
end
Addon.Frame:RegisterEvent("ADDON_LOADED")
Addon.Frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then if (...) == Addon.NAME then Addon:Initialize() end
    elseif Addon.initialized then Addon.Scanner:OnEvent(event, ...) end
end)
local core = _G.YiboCore
if core and core.Events then core.Events:Register("CORE_READY", Addon, function() Addon:Initialize() end) end
