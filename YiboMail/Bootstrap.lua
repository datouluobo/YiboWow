local Addon = _G.YiboMail
function Addon:Initialize()
    if self.initialized then return end
    local core = _G.YiboCore
    if not (core and type(core.CheckAPIVersion) == "function" and core:CheckAPIVersion(self.REQUIRED_CORE_API)
        and type(core.HasCapability) == "function" and core:HasCapability("localization", 1)
        and core.Locale and type(core.Locale.Get) == "function" and type(core.Locale.Register) == "function"
        and core.IsInitialized and core:IsInitialized()
        and core.Contracts and type(core.Contracts.Register) == "function"
        and type(core.Contracts.NotifyChanged) == "function"
        and core:HasCapability("business-services", 1)
        and core:HasCapability("character-name-format", 1)
        and core:HasCapability("basic-input", 1)
        and core:HasCapability("item-resolver", 1)
        and core:HasCapability("item-picker", 2)
        and core:HasCapability("character-identity", 1)
        and core:HasCapability("characters", 1)
        and core:HasCapability("character-cleanup", 1)
        and core:HasCapability("account-view", 2)
        and core:HasCapability("account-character-admission", 1)
        and core:HasCapability("account-surface-budget", 1)
        and core:HasCapability("account-entry", 2)
        and core.Characters and type(core.Characters.FormatName) == "function"
        and type(core.Characters.GetAllCached) == "function"
        and type(core.Characters.Get) == "function"
        and core.CharacterCleanup and type(core.CharacterCleanup.RegisterOwner) == "function"
        and core.AccountView and type(core.AccountView.RegisterPage) == "function"
        and type(core.AccountView.NotifyPageChanged) == "function"
        and type(core.AccountView.Toggle) == "function"
        and type(core.AccountView.BuildContext) == "function"
        and type(core.AccountView.GetVisibleCharacters) == "function"
        and type(core.AccountView.GetEffectiveCharacterSort) == "function"
        and type(core.AccountView.GetCustomCharacterOrder) == "function"
        and core.Entry and type(core.Entry.RegisterBusinessEntry) == "function"
        and core.UITheme and type(core.UITheme.CreateInput) == "function"
        and type(core.CreateItemPicker) == "function"
        and type(core.ItemResolver.Request) == "function") then
        if core and type(core.Print) == "function" and not (core.Locale and type(core.Locale.Get) == "function") then
            core:Print("YiboMail requires YiboCore 1.12.0 / API 13 with localization:1.")
        else
            self:Print(self:T("BOOTSTRAP.UPGRADE_CORE"))
        end
        return
    end
    self.Core = core; self:InitializeDatabase()
    local ok, err = core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = self.REQUIRED_CORE_API })
    if not ok then self:Print(err or self:T("ERROR.CORE_REGISTER")); return end
    self.Recipients:Initialize()
    self.SendRules:Initialize()
    ok, err = core.CharacterCleanup:RegisterOwner(self.NAME, {
        Inspect = function(character, aliases)
            local hasData = Addon.db.byCharacter[character.id] ~= nil or Addon.Recipients:HasCharacter(character, aliases)
            for id in pairs(aliases or {}) do if Addon.db.byCharacter[id] then hasData = true end end
            return { hasData = hasData, label = Addon:T("UI.TEXT_0596") }
        end,
        Delete = function(character, aliases)
            Addon:DeleteCharacter(character)
            for id in pairs(aliases or {}) do Addon:DeleteCharacter({ id = id }) end
            Addon.Recipients:DeleteCharacter(character, aliases); return true
        end,
    })
    if not ok then self:Print(err or self:T("ERROR.CLEANUP_REGISTER")); return end
    if self.FEATURES.account then
        ok, err = self.AccountPage:Register(); if not ok then self:Print(err or self:T("ERROR.PAGE_REGISTER")); return end
        self.Items.Events:Register(self.AccountPage, function() core.AccountView:NotifyPageChanged("mail-inbox") end)
    end
    self.initialized = true
    ok, err = self.Items:RegisterService()
    if not ok then self.initialized = false; self:Print(err or self:T("ERROR.ITEMS_REGISTER")); return end
    if self.GoalTargets then self.GoalTargets:Initialize() end
    ok, err = self.ActionTodo:Initialize()
    if not ok then self:Print(err) end
    SLASH_YIBOMAIL1 = "/yma"
    SlashCmdList.YIBOMAIL = function(message)
        local command = (message or ""):match("^%s*(%S*)")
        if command == "scan" then local success, errorMessage = Addon.Scanner:Scan(); Addon:Print(success and Addon:T("UI.TEXT_0604") or errorMessage)
        elseif command == "status" then
            local character = core.Characters:GetCurrent(); local state = character and Addon.Items:GetState(character.id)
            Addon:Print(state and (state.status .. " · " .. tostring(state.currentCount or 0) .. "/" .. tostring(state.totalCount or 0) .. " · revision " .. Addon.Items:GetRevision()) or Addon:T("UI.TEXT_0505"))
        elseif Addon.FEATURES.account then core.AccountView:Toggle("mail-inbox")
        else Addon:Print(Addon:T("UI.TEXT_0345")) end
    end
    for _, event in ipairs({ "PLAYER_LOGIN", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "UPDATE_PENDING_MAIL", "MAIL_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE" }) do self.Frame:RegisterEvent(event) end
    if self.FEATURES.send then for _, event in ipairs({ "MAIL_SEND_SUCCESS", "MAIL_SEND_INFO_UPDATE" }) do self.Frame:RegisterEvent(event) end end
    self.Recipients:RequestFriends(true)
    self.Scanner:InstallHooks()
    self.Queue:Install(); if self.FEATURES.send then self.Compose:Install() end; self:PruneHistory()
    self.NativeUI:Install()
end
Addon.Frame:RegisterEvent("ADDON_LOADED")
Addon.Frame:SetScript("OnEvent", function(_, event, name, ...)
    if event == "ADDON_LOADED" and name == Addon.NAME then Addon:Initialize() end
    if Addon.initialized then
        Addon.Recipients:OnEvent(event)
        Addon.Scanner:OnEvent(event)
        Addon.Queue:OnEvent(event, name, ...)
        if Addon.FEATURES.send then Addon.Compose:OnEvent(event, name, ...) end
        Addon.RuleSendController:OnEvent(event, name, ...)
        Addon.NativeUI:OnEvent(event, name, ...)
        if event == "PLAYER_LOGIN" and Addon.FEATURES.account then Addon.AccountPage:OnLogin() end
    end
end)
