local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local e, core, mail, fire, flush, box = Boot()
fire("PLAYER_ENTERING_WORLD"); box.open = true; fire("MAIL_SHOW"); flush()
local current = core.Characters:GetCurrent()
local alt = { id = "Player-SessionAlt", name = "Receiver", realm = current.realm, faction = current.faction }
core.Characters.GetAllCached = function() return { current, alt } end
mail:AddHistory(current.id, { state = "in-transit", recipient = alt.name .. "-" .. alt.realm,
    senderFaction = current.faction, subject = "Parcel", observedAt = mail:Now(),
    attachments = { { itemID = 7001, quantity = 3, itemLink = "item:7001" } } })
local function Query()
    local result = assert(mail.Items:GetTransfers(alt.id))
    assert(#result.records == 1 and result.records[1].quantity == 3)
    return result
end
Query()
assert(mail.Items.transferDirectory and mail.Items.transferEvidence, "public queries build derived data")
local snapshot = mail.db.byCharacter[current.id]
local historyCount = #snapshot.history
local callbackCount = 0
mail.Items.Events:RegisterSignal({}, function() Query(); callbackCount = callbackCount + 1 end)
fire("MAIL_INBOX_UPDATE")
local reads = box.reads
fire("MAIL_CLOSED"); box.open = false
assert(callbackCount > 0, "status listeners may query while close publishes")
assert(not mail.Items.transferDirectory and not mail.Items.transferEvidence and not mail.Items.transferIndex
    and next(mail.Items.transfersCache) == nil, "close releases even caches rebuilt by synchronous listeners")
assert(not mail.Scanner.queued and not mail.Scanner.validAt and not mail.Scanner.refreshPending)
assert(mail.Items:GetState(current.id).status == "stale" and #snapshot.history == historyCount)
flush(); assert(box.reads == reads, "scheduled read from the closed session cannot run")
Query(); assert(mail.Items.transferDirectory, "offline query safely rebuilds the same in-transit data")
fire("MAIL_CLOSED"); flush()
assert(not mail.Items.transferDirectory and #snapshot.history == historyCount, "duplicate close is harmless")
box.open = true; fire("MAIL_SHOW"); flush()
assert(mail.Items:GetState(current.id).status == "known" and mail.Items:GetByCharacter(current.id).quantity == 5)
Query()
fire("PLAYER_LEAVING_WORLD"); box.open = false; flush()
assert(not mail.Scanner.inWorld and not mail.Scanner.open and not mail.Items.transferDirectory)
assert(#mail.db.byCharacter[current.id].history == historyCount, "world exit preserves durable history")
print("PASS: Forever close/world exit, listener-rebuilt cache release, stale snapshot, cancelled reads, offline transit rebuild and reopen")
