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
    e.date = os.date
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
Check(a.initialized and a.VERSION=="0.3.0","Forever manifest starts")
Check(not e.YiboReputationDB.settings and e.YiboReputationDB.sentinel=="mists","Mists save untouched")
Check(not a.Migration and not a.FactionRegistry and not a.GoalTargets and not a.Nomi,"MoP catalogs and operations excluded")
Check(not a.Scanner:Scan() and d.reads==0,"no native reads before world entry")
e.SlashCmdList.YIBOREPUTATION(""); flush()
local panel=c.AccountView.frame.instances.reputation
local function Rows(panel) return panel.matrixView.rows end
local function ID(panel, index) return Rows(panel)[index].node.factionID end
local function Cell(panel, row, column) return panel.matrixRows[row].displays[column or 1] end
local function Search(panel, text, flush)
    panel.matrixToolbar.search:SetValue(text)
    panel.matrixToolbar.search:Fire("OnTextChanged", true)
    flush()
end
local function Select(control, option, flush)
    control:Fire("OnClick")
    control.menu.buttons[option]:Fire("OnClick")
    flush()
end
local function FilterWatched(panel, value, flush)
    panel.matrixToolbar.filterButtons[value and 2 or 1]:Fire("OnClick")
    flush()
end
Check(#Rows(panel)==0,"unknown has no invented rows")
fire("PLAYER_ENTERING_WORLD"); flush()
local snapshot,state=a.Store:Get(e.TEST_GUID)
Check(state=="partial" and snapshot.factions[72].value==4500 and snapshot.factions[9999].value==-100,"raw numeric observations including negative standings")
Check(#Rows(panel)==2 and ID(panel,1)==72,"current factions displayed")
Check(table.concat(Cell(panel,2).details,"|"):find(a:T("MATRIX.SCOPE_ACCOUNT_FLAG"),1,true),"native account flag preserved in detail")
Check(Cell(panel,1).details[1]==a:T("STANDING.5") and Cell(panel,1).text=="1500" and not Cell(panel,1).delta
    and table.concat(Cell(panel,1).details,"|"):find(a:T("MATRIX.SESSION_DETAIL","0"),1,true),
    "zero baseline stays accessible in details without repeating in the cell")
Check(panel.matrixRows[1].progressBars[2].base:IsShown() and Cell(panel,1).fraction==0.25,"colored rank progress bar")
Check(Cell(panel,2).muted and table.concat(Cell(panel,2).details,"|"):find(a:T("STATE.ATYPICAL"),1,true),"unconfirmed rank is explained in details")
local filterReads=d.reads
Search(panel,"  FACTION72  ",flush)
Check(#Rows(panel)==1 and ID(panel,1)==72,"faction name search uses cached observations")
Select(panel.matrixToolbar.rank,6,flush)
Check(#Rows(panel)==1 and ID(panel,1)==72,"standing and name filters intersect")
Search(panel,"9999",flush)
Check(#Rows(panel)==0,"faction ID excluded by selected standing")
Select(panel.matrixToolbar.rank,1,flush)
Check(#Rows(panel)==1 and ID(panel,1)==9999,"ID search matches with all standings")
c.AccountView.frame:Hide()
Check(c.AccountView:ShowPreview("reputation",e.Minimap) and #Rows(panel)==0 and not panel.matrixToolbar:IsShown()
    and panel.matrixEmpty:GetText()==a:T("MATRIX.NO_WATCHED"),"preview asks for monitored factions and hides main filters")
Check(not panel.matrixRows[1]:IsShown(),"empty preview hides previously visible rows")
c.AccountView:HidePreview(); c.AccountView:Toggle("reputation"); flush()
Check(#Rows(panel)==1 and panel.matrixToolbar:IsShown(),"main filter is retained after preview")
panel.matrixToolbar.search.clearButton.scripts.OnClick(); flush()
Check(#Rows(panel)==2 and d.reads==filterReads,"clearing filter restores records without native scans")
FilterWatched(panel,true,flush)
Check(#Rows(panel)==0,"empty watch list has its own state")
FilterWatched(panel,false,flush)
panel.matrixRows[2].star:Fire("OnClick"); flush()
Check(ID(panel,2)==9999 and a:IsMonitored(9999),"watching a faction updates its control without changing order")
Check(not a.Store:ToggleWatched(123456),"watch only applies to known faction IDs")
FilterWatched(panel,true,flush)
Check(#Rows(panel)==1 and ID(panel,1)==9999,"watched-only filter applies")
local unconfirmed = Cell(panel,1).text
Search(panel,"72",flush)
Check(#Rows(panel)==0,"watched-only intersects search")
c.AccountView.frame:Hide()
Check(c.AccountView:ShowPreview("reputation",e.Minimap) and #Rows(panel)==1
    and ID(panel,1)==9999 and not panel.matrixRows[1].star:IsShown(),"entry preview uses shared rows and hides watch actions")
Check(Cell(panel,1).text==unconfirmed,"main and preview share the same unconfirmed value")
local matrixAlt = {id="ReputationMatrixAlt", name="Alt", realm="Realm"}
a.Store.db.characters[matrixAlt.id] = {observedAt=1, factions={}}
local look = {preview=true,surfaceAvailableWidth=800,characters={c.Characters:GetCurrent(),matrixAlt}}
a:RefreshMatrixView(panel,look)
Check(Cell(panel,1,2).muted and Cell(panel,1,2).details[1]==a:T("STATE.NEEDS_LOGIN"),"missing observation stays unknown")
a.Store.db.characters[matrixAlt.id].factions[9999] = {factionID=9999, name="Faction9999",
    reaction=5, minimum=3000, maximum=9000, value=4123, observedAt=1}
a:NotifyChanged()
a:RefreshMatrixView(panel,look)
Check(Cell(panel,1,2).text=="1123" and not Cell(panel,1,2).delta
    and Cell(panel,1,2).details[1]==a:T("STANDING.5") and Cell(panel,1,2).details[2]=="1123/6000"
    and table.concat(Cell(panel,1,2).details,"|"):find(a:T("STATE.STALE"),1,true)
    and table.concat(Cell(panel,1,2).details,"|"):find(a:T("MATRIX.OBSERVED_AT",os.date("%m-%d %H:%M",1)),1,true),
    "saved progress stays unmarked in the cell and keeps its rank and timestamp in details")
a.Store.db.characters[matrixAlt.id] = nil
a:NotifyChanged()
c.AccountView:HidePreview(); c.AccountView:Toggle("reputation"); flush()
Search(panel,"",flush)
local _,_,wa=Boot(c.Defaults:Copy(e.YiboReputationForeverDB))
Check(wa.Store.db.settings.watchedFactionIDs[1]==9999,"watched factions restore from save")
local legacyWatch = c.Defaults:Copy(e.YiboReputationForeverDB)
legacyWatch.settings.watchedFactionIDs = nil
legacyWatch.characters[e.TEST_GUID].watched = {[9999]=true,[72]=true}
local _,_,migratedWatch = Boot(legacyWatch)
Check(migratedWatch.Store.db.settings.watchedFactionIDs[1]==72 and migratedWatch.Store.db.settings.watchedFactionIDs[2]==9999,
    "legacy unordered selections migrate in deterministic order")
panel.matrixRows[1].star:Fire("OnClick"); flush()
Check(#Rows(panel)==0,"unwatch updates active filter")
FilterWatched(panel,false,flush)
Check(d.reads==filterReads,"watch operations do not query or mutate native reputation")
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
local increased = Cell(panel,1)
local progressBar = panel.matrixRows[1].progressBars[2]
Check(a.Store:GetSessionChange(e.TEST_GUID,72)==500 and increased.text=="2000" and increased.delta=="+500"
    and math.abs(increased.previousFraction - 1500/6000) < 0.00001
    and math.abs(progressBar.gain:GetWidth() - progressBar.track:GetWidth()*500/6000) < 0.00001
    and progressBar.gain:IsShown(), "gain segment covers exactly the additional progress")
local role = {id=e.TEST_GUID,name="A",realm="Realm"}
local dense = { characters={role}, surfaceAvailableWidth=300, fields=a:GetMatrixFields() }
a:RefreshMatrixView(panel,dense)
Check(panel.matrixRows[1].cells[2]:GetText()=="2000" and panel.matrixRows[1].progressBars[2].gain:IsShown(),
    "narrow columns prioritize current value without losing the gain segment")
role.name="Long Character Name"
dense.surfaceAvailableWidth=900
a:RefreshMatrixView(panel,dense)
Check(panel.matrixRows[1].cells[2]:GetText()==a:T("FORMAT.CELL_DELTA","2000","+500"),"wide column fits the signed delta in the same line")
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
a:RefreshMatrixView(panel,{characters={},fields=a:GetMatrixFields()})
Check(#Rows(panel)==0,"Core character exclusions respected")
a.Store:ToggleWatched(72); a.Store:ToggleWatched(9999)
c.AccountView:NotifyPageChanged("reputation"); flush(); c.AccountView.frame:Hide()
Check(c.AccountView:ShowPreview("reputation",e.Minimap),"Core owns preview")
Check(#Rows(panel)==2 and not panel.matrixToolbar:IsShown(),"preview uses same observed plus stale watched records")
c.AccountView:HidePreview(); c.AccountView:Toggle("reputation")
fire("PLAYER_LEAVING_WORLD"); flush(); before=d.reads; fire("UPDATE_FACTION"); flush()
Check(d.reads==before and select(2,a.Store:Get(e.TEST_GUID))=="stale","outside world no reads and historical state stale")
local saved=c.Defaults:Copy(e.YiboReputationForeverDB)
local e2,c2,a2,f2,fl2,d2=Boot(saved)
Check(select(2,a2.Store:Get(e2.TEST_GUID))=="stale" and a2.Store:Get(e2.TEST_GUID).factions[72].value==0,"saved data restored stale")
Check(a2.Store:GetSessionChange(e2.TEST_GUID,72)==nil,"saved reputation does not restore a session baseline")
e2.TEST_GUID=nil; f2("PLAYER_ENTERING_WORLD"); fl2(); Check(d2.reads==0,"missing identity blocks native scan")
e2.TEST_GUID="Player-Test-1"; f2("BAG_UPDATE_DELAYED"); fl2()
Check(a2.Store:Get(e2.TEST_GUID).factions[72].value==4500,"late GUID recovers from native event")
Check(a2.Store:GetSessionChange(e2.TEST_GUID,72)==0,"new session does not compare to saved standing")
local observed=d2.rows[2]
observed.reaction,observed.currentReactionThreshold,observed.nextReactionThreshold,observed.currentStanding=4,0,3000,2900
f2("UPDATE_FACTION"); fl2()
Check(a2.Store:GetSessionChange(e2.TEST_GUID,72)==-1600,"loss across ordinary ranks uses the absolute standing")
Check(c2.AccountView:ShowPreview("reputation",e2.Minimap),"Core opens the monitored matrix")
local previewPanel=c2.AccountView.frame.instances.reputation
Check(Cell(previewPanel,1).text=="2900" and Cell(previewPanel,1).delta=="-1600"
    and not previewPanel.matrixRows[1].progressBars[2].gain:IsShown(),
    "preview shows compact rank-relative progress")
observed.isAccountWide=true
f2("UPDATE_FACTION"); fl2()
Check(a2.Store:GetSessionChange(e2.TEST_GUID,72)==0,"native scope change establishes a separate baseline")
observed.reaction,observed.currentReactionThreshold,observed.nextReactionThreshold,observed.currentStanding=5,3000,9000,3100
f2("UPDATE_FACTION"); fl2()
Check(Cell(previewPanel,1).delta=="+200" and Cell(previewPanel,1).previousFraction==0
    and Cell(previewPanel,1).fraction==100/6000,"cross-rank gain highlights only the new standing's progress")
c2.AccountView._pages.reputation.SetPreviewFieldVisible("session",false); fl2()
Check(not Cell(previewPanel,1).delta and not previewPanel.matrixRows[1].progressBars[2].gain:IsShown(),
    "preview can hide the session field and its bright segment")
d2.failRow=true; a2.Scanner:Scan()
Check(a2.Store:GetSessionChange(e2.TEST_GUID,72)==nil,"failed scan never shows stale change as current")
d2.failRow=nil
observed.reaction,observed.currentReactionThreshold,observed.nextReactionThreshold,observed.currentStanding,observed.isAccountWide=5,3000,9000,4500,false
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
for _,cap in ipairs({"localization","character-name-format","character-identity","character-cleanup","account-surface-budget","basic-input"}) do
    local env,_,addon=Boot(nil,function(_,core) local old=core.HasCapability; core.HasCapability=function(self,name,version) return name~=cap and old(self,name,version) end end)
    Check(not addon.initialized and env.YiboReputationForeverDB==nil,"missing Core capability stops before DB: "..cap)
end
local _,_,wrong=Boot(nil,function(env) env.WOW_PROJECT_ID=19 end); Check(not wrong.initialized,"wrong client stopped")
local de,_,da=Boot(nil,nil,true)
Check(de.YiboReputationDB.sentinel=="mists" and not de.YiboReputationDB.settings and not da,"forced Mists manifest cannot write on Forever")
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
Check(be.YiboReputation.matrixPageRegistered and be.YiboReputation.Store:Get(be.TEST_GUID).factions[81].isAccountWide==nil,"missing native account flag stays unknown")
by.rows[1].currentStanding=7100; bf("UPDATE_FACTION")
ba.Store:Delete({id="Other"}); bd()
Check(ba.Store:Get(be.TEST_GUID).factions[81].value==7100,"cleanup of another GUID does not cancel current observation")
for _,case in ipairs({{"zhCN","auto","zh"},{"enUS","auto","en"},{"zhCN","en","en"},{"enUS","zh","zh"}}) do
    local coreSave=c.Defaults:Copy(c.Database:GetDB()); coreSave.settings.language=case[2]
    local env,core,addon,native,drain=Boot(nil,nil,nil,{client=case[1],savedCore=coreSave})
    native("PLAYER_ENTERING_WORLD"); drain(); env.SlashCmdList.YIBOREPUTATION(""); drain()
    local view = core.AccountView.frame.instances.reputation
    Check(core.Locale:GetLanguage()==case[3] and ID(view,1)==72,"four session language modes")
    Check(Cell(view,1).details[1]==addon:T("STANDING.5") and Cell(view,1).text=="1500" and not Cell(view,1).delta,"localized standing and progress in each session language")
    Check(#core.Locale:GetMissingEnglish("YiboReputation")==0,"target resources complete")
end
Check(#e.TEST_MESSAGES==0,"no hidden callback failures: "..table.concat(e.TEST_MESSAGES," | "))
for _,case in ipairs({
    {rank=5,min=3000,max=9000,value=3100,key="STANDING.5",text="100 / 6000",fraction=100/6000},
    {rank=5,min=3000,max=9000,value=3000,key="STANDING.5",text="0 / 6000",fraction=0},
    {rank=4,min=0,max=3000,value=2000,key="STANDING.4",text="2000 / 3000",fraction=2/3},
    {rank=5,min=3000,max=9000,value=4855,key="STANDING.5",text="1855 / 6000",fraction=1855/6000},
    {rank=3,min=-3000,max=0,value=-2000,key="STANDING.3",text="1000 / 3000",fraction=1/3},
    {rank=8,min=42000,max=43000,value=42000,key="STANDING.8",text="0 / 1000",fraction=0},
    {rank=8,min=42000,max=43000,value=42998,key="STANDING.8",text="998 / 1000",fraction=0.998},
    {rank=8,min=42000,max=43000,value=42999,key="STANDING.8",fraction=1},
    {rank=8,min=42000,max=42000,value=42000,key="STANDING.8",fraction=1},
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
Check(Cell(pp,1).text=="0" and Cell(pp,1).delta=="-1500" and not pp.matrixRows[1].progressBars[2].base:IsShown()
    and pp.matrixRows[1].progressBars[2].track:IsShown(), "confirmed zero has an empty track and signed loss")
pa:RefreshMatrixView(pp,{characters={{id=pe.TEST_GUID}},fields={{id="reaction",title="Rank"}}})
Check(not pp.matrixRows[1].progressBars[2].track:IsShown() and Cell(pp,1).details[1]==pa:T("STANDING.5"),"hidden progress leaves standing in the tooltip")
pa.Store:ToggleWatched(72)
pc.AccountView:NotifyPageChanged("reputation"); pdrain(); pc.AccountView.frame:Hide(); pc.AccountView:ShowPreview("reputation",pe.Minimap)
Check(Cell(pp,1).text=="0" and Cell(pp,1).delta=="-1500","preview uses the same signed-change projection")
pdata.rows[1].reaction,pdata.rows[1].currentReactionThreshold,pdata.rows[1].nextReactionThreshold,pdata.rows[1].currentStanding=8,42000,43000,42998
pa.Scanner:Scan(); pdrain()
local exalted = Cell(pp,1)
Check(exalted.text=="998" and exalted.fraction==0.998 and exalted.gainColor and pp.matrixRows[1].progressBars[2].gain:IsShown(),
    "Exalted below 999 has rank-relative progress and a distinct gain segment")
pdata.rows[1].currentStanding=42999
pa.Scanner:Scan(); pdrain()
local cappedExalted = Cell(pp,1)
Check(pp.matrixRows[1].cells[2]:GetText()==pa:T("STANDING.8") and cappedExalted.fraction==1
    and cappedExalted.details[1]==pa:T("STANDING.8") and cappedExalted.textColor
    and cappedExalted.baseColor ~= exalted.baseColor and not pp.matrixRows[1].progressBars[2].gain:IsShown(),
    "maximum standing uses a dark gold fill and a localized Exalted label")
local se,sc,sa,sf,sflush,sd=Boot()
local zulu,alpha,unknown=Faction(72,4500,false),Faction(9999,2700,false),Faction(11,30,false)
zulu.name,alpha.name,unknown.name="Zulu","Alpha","Bravo"
alpha.reaction,alpha.currentReactionThreshold,alpha.nextReactionThreshold=4,0,3000
sd.rows,sd.byID={zulu,alpha,unknown},{}
sf("PLAYER_ENTERING_WORLD"); sflush(); se.SlashCmdList.YIBOREPUTATION(""); sflush()
local sp=sc.AccountView.frame.instances.reputation
local function SortBy(index) Select(sp.matrixToolbar.sort, index, sflush) end
local sortReads=sd.reads
SortBy(2)
Check(ID(sp,1)==9999 and ID(sp,3)==72,"name order uses the recorded faction labels")
SortBy(3)
Check(ID(sp,1)==72 and ID(sp,3)==11,"standing sort puts unconfirmed ranks last")
SortBy(4)
Check(ID(sp,1)==9999 and ID(sp,3)==11,"progress sort compares rank-relative fractions")
Check(sd.reads==sortReads,"sorting does not rescan native data")
zulu.currentStanding,alpha.currentStanding=4600,2600
sf("UPDATE_FACTION"); sflush()
SortBy(5)
Check(ID(sp,1)==72 and ID(sp,2)==9999 and ID(sp,3)==11,"session sort orders gain, loss, and unknown")
sp.matrixRows[2].star:Fire("OnClick"); sflush()
Check(ID(sp,1)==72,"watching a faction preserves the main sort")
Search(sp,"Zulu",sflush)
Check(#Rows(sp)==1 and ID(sp,1)==72,"sorting preserves search eligibility")
sc.AccountView.frame:Hide()
Check(sc.AccountView:ShowPreview("reputation",se.Minimap) and #Rows(sp)==1
    and ID(sp,1)==9999 and not sp.matrixToolbar:IsShown(),"preview ignores main-window sort and filters")
sc.AccountView:HidePreview(); sc.AccountView:Toggle("reputation"); sflush()
Check(sp.matrixToolbar.sort.value=="session" and #Rows(sp)==1,"returning to the main page keeps sort and search")
Search(sp,"",sflush)
SortBy(1)
for id=100,339 do sd.rows[#sd.rows+1]=Faction(id,4500,false) end
sf("UPDATE_FACTION"); sflush()
local height = sa:GetMatrixRowHeight()
sp.matrixScroll:SetHeight(3 * height)
sp.matrixScroll:Fire("OnSizeChanged")
Check(#Rows(sp)==243 and #sp.matrixRows<30 and sp.matrixBody:GetHeight()==243*height,
    "large snapshot retains all rows while allocating only visible controls")
local reused = sp.matrixRows[1]
se.GetCursorPosition = function() return reused:GetLeft()+sp.matrixView.columns[1].width+10, 0 end
reused:Fire("OnEnter")
Check(se.GameTooltip:IsShown() and se.GameTooltip.lines[1].text==Rows(sp)[1].node.title,"tooltip describes the current row")
local reads=sd.reads
sp.matrixScroll:SetVerticalScroll(80*height)
sp.matrixScroll:Fire("OnVerticalScroll")
local scrolled=Rows(sp)[81].node
Check(sp.matrixRows[1]==reused and reused.matrixNode.factionID==scrolled.factionID and not se.GameTooltip:IsShown()
    and sd.reads==reads,"scrolling recycles rows and closes the old tooltip without reading game data")
reused:Fire("OnEnter")
Check(se.GameTooltip.lines[1].text==scrolled.title,"reused tooltip contains only the current faction lines")
reused.star:Fire("OnClick"); sflush()
Check(sa:GetMonitoredFactions()[2]==scrolled.factionID,"watch action follows the recycled row")
for id=100,112 do Check(sa:ToggleMonitored(id),"Forever accepts more than ten watched factions") end
Check(#sa:GetMonitoredFactions()>10,"Forever watch list has no fixed cap")
sc.AccountView.frame:Hide()
Check(sc.AccountView:ShowPreview("reputation",se.Minimap) and #Rows(sp)==#sa:GetMonitoredFactions(),
    "preview includes every watched faction")
sp.matrixScroll:SetHeight(3*height)
sp.matrixScroll:Fire("OnSizeChanged")
sp.matrixScroll:SetVerticalScroll(8*height)
sp.matrixScroll:Fire("OnVerticalScroll")
Check(sp.matrixRows[1].matrixNode.factionID==ID(sp,9),"long previews use the shared scroll viewport")
sc.AccountView:HidePreview()
sc.AccountView:Toggle("reputation")
sflush()
sp.matrixScroll:SetHeight(7*height)
sp.matrixScroll:Fire("OnSizeChanged")
Check(sp.matrixRows[7]:IsShown(),"resizing extends the visible pool")
Search(sp,"Zulu",sflush)
Check(sp.matrixScroll:GetVerticalScroll()==0 and sp.matrixRows[1].matrixNode.title=="Zulu" and not sp.matrixRows[2]:IsShown(),
    "filtering a scrolled list returns to the matching row and hides surplus controls")
print("ReputationForever Smoke passed: "..checks.." checks (actual Core/Reputation manifests; simulated client/UI)")
