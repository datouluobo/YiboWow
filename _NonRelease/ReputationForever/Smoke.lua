local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value,label) checks=checks+1; assert(value,label) end
local function Faction(id,value,account)
    return {factionID=id,name="Faction"..id,reaction=5,currentReactionThreshold=3000,nextReactionThreshold=9000,
        currentStanding=value or 4500,isHeader=false,isHeaderWithRep=false,isAccountWide=account}
end
local function Boot(saved,configure,defaultManifest,localeCase)
    local e,c,fire,_,load=BootCore(true,localeCase and localeCase.savedCore)
    if localeCase then e.GetLocale=function() return localeCase.client end end
    e.TEST_GUID="Player-Test-1"; e.GetServerTime=function() return 200000 end; e.IsLoggedIn=function() return true end
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN")
    e.YiboReputationDB={sentinel="mists"}; e.YiboReputationForeverDB=saved
    local data={rows={{isHeader=true,isHeaderWithRep=false,name="Group"},Faction(72,4500,false),Faction(9999,-100,true)},reads=0}
    data.byID={[72]=data.rows[2],[9999]=data.rows[3]}
    e.C_Reputation={GetNumFactions=function()
        data.reads=data.reads+1; if data.failCount then error("not ready") end
        return data.badCount or (data.changingCount and #data.rows+data.reads%2 or #data.rows)
    end,
    GetFactionDataByIndex=function(index)
        if data.failRow then error("unavailable") end
        if data.nilRow then return nil end
        local row=data.rows[index]
        if data.changing and row and row.factionID then row=c.Defaults:Copy(row); row.currentStanding=data.reads end
        return row
    end,
    GetFactionDataByID=function(id) if data.failByID then error("unavailable") end; return data.byID[id] end}
    for _,name in ipairs({"ExpandAllFactionHeaders","ExpandFactionHeader","CollapseFactionHeader","SetWatchedFactionByID","SetLegacyReputationsShown","SetReputationSortType","ToggleFactionAtWar"}) do
        e.C_Reputation[name]=function() error("unexpected native mutation: "..name) end
    end
    e.issecretvalue=function(value) return data.secret and value==4500 end
    if configure then configure(e,c,data) end
    for line in io.lines("YiboReputation/"..(defaultManifest and "YiboReputation.toc" or "YiboReputation_Forever.toc")) do
        line=line:gsub("\r",""); if line:match("%.lua$") then load("YiboReputation/"..line:gsub("\\","/"),"YiboReputation") end
    end
    fire("ADDON_LOADED","YiboReputation")
    local function Flush()
        for i=1,15 do
            if #e.TEST_TIMERS==0 then return end
            local pending=e.TEST_TIMERS; e.TEST_TIMERS={}; for _,timer in ipairs(pending) do timer[2]() end
        end
        error("timer loop")
    end
    return e,c,e.YiboReputation,fire,Flush,data
end
local e,c,a,fire,flush,d=Boot()
Check(a.initialized and a.VERSION=="0.1.1","Forever manifest starts")
Check(not e.YiboReputationDB.settings and e.YiboReputationDB.sentinel=="mists","Mists save untouched")
Check(not a.Migration and not a.FactionRegistry and not a.GoalTargets and not a.Nomi,"MoP catalogs and operations excluded")
Check(not a.Scanner:Scan() and d.reads==0,"no native reads before world entry")
e.SlashCmdList.YIBOREPUTATION(""); flush()
local panel=c.AccountView.frame.instances.reputation
Check(#panel.renderedFactions==0,"unknown has no invented rows")
fire("PLAYER_ENTERING_WORLD"); flush()
local snapshot,state=a.Store:Get(e.TEST_GUID)
Check(state=="partial" and snapshot.factions[72].value==4500 and snapshot.factions[9999].value==-100,"raw numeric observations including negative standings")
Check(#panel.renderedFactions==2 and panel.rows[1].labels.faction:GetText()=="Faction72","current factions displayed")
Check(panel.rows[2].labels.scope:GetText()==a:T("FOREVER.SCOPE_ACCOUNT_FLAG"),"native account flag separately labeled")
Check(panel.rows[1].labels.reaction:GetText()==a:T("STANDING.5") and panel.rows[1].labels.value:GetText()=="1500 / 6000","standing and current-rank progress displayed")
Check(panel.rows[1].progress:IsShown() and panel.rows[1].progress.fill:IsShown() and panel.rows[1].display.fraction==0.25,"colored current-rank progress bar")
snapshot.factions[72].value=999
Check(a.Store:Get(e.TEST_GUID).factions[72].value==4500,"snapshots are detached")
Check(not a.Store:Get("Other"),"other GUID rejected")
local before=d.reads
for i=1,20 do fire("UPDATE_FACTION") end; flush()
Check(d.reads-before==2,"native reputation burst coalesced into two-pass scan")
d.rows={d.rows[1],d.rows[2]}; fire("UPDATE_FACTION"); flush()
Check(a.Store:RowState(e.TEST_GUID,9999)=="observed","collapsed known faction refreshed by stable ID")
d.byID[9999]=nil; fire("UPDATE_FACTION"); flush()
Check(a.Store:Get(e.TEST_GUID).factions[9999] and a.Store:RowState(e.TEST_GUID,9999)=="stale","hidden unavailable faction retains stale data")
d.rows[2].currentStanding=5000; fire("FACTION_STANDING_CHANGED",72,5000); flush()
Check(a.Store:Get(e.TEST_GUID).factions[72].value==5000,"native standing changes saved")
for _,flag in ipairs({"failCount","failRow","nilRow","changing","changingCount"}) do
    d[flag]=true; a.Scanner:Scan(); snapshot,state=a.Store:Get(e.TEST_GUID)
    Check(state=="error" and snapshot.factions[72].value==5000,"incomplete or changing result preserves previous batch: "..flag)
    d[flag]=nil
end
d.rows[2].currentStanding=4500; d.secret=true; a.Scanner:Scan()
Check(a.Store:Get(e.TEST_GUID).factions[72].value==5000,"secret field rejected before comparison")
d.secret=nil; d.rows[2].currentStanding=0/0; a.Scanner:Scan()
Check(a.Store:Get(e.TEST_GUID).factions[72].value==5000,"NaN is not stored")
d.rows[2].currentStanding=5000
for _,value in ipairs({-1,1.5,math.huge,2001}) do
    d.badCount=value; a.Scanner:Scan(); Check(a.Store:Get(e.TEST_GUID).factions[72].value==5000,"invalid enumeration count rejected")
end; d.badCount=nil
d.rows={}; d.byID={}; a.Scanner:Scan(); snapshot,state=a.Store:Get(e.TEST_GUID)
Check(state=="pending" and snapshot.factions[72].value==5000,"empty visible list is not confirmed absence")
d.rows={Faction(72,0,false)}; d.byID={}; a.Scanner:Scan()
Check(a.Store:Get(e.TEST_GUID).factions[72].value==0,"zero standing is a real observed value")
d.rows={Faction(72,0,false),Faction(72,2,false)}; a.Scanner:Scan()
Check(select(2,a.Store:Get(e.TEST_GUID))=="error","duplicate IDs reject atomic batch")
d.rows={Faction(72,0,false)}; a.Scanner:Scan()
a.AccountPage:Refresh(panel,{characters={},fields=a.AccountPage:Fields()})
Check(#panel.renderedFactions==0,"Core character exclusions respected")
c.AccountView:NotifyPageChanged("reputation"); flush(); c.AccountView.frame:Hide()
Check(c.AccountView:ShowPreview("reputation",e.Minimap),"Core owns preview")
Check(#panel.renderedFactions==2 and not panel.refresh:IsShown(),"preview uses same observed plus stale snapshot")
c.AccountView:HidePreview(); c.AccountView:Toggle("reputation")
fire("PLAYER_LEAVING_WORLD"); flush(); before=d.reads; fire("UPDATE_FACTION"); flush()
Check(d.reads==before and select(2,a.Store:Get(e.TEST_GUID))=="stale","outside world no reads and historical state stale")
local saved=c.Defaults:Copy(e.YiboReputationForeverDB)
local e2,c2,a2,f2,fl2,d2=Boot(saved)
Check(select(2,a2.Store:Get(e2.TEST_GUID))=="stale" and a2.Store:Get(e2.TEST_GUID).factions[72].value==0,"saved data restored stale")
e2.TEST_GUID=nil; f2("PLAYER_ENTERING_WORLD"); fl2(); Check(d2.reads==0,"missing identity blocks native scan")
e2.TEST_GUID="Player-Test-1"; f2("BAG_UPDATE_DELAYED"); fl2()
Check(a2.Store:Get(e2.TEST_GUID).factions[72].value==4500,"late GUID recovers from native event")
f2("UPDATE_FACTION"); a2.Store:Delete({id=e2.TEST_GUID}); fl2()
Check(not a2.Store:Get(e2.TEST_GUID),"cache deletion cancels queued scan")
f2("UPDATE_FACTION"); fl2(); a2.Store:Delete({id=e2.TEST_GUID},{replay=true,deletedAt=199999})
Check(a2.Store:Get(e2.TEST_GUID).factions[72].value==4500,"cleanup replay preserves newer observations")
for _,mutate in ipairs({function(db) db.schema=2 end,function(db) db.clientScope.projectID=19 end,
    function(db) db.clientScope.scope="account" end,function(db) db.characters["Other"]={observedAt=1,factions={[72]={}}} end,
    function(db) db.settings.previewColumns=false end}) do
    local bad=c.Defaults:Copy(saved); mutate(bad); local _,_,addon=Boot(bad)
    Check(not addon.initialized and not addon.Store.db,"incompatible stored structure rejected before mutation")
end
for _,cap in ipairs({"localization","character-name-format","character-identity","character-cleanup","account-surface-budget"}) do
    local env,_,addon=Boot(nil,function(_,core) local old=core.HasCapability; core.HasCapability=function(self,name,version) return name~=cap and old(self,name,version) end end)
    Check(not addon.initialized and env.YiboReputationForeverDB==nil,"missing Core capability stops before DB: "..cap)
end
local _,_,wrong=Boot(nil,function(env) env.WOW_PROJECT_ID=19 end); Check(not wrong.initialized,"wrong client stopped")
local de,_,da=Boot(nil,nil,true)
Check(de.YiboReputationDB.sentinel=="mists" and not de.YiboReputationDB.settings and not da.CoreIntegration.initialized,"forced Mists manifest cannot write on Forever")
local ue,_,ua,uf,ud=Boot(nil,function(env) env.C_Reputation=nil end)
uf("PLAYER_ENTERING_WORLD"); ud()
Check(select(2,ua.Store:Get(ue.TEST_GUID))=="unavailable" and not ua.Store:Get(ue.TEST_GUID),"missing native API is unavailable, not empty")
local le,lc,la=Boot(nil,function(_,core) core._testIsInitialized=core.IsInitialized; core.IsInitialized=function() return false end end)
Check(not la.initialized and le.YiboReputationForeverDB==nil,"unready Core stops before save")
lc.IsInitialized=lc._testIsInitialized; lc.Events:Fire("CORE_READY")
Check(la.initialized and la:Initialize(),"late Core and repeated initialization")
local ne,_,na=Boot(nil,function(_,core) core.Locale=nil end)
Check(not na.initialized and ne.YiboReputationForeverDB==nil,"missing language facility stops with bootstrap diagnostic")
local be,_,ba,bf,bd,by=Boot()
bf("PLAYER_ENTERING_WORLD"); bd(); by.rows={Faction(72,4600,false)}; by.byID[9999]=Faction(123,10,false)
ba.Scanner:Scan(); Check(ba.Store:Get(be.TEST_GUID).factions[72].value==4500,"mismatched by-ID response rejects whole batch")
by.failByID=true; ba.Scanner:Scan()
Check(select(2,ba.Store:Get(be.TEST_GUID))=="error","failed known-ID read is not treated as absent")
by.failByID=nil; be.C_Reputation.GetFactionDataByID=nil; ba.Scanner:Scan()
Check(ba.Store:Get(be.TEST_GUID).factions[72].value==4600 and ba.Store:RowState(be.TEST_GUID,9999)=="stale","missing by-ID API retains unseen stale row while visible rows refresh")
by.rows[1].isHeader=nil; ba.Scanner:Scan()
Check(select(2,ba.Store:Get(be.TEST_GUID))=="error","incomplete native row rejected")
by.rows={Faction(81,7000)}; by.rows[1].isHeader=true; by.rows[1].isHeaderWithRep=true
ba.Scanner:Scan()
Check(ba.Store:Get(be.TEST_GUID).factions[81].value==7000,"header with reputation is a real faction")
be.SlashCmdList.YIBOREPUTATION(""); bd()
Check(be.YiboReputation.AccountPage and be.YiboReputation.Store:Get(be.TEST_GUID).factions[81].isAccountWide==nil,"missing native account flag stays unknown")
by.rows[1].currentStanding=7100; bf("UPDATE_FACTION")
ba.Store:Delete({id="Other"}); bd()
Check(ba.Store:Get(be.TEST_GUID).factions[81].value==7100,"cleanup of another GUID does not cancel current observation")
for _,case in ipairs({{"zhCN","auto","zh"},{"enUS","auto","en"},{"zhCN","en","en"},{"enUS","zh","zh"}}) do
    local coreSave=c.Defaults:Copy(c.Database:GetDB()); coreSave.settings.language=case[2]
    local env,core,addon,native,drain=Boot(nil,nil,nil,{client=case[1],savedCore=coreSave})
    native("PLAYER_ENTERING_WORLD"); drain(); env.SlashCmdList.YIBOREPUTATION(""); drain()
    Check(core.Locale:GetLanguage()==case[3] and core.AccountView.frame.instances.reputation.rows[1].labels.faction:GetText()=="Faction72","four session language modes")
    local firstRow=core.AccountView.frame.instances.reputation.rows[1]
    Check(firstRow.labels.reaction:GetText()==addon:T("STANDING.5") and firstRow.labels.value:GetText()=="1500 / 6000","localized standing and progress in each session language")
    Check(#core.Locale:GetMissingEnglish("YiboReputation")==0,"target resources complete")
end
Check(#e.TEST_MESSAGES==0,"no hidden callback failures: "..table.concat(e.TEST_MESSAGES," | "))
for _,case in ipairs({
    {rank=5,min=3000,max=9000,value=3100,key="STANDING.5",text="100 / 6000",fraction=100/6000},
    {rank=5,min=3000,max=9000,value=3000,key="STANDING.5",text="0 / 6000",fraction=0},
    {rank=4,min=0,max=3000,value=2000,key="STANDING.4",text="2000 / 3000",fraction=2/3},
    {rank=5,min=3000,max=9000,value=4855,key="STANDING.5",text="1855 / 6000",fraction=1855/6000},
    {rank=3,min=-3000,max=0,value=-2000,key="STANDING.3",text="1000 / 3000",fraction=1/3},
    {rank=8,min=42000,max=43000,value=42000,key="STANDING.8",fraction=1},
}) do
    local display=a.ReputationDisplay:Get({reaction=case.rank,minimum=case.min,maximum=case.max,value=case.value})
    Check(display.rank==a:T(case.key) and display.progress==(case.text or a:T("FOREVER.MAXIMUM")),"native standing and rank-relative progress example")
    Check(display.fraction==case.fraction and display.color,"bar proportion for native progression")
end
local custom=a.ReputationDisplay:Get({reaction=5,minimum=0,maximum=100,value=50})
Check(not custom.color and custom.rank==a:T("FOREVER.DISPLAY_UNCONFIRMED"),"unverified rank structure remains unconfirmed")
local pe,pc,pa,pf,pdrain,pdata=Boot()
pf("PLAYER_ENTERING_WORLD"); pdrain(); pe.SlashCmdList.YIBOREPUTATION(""); pdrain()
local pp=pc.AccountView.frame.instances.reputation
pdata.rows={Faction(72,3000,false)}; pdata.byID={}; pa.Scanner:Scan(); pdrain()
Check(pp.rows[1].labels.value:GetText()=="0 / 6000" and not pp.rows[1].progress.fill:IsShown(),"zero progress keeps readable label with empty fill")
pa.AccountPage:Refresh(pp,{characters={{id=pe.TEST_GUID}},fields={{id="faction",title="Faction"}}})
Check(not pp.rows[1].progress:IsShown(),"hidden progress field hides bar and label")
pc.AccountView:NotifyPageChanged("reputation"); pdrain(); pc.AccountView.frame:Hide(); pc.AccountView:ShowPreview("reputation",pe.Minimap)
Check(pp.rows[1].labels.reaction:GetText()==pa:T("STANDING.5") and pp.rows[1].labels.value:GetText()=="0 / 6000","preview uses same standing and progress")
print("ReputationForever Smoke passed: "..checks.." checks (actual Core/Reputation manifests; simulated client/UI)")
