local Env=dofile('_NonRelease/OtherPluginsFix20261030/Harness.lua')
local checks=0
local function Check(v,msg) checks=checks+1; assert(v,msg) end
local function Copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=Copy(x) end;return r end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=='number' then return math.abs(a-b)<1e-7 end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end; return true
end

-- Startup checks stop before touching an existing saved table. Currency deltas
-- use the real tracker, including spending and missing-payload balance fallback.
do
    local e=Env(); local missing,ready,registrations=nil,true,0
    e.WOW_PROJECT_MISTS_CLASSIC,e.WOW_PROJECT_ID=19,19
    local record={id='A',name='A',realm='R',class='WARRIOR',level=90,domains={large={value=42}}}
    local directory={characters={byID={A=record}}}
    local c={Defaults={Copy=function(_,v) return Copy(v) end},Database={GetDB=function() return directory end},
        Capabilities={Register=function() end},CheckAPIVersion=function() return true end,
        HasCapability=function(_,name) return name~=missing end,IsInitialized=function() return ready end,
        Locale={Get=function(_,owner,key) return key end},
        AccountView={RegisterPage=function() end,GetScrollSurfaceWidth=function() end},
        Entry={RegisterBusinessEntry=function() end},LevelFilter={Validate=function() end},
        RegisterAddon=function() registrations=registrations+1; return true end}
    e.YiboCore=c; e.load('YiboCore/Data/Characters.lua'); c.Characters.GetCurrentID=function() return 'A' end
    e.load('YiboLegendary/Bootstrap.lua','YiboLegendary')
    local a=e.YiboLegendary; local initialized,builds=0,0
    a.Print=function() end; a.Catalog={GetTargets=function() return {} end}; a.Probe={Run=function() end}
    a.UI={Initialize=function() initialized=initialized+1 end,Refresh=function() end}
    a.Model={BuildSnapshot=function(_,character,store,availability,progress)
        Check(character.id=='A' and character.domains==nil,'model gets identity')
        builds=builds+1; return {targets={},progress=progress}
    end}
    e.load('YiboLegendary/Data.lua')
    local quantity=100
    e.GetCurrencyInfo=function() return 'Valor',quantity end
    e.GetQuestLogIndexByID=function(id) return id==32476 and 1 or 0 end
    e.GetQuestLogTitle=function() return 'Valor quest' end
    e.IsQuestFlaggedCompleted=function() return false end
    e.YiboLegendaryDB={sentinel='kept'}; local saved=e.YiboLegendaryDB
    missing='character-identity'; a:Initialize()
    Check(not a.initialized and Same(saved,{sentinel='kept'}) and registrations==0,'missing identity stops before database writes')
    missing=nil; ready=false; a:Initialize()
    Check(not a.initialized and Same(saved,{sentinel='kept'}),'Core not ready stops')
    ready=true; e.WOW_PROJECT_ID=18; a:Initialize()
    Check(not a.initialized and Same(saved,{sentinel='kept'}),'wrong client stops before writes')
    e.WOW_PROJECT_ID=19; a:Initialize(); a:Initialize()
    Check(a.initialized and registrations==1 and initialized==1 and a.db==saved and saved.sentinel=='kept','initialization is idempotent and retains store')
    for i=1,100 do quantity=quantity+1; a:QueueRefresh('CURRENCY_DISPLAY_UPDATE',396,quantity,1,2) end
    quantity=quantity-20; a:QueueRefresh('CURRENCY_DISPLAY_UPDATE',396,quantity,-20,2)
    quantity=quantity+3; a:QueueRefresh('CURRENCY_DISPLAY_UPDATE',396,quantity,nil,2)
    Check(e.pending()==1 and saved.byCharacter.A.valorProgress.progress==103,'every gain counted once, spending ignored, balance fallback retained')
    e.advance(0.1)
    Check(builds==2 and saved.byCharacter.A.snapshot.progress==103,'one model refresh after ordered deltas')
    Check(record.domains.large.value==42,'Core domains unchanged')
end

