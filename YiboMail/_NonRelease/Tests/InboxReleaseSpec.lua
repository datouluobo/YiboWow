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
local function Forbidden() error("Disabled feature was registered or opened") end
local owner
YiboCore = {
    CheckAPIVersion = function(_, version) return version == 8 end,
    HasCapability = function(_, name, version) return name == "character-name-format" and version == 1 or name == "item-picker" and version == 2 end,
    RegisterAddon = function(_, name, options) assert(name == "YiboMail" and options.requiredAPI == 8); return true end,
    CharacterCleanup = { RegisterOwner = function(_, name, callbacks) owner = callbacks; assert(name == "YiboMail"); return true end },
    Characters = { GetCurrent = function() return { id = "test", name = "Test", realm = "Realm" } end, FormatName = function(_, character) return character.name end },
    AccountView = {
        RegisterPage = function(_, addonName, definition)
            assert(addonName == "YiboMail" and definition.id == "mail-inbox")
            assert(#definition.fields == 22 and definition.previewEnabled)
            local seen = {}; for _, field in ipairs(definition.fields) do
                assert(not seen[field.id]); seen[field.id] = true
                if field.group ~= "账号总览" then assert(field.preview == false) end
            end
            assert(seen["inbox.subject"] and seen["history.result"] and seen.backlog)
            return definition
        end,
        Toggle = function() end,
        NotifyPageChanged = function() end,
        ShowSettings = function() end,
    },
    Entry = { RegisterBusinessEntry = function(_, addonName, definition)
        assert(addonName == "YiboMail" and definition.id == "yma" and definition.pageID == "mail-inbox")
        return definition
    end },
    UITheme = {},
}
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
assert(#messages == 1 and messages[1]:find("not-yet-scanned", 1, true))
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
SendMailNameEditBox = { GetText = function() return "" end }
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
local originalCheck, originalCapability, originalFormat = YiboCore.CheckAPIVersion, YiboCore.HasCapability, YiboCore.Characters.FormatName
local originalDB = addon.InitializeDatabase
addon.InitializeDatabase = function() error('Unsupported Core must stop before database initialization') end
for _, scenario in ipairs({ 'api', 'names', 'batch', 'method' }) do
    addon.initialized = nil
    YiboCore.CheckAPIVersion = scenario == 'api' and function() return false end or originalCheck
    YiboCore.HasCapability = function(_, name, version)
        if scenario == 'names' and name == 'character-name-format' or scenario == 'batch' and name == 'item-picker' then return false end
        return originalCapability(nil, name, version)
    end
    YiboCore.Characters.FormatName = scenario ~= 'method' and originalFormat or nil
    addon:Initialize(); assert(not addon.initialized and messages[#messages]:find('升级', 1, true))
end
addon.InitializeDatabase = originalDB
print('PASS: old API, missing name/batch capabilities and missing method all prompt upgrade and stop initialization')
