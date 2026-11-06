-- Real runtimes: preserve public copy isolation while skipping unused payloads.
GetServerTime = function() return 1000 end
CreateFrame = function() return { RegisterEvent=function() end, SetScript=function() end } end
dofile('YiboCore/Bootstrap.lua')
dofile('YiboCore/Util/Defaults.lua')
dofile('YiboCore/Runtime/Capabilities.lua')
dofile('YiboCore/_NonRelease/Tests/LoadLocale.lua')
dofile('YiboCore/Runtime/Events.lua')
dofile('YiboCore/Runtime/Registry.lua')
local core=YiboCore
core.IsInitialized=function() return true end
core.Registry:Register(core.NAME,{requiredAPI=13})
core.Registry:Register('Consumer',{requiredAPI=13})
local record={id='C',name='Name',realm='Realm',level=90,domains={large={data={}}}}
for i=1,10000 do record.domains.large.data[i]={id=i,quantity=1} end
local db={characters={byID={C=record},aliases={},seenOrder={}}}
core.Database={GetDB=function() return db end}
core.Client={ReadGUID=function() return 'C' end}
dofile('YiboCore/Data/Characters.lua')
dofile('YiboCore/Runtime/DataDomains.lua')
dofile('YiboCore/Data/DomainStore.lua')
local copy, fullCopies=core.Defaults.Copy,0
core.Defaults.Copy=function(self,value)
    if value==record then fullCopies=fullCopies+1 end
    return copy(self,value)
end
assert(core.DataDomains:Register(core.NAME,{id='perf',version=1,events={PULSE=true},Collect=function(ctx)
    assert(ctx.character.id=='C' and not ctx.character.domains)
    return {v=1},'known'
end}))
for i=1,1000 do assert(core.DataDomains:Dispatch('PULSE')==1) end
assert(fullCopies==0,'Core-owned native collectors must not copy legacy inventories')
assert(core.DataDomains:Register('Consumer',{id='legacy-perf',version=1,events={LEGACY=true},Collect=function(ctx)
    assert(ctx.character.domains.large.data[10000].id==10000)
    ctx.character.domains.large.data[10000].id=-1
    return {},'known'
end}))
assert(core.DataDomains:Dispatch('LEGACY')==1 and fullCopies==1)
assert(record.domains.large.data[10000].id==10000,'external collector context remains isolated')
local input={v=2}
local first,changed=core.DomainStore:Commit('C','perf',input,'known')
assert(changed); input.v=3; first.data.v=4
local second,unchanged=core.DomainStore:Commit('C','perf',{v=2},'known')
assert(not unchanged and second.data.v==2)
second.data.v=5; assert(core.DomainStore:Get('C','perf').data.v==2)

dofile('YiboMail/Namespace.lua')
dofile('YiboMail/Store.lua')
local mail=YiboMail
local attachments={{itemID=1,quantity=3}}
local source={mail={attachments=attachments},attachments=attachments}
local a,b=mail.Copy(source),mail.Copy(source)
assert(a.attachments==a.mail.attachments and a.attachments~=attachments)
a.attachments[1].quantity=99
assert(attachments[1].quantity==3 and b.attachments[1].quantity==3)
YiboMailDB={byCharacter={C={records={},visibleKeys={},coverage={},history={
    {mail={attachments={{itemID=1,quantity=3}}},attachments={{itemID=1,quantity=3}}},
    {mail={attachments={{itemID=1,quantity=3}}},attachments={{itemID=1,quantity=2}}},
}}}}
assert(mail:InitializeDatabase())
local history=mail.db.byCharacter.C.history
assert(#history==2 and history[1].attachments==history[1].mail.attachments)
assert(history[2].attachments[1].quantity==2 and history[2].mail.attachments[1].quantity==3)
mail:AppendHistory(mail.db.byCharacter.C,source)
assert(history[3].attachments==history[3].mail.attachments)
assert(history[3].attachments[1].quantity==3)
print('PASS: 1000 native dispatches, zero full character copies; legacy collector and domain isolation; history attachment reuse without data loss')
