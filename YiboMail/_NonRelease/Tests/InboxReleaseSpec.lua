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
    CheckAPIVersion = function(_, version) return version == 6 end,
    RegisterAddon = function(_, name) assert(name == "YiboMail"); return true end,
    CharacterCleanup = { RegisterOwner = function(_, name, callbacks) owner = callbacks; assert(name == "YiboMail"); return true end },
    Characters = { GetCurrent = function() return { id = "test", name = "Test", realm = "Realm" } end },
    AccountView = { RegisterPage = Forbidden, Toggle = Forbidden, NotifyPageChanged = Forbidden, ShowSettings = Forbidden },
    Entry = { RegisterBusinessEntry = Forbidden },
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
assert(not addon.FEATURES.send and not addon.FEATURES.account and not addon.FEATURES.settings)
for _, module in ipairs({ "Compose", "Rules", "MailUI", "CacheModel", "CacheUI", "AccountPage", "Settings" }) do
    assert(addon[module] == nil, module .. " unexpectedly loaded")
end
assert(type(addon.GetInboxActions) == "function" and addon:GetInboxPreferences().sort == "inbox")
assert(addon.db.contacts.marker == "contact" and addon.db.rules.marker == "rule")
assert(addon.Frame.events.MAIL_INBOX_UPDATE and addon.Frame.events.MAIL_SUCCESS)
assert(not addon.Frame.events.MAIL_SEND_SUCCESS and not addon.Frame.events.MAIL_SEND_INFO_UPDATE)
SlashCmdList.YIBOMAIL("")
SlashCmdList.YIBOMAIL("status")
assert(#messages == 2 and messages[1]:find("/yma status", 1, true))
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
print("PASS: client read state scanned and published without changing mail identity or registering disabled account pages")
print("PASS: release TOC boot; inbox dependencies; disabled pages/settings/send/events; saved rules and contacts preserved; diagnostic slash and mailbox lifecycle")
