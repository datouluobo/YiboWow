local BootCore=dofile("_NonRelease/CoreForever/Harness.lua")
local checks=0
local function Check(value,label) checks=checks+1; assert(value,label) end
local function Boot(saved,configure,defaultManifest,language)
    local e,c,fire,_,load=BootCore(true,language and language.savedCore)
    if language then e.GetLocale=function() return language.client end end
    e.TEST_GUID="Player-Test-1"; e.GetServerTime=function() return 200000 end; e.IsLoggedIn=function() return true end
    local d={shown=false,ready=true,reads=0,professionID=197,sourceCounter=1,rows={1001,1002},info={
        [1001]={recipeID=1001,name="Linen Tunic",learned=true},[1002]={recipeID=1002,name="Wool Tunic",learned=false}}}
    e.GetProfessions=function() if d.emptyProfile then return end; if d.profileFailure then error("not ready") end; return 1,nil,3,nil,nil,nil,7 end
    e.GetProfessionInfo=function(index)
        if d.profileBad then return "Unready",1,nil,nil,nil,nil,nil end
        local id=index==1 and 197 or (index==3 and 129 or 9123)
        return "Profession"..id,1,30,75,nil,nil,id
    end
    e.issecretvalue=function(value) return d.secret and value=="Linen Tunic" end
    e.ProfessionsFrame={IsShown=function() return d.shown end}
    e.C_TradeSkillUI={IsTradeSkillReady=function() return d.ready end,IsTradeSkillLinked=function() return d.linked==true end,
        IsTradeSkillGuild=function() return d.guild==true end,IsTradeSkillGuildMember=function() return d.member==true end,IsNPCCrafting=function() return d.npc==true end,
        GetBaseProfessionInfo=function() return {professionID=d.professionID,sourceCounter=d.sourceCounter} end,
        GetAllRecipeIDs=function() assert(d.shown,"closed profession API read"); d.reads=d.reads+1; if d.fail then error("read error") end; return d.rows end,
        GetRecipeInfo=function(id)
            local info=d.info[id]; if d.nilInfo then return end
            if info and d.changing then info=c.Defaults:Copy(info); info.learned=d.reads%2==0 end
            return info
        end,
        GetProfessionInfoByRecipeID=function(id) return {professionID=d.crossProfession and 171 or d.professionID} end}
    for _,action in ipairs({"CraftRecipe","CraftEnchant","SetRecipeItemNameFilter","SetOnlyShowLearnedRecipes","SetTradeSkillCategoryFilter","OpenTradeSkill","CloseTradeSkill"}) do
        e.C_TradeSkillUI[action]=function() error("unexpected profession action "..action) end
    end
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN")
    e.YiboCraftingDB={sentinel="mists"}; e.YiboCraftingForeverDB=saved
    if configure then configure(e,c,d) end
    for line in io.lines("YiboCrafting/"..(defaultManifest and "YiboCrafting.toc" or "YiboCrafting_Forever.toc")) do
        line=line:gsub("\r",""); if line:match("%.lua$") then load("YiboCrafting/"..line:gsub("\\","/"),"YiboCrafting") end
    end
    fire("ADDON_LOADED","YiboCrafting")
    local function Flush()
        for i=1,20 do if #e.TEST_TIMERS==0 then return end; local timers=e.TEST_TIMERS; e.TEST_TIMERS={}; for _,timer in ipairs(timers) do timer[2]() end end
        error("timer loop")
    end
    if defaultManifest then fire("PLAYER_LOGIN") end
    return e,c,e.YiboCrafting,fire,Flush,d
