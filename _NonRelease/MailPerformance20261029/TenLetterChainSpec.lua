local nativeDofile=dofile
if arg[1]=='before' then
    dofile=function(path)
        if path=='YiboVault/MailProvider.lua' then return nativeDofile('_NonRelease/MailPerformance20261029/TenR6-before-MailProvider.lua') end
        return nativeDofile(path)
    end
end
dofile('YiboVault/_NonRelease/Tests/MailProviderSpec.lua')
dofile=nativeDofile
local M,V,C=YiboMail,YiboVault,YiboCore
local clock,timers,inbox=1000,{},{}
function GetServerTime() return math.floor(clock) end
function GetTime() return clock end
function GetContainerNumFreeSlots() return 100,0 end
C_Timer={After=function(delay,callback) timers[#timers+1]={at=clock+delay,delay=delay,callback=callback} end}
local function Flush()
    for iteration=1,1000 do
        local best
        for i,t in ipairs(timers) do if t.delay<1 and (not best or t.at<timers[best].at) then best=i end end
        if not best then return end
        local t=table.remove(timers,best);clock=math.max(clock,t.at);t.callback()
    end
    error('timer loop')
end
local roles,byID={},{}
for i=1,31 do
    local id=i==1 and 'A' or i==2 and 'B' or 'R'..i
    local role={id=id,name=id=='A' and 'Alpha' or id=='B' and 'Beta' or id,realm='Realm',class='MAGE',level=80,seenOrder=i,domains={unrelated={records={}}}}
    for n=1,1500 do role.domains.unrelated.records[n]={itemID=n,quantity=i,location='Bag'..(n%4)} end
    roles[i]=role;byID[id]=role
end
local database={characters={byID=byID},settings={}}
C.Database={GetDB=function() return database end}
dofile('YiboCore/Util/Defaults.lua');dofile('YiboCore/Data/Characters.lua')
C.Characters.GetCurrentID=function() return 'A' end
C.AccountView.GetVisibleCharacters=function() return C.Characters:GetAllCached({identityOnly=true}) end
M.db.byCharacter={};M.db.collectedMailMarkers={};M.db.mailArrivalSignals={};M.db.mailNoticeBatches={}
for i,role in ipairs(roles) do
    local snapshot={records={},visibleKeys={},history={},coverage={revision=1,status='known-empty',observedAt=1,currentCount=0,totalCount=0,unscannedCount=0}}
    M.db.byCharacter[role.id]=snapshot
    for n=1,230 do
        local items={{itemID=100+n,quantity=1,attachmentIndex=1,variantKey='item:'..(100+n)}}
        snapshot.history[#snapshot.history+1]={state='collected-archived',eventID='old'..n,observedAt=100,mail={sender='Auction House',subject='Old',attachments=items,observedAt=100}}
    end
    local recipient=roles[i%31+1]
    for n=1,22 do snapshot.history[#snapshot.history+1]={state='in-transit',eventID='send'..n,observedAt=500,recipient=recipient.name..'-Realm',attachments={{itemID=1000+n,quantity=1,attachmentIndex=1}}} end
end
for _,file in ipairs({'ViewModel','Inbox','Mists/Queue'}) do dofile('YiboMail/'..file..'.lua') end
local Q=M.Queue
local paints,progress=0,0
M.NativeUI={Refresh=function() paints=paints+1 end,OnCollected=function() end,inbox={keepTilesDuringQueue=true},RefreshInboxProgress=function() progress=progress+1 end}
M.FEATURES.account=false
for i=1,10 do inbox[i]={subject='Letter'..i,itemID=123} end
function GetInboxNumItems() return #inbox,#inbox end
function GetInboxHeaderInfo(i) return nil,nil,'Auction House',inbox[i].subject,0,0,20,1,false,false end
function GetInboxItem(i,slot) if slot==1 then return 'Item',inbox[i].itemID,'icon',1 end end
function GetInboxItemLink(i,slot) if slot==1 then return '|cff0070dd|Hitem:'..inbox[i].itemID..':0|h[Item]|h|r' end end
local reads={}
for _,name in ipairs({'GetInboxHeaderInfo','GetInboxItem','GetInboxItemLink'}) do
    local fn=_G[name];_G[name]=function(...) reads[name]=(reads[name] or 0)+1;return fn(...) end
end
M.Scanner.open,M.Scanner.updated=true,true
assert(M.Scanner:Scan())
local beforeHistory=#M.db.byCharacter.A.history
local selection={}
for _,entry in ipairs(M.ViewModel:GetMails({characters={roles[1]}})) do for _,action in ipairs(M:GetInboxActions(entry)) do selection[action.id]=true end end
local actions=assert(Q:Prepare(selection,{characters={roles[1]}}));assert(#actions==10)
local full,identity=0,0
local getAll=C.Characters.GetAll
C.Characters.GetAll=function(self,options)
    if options and options.identityOnly then identity=identity+1 else full=full+1 end
    return getAll(self,options)
end
function TakeInboxItem(index,slot)
    assert(slot==1);table.remove(inbox,index)
    C.Events:Fire('DATA_DOMAIN_UPDATED',{domainID='bags',characterID='A'})
    M.Scanner:OnEvent('MAIL_SUCCESS');Q:OnEvent('MAIL_SUCCESS')
    M.Scanner:OnEvent('MAIL_INBOX_UPDATE');Q:OnEvent('MAIL_INBOX_UPDATE')
end
local calls,allocation={},{}
local function Wrap(owner,key,label)
    local fn=owner[key]
    owner[key]=function(...)
        local before=collectgarbage('count');calls[label]=(calls[label] or 0)+1
        local a,b,c,d=fn(...);allocation[label]=(allocation[label] or 0)+collectgarbage('count')-before
        return a,b,c,d
    end
end
Wrap(M,'Publish','publish');Wrap(V.MailProvider,'Refresh','vaultRefresh');Wrap(M.Items,'GetTransfers','transitDirect');Wrap(M.NativeUI,'Refresh','nativePaint');Wrap(M,'CommitScan','commitScan')
collectgarbage('collect');collectgarbage('stop')
local before,started=collectgarbage('count'),os.clock()
assert(Q:Start(actions));Flush()
local allocated=(collectgarbage('count')-before)/1024
collectgarbage('restart');collectgarbage('collect')
assert(Q.state=='complete' and Q.completed==10 and #inbox==0,tostring(Q.state)..':'..tostring(Q.completed)..':'..tostring(Q.message))
assert(#M.db.byCharacter.A.history==beforeHistory+10,'Every original archive is preserved')
local archives=0
for _,h in ipairs(M.db.byCharacter.A.history) do if h.state=='collected-archived' and h.mail and h.mail.subject:match('^Letter') then assert(#h.mail.attachments==1 and h.item.quantity==1);archives=archives+1 end end
assert(archives==10)
print(string.format('TEN LETTERS allocated=%.3fMB fullDirectoryBuilds=%d identityBuilds=%d paints=%d progress=%d seconds=%.3f',allocated,full,identity,paints,progress,os.clock()-started))
for _,name in ipairs({'publish','vaultRefresh','nativePaint','commitScan'}) do print(string.format('INCLUSIVE %s calls=%d MB=%.3f',name,calls[name] or 0,(allocation[name] or 0)/1024)) end
for _,name in ipairs({'GetInboxHeaderInfo','GetInboxItem','GetInboxItemLink'}) do print('READS '..name..' '..(reads[name] or 0)) end
if arg[1]~='before' then assert(full==0 and C.Characters._allSnapshot==nil,'Mail publication must never materialize unrelated Core business domains');assert(allocated<35,'Ten single-item letters must not allocate a full account directory per event') end


local count=0
for _,role in ipairs(roles) do
    local snapshot=M.db.byCharacter[role.id]
    assert(#snapshot.history==252+(role.id=='A' and 20 or 0),'All preexisting history plus discovered/archived letters retained')
    local result=assert(V.Items:Query({scope={mode='characters',characterIDs={role.id}},sources={'mail'}}))
    for _,record in ipairs(result.transitRecords or {}) do count=count+record.quantity end
end
assert(count==682,'All unmatched cross-character sends remain visible after auction collection')
if arg[1]~='before' then
    local provider=V.MailProvider
    local hasCapability=C.HasCapability
    local messages,printMessage=0,V.Print
    V.Print=function() messages=messages+1 end
    local getCached=C.Characters.GetAllCached
    C.HasCapability=function(_,name,minimum) if name=='character-identity-cache' then return false end;return hasCapability(C,name,minimum) end
    C.Characters.GetAllCached=function() error('Missing identity cache cannot perform directory queries') end
    local saved=V.db.byCharacter
    provider:Install();provider:Install()
    assert(messages==1 and provider.api==nil and not provider:Connect() and V.db.byCharacter==saved,'Missing Core capability stops optional integration, prompts once and retains local archives')
    C.HasCapability=hasCapability;C.Characters.GetAllCached=getCached;V.Print=printMessage
    local register=C.Events.Register;local registrations=0
    C.Events.Register=function(self,...) registrations=registrations+1;return register(self,...) end
    provider:Install();provider:Install()
    C.Events.Register=register
    assert(provider.api and registrations==0,'Restored capability reconnects without duplicate subscriptions')
    C.Characters:InvalidateAllCache()
    C.Events:Fire('CHARACTER_UPDATED','A',C.Characters:Get('A',{identityOnly=true}))
    assert(full==0 and C.Characters._allSnapshot==nil,'Directory events and repeated installation use identity data too')
    print('PASS: missing capability stops only optional Mail integration, upgrade once, local archives preserved, reconnect/installation/directory events remain lightweight')
end
