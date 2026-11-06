local BootCore=dofile("_NonRelease/CoreForever/Harness.lua")
local checks=0
local function Check(value,label) checks=checks+1; assert(value,label) end
local function Boot(saved,configure,defaultManifest,language)
    local e,c,fire,_,load=BootCore(true,language and language.savedCore)
    if language then e.GetLocale=function() return language.client end end
    e.TEST_GUID="Player-Test-1"; e.GetServerTime=function() return 200000 end; e.IsLoggedIn=function() return true end
    local d={reads=0,items={[1]=1001,[5]=1005,[16]=1016}}
    local function Link(id) return "|cffffffff|Hitem:"..id..":0:0:0|h[Item"..id.."]|h|r" end
    e.GetInventoryItemID=function(unit,slot)
        assert(unit=="player"); d.reads=d.reads+1
        if d.fail then error("not ready") end
        local id=d.items[slot]; if d.changing and slot==1 then return id+(math.floor((d.reads-1)/19)%2) end
        return id
    end
    e.GetInventoryItemLink=function(_,slot) local id=d.items[slot]; if d.badLink and id then return Link(id+1) end; return id and not d.noLink and Link(id) or nil end
    e.GetItemInfo=function(id) if d.cacheFail then error("cache unavailable") end; if d.uncached then return end; return "Item"..id,Link(id),nil,nil,nil,nil,nil,nil,nil,1 end
    e.issecretvalue=function(value) return d.secret and value==1001 end
    for _,name in ipairs({"EquipItemByName","PickupInventoryItem","SocketInventoryItem","LearnTalent","CastSpellByID"}) do e[name]=function() error("unexpected action "..name) end end
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN")
    e.YiboBuildsDB={sentinel="mists"}; e.YiboBuildsForeverDB=saved
    if configure then configure(e,c,d) end
    for line in io.lines("YiboBuilds/"..(defaultManifest and "YiboBuilds.toc" or "YiboBuilds_Forever.toc")) do
        line=line:gsub("\r",""); if line:match("%.lua$") then load("YiboBuilds/"..line:gsub("\\","/"),"YiboBuilds") end
    end
    fire("ADDON_LOADED","YiboBuilds")
    local function Flush()
        for i=1,20 do if #e.TEST_TIMERS==0 then return end; local timers=e.TEST_TIMERS; e.TEST_TIMERS={}; for _,timer in ipairs(timers) do timer[2]() end end
        error("timer loop")
    end
    return e,c,e.YiboBuilds,fire,Flush,d
