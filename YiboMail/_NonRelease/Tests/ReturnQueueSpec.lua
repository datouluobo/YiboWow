-- Real Mists scanner/store/queue with a chronological virtual client clock.
local clock, timers, inbox, total, shown, behaviour, calls, headers, fullReads, scans
local character = { id = "queue-test", name = "Collector", realm = "Realm" }
function CreateFrame() return { HookScript = function(self, name, fn) self[name] = fn end } end
function GetTime() return clock end
function GetServerTime() return 1000 + math.floor(clock) end
MailFrame = { IsShown = function() return shown end, HookScript = function() end }
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = clock + delay, callback = callback } end }
local function Advance(seconds)
    local untilAt, steps = clock + seconds, 0
    while true do
        local first
        for i, timer in ipairs(timers) do
            if timer.at <= untilAt and (not first or timer.at < timers[first].at) then first = i end
        end
        if not first then break end
        local timer = table.remove(timers, first)
        clock = timer.at; timer.callback(); steps = steps + 1
        assert(steps < 20000, "Timer loop must make progress")
    end
    clock = untilAt
end
local function Item(id, slot, count) return { id = id, slot = slot, count = count or 1 } end
local function Mail(subject, items, money, cod)
    return { sender = "Sender", subject = subject, items = items or {}, money = money or 0, cod = cod or 0 }