for _,native in ipairs({false,true}) do
    -- Compare actual old/new scheduling across earlier and later deadlines.
    local function Builds(before)
        local e=Env(before,native); local trace={}
        e.YiboBuilds={HasCompatibleCore=function() return true end,Now=function() return e.clock end}
        e.load('YiboBuilds/Snapshot.lua'); local s=e.YiboBuilds.Snapshot
        s.Capture=function(_,reason,logout,parts) trace[#trace+1]={at=e.clock,reason=reason,parts=Copy(parts)} end
        for i=1,100 do s:ScheduleEquipmentCapture() end
        if not before then Check(e.pending()==2,'one capture plus one settle timer') end
        e.advance(.01); s:ScheduleCapture('glyph-update',.1,{glyphs=true})
        e.advance(.02); s:ScheduleEquipmentCapture()
        e.advance(.08); s:ScheduleCapture('late-talents',.4,{talents=true})
        e.advance(1)
        return trace
    end
    Check(Same(Builds(true),Builds(false)),'Builds before/after capture times, reasons and merged parts match')
    local function Crafting(before)
        local e=Env(before,native);local trace={}
        e.YiboCore={}; e.YiboCrafting={initialized=true,
            Collector={Scan=function(_,reason) trace[#trace+1]={kind='collect',reason=reason,at=e.clock} end},
            RecipeStateScanner={Start=function(_,reason) trace[#trace+1]={kind='states',reason=reason,at=e.clock} end}}
        e.load('YiboCrafting/Bootstrap.lua')
        for i=1,100 do e.frame.OnEvent(nil,'SPELLS_CHANGED') end
        if not before then Check(e.pending()==1,'one pending Crafting scan') end
        e.advance(.1); e.frame.OnEvent(nil,'TRADE_SKILL_UPDATE')
        e.advance(.15); e.frame.OnEvent(nil,'NEW_RECIPE_LEARNED')
        e.advance(.4); e.frame.OnEvent(nil,'TRADE_SKILL_SHOW')
        e.advance(.5); e.frame.OnEvent(nil,'TRADE_SKILL_LIST_UPDATE')
        e.advance(1)
        return trace
    end
    Check(Same(Crafting(true),Crafting(false)),'Crafting deadlines, forced-state reasons and scans unchanged')

    local e=Env(false,native);local queries,notices=0,0
    local goal={id='G',revision=1,state='active',intent={providerID='P',scope={characterID='A'}}}
    e.YiboTaskHub={NAME='YiboTaskHub',PAGE_ID='hub',Now=e.GetServerTime,T=function(_,key) return key end,
        Goals={List=function() return {goal} end},db={goals={byID={G=goal}}},Core={Contracts={
            List=function() return {{providerID='P',registrationRef='R'}} end,
            Call=function() queries=queries+1;return {sourceEpoch='E',evaluations={}} end},
            AccountView={NotifyPageChanged=function() notices=notices+1 end}}}
    e.load('YiboTaskHub/Contracts.lua');e.load('YiboTaskHub/GoalContracts.lua')
    local c=e.YiboTaskHub.Contracts
    e.YiboTaskHub.Displays={ScheduleRefresh=function() c:GetGoalResults({{id='A'}}) end}
    c:GetGoalResults({{id='A'}})
    for i=1,50 do e.advance(i); c:Invalidate('P') end
    Check(e.pending()==1 and queries==51,'source changes reuse earliest wake')
    e.advance(60.2)
    Check(queries==51 and e.pending()==1,'early wake retains still-valid projection and schedules its real boundary')
    e.advance(110.2)
    Check(queries==52,'actual expiry re-evaluates once')
    c:ScheduleExpiry('goals',e.GetServerTime()+2)
    local was=notices; e.advance(112.4);Check(notices>was,'earlier new deadline fires')
    c:Shutdown(); was=notices; e.advance(500)
    Check(notices==was,'shutdown prevents all delayed page/HUD callbacks')
end

-- Ephemeral mount IDs are cached; ownership and faction state are read live.
do
    local e=Env(); local ns={CoreIntegration={IsCollectionStatusAvailable=function() return true end}}
    local entries,ids={[1]={spell=999,owned=false},[2]={spell=123,owned=false}},{1,2}
    local scans=0
    e.UnitFactionGroup=function() return 'Horde' end
    e.C_MountJournal={GetMountIDs=function() scans=scans+1;return ids end,
        GetMountInfoByID=function(id)
            local v=entries[id]; if not v or v.pending then return end
            return 'Mount',v.spell,nil,nil,nil,nil,nil,v.faction~=nil,v.faction,nil,v.owned
        end}
    e.load('YiboMounts/Mists/CollectionState.lua','YiboMounts',ns)
    local s=ns.CollectionState;local r={ids={mountJournalID=1}}
    Check(s:Get(r,123)==false and scans==1,'stale catalog ID resolved through real spell')
    for i=1,50 do Check(s:Get(r,123)==false,'uncollected state unchanged') end
    Check(scans==1,'repeated new tooltips reuse index')
    entries[2].owned=true;Check(s:Get(r,123)==true,'ownership change visible without caching boolean')
    entries[2].owned=false;entries[2].faction='Alliance'
    Check(s:Get(r,123)==nil,'opposing-faction absence stays unknown')
    entries[3]={spell=123,owned=true};ids[3]=3;s.frame.OnEvent(s.frame,'NEW_MOUNT_ADDED')
    Check(s:Get(r,123)==true and scans==2,'new mount event rebuilds index and finds alternate collected entry')
    entries[3]=nil;ids[3]=nil;entries[2].pending=true;s:Invalidate()
    Check(s:Get(r,123)==nil and not s.index,'partial index is not retained')
    entries[2].pending=false;entries[2].faction=nil
    Check(s:Get(r,123)==false and s.index,'pending journal retries successfully')
    local frame=s.frame;s:Initialize();Check(s.frame==frame,'event initialization idempotent')
    ids={};s:Invalidate();Check(s:Get({ids={}},456)==nil and not s.index,'empty startup journal is retried')
    ids={2};entries[2].spell=456;entries[2].owned=true
    Check(s:Get({ids={}},456)==true,'journal populated without an event recovers')
end
print('PASS: '..checks..' behavior checks; real currency deltas, startup stops, debounce equivalence, live mount state, expiry and shutdown')