end
local e,c,a,fire,flush,d=Boot()
Check(a.initialized and a.VERSION=="0.1.0","Forever equipment manifest starts")
Check(e.YiboBuildsDB.sentinel=="mists" and not e.YiboBuildsDB.characters,"Mists store untouched")
Check(not a.Snapshot and not a.GoalTargets and not a.EnchantCatalog,"MoP talents and augmentation excluded")
Check(not a.Scanner:Scan(true) and d.reads==0,"no reads before entering world")
e.SlashCmdList.YIBOBUILDS(""); flush(); local panel=c.AccountView.frame.instances.builds
Check(#panel.renderedEquipment==0 and panel.status:GetText()==a:T("FOREVER.UNKNOWN"),"unknown is not empty equipment")
fire("PLAYER_ENTERING_WORLD"); flush()
local row,state=a.Store:Get(e.TEST_GUID)
Check(state=="known" and row.slots[1].itemID==1001 and row.slots[2].itemID==0 and row.slots[16].itemID==1016,"whole equipment and explicit empty slots captured")
Check(#panel.renderedEquipment==19 and panel.rows[1].labels.item:GetText()=="Item1001" and panel.rows[2].labels.item:GetText()==a:T("FOREVER.EMPTY"),"native item names and empty slots shown")
Check(panel.rows[1].labels.slot:GetText()==a:T("FOREVER.SLOT_HEAD"),"localized slot labels")
row.slots[1].itemID=999; Check(a.Store:Get(e.TEST_GUID).slots[1].itemID==1001,"snapshots returned by value")
Check(not a.Store:Get("Other"),"current GUID only")
local before=d.reads; for i=1,20 do fire("PLAYER_EQUIPMENT_CHANGED") end; flush()
Check(d.reads-before==38,"equipment event burst merged into two passes")
before=d.reads; fire("UNIT_INVENTORY_CHANGED","target"); flush(); Check(d.reads==before,"other unit ignored")
d.items[1]=1002; fire("UNIT_INVENTORY_CHANGED","player"); flush(); Check(a.Store:Get(e.TEST_GUID).slots[1].itemID==1002,"equipment replacement captured")
d.items[1]=nil; fire("PLAYER_EQUIPMENT_CHANGED"); flush(); Check(a.Store:Get(e.TEST_GUID).slots[1].itemID==0,"unequip clears only through full successful scan")
d.items[1]=1001; a.Scanner:Scan(true)
for _,flag in ipairs({"fail","changing","badLink","secret"}) do
 d[flag]=true; Check(not a.Scanner:Scan(true) and select(2,a.Store:Get(e.TEST_GUID))=="error","failure marked: "..flag)
 Check(a.Store:Get(e.TEST_GUID).slots[1].itemID==1001,"old facts retained: "..flag); d[flag]=nil
end
d.cacheFail=true
Check(a.Scanner:Scan(true) and select(2,a.Store:Get(e.TEST_GUID))=="known","equipment identity does not require cached item names")
Check(a.Store:Get(e.TEST_GUID).slots[1].itemID==1001,"name cache failure retains native equipment identity")
d.cacheFail=nil
d.noLink=true; Check(a.Scanner:Scan(true) and a.Store:Get(e.TEST_GUID).slots[1].itemID==1001,"known item ID survives uncached link"); d.noLink=nil
local getter=e.GetInventoryItemID; e.GetInventoryItemID=nil
Check(not a.Scanner:Scan(true) and a.Store:Get(e.TEST_GUID).slots[1].itemID==1001,"missing API preserves old equipment"); e.GetInventoryItemID=getter
local old=d.items; d.items={}
Check(not a.Scanner:Scan(false) and a.Store:Get(e.TEST_GUID).slots[1].itemID==1001,"all nil at world entry cannot erase equipment")
Check(a.Scanner:Scan(true) and a.Store:Get(e.TEST_GUID).slots[1].itemID==0,"manual confirmed all-empty captured")
d.items=old; a.Scanner:Scan(true); flush()
d.uncached=true; a:NotifyChanged(); flush()
Check(panel.rows[1].labels.item:GetText()==a:T("FOREVER.UNCACHED",1001),"uncached name shows stable ID")
d.uncached=nil; fire("GET_ITEM_INFO_RECEIVED",1001); flush(); Check(panel.rows[1].labels.item:GetText()=="Item1001","item cache event updates display")
local saved=c.Defaults:Copy(e.YiboBuildsForeverDB)
local e2,c2,a2,f2,fl2,d2=Boot(saved)
e2.SlashCmdList.YIBOBUILDS(""); fl2()
Check(select(2,a2.Store:Get(e2.TEST_GUID))=="stale" and #c2.AccountView.frame.instances.builds.renderedEquipment==19,"saved snapshot shown stale before world scan")
a2.AccountPage:Refresh(c2.AccountView.frame.instances.builds,{characters={},fields=a2.AccountPage:Fields()})
Check(#c2.AccountView.frame.instances.builds.renderedEquipment==0,"Core hidden character excluded")
f2("PLAYER_ENTERING_WORLD"); fl2(); c2.AccountView.frame:Hide()
Check(c2.AccountView:ShowPreview("builds",e2.Minimap),"Core preview opens")
Check(#c2.AccountView.frame.instances.builds.renderedEquipment==19 and not c2.AccountView.frame.instances.builds.refresh:IsShown(),"preview same snapshot read only")
f2("PLAYER_EQUIPMENT_CHANGED"); a2.Store:Delete({id=e2.TEST_GUID}); fl2(); Check(not a2.Store:Get(e2.TEST_GUID),"cleanup cancels queued repopulation")
a2.Scanner:Scan(true); a2.Store:Delete({id=e2.TEST_GUID},{replay=true,deletedAt=199999}); Check(a2.Store:Get(e2.TEST_GUID)~=nil,"cleanup replay preserves newer snapshot")
a2.Store:Delete({id="Other"}); Check(select(2,a2.Store:Get(e2.TEST_GUID))=="known","other character cleanup does not invalidate current")
f2("PLAYER_LEAVING_WORLD"); before=d2.reads; f2("PLAYER_EQUIPMENT_CHANGED"); fl2(); Check(d2.reads==before,"leaving world stops deferred reads")
for _,cap in ipairs({"localization","item-resolver","character-name-format","character-identity","characters","character-cleanup","account-view","account-entry","account-preview-characters","account-character-admission","account-surface-budget"}) do
 local be,bc,ba=Boot(nil,function(_,core) local original=core.HasCapability; core.HasCapability=function(self,name,v) return name~=cap and original(self,name,v) end end)
 Check(not ba.initialized and be.YiboBuildsForeverDB==nil,"missing required capability stops before save: "..cap)
end
for _,bad in ipairs({{schema=99},{schema=1,clientScope={target="Mists"},characters={}}}) do
 local be,_,ba=Boot(bad); Check(not ba.initialized and be.YiboBuildsForeverDB==bad,"incompatible save untouched")
end
local bad=c.Defaults:Copy(saved); bad.characters[e.TEST_GUID].slots[19]=nil
local be,_,ba=Boot(bad); Check(not ba.initialized and be.YiboBuildsForeverDB==bad,"incomplete stored snapshot rejected before mutation")
local de,_,da=Boot(nil,nil,true); Check(not da.CoreIntegration.initialized and de.YiboBuildsDB.sentinel and not de.YiboBuildsDB.characters,"default MoP manifest cannot initialize on Forever")
for _,case in ipairs({{client="zhCN",expected="角色构筑"},{client="enUS",expected="Character builds"},{client="enUS",savedCore={settings={language="zh"}},expected="角色构筑"},{client="zhCN",savedCore={settings={language="en"}},expected="Character builds"}}) do
 local le,lc,la,lf,lfl=Boot(nil,nil,nil,case); lf("PLAYER_ENTERING_WORLD"); lfl(); le.SlashCmdList.YIBOBUILDS(""); lfl()
 Check(la:T("FOREVER.TITLE")==case.expected,"client and manual language respected: "..case.client..case.expected)
 Check(not lc.AccountView.frame.instances.builds.rows[1].labels.slot:GetText():match("FOREVER"),"localized slot resource available")
end
local le,lc,la=Boot(nil,function(_,core) core.oldInitialized=core.IsInitialized; core.IsInitialized=function() return false end end)
Check(not la.initialized and le.YiboBuildsForeverDB==nil,"late Core stops before store")
lc.IsInitialized=lc.oldInitialized; lc.Events:Fire("CORE_READY"); Check(la.initialized and la:Initialize(),"late Core registration is idempotent")
local future
-- Use the active successful instance for future-dated cleanup and strict method checks.
future=c.Defaults:Copy(a.Store:Get(e.TEST_GUID)); future.observedAt=200001; a.Store:Commit(e.TEST_GUID,future)
a.Store:Delete({id=e.TEST_GUID},{replay=true,deletedAt=199999}); Check(not a.Store:Get(e.TEST_GUID),"future-dated snapshot is not protected by deletion replay")
local we,_,wa=Boot(nil,function(env) env.WOW_PROJECT_ID=19 end)
Check(not wa.initialized and we.YiboBuildsForeverDB==nil,"wrong client rejected before save")
local xe,_,xa=Boot(nil,function(_,core) core.ItemResolver.Parse=nil end)
Check(not xa.initialized and xe.YiboBuildsForeverDB==nil,"missing public resolver method stops before save")
Check(#e.TEST_MESSAGES==0,"no hidden errors: "..table.concat(e.TEST_MESSAGES," | "))
print("BuildsForever Smoke passed: "..checks.." checks (actual Core/Builds manifests; simulated client/UI)")
