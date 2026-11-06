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



addon.FEATURES.account=false
local function Attachment(id,n) return {{itemID=id,quantity=n,itemLink='|Hitem:'..id..'|h[I]|h',variantKey='item:'..id,attachmentIndex=1}} end
local function Letter(sender,id,n,at,returned)
    return {sender=sender,subject='Evidence',attachments=Attachment(id,n),money=0,cod=0,wasReturned=returned==true,observedAt=at,signature='sig:'..id..':'..n,state='observed',inboxIndex=1}
end
for _,role in ipairs({a,b,c}) do addon.db.byCharacter[role.id]={coverage={revision=1,status='known',observedAt=1000},records={},visibleKeys={},history={}} end
local sa,sb,sc=addon.db.byCharacter.A,addon.db.byCharacter.B,addon.db.byCharacter.C
for n=1,150 do
    local items=Attachment(900+n,1)
    sa.history[#sa.history+1]={state='in-transit',recipient=b.name..'-'..b.realm,attachments=items,eventID='send'..n,observedAt=100+n}
    if n%2==0 then sb.history[#sb.history+1]={state='collected-archived',mail=Letter(a.name..'-'..a.realm,900+n,1,500+n),eventID='receive'..n,observedAt=500+n} end
end
sc.history[1]={state='in-transit',recipient=b.name..'-'..b.realm,attachments=Attachment(123456,2),observedAt=100,eventID='legacy',transferReview='legacy-unverified'}
local current=addon.Items
local function Equal(x,y)
    if type(x)~=type(y) then return false end
    if type(x)~='table' then return x==y end
    for k,v in pairs(x) do if not Equal(v,y[k]) then return false end end
    for k in pairs(y) do if x[k]==nil then return false end end
    return true
end
local cases=0
local function Compare()
    local results={}
    for _,role in ipairs(addon.Core.Characters:GetAllCached({identityOnly=true})) do results[role.id]=assert(current:GetTransfers(role.id)) end
    dofile('_NonRelease/MailPerformance20261029/TransitR5-before-Items.lua')
    local previous=addon.Items;addon.Items=current
    for id,result in pairs(results) do assert(Equal(result,assert(previous:GetTransfers(id))),'Every public result field matches frozen matcher') end
    cases=cases+1
end
Compare()
local retainedB=current.transferEvidence.byID.B
addon:AddHistory('A',{state='in-transit',recipient=b.name..'-'..b.realm,attachments=Attachment(789,2),observedAt=600})
assert(current.transferEvidence.byID.A==nil and current.transferEvidence.byID.B==retainedB,'Owner publish immediately evicts only changed evidence')
Compare();assert(current.transferEvidence.byID.B==retainedB)
local getCached=addon.Core.Characters.GetAllCached
addon.Core.Characters.GetAllCached=function(self,...) return addon.Copy(getCached(self,...)) end
addon:Publish('A',{}, {},'scan',false);Compare()
assert(current.transferEvidence.byID.B==retainedB,'Unrelated Core domain updates may replace arrays without changing mail identity values')
addon.Core.Characters.GetAllCached=getCached
addon:AddHistory('B',{state='collected-archived',mail=Letter(a.name..'-'..a.realm,789,2,700),observedAt=700})
Compare()
addon:AddHistory('A',{state='collected-archived',mail=Letter(b.name..'-'..b.realm,901,1,800,true),observedAt=800})
Compare()
sb.history[1].mail.attachments[1].quantity=999
addon:Publish('B',{}, {},'scan',false);Compare()
sb.records.live=Letter(a.name..'-'..a.realm,903,1,900);sb.visibleKeys={'live'}
addon:Publish('B',{}, {},'scan',false);Compare()
-- An unscoped/manual invalidation deliberately discards every owner's memo.
current:OnPublish(addon.db.revision+1,false);assert(current.transferEvidence==nil);Compare()
-- Core identity array changes invalidate all address-dependent evidence.
a.name='Renamed';Compare()
sc.coverage.revision=nil;current:ReleaseCaches();Compare();assert(current.transferEvidence.byID.C==nil)
local pieces=current.transferEvidence
addon.db.byCharacter.C=nil;addon:Publish('C',{}, {},'cleanup',false)
assert(not pieces.byID.C);Compare()
local out=current:GetTransfers('B');if out.records[1] then out.records[1].quantity=999999 end;Compare()
local weak=setmetatable({current.transferEvidence},{__mode='v'})
retainedB=nil;pieces=nil;current:ReleaseCaches(true)
collectgarbage('collect');collectgarbage('collect')
assert(weak[1]==nil and current.transferEvidence==nil,'Close releases owner evidence and its input graph')
print('PASS: '..cases..' exact frozen-matcher comparisons; changed-owner invalidation, untouched-owner reuse, identity changes, legacy/manual invalidation, deletion and close release')
