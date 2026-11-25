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
    local createFrame = e.CreateFrame
    e.CreateFrame = function(kind, ...)
        local frame = createFrame(kind, ...)
        if kind == "DressUpModel" then
            frame.SetUnit = function(self, unit)
                d.modelLoads = (d.modelLoads or 0) + 1
                if d.failModel then error("model unavailable") end
                self.unit = unit
            end
            frame.ClearModel = function(self) self.unit = nil end
        end
        return frame
    end
    e.GetItemInfo=function(id) if d.cacheFail then error("cache unavailable") end; if d.uncached then return end; return "Item"..id,Link(id),nil,nil,nil,nil,nil,nil,nil,1 end
    e.issecretvalue=function(value) return d.secret and value==1001 end
    for _,name in ipairs({"EquipItemByName","PickupInventoryItem","SocketInventoryItem","LearnTalent","CastSpellByID"}) do e[name]=function() error("unexpected action "..name) end end
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN")
    e.YiboBuildsDB={sentinel="mists"}; e.YiboBuildsForeverDB=saved
    if configure then configure(e,c,d) end
    local manifestVersion
    for line in io.lines("YiboBuilds/"..(defaultManifest and "YiboBuilds.toc" or "YiboBuilds_Forever.toc")) do
        manifestVersion=manifestVersion or line:match("^## Version:%s*(%S+)")
        line=line:gsub("\r",""); if line:match("%.lua$") then load("YiboBuilds/"..line:gsub("\\","/"),"YiboBuilds") end
    end
    fire("ADDON_LOADED","YiboBuilds")
    local function Flush()
        for i=1,20 do if #e.TEST_TIMERS==0 then return end; local timers=e.TEST_TIMERS; e.TEST_TIMERS={}; for _,timer in ipairs(timers) do timer[2]() end end
        error("timer loop")
    end
    return e,c,e.YiboBuilds,fire,Flush,d,manifestVersion
