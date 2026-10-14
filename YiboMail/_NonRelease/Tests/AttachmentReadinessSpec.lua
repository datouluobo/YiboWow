-- Real scanner/store/view/grid with the native-frame harness and timed events.
dofile('YiboMail/_NonRelease/Tests/NativeInboxSpec.lua')
local A = YiboMail
local clock, timers, reads, takes = 1000, {}, 0, 0
local inbox = {
    { items = { { 72096, 20 }, { 72096, 20 }, { 72096, 20 }, { 72096, 20 }, { 72096, 20 }, { 72096, 10 } } },
    { items = {}, missingSender = true },
    { items = { { 102271, 1 }, { 102323, 1 }, { 102276, 1 } } },
    { items = {} },
}
function GetServerTime() return math.floor(clock) end
function GetTime() return clock end
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = clock + delay, callback = callback } end }
function GetInboxNumItems() return #inbox, #inbox end
function GetInboxHeaderInfo(index)
    local mail = inbox[index]
    local count = 0; for _ in pairs(mail.items) do count = count + 1 end
    local sender = not mail.missingSender and 'Sender' or nil
    return nil, nil, sender, 'Mail' .. index, 0, 0, 20, count, mail.read == true, false
end
function GetInboxItem(index, slot)
    local item = inbox[index].items[slot]
    if item then return 'Item' .. item[1], item[1], item[1], item[2] end
end
function GetInboxItemLink(index, slot)
    local item = inbox[index].items[slot]
    return item and ('|Hitem:' .. item[1] .. ':0|h[Item]|h')
end
GetItemInfo = function(id) return 'Item' .. tostring(id), nil, 4 end
HasNewMail, CheckInbox = function() return false end, function() end
YiboMailDB = nil
for _, file in ipairs({ 'Store', 'Items', 'Scanner', 'ViewModel', 'Inbox', 'Queue', 'NativeUI' }) do dofile('YiboMail/' .. file .. '.lua') end
A.FEATURES.send, A.FEATURES.account = false, false
A:InitializeDatabase()
MailFrame:Show(); InboxFrame:Show()
local N, S = A.NativeUI, A.Scanner
N:CreateInbox(); N.inbox.mode = 'items'; N.installed = true
A.Items.Events:Register(N, function() N:Refresh() end)
local function Fire(event) S:OnEvent(event); A.Queue:OnEvent(event); N:OnEvent(event) end
function GetInboxText(index)
    reads = reads + 1
    if not inbox[index].read then
        inbox[index].read = true
        C_Timer.After(0, function() Fire('MAIL_INBOX_UPDATE') end)
    end
    return ''
end
function TakeInboxItem(index, slot)
    takes = takes + 1; inbox[index].items[slot] = nil
    C_Timer.After(0, function() Fire('MAIL_SUCCESS'); Fire('MAIL_INBOX_UPDATE') end)
end
local function Advance(seconds)
    local target, steps = clock + seconds, 0
    while true do
        local selected
        for i, timer in ipairs(timers) do
            if timer.at <= target and (not selected or timer.at < timers[selected].at) then selected = i end
        end
        if not selected then clock = target; return end
        local timer = table.remove(timers, selected); clock = timer.at; timer.callback()
        steps = steps + 1; assert(steps < 1000, 'Mailbox events must settle')
    end
end
Fire('MAIL_SHOW'); Advance(1)
assert(A.Items:GetState(A.Core.Characters:GetCurrent().id).status == 'known')
assert(#N.inbox.tiles == 4)
local material
for _, tile in ipairs(N.inbox.tiles) do
    assert(tile:IsEnabled() and tile.eligibleCount > 0)
    if tile.mailGroup.item.itemID == 72096 then material = tile end
end
assert(material and material.count:GetText() == '110')
assert(reads == 2, 'Only the two displayed attachment mails are acknowledged once')
print('PASS: real four-mail/110-material/three-gear snapshot reaches an enabled attachment grid after automatic read events')

-- Updates arriving faster than the debounce delay must not prevent scanning.
local completedScans, scan = 0, A.CommitScan
function A:CommitScan(...) completedScans = completedScans + 1; return scan(self, ...) end
for i = 1, 20 do Fire('MAIL_INBOX_UPDATE'); Advance(0.1) end
assert(completedScans > 0, 'Continuous inbox updates must not starve the scheduled scan')
Advance(0.3)
for _, tile in ipairs(N.inbox.tiles) do assert(tile:IsEnabled()) end
print('PASS: continuous mailbox updates coalesce without starving scan completion or leaving attachment tiles disabled')

N:CollectItem(material.mailGroup); Advance(2)
assert(takes == 6 and A.Queue.state == 'complete' and not next(inbox[1].items))
assert(A.Items:GetState(A.Core.Characters:GetCurrent().id).status == 'known')
inbox[3].missingSender = true
Fire('MAIL_INBOX_UPDATE'); Advance(0.3)
local unknownSenderGroup
for _, tile in ipairs(N.inbox.tiles) do
    if tile:IsShown() then
        assert(tile:IsEnabled())
        unknownSenderGroup = tile.mailGroup
        assert(unknownSenderGroup.sources[1].entry.mail.sender == '')
    end
end
assert(unknownSenderGroup)
for _, language in ipairs({ 'zh', 'en' }) do
    A.Core.Locale.language = language
    assert(A.ViewModel:CounterpartLabel('', A.Core.Characters:GetCurrent()) == A:T('UI.TEXT_0399'))
end
N:CollectItem(unknownSenderGroup); Advance(0.4)
assert(takes == 7 and A.Queue.state == 'complete')
print('PASS: missing sender on an empty mail cannot block six-stack/110-item collection; attachments with an unknown sender remain identifiable and collectable')

local header = GetInboxHeaderInfo
for _, invalidField in ipairs({ 'sender', 'subject', 'days' }) do
    GetInboxHeaderInfo = function(index)
        local values = { header(index) }
        if index == 2 then
            if invalidField == 'sender' then values[3] = 42
            elseif invalidField == 'subject' then values[4] = nil
            else values[7] = nil end
        end
        return unpack(values, 1, 10)
    end
    assert(not S:Scan() and S.lastError:find('header-unavailable', 1, true))
    assert(A.Items:GetState(A.Core.Characters:GetCurrent().id).status == 'error')
    for _, tile in ipairs(N.inbox.tiles) do if tile:IsShown() then assert(not tile:IsEnabled()) end end
end
GetInboxHeaderInfo = header
assert(S:Scan())
for _, tile in ipairs(N.inbox.tiles) do if tile:IsShown() then assert(tile:IsEnabled()) end end
local unknownEntry
for _, candidate in ipairs(A.ViewModel:GetMails(N:Context(), {})) do
    if candidate.mail.inboxIndex == 3 then unknownEntry = candidate end
end
assert(unknownEntry and unknownEntry.mail.sender == '')
inbox[3].missingSender = false
assert(not S:ReadEntry(unknownEntry) and takes == 7, 'A changed sender still invalidates the old mail signature')
assert(S:Scan())
S:Schedule(); local previousRequest = S.scheduledScan
Fire('MAIL_CLOSED'); assert(not S.scheduledScan)
Fire('MAIL_SHOW'); assert(S.scheduledScan ~= previousRequest)
Advance(0.5)
assert(A.Items:GetState(A.Core.Characters:GetCurrent().id).status == 'known')
for _, tile in ipairs(N.inbox.tiles) do if tile:IsShown() then assert(tile:IsEnabled()) end end
print('PASS: malformed header fields still block collection; valid recovery and sender identity changes are checked; closing cancels the old scan and reopening restores availability')
