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
    return nil, nil, mail.sender, mail.subject, mail.money, mail.cod, mail.days or 20, #mail.items, false, false
end
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
function ReturnInboxItem() end
function AutoLootMailItem() end
function TakeInboxItem(index, slot) calls[#calls + 1] = { at = clock, index = index, slot = slot, subject = inbox[index].subject }; behaviour(index, slot) end
function TakeInboxMoney(index) calls[#calls + 1] = { at = clock, index = index, slot = "money", subject = inbox[index].subject }; behaviour(index, "money") end
function hooksecurefunc(name, callback)
    local original = _G[name]
    _G[name] = function(...) local result = original(...); callback(...); return result end
end
for _, name in ipairs({ "Namespace", "Store", "Items", "Mists/Scanner", "ViewModel", "Inbox", "Mists/Queue" }) do dofile("YiboMail/" .. name .. ".lua") end
local A, S, Q = YiboMail, YiboMail.Scanner, YiboMail.Queue
A.Core = { Characters = { GetCurrent = function() return character end, GetAllCached = function() return { character } end },
    AccountView = { GetVisibleCharacters = function() return { character } end, NotifyPageChanged = function() end } }
A.NativeUI = { Refresh = function() end, OnCollected = function() end }
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
    Q.state, Q.pending, Q.actions, Q.preflight, Q.onSuccess = "idle", nil, {}, nil, nil
    Q.requestInterval, Q.notifyPending, Q.pauseCode, Q.cooldownUntil, Q.responseLatency = 0.25, nil, nil, nil, nil
    S.open, S.updated, S.lastError, S.validAt, S.scheduledScan = true, true, nil, nil, nil
    S.generation, S.publishedStatus = (S.generation or 0) + 1, {}
    YiboMailDB = nil; A:InitializeDatabase()
    assert(S:Scan()); headers, fullReads, scans = 0, 0, 0
end
local function Start(select)
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
    for _, event in ipairs(A.db.byCharacter[character.id].history) do if event.state == (state or "collected-archived") then count = count + 1 end end
    return count
end
local function Complete(count)
    assert(Q.state == "complete" and not Q.pending and Q.completed == count and #calls == count)
    assert(Archives() == count and not S.lastError and not S.refreshPending)
end
Q:Install()

-- AH returns can expose an empty row before the client removes it. The next
-- request must rebase instead of pausing at the old selected inbox index.
local ah = {}
for i = 1, 12 do ah[i] = Mail("AH expired " .. i, { Item(2000 + i, 1) }) end
Reset(ah)
behaviour = function(index, slot)
    if #calls ~= 8 then Normal(index, slot); return end
    local target = inbox[index]
    C_Timer.After(0.04, function()
        Remove(index, slot, true); Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
        C_Timer.After(0.08, function()
            for i, row in ipairs(inbox) do
                if row == target then table.remove(inbox, i); total = total - 1; break end
            end
            Fire("MAIL_INBOX_UPDATE")
        end)
    end)
end
Start(); Advance(5); Complete(12)
assert(#inbox == 0)
assert(fullReads == 1 and scans == 1, "Routine AH empty-row cleanup needs no extra full scan")
print("PASS: AH return confirmed empty at 8/12, then removed later; remaining four selected letters finish")

ah = {}
for i = 1, 12 do ah[i] = Mail("Late AH cleanup " .. i, { Item(2500 + i, 1) }) end
Reset(ah)
behaviour = function(index, slot)
    if #calls ~= 8 then Normal(index, slot); return end
    local target = inbox[index]
    C_Timer.After(0.04, function()
        Remove(index, slot, true); Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
        C_Timer.After(0.25, function()
            for i, row in ipairs(inbox) do
                if row == target then table.remove(inbox, i); total = total - 1; break end
            end
            Fire("MAIL_INBOX_UPDATE")
        end)
    end)
end
Start(); Advance(5); Complete(12)
assert(#inbox == 0 and fullReads == 2, "A later cleanup is recovered by one ordered rebase")
print("PASS: an AH empty row disappearing after the next action is confirmed also rebases safely")

-- New unselected AH returns may arrive at the front during an in-flight loot.
ah = {}
for i = 1, 12 do ah[i] = Mail("Original " .. i, { Item(3000 + i, 1) }) end
Reset(ah)
behaviour = function(index, slot)
    C_Timer.After(0.04, function()
        Remove(index, slot)
        if #calls == 8 then
            table.insert(inbox, 1, Mail("New AH return B", { Item(9002, 1) }))
            table.insert(inbox, 1, Mail("New AH return A", { Item(9001, 1) }))
            total = total + 2; Fire("UPDATE_PENDING_MAIL")
        end
        Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
    end)
end
Start(); Advance(6); Complete(12)
assert(#inbox == 2 and inbox[1].subject == "New AH return A" and inbox[2].subject == "New AH return B")
assert(A.Items:Query().quantity == 2)
print("PASS: two new AH returns inserted during request 8/12; only the original twelve letters are collected")

ah = {}
for i = 1, 100 do ah[i] = Mail("Visible original " .. i, { Item(4000 + i, 1) }) end
ah[1].days, ah[100].days = 18, 19
Reset(ah)
Q.onSuccess = function()
    if #calls == 1 then
        table.insert(inbox, 1, Mail("AH inserted B", { Item(9102, 1) }))
        table.insert(inbox, 1, Mail("AH inserted A", { Item(9101, 1) }))
        total = total + 2; Fire("UPDATE_PENDING_MAIL"); Fire("MAIL_INBOX_UPDATE")
    end
end
Start(); Advance(25); Complete(100)
assert(#inbox == 2 and inbox[1].subject == "AH inserted A" and inbox[2].subject == "AH inserted B")
assert(calls[2].subject == "Visible original 2" and calls[3].subject == "Visible original 100")
print("PASS: front insertion pushes an original beyond the 100-mail window; it is collected only after becoming visible again")

Reset({ Mail("First", { Item(100, 1) }), Mail("Identical AH", { Item(200, 1) }) })
Q.onSuccess = function()
    if #calls == 1 then
        table.insert(inbox, 1, Mail("Identical AH", { Item(200, 1) })); total = total + 1
        Fire("UPDATE_PENDING_MAIL"); Fire("MAIL_INBOX_UPDATE")
    end
end
Start(); Advance(5)
assert(Q.state == "paused" and Q.completed == 1 and #calls == 1 and #inbox == 2)
print("PASS: an identical newly delivered AH return makes identity ambiguous; no arbitrary duplicate is collected")

-- The normal path is linear in actions, independent of inbox length. The
-- publication never claims a full fresh snapshot for a target-only read.
local bulk = {}
for i = 1, 30 do bulk[i] = Mail("Batch" .. i, { Item(100, 1), Item(200, 4, 2), Item(300, 8, 3) }) end
Reset(bulk)
local liveDuringBatch, confirmations = false, 0
A.Items.Events:Register("publication-check", function(_, payload)
    if payload.reason == "archive" then
        confirmations = confirmations + 1
        assert(Q.completed == confirmations and not Q.pending, "Publish action/history atomically")
        liveDuringBatch = liveDuringBatch or A.Items:GetState(character.id).status ~= "stale"
    end
end)
Start(); Advance(20); Complete(90)
assert(not liveDuringBatch and confirmations == 90 and A.Items:Query().quantity == 0)
assert(fullReads == 1 and scans == 1 and headers <= 240, "No per-action full inbox reads")
assert(calls[90].at - calls[1].at < 15 and calls[90].at - calls[1].at > 12, "Fast but bounded request pacing")
print(string.format("PASS: 30 mails / 90 attachments: %d header reads, %d full reads + %d final scan, %.2fs simulated requests; atomic truthful snapshots", headers, fullReads, scans, calls[90].at - calls[1].at))
A.Items.Events:Unregister("publication-check")

-- Delayed cache data must not fail after two reads or retransmit the request.
Reset({ Mail("Delayed", { Item(100, 1) }) })
behaviour = function(index, slot)
    Fire("MAIL_INBOX_UPDATE"); Fire("MAIL_SUCCESS")
    C_Timer.After(1.4, function() Remove(index, slot) end)
end
Start(); Advance(1)
assert(Q.state == "running" and Q.completed == 0 and #calls == 1 and fullReads == 1 and Q.requestInterval > 0.25)
Advance(2); Complete(1)
print("PASS: multiple stale reads wait for evidence; slow response backs off without retransmitting")

Reset({ Mail("Success without update", { Item(100, 1) }) })
behaviour = function(index, slot) C_Timer.After(0.1, function() Remove(index, slot); Fire("MAIL_SUCCESS") end) end
Start(); Advance(1); Complete(1)
Reset({ Mail("Unrelated UI error", { Item(100, 1) }) })
behaviour = function(index, slot) Fire("UI_ERROR_MESSAGE", 98765, "Unrelated error"); Normal(index, slot) end
Start(); Advance(1); Complete(1)
print("PASS: missing inbox-update event and unrelated UI errors do not stop confirmed collection")

Reset({ Mail("Selected", { Item(100, 1), Item(200, 4) }), Mail("Unselected", { Item(300, 1) }) })
behaviour = function(index, slot)
    C_Timer.After(0.04, function()
        local other = inbox[2]
        if other then other.items[1].count = other.items[1].count + 1 end
        Remove(index, slot); Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
    end)
end
Start(function(i) return i == 1 end); Advance(2); Complete(2)
assert(#inbox == 1 and inbox[1].subject == "Unselected" and A.Items:Query().quantity == 3)
print("PASS: changes to unselected contents do not reject proven selected collection; final scan reconciles them")

Reset({ Mail("Selected", { Item(100, 1), Item(200, 4) }), Mail("Existing", { Item(300, 1) }) })
Q.onSuccess = function()
    if #calls == 1 then inbox[#inbox + 1] = Mail("Arrival", { Item(400, 1) }); total = total + 1 end
end
Start(function(i) return i == 1 end); Advance(2); Complete(2)
assert(#inbox == 2 and A.Items:Query().quantity == 2)
print("PASS: new arrival between actions refreshes the layout without selecting the new letter")

-- The full 100-message window refills while selected original indexes shift.
bulk = {}
for i = 1, 102 do bulk[i] = Mail("Window" .. i, { Item(1000 + i, 1) }) end
Reset(bulk); Start(); Advance(20); Complete(100)
assert(#inbox == 2 and inbox[1].subject == "Window101" and inbox[2].subject == "Window102")
assert(A.Items:Query().quantity == 2 and fullReads == 3, "Only refill boundaries need full relocation")
print("PASS: 100/102 visible-window refill; selected original letters only; two full relocations")

bulk = { Mail("Shared", { Item(100, 1) }), Mail("Shared", {}) }
for i = 3, 101 do bulk[i] = Mail("Boundary" .. i, { Item(1000 + i, 1) }) end
Reset(bulk); Start(function(i) return i == 1 or i == 3 end); Advance(2); Complete(2)
assert(#inbox == 99 and inbox[1].subject == "Shared" and #inbox[1].items == 0 and inbox[2].subject == "Boundary4")
print("PASS: refill with an identical empty successor proves removal and preserves the next selected index")

-- Identical letters stay separate and old cached contents never count as a
-- success merely because the next letter has the same signature.
Reset({ Mail("Duplicate", { Item(100, 1) }), Mail("Duplicate", { Item(100, 1) }) })
behaviour = function(index, slot)
    Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
    C_Timer.After(0.6, function() Remove(index, slot) end)
end
Start(function(i) return i == 1 end); Advance(0.4)
assert(Q.completed == 0 and #calls == 1)
Advance(1); Complete(1); assert(#inbox == 1 and A.Items:Query().quantity == 1)
print("PASS: identical selected/unselected letters; stale duplicate prefix cannot prove removal")

-- A remaining empty letter and sparse slots/money retain exact action data.
Reset({ Mail("Sparse", { Item(100, 2), Item(200, 8) }, 123) })
behaviour = function(index, slot)
    C_Timer.After(0.04, function() Remove(index, slot, true); Fire("MAIL_INBOX_UPDATE"); Fire("MAIL_SUCCESS") end)
end
Start(); Advance(1); Complete(3)
assert(calls[1].slot == "money" and calls[2].slot == 2 and calls[3].slot == 8 and #inbox == 1)
assert(A.Items:Query().quantity == 0)
print("PASS: money, sparse attachment slots and retained empty letter")

-- A true conflict waits for reconciliation but never starts the next action.
Reset({ Mail("Changed", { Item(100, 1) }), Mail("Must not take", { Item(200, 1) }) })
behaviour = function(index) inbox[index].items[1].id = 999; Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE") end
Start(); Advance(2); assert(Q.state == "running" and Q.completed == 0 and #calls == 1)
Advance(30); assert(Q.state == "paused" and Q.pending and Q.pauseCode == "result-timeout" and Archives() == 0 and #calls == 1)
Fire("MAIL_CLOSED"); assert(not Q.pending and Archives("unverified") == 1)
Fire("MAIL_SHOW"); Advance(1); assert(Q.state == "idle" and #calls == 1)
print("PASS: content conflict retains unknown outcome through timeout/close; reopening does not retry")

Reset({ Mail("Incomplete target cache", { Item(100, 1) }), Mail("Still selected", { Item(200, 1) }) })
behaviour = function(index, slot)
    if #calls ~= 1 then Normal(index, slot); return end
    local target = inbox[index]
    target.items[1].id = 999
    table.insert(inbox, 1, Mail("Genuine new arrival", { Item(9000, 1) })); total = total + 1
    Fire("UPDATE_PENDING_MAIL"); Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
    C_Timer.After(0.8, function()
        for i, row in ipairs(inbox) do if row == target then Remove(i, slot); break end end
        Fire("MAIL_INBOX_UPDATE")
    end)
end
Start(); Advance(0.6)
assert(Q.state == "running" and Q.completed == 0 and #calls == 1, "Unexpected target contents are not classified as a new arrival")
Advance(3); Complete(2)
assert(#inbox == 1 and inbox[1].subject == "Genuine new arrival")
print("PASS: new delivery cannot disguise an unexpected nonempty target cache as a completed collection")

Reset({ Mail("Identical AH partial", { Item(100, 1), Item(200, 2) }) })
behaviour = function(index)
    inbox[index].items[1].id = 999
    table.insert(inbox, 1, Mail("Identical AH partial", { Item(200, 2) })); total = total + 1
    Fire("UPDATE_PENDING_MAIL"); Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
end
Start(); Advance(2)
assert(Q.state == "running" and Q.pending and Q.completed == 0 and #calls == 1)
Advance(30)
assert(Q.state == "paused" and Q.pending and Archives() == 0 and #calls == 1)
print("PASS: a new mail resembling a partial result cannot replace the in-flight target or supply its next attachment")

Reset({ Mail("No success event", { Item(100, 1) }), Mail("Must wait", { Item(200, 1) }) })
behaviour = function(index, slot) Remove(index, slot); Fire("MAIL_INBOX_UPDATE") end
Start(); Advance(32)
assert(Q.state == "paused" and Q.pending and Q.completed == 0 and Archives() == 0 and #calls == 1)
print("PASS: changed contents alone cannot confirm a request without success evidence")

Reset({ Mail("First", { Item(100, 1) }), Mail("Replaced", { Item(200, 1) }) })
Q.onSuccess = function() inbox[1].items[1].id = 777 end
Start(); Advance(5)
assert(Q.state == "paused" and not Q.pending and #calls == 1 and Q.completed == 1)
print("PASS: target changed between requests is never collected")

Reset({ Mail("Moved slot", { Item(100, 1), Item(200, 8) }) })
Q.onSuccess = function() inbox[1].items[1].slot = 9 end
Start(); Advance(1)
assert(Q.state == "paused" and not Q.pending and Q.completed == 1 and #calls == 1)
print("PASS: an unchanged item multiset cannot bypass the exact attachment-slot check")

Reset({ Mail("Failure", { Item(100, 1) }), Mail("Do not retry", { Item(200, 1) }) })
behaviour = function() Fire("MAIL_FAILED") end
Start(); Advance(1)
assert(Q.state == "paused" and Q.pending and Q.completed == 0 and #calls == 1 and Q.requestInterval > 0.25)
Reset({ Mail("Identity changed", { Item(100, 1) }) })
Start()
local getCurrent = A.Core.Characters.GetCurrent
A.Core.Characters.GetCurrent = function() return { id = "different-character" } end
Advance(1)
assert(Q.state == "paused" and Q.pending and Q.pending.interference and Archives() == 0 and #calls == 1)
A.Core.Characters.GetCurrent = getCurrent
print("PASS: explicit failure backs off without retry; a character change cannot archive into another mailbox")

Reset({ Mail("First", { Item(100, 1) }), Mail("Paused", { Item(200, 1) }) })
Start(); Q:Pause(); Advance(1)
assert(Q.state == "paused" and not Q.pending and Q.completed == 1 and #calls == 1)
Reset({ Mail("First", { Item(100, 1) }), Mail("External", { Item(200, 1) }) })
Start(); DeleteInboxItem(2); Advance(1)
assert(Q.state == "paused" and Q.pending and Q.pending.interference and #calls == 1 and Archives() == 0)
print("PASS: manual pause settles only the in-flight action; external mailbox operations prevent continuation")

Reset({ Mail("Pause then external", { Item(100, 1) }) })
Start(); Q:Pause(); DeleteInboxItem(1); Advance(1)
assert(Q.state == "paused" and Q.pending and Q.pending.interference and Archives() == 0 and #calls == 1)
print("PASS: paused in-flight results are isolated from subsequent external mailbox operations")

Reset({ Mail("Bag full", { Item(100, 1) }) })
GetContainerNumFreeSlots = function() return 0, 0 end
Start(); assert(Q.state == "paused" and not Q.pending and #calls == 0)
GetContainerNumFreeSlots = function() return 20, 0 end
Reset({ Mail("Combat", { Item(100, 1) }) }); InCombatLockdown = function() return true end
Start(); assert(Q.state == "paused" and #calls == 0); InCombatLockdown = function() return false end
Reset({ Mail("COD", { Item(100, 1) }, 0, 500) })
local entry = A.ViewModel:GetMails({ characters = { character } }, {})[1]
assert(not Q:Prepare({ [A.ViewModel:ActionID(character.id, entry.key, 1)] = true }, { characters = { character } }))
assert(#calls == 0)
print("PASS: full bags, combat and COD remain guarded")