end
local e,c,a,fire,flush,d,manifestVersion=Boot()
Check(a.initialized and manifestVersion and a.VERSION==manifestVersion,"Forever starts with the version declared in its manifest")
Check(e.YiboBuildsDB.sentinel=="mists" and not e.YiboBuildsDB.characters,"Mists store untouched")
Check(not a.Snapshot and not a.GoalTargets and not a.EnchantCatalog,"MoP talents and augmentation excluded")
Check(not a.Scanner:Scan(true) and d.reads==0,"no reads before entering world")
e.SlashCmdList.YIBOBUILDS(""); flush(); local panel=c.AccountView.frame.instances.builds
Check(#panel.renderedEquipment==0 and panel.status:GetText()==a:T("FOREVER.UNKNOWN"),"unknown is not empty equipment")
fire("PLAYER_ENTERING_WORLD"); flush()
local row,state=a.Store:Get(e.TEST_GUID)
assert(not c.AccountView._pages.builds.lastError,c.AccountView._pages.builds.lastError)
Check(state=="known" and row.slots[1].itemID==1001 and row.slots[2].itemID==0 and row.slots[16].itemID==1016,"whole equipment and explicit empty slots captured")
Check(panel.doll:IsShown() and panel.doll.model.unit=="player" and #panel.renderedEquipment==19,
    "main page shows the character model with all saved slots")
Check(panel.doll.slots[1].itemLabel:GetText()=="Item1001" and panel.doll.slots[2].itemLabel:GetText()==a:T("FOREVER.EMPTY")
    and panel.doll.slots[18].item.itemID==0,"slot cards show names and explicit empties including ranged")
Check(panel.doll.slots[1].slotLabel:GetText()==a:T("FOREVER.SLOT_HEAD"),"localized slot labels")
panel.scroll:SetWidth(460)
a.AccountPage:Refresh(panel,{characters={c.Characters:GetCurrent()},fields=a.AccountPage:Fields()})
Check(not panel.doll:IsShown() and panel.rows[1].labels.item:GetText()=="Item1001","narrow window retains readable list")
panel.rows[1]:Fire("OnEnter")
Check(e.GameTooltip.link==row.slots[1].itemLink,"narrow equipment list opens the saved native item tooltip")
panel.rows[2]:Fire("OnEnter")
Check(e.GameTooltip.lines[2].text==a:T("FOREVER.EMPTY"),"empty slot uses a text-only tooltip")
panel.rows[2]:Fire("OnLeave")
panel.scroll:SetWidth(720)
a.AccountPage:Refresh(panel,{characters={c.Characters:GetCurrent()},fields=a.AccountPage:Fields()})
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
local originalItemLink=e.GetInventoryItemLink
e.ITEM_QUALITY_COLORS={[2]={r=0.12,g=1,b=0}}
e.GetInventoryItemLink=function(unit,slot)
    if slot==1 and not d.noLink then return "|cnIQ2:|Hitem:1001:0:0:0|h[Saved item name]|h|r" end
    return originalItemLink(unit,slot)
end
d.uncached=true; a:NotifyChanged(); flush()
a.Scanner:Scan(true); flush()
Check(panel.doll.slots[1].itemLabel:GetText()=="Saved item name" and panel.doll.slots[1].itemLabel.textColor[1]==0.12,
    "native named-quality hyperlink preserves its exact label and native color without an item cache")
d.noLink=true; a.Scanner:Scan(true); flush()
Check(panel.doll.slots[1].itemLabel:GetText()==a:T("FOREVER.UNCACHED",1001),"uncached item without a link falls back to stable ID")
d.uncached=nil; fire("GET_ITEM_INFO_RECEIVED",1001); flush(); Check(panel.doll.slots[1].itemLabel:GetText()=="Item1001","item cache event updates display")
d.noLink=nil; e.GetInventoryItemLink=originalItemLink; a.Scanner:Scan(true); flush()
local loads = d.modelLoads
a.Scanner:Scan(true); flush()
Check(d.modelLoads==loads,"same equipment scan keeps the existing model")
d.failModel=true; d.items[1]=1010; a.Scanner:Scan(true); flush()
Check(panel.doll.appearanceFallback:IsShown() and panel.doll.slots[1].item.itemID==1010,"model failure leaves equipment slots readable")
d.failModel=nil; d.items[1]=1001; a.Scanner:Scan(true); flush()
local saved=c.Defaults:Copy(e.YiboBuildsForeverDB)
local e2,c2,a2,f2,fl2,d2=Boot(saved)
e2.SlashCmdList.YIBOBUILDS(""); fl2()
Check(select(2,a2.Store:Get(e2.TEST_GUID))=="stale" and #c2.AccountView.frame.instances.builds.renderedEquipment==19,"saved snapshot shown stale before world scan")
a2.AccountPage:Refresh(c2.AccountView.frame.instances.builds,{characters={},fields=a2.AccountPage:Fields()})
Check(#c2.AccountView.frame.instances.builds.renderedEquipment==0,"Core hidden character excluded")
f2("PLAYER_ENTERING_WORLD"); fl2(); c2.AccountView.frame:Hide()
Check(c2.AccountView:ShowPreview("builds",e2.Minimap),"Core preview opens")
local preview = c2.AccountView.frame.instances.builds
Check(#preview.previewRows[1].cells==19 and not preview.refresh:IsShown() and not preview.header:IsShown(),"preview renders an equipment icon row")
Check(preview.previewRows[1].cells[2].item.itemID==0,"confirmed empty slot remains in the matrix")
preview.previewRows[1].cells[1]:Fire("OnEnter")
Check(e2.GameTooltip.link==a2.Store:Get(e2.TEST_GUID).slots[1].itemLink,"entry preview uses the full link from the same equipment snapshot")
local other = {id="PreviewOther", name="Other", realm="Realm"}
local otherGear = a2.Store:Get(e2.TEST_GUID)
otherGear.slots[1] = {itemID=0}
a2.Store.db.characters[other.id] = otherGear
a2.AccountPage:Refresh(preview,{preview=true, characters={c2.Characters:GetCurrent(), other}})
Check(preview.previewRows[1].cells[1].item.itemID~=0 and preview.previewRows[2].cells[1].item.itemID==0,
    "two GUIDs render their own snapshots")
f2("PLAYER_EQUIPMENT_CHANGED"); a2.Store:Delete({id=e2.TEST_GUID}); fl2(); Check(not a2.Store:Get(e2.TEST_GUID),"cleanup cancels queued repopulation")
a2.Scanner:Scan(true); a2.Store:Delete({id=e2.TEST_GUID},{replay=true,deletedAt=199999}); Check(a2.Store:Get(e2.TEST_GUID)~=nil,"cleanup replay preserves newer snapshot")
a2.Store:Delete({id="Other"}); Check(select(2,a2.Store:Get(e2.TEST_GUID))=="known","other character cleanup does not invalidate current")
f2("PLAYER_LEAVING_WORLD"); before=d2.reads; f2("PLAYER_EQUIPMENT_CHANGED"); fl2(); Check(d2.reads==before,"leaving world stops deferred reads")
for _,cap in ipairs({"localization","item-resolver","character-name-format","character-identity","characters","character-cleanup","account-view","account-entry","account-preview-characters","account-character-admission","account-surface-budget","basic-input"}) do
 local be,bc,ba=Boot(nil,function(_,core) local original=core.HasCapability; core.HasCapability=function(self,name,v) return name~=cap and original(self,name,v) end end)
 Check(not ba.initialized and be.YiboBuildsForeverDB==nil,"missing required capability stops before save: "..cap)
end
for _,bad in ipairs({{schema=99},{schema=1,clientScope={target="Mists"},characters={}}}) do
 local be,_,ba=Boot(bad); Check(not ba.initialized and be.YiboBuildsForeverDB==bad,"incompatible save untouched")
end
local bad=c.Defaults:Copy(saved); bad.characters[e.TEST_GUID].slots[19]=nil
local be,_,ba=Boot(bad); Check(not ba.initialized and be.YiboBuildsForeverDB==bad,"incomplete stored snapshot rejected before mutation")
local de,_,da=Boot(nil,nil,true)
Check(not (da and da.CoreIntegration and da.CoreIntegration.initialized) and de.YiboBuildsDB.sentinel
    and not de.YiboBuildsDB.characters and not de.YiboBuildsForeverDB,"default manifest cannot initialize on Forever")
for _,case in ipairs({{client="zhCN",expected="角色构筑"},{client="enUS",expected="Character builds"},{client="enUS",savedCore={settings={language="zh"}},expected="角色构筑"},{client="zhCN",savedCore={settings={language="en"}},expected="Character builds"}}) do
 local le,lc,la,lf,lfl=Boot(nil,nil,nil,case); lf("PLAYER_ENTERING_WORLD"); lfl(); le.SlashCmdList.YIBOBUILDS(""); lfl()
 Check(la:T("FOREVER.TITLE")==case.expected,"client and manual language respected: "..case.client..case.expected)
 Check(not lc.AccountView.frame.instances.builds.doll.slots[1].slotLabel:GetText():match("FOREVER"),"localized slot resource available")
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
local dropdownEnv,_,dropdownAddon=Boot(nil,function(_,core) core.UITheme.CreateDropdown=nil end)
Check(not dropdownAddon.initialized and dropdownEnv.YiboBuildsForeverDB==nil,"missing public dropdown stops before save")
local function TalentFixture(env, _, d)
    local ids = {104923,104924,104927,104931}
    for i=1,48 do ids[#ids+1]=105000+i end
    local positions={}
    for index,id in ipairs(ids) do
        positions[id]={x=((index-1)%8)*100,y=math.floor((index-1)/8)*90}
    end
    local create = env.CreateFrame
    env.CreateFrame = function(...)
        local frame = create(...)
        frame.CreateLine = function(self)
            local line = self:CreateTexture()
            line.SetStartPoint = function(self, ...) self.startPoint={...} end
            line.SetEndPoint = function(self, ...) self.endPoint={...} end
            line.SetThickness = function() end
            return line
        end
        return frame
    end
    d.ranks={[104923]=5,[104924]=1,[104927]=2,[104931]=2}
    d.points,d.available,d.currencyReads,d.nodeListReads=10,0,0,0
    env.C_ClassTalents={GetActiveConfigID=function() return 705207 end}
    env.C_Traits={
        GetConfigInfo=function(id) if id==705207 then return {treeIDs={1089}} end end,
        ConfigHasStagedChanges=function() return d.staged==true end,
        GetTreeNodes=function(id)
            if id~=1089 then return nil end
            d.nodeListReads=d.nodeListReads+1
            if d.unstableNodes and d.nodeListReads%2==0 then return {unpack(ids,1,#ids-1)} end
            return ids
        end,
        GetTreeCurrencyInfo=function(_,_,exclude)
            assert(exclude==true)
            d.currencyReads=d.currencyReads+1
            if d.currencyFailures and d.currencyFailures>0 then
                d.currencyFailures=d.currencyFailures-1
                return nil
            end
            local spent=d.unstablePoints and d.points+d.currencyReads%2 or d.points
            return {{traitCurrencyID=3820,spentInTree=spent,quantity=d.available}}
        end,
        GetNodeInfo=function(_,id)
            if d.incomplete and id==105001 then return nil end
            local point=positions[id]
            local edges=id==104923 and {{targetNode=104924},{targetNode=999999}}
                or id==104924 and {{targetNode=104923}} or {}
            local rank=d.ranks[id] or 0
            local entries=id==104931 and {id+100,id+200} or {id+100}
            return {ranksPurchased=rank,currentRank=id==104923 and rank+1 or rank,maxRanks=id==104923 and 7 or 3,
                entryIDs=entries,entryIDsWithCommittedRanks=id==104931 and {id+200} or nil,
                posX=not d.missingGeometry and point.x or nil,posY=point.y,visibleEdges=edges}
        end,
        GetEntryInfo=function(_,id) return {definitionID=id+100} end,
        GetDefinitionInfo=function(id)
            return {spellID=id+100,overrideDescription=id==105123 and "Native trait description" or nil}
        end,
        PurchaseRank=function() error("unexpected talent mutation") end,
    }
    env.GameTooltip.SetOwner=function(self,owner) self.owner=owner end
    env.GameTooltip.IsOwned=function(self,owner) return self.owner==owner end
    env.C_Spell={
        GetSpellName=function(id) if id==105223 then return "Native talent" end end,
        GetSpellDescription=function(id)
            if id==105224 then d.descriptionReads=(d.descriptionReads or 0)+1 end
            if id==105224 and not d.loadedSpell then return "" end
            return "Native spell description "..id
        end,
        RequestLoadSpellData=function(id) d.requestedSpell=id end,
    }
end
local te,tc,ta,tf,tflush,td=Boot(saved,TalentFixture)
Check(not ta.Talents:Scan() and te.YiboBuildsForeverDB.talents==nil,"legacy equipment save works before talent scan")
tf("PLAYER_ENTERING_WORLD"); tflush()
local talent,state=ta.Talents:Get(te.TEST_GUID)
Check(state=="known" and talent.trees[1].points==10 and #talent.trees[1].nodes==4,"native 52-node fixture produces four invested ranks and 10 points")
Check(not ta.Talents:Get("Other"),"talent snapshot is current-character only")
te.SlashCmdList.YIBOBUILDS(""); tflush()
local tp=tc.AccountView.frame.instances.builds
tp.talentsTab:GetScript("OnClick")(tp.talentsTab)
Check(tp.showTalents and tp.showTree and not tp.doll:IsShown() and #tp.talentTree.tiles==52
    and tp.talentTree.tiles[1].rank:GetText()=="5" and tp.talentTree.tiles[5].rank:GetText()=="0","talent tab draws spent and unspent nodes")
local _,_,_,_,talentTop=tp.scroll:GetPoint(1)
Check(talentTop == -76 and not tp.status:IsShown(),"known talent tree starts below two compact rows")
Check(#tp.talentTree.lines==1 and tp.talentTree.lines[1].startPoint[3]<tp.talentTree.lines[1].endPoint[3],
    "native endpoints draw once and unresolved endpoints do not invent links")
Check(tp.talentTree.titles[1]:GetText()==ta:T("FOREVER.TALENT_TREE_AVAILABLE",1089,10,0),"explicit zero available points display")
tp.talentTree.tiles[1]:Fire("OnEnter")
Check(te.GameTooltip.lines[1].text=="Native talent"
    and te.GameTooltip.lines[2].text==ta:T("FOREVER.TALENT_RANK_DETAIL","6","7")
    and te.GameTooltip.lines[3].text=="Native trait description",
    "node tooltip uses native current and max ranks and prefers trait-specific description")
tp.talentTree.tiles[2]:Fire("OnEnter")
Check(te.GameTooltip.lines[3].text==ta:T("FOREVER.TALENT_DESCRIPTION_UNAVAILABLE") and td.requestedSpell==105224,
    "uncached spell description requests native data")
td.loadedSpell=true
tflush()
Check(te.GameTooltip.lines[3].text=="Native spell description 105224","current tooltip reads the loaded description without a new hover")
td.loadedSpell=false
tp.talentTree.tiles[2]:Fire("OnEnter")
local descriptionReads=td.descriptionReads
tflush()
Check(td.descriptionReads-descriptionReads==8,"unavailable spell data stops after eight deferred reads")
tp.talentTree.tiles[2]:Fire("OnLeave")
tp.talentTree.tiles[2]:Fire("OnEnter")
tp.talentTree.tiles[2]:Fire("OnLeave")
descriptionReads=td.descriptionReads
tflush()
Check(td.descriptionReads==descriptionReads and not te.GameTooltip:IsShown(),"leaving cancels the pending refresh")
td.loadedSpell=true
tp.talentTree.tiles[4]:Fire("OnEnter")
Check(te.GameTooltip.lines[3].text=="Native spell description 105331","choice node resolves the unique committed entry")
tp.talentSearch:SetValue("  NATIVE TALENT  ",true)
Check(tp.showTree and #tp.talentMatchOffsets==1 and tp.talentMatchOffsets[1].tile==tp.talentTree.tiles[1]
    and tp.talentSearchCount:GetText()==ta:T("FOREVER.TALENT_SEARCH_COUNT",1),"trimmed case-insensitive name search retains the tree and identifies the matching node")
local _,_,_,_,searchedTop=tp.scroll:GetPoint(1)
Check(searchedTop == talentTop and tp.talentNext:IsShown(),"search results share the toolbar without taking another row")
tp.talentSearch:SetValue("105048",true)
Check(tp.talentMatchOffsets[1].tile==tp.talentTree.tiles[52] and tp.talentTree.tiles[52].point.rank==0,
    "node ID search includes uninvested nodes from the saved geometry")
tp.talentSearch:SetValue("!!",true)
Check(tp.showTree and #tp.talentMatchOffsets==0 and not tp.talentNext:IsShown()
    and tp.talentSearchCount:GetText()==ta:T("FOREVER.TALENT_SEARCH_COUNT",0),"no hits preserve tree and report zero matches")
local nodePrefix=ta:T("FOREVER.TALENT_NODE_ID",123):gsub("%s*123$","")
tp.talentSearch:SetValue(nodePrefix,true)
tp.talentNext:Fire("OnClick")
Check(#tp.talentMatchOffsets>1 and tp.talentMatchIndex==2,"next match advances within the native tree")
tp.talentSearch.clearButton:Fire("OnClick")
Check(not tp.talentQuery and not tp.talentSearchCount:IsShown(),"shared clear button restores unfiltered tree")
tp.scroll:SetWidth(330)
ta.AccountPage:Refresh(tp,tp.context)
Check(tp.showTree and #tp.renderedRows==0 and not tp.talentTreeHint:IsShown()
    and tp.talentTree.tiles[1]:GetWidth() < 34 and tp.talentTree.tiles[1]:GetWidth() >= 24,
    "narrow tree shrinks nodes while preserving the native view")
local tooNarrow,_,issue=ta.TalentTree:Render(tp.talentTree,talent,240)
Check(not tooNarrow and issue=="width","tree rejects widths below the minimum tile spacing")
Check(ta.Talents:GetRankText({maxRanks=7},5)==ta:T("FOREVER.TALENT_RANK_DETAIL",ta:T("FOREVER.TALENT_RANK_UNKNOWN"),"7")
    and ta.Talents:GetRankText({},5)==ta:T("FOREVER.TALENT_RANK_VALUE",5),"missing native ranks remain unknown and old snapshots show invested rank")
tp.scroll:SetWidth(720)
ta.AccountPage:Refresh(tp,tp.context)
Check(tp.showTree and not tp.talentTreeHint:IsShown() and tp.talentView==nil
    and tp.talentTree.tiles[1]:GetWidth()==34,"restoring space restores full-size nodes")
tp.equipmentTab:GetScript("OnClick")(tp.equipmentTab)
Check(not tp.showTalents and #tp.renderedEquipment==19,"equipment tab returns to the same equipment")
tp.talentsTab:GetScript("OnClick")(tp.talentsTab)
tc.AccountView.frame:Hide()
Check(tc.AccountView:ShowPreview("builds",te.Minimap) and not tp.showTalents and not tp.talentsTab:IsShown()
    and not tp.talentSearch:IsShown() and tp.talentView==nil and #tp.previewRows[1].cells==19,"equipment preview stays independent of the selected main tab")
td.ranks[104924]=2
td.staged=true
Check(not ta.Talents:Scan() and ta.Talents:Get(te.TEST_GUID).trees[1].points==10,"staged talents preserve committed snapshot")
td.staged=false
td.points=17
td.unstablePoints=true
Check(not ta.Talents:Scan() and ta.Talents:Get(te.TEST_GUID).trees[1].points==10
    and select(2,ta.Talents:Get(te.TEST_GUID))=="stale","changing native point totals between passes preserve the previous snapshot")
td.unstablePoints=false
td.unstableNodes=true
Check(not ta.Talents:Scan() and ta.Talents:Get(te.TEST_GUID).trees[1].points==10,
    "changing enumeration of a zero-rank node prevents accepting an incomplete tree")
td.unstableNodes=false
tf("TRAIT_CONFIG_UPDATED"); tflush()
local weighted=ta.Talents:Get(te.TEST_GUID).trees[1]
Check(weighted.points==17 and weighted.nodes[2].rank==2,"native event accepts 17 spent points for 11 purchased ranks")
Check(not weighted.observedNodeIDs,"verification data does not change the saved snapshot format")
td.incomplete=true
Check(not ta.Talents:Scan() and ta.Talents:Get(te.TEST_GUID).trees[1].points==17,"unreadable node cannot erase data")
local re,_,ra=Boot(tc.Defaults:Copy(te.YiboBuildsForeverDB))
local historical,historicalState=ra.Talents:Get(re.TEST_GUID)
Check(historicalState=="stale" and historical.trees[1].points==17 and historical.trees[1].nodes[2].rank==2
    and #ra.Talents:GetGraph(historical.trees[1])==52,"saved graph and unequal rank and point totals restore without a native API")
local oldTalentSave=tc.Defaults:Copy(te.YiboBuildsForeverDB)
oldTalentSave.talents[te.TEST_GUID].trees[1].graph=nil
oldTalentSave.talents[te.TEST_GUID].trees[1].points=11
local oe,oc,oa,_,oflush=Boot(oldTalentSave)
local oldSnapshot=oa.Talents:Get(oe.TEST_GUID)
Check(oldSnapshot.trees[1].points==11 and not oa.Talents:GetGraph(oldSnapshot.trees[1]),"0.1.2 rank-only records remain readable")
oe.SlashCmdList.YIBOBUILDS(""); oflush()
local op=oc.AccountView.frame.instances.builds
op.talentsTab:Fire("OnClick")
Check(not op.showTree and op.talentTreeHint:GetText()==oa:T("FOREVER.TALENT_TREE_UNAVAILABLE") and #op.renderedRows==0,
    "older rank-only snapshot offers refresh without inventing a tree")
td.incomplete=false
td.missingGeometry=true
Check(ta.Talents:Scan() and not ta.Talents:Get(te.TEST_GUID).trees[1].graph,"missing coordinates still commit known ranks")
local fallback=ta.Talents:Get(te.TEST_GUID).trees[1]
Check(not fallback.graph and not fallback.catalog and #fallback.nodes==4,"missing geometry retains the purchased ranks without saving a separate list")
td.missingGeometry=false
tc.AccountView:HidePreview()
tc.AccountView:Toggle("builds")
tflush()
td.ranks,td.points,td.available={},0,17
td.currencyFailures=1
tf("TRAIT_CONFIG_UPDATED")
tf("TRAIT_TREE_CURRENCY_INFO_UPDATED")
tflush()
local reset,resetState=ta.Talents:Get(te.TEST_GUID)
Check(resetState=="known" and reset.trees[1].points==0 and reset.trees[1].available==17
    and #reset.trees[1].nodes==0,"reset events retry a transient read and replace spent ranks with a complete zero-point snapshot")
Check(tp.showTree and tp.talentTree.tiles[1].rank:GetText()=="0"
    and tp.talentTree.titles[1]:GetText()==ta:T("FOREVER.TALENT_TREE_AVAILABLE",1089,0,17),"visible tree clears old ranks and displays refunded points")
local readsBefore=td.currencyReads
td.currencyFailures=10
tf("PLAYER_TALENT_UPDATE"); tflush()
Check(td.currencyReads-readsBefore==3 and not ta.Talents.queued
    and select(2,ta.Talents:Get(te.TEST_GUID))=="stale","failed event refresh stops after three attempts and retains history")
tf("TRAIT_NODE_CHANGED"); ta.Store:Delete({id=te.TEST_GUID}); tflush()
Check(not ta.Talents:Get(te.TEST_GUID),"Core cleanup removes talent snapshot and cancels queued scan")
Check(#e.TEST_MESSAGES==0,"no hidden errors: "..table.concat(e.TEST_MESSAGES," | "))
local function EnhancementLinks(env, _, fixture)
    env.GetInventoryItemLink=function(_,slot)
        if slot==1 then return "|cffffffff|Hitem:1001:555:0:0:0:0:0|h[Item1001]|h|r" end
        if slot==5 and fixture.items[slot] then return "|cffffffff|Hitem:1005::::::0|h[Item1005]|h|r" end
    end
    env.Enum={TooltipDataLineType={ItemEnchantmentPermanent=44}}
    env.C_TooltipInfo={GetHyperlink=function(link)
        assert(link:find("item:1001:555:",1,true))
        if fixture.enchantEffect then return {lines={
            {type=44,enchantID=999,leftText="Unrelated effect"},
            {type=44,leftText="Ambiguous effect A"},
            {type=44,leftText="Ambiguous effect B"},
            {type=44,itemEnchantmentID=555,leftText="Native enchant effect"},
        }} end
    end}
end
local ee,ec,ea,ef,eflush,ed=Boot(saved,EnhancementLinks)
ef("PLAYER_ENTERING_WORLD"); eflush()
ee.SlashCmdList.YIBOBUILDS(""); eflush()
local ep=ec.AccountView.frame.instances.builds
ep.doll.slots[2]:Fire("OnClick")
Check(ep.activeTab=="equipment","an empty doll slot does not open enhancement details")
local gearReads=ed.reads
ep.doll.slots[1]:Fire("OnClick")
Check(ep.activeTab=="enhancements" and ep.enhancementSlot.value==1 and #ep.renderedRows==1
    and ep.renderedRows[1].slot==1 and ep.rows[1].labels.enchant:GetText()=="#555",
    "occupied doll slot opens its own enchant record")
ep.enhancementSlot:Fire("OnClick")
ep.enhancementSlot.menu.buttons[3]:Fire("OnClick")
Check(ep.enhancementSlot.value==2 and #ep.renderedRows==0
    and ep.enhancementHint:GetText()==ea:T("FOREVER.ENHANCEMENT_EMPTY_SLOT"),
    "slot picker reports an empty slot without inventing an enchant state")
ep.equipmentTab:Fire("OnClick")
ep.scroll:SetWidth(450)
ea.AccountPage:Refresh(ep,ep.context)
ep.rows[5]:Fire("OnClick")
Check(ep.activeTab=="enhancements" and ep.enhancementSlot.value==5 and #ep.renderedRows==1 and ed.reads==gearReads,
    "compact equipment list opens slot details without scanning again")
ed.items[5]=nil; ef("PLAYER_EQUIPMENT_CHANGED"); eflush()
Check(ep.enhancementSlot.value==5 and #ep.renderedRows==0 and ep.enhancementHint:IsShown(),
    "unequipping the selected slot keeps it selected and clears its enchant record")
ed.items[5]=1005; ef("PLAYER_EQUIPMENT_CHANGED"); eflush()
Check(#ep.renderedRows==1 and not ep.enhancementHint:IsShown(),"equipping the selected slot restores its live detail")
ep.enhancementsTab:GetScript("OnClick")(ep.enhancementsTab)
Check(ep.activeTab=="enhancements" and not ep.doll:IsShown() and #ep.renderedRows==3,"enhancement tab lists only occupied slots")
Check(#ep.columns==3 and ep.columns[3].id=="enchant" and not ep.labels.gems,"Forever enhancement page has no socket column")
Check(ep.rows[1].labels.enchant:GetText()=="#555","enchant ID comes from the equipped link")
Check(ep.rows[2].labels.enchant:GetText()==ea:T("FOREVER.NO_ENCHANT"),"blank enchant field is explicit absence")
Check(ep.rows[3].labels.enchant:GetText()==ea:T("FOREVER.ENHANCEMENT_UNKNOWN"),"uncached equipped link does not imply no enhancements")
ep.rows[1]:Fire("OnEnter")
Check(ee.GameTooltip.link==ep.renderedRows[1].item.itemLink,"native tooltip uses full equipped link")
ed.enchantEffect=true
ef("GET_ITEM_INFO_RECEIVED"); eflush()
Check(ep.rows[1].labels.enchant:GetText()=="Native enchant effect","native enchant text takes precedence over the numeric fallback")
Check(ea.Enhancements:Read({itemID=1002,itemLink="item:1001:555:0"})==nil,"mismatched stored link is unknown")
Check(ea.Enhancements:Read({itemID=1001,itemLink="item:1001"})==nil,"missing enchant field is unknown")
ec.AccountView.frame:Hide()
Check(ec.AccountView:ShowPreview("builds",ee.Minimap) and ep.activeTab=="equipment"
    and not ep.enhancementsTab:IsShown() and #ep.previewRows[1].cells==19,"enhancement tab does not change the entry preview")
Check(ep.activeTab=="equipment" and not ep.enhancementSlot:IsShown(),"entry preview remains a read-only equipment projection")
local legacy=c.Defaults:Copy(saved)
legacy.equipmentBaselines={[e.TEST_GUID]=c.Defaults:Copy(legacy.characters[e.TEST_GUID])}
local ce,cc,ca,_,cflush=Boot(legacy)
ce.SlashCmdList.YIBOBUILDS(""); cflush()
local cp=cc.AccountView.frame.instances.builds
Check(ca.initialized and #cp.renderedEquipment==19 and cp.compareButton==nil
    and cp.equipmentView==nil and cp.equipmentSearch==nil,"legacy save loads with the equipment controls removed")
Check(ca.Store.db.equipmentBaselines[ce.TEST_GUID]~=nil and ca.Store.SaveEquipmentBaseline==nil,
    "existing baselines are preserved but the addon cannot create more")
ca.Store:Delete({id=ce.TEST_GUID})
Check(ca.Store.db.equipmentBaselines[ce.TEST_GUID]==nil,"Core character cleanup still removes old baseline data")
print("BuildsForever Smoke passed: "..checks.." checks (actual Core/Builds manifests; simulated client/UI)")
