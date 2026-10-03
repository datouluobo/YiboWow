-- Simulate an external consumer using only the public Items API.
function CreateFrame() return {} end
function GetServerTime() return 1234 end
for _, name in ipairs({ "Namespace", "Store", "Items", "Scanner" }) do dofile("YiboMail/" .. name .. ".lua") end
local addon, api = YiboMail, YiboMail.Items
local current = { id = "Current", name = "Current", realm = "Realm" }
local hidden = { id = "Hidden", name = "Hidden", realm = "Realm" }
addon.Core = { Characters = {
    GetCurrent = function() return current end,
    GetAllCached = function() return { current, hidden } end,
}, AccountView = { GetVisibleCharacters = function() return { current } end } }
local function NoClientRead() error("Public queries must not scan or read mail") end
GetInboxNumItems, GetInboxHeaderInfo, GetInboxItem, GetInboxItemLink, GetInboxText = NoClientRead, NoClientRead, NoClientRead, NoClientRead, NoClientRead
assert(api:Query().quantity == 0)
assert(api:GetState("Current").status == "not-yet-scanned")
addon:InitializeDatabase()
local item = { itemID = 123, quantity = 7, attachmentIndex = 3, itemKey = "item:123", variantKey = "link:item:123:0", identityQuality = "full-link", itemLink = "|Hitem:123:0|h[Test]|h" }
local function Seed(character)
    addon.db.byCharacter[character.id] = { visibleKeys = { "key" }, records = { key = {
        mailKey = "key", inboxIndex = 2, signature = "signature", attachments = { addon.Copy(item) }, state = "observed",
        sender = "Sender", subject = "Subject", mailType = "ordinary", observedAt = 1234, clockSource = "server", expiresAtEstimate = 2000, daysLeftAtScan = 1,
    } }, coverage = { status = "known", currentCount = 1, totalCount = 1, observedAt = 1234, revision = 0 } }
end
Seed(current); Seed(hidden)
MailFrame = { IsShown = function() return true end }
addon.Scanner.open, addon.Scanner.updated, addon.Scanner.validAt = true, true, 1234
local query = assert(api:Query())
local record = assert(query.records[1])
assert(record.itemID == 123 and record.quantity == 7 and query.quantity == 7)
assert(record.source == "mail" and record.sourceClass == "external" and record.characterID == "Current" and record.realm == "Realm")
assert(record.sourceID == "mail:Current:key:3" and record.mailKey == "key" and record.attachmentIndex == 3)
assert(record.location.container == "inbox" and record.location.slot == 2 and record.location.attachmentIndex == 3)
assert(record.itemKey == "item:123" and record.variantKey == "link:item:123:0" and record.identityQuality == "full-link")
assert(record.observedAt == 1234 and record.clockSource == "server" and record.state == "observed")
assert(record.sender == "Sender" and record.subject == "Subject" and record.mailType == "ordinary")
assert(record.expiresAtEstimate == 2000 and record.daysLeftAtScan == 1)
assert(api:Query({ scope = { mode = "account" } }).quantity == 7)
assert(api:GetByCharacter("Hidden").quantity == 7)
assert(api:GetByCharacter("Unknown").quantity == 0)
assert(api:Query({ scope = { mode = "characters", characterIDs = { "Hidden", "Current", "Hidden" } } }).quantity == 14)
assert(api:Query({ scope = { mode = "realm", realm = "realm" } }).quantity == 0)
local savedRevision = api:GetRevision()
query.records[1].location.slot = 999; query.records[1].quantity = 999; query.coverage.Current.status = "bad"
assert(api:Query().records[1].location.slot == 2 and api:Query().quantity == 7 and api:GetState("Current").status == "known")
local state = api:GetState("Current"); state.status = "bad"
assert(api:GetState("Current").status == "known" and api:GetRevision() == savedRevision)
local invalid = {
    { { identityMode = false }, "invalid-identity-mode" }, { { identityMode = 0 }, "invalid-identity-mode" },
    { { identityMode = "" }, "invalid-identity-mode" }, { { identityMode = "strict", variantKey = "" }, "invalid-variant-key" },
    { { itemID = 1.5 }, "invalid-item-id" }, { { itemID = 0/0 }, "invalid-item-id" },
    { { itemID = math.huge }, "invalid-item-id" }, { { includeStale = "false" }, "invalid-include-stale" },
    { { scope = { mode = "characters", characterIDs = { "Current", false } } }, "invalid-scope" },
}
for _, test in ipairs(invalid) do local result, err = api:Query(test[1]); assert(result == nil and err == test[2], test[2]) end
local callbackCount = 0
local callbackErrors = {}
geterrorhandler = function() return function(message) callbackErrors[#callbackErrors + 1] = message end end
local owner = {}
local function OnChange(event, payload)
    callbackCount = callbackCount + 1
    local refreshed = assert(api:Query({ includeStale = false }))
    assert(event == "MAIL_ITEMS_CHANGED" and refreshed.revision == payload.revision and refreshed.quantity == 7)
    assert(refreshed.coverage.Current.revision == payload.revision)
    payload.changedMailKeys[1] = "mutated"
end
assert(api.Events:Register(owner, OnChange)); assert(api.Events:Register(owner, OnChange))
addon:Publish("Current", { "key" }, { 123 }, "scan")
assert(callbackCount == 1 and #callbackErrors == 0 and addon.db.byCharacter.Current.visibleKeys[1] == "key")
api.Events:Unregister(owner, OnChange)
addon:Publish("Current", {}, {}, "scan"); assert(callbackCount == 1)
assert(select(2, api.Events:Register(nil, OnChange)) == "invalid-listener")
assert(select(2, api.Events:Register(owner, false)) == "invalid-listener")
addon.Scanner.lastError = "scan-failed"
assert(api:GetState("Current").status == "error" and api:Query({ includeStale = false }).quantity == 0)
assert(api:Query().records[1].state == "stale")
addon.db.byCharacter.Current = nil
assert(api:GetState("Current").status == "error", "First failed scan is also an error, not known-empty")
print("PASS: external consumer calls; complete record schema; hidden/unknown/exact scopes; read-only queries; nested copies; invalid parameter matrix; event subscription and revision; failed/unscanned states")
