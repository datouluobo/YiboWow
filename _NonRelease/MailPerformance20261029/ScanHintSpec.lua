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
inbox={Mail('Hint',{Item(100,1,2),Item(200,4,3)})};total=1
scanner.open,scanner.updated=true,true
local calls={}
local getItem=GetInboxItem
local changedName,changedTexture
GetInboxItem=function(index,slot)
    calls.items=(calls.items or 0)+1
    local name,id,texture,quantity=getItem(index,slot)
    if name and slot==4 then name=changedName or name; texture=changedTexture or texture end
    return name,id,texture,quantity
end
local before=assert(scanner:ReadTarget(1)); calls.items=0
local hint=assert(scanner:ReadTarget(1,before))
assert(calls.items==16 and hint~=before and hint.attachments~=before.attachments)
assert(hint.attachments[1]==before.attachments[1] and hint.attachments[2]==before.attachments[2])
changedName='Updated name'
local changed=assert(scanner:ReadTarget(1,hint));assert(changed.attachments[2]~=hint.attachments[2] and changed.attachments[2].name==changedName)
changedName=nil;changedTexture='Updated icon'
changed=assert(scanner:ReadTarget(1,hint));assert(changed.attachments[2]~=hint.attachments[2] and changed.attachments[2].texture==changedTexture)
changedTexture=nil;inbox[1].items[2].quantity=5
changed=assert(scanner:ReadTarget(1,hint));assert(changed.signature~=hint.signature and changed.attachments[2].quantity==5)
inbox[1].items[2].quantity=3;inbox[1].items[2].variant=7
changed=assert(scanner:ReadTarget(1,hint));assert(changed.signature~=hint.signature and changed.attachments[2].variantKey~=hint.attachments[2].variantKey)
inbox[1].items[2].variant=nil;inbox[1].items[2].slot=3
changed=assert(scanner:ReadTarget(1,hint));assert(changed.attachments[2].attachmentIndex==3 and changed.attachments[2]~=hint.attachments[2])
inbox[1].items[2].slot=4
hint.attachments[2].extra={annotation=true}
changed=assert(scanner:ReadTarget(1,hint));assert(changed.attachments[2].extra==nil and changed.attachments[2]~=hint.attachments[2])
assert(scanner:ReadTarget(1,{attachments={123}}), "Malformed hints cannot reject a readable native result")
local header=GetInboxHeaderInfo
GetInboxHeaderInfo=function() return nil end
local failed,_,_,err=scanner:ReadTarget(1,hint);assert(not failed and err)
GetInboxHeaderInfo=header; scanner.open=false
failed,_,_,err=scanner:ReadTarget(1,hint);assert(not failed and err=='mailbox-unavailable')
print('PASS: scan hints reuse exact immutable items only; every slot re-read; changed name/icon/count/link/slot, unknown metadata and unreadable/closed states remain fresh')

local active=addon.Scanner
dofile('_NonRelease/MailPerformance20261029/CollectionR2-before-Scanner.lua')
local previousSignature=addon.Scanner.Signature; addon.Scanner=active
for n=1,50 do
    local mail={sender='Sender:'..n,subject='主题|:'..n,money=n*100,cod=n%2,wasReturned=n%3==0,attachments={
        {variantKey='link:item:123:你好|:'..n,quantity=n},
        {variantKey='item:9',quantity=1000000000000+n},
    }}
    assert(scanner:Signature(mail)==previousSignature(scanner,mail),'Length-prefixed signature bytes must remain unchanged')
end
print('PASS: optimized item-pair encoding matches frozen scanner signatures, including Unicode, separators and large quantities')
