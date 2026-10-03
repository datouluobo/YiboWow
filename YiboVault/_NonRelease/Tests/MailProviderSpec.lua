function CreateFrame() return { HookScript = function() end } end
function GetServerTime() return 1000 end
local character = { id = "A", name = "Alpha", realm = "Realm" }
local other = { id = "B", name = "Beta", realm = "Realm" }
local core = { Characters = { GetCurrent = function() return character end, GetAllCached = function() return { character, other } end },
    AccountView = { GetVisibleCharacters = function() return { character, other } end } }
MailFrame = { IsShown = function() return true end }
for _, file in ipairs({ "Namespace", "Store", "Items", "Scanner" }) do dofile("YiboMail/" .. file .. ".lua") end
YiboMail.Core = core; YiboMail:InitializeDatabase()
local mail = YiboMail
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
assert(Query("A").totals.externalQuantity == 99, "unscanned Mail falls back to Vault")
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
mail.Scanner.open, mail.Scanner.updated = true, true; assert(mail.Scanner:Scan())
assert(#events == 3)
fail = true; assert(not mail.Scanner:Scan())
assert(Query("A").totals.externalQuantity == 99 and #events == 4, "failed Mail switches to one fallback without summing")
fail = false; quantity, total = 0, 0; assert(mail.Scanner:Scan())
assert(Query("A").totals.externalQuantity == 0 and #events == 5, "known-empty Mail overrides the old Vault quantity")
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
_G.YiboMail = nil; provider:Install(); assert(Query("A").totals.externalQuantity == 99)
_G.YiboMail = { Items = { GetAPIVersion = function() return 2 end } }
provider:Install(); assert(Query("A").totals.externalQuantity == 99)
_G.YiboMail = mail; provider:Install(); assert(Query("A").totals.externalQuantity == 2)
assert(#mail.Items.Events.listeners == 2, "reconnecting must replace rather than duplicate the provider subscription")
print("PASS: real Mail API integration; per-character fallback; no duplicate totals; query/state/storage projections; partial/stale/error/empty; committed single Vault events; read-only scan suppression; early consumer race; optional load and subscription lifecycle")