end
local e,c,a,fire,flush,d=Boot()
Check(a.initialized and a.VERSION=="0.1.2" and c.VERSION=="0.2.0","Crafting and Core target manifests start")
Check(e.YiboCraftingDB.sentinel=="mists" and not e.YiboCraftingDB.characters,"Mists store untouched")
Check(not a.RecipeCatalog and not a.GoalTargets and not a.RecipeStateScanner,"MoP catalog and spell assumptions excluded")
fire("PLAYER_ENTERING_WORLD"); flush()
local profile=c.DataDomains:Get(e.TEST_GUID,"professions")
Check(profile.state=="known" and #profile.data.professions==3 and profile.data.professions[3].id==9123,"Core captures seventh slot and stable skill-line IDs")
Check(profile.data.professions[2].id==129 and profile.data.skillLineIDsAuthoritative,"secondary identity does not assume MoP slot semantics")
local fields=c.Fields:GetByConsumer("character-archive")
local byID={}; for _,field in ipairs(fields) do byID[field.id]=field end
Check(byID["character.first-aid"].Read(nil,profile.data).id==129 and byID["character.archaeology"].Read(nil,profile.data)==nil,"Core archive fields use IDs rather than secondary positions")
Check(byID["character.profession-secondary"].Read(nil,profile.data)==nil,"missing second primary cannot borrow a secondary profession")
profile.data.professions[1].skillLevel=999
Check(c.DataDomains:Get(e.TEST_GUID,"professions").data.professions[1].skillLevel==30,"Core profile value copy")
e.SlashCmdList.YIBOCRAFTING(""); flush(); local panel=c.AccountView.frame.instances.crafting
Check(#panel.renderedRecipes==0 and panel.professions:GetText():match("Profession197"),"profession skill profile shown before recipes")
Check(d.reads==0,"no recipes queried before own window")
d.shown=true; fire("TRADE_SKILL_SHOW"); flush()
local saved=a.Store:Get(e.TEST_GUID)
Check(saved.professions[197].recipes[1001].learned and not saved.professions[197].recipes[1002].learned,"explicit learned and unlearned facts committed")
Check(#panel.renderedRecipes==2 and panel.rows[1].labels.recipe:GetText()=="Linen Tunic","recipe names rendered")
Check(panel.rows[2].labels.learned:GetText()==a:T("FOREVER.NOT_LEARNED"),"unlearned UI text")
saved.professions[197].recipes[1001].name="tampered"
Check(a.Store:Get(e.TEST_GUID).professions[197].recipes[1001].name=="Linen Tunic","Crafting snapshot detached")
Check(not a.Store:Get("Other"),"current GUID scope only")
local before=d.reads; for i=1,20 do fire("TRADE_SKILL_LIST_UPDATE") end; flush()
Check(d.reads-before==2,"recipe event burst coalesced")
d.info[1002].learned=true; fire("NEW_RECIPE_LEARNED"); flush()
Check(a.Store:Get(e.TEST_GUID).professions[197].recipes[1002].learned,"learning change committed")
d.rows={1001}; fire("TRADE_SKILL_LIST_UPDATE"); flush()
Check(a.Store:Get(e.TEST_GUID).professions[197].recipes[1002].learned and not a.Store:IsFresh(e.TEST_GUID,197,1002),"filter omissions retain historical learned fact")
for _,flag in ipairs({"linked","guild","member","npc"}) do d[flag]=true; before=d.reads; a.Scanner:Scan(); Check(d.reads==before and a.Scanner.state=="external","foreign profession rejected before recipes: "..flag); d[flag]=nil end
d.ready=false; before=d.reads; a.Scanner:Scan(); Check(d.reads==before and a.Scanner.state=="pending","unready source does not read or clear"); d.ready=true
for _,flag in ipairs({"fail","nilInfo","changing","crossProfession","secret"}) do
    d[flag]=true; a.Scanner:Scan(); Check(a.Store:Get(e.TEST_GUID).professions[197].recipes[1002].learned,"failed batch preserves prior facts: "..flag); d[flag]=nil
end
d.rows={}; a.Scanner:Scan(); Check(a.Scanner.state=="pending" and a.Store:Get(e.TEST_GUID).professions[197].recipes[1001],"empty list does not erase recipes")
d.rows={1001,1001}; a.Scanner:Scan(); Check(a.Scanner.state=="error","duplicate recipe IDs rejected")
d.rows={1001}; d.info[1001].learned=nil; a.Scanner:Scan(); Check(a.Scanner.state=="error","unknown learning state not treated as false"); d.info[1001].learned=true
d.professionID=171; before=d.reads; a.Scanner:Scan(); Check(d.reads==before and a.Scanner.state=="profile","unowned profession rejected"); d.professionID=197
a.Scanner:Scan(); c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("crafting",e.Minimap),"Core owns preview")
Check(#panel.renderedRecipes==2 and not panel.refresh:IsShown(),"preview reuses saved recipe rows")
c.AccountView:HidePreview(); c.AccountView:Toggle("crafting")
d.shown=false; fire("TRADE_SKILL_CLOSE"); flush()
Check(not a.Store:IsFresh(e.TEST_GUID,197,1001) and #panel.renderedRecipes==2,"close retains stale snapshot")
local disk=c.Defaults:Copy(e.YiboCraftingForeverDB)
local e2,c2,a2,f2,fl2,d2=Boot(disk)
f2("PLAYER_ENTERING_WORLD"); fl2(); e2.SlashCmdList.YIBOCRAFTING(""); fl2()
Check(#c2.AccountView.frame.instances.crafting.renderedRecipes==2 and not a2.Store:IsFresh(e2.TEST_GUID,197,1001),"saved recipes restored as historical snapshot")
d2.profileFailure=true; f2("SKILL_LINES_CHANGED"); fl2()
local staleProfile=c2.DataDomains:Get(e2.TEST_GUID,"professions")
Check(staleProfile.state~="known" and staleProfile.data.professions[1].id==197,"failed Core read preserves previous profile with non-known state")
d2.profileFailure=nil; f2("SKILL_LINES_CHANGED"); fl2()
d2.shown=true; f2("TRADE_SKILL_SHOW"); a2.Store:Delete({id=e2.TEST_GUID}); fl2()
Check(not a2.Store:Get(e2.TEST_GUID),"cleanup cancels queued recipe scan")
f2("TRADE_SKILL_LIST_UPDATE"); fl2(); a2.Store:Delete({id=e2.TEST_GUID},{replay=true,deletedAt=199999})
Check(a2.Store:Get(e2.TEST_GUID).professions[197].recipes[1001],"cleanup replay preserves newer observations")
d2.emptyProfile=true; f2("SKILL_LINES_CHANGED"); fl2()
Check(#c2.DataDomains:Get(e2.TEST_GUID,"professions").data.professions==0,"explicit skill event can confirm no professions")
e2.SlashCmdList.YIBOCRAFTING(""); fl2()
Check(not a2:OwnsProfession(197),"removed profession cannot authorize recipe scan")
for _,cap in ipairs({"profession-profile","data-domains","localization","account-surface-budget","character-cleanup"}) do
    local env,_,addon=Boot(nil,function(_,core) local old=core.HasCapability; core.HasCapability=function(self,name,version) return name~=cap and old(self,name,version) end end)
    Check(not addon.initialized and env.YiboCraftingForeverDB==nil,"required capability checked before DB: "..cap)
end
for _,mutate in ipairs({function(db) db.schema=2 end,function(db) db.clientScope.projectID=19 end,function(db) db.characters["Bad"]={professions={[197]={}}} end}) do
    local bad=c.Defaults:Copy(disk); mutate(bad); local _,_,addon=Boot(bad); Check(not addon.initialized,"incompatible saved schema/scope rejected")
end
local de,_,da=Boot(nil,nil,true)
Check(not da.initialized and not de.YiboCraftingDB.characters,"forced default manifest cannot write on Forever")
for _,case in ipairs({{"zhCN","auto","zh"},{"enUS","auto","en"},{"zhCN","en","en"},{"enUS","zh","zh"}}) do
    local coreSave=c.Defaults:Copy(c.Database:GetDB()); coreSave.settings.language=case[2]
    local env,core,addon,native,drain,data=Boot(nil,nil,nil,{client=case[1],savedCore=coreSave})
    native("PLAYER_ENTERING_WORLD"); data.shown=true; native("TRADE_SKILL_SHOW"); drain(); env.SlashCmdList.YIBOCRAFTING(""); drain()
    local page=core.AccountView.frame.instances.crafting
    Check(core.Locale:GetLanguage()==case[3] and page.rows[1].labels.learned:GetText()==addon:T("UI.LEARNED"),"four session language modes")
    Check(#core.Locale:GetMissingEnglish("YiboCrafting")==0,"Crafting target resources complete")
end
Check(#e.TEST_MESSAGES==0,"no hidden callbacks: "..table.concat(e.TEST_MESSAGES," | "))
local ve,vc,va,vf,vd,vdata=Boot()
vf("PLAYER_ENTERING_WORLD"); vdata.shown=true; vf("TRADE_SKILL_SHOW"); vd(); ve.SlashCmdList.YIBOCRAFTING(""); vd()
local vp=vc.AccountView.frame.instances.crafting
local many={}; for id=10000,13000 do many[id]={recipeID=id,name="Recipe"..id,learned=true,observedAt=200000} end
Check(va.Store:Commit(ve.TEST_GUID,197,many,200000),"large observed set commits")
vd(); Check(#vp.renderedRecipes==3003 and #vp.rows<100,"large recipe lists reuse only viewport rows")
vp.scroll:SetVerticalScroll(9000)
Check(vp.rows[1].labels.recipe:GetText()==vp.renderedRecipes[301].recipe.name,"scrolling projects correct recipe slice")
va.AccountPage:Refresh(vp,{characters={},fields=va.AccountPage:Fields()})
Check(#vp.renderedRecipes==0,"Core character exclusion respected")
local coreSaved=vc.Defaults:Copy(vc.Database:GetDB())
local re,rc,rf=BootCore(true,coreSaved); re.TEST_GUID="Player-Test-1"; re.GetProfessions=function() return 1 end
re.GetProfessionInfo=function() error("temporary") end; rf("ADDON_LOADED"); rf("PLAYER_LOGIN"); rf("PLAYER_ENTERING_WORLD")
Check(rc.DataDomains:Get(re.TEST_GUID,"professions").state~="known" and rc.DataDomains:Get(re.TEST_GUID,"professions").data.professions[1].id==197,"Core profile restored and retained on failed native read")
local se,sc,sfire,_,sload=BootCore(false); sfire("ADDON_LOADED"); sfire("PLAYER_LOGIN")
local legacyFields={}; for _,field in ipairs(sc.Fields:GetByConsumer("character-archive")) do legacyFields[field.id]=field end
local legacy={professions={{slot=3,name="Legacy profession"}}}
Check(legacyFields["character.archaeology"].Read(nil,legacy).name=="Legacy profession","Mists secondary-slot fallback remains compatible")
local me,mc,ma,mf,md=Boot(nil,function(env) env.GetProfessionInfo=nil end)
mf("PLAYER_ENTERING_WORLD"); md()
Check(mc.DataDomains:Get(me.TEST_GUID,"professions").state=="unavailable","missing profile API is not known empty")
local le,lc,la=Boot(nil,function(_,core) core._testInitialized=core.IsInitialized; core.IsInitialized=function() return false end end)
Check(not la.initialized and le.YiboCraftingForeverDB==nil,"Core not ready does not create business store")
lc.IsInitialized=lc._testInitialized; lc.Events:Fire("CORE_READY"); Check(la.initialized and la:Initialize(),"late Core readiness and idempotent initialization")
local we,_,wa=Boot(nil,function(env) env.WOW_PROJECT_ID=19 end)
Check(not wa.initialized and we.YiboCraftingForeverDB==nil,"wrong client rejected before store")
local de,dc,da,df,dflush,dd=Boot()
df("PLAYER_ENTERING_WORLD"); dd.shown=true; df("TRADE_SKILL_SHOW"); dflush()
dd.info[1001].learned=nil; da.Scanner:Scan()
Check(da.Scanner:ReportText():match("detail=recipe_fields:1001"),"diagnostic identifies malformed recipe fields")
dd.info[1001].learned=true; de.C_TradeSkillUI.GetProfessionInfoByRecipeID=nil; da.Scanner:Scan()
local diagnostic=da.Scanner:ReportText()
Check(diagnostic:match("detail=recipe_profession:1001 expected=197") and diagnostic:match("GetProfessionInfoByRecipeID=nil"),"missing API explicitly inventoried with failing recipe")
Check(da.Store:Get(de.TEST_GUID).professions[197].recipes[1001].learned,"diagnostic failure retains existing snapshot")
de.C_TradeSkillUI.GetProfessionInfoByRecipeID=function() return {professionID=171} end
da.Scanner:Scan(); Check(da.Scanner:ReportText():match('professionID"=171'),"foreign profession raw metadata captured")
dd.secret=true; da.Scanner:Scan(); Check(not da.Scanner:ReportText():match("Linen Tunic") and da.Scanner:ReportText():match("<restricted>"),"report redacts restricted values before formatting")
dd.secret=nil; de.C_TradeSkillUI.GetProfessionInfoByRecipeID=function() return {professionID=197} end
de.SlashCmdList.YIBOCRAFTING("report")
Check(da.Scanner.reportWindow:IsShown() and da.Scanner.reportWindow.edit:GetText()==da.Scanner:ReportText(),"slash report opens selectable current diagnostics")
local reportWindow=da.Scanner.reportWindow; de.SlashCmdList.YIBOCRAFTING("report")
Check(da.Scanner.reportWindow==reportWindow and #da.Scanner.trace<=24,"report reuses window with bounded session trace")
local xe,xc,xa,xf,xflush,xd=Boot(nil,function(env,_,data)
    data.professionID=2945
    env.GetProfessionInfo=function(index) return "Profession",1,33,75,nil,nil,index==1 and 165 or (index==3 and 129 or 9123) end
    env.C_TradeSkillUI.GetBaseProfessionInfo=function() return {professionID=2945,parentProfessionID=165,sourceCounter=data.sourceCounter} end
    env.C_TradeSkillUI.GetProfessionInfoByRecipeID=function(id)
        return {professionID=id==461692 and 2948 or 2945,parentProfessionID=id==461692 and 197 or 165}
    end
    data.info[461692]={recipeID=461692,name="Shared recipe",learned=false}
    data.rows={1001,461692,1002}; data.membershipCalls={}
    env.C_TradeSkillUI.IsRecipeInSkillLine=function(id,skillLine)
        assert(id==461692 and (skillLine==2945 or skillLine==165),"membership uses actual recipe and open skill line")
        data.membershipCalls[#data.membershipCalls+1]=skillLine
        if data.membershipError then error("membership unavailable") end
        if data.membershipInvalid then return "unknown" end
        if data.membershipChanging then return data.reads%2==0 end
        return skillLine==(data.sharedAt or 0)
    end
end)
xf("PLAYER_ENTERING_WORLD"); xd.shown=true; xf("TRADE_SKILL_SHOW"); xflush()
assert(xa.Store:Get(xe.TEST_GUID),xa.Scanner:ReportText())
local xr=xa.Store:Get(xe.TEST_GUID).professions[165].recipes
Check(xr[1001] and xr[1002] and not xr[461692],"explicit foreign recipe no longer aborts valid leatherworking observations")
Check(not xa.Store:Get(xe.TEST_GUID).professions[197],"foreign metadata never creates tailoring snapshot")
Check(#xd.membershipCalls==4 and xd.membershipCalls[1]==2945 and xd.membershipCalls[2]==165,"both scan passes validate child and parent membership")
xd.sharedAt=2945; Check(xa.Scanner:Scan() and xa.Store:IsFresh(xe.TEST_GUID,165,461692),"shared recipe confirmed in child line belongs to open profession")
Check(xa.Scanner:ReportText():match("arg=461692,2945"),"diagnostics retain both membership arguments")
xd.sharedAt=165; Check(xa.Scanner:Scan() and xa.Store:IsFresh(xe.TEST_GUID,165,461692),"shared recipe confirmed in parent line accepted")
for _,flag in ipairs({"membershipError","membershipInvalid","membershipChanging"}) do
    xd[flag]=true; Check(not xa.Scanner:Scan(),"uncertain membership aborts atomic batch: "..flag)
    Check(xa.Store:Get(xe.TEST_GUID).professions[165].recipes[461692]~=nil,"uncertain membership preserves previous shared facts: "..flag)
    xd[flag]=nil
end
local membership=xe.C_TradeSkillUI.IsRecipeInSkillLine
xe.C_TradeSkillUI.IsRecipeInSkillLine=nil
Check(not xa.Scanner:Scan() and xa.Scanner:ReportText():match("detail=recipe_membership:461692"),"missing membership API fails with precise diagnostic")
xe.C_TradeSkillUI.IsRecipeInSkillLine=function() return "restricted membership" end
local secret=xe.issecretvalue
xe.issecretvalue=function(value) return value=="restricted membership" end
Check(not xa.Scanner:Scan() and not xa.Scanner:ReportText():match("restricted membership"),"restricted membership is not consumed or exposed")
xe.issecretvalue=secret; xe.C_TradeSkillUI.IsRecipeInSkillLine=membership
xd.sharedAt=nil; xd.rows={461692}
Check(not xa.Scanner:Scan() and xa.Scanner.state=="pending","all foreign rows cannot overwrite snapshot as known empty")
Check(xa.Store:Get(xe.TEST_GUID).professions[165].recipes[1001]~=nil,"all foreign rows preserve historical observations")
print("CraftingForever Smoke passed: "..checks.." checks (actual Core/Crafting manifests; simulated client/UI)")
