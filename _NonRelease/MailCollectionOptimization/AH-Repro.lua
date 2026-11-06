if USE_OLD_AH_RULES then
    local real = dofile
    function dofile(path)
        if path == "YiboMail/Mists/Scanner.lua" then path = "_NonRelease/MailCollectionOptimization/Scanner-Before.lua" end
        if path == "YiboMail/Mists/Queue.lua" then path = "_NonRelease/MailCollectionOptimization/Queue-Before.lua" end
        return real(path)
    end
end
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
    return nil, nil, mail.sender, mail.subject, mail.money, mail.cod, 20, #mail.items, false, false
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
function TakeInboxItem(index, slot) calls[#calls + 1] = { at = clock, index = index, slot = slot }; behaviour(index, slot) end
function TakeInboxMoney(index) calls[#calls + 1] = { at = clock, index = index, slot = "money" }; behaviour(index, "money") end
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

local ah = {}
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
Start(); Advance(20); Complete(12)
assert(#inbox == 0 and fullReads == 2, "A later cleanup is recovered by one ordered rebase")
print("PASS: an AH empty row disappearing after the next action is confirmed also rebases safely")

