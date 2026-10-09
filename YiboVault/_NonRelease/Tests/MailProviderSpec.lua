function CreateFrame() return { HookScript = function() end } end
function GetServerTime() return 1000 end
local character = { id = "A", name = "Alpha", realm = "Realm" }
local other = { id = "B", name = "Beta", realm = "Realm" }
local core = { Characters = { GetCurrent = function() return character end, GetAllCached = function() return { character, other } end },
    AccountView = { GetVisibleCharacters = function() return { character, other } end, NotifyPageChanged = function() end } }
MailFrame = { IsShown = function() return true end }
YiboCore = core
core.Defaults = { Copy = function(_, value) local function copy(v) if type(v) ~= 'table' then return v end local r = {}; for k,x in pairs(v) do r[k] = copy(x) end return r end return copy(value) end }
core.Capabilities = { Register = function() end }
core.Registry = { Get = function(_, name) return name == 'YiboMail' or name == 'YiboVault' end }
core.Print = function() end
dofile('YiboCore/Runtime/Events.lua')
dofile('YiboCore/Runtime/Contracts.lua')
for _, file in ipairs({ "Namespace", "Store", "Items", "Scanner" }) do dofile("YiboMail/" .. file .. ".lua") end
YiboMail.Core = core; YiboMail:InitializeDatabase()
local mail = YiboMail
assert(mail.Items:RegisterService())
for _, file in ipairs({ "Namespace", "Store", "Items", "MailItems", "MailProvider" }) do dofile("YiboVault/" .. file .. ".lua") end
local vault, provider = YiboVault, YiboVault.MailProvider
vault.Core = core
vault.db = { revision = 0, byCharacter = {}, byGuild = {}, settings = {} }
local function Seed(id, quantity)
    vault:ReplaceLocation(id, "mail", "inbox", { { sourceID = "vault:" .. id, source = "mail", sourceClass = "external", characterID = id, realm = "Realm",
        itemID = 123, quantity = quantity, itemKey = "item:123", variantKey = "link:item:123:0", location = { container = "inbox", slot = 1, attachmentIndex = 1 } } }, { container = "inbox" }, nil,
        { status = "known", currentCount = 1, totalCount = 1, unscannedCount = 0 })
