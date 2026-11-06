-- Run from workspace root. Optional: count, fixed|baseline, consumer|none.
arg[2]=arg[2] or 'fixed'; arg[3]=arg[3] or 'consumer'
-- Real scanner, store, query API and queue; simulated client data and events.
function CreateFrame() return { hooks = {}, HookScript = function(self, event, callback) self.hooks[event] = callback end } end
local now, shown, inbox, total, timers = 1000, true, {}, 0, {}
local a = { id = "A", name = "Alpha", realm = "Realm" }
local b = { id = "B", name = "Beta", realm = "Other" }
local c = { id = "C", name = "Hidden", realm = "Realm" }
function GetServerTime() return now end
function GetTime() return now end
MailFrame = { IsShown = function() return shown end, HookScript = function() end }
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback, at = now + delay } end }
local function Flush(limit)
    for iteration = 1, limit or 80 do
        local found
        for index, timer in ipairs(timers) do
            if timer[1] < 1 and (not found or timer.at < timers[found].at) then found = index end
        end
        if not found then return end
        local timer = table.remove(timers, found); now = math.max(now, timer.at); timer[2]()
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
local function LoadMail(file)
    if arg[2]=='before-r4' then
        local name=file=='YiboMail/Mists/Scanner.lua' and 'Scanner' or file=='YiboMail/ViewModel.lua' and 'ViewModel' or file=='YiboMail/NativeUI.lua' and 'NativeUI'
        if name then return dofile('_NonRelease/MailPerformance20261029/PeakR4-before-'..name..'.lua') end
    end
    if arg[2]=='before-r2' then
        local name=file=='YiboMail/Store.lua' and 'Store' or file=='YiboMail/Mists/Queue.lua' and 'Queue' or file=='YiboMail/Mists/Scanner.lua' and 'Scanner'
        if name then return dofile('_NonRelease/MailPerformance20261029/CollectionR2-before-'..name..'.lua') end
    end
    if arg[2]=='transient-baseline' then
        if file=='YiboMail/Store.lua' then return dofile('_NonRelease/MailPerformance20261029/Transient-before-Store.lua') end
        if file=='YiboMail/Mists/Queue.lua' then return dofile('_NonRelease/MailPerformance20261029/Transient-before-Queue.lua') end
    end
    if arg[2]~='baseline' then return dofile(file) end
    local handle=assert(io.open(file,'r')); local source=handle:read('*a'); handle:close()
    local function Replace(old,new)
        local first,last=source:find(old,1,true); assert(first, 'Missing comparison block: '..file)
        source=source:sub(1,first-1)..new..source:sub(last+1)
    end
    if file=='YiboMail/Mists/Queue.lua' then
        Replace('local shifted = {}; for key, value in pairs(mail) do shifted[key] = value end', 'local shifted = Addon.Copy(mail)')
    elseif file=='YiboMail/Store.lua' then
        Replace('local stored = self.Copy(record, copies)', 'local stored = self.Copy(record)')
    elseif file=='YiboMail/Items.lua' then
        Replace('if not hasSends then return index end', '-- Comparison: build receipt evidence even without sends')
    end
    return assert(loadstring(source,'@'..file))()
end
for _, file in ipairs({ "Namespace", "Store", "Items", "Mists/Scanner", "ViewModel", "Inbox", "Mists/Queue", "Recipients" }) do LoadMail("YiboMail/" .. file .. ".lua") end
local addon, scanner, api, queue = YiboMail, YiboMail.Scanner, YiboMail.Items, YiboMail.Queue
addon.Core = { Characters = { GetCurrent = function() return a end, GetAllCached = function() return { a, b, c } end },
    AccountView = { GetVisibleCharacters = function() return { a, b } end, NotifyPageChanged = function() end } }
dofile('_NonRelease/MailPerformance20261029/IdentityMock.lua')(addon.Core.Characters)
addon:InitializeDatabase()
local refreshes = 0
addon.NativeUI = { Refresh = function() refreshes = refreshes + 1 end, OnCollected = function() end }
local function Fire(event) scanner:OnEvent(event); queue:OnEvent(event) end
local function Scan(mails, count)
    inbox, total = mails, count or #mails
    scanner.open, scanner.updated = true, true
    assert(scanner:Scan())
end



