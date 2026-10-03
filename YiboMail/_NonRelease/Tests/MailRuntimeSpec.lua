-- Real scanner, store, query API and queue; simulated client data and events.
function CreateFrame() return { hooks = {}, HookScript = function(self, event, callback) self.hooks[event] = callback end } end
local now, shown, inbox, total, timers = 1000, true, {}, 0, {}
local a = { id = "A", name = "Alpha", realm = "Realm" }
local b = { id = "B", name = "Beta", realm = "Other" }
local c = { id = "C", name = "Hidden", realm = "Realm" }
function GetServerTime() return now end
function GetTime() return now end
MailFrame = { IsShown = function() return shown end, HookScript = function() end }
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
local function Flush()
    for iteration = 1, 80 do
        local found
        for index, timer in ipairs(timers) do
            if timer[1] < 1 then found = index; break end
        end
        if not found then return end
        local timer = table.remove(timers, found); timer[2]()
    end
    error("Timer loop did not settle")
end
function GetInboxNumItems() return #inbox, total end
function GetInboxHeaderInfo(index)
    local mail = inbox[index]
    return nil, nil, mail.sender, mail.subject, mail.money or 0, mail.cod or 0, 20, #mail.items, mail.read or false, false
end
function GetInboxItem(index, slot)
    for _, item in ipairs(inbox[index].items) do
        if item.slot == slot then return "Item" .. item.id, item.id, "icon", item.quantity end
    end
end
function GetInboxItemLink(index, slot)
    for _, item in ipairs(inbox[index].items) do
        if item.slot == slot then return "|cff0070dd|Hitem:" .. item.id .. ":" .. (item.variant or 0) .. "|h[Item]|h|r" end
    end
end
function GetContainerNumFreeSlots() return 10, 0 end
local function Item(id, slot, quantity, variant) return { id = id, slot = slot, quantity = quantity, variant = variant } end
local function Mail(subject, items, money, cod) return { sender = "Sender", subject = subject, items = items or {}, money = money or 0, cod = cod or 0 } end
for _, file in ipairs({ "Namespace", "Store", "Items", "Scanner", "ViewModel", "Inbox", "Queue" }) do dofile("YiboMail/" .. file .. ".lua") end
local addon, scanner, api, queue = YiboMail, YiboMail.Scanner, YiboMail.Items, YiboMail.Queue
addon.Core = { Characters = { GetCurrent = function() return a end, GetAllCached = function() return { a, b, c } end },
    AccountView = { GetVisibleCharacters = function() return { a, b } end } }
addon:InitializeDatabase()
local refreshes = 0
addon.NativeUI = { Refresh = function() refreshes = refreshes + 1 end, OnCollected = function() end }
local function Fire(event) scanner:OnEvent(event); queue:OnEvent(event) end
local function Scan(mails, count)
    inbox, total = mails, count or #mails
    scanner.open, scanner.updated = true, true
    assert(scanner:Scan())
