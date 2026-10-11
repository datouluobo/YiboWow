-- Actual Core entry service, LDB, bar and settings renderer with existing frame fixture.
dofile("YiboMail/_NonRelease/Tests/WorkspaceSpec.lua")
local Core, checks = YiboCore, 0
local function Check(value,label) checks=checks+1;assert(value,label) end
local methods = getmetatable(UIParent).__index
methods.RegisterForDrag=function() end
methods.SetMovable=function() end
methods.StartMoving=function(self) self.moving=true end
methods.StopMovingOrSizing=function(self) self.moving=false end
methods.GetPoint=function(self,index) return unpack(self.points[index or 1]) end
Minimap=CreateFrame("Frame",nil,UIParent)
dofile("YiboCore/Runtime/EntryConfig.lua")
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Libs/LibStub/LibStub.lua")
dofile("YiboCore/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("YiboCore/Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
dofile("YiboCore/UI/Entry.lua")
dofile("YiboCore/UI/EntryBar.lua")
local E=Core.Entry
local s=Core.AccountView:GetSettings()
s.entry=Core.EntryConfig:Normalize({coreMode="none",pageModes={legacy="broker",unloaded="minimap"},pagePositions={legacy=137}})
local modes={none={false,false},broker={false,true},minimap={true,false},both={true,true}}
for mode,expected in pairs(modes) do
 local old={coreMode=mode,pageModes={unloaded=mode},minimap={angle=123},pagePositions={unloaded=190}}
 local normalized=Core.EntryConfig:Normalize(old)
 for _,c in ipairs({normalized.coreChannels,normalized.businessChannels.unloaded}) do
  Check(c.minimap==expected[1] and c.broker==expected[2] and c.builtinBar==false,"mode migration "..mode)
 end
 Check(not normalized.bar.enabled,"upgrade bar disabled")
 Check(normalized.minimap.angle==123 and normalized.pagePositions.unloaded==190,"position preserved")
 normalized.coreChannels.minimap=false;normalized.coreChannels.broker=false;normalized.coreChannels.builtinBar=true
 Core.EntryConfig:Normalize(normalized)
 Check(not normalized.coreChannels.minimap and not normalized.coreChannels.broker and normalized.coreChannels.builtinBar,"new structure wins on repeat")
end
local c=Core.EntryConfig:Normalize({broker={show=false},minimap={show=false}})
Check(not c.coreChannels.broker and not c.coreChannels.minimap,"missing mode preserves false flags")
dofile("YiboCore/Data/Migrations.lua")
local db={schemaVersion=10,settings={accountView={entry={coreMode="minimap",pageModes={unloaded="both"}}}}}
Check(Core.Migrations:Run(db) and db.schemaVersion==11,"schema11 migration runs")
Check(db.settings.accountView.entry.businessChannels.unloaded.broker,"unloaded plugin migrates")
Check(Core.Migrations:Run(db),"migration idempotent")
for _,name in ipairs({"YiboA","YiboZ"}) do
 Core.Registry._addons[name]={name=name}
 local id=name.."Page"
 Core.AccountView._pages[id]={id=id,addonName=name,title=name,fields={},defaultEnabled=true}
 local result,err=E:RegisterBusinessEntry(name,{id=name,pageID=id,text=name,brokerName=name,defaultMode="none"})
 Check(result~=nil,err or "business registers")
end
Check(LibStub("LibDataBroker-1.1"):GetDataObjectByName("YiboA")==nil,"no external broker when unselected")
E:Initialize()
for _,id in ipairs({"YiboCore","YiboA","YiboZ"}) do
 for mask=0,7 do
  local mini=mask%2==1;local broker=math.floor(mask/2)%2==1;local builtin=math.floor(mask/4)%2==1
  E:SetEntryChannel(id,"minimap",mini);E:SetEntryChannel(id,"broker",broker);E:SetEntryChannel(id,"builtinBar",builtin)
  local actual=E:GetEntryChannels(id)
  Check(actual.minimap==mini and actual.broker==broker and actual.builtinBar==builtin,"eight independent combinations")
  local button=id=="YiboCore" and E.button or E.businessEntries[id].button
  Check((button and button:IsShown() or false)==mini,"minimap follows independent choice")
  E:SetBuiltinBarEnabled(false)
  Check(E:GetEntryChannels(id).builtinBar==builtin,"disable retains choice")
  Check(not Core.EntryBar.frame or not Core.EntryBar.frame:IsShown(),"disabled hides frame")
  E:SetBuiltinBarEnabled(true)
  if builtin then Check(Core.EntryBar.frame:IsShown(),"selected bar restores") end
 end
end
Check(E.broker and E.broker.OnClick,"Core broker created immediately")
E:SetEntryChannel("YiboCore","broker",false)
Check(E.broker.yiboCoreEntryDisabled==true,"Core broker disabled")
E:SetEntryChannel("YiboCore","broker",true)
Check(not E.broker.yiboCoreEntryDisabled,"Core broker restored")
local list=E:GetBuiltinBarEntries()
Check(list[1].id=="YiboCore" and list[2].id=="YiboA" and list[3].id=="YiboZ","stable ordering")
E.previewOwner={id="YiboA",source="broker"}
E:SetBuiltinBarEnabled(false)
Check(E.previewOwner and E.previewOwner.source=="broker","bar disable preserves other preview owner")
E.previewOwner={id="YiboA",source="builtinBar"}
E:SetBuiltinBarEnabled(false)
Check(E.previewOwner==nil,"bar disable clears own preview")
E:SetBuiltinBarEnabled(true)
s.pages.YiboAPage=false;E:Refresh()
Check(not E:GetEntryAvailability("YiboA") and E:GetEntryChannels("YiboA").builtinBar,"page hidden preserves intent")
Check(#E:GetBuiltinBarEntries()==2,"hidden page excluded")
s.pages.YiboAPage=true;E:Refresh()
E:UnregisterEntriesForPage("YiboAPage")
Check(not E:GetEntryAvailability("YiboA") and E.businessEntries.YiboA.broker.yiboCoreEntryDisabled,"unregister disables all channels")
local restored=E:RegisterBusinessEntry("YiboA",{id="YiboA",pageID="YiboAPage",text="A",defaultChannels={minimap=false,broker=false,builtinBar=false}})
Check(restored and E:GetEntryChannels("YiboA").builtinBar,"registration defaults do not override saved choices")
local alias=E:RegisterBusinessEntry("YiboA",{id="alias",pageID="YiboAPage",brokerName="Alias",text="Alias",legacyIDs={"legacy"}})
Check(alias and E:GetEntryChannels("alias").broker and s.entry.pagePositions.alias==137,"legacy aliases and positions")
local invalid=E:RegisterBusinessEntry("YiboA",{id="invalid",pageID="YiboAPage",defaultChannels={broker="yes"}})
Check(not invalid,"invalid channels rejected")
local copy=E:GetEntryChannels("YiboA");copy.broker=false
Check(E:GetEntryChannels("YiboA").broker,"returned channels are snapshots")
local target,settingsTarget
Core.AccountView.Toggle=function(_,id) target=id end
Core.AccountView.ShowSettings=function(_,id) settingsTarget=id end
E:HandleEntryClick("YiboA","LeftButton");Check(target=="YiboAPage","business left click")
E:HandleEntryClick("YiboA","RightButton");Check(settingsTarget=="display","right click display settings")
local widths={}
for i=1,150 do widths[i]=i%2==0 and 300 or 24 end
for _,width in ipairs({220,640,1600}) do
 local pages=Core.EntryBar:Layout(widths,24,6,width,240)
 local seen=0
 for _,page in ipairs(pages) do
  Check(page.width<=width and page.height+26<=240,"safe screen bounds")
  for _,item in ipairs(page.items) do seen=seen+1;Check(item.index==seen,"pagination has no skipped entries") end
 end
 Check(seen==150,"all entries reachable")
end
-- Same version loading twice must not replace an existing library/object.
local library=LibStub("LibDataBroker-1.1")
local existing=library:GetDataObjectByName("YiboCore")
dofile("YiboCore/Libs/LibStub/LibStub.lua")
dofile("YiboCore/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("YiboCore/Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
Check(library==LibStub("LibDataBroker-1.1") and existing==library:GetDataObjectByName("YiboCore"),"library/object coexistence")
print("EntryBarSpec passed: "..checks.." checks")
-- Exercise real settings controls, including disabled retained state at both languages and narrow widths.
dofile("YiboCore/Util/LevelFilter.lua")
dofile("YiboCore/UI/AccountPages/CharacterArchive.lua")
dofile("YiboCore/UI/AccountPages/Overview.lua")
dofile("YiboCore/Runtime/SettingsRegistry.lua")
dofile("YiboCore/UI/AccountPages/SettingsWorkbench.lua")
Core.Fields={GetByConsumer=function() return {} end}
Core.AccountView.settingsTargetPageID="display"
Core.AccountView._pageOrder={Core.AccountView._pages.YiboAPage,Core.AccountView._pages.YiboZPage}
local settingsPage=Core.AccountView._pages.settings
for _,language in ipairs({"zh","en"}) do
 Core.Locale.previewLanguage=language;Core.Locale:RefreshBindings()
 for _,width in ipairs({620,800,1200}) do
  for _,enabled in ipairs({false,true}) do
   E:SetBuiltinBarEnabled(enabled)
   local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(width,650)
   settingsPage.Create(parent);parent.scroll:SetSize(width-20,550);settingsPage.Refresh(parent)
   for _,row in ipairs(parent.rows) do
    if row.controlType=="core-entry" or row.controlType=="business-entry" then
     Check(#row.channels==3,"three independent channel controls")
     Check(row.channels[3]:IsEnabled()==enabled,"bar control follows master")
     Check(row.channels[1]:IsEnabled() and row.channels[2]:IsEnabled(),"other channels remain enabled")
     Check(row.channels[3]:GetChecked(),"disabled retains visible check")
     for _,control in ipairs(row.channels) do
      local x=control.points[1][2]
      Check(x+control:GetWidth()<=parent.content:GetWidth()+1,"channel group fits viewport")
     end
    end
   end
   local scroll=math.min(137,math.max(0,parent.settingsContentHeight-parent.scroll:GetHeight()));parent.scroll:SetVerticalScroll(scroll)
   settingsPage.Refresh(parent)
   Check(parent.scroll:GetVerticalScroll()==scroll,"refresh preserves scroll")
  end
 end
end
print("EntryBar settings checks total: "..checks)

E:SetBuiltinBarEnabled(false)
local late=E:RegisterBusinessEntry("YiboZ",{id="late",brokerName="Late",pageID="YiboZPage",defaultChannels={builtinBar=true}})
Check(late and E:GetEntryChannels("late").builtinBar and not Core.EntryBar.frame:IsShown(),"late registration preserves disabled master")
Check(not library:GetDataObjectByName("Late"),"builtin-only late entry does not publish broker")
E:UnregisterEntriesForPage("YiboZPage")
Check(E:GetEntryChannels("late").builtinBar and not E:GetBuiltinBarSettings().enabled,"disabled unregister preserves settings")
-- Loading older embedded versions leaves newer shared libraries untouched.
local oldMinor=LibStub.minors["LibDataBroker-1.1"]
LibStub.minors["LibDataBroker-1.1"]=99
dofile("YiboCore/Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
Check(LibStub.minors["LibDataBroker-1.1"]==99 and LibStub("LibDataBroker-1.1")==library,"newer LDB preserved")
LibStub.minors["LibDataBroker-1.1"]=oldMinor
print("EntryBarSpec final: "..checks.." checks")
-- Real preview scheduling/token and source ownership, with the account renderer isolated.
Core.AccountView._pages.YiboAPage.previewEnabled=true
s.entry.showPreviewWhileMainWindowOpen=true
local pending={}
C_Timer={After=function(_,fn) pending[#pending+1]=fn end}
local rendered={}
Core.AccountView.ShowPreview=function(self,id,anchor)
 rendered[#rendered+1]={id=id,anchor=anchor};self.frame.preview=true;return true
end
Core.AccountView.HidePreview=function(self) self.frame.preview=false end
Check(E:ShowEntryPreview("YiboA",E.businessEntries.YiboA.button,"builtinBar"),"builtin uses shared preview")
Check(E.previewOwner.source=="builtinBar" and rendered[#rendered].id=="YiboAPage","preview tracks source and page")
E:ShowEntryPreview("YiboA",E.businessEntries.YiboA.button,"broker")
E:SetBuiltinBarEnabled(false)
Check(E.previewOwner.source=="broker","latest external source survives bar close")
E:CloseEntryPreview("YiboA","broker")
local before=#rendered
for _,fn in ipairs(pending) do fn() end
Check(#rendered==before and E.previewOwner==nil,"closed preview cancels queued render")
Core.AccountView._pages.YiboAPage.previewEnabled=false
Check(not E:ShowEntryPreview("YiboA",nil,"builtinBar"),"unavailable preview rejected")
Check(E.previewOwner==nil,"rejected preview has no dangling owner")
local snapshot=E:GetBuiltinBarEntries()
snapshot[1].id="mutated"
Check(E:GetBuiltinBarEntries()[1].id=="YiboCore","bar list isolates registered metadata")
print("EntryBarSpec complete: "..checks.." checks")
-- Appearance and persistent ordering from the actual API/render path.
local M=getmetatable(UIParent).__index
M.SetBackdropColor=function(self,...) self.fill={...} end
M.SetBackdropBorderColor=function(self,...) self.borderColor={...} end
E:SetBuiltinBarEnabled(true)
Check(E:SetBuiltinBarOption("background","navy"),"background choice saved")
Check(E:SetBuiltinBarOption("backgroundAlpha",0.5),"opacity saved")
Check(E:SetBuiltinBarOption("showBorder",false),"border choice saved")
Check(Core.EntryBar.frame.fill[3]==0.14 and Core.EntryBar.frame.fill[4]==0.5,"background applied immediately")
Check(Core.EntryBar.frame.borderColor[4]==0,"border removed immediately")
Check(not E:SetBuiltinBarOption("background","invalid"),"unknown palette rejected")
Check(not E:SetBuiltinBarOption("backgroundAlpha","0.5"),"invalid opacity rejected")
E:SetBuiltinBarOption("backgroundAlpha",9)
Check(E:GetBuiltinBarSettings().backgroundAlpha==1,"opacity clamped")
E:SetBuiltinBarOption("backgroundAlpha",0)
Check(Core.EntryBar.frame.fill[4]==0,"transparent background supported")
E:SetBuiltinBarEnabled(false);E:SetBuiltinBarEnabled(true)
Check(E:GetBuiltinBarSettings().background=="navy" and not E:GetBuiltinBarSettings().showBorder,"style survives master switch")
local z=E:RegisterBusinessEntry("YiboZ",{id="YiboZ",pageID="YiboZPage",text="Z",defaultMode="none"})
E:ResetBuiltinBarOrder()
Check(E:GetBuiltinBarEntries()[1].id=="YiboCore","default Core first")
Check(E:MoveBuiltinBarEntry("YiboCore",1),"Core can be reordered")
Check(E:GetBuiltinBarEntries()[2].id=="YiboCore","custom Core position")
local order=E:GetBuiltinBarSettings().order
Core.EntryConfig:Normalize(s.entry)
Check(E:GetBuiltinBarSettings().order[1]==order[1],"order survives normalization")
s.pages.YiboAPage=false;E:Refresh()
Check(E:GetBuiltinBarEntries()[1].id=="YiboCore","hidden neighbor excluded")
s.pages.YiboAPage=true;E:Refresh()
Check(E:GetBuiltinBarEntries()[1].id=="YiboA","hidden neighbor restores order")
E:SetBuiltinBarEnabled(false)
Check(E:GetBuiltinBarSettings().order[1]=="YiboA","master switch retains order")
Check(not E:MoveBuiltinBarEntry("unknown",1) and not E:MoveBuiltinBarEntry("YiboA",-1),"invalid and boundary reorder rejected")
E:ResetBuiltinBarOrder()
Check(#E:GetBuiltinBarSettings().order==0 and E:GetBuiltinBarEntries()[1].id=="YiboCore","reset returns default")
local invalidStyle=Core.EntryConfig:Normalize({bar={background="unknown",backgroundAlpha=-4,showBorder=false,order={"x","x",false,"YiboCore"}}}).bar
Check(invalidStyle.background=="theme" and invalidStyle.backgroundAlpha==0 and not invalidStyle.showBorder,"invalid style normalized and explicit false retained")
Check(#invalidStyle.order==2,"saved order deduplicates IDs")
-- Inspect each tab and pagination at actual settings renderer widths.
for _,language in ipairs({"zh","en"}) do
 Core.Locale.previewLanguage=language;Core.Locale:RefreshBindings()
 for _,width in ipairs({620,800,1200}) do
  local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(width,650)
  settingsPage.Create(parent);parent.scroll:SetSize(width-20,550)
  for _,section in ipairs({"general","entries","bar"}) do
   Core.AccountView.settingsTargetPageID=section=="entries" and "display" or section
   parent.displaySection=section;settingsPage.Refresh(parent)
   Check(#parent.displayTabs==0,"settings pages have no nested tabs")
   for _,tab in ipairs(parent.displayTabs) do Check(tab:IsShown()==(section~="general"),"tabs only on display page") end
   Check(parent.settingsContentHeight<=550,"focused tab fits safe viewport")
   for _,row in ipairs(parent.rows) do
    if row:IsShown() then
     if row.controlType=="dropdown" then
      local rightPoint=row.dropdown.points[#row.dropdown.points]
      Check(row.dropdown:GetWidth()<=row:GetWidth(),"dropdown bounded by semantic row")
      if section=="bar" then
       Check(not row.dropdown:IsEnabled(),"all bar dropdowns disabled with master off")
      end
     elseif row.controlType=="business-entry" and #Core.AccountView._pages.YiboAPage.fields==0 then
      Check(row:GetHeight()<=76,"empty field area does not consume a row")
     end
    end
   end
  end
 end
end
Core.Locale.previewLanguage=nil;Core.Locale:RefreshBindings()
Core.AccountView.settingsTargetPageID="display"
-- All registered plugins occupy a single compact row in one scrollable list.
local originalPages=Core.AccountView._pageOrder
Core.AccountView._pageOrder={}
for i=14,1,-1 do
 local id=string.format("YiboFixture%02d",i)
 Core.AccountView._pageOrder[#Core.AccountView._pageOrder+1]={id=id,addonName=id,title=id,fields={}}
end
for _,width in ipairs({620,1200}) do
 local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(width,650)
 settingsPage.Create(parent);parent.scroll:SetSize(width-20,550);settingsPage.Refresh(parent)
 local seen,last,count={},"",0
 for _,row in ipairs(parent.rows) do
  if row:IsShown() and row.controlType=="business-entry" then
   local id=row.title:GetText();count=count+1
   Check(not seen[id] and id>last,"complete list is unique and technically sorted")
   Check(row:GetHeight()==30,"each business occupies one row")
   seen[id]=true;last=id
  end
 end
 Check(count==14,"all plugins present without pagination")
 Check(parent.settingsContentHeight>550,"long list uses vertical scrolling")
end
Core.AccountView._pageOrder=originalPages
-- Settings-only addons participate in discovery without fictitious controls.
Core.Registry._addons.YiboSettingsFixture={name="YiboSettingsFixture"}
Check(Core:RegisterSettingsPanel("YiboSettingsFixture",{id="settings-fixture",title="SettingsFixture",CreateSettingsPanel=function() end})~=nil,"settings-only registration")
local host=CreateFrame("Frame",nil,UIParent);host:SetSize(1200,650)
settingsPage.Create(host);host.scroll:SetSize(1180,550);host.displaySection="entries"
settingsPage.Refresh(host)
local found=false
for _,row in ipairs(host.rows) do
 if row:IsShown() and row.controlType=="business-entry" and row.title:GetText()=="SettingsFixture" then
  found=true;Check(not row.visible:IsShown(),"settings-only addon has no page toggle")
  Check(row.entryLabel:GetText()==Core:Text("ENTRY.SETTINGS_ONLY"),"settings-only explanation")
 end
end
Check(found,"settings-only addon included in entry list")
Core:UnregisterSettingsPanel("settings-fixture","YiboSettingsFixture")
Check(Core.AccountView:SelectSettingsTarget("bar"),"standalone bar navigation accepted")
Check(Core.AccountView:SelectSettingsTarget("general"),"standalone general navigation accepted")
settingsPage.Refresh(host)
for _,tab in ipairs(host.displayTabs) do Check(not tab:IsShown(),"general has no nested display tabs") end
Core.AccountView.settingsTargetPageID="display";host.displaySection="entries";settingsPage.Refresh(host)
for _,row in ipairs(host.rows) do
 if row:IsShown() and row.controlType=="business-entry" then
  for _,control in ipairs({row.mainFields,row.previewFields}) do
   if control:IsShown() then
    local point=control.points[1];local top=-(point[#point] or 0)
    Check(top+control:GetHeight()<=row:GetHeight(),"field controls fit row height")
   end
  end
 end
end
-- Drag the actual icon controls, including click suppression and cancellation.
E:SetBuiltinBarEnabled(true);E:ResetBuiltinBarOrder()
M.IsMouseOver=function(self) return self.testHover==true end
local source,target=Core.EntryBar.buttons[1],Core.EntryBar.buttons[2]
local sourceID,targetID=source.entryID,target.entryID
source.scripts.OnMouseDown(source)
source.scripts.OnDragStart(source)
Check(Core.EntryBar.draggedID==sourceID,"drag captures stable entry ID")
target.testHover=true;source.scripts.OnDragStop(source);target.testHover=nil
Check(E:GetBuiltinBarEntries()[2].id==sourceID,"drop moves icon to target position")
Check(Core.EntryBar.draggedID==nil,"drop clears drag state")
local originalClick,calls=E.HandleEntryClick,0
E.HandleEntryClick=function() calls=calls+1 end
source.scripts.OnClick(source,"LeftButton")
Check(calls==0,"drag release cannot open page")
source.scripts.OnMouseDown(source);source.scripts.OnClick(source,"LeftButton")
Check(calls==1,"next deliberate click works")
E.HandleEntryClick=originalClick
local before=E:GetBuiltinBarEntries()[1].id
source.scripts.OnDragStart(source);source.scripts.OnDragStop(source)
Check(E:GetBuiltinBarEntries()[1].id==before,"drop outside cancels ordering")
Check(not E:ReorderBuiltinBarEntry("unknown",targetID),"unknown drag source rejected")
E:ResetBuiltinBarOrder()
for _,entry in ipairs(E:GetBuiltinBarEntries()) do
 Check(not entry.text:find("[Yibo]",1,true),"bar label excludes author prefix")
end
local page=Core.AccountView._pages.YiboAPage
local oldTitle=page.title;page.title="[Yibo] YiboExample - Unified label"
for _,entry in ipairs(E:GetBuiltinBarEntries()) do
 if entry.id=="YiboA" then Check(entry.text=="Unified label","registered page title normalized without addon-specific branch") end
end
page.title=oldTitle
print("Entry bar appearance/layout final: "..checks.." checks")
