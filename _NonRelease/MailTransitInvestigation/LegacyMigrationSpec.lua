function CreateFrame() return {} end
local boundary, now = 1791784788, 1792476240
function GetServerTime() return now end
local sender = { id = "sender", name = "Sender", realm = "Realm" }
local receiver = { id = "receiver", name = "Receiver", realm = "Realm" }
YiboCore = { Characters = { GetAllCached = function() return { sender, receiver } end,
    GetCurrent = function() return sender end, FormatName = function(_, c) return c.name end } }
for _, file in ipairs({ "Namespace", "Store", "Recipients", "Items", "Mists/TransferMigration", "HistoryModel" }) do dofile("YiboMail/" .. file .. ".lua") end
local addon = YiboMail; addon.Core = YiboCore
addon:InitializeDatabase()
local function Item(n) return { itemID = 72095, quantity = n } end
local function Send(id, at, items)
    return { eventID = id, state = "in-transit", recipient = "Receiver-Realm", observedAt = at, attachments = items }
end
local old = Send("h1", boundary - 86400, { Item(15) })
local confirmed = Send("h2", boundary - 86400, { Item(4) })
local modern = Send("h3", boundary + 1, { Item(20), Item(17), Item(20), Item(20), Item(4), Item(20) })
addon.db.byCharacter.sender = { history = { old, confirmed, modern }, records = {}, visibleKeys = {}, coverage = {} }
addon.db.byCharacter.receiver = { history = {}, records = { receipt = {
    state = "observed", sender = "Sender", attachments = { Item(4) }, observedAt = boundary } }, visibleKeys = {}, coverage = {} }
local function Total()
    local total = 0; for _, record in ipairs(addon.Items:GetTransfers(receiver.id).records) do total = total + record.quantity end; return total
end
assert(Total() == 116, "Reproduce legacy 15 plus modern 101 before migration")
local originalHistory = addon.Copy(addon.db.byCharacter.sender.history)
assert(addon.Items:MigrateLegacyTransfers())
assert(Total() == 101 and old.transferReview == "legacy-unverified", "Legacy send leaves the active projection and invalidates warm caches")
assert(not confirmed.transferReview and not modern.transferReview, "Confirmed legacy and modern sends retain their behavior")
assert(old.state == "in-transit" and old.attachments[1].quantity == 15 and #addon.db.byCharacter.sender.history == #originalHistory,
    "Original send facts and quantities are preserved")
local rows = addon.HistoryModel:Query({ characters = { sender, receiver } }, { days = 30, result = "unverified" })
assert(#rows == 1 and rows[1].record == old and rows[1].state == "unverified", "Legacy send remains searchable as needs verification")
local revision = addon.db.revision
assert(addon.Items:MigrateLegacyTransfers() and addon.db.revision == revision and Total() == 101, "Migration is idempotent")
dofile("YiboMail/Items.lua"); dofile("YiboMail/Mists/TransferMigration.lua")
assert(addon.Items:MigrateLegacyTransfers() and Total() == 101, "Reload retains the review classification")
addon.db.byCharacter.receiver.records.modern = { state = "observed", sender = "Sender", observedAt = now, attachments = addon.Copy(modern.attachments) }
addon:Publish(receiver.id, {}, {72095}, "scan")
assert(Total() == 0, "Receipt still converts all modern 101 attachments without resurrecting the legacy 15")
-- Unrelated/unknown recipients are not classified without a resolvable projection.
local unknown = Send("h4", boundary - 86400, { Item(8) }); unknown.recipient = "Unknown-Realm"
addon.db.byCharacter.sender.history[#addon.db.byCharacter.sender.history + 1] = unknown
addon.db.transferTrackingMigrationVersion = nil
assert(addon.Items:MigrateLegacyTransfers() and not unknown.transferReview)
print("PASS: legacy 15/modern 101; matched legacy; preserved facts; history review; warm cache; idempotency; reload; receipt; unknown recipient")