end
function GetInboxNumItems() return math.min(100, #inbox), total end
function GetInboxHeaderInfo(index)
    headers = headers + 1
    local mail = assert(inbox[index], "Reading a missing row")
    local reply = true
    if mail.unreplyable then reply = false elseif mail.replyUnknown then reply = nil end
    if mail.replyOverride ~= nil then reply = mail.replyOverride end
    return nil, nil, mail.sender, mail.subject, mail.money, mail.cod, mail.days or 20, #mail.items, false, false,
        nil, reply, mail.isGM
end
function GetInboxInvoiceInfo(index) return inbox[index].invoiceType end
function GetInboxItem(index, slot)
    for _, item in ipairs(inbox[index].items) do
        if item.slot == slot then return "Item", item.id, "icon", item.count end
    end
end
function GetInboxItemLink(index, slot)
    for _, item in ipairs(inbox[index].items) do
        if item.slot == slot then return "|Hitem:" .. item.id .. ":0|h[Item]|h" end
    end
end
function GetContainerNumFreeSlots() return 20, 0 end
function InCombatLockdown() return false end
function DeleteInboxItem() end
function InboxItemCanDelete(index) return inbox[index].returnable == false end
function ReturnInboxItem(index)
 calls[#calls + 1] = { index = index, subject = inbox[index].subject, at = clock }
 behaviour(index, "return")
end
function AutoLootMailItem() end
function TakeInboxItem(index, slot) calls[#calls + 1] = { at = clock, index = index, slot = slot, subject = inbox[index].subject }; behaviour(index, slot) end
function TakeInboxMoney(index) calls[#calls + 1] = { at = clock, index = index, slot = "money", subject = inbox[index].subject }; behaviour(index, "money") end
function hooksecurefunc(name, callback)
    local original = _G[name]
    _G[name] = function(...) local result = original(...); callback(...); return result end
end
for _, name in ipairs({ "Namespace", "Store", "Items", "Mists/Scanner", "ViewModel", "Inbox", "Mists/Queue", "Mists/Returns" }) do dofile("YiboMail/" .. name .. ".lua") end
local A, S, Q = YiboMail, YiboMail.Scanner, YiboMail.Queue
A.Core = { Characters = { GetCurrent = function() return character end, GetAllCached = function() return { character } end },
    AccountView = { GetVisibleCharacters = function() return { character } end, NotifyPageChanged = function() end } }
A.NativeUI = { Refresh = function() end, OnCollected = function() end }
A.NativeUI.inboxWidgets = { [4] = function() end }
A.NativeUI.inbox = { selection = {} }
dofile("YiboMail/Mists/ReturnUI.lua")
local readVisible, scanAsync = S.ReadVisible, S.ScanAsync
function S:ReadVisible(...) fullReads = fullReads + 1; return readVisible(self, ...) end
function S:ScanAsync(...) scans = scans + 1; return scanAsync(self, ...) end
local function Fire(event, ...) S:OnEvent(event); Q:OnEvent(event, ...) end
local function Remove(index, slot, retainEmpty)
    local mail = inbox[index]
    if slot == "money" then mail.money = 0
    else
        for i, item in ipairs(mail.items) do if item.slot == slot then table.remove(mail.items, i); break end end
    end
    if not retainEmpty and #mail.items == 0 and mail.money == 0 then table.remove(inbox, index); total = total - 1 end
end
local function Normal(index, slot)
    C_Timer.After(0.04, function() Remove(index, slot); Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE") end)
end
local function Reset(mails)
    clock, timers, inbox, total, shown, behaviour, calls, headers, fullReads, scans = 0, {}, mails, #mails, true, Normal, {}, 0, 0, 0
    Q.operation, Q.returnPlan = nil, nil
    Q.state, Q.pending, Q.actions, Q.preflight, Q.onSuccess = "idle", nil, {}, nil, nil
    Q.requestInterval, Q.notifyPending, Q.pauseCode, Q.cooldownUntil, Q.responseLatency = 0.25, nil, nil, nil, nil
    S.open, S.updated, S.lastError, S.validAt, S.scheduledScan = true, true, nil, nil, nil
    S.generation, S.publishedStatus = (S.generation or 0) + 1, {}
    YiboMailDB = nil; A:InitializeDatabase()
    assert(S:Scan()); headers, fullReads, scans = 0, 0, 0
end
local function StartCollection(select)
    local selection = {}
    for index, entry in ipairs(A.ViewModel:GetMails({ characters = { character } }, {})) do
        for _, action in ipairs(A:GetInboxActions(entry)) do
            if not select or select(index, action) then selection[action.id] = true end
        end
    end
    local actions = assert(Q:Prepare(selection, { characters = { character } }))
    assert(Q:Start(actions)); return actions
end
local function Archives(state)
    local count = 0
    for _, event in ipairs(A.db.byCharacter[character.id].history) do if event.state == (state or "returned-archived") then count = count + 1 end end
    return count
end
local function Complete(count)
    assert(Q.state == "complete" and not Q.pending and Q.completed == count and #calls == count)
    assert(Archives() == count and not S.lastError and not S.refreshPending)
end
Q:Install()

local function ReturnPlan(select)
    local selection = {}
    for _, entry in ipairs(A.ViewModel:GetMails({ characters = { character } }, { sort = "inbox" })) do
        if not select or select(entry.mail.inboxIndex, entry) then
            selection[A.Returns:MailID(entry)] = true
        end
    end
    return A.Returns:Prepare(selection, { characters = { character } }), selection
end
local function ReturnNormal(index)
    C_Timer.After(0.04, function()
        table.remove(inbox, index); total = total - 1
        Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
    end)
end
local function Start(select)
    local plan = assert(ReturnPlan(select))
    behaviour = ReturnNormal
    assert(Q:StartReturn(plan)); return plan
end
local function Returned(count)
    assert(Q.state == "complete" and not Q.pending and Q.completed == count and #calls == count)
    assert(Archives() == count)
    for _, record in ipairs(A.db.byCharacter[character.id].history) do
        assert(record.state ~= "collected-archived", "Returning must not archive looted items")
    end
end
Reset({ Mail("One", { Item(1, 1), Item(2, 4) }, 123) })
Start(); Advance(2); Returned(1)
assert(#inbox == 0)
local history = A.db.byCharacter[character.id].history
assert(history[#history].money == 123 and #history[#history].attachments == 2)
print("PASS: whole-letter single return includes all remaining attachments and gold; one return request; no loot archive")

Reset({ Mail("First", { Item(1, 1) }), Mail("Second", { Item(2, 1) }), Mail("Third", {}, 500) })
Start(); Advance(3); Returned(3)
assert(calls[1].subject == "Third" and calls[2].subject == "Second" and calls[3].subject == "First")
print("PASS: batch return runs serially in descending positions with confirmed index shifts")

Reset({ Mail("COD", { Item(3, 1) }, 0, 250), Mail("System", { Item(4, 1) }) })
inbox[2].returnable = false; assert(S:Scan())
local plan = Start(); assert(#plan.actions == 1 and plan.skipped == 1)
Advance(2); Returned(1)
assert(inbox[1].subject == "System" and not Q.returnPlan.selectedMails[2].returned)
local selectedAfter = 0; for _ in pairs(A.NativeUI.inbox.selection) do selectedAfter = selectedAfter + 1 end
assert(selectedAfter == 1, "Skipped envelope stays selected after its position shifts")
print("PASS: COD is returned without payment; unreturnable mail is skipped and retained")

Reset({ Mail("Dedup", { Item(1, 1), Item(2, 3) }, 50) })
local entries = A.ViewModel:GetMails({ characters = { character } }, {})
local selection = {}
for _, action in ipairs(A:GetInboxActions(entries[1])) do selection[action.id] = true end
plan = assert(A.Returns:Prepare(selection, { characters = { character } }))
assert(#plan.actions == 1 and plan.selected == 1)
selection = { [A.ViewModel:ActionID(character.id, entries[1].key, 1)] = true }
plan = assert(A.Returns:Prepare(selection, { characters = { character } }))
assert(#plan.actions == 1 and #plan.actions[1].original.attachments == 2)
print("PASS: attachment/gold selection deduplicates envelopes; partial attachment selection still returns the full letter")

Reset({ Mail("No return", { Item(1, 1) }) }); inbox[1].returnable = false; assert(S:Scan())
assert(not ReturnPlan() and #calls == 0)
InboxItemCanDelete = nil; assert(S:Scan()); assert(not ReturnPlan())
InboxItemCanDelete = function(index) return inbox[index].returnable == false end
print("PASS: all-ineligible and unknown native permissions issue no return request")

Reset({ Mail("Change", { Item(1, 1) }) }); plan = assert(ReturnPlan())
inbox[1].money = 1
assert(not Q:StartReturn(plan) and #calls == 0)
Reset({ Mail("Permission change", { Item(1, 1) }) }); plan = assert(ReturnPlan()); inbox[1].returnable = false
assert(not Q:StartReturn(plan) and #calls == 0)
Reset({ Mail("Stale selection", { Item(1, 1) }) }); plan, selection = ReturnPlan()
selection.bad = true; assert(not A.Returns:Matches(plan, selection))
assert(not A.Returns:Prepare(selection, { characters = { character } }))
print("PASS: confirmation rechecks the full mailbox, permission and exact selection before execution")

Reset({ Mail("Wait", { Item(1, 1) }), Mail("Unsent", { Item(2, 1) }) })
plan = assert(ReturnPlan()); behaviour = function() Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE") end
assert(Q:StartReturn(plan)); Advance(31)
assert(#calls == 1 and Q.state == "paused" and Q.pending and Q.pauseCode == "result-timeout" and Archives() == 0)
assert(not Q:Discard())
print("PASS: success/update signals with unchanged content time out, remain unverified and never resend")

Reset({ Mail("No event", { Item(1, 1) }) })
plan = assert(ReturnPlan()); behaviour = function(index) table.remove(inbox, index); total = total - 1; Fire("MAIL_INBOX_UPDATE") end
assert(Q:StartReturn(plan)); Advance(31)
assert(Q.state == "paused" and Q.completed == 0 and Archives() == 0)
print("PASS: disappearance alone without a success event never counts as returned")

local many = {}; for i = 1, 102 do many[i] = Mail("Window " .. i, { Item(1000 + i, 1) }) end
Reset(many); Start(function(index) return index == 1 or index == 100 end); Advance(3); Returned(2)
assert(#inbox == 100 and calls[1].subject == "Window 100" and calls[2].subject == "Window 1")
print("PASS: 100/102 visible-window refill exposes but never selects unseen tail mail")

Reset({ Mail("Twin", { Item(1, 1) }), Mail("Twin", { Item(1, 1) }), Mail("Keep", { Item(2, 1) }) })
Start(function(index) return index < 3 end); Advance(3); Returned(2)
assert(#inbox == 1 and inbox[1].subject == "Keep")
assert(not next(A.NativeUI.inbox.selection), "Successful duplicate envelopes clear their remapped selection")
print("PASS: duplicate signatures use verified positions and updated Store keys across the batch")

Reset({ Mail("Keep", { Item(1, 1) }), Mail("Return", { Item(2, 1) }) })
plan = assert(ReturnPlan()); behaviour = function(index)
    C_Timer.After(0.04, function()
        table.remove(inbox, index); total = total - 1
        table.insert(inbox, 1, Mail("New", { Item(3, 1) })); total = total + 1
        Fire("UPDATE_PENDING_MAIL"); Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
    end)
end
assert(Q:StartReturn(plan)); Advance(31)
assert(#calls == 1 and Q.completed == 0 and Q.state == "paused")
print("PASS: concurrent new mail or changed list stops the batch without guessing which envelope disappeared")

Reset({ Mail("A", { Item(1, 1) }), Mail("B", { Item(2, 1) }) })
Start(); Q:Pause("manual"); Advance(2)
assert(Q.state == "paused" and Q.completed == 1 and #calls == 1)
assert(Q:Discard())
Reset({ Mail("A", { Item(1, 1) }), Mail("B", { Item(2, 1) }) })
Start(); DeleteInboxItem(1); Advance(2)
assert(Q.state == "paused" and Q.completed == 0 and Q.pending.interference and #calls == 1)
print("PASS: manual pause settles only the current request; external mailbox operations isolate unknown results")

Reset({ Mail("Close", { Item(1, 1) }), Mail("Not sent", { Item(2, 1) }) })
Start()
local closedReturn = setmetatable({ Q.actions, Q.returnPlan, Q.pending }, { __mode = "v" })
shown = false; Fire("MAIL_CLOSED")
collectgarbage("collect")
assert(closedReturn[1] == nil and closedReturn[2] == nil and closedReturn[3] == nil,
    "Close releases return actions, plan and pending request before timers expire")
Advance(2)
assert(Q.state == "paused" and #calls == 1 and Archives() == 0 and Archives("unverified") == 1)
local unknown = A.db.byCharacter[character.id].history
assert(#unknown[#unknown].attachments == 1)
shown = true; Fire("MAIL_SHOW"); Advance(2)
assert(Q.state == "idle" and #calls == 1)
print("PASS: mailbox close preserves unknown return details; stale callbacks cannot continue after reopen")

Reset({ Mail("Combat", { Item(1, 1) }) }); plan = assert(ReturnPlan())
InCombatLockdown = function() return true end; assert(Q:StartReturn(plan)); assert(#calls == 0 and Q.state == "paused")
InCombatLockdown = function() return false end
Reset({ Mail("Failure", { Item(1, 1) }) }); plan = assert(ReturnPlan())
behaviour = function() Fire("MAIL_FAILED") end; assert(Q:StartReturn(plan)); Advance(2)
assert(Q.state == "paused" and Q.pending and #calls == 1 and Archives() == 0)
print("PASS: combat and explicit failure stop subsequent returns")

Reset({ Mail("Exception", { Item(1, 1) }) }); plan = assert(ReturnPlan())
behaviour = function() error("client return exception") end
assert(Q:StartReturn(plan)); Advance(2)
assert(Q.state == "paused" and Q.pending.interference and #calls == 1 and not Q:Discard())
print("PASS: an API exception retains the uncertain request and prevents accidental retry")

AUCTION_SOLD_MAIL_SUBJECT = "Auction successful: %s"
AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
AUCTION_REMOVED_MAIL_SUBJECT = "Auction cancelled: %s"
Reset({ Mail("Player mail", { Item(1, 1) }), Mail("Auction successful: Ore", {}, 500),
    Mail("Auction expired: Ore", { Item(2, 1) }), Mail("Auction cancelled: Herb", { Item(3, 1) }) })
inbox[2].invoiceType = "seller"; assert(S:Scan())
local collectSelection = {}
for _, entry in ipairs(A.ViewModel:GetMails({ characters = { character } }, {})) do
    for _, action in ipairs(A:GetInboxActions(entry)) do collectSelection[action.id] = true end
end
assert(#assert(Q:Prepare(collectSelection, { characters = { character } })) == 4,
    "Auction mail must remain selectable for both money and attachment collection")
plan = Start(); assert(#plan.actions == 1 and plan.skipped == 3)
Advance(3); Returned(1)
assert(calls[1].subject == "Player mail" and #inbox == 3)
print("PASS: sold proceeds and expired/cancelled listings are skipped by return, while their collection selections remain valid")

for _, kind in ipairs({ "buyer", "seller", "seller_temp_invoice" }) do
    Reset({ Mail("Unloaded auction subject", { Item(1, 1) }) })
    inbox[1].invoiceType = kind; assert(S:Scan()); assert(not ReturnPlan() and #calls == 0)
end
AUCTION_EXPIRED_MAIL_SUBJECT = "拍卖到期：%s"
AUCTION_REMOVED_MAIL_SUBJECT = "拍卖取消（%s）."
Reset({ Mail("拍卖到期：矿石", { Item(1, 1) }), Mail("拍卖取消（草药）.", { Item(2, 1) }) })
assert(not ReturnPlan() and #calls == 0)
print("PASS: invoice categories and native Chinese subject templates exclude all-auction selections, including punctuation")

Reset({ Mail("Permission drift", { Item(1, 1) }) }); plan = assert(ReturnPlan())
inbox[1].invoiceType = "seller"
assert(not Q:StartReturn(plan) and #calls == 0, "Acceptance rechecks auction status even when the mail signature is unchanged")
Reset({ Mail("Later target", { Item(1, 1) }), Mail("First target", { Item(2, 1) }) })
plan = assert(ReturnPlan()); behaviour = function(index)
    ReturnNormal(index); inbox[1].invoiceType = "seller"
end
assert(Q:StartReturn(plan)); Advance(3)
assert(#calls == 1 and Q.completed == 1 and Q.state == "paused")
print("PASS: confirmation and each queued request recheck auction exclusion without relying on cached selection")

-- Reproduce unavailable auction classification: no invoice and no native
-- subject globals. Positive reply permission is a separate mandatory gate.
AUCTION_SOLD_MAIL_SUBJECT, AUCTION_EXPIRED_MAIL_SUBJECT, AUCTION_REMOVED_MAIL_SUBJECT = nil, nil, nil
for _, flags in ipairs({ { unreplyable = true }, { replyUnknown = true }, { replyOverride = "1" }, { isGM = true } }) do
    local system = Mail("Sale receipt without metadata", {}, 35000)
    for key, value in pairs(flags) do system[key] = value end
    Reset({ system })
    assert(not ReturnPlan() and #calls == 0)
    local entry = A.ViewModel:GetMails({ characters = { character } }, {})[1]
    assert(not entry.mail.auctionMail, "Test must exercise the independent sender gate")
    local money = A:GetInboxActions(entry)[1]
    assert(money.actionable and #assert(Q:Prepare({ [money.id] = true }, { characters = { character } })) == 1)
end
print("PASS: absent/false/malformed reply evidence and GM mail cannot return even when auction detection fails; gold remains collectable")

local system = Mail("Sale receipt", {}, 35000); system.unreplyable = true
Reset({ Mail("Player envelope", { Item(1, 1) }), system })
plan = Start(); assert(#plan.actions == 1 and plan.skipped == 1)
Advance(3); Returned(1)
assert(#inbox == 1 and inbox[1].money == 35000 and calls[1].subject == "Player envelope")
print("PASS: mixed selection leaves unclassified system gold intact and returns only positively permitted player mail")

Reset({ Mail("Sender changed", {}, 35000) }); plan = assert(ReturnPlan())
inbox[1].unreplyable = true
assert(not Q:StartReturn(plan) and #calls == 0)
Reset({ Mail("Later sender changed", {}, 35000), Mail("First player", { Item(2, 1) }) })
plan = assert(ReturnPlan()); behaviour = function(index)
    ReturnNormal(index); inbox[1].unreplyable = true
end
assert(Q:StartReturn(plan)); Advance(3)
assert(Q.completed == 1 and #calls == 1 and Q.state == "paused" and inbox[1].money == 35000)
print("PASS: positive sender permission is re-read at acceptance and before each queued request")
