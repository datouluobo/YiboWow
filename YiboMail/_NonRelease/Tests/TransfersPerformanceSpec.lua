-- Real Mail transfer queries, history and lifecycle publication. Optional
-- "baseline" argument loads HEAD's Items implementation for comparison.
function CreateFrame() return {} end
function GetServerTime() return 1000 end
local characters = {}
for index = 1, 20 do characters[index] = { id = "c" .. index, name = "Name" .. index, realm = "Realm" } end
YiboCore = { Characters = { GetAllCached = function() return characters end, GetCurrent = function() return characters[1] end } }
for _, name in ipairs({ "Namespace", "Store", "Recipients", "Items", "Mists/Scanner" }) do dofile("YiboMail/" .. name .. ".lua") end
local Addon = YiboMail; Addon.Core = YiboCore
if arg[1] == "baseline" then
    local pipe = assert(io.popen("git show HEAD:YiboMail/Items.lua"))
    local source = pipe:read("*a"); pipe:close(); assert(loadstring(source))()
end
dofile('_NonRelease/MailPerformance20261029/IdentityMock.lua')(Addon.Core.Characters)
Addon:InitializeDatabase()
local function Snapshot()
    return { records = {}, visibleKeys = {}, history = {}, coverage = { status = "known", observedAt = 1000 } }
end
for _, character in ipairs(characters) do Addon.db.byCharacter[character.id] = Snapshot() end
local sender, recipient = Addon.db.byCharacter.c1, Addon.db.byCharacter.c2
local attachment = { itemID = 123, quantity = 2, variantKey = "item:123" }
for index = 1, 1200 do
    sender.history[#sender.history + 1] = { state = "in-transit", recipient = "Name2-Realm", subject = "Goods",
        attachments = { attachment }, observedAt = 100, eventID = "send" .. index }
end
for index = 1, 500 do
    sender.history[#sender.history + 1] = { state = "collected-archived", observedAt = 200, eventID = "return" .. index,
        mail = { sender = "Name2", subject = "Goods", wasReturned = true, attachments = { attachment } } }
end
for index = 1, 1711 do
    sender.history[#sender.history + 1] = { state = "discovered", observedAt = 200, eventID = "filler" .. index,
        mail = { sender = "Auction House", subject = "Sale", attachments = {} } }
end
for index = 1, 300 do
    recipient.history[index] = { state = "collected-archived", observedAt = 200, eventID = "receipt" .. index,
        mail = { sender = "Name1", subject = "Goods", attachments = { attachment } } }
end
local normalizations, normalize = 0, Addon.Recipients.Normalize
function Addon.Recipients:Normalize(...) normalizations = normalizations + 1; return normalize(self, ...) end
Addon:Publish("c1", {}, {}, "archive")
collectgarbage("collect")
collectgarbage("stop")
local started, memory = os.clock(), collectgarbage("count")
for _, character in ipairs(characters) do
    local result = assert(Addon.Items:GetTransfers(character.id))
    assert(#result.records == (character.id == "c2" and 400 or 0), "Duplicate receipt/return multiplicity must be preserved")
end
local elapsed = os.clock() - started
local allocated = collectgarbage("count") - memory
collectgarbage("restart")
print(string.format("SAMPLE: 20 characters / 3411 sender history + 300 receipts; %.4fs, %.2f MB allocated, %d address normalizations", elapsed, allocated / 1024, normalizations))
if arg[1] == "baseline" then return end
assert(normalizations < 10000, "Account-wide matching must not rescan history per send/recipient")
local count = normalizations
for index = 1, 30 do
    Addon:Publish("c1", {}, {}, "scan", true)
    local result = Addon.Items:GetTransfers("c2")
    assert(#result.records == 400 and result.revision == Addon.db.revision)
    result.records[1].quantity = 999
end
assert(normalizations == count, "Open/close/read status must reuse transfer evidence")
assert(Addon.Items:GetTransfers("c2").records[1].quantity == 2, "Cached results must remain isolated")
-- A genuinely new receipt invalidates matching, unlike readiness changes.
recipient.history[#recipient.history + 1] = { state = "discovered", observedAt = 200, eventID = "new",
    mail = { sender = "Name1", subject = "Goods", attachments = { attachment } } }
Addon:Publish("c2", {}, {}, "scan")
assert(#Addon.Items:GetTransfers("c2").records == 399)
assert(normalizations > count)
-- Too-old receipts, wrong variants, non-account senders and future sends
-- cannot confirm an unrelated in-transit stack.
sender.history[#sender.history + 1] = { state = "in-transit", recipient = "Name2-Realm", subject = "Goods",
    attachments = { attachment }, observedAt = 300, eventID = "future" }
Addon:Publish("c1", {}, {}, "archive")
assert(#Addon.Items:GetTransfers("c2").records == 400)
characters[2].name = "Renamed"
assert(#Addon.Items:GetTransfers("c2").records == 0, "Directory changes must invalidate address matching")
MailFrame = { IsShown = function() return true end }
Addon.Scanner.open, Addon.Scanner.updated = true, true
Addon.Scanner.publishedStatus.c1 = "known"
count = normalizations
Addon.Scanner:Close()
assert(Addon.Items.transferIndex == nil and next(Addon.Items.transfersCache) == nil, "Close releases derived matching caches")
assert(#Addon.Items:GetTransfers("c2").records == 0 and normalizations > count, "A query after close safely rebuilds matching without changing results")
count = normalizations
assert(#Addon.Items:GetTransfers("c2").records == 0 and normalizations == count, "Repeated closed-mailbox queries reuse the rebuilt result")
print("PASS: shared linear history index; duplicate matching; read/status cache reuse; current revision; isolated results; content and directory invalidation; timestamp eligibility")

-- Real native automatic acknowledgement publishes once per mailbox, not once
-- per letter (each publication fans out to all account consumers).
dofile("YiboMail/NativeUI.lua"); dofile("YiboMail/Mists/InboxUI.lua")
Addon.Queue = { state = "idle" }
MailFrame = { IsShown = function() return true end }
Addon.Scanner.open = true
Addon.Scanner.ReadEntry = function(_, entry) return entry.mail end
GetInboxText = function() return "Letter" end
local entries, notifications = {}, 0
for index = 1, 100 do
    local key = "m" .. index
    local mail = { signature = key, inboxIndex = index, state = "observed", attachments = {} }
    sender.records[key], sender.visibleKeys[index] = mail, key
    entries[index] = { character = characters[1], key = key, mail = mail }
end
Addon.Items.Events:Register({}, function(_, payload)
    notifications = notifications + 1
    assert(#payload.changedMailKeys == 100)
    for _, entry in ipairs(entries) do assert(entry.mail.openedByUser and entry.mail.noticeHandled) end
end)
Addon.NativeUI:ReadDisplayedMails(entries)
assert(notifications == 1, "100 displayed letters must produce one coherent notification")
Addon.NativeUI:ReadDisplayedMails(entries)
assert(notifications == 1, "Already acknowledged letters must not republish")
print("PASS: 100 native letter acknowledgements produce one completed mailbox notification; repeated refresh is quiet")
