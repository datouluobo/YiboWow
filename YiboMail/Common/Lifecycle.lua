local Addon = _G.YiboMail
local function Methods(object, names)
    if not object then return false end
    for _, name in ipairs(names) do if type(object[name]) ~= "function" then return false end end
    return true
end
local function CoreReady(core)
    if not Methods(core, {"CheckAPIVersion", "IsInitialized", "HasCapability", "RegisterAddon"})
        or not core:IsInitialized() or not core:CheckAPIVersion(Addon.REQUIRED_CORE_API) then return false end
    local capabilities = {localization=1, ["business-services"]=1, ["character-name-format"]=1,
        ["basic-input"]=1, ["item-resolver"]=2, ["character-identity"]=1, ["character-identity-cache"]=1,
        characters=1, ["character-cleanup"]=1, ["account-view"]=2, ["account-preview-characters"]=1,
        ["account-character-admission"]=1, ["account-surface-budget"]=2, ["account-entry"]=2,
        ["account-surface-realm-scope"]=1, ["pixel-line"]=1}
    if Addon.FEATURES.contacts then capabilities["character-identity"], capabilities["account-identity-context"] = 2, 1 end
    if Addon.FEATURES.send then capabilities["item-picker"] = 2 end
    for name, minimum in pairs(capabilities) do if not core:HasCapability(name, minimum) then return false end end
    return Methods(core.Locale, {"Get", "Register"})
        and Methods(core.Contracts, {"Register", "NotifyChanged"})
        and Methods(core.Characters, {"GetCurrent", "GetCurrentID", "FormatName", "GetAll", "GetAllCached", "Get"})
        and Methods(core.CharacterCleanup, {"RegisterOwner"})
        and Methods(core.AccountView, {"RegisterPage", "NotifyPageChanged", "Toggle", "BuildContext",
            "GetVisibleCharacters", "GetEffectiveCharacterSort", "GetCustomCharacterOrder"})
        and Methods(core.Entry, {"RegisterBusinessEntry"})
        and Methods(core.UITheme, {"CreateInput", "CreateDropdown", "ApplyPixelBackdrop", "ApplyPixelRule", "GetPixelSize", "SetPixelAnchor"})
        and Methods(core.ItemResolver, {"GetInfo", "Request"})
        and (not (Addon.FEATURES.send or Addon.FEATURES.collect) or Methods(core.ItemConfirmation, {"Show"}))
        and (not Addon.FEATURES.send or Methods(core, {"CreateItemPicker"}))
end
local function Initialize(core)
    local state = Addon._startup or {}; Addon._startup = state
    if not state.database then
        if not Addon:InitializeDatabase() then return nil, Addon:T("FOREVER.STORE_MISMATCH") end
        state.database = true
    end
    if not state.registered then
        local ok, err = core:RegisterAddon(Addon.NAME, {version=Addon.VERSION, requiredAPI=Addon.REQUIRED_CORE_API})
        if not ok then return nil, err or Addon:T("ERROR.CORE_REGISTER") end
        state.registered = true
    end
    if Addon.FEATURES.contacts and not state.contacts then Addon.Recipients:Initialize(); state.contacts=true end
    if Addon.FEATURES.rules and not state.rules then Addon.SendRules:Initialize(); state.rules=true end
    if not state.cleanup then
        local ok, err = core.CharacterCleanup:RegisterOwner(Addon.NAME, {
            Inspect=function(character, aliases)
                local hasData = Addon.db.byCharacter[character.id] ~= nil
                    or (Addon.FEATURES.contacts and Addon.Recipients:HasCharacter(character, aliases))
                for id in pairs(aliases or {}) do if Addon.db.byCharacter[id] then hasData=true end end
                return {hasData=not not hasData, label=Addon:T("UI.TEXT_0596")}
            end,
            Delete=function(character, aliases)
                Addon:DeleteCharacter(character)
                for id in pairs(aliases or {}) do Addon:DeleteCharacter({id=id}) end
                if Addon.FEATURES.contacts then Addon.Recipients:DeleteCharacter(character, aliases) end
                return true
            end})
        if not ok then return nil, err or Addon:T("ERROR.CLEANUP_REGISTER") end
        state.cleanup=true
    end
    if Addon.FEATURES.account and not state.page then
        local ok, err = Addon.AccountPage:Register()
        if not ok then return nil, err or Addon:T("ERROR.PAGE_REGISTER") end
        state.page=true
    end
    if Addon.FEATURES.account and not state.signal then
        Addon._pageChangedSignal = Addon._pageChangedSignal or function() core.AccountView:NotifyPageChanged("mail-inbox") end
        Addon.Items.Events:RegisterSignal(Addon.AccountPage, Addon._pageChangedSignal)
        state.signal=true
    end
    if Addon.CAPABILITIES["mail-items.transfers"] and not state.migration then
        local ok, err = Addon.Items:MigrateLegacyTransfers()
        if not ok then return nil, Addon:T("ERROR.TRANSFER_MIGRATION", tostring(err)) end
        state.migration=true
    end
    if not state.service then
        local ok, err = Addon.Items:RegisterService()
        if not ok then return nil, err or Addon:T("ERROR.ITEMS_REGISTER") end
        state.service=true
    end
    state.events = state.events or {}
    Addon._unsupportedEvents = Addon._unsupportedEvents or {}
    for _, event in ipairs(Addon.Target.events) do
        if not state.events[event] then
            local ok, reason = pcall(Addon.Frame.RegisterEvent, Addon.Frame, event)
            if not ok then Addon._unsupportedEvents[event]=tostring(reason); return nil, tostring(reason) end
            state.events[event]=true
        end
    end
    if not state.hooks then
        if Addon.FEATURES.collect then Addon.Scanner:InstallHooks(); Addon.Queue:Install() end
        if Addon.FEATURES.send then Addon.Compose:Install() end
        if Addon.FEATURES.collect or Addon.FEATURES.send then Addon.NativeUI:Install() end
        state.hooks=true
    end
    return true
