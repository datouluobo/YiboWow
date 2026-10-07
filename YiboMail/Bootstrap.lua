local Addon = _G.YiboMail
function Addon:Initialize()
    if self.initialized then return end
    local core = _G.YiboCore
    if not (core and core.CheckAPIVersion and core:CheckAPIVersion(8)
        and core.HasCapability and core:HasCapability("character-name-format", 1)
        and core:HasCapability("item-picker", 2)
        and core.Characters and type(core.Characters.FormatName) == "function") then
        self:Print("请升级 YiboCore 至 1.7.1 或更新版本：需要 API v8、公共名称格式化和批量物品确认能力。"); return
    end
    self.Core = core; self:InitializeDatabase()
    local ok, err = core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = 8 })
    if not ok then self:Print(err); return end
    self.Recipients:Initialize()
    self.SendRules:Initialize()
    ok, err = core.CharacterCleanup:RegisterOwner(self.NAME, {
        Inspect = function(character, aliases)
            local hasData = Addon.db.byCharacter[character.id] ~= nil or Addon.Recipients:HasCharacter(character, aliases)
            for id in pairs(aliases or {}) do if Addon.db.byCharacter[id] then hasData = true end end
            return { hasData = hasData, label = "邮件快照、积压与角色好友缓存" }
        end,
        Delete = function(character, aliases)
            Addon:DeleteCharacter(character)
            for id in pairs(aliases or {}) do Addon:DeleteCharacter({ id = id }) end
            Addon.Recipients:DeleteCharacter(character, aliases); return true
        end,
    })
    if not ok then self:Print(err); return end
    if self.FEATURES.account then
        ok, err = self.AccountPage:Register(); if not ok then self:Print(err); return end
        self.Items.Events:Register(self.AccountPage, function() core.AccountView:NotifyPageChanged("mail-inbox") end)
    end
    self.initialized = true
    SLASH_YIBOMAIL1 = "/yma"
    SlashCmdList.YIBOMAIL = function(message)
        local command = (message or ""):match("^%s*(%S*)")
        if command == "scan" then local success, errorMessage = Addon.Scanner:Scan(); Addon:Print(success and "邮箱快照已更新。" or errorMessage)
        elseif command == "status" then
            local character = core.Characters:GetCurrent(); local state = character and Addon.Items:GetState(character.id)
            Addon:Print(state and (state.status .. " · " .. tostring(state.currentCount or 0) .. "/" .. tostring(state.totalCount or 0) .. " · revision " .. Addon.Items:GetRevision()) or "角色不可用。")
        elseif Addon.FEATURES.account then core.AccountView:Toggle("mail-inbox")
        else Addon:Print("收件箱版：打开游戏邮箱即可使用。诊断命令：/yma status、/yma scan。") end
    end
    for _, event in ipairs({ "PLAYER_LOGIN", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE" }) do self.Frame:RegisterEvent(event) end
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
