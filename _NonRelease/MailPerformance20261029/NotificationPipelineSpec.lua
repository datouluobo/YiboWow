date=os.date
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
        local name=file=='YiboMail/Mists/Scanner.lua' and 'Scanner' or file=='YiboMail/ViewModel.lua' and 'ViewModel'
        if name then return dofile('_NonRelease/MailPerformance20261029/PeakR4-before-'..name..'.lua') end
    end
    if arg[2]=='before-r3' then
        local name=file=='YiboMail/Store.lua' and 'Store' or file=='YiboMail/Items.lua' and 'Items' or file=='YiboMail/AccountPage.lua' and 'AccountPage'
        if name then return dofile('_NonRelease/MailPerformance20261029/NotificationsR3-before-'..name..'.lua') end
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


_G.YiboCore=addon.Core
local C=addon.Core
C.Capabilities={Register=function() end}
C.Database={GetDB=function() return C.testDB end}
C.testDB={characters={byID={A=a,B=b,C=c}},settings={}}
dofile('YiboCore/Util/Defaults.lua');dofile('YiboCore/Data/Characters.lua')
C.Characters.GetCurrentID=function() return 'A' end
C.UITheme={}
dofile('YiboCore/_NonRelease/Tests/LoadLocale.lua');dofile('YiboMail/Locales/zh.lua');dofile('YiboMail/Locales/en.lua')
LoadMail('YiboMail/AccountPage.lua')
function GetServerTime() return math.floor(now) end
for _,role in ipairs({b,c}) do
    local snapshot={records={},visibleKeys={},history={},coverage={revision=0,status='known',observedAt=1000}}
    for i=1,20 do
        local key='offline'..i
        snapshot.records[key]={sender='Sender',subject='Offline',money=0,cod=0,attachments={{itemID=200,quantity=1}},state='observed',expiresAtEstimate=1000+86400*20}
        snapshot.visibleKeys[i]=key
    end
    addon.db.byCharacter[role.id]=snapshot
end
local dispatchErrors={}
geterrorhandler=function() return function(e) dispatchErrors[#dispatchErrors+1]=e end end
local function ViewInvalidation()
    for pass=1,3 do for _,role in ipairs({a,b,c}) do addon.AccountPage:GetSummary(role) end end
end
if arg[2]=='before-r3' then
    api.Events:Register('account-view',ViewInvalidation)
    api.Events:Register('native-view',function() end)
    api.Events:Register('action-invalidation',function() end)
else
    api.Events:RegisterSignal('account-view',ViewInvalidation)
    api.Events:RegisterSignal('native-view',function() end)
    api.Events:RegisterSignal('action-invalidation',function() end)
end
addon.FEATURES.account = false
local normalizations,normalize=0,addon.Recipients.Normalize
function addon.Recipients:Normalize(...) normalizations=normalizations+1; return normalize(self,...) end
-- Real transfer consumer executes on each publication, as Vault does.
if arg[3]=='consumer' then
    api.Events:Register('transfer-consumer',function() for _,id in ipairs({'A','B','C'}) do assert(#api:GetTransfers(id).records==0) end end)
end
local count = tonumber(arg[1]) or 100
for i=1,count do
    local items={}; for slot=1,12 do items[slot]=Item(100+slot,slot,slot) end
    inbox[i]=Mail("Bulk"..i,items)
end
total=#inbox
scanner.open,scanner.updated=true,true
assert(scanner:Scan())
local selection={}
for _,entry in ipairs(addon.ViewModel:GetMails({characters={a}})) do
    for _,action in ipairs(addon:GetInboxActions(entry)) do selection[action.id]=true end
end
function TakeInboxItem(index,slot)
    for i,item in ipairs(inbox[index].items) do if item.slot==slot then table.remove(inbox[index].items,i); break end end
    if #inbox[index].items==0 then table.remove(inbox,index); total=#inbox end
    Fire("MAIL_SUCCESS"); Fire("MAIL_INBOX_UPDATE")
end

local reads={}
for _,name in ipairs({'GetInboxHeaderInfo','GetInboxItem','GetInboxItemLink'}) do
    local original=_G[name]
    _G[name]=function(...) reads[name]=(reads[name] or 0)+1; return original(...) end
end
local allocations={}
local function Wrap(owner,key)
    local original=owner[key]
    owner[key]=function(...)
        local before=collectgarbage('count')
        local a,b,c,d=original(...)
        allocations[key]=(allocations[key] or 0)+collectgarbage('count')-before
        return a,b,c,d
    end
end
Wrap(addon,'CommitScan'); Wrap(addon,'AppendHistory'); Wrap(scanner,'ReadTarget'); Wrap(api,'GetTransfers')
local actions=assert(queue:Prepare(selection,{characters={a}}))
collectgarbage('collect'); collectgarbage('stop')
local before,started=collectgarbage('count'),os.clock()
assert(queue:Start(actions))
if arg[2]=='fixed' then
    local pending=assert(queue.pending)
    assert(pending.expected.attachments~=pending.before.attachments and #pending.before.attachments==12)
    assert(pending.expected.attachments[1]==pending.before.attachments[2],'Predicted removal shares immutable items, never mutates the observed array')
end
Flush(30000)
local allocated=collectgarbage('count')-before
collectgarbage('restart'); collectgarbage('collect')
local retained=collectgarbage('count')-before
assert(queue.state=='complete' and queue.completed==count*12)
assert(api:Query().quantity==0)
local archives,uniqueMails,mailCount=0,{},0
for _,record in ipairs(addon.db.byCharacter.A.history) do
    if record.state=='collected-archived' then
        archives=archives+1
        assert(record.item and record.item.quantity==record.item.attachmentIndex)
        assert(#record.mail.attachments==12, 'Full original evidence retained')
        if not uniqueMails[record.mail] then uniqueMails[record.mail]=true; mailCount=mailCount+1 end
    end
end
assert(archives==count*12)
print(string.format('PASS: %d mails / %d attachments; allocated %.2f MB; retained delta %.2f MB; %.3fs; %d archive mail tables',count,archives,allocated/1024,retained/1024,os.clock()-started,mailCount))
if arg[2]=='fixed' then
    assert(mailCount==count, 'One isolated original snapshot per letter in batch history')
    assert(queue.historyCopies==nil, 'Completed batches release copy maps')
    assert(normalizations==0, 'No send evidence means no receipt address parsing')
end
print('Transfer address normalizations: '..normalizations)


for _,name in ipairs({'CommitScan','AppendHistory','ReadTarget','GetTransfers'}) do print(string.format('INCLUSIVE %s %.2f MB',name,(allocations[name] or 0)/1024)) end


assert(C.Characters._allSnapshot==nil, "No full business directory snapshot is needed")

assert(#dispatchErrors==0, table.concat(dispatchErrors,"; "))
