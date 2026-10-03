local Addon = _G.YiboMail
function Addon:Initialize()
    if self.initialized then return end
    local core = _G.YiboCore
    if not core or not core:CheckAPIVersion(6) then self:Print("需要 YiboCore API v6。"); return end
    self.Core = core; self:InitializeDatabase()
    local ok, err = core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = 6 })
    if not ok then self:Print(err); return end
    ok, err = core.CharacterCleanup:RegisterOwner(self.NAME, {
        Inspect = function(character) return { hasData = Addon.db.byCharacter[character.id] ~= nil, label = "邮件快照与积压缓存" } end,
        Delete = function(character) return Addon:DeleteCharacter(character) end,
    })
    if not ok then self:Print(err); return end
    if self.FEATURES.account then
        ok, err = self.AccountPage:Register(); if not ok then self:Print(err); return end
        self.Items.Events:Register(self.AccountPage, function() core.AccountView:NotifyPageChanged("mail-inbox") end)
    end
    self.initialized = true
    for _, event in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "PLAYER_REGEN_ENABLED" }) do self.Frame:RegisterEvent(event) end
    if self.FEATURES.send then for _, event in ipairs({ "MAIL_SEND_SUCCESS", "MAIL_SEND_INFO_UPDATE" }) do self.Frame:RegisterEvent(event) end end
    self.Scanner:InstallHooks()
    self.Queue:Install(); if self.FEATURES.send then self.Compose:Install() end; self:PruneHistory()
    self.NativeUI:Install()
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
end
Addon.Frame:RegisterEvent("ADDON_LOADED")
Addon.Frame:SetScript("OnEvent", function(_, event, name, ...)
    if event == "ADDON_LOADED" and name == Addon.NAME then Addon:Initialize() end
    if Addon.initialized then
        Addon.Scanner:OnEvent(event)
        Addon.Queue:OnEvent(event, name, ...)
        if Addon.FEATURES.send then Addon.Compose:OnEvent(event, name, ...) end
        Addon.NativeUI:OnEvent(event, name, ...)
    end
end)