addon.FEATURES.account=false;addon.FEATURES.send=false
LoadMail('YiboMail/NativeUI.lua')
local native=addon.NativeUI
native.CreateInbox=function() end;native.InstallMailboxTabs=function() end;native.RestoreBrowsePageWhenShown=function() end
InboxFrame=MailFrame
native:Install()
local renders=0
native.Refresh=function()
    if renders>0 and scanner.refreshPending and not scanner.lastError then return end
    renders=renders+1
    local entries=addon.ViewModel:GetMails({characters={a}})
    local groups=addon.ViewModel:GetGroupsFromEntries(entries)
    assert(#entries==100 and #groups==12)
end
local reads={}
for _,name in ipairs({'GetInboxHeaderInfo','GetInboxItem','GetInboxItemLink'}) do
    local original=_G[name]
    _G[name]=function(...) reads[name]=(reads[name] or 0)+1;return original(...) end
end
for i=1,100 do
    local items={};for slot=1,12 do items[slot]=Item(100+slot,slot,slot) end
    inbox[i]=Mail('Open'..i,items)
end
total=#inbox;scanner.open,scanner.updated=true,true
local function Measure(label,fn)
    collectgarbage('collect');collectgarbage('stop')
    local memory,started=collectgarbage('count'),os.clock()
    local n=renders
    fn()
    local allocation=collectgarbage('count')-memory
    collectgarbage('restart');collectgarbage('collect')
    print(string.format('%s allocated=%.3fMB renders=%d seconds=%.4f',label,allocation/1024,renders-n,os.clock()-started))
    return allocation
end
Measure('COLD',function() assert(scanner:Scan()) end)
local snapshot=addon.db.byCharacter.A
local original=snapshot.records[snapshot.visibleKeys[1]]
local item=original.attachments[1]
local found=assert(scanner:ReadVisible())
if arg[2]~='before-r4' then assert(found[1].attachments[1]==item,'Full native reread reuses only identical immutable observations') end
assert(reads.GetInboxHeaderInfo==200 and reads.GetInboxItem==3200 and reads.GetInboxItemLink==2400)
local repeated=Measure('REPEAT10',function()
    for i=1,10 do
        scanner:Schedule(true)
        timers={};assert(scanner:Scan())
    end
end)
if arg[2]~='before-r4' then
    assert(repeated<6*1024,'Repeated scans and projections must not rebuild identical attachments or duplicate native renders')
    assert(renders==11,'One native render for each committed scan, including unchanged observations')
    local before=addon.db.byCharacter.A.history;local n=#before
    inbox[1].items[1].quantity=99
    assert(scanner:Scan())
    local fresh=addon.db.byCharacter.A.records
    local updated
    for _,mail in pairs(fresh) do if mail.inboxIndex==1 and mail.state=='observed' then updated=mail end end
    assert(updated.attachments[1]~=item and updated.attachments[1].quantity==99 and item.quantity==1)
    assert(#addon.db.byCharacter.A.history>=n,'Existing history retained')
    scanner.generation=100;assert(scanner:ScanAsync(100))
    local job=assert(scanner.scanJob);scanner:CancelRead()
    assert(job.hints==nil and job.mails==nil,'Cancelled async job releases hint map and partial observations')
    local commit=addon.CommitScan
    addon.CommitScan=function() error('injected-commit-error') end
    local ok,err=pcall(scanner.Scan,scanner)
    assert(not ok and tostring(err):find('injected-commit-error',1,true) and scanner.committingObservation==nil)
    addon.CommitScan=commit
    assert(scanner:Scan())
    local header=GetInboxHeaderInfo
    GetInboxHeaderInfo=function() return nil end
    local count=renders
    assert(not scanner:Scan() and scanner.lastError and scanner.committingObservation==nil)
    assert(renders==count+1,'Error status has one authoritative native render')
    GetInboxHeaderInfo=header;assert(scanner:Scan())
    local storedCoverage=addon.db.byCharacter.A.coverage
    local getItem=GetInboxItem;local interrupted=false
    GetInboxItem=function(...)
        if not interrupted then interrupted=true;scanner:Close() end
        return getItem(...)
    end
    scanner.generation=200;scanner:ScanAsync(200)
    GetInboxItem=getItem
    assert(interrupted and scanner.scanJob==nil and addon.db.byCharacter.A.coverage==storedCoverage,'A close during a native chunk never commits cancelled observations')
    scanner.open,scanner.updated=true,true;assert(scanner:Scan())
    print('PASS: live reads and changed quantities preserved; cancelled jobs and failed commits release suppression state')
end
