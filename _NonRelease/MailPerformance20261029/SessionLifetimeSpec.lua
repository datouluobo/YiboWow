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


addon.FEATURES.account=false
local baseline=arg[1]=='baseline'
if baseline then
    local onEvent=queue.OnEvent
    function queue:OnEvent(event,...)
        if event=='MAIL_CLOSED' and not self.pending then
            self.verifiedMails,self.nextScheduled,self.historyCopies=nil,nil,nil
            return
        end
        return onEvent(self,event,...)
    end
    api.ReleaseCaches=function() end
end
api.Events:Register('consumer',function() api:GetTransfers('A') end)
local taken=0
function TakeInboxItem(index,slot)
    taken=taken+1
    for i,item in ipairs(inbox[index].items) do if item.slot==slot then table.remove(inbox[index].items,i); break end end
    if #inbox[index].items==0 then table.remove(inbox,index); total=#inbox end
    Fire('MAIL_SUCCESS'); Fire('MAIL_INBOX_UPDATE')
end
local watches=setmetatable({},{__mode='k'})
local function Watch(value) if type(value)=='table' then watches[value]=true end end
local function Count() local n=0; for _ in pairs(watches) do n=n+1 end; return n end
local function Batch(number,close)
    inbox={}
    for i=1,30 do
        local items={}; for slot=1,12 do items[slot]=Item(100+slot,slot,slot) end
        inbox[i]=Mail('Batch'..number..'-'..i,items)
    end
    Scan(inbox)
    local selection={}
    for _,entry in ipairs(addon.ViewModel:GetMails({characters={a}})) do
        for _,action in ipairs(addon:GetInboxActions(entry)) do selection[action.id]=true end
    end
    local actions=assert(queue:Prepare(selection,{characters={a}}))
    assert(queue:Start(actions)); Flush(30000)
    assert(queue.state=='complete' and queue.completed==360)
    Watch(queue.actions); Watch(queue.expectedMails); Watch(queue.positions); Watch(queue.mailOrder); Watch(queue.removedIndexes)
    local history=#addon.db.byCharacter.A.history
    if close then shown=false; scanner:Close() end
    assert(#addon.db.byCharacter.A.history==history,'Closing never prunes history')
end
local function VerifyHistory(batches)
    local discoveries,archives=0,0
    for _,event in ipairs(addon.db.byCharacter.A.history) do
        if event.state=='discovered' then discoveries=discoveries+1 end
        if event.state=='collected-archived' then
            archives=archives+1
            assert(event.eventID and event.sourceMailKey and #event.mail.attachments==12)
            assert(event.item.quantity==event.item.attachmentIndex)
        end
    end
    assert(discoveries==batches*30 and archives==batches*360)
end
for n=1,10 do
    shown=true; Batch(n,true); collectgarbage('collect')
    local retained=Count()
    print(string.format('Batch %02d: retired queue containers=%d, total Lua=%.2f MB, history=%d',n,retained,collectgarbage('count')/1024,#addon.db.byCharacter.A.history))
    if not baseline then
        assert(retained==0,'Closed batches must not remain reachable through queue/timers')
        assert(queue.pending==nil and #queue.actions==0 and queue.expectedMails==nil and queue.returnPlan==nil)
        assert(api.transferIndex==nil and next(api.transfersCache)==nil,'Close drops derived caches even when consumers queried the stale notification')
    end
    VerifyHistory(n)
end
assert(taken==3600)
if baseline then print('BASELINE: old close policy retains the most recent batch; history preserved'); return end
-- Same open session: prior batches must become unreachable when replaced.
for n=11,14 do
    shown=true; Batch(n,false); collectgarbage('collect')
    assert(Count()==5,'Only the current completed batch may remain while its summary is visible')
    VerifyHistory(n)
end
scanner:Close(); collectgarbage('collect'); assert(Count()==0)
print('PASS: 14 batches / 5040 attachments; all discovery and operation history preserved; retired queue graphs released')
-- Close with an uncertain request and an outstanding check callback.
inbox={Mail('Unknown',{Item(777,1,1)})}; Scan(inbox); shown=true
local beforeTaken=taken
TakeInboxItem=function() taken=taken+1 end
local function BeginUnknown()
    local entry=addon.ViewModel:GetMails({characters={a}})[1]
    assert(queue:Start(assert(queue:Prepare({[addon.ViewModel:ActionID('A',entry.key,1)]=true},{characters={a}}))))
    Watch(queue.pending); Watch(queue.pending.beforeMails); Watch(queue.actions)
end
BeginUnknown()
shown=false; local history=#addon.db.byCharacter.A.history; scanner:Close(); scanner:Close()
assert(#addon.db.byCharacter.A.history==history+1,'Uncertain operation archives exactly once')
assert(addon.db.byCharacter.A.history[history+1].state=='unverified')
collectgarbage('collect'); assert(Count()==0,'Pending check timers cannot retain the unknown request graph')
shown=true; Fire('MAIL_SHOW'); Flush(30000)
assert(taken==beforeTaken+1 and queue.state=='idle','Stale callbacks cannot retransmit after reopen')
-- Cancel an async scanner while a five-letter chunk is queued.
assert(queue:Discard()); inbox={}
for i=1,20 do inbox[i]=Mail('Async'..i,{Item(100,1,1)}) end
total=#inbox; scanner.open,scanner.updated=true,true; scanner.generation=(scanner.generation or 0)+1
assert(scanner:ScanAsync(scanner.generation)); assert(scanner.scanJob and #scanner.scanJob.mails==5)
Watch(scanner.scanJob.mails)
shown=false; scanner:Close(); collectgarbage('collect'); assert(Count()==0,'Cancelled read chunks release their partially built array immediately')
local before=#addon.db.byCharacter.A.history
Flush(30000); assert(#addon.db.byCharacter.A.history==before,'Cancelled async reads cannot commit')
print('PASS: close during pending request/async scan, duplicate close, immediate graph release and stale callback isolation')
-- Invalidated indexes release references before the next query, not only when rebuilt.
api.transferIndex={retired=true}; api.transferIndexKey='old'; api.transfersCache={A={result={}}}
local retired=setmetatable({api.transferIndex,api.transfersCache},{__mode='v'})
addon:Publish('A',{}, {},'archive')
collectgarbage('collect'); assert(retired[1]==nil and retired[2]==nil)
assert(api:GetTransfers('A').records)
print('PASS: content invalidation releases old indexes; public queries rebuild safely')
