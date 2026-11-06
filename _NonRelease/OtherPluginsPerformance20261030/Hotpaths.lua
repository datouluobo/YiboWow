-- Read-only audit: real runtime modules with simulated native events/timers.
local function Copy(v)
    if type(v) ~= 'table' then return v end
    local r = {}; for k,x in pairs(v) do r[k] = Copy(x) end; return r
end
local function Environment()
    local e = setmetatable({}, {__index=_G}); e._G = e
    e.SlashCmdList = {}; e.queue = {}
    e.CreateFrame = function() return {RegisterEvent=function() end, SetScript=function(self,k,v) self[k]=v; e.frame=self end} end
    e.C_Timer = {After=function(delay,fn) e.queue[#e.queue+1]={delay=delay,fn=fn} end}
    function e.load(path, ... ) setfenv(assert(loadfile(path)), e)(...) end
    function e.drain() local q=e.queue; e.queue={}; for _,v in ipairs(q) do v.fn() end end
    return e
end

-- Legendary coalesces model refresh, but currency deltas read full identities first.
do
    local e=Environment()
    local record={id='Player-A',name='A',realm='R',class='HUNTER',level=90,domains={fixture={}}}
    for i=1,1500 do record.domains.fixture[i]={id=i,value='payload'} end
    local db={characters={byID={['Player-A']=record}}}
    e.YiboCore={Database={GetDB=function() return db end},Defaults={Copy=function(_,v) return Copy(v) end},Capabilities={Register=function() end}}
    e.load('YiboCore/Data/Characters.lua')
    local c=e.YiboCore.Characters; c.GetCurrentID=function() return 'Player-A' end
    e.load('YiboLegendary/Bootstrap.lua','YiboLegendary')
    local a=e.YiboLegendary; a.Core=e.YiboCore; a.db={byCharacter={},settings={phaseAvailability={}}}
    e.GetServerTime=function() return 1000 end
    local builds,deltas,full=0,0,0
    a.Data={TrackValorProgress=function() deltas=deltas+1; return {} end}
    a.Model={BuildSnapshot=function() builds=builds+1; return {targets={}} end}
    local get=c.Get; c.Get=function(self,id,options) if not (options and options.identityOnly) then full=full+1 end; return get(self,id,options) end
    collectgarbage('collect'); collectgarbage('stop'); local before=collectgarbage('count')
    for i=1,100 do a:QueueRefresh('CURRENCY_DISPLAY_UPDATE',396,i,1,1) end
    assert(#e.queue==1 and full==100 and deltas==100)
    e.drain()
    local allocated=collectgarbage('count')-before; collectgarbage('restart')
    assert(builds==1 and full==101)
    print(string.format('Legendary: 100 currency events -> %d full character copies, %d currency deltas, %d model build; %.1f KB allocated (1500 synthetic domain records, GC stopped)',full,deltas,builds,allocated))
end

do
    local e=Environment(); e.YiboBuilds={HasCompatibleCore=function() return true end}
    e.load('YiboBuilds/Snapshot.lua')
    local captures=0; local s=e.YiboBuilds.Snapshot
    s.Capture=function() captures=captures+1 end
    for i=1,100 do s:ScheduleEquipmentCapture() end
    local scheduled=#e.queue
    assert(scheduled==200); e.drain(); e.drain()
    assert(captures==2)
    print('Builds: 100 equipment requests -> '..scheduled..' initial timer callbacks + 1 settle callback; '..captures..' actual captures')
end

do
    local e=Environment(); local scans,states=0,0
    e.YiboCore={}; e.YiboCrafting={initialized=true,Collector={Scan=function() scans=scans+1 end},RecipeStateScanner={Start=function() states=states+1 end}}
    e.load('YiboCrafting/Bootstrap.lua')
    for i=1,100 do e.frame.OnEvent(nil,'SPELLS_CHANGED') end
    assert(#e.queue==100); e.drain()
    assert(scans==1 and states==1)
    print('Crafting: 100 spell events -> 100 timer callbacks, 1 collector scan, 1 recipe-state start')
end

do
    local e=Environment(); local evals,now=0,1000
    local goal={id='G',revision=1,state='active',intent={providerID='P',scope={mode='self',characterID='A'}}}
    e.YiboTaskHub={NAME='YiboTaskHub',Now=function() return now end,T=function(_,s) return s end,
        Goals={List=function() return {goal} end},db={goals={byID={G=goal}}},
        Core={Contracts={List=function() return {{providerID='P',registrationRef='R'}} end,
            Call=function() evals=evals+1; return {evaluations={},sourceEpoch='E'} end},AccountView={NotifyPageChanged=function() end}}}
    e.load('YiboTaskHub/Contracts.lua'); e.load('YiboTaskHub/GoalContracts.lua')
    local c=e.YiboTaskHub.Contracts
    for i=1,50 do now=1000+i; c:Invalidate('P'); c:GetGoalResults({{id='A'}}) end
    assert(#e.queue==50 and evals==50)
    local oldToken=c.goalTimer; c:Shutdown(); e.drain()
    assert(c.goalTimer~=oldToken)
    print('TaskHub: 50 source invalidation/query cycles at 1-second intervals -> 50 retained 60.1-second callbacks; shutdown makes callbacks inert')
end

do
    local e=Environment()
    local record={id='A',name='A',realm='R',domains={fixture={}}}
    for i=1,1500 do record.domains.fixture[i]={id=i,value='payload'} end
    local db={characters={byID={A=record}}}
    local core={Database={GetDB=function() return db end},Defaults={Copy=function(_,v) return Copy(v) end},Capabilities={Register=function() end}}
    e.YiboCore=core; e.load('YiboCore/Data/Characters.lua')
    local c=core.Characters; c.GetCurrentID=function() return 'A' end
    core.AccountView={GetVisibleCharacters=function() return {{id='A',realm='R'}} end,
        GetEffectiveCharacterSort=function() end,GetCustomCharacterOrder=function() end}
    core.CharacterSort={Sort=function(_,v) return v end}
    e.YiboVault={db={settings={}}}; e.load('YiboVault/AccountPage.lua')
    local full=0; local get=c.Get
    c.Get=function(self,id,options) if not (options and options.identityOnly) then full=full+1 end; return get(self,id,options) end
    for i=1,100 do local scope=e.YiboVault.AccountPage:GetTooltipScope(); assert(scope.characterIDs[1]=='A') end
    assert(full==100)
    print('Vault: 100 tooltip scope queries -> 100 full current-character copies before the item query cache is consulted')
end
do
    local e=Environment(); local reads,enumerations=0,0
    local ids={}; for i=1,1000 do ids[i]=i end
    e.C_MountJournal={GetMountIDs=function() enumerations=enumerations+1; return ids end,
        GetMountInfoByID=function(id) reads=reads+1; return 'Mount',id==1 and 123 or 456,nil,nil,nil,nil,nil,false,nil,nil,false end}
    local ns={CoreIntegration={IsCollectionStatusAvailable=function() return true end},
        GetSettings=function() return {collectionStatus={showCollected=true,showUncollected=true}} end,
        L=function(_,key) return key end,
        Catalog={GetBySpellID=function() return {ids={mountJournalID=1}} end},
        SourceFormatter={FormatAll=function() return {{primary='source'}} end}}
    e.load('YiboMounts/Tooltip.lua','YiboMounts',ns)
    for i=1,100 do
        local tip={AddLine=function() end,Show=function() end}
        ns.Tooltip:ApplySpellID(tip,123,'hyperlink','target')
        ns.Tooltip:ApplySpellID(tip,123,'hyperlink','target') -- same tooltip deduplicates
    end
    assert(enumerations==100 and reads==100100)
    print('Mounts: 100 new tooltips for an uncollected mount -> 100 full journal traversals, 100100 mount reads (1000-entry synthetic journal); duplicate hooks on same tooltip deduplicate')
end
print('PASS: all six hotpath characterizations reproduced; no production files changed')