end
function Addon:Initialize()
    if self.initialized then return true end
    if self._initializing then return false end
    if not self.CLIENT_SUPPORTED then self:Print(self:T("FOREVER.WRONG_CLIENT")); return false end
    local core = _G.YiboCore
    if not CoreReady(core) then
        if core and core.Print and not (core.Locale and core.Locale.Get) then
            core:Print("YiboMail requires a matching YiboCore with API 14 and the required mail capabilities.")
        else self:Print(self:T("BOOTSTRAP.UPGRADE_CORE")) end
        return false
    end
    self.Core, self._initializing = core, true
    local executed, ok, err = pcall(Initialize, core)
    self._initializing = nil
    if not executed or not ok then self:Print(executed and err or tostring(ok)); return false end
    self.initialized=true
    if self.Expiry then self.Expiry:Seed(); self.Expiry:WatchAuctionTimings() end
    if self.FEATURES.contacts then self.Recipients:RequestFriends(true) end
    self:PruneHistory()
    if self.GoalTargets then self.GoalTargets:Initialize() end
    if self.ActionTodo then local ready, reason=self.ActionTodo:Initialize(); if not ready then self:Print(reason) end end
    return true
end
SLASH_YIBOMAIL1 = "/yma"
SlashCmdList.YIBOMAIL = function(message)
    if not Addon.initialized then Addon:Print(Addon:T("FOREVER.NOT_READY")); return end
    local command=(message or ""):match("^%s*(%S*)")
    if command=="scan" then
        local ok, err=Addon.Scanner:Scan(Addon.Target.manualScan)
        local reasons = { ["mailbox-unavailable"] = "UI.TEXT_0520", ["character-unavailable"] = "UI.TEXT_0505",
            ["command-pending"] = "FOREVER.PENDING", ["inbox-not-ready"] = "FOREVER.PENDING" }
        Addon:Print(Addon:T(ok and "UI.TEXT_0604" or reasons[err] or "FOREVER.ERROR"))
    elseif command=="status" then
        local character=Addon.Core.Characters:GetCurrent({identityOnly=true})
        local state=character and Addon.Items:GetState(character.id)
        Addon:Print(state and (state.status.." · "..tostring(state.currentCount or 0).."/"..tostring(state.totalCount or 0).." · revision "..Addon.Items:GetRevision()) or Addon:T("UI.TEXT_0505"))
    elseif Addon.FEATURES.account then Addon.Core.AccountView:Toggle("mail-inbox")
    else Addon:Print(Addon:T("UI.TEXT_0345")) end
end
Addon.Frame:RegisterEvent("ADDON_LOADED")
Addon.Frame:SetScript("OnEvent", function(_, event, ...)
    if event=="ADDON_LOADED" then if (...)==Addon.NAME then Addon:Initialize() end; return end
    if not Addon.initialized then return end
    if Addon.FEATURES.contacts then Addon.Recipients:OnEvent(event) end
    Addon.Scanner:OnEvent(event,...)
    if Addon.FEATURES.collect then Addon.Queue:OnEvent(event,...) end
    if Addon.FEATURES.send then Addon.Compose:OnEvent(event,...) end
    if Addon.FEATURES.rules then Addon.RuleSendController:OnEvent(event,...) end
    if Addon.FEATURES.collect or Addon.FEATURES.send then Addon.NativeUI:OnEvent(event,...) end
    if event=="PLAYER_LOGIN" and Addon.FEATURES.account then Addon.AccountPage:OnLogin() end
end)
local core=_G.YiboCore
if core and core.Events then core.Events:Register("CORE_READY",Addon,function() Addon:Initialize() end) end