end
local notifications = {}
local owner = {}
local function Subscriber(event, payload)
    assert(event == "MAIL_ITEMS_CHANGED" and payload.apiVersion == 1)
    assert(payload.revision == api:GetRevision() and api:Query().revision == payload.revision)
    if addon.db.byCharacter[payload.characterID] then assert(api:GetState(payload.characterID).revision == payload.revision) end
    notifications[#notifications + 1] = payload
end
assert(api.Events:Register(owner, Subscriber)); assert(api.Events:Register(owner, Subscriber))
Scan({ Mail("First", { Item(100, 1, 2), Item(100, 2, 3, 1) }), Mail("Second", { Item(200, 1, 4) }) }, 5)
assert(#notifications == 1 and api:GetState("A").status == "partial")
local result = api:Query(); assert(result.quantity == 9 and #result.records == 3 and result.coverage.A.unscannedCount == 3)
assert(result.records[1].source == "mail" and result.records[1].sourceClass == "external" and result.records[1].state == "observed")
assert(api:Query({ itemID = 100 }).quantity == 5)
assert(api:Query({ identityMode = "strict", variantKey = "link:item:100:1" }).quantity == 3)
result.records[1].quantity = 999; result.coverage.A.status = "bad"
assert(api:Query().quantity == 9 and api:GetState("A").status == "partial")
local capabilities = api:GetCapabilities(); capabilities["mail-items.query"] = 999
assert(api:GetAPIVersion() == 1 and api:HasCapability("mail-items.query", 1) and not api:HasCapability("missing", 1))
local revision = api:GetRevision(); now = now + 1
scanner:Schedule(); Flush()
assert(api:GetRevision() == revision and #notifications == 1 and refreshes >= 2, "unchanged scans refresh UI without publishing")
assert(api:Query({ includeStale = false }).quantity == 9)
local entries = addon.ViewModel:GetMails({ characters = { a } }, {})
assert(not entries[1].mail.openedByUser and not entries[2].mail.openedByUser)
assert(addon:MarkMailOpened(entries[1]))
assert(entries[1].mail.openedByUser and not entries[2].mail.openedByUser)
revision = api:GetRevision(); assert(addon:MarkMailOpened(entries[1])); assert(api:GetRevision() == revision)
inbox[1].read, inbox[2].read = true, true -- Background/client flags cannot mark the second letter opened.
GetInboxText = function() error("Background scanning must not read message bodies") end
assert(scanner:Scan())
assert(addon.db.byCharacter.A.records[entries[1].key].openedByUser and not addon.db.byCharacter.A.records[entries[2].key].openedByUser)
local stateEvents = #notifications
scanner:Close(); assert(api:GetState("A").status == "stale" and api:Query({ includeStale = false }).quantity == 0)
assert(api:Query().quantity == 9 and #notifications == stateEvents + 1)
revision = api:GetRevision(); scanner:Close(); assert(api:GetRevision() == revision)
scanner.open, scanner.updated = true, true; assert(scanner:Scan()); assert(#notifications == stateEvents + 2)
local header = GetInboxHeaderInfo
GetInboxHeaderInfo = function() return nil end
assert(not scanner:Scan()); assert(api:GetState("A").status == "error" and api:Query().quantity == 9)
revision = api:GetRevision(); assert(not scanner:Scan()); assert(api:GetRevision() == revision)
GetInboxHeaderInfo = header; assert(scanner:Scan()); assert(api:GetState("A").status == "partial")
local options = { scope = { mode = "realm", realm = "Other" }, itemID = 100 }
assert(api:GetByCharacter("A", options).quantity == 5 and options.scope.mode == "realm")
local mirrored = addon.Copy(addon.db.byCharacter.A); mirrored.character = b; addon.db.byCharacter.B = mirrored
assert(api:Query({ scope = { mode = "account" } }).quantity == 18)
assert(api:Query({ scope = { mode = "realm", realm = "Other" } }).quantity == 9)
assert(api:Query({ scope = { mode = "characters", characterIDs = { "A", "A", "B" } } }).quantity == 18)
assert(api:Query({ scope = { mode = "characters", characterIDs = {} } }).quantity == 0)
local invalid = {
    { { itemID = 0 }, "invalid-item-id" }, { { identityMode = "bad" }, "invalid-identity-mode" },
    { { variantKey = "item:1" }, "invalid-variant-key" }, { { includeStale = 1 }, "invalid-include-stale" },
    { { scope = { mode = "characters", characterIDs = { [2] = "A" } } }, "invalid-scope" },
    { { scope = { mode = "realm" } }, "invalid-scope" }, { "bad", "invalid-options" },
}
for _, test in ipairs(invalid) do local value, err = api:Query(test[1]); assert(value == nil and err == test[2]) end
assert(select(2, api:GetState("")) == "invalid-character-id")
local received, errors = 0, 0
geterrorhandler = function() return function() errors = errors + 1 end end
api.Events:Register("broken", function() error("consumer failure") end)
api.Events:Register("healthy", function(_, payload) received = received + 1; payload.changedItemIDs[1] = 999 end)
local duplicate = Mail("Duplicate", { Item(300, 1, 5) })
Scan({ duplicate, addon.Copy(duplicate) })
assert(api:Query().quantity == 10 and errors == 1 and received == 1)
local firstKey = addon.db.byCharacter.A.visibleKeys[1]
assert(#addon.db.byCharacter.A.visibleKeys == 2 and firstKey ~= addon.db.byCharacter.A.visibleKeys[2])
assert(not addon.ViewModel:GetMails({ characters = { a } }, {})[1].actionable)
Scan({ duplicate })
assert(api:Query().quantity == 5 and addon.db.byCharacter.A.records[firstKey].state == "unverified")
now = now + 61; assert(scanner:Scan())
assert(addon.db.byCharacter.A.records[firstKey] == nil and api:Query().quantity == 5, "stable complete mailbox clears only unverified backlog")
api.Events:Unregister("broken"); api.Events:Unregister("healthy"); api.Events:Unregister(owner)
local countBefore = #notifications; Scan({}); assert(api:GetState("A").status == "known-empty" and #notifications == countBefore)
shown = false; assert(not scanner:Scan()); assert(api:GetState("A").status == "stale")
shown = true; scanner:Close()
shown = false; scanner:OnEvent("MAIL_SHOW"); scanner:OnEvent("MAIL_INBOX_UPDATE")
assert(scanner.updated)
shown = true; Flush(); assert(api:GetState("A").status == "known-empty")
print("PASS: API query/filters/scopes/errors/copies/capabilities; partial/empty/stale/error/recovery; event ordering/isolation/unsubscribe; idempotent UI refresh; duplicate identities and unverified exclusion")

-- Execute multiple actions against real rescans, including sparse attachment slots.
local taken, order = 0, {}
function TakeInboxMoney(index)
    taken = taken + 1; order[#order + 1] = "money"; inbox[index].money = 0
    Fire("MAIL_INBOX_UPDATE"); Fire("MAIL_SUCCESS")
end
function TakeInboxItem(index, slot)
    taken = taken + 1; order[#order + 1] = slot
    for i, item in ipairs(inbox[index].items) do if item.slot == slot then table.remove(inbox[index].items, i); break end end
    if #inbox[index].items == 0 and inbox[index].money == 0 then table.remove(inbox, index); total = #inbox end
    Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
end
Scan({ Mail("Batch", { Item(100, 1, 2), Item(200, 4, 3) }, 123), Mail("Next", { Item(400, 2, 1) }) })
local selection = {}
for _, entry in ipairs(addon.ViewModel:GetMails({ characters = { a } }, {})) do
    for _, action in ipairs(addon:GetInboxActions(entry)) do selection[action.id] = true end
end
local actions = assert(queue:Prepare(selection, { characters = { a } }))
assert(queue:Start(actions)); Flush()
assert(queue.state == "complete" and queue.completed == 4 and taken == 4 and api:Query().quantity == 0)
assert(order[1] == "money" and order[2] == 1 and order[3] == 4 and order[4] == 2)
assert(#addon.db.byCharacter.A.history == 4)
assert(queue:Discard())
Scan({ Mail("COD", { Item(100, 1, 1) }, 0, 500) })
local cod = addon.ViewModel:GetMails({ characters = { a } }, {})[1]
assert(not cod.actionable and not queue:Prepare({ [addon.ViewModel:ActionID("A", cod.key, 1)] = true }, { characters = { a } }))
assert(taken == 4)
print("PASS: real queue atomic start, money and sparse-slot multi-attachment collection, event ordering, index shifts, completion/history/API totals, COD batch exclusion")
assert(queue:Discard())
Scan({ Mail("Paused", { Item(100, 1, 1) }) })
local entry = addon.ViewModel:GetMails({ characters = { a } }, {})[1]
local single = { [addon.ViewModel:ActionID("A", entry.key, 1)] = true }
GetContainerNumFreeSlots = function() return 0, 0 end
assert(queue:Start(assert(queue:Prepare(single, { characters = { a } }))))
assert(queue.state == "paused" and not queue.pending and taken == 4)
GetContainerNumFreeSlots = function() return 10, 0 end
assert(queue:Discard())
InCombatLockdown = function() return true end
assert(queue:Start(assert(queue:Prepare(single, { characters = { a } }))))
assert(queue.state == "paused" and not queue.pending and taken == 4)
InCombatLockdown = function() return false end
assert(queue:Discard())
local collectItem = TakeInboxItem
TakeInboxItem = function() taken = taken + 1 end -- Client accepts, but no result arrives.
assert(queue:Start(assert(queue:Prepare(single, { characters = { a } }))))
assert(queue.pending and taken == 5)
queue:Install(); now = now + 13; addon.Frame.hooks.OnUpdate()
assert(queue.state == "paused" and queue.pending)
local historyCount = #addon.db.byCharacter.A.history
Fire("MAIL_CLOSED")
assert(not queue.pending and #addon.db.byCharacter.A.history == historyCount + 1)
assert(addon.db.byCharacter.A.history[historyCount + 1].state == "unverified" and taken == 5)
assert(queue:Discard())
print("PASS: early inbox update; no-space/combat guards; timeout retains unknown result; mailbox close archives uncertainty without retry")
local hundred = {}
for index = 1, 100 do hundred[index] = Mail("Mail" .. index, { Item(100, 1, 1) }) end
Scan(hundred, 101)
assert(api:GetState("A").status == "partial" and api:Query().quantity == 100)
total = 100; assert(scanner:Scan()); assert(api:GetState("A").status == "known")
now = now + 61; assert(scanner:Scan()); assert(api:Query().quantity == 100)
print("PASS: 100/101 partial lower-bound and 100/100 complete mailbox with stable-backlog cleanup")
TakeInboxItem = collectItem
Scan({ Mail("Read partial", { Item(100, 1, 1), Item(200, 2, 1) }) })
entry = addon.ViewModel:GetMails({ characters = { a } }, {})[1]
assert(addon:MarkMailOpened(entry))
single = { [addon.ViewModel:ActionID("A", entry.key, 1)] = true }
assert(queue:Start(assert(queue:Prepare(single, { characters = { a } }))))
Flush()
local remaining = addon.ViewModel:GetMails({ characters = { a } }, {})[1]
assert(queue.state == "complete" and remaining.mail.openedByUser and #remaining.mail.attachments == 1)
print("PASS: user-opened state survives a partial collection and new mail key")
