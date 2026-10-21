-- Run from the repository root using Lua 5.1. Load the actual release manifest.
function CreateFrame()
    return {
        events = {}, scripts = {}, hooks = {},
        RegisterEvent = function(self, event) self.events[event] = true end,
        SetScript = function(self, event, callback) self.scripts[event] = callback end,
        HookScript = function(self, event, callback) self.hooks[event] = callback end,
    }
end
function GetServerTime() return 1000 end
SlashCmdList = {}
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
local function Forbidden() error("Release startup must not construct or open native UI") end
local owner, registeredAddons, registeredContracts, contractRegistrations = nil, 0, {}, 0
local current = { id = "test", name = "Test", realm = "Realm", faction = "Alliance" }
local coreAPI = 13
local requiredCapabilities = {
    localization = 1, ["business-services"] = 1, ["character-name-format"] = 1,
    ["basic-input"] = 1, ["item-resolver"] = 1, ["item-picker"] = 2,
    ["character-identity"] = 1, characters = 1, ["character-cleanup"] = 1,
    ["account-view"] = 2, ["account-preview-characters"] = 1,
    ["account-character-admission"] = 1, ["account-surface-budget"] = 1, ["account-entry"] = 2,
}
YiboCore = {
    CheckAPIVersion = function(_, version) return version <= coreAPI end,
    IsInitialized = function() return true end,
    Print = function(_, message) messages[#messages + 1] = message end,
    RegisterAddon = function(_, name, options)
        assert(name == "YiboMail" and options.requiredAPI == 13)
        registeredAddons = registeredAddons + 1; return true
    end,
    Contracts = {
        Register = function(_, name, definition)
            assert(name == "YiboMail" and definition.version.major == 1)
            contractRegistrations = contractRegistrations + 1
            registeredContracts[definition.name] = definition
            return "release:" .. definition.name
        end,
        NotifyChanged = function() end, List = function() return {} end,
        Unregister = function(_, _, ref) registeredContracts[ref:match("^release:(.+)$")] = nil end,
    },
    CharacterCleanup = { RegisterOwner = function(_, name, callbacks) owner = callbacks; assert(name == "YiboMail"); return true end },
    Characters = {
        GetCurrent = function() return current end, GetAllCached = function() return { current } end,
        Get = function(_, id) return id == current.id and current or nil end,
        FormatName = function(_, character) return character.name end,
    },
    AccountView = {
        RegisterPage = function(_, addonName, definition)
            assert(addonName == "YiboMail" and definition.id == "mail-inbox")
            assert(#definition.fields == 22 and definition.previewEnabled)
            local seen = {}; for _, field in ipairs(definition.fields) do
                assert(not seen[field.id]); seen[field.id] = true
                if field.groupID ~= "overview" then assert(field.preview == false) end
            end
            assert(seen["inbox.subject"] and seen["history.result"] and seen.backlog)
            return definition
        end,
        Toggle = function() end,
        NotifyPageChanged = function() end,
        ShowSettings = function() end,
        BuildContext = Forbidden, GetVisibleCharacters = function() return { current } end,
        GetEffectiveCharacterSort = function() return "default" end, GetCustomCharacterOrder = function() return {} end,
    },
    Entry = { RegisterBusinessEntry = function(_, addonName, definition)
        assert(addonName == "YiboMail" and definition.id == "yma" and definition.pageID == "mail-inbox")
        return definition
    end },
    UITheme = { CreateInput = Forbidden },
    CreateItemPicker = Forbidden, ItemResolver = { Request = Forbidden },
    Defaults = { Copy = function(_, value) return YiboMail.Copy(value) end },
}
dofile("YiboCore/_NonRelease/Tests/LoadLocale.lua")
for name, version in pairs(requiredCapabilities) do YiboCore.Capabilities:Register(name, version) end
YiboMailDB = { contacts = { marker = "contact" }, rules = { marker = "rule" }, settings = { inbox = { sort = "inbox" } } }
for line in io.lines("YiboMail/YiboMail.toc") do
    local file = line:match("^%s*([^#%s].-)%s*$")
    if file then dofile("YiboMail/" .. file) end
end
local addon = YiboMail
addon.Frame.scripts.OnEvent(addon.Frame, "ADDON_LOADED", "YiboMail")
assert(addon.initialized and owner)
assert(addon.FEATURES.send and not addon.FEATURES.sendAssist and addon.FEATURES.account and addon.FEATURES.settings)
assert(addon.SendRules and addon.RuleSendController and addon.RuleSendUI and addon.SendRulesSettings)
for _, module in ipairs({ "MailUI", "CacheModel", "CacheUI", "AccountPage" }) do assert(addon[module] ~= nil, module .. " failed to load") end
assert(addon.Rules == nil and addon.Settings == nil)
assert(type(addon.GetInboxActions) == "function" and addon:GetInboxPreferences().sort == "inbox")
assert(addon.db.contacts.marker == "contact" and addon.db.rules.marker == "rule")
assert(addon.Frame.events.MAIL_INBOX_UPDATE and addon.Frame.events.MAIL_SUCCESS)
assert(addon.Frame.events.MAIL_SEND_SUCCESS and addon.Frame.events.MAIL_SEND_INFO_UPDATE)
SlashCmdList.YIBOMAIL("")
SlashCmdList.YIBOMAIL("status")
assert(#messages == 3 and messages[1] == addon:T("APP.PREFIX") .. addon:T("UI.TEXT_0099")
    and messages[2] == addon:T("APP.PREFIX") .. addon:T("UI.TEXT_0495") and messages[3]:find("not-yet-scanned", 1, true))
assert(addon.GoalTargets.ref == nil and addon.initialized) -- New enhancement stops explicitly; base remains available.
assert(addon.ActionTodo.ref == nil and addon.initialized) -- Missing optional provider capability preserves base mail.
assert(registeredAddons == 1 and registeredContracts['mail.items'] and not registeredContracts['action.todo']
    and not registeredContracts['action.targets'])
assert(addon.Core.AccountView)
addon.Frame.scripts.OnEvent(addon.Frame, "MAIL_CLOSED")
addon.Frame.scripts.OnEvent(addon.Frame, "PLAYER_REGEN_ENABLED")
addon.Frame.hooks.OnUpdate()
assert(not addon.NativeUI.installed) -- Native mailbox can load later.
MailFrame = { IsShown = function() return true end }
GetInboxNumItems = function() return 1, 1 end
local wasRead = false
GetInboxHeaderInfo = function() return nil, nil, "Sender", "Subject", 0, 0, 20, 0, wasRead, false end
GetInboxItem = function() return nil end
addon.Scanner.open, addon.Scanner.updated = true, true
assert(addon.Scanner:Scan())
local snapshot = addon.db.byCharacter.test
local key, revision = snapshot.visibleKeys[1], addon.db.revision
local signature = snapshot.records[key].signature
assert(snapshot.records[key].wasRead == false)
wasRead = true; assert(addon.Scanner:Scan())
assert(snapshot.visibleKeys[1] == key and snapshot.records[key].signature == signature)
assert(snapshot.records[key].wasRead == true and addon.db.revision > revision)
print("PASS: client read state scanned and published without changing mail identity; Core account page and business entry are registered")
-- Recents use the captured send recipient, even after native input reset.
addon.Core.Characters.GetAllCached = function() return { addon.Core.Characters:GetCurrent() } end
SendMailNameEditBox = { GetText = function() return "" end, SetText = function() end }
addon.Compose.pendingSend = { characterID = "test", recipient = "Success-Realm", subject = "subject", attachments = {}, observedAt = 1000 }
addon.Compose:OnEvent("MAIL_SEND_SUCCESS")
assert(addon.db.recentRecipients[1].address == "Success-Realm")
addon.Compose.pendingSend = { characterID = "test", recipient = "Failed-Realm", subject = "subject", attachments = {}, observedAt = 1000 }
addon.Compose:OnEvent("MAIL_FAILED")
assert(#addon.db.recentRecipients == 1)
addon.Compose:OnEvent("MAIL_SEND_SUCCESS"); assert(#addon.db.recentRecipients == 1)
addon.db.friendsByCharacter.friendOnly = { addresses = {}, updatedAt = 1000 }
assert(owner.Inspect({ id = "friendOnly" }, {}).hasData)
owner.Delete({ id = "friendOnly" }, {}); assert(not addon.db.friendsByCharacter.friendOnly)
print("PASS: release send success captured recipient; failed/unassociated sends excluded; friend-only cleanup owner")
print("PASS: release TOC boot; native send tracking without send-assist UI; Core page and entry registration; saved rules and contacts preserved; diagnostic slash and mailbox lifecycle")
addon:Initialize(); assert(registeredAddons == 1 and contractRegistrations == 1, 'Startup is idempotent')
-- Optional capabilities may register after base startup without restarting it.
YiboCore.Capabilities:Register('business-providers', 1)
assert(addon.ActionTodo:Initialize() and registeredContracts['action.todo'])
local tasks = registeredContracts['action.todo'].methods.Query({ scope = { characterIDs = { 'test' } } })
assert(tasks.providerID == addon.ActionTodo.PROVIDER and tasks.coverage.test.state == 'known')
YiboCore.Capabilities:Register('business-item-actions', 1)
YiboCore.BusinessItemActions = { Bind = Forbidden, Handle = Forbidden }
assert(addon.GoalTargets:Initialize() and registeredContracts['action.targets'])
local intent = { objectID = 'view-mailbox', scope = { characterID = 'test' } }
local normalized = registeredContracts['action.targets'].methods.Normalize({ intent = intent })
assert(normalized.intent.scope.characterID == 'test' and normalized.intent.targetType == 'mail-view' and not intent.targetType)
assert(contractRegistrations == 3)
assert(addon.ActionTodo:Initialize() and addon.GoalTargets:Initialize() and contractRegistrations == 3)
addon.ActionTodo:Shutdown(); assert(not addon.ActionTodo.ref and not registeredContracts['action.todo'] and addon.initialized)
local list = YiboCore.Contracts.List
YiboCore.Contracts.List = nil
assert(not addon.ActionTodo:Initialize() and not addon.ActionTodo.ref and addon.initialized)
YiboCore.Contracts.List = list
assert(addon.ActionTodo:Initialize() and registeredContracts['action.todo'])
print('PASS: missing optional enhancements preserve base mail; late registration, public provider methods, repeated registration and provider shutdown/recovery')

local originalDB, savedDB = addon.InitializeDatabase, addon.db
addon.InitializeDatabase = function() error('Unsupported Core must stop before database initialization') end
local rejectionCount = 0
local function Reject(label, apply, restore)
    for _, language in ipairs({ 'zh', 'en' }) do
        YiboCore.Locale.language = language
        local messageCount, addonCount = #messages, registeredAddons
        addon.initialized = nil; apply()
        addon:Initialize()
        assert(not addon.initialized and registeredAddons == addonCount and addon.db == savedDB, label)
        assert(#messages == messageCount + 1 and messages[#messages]:find('YiboCore', 1, true), label .. ': upgrade prompt missing')
        restore(); rejectionCount = rejectionCount + 1
    end
end
Reject('Core API12', function() coreAPI = 12 end, function() coreAPI = 13 end)
local isInitialized = YiboCore.IsInitialized
Reject('Core not ready', function() YiboCore.IsInitialized = function() return false end end,
    function() YiboCore.IsInitialized = isInitialized end)
for name, version in pairs(requiredCapabilities) do
    local capability, minimum = name, version
    Reject('capability ' .. capability,
        function() YiboCore.Capabilities._items[capability] = minimum - 1 end,
        function() YiboCore.Capabilities._items[capability] = minimum end)
end
local requiredMethods = {
    { YiboCore, 'CheckAPIVersion' }, { YiboCore, 'HasCapability' }, { YiboCore, 'IsInitialized' },
    { YiboCore.Locale, 'Get' }, { YiboCore.Locale, 'Register' },
    { YiboCore.Contracts, 'Register' }, { YiboCore.Contracts, 'NotifyChanged' },
    { YiboCore.Characters, 'FormatName' }, { YiboCore.Characters, 'GetAllCached' }, { YiboCore.Characters, 'Get' },
    { YiboCore.CharacterCleanup, 'RegisterOwner' },
    { YiboCore.AccountView, 'RegisterPage' }, { YiboCore.AccountView, 'NotifyPageChanged' },
    { YiboCore.AccountView, 'Toggle' }, { YiboCore.AccountView, 'BuildContext' },
    { YiboCore.AccountView, 'GetVisibleCharacters' }, { YiboCore.AccountView, 'GetEffectiveCharacterSort' },
    { YiboCore.AccountView, 'GetCustomCharacterOrder' }, { YiboCore.Entry, 'RegisterBusinessEntry' },
    { YiboCore.UITheme, 'CreateInput' }, { YiboCore, 'CreateItemPicker' }, { YiboCore.ItemResolver, 'Request' },
}
for _, entry in ipairs(requiredMethods) do
    local target, method = entry[1], entry[2]
    local original = target[method]
    Reject('method ' .. method, function() target[method] = nil end, function() target[method] = original end)
end
addon.InitializeDatabase, addon.initialized = originalDB, true
print(string.format('PASS: %d Chinese/English API, readiness, capability-version and required-method failures prompt upgrade before database initialization', rejectionCount))