end
Seed("A", 99); Seed("B", 11)
provider:Install()
local function Query(id) return assert(vault.Items:Query({ scope = { mode = "characters", characterIDs = { id } }, sources = { "mail" } })) end
vault.AccountPage = { GetTooltipScope = function()
    return { mode = "characters", characterIDs = { "A" } }, { character }, false
end }
dofile("YiboVault/Tooltip.lua")
local function TooltipText()
    local tooltip = { lines = {} }
    function tooltip:AddLine(line) self.lines[#self.lines + 1] = line end
    function tooltip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. " / " .. right end
    function tooltip:Show() end
    vault.Tooltip:Append(tooltip, 123)
    return table.concat(tooltip.lines, "\n")
end
assert(Query("A").totals.externalQuantity == 99, "unscanned Mail falls back to Vault")
assert(TooltipText():find("账号库存 / |cff20e07099|r", 1, true),
    "Tooltip uses the local snapshot while installed Mail has no successful scan")
local events = {}
vault.Items.Events:Register("test", function(event, payload)
    if payload.source == "mail" then
        local query = Query(payload.characterID)
        assert(event == "VAULT_ITEMS_CHANGED" and query.revision == payload.revision)
        events[#events + 1] = payload
    end
end)
local quantity, total, fail = 7, 3, false
GetInboxNumItems = function() return quantity == 0 and 0 or 1, total end
GetInboxHeaderInfo = function() if fail then error("incomplete") end; return nil, nil, "Sender", "Subject", 0, 0, 20, 1, false, false end
GetInboxItem = function(_, slot) if slot == 1 then return "Item", 123, "icon", quantity end end
GetInboxItemLink = function(_, slot) if slot == 1 then return "|cff0070dd|Hitem:123:0|h[Item]|h|r" end end
mail.Scanner.open, mail.Scanner.updated = true, true
assert(mail.Scanner:Scan())
assert(#events == 1 and Query("A").totals.externalQuantity == 7)
assert(Query("B").totals.externalQuantity == 11)
assert(vault.Items:Query({ scope = { mode = "account" }, sources = { "mail" } }).totals.externalQuantity == 18)
assert(Query("A").coverage.mail.A.locations.inbox.status == "partial")
assert(TooltipText():find("账号库存 / |cff20e0707+|r", 1, true),
    "Tooltip consumes the actual Mail partial snapshot without adding local Vault stock")
assert(vault.Items:GetSourceState("mail", { mode = "characters", characterIDs = { "A" } }).A.locations.inbox.status == "partial")
assert(vault.Items:GetStorageSummary({ mode = "characters", characterIDs = { "A" } }).characters[1].mail.locations[1].status == "partial")
local state = Query("A"); state.records[1].quantity = 999
assert(Query("A").totals.externalQuantity == 7 and vault:GetCachedCharacterRecords("A", "mail")[1].quantity == 99)
local before = vault.Items:GetRevision()
assert(mail.Scanner:Scan()); assert(vault.Items:GetRevision() == before and #events == 1)
local inboxReader = GetInboxNumItems
GetInboxNumItems = function() error("Vault must not rescan when Mail has a usable snapshot") end
assert(vault.MailItems:Scan()); assert(Query("A").totals.externalQuantity == 7)
GetInboxNumItems = inboxReader
mail.Scanner:Close()
assert(Query("A").coverage.mail.A.locations.inbox.status == "stale")
assert(vault.Items:Query({ sources = { "mail" }, includeStale = false }).totals.externalQuantity == 0)
assert(Query("A").totals.externalQuantity == 7 and #events == 2)
assert(TooltipText():find("账号库存 / |cff20e0707+|r", 1, true),
    "closing Mail preserves its numeric partial snapshot in Tooltip")
mail.Scanner.open, mail.Scanner.updated = true, true; assert(mail.Scanner:Scan())
assert(#events == 3)
fail = true; assert(not mail.Scanner:Scan())
assert(Query("A").totals.externalQuantity == 7 and #events == 4, "failed Mail retains its last snapshot with error coverage")
assert(Query("A").coverage.mail.A.locations.inbox.status == 'error')
assert(TooltipText():find("账号库存 / |cff20e0707+|r", 1, true),
    "a failed Mail refresh preserves the last successful Mail snapshot rather than using old local quantities")
fail = false; quantity, total = 0, 0; assert(mail.Scanner:Scan())
assert(Query("A").totals.externalQuantity == 0 and #events == 5, "known-empty Mail overrides the old Vault quantity")
assert(TooltipText() == "", "successful empty Mail removes previous attachments from Tooltip")
-- A caller querying before the adapter's event callback must not swallow notification.
mail.Items.Events:Register("early", function() Query("A") end)
local listeners = mail.Items.Events.listeners
table.insert(listeners, 1, table.remove(listeners))
quantity, total = 2, 1; assert(mail.Scanner:Scan())
assert(Query("A").totals.externalQuantity == 2 and #events == 6)
before = vault.Items:GetRevision()
local key = mail.db.byCharacter.A.visibleKeys[1]
mail:MarkMailOpened({ character = character, key = key, mail = mail.db.byCharacter.A.records[key] })
assert(vault.Items:GetRevision() == before, "opening a letter without inventory changes does not publish a Vault event")
-- Optional dependency absent or incompatible: local cache remains usable.
MailFrame.IsShown = function() return false end
core.Contracts:Unregister('YiboMail', mail.Items.serviceRef); provider:Install(); assert(Query("A").totals.externalQuantity == 99)
assert(TooltipText():find("账号库存 / |cff20e07099|r", 1, true),
    "provider removal invalidates Tooltip and restores independent Vault stock")
local incompatible = assert(core.Contracts:Register('YiboMail', { kind = 'service', name = 'mail.items', providerID = 'YiboMail:inbox', version = { major = 2, minor = 0 }, methods = { GetState = function() end } }))
provider:Install(); assert(Query("A").totals.externalQuantity == 99)
core.Contracts:Unregister('YiboMail', incompatible)
assert(mail.Items:RegisterService()); provider:Install(); assert(Query("A").totals.externalQuantity == 2)
assert(TooltipText():find("账号库存 / |cff20e0702|r", 1, true),
    "late re-registration restores Mail as the single source in Tooltip")
assert(#mail.Items.Events.listeners == 1 and #core.Events._listeners.BUSINESS_CONTRACT_CHANGED == 1, "reconnecting must not duplicate subscriptions")
MailFrame.IsShown = function() return true end
mail.Scanner.open, mail.Scanner.updated = true, true
quantity, total = 0, 0; assert(mail.Scanner:Scan())
quantity, total, fail = 1, 1, true; assert(not mail.Scanner:Scan())
assert(Query("A").totals.externalQuantity == 0
    and Query("A").coverage.mail.A.locations.inbox.status == "error"
    and TooltipText() == "",
    "an error after successful empty Mail retains that empty snapshot instead of resurrecting old local attachments")
print("PASS: real Mail API integration; per-character fallback; no duplicate totals; query/state/storage projections; partial/stale/error/empty; committed single Vault events; read-only scan suppression; early consumer race; optional load and subscription lifecycle")
