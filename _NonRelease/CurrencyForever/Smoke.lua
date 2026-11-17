local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Boot(saved, configure, manifest, localeCase)
    local e, core, fire, _, load = BootCore(true, localeCase and localeCase.savedCore)
    if localeCase then e.GetLocale = function() return localeCase.client end end
    e.TEST_GUID = "Player-Test-1"
    e.GetServerTime = function() return 200000 end
    e.IsLoggedIn = function() return true end
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN")
    local data = { money = 123456, reads = 0 }
    e.GetMoney = function()
        data.reads = data.reads + 1
        if data.fail then error("unavailable") end
        if data.change then return data.money + data.reads end
        return data.money
    end
    e.issecretvalue = function(v) return data.secret and v == data.money end
    e.YiboCurrencyDB = { sentinel = "mists" }; e.YiboCurrencyForeverDB = saved
    if configure then configure(e, core, data) end
    for line in io.lines("YiboCurrency/" .. (manifest or "YiboCurrency_Forever.toc")) do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then load("YiboCurrency/" .. line:gsub("\\", "/"), "YiboCurrency") end
    end
    fire("ADDON_LOADED", "YiboCurrency")
    local function Flush()
        for i = 1, 15 do
            if #e.TEST_TIMERS == 0 then return end
            local pending = e.TEST_TIMERS; e.TEST_TIMERS = {}
            for _, timer in ipairs(pending) do timer[2]() end
        end
        error("timer loop")
    end
    return e, core, e.YiboCurrency, fire, Flush, data
end
local e,c,a,fire,flush,d = Boot()
Check(a.initialized and a.VERSION == "0.1.9", "Forever manifest starts")
Check(e.YiboCurrencyDB.sentinel == "mists" and not e.YiboCurrencyDB.settings, "Mists store untouched")
Check(not a.Migration and not a.VaultIntegration and not a.GoalTargets
    and #a.Catalog == 1 and a.Catalog[1].id == "money", "Forever catalog contains only confirmed money")
Check(not a.Store:Get(e.TEST_GUID) and not a.Scanner:Scan(true) and d.reads == 0, "no scans before world entry")
e.SlashCmdList.YCU(""); flush()
local panel = c.AccountView.frame.instances.currency
Check(c.AccountView.activePageID == "currency" and panel.balance:GetText() == a:T("FOREVER.NO_BALANCE"), "unknown displayed rather than zero")
Check(panel.sessionChange:GetText() == a:T("FOREVER.SESSION_UNAVAILABLE"), "unknown session is not reported as zero")
fire("PLAYER_ENTERING_WORLD"); flush()
local row,state = a.Store:Get(e.TEST_GUID)
Check(row.moneyCopper == 123456 and state == "known", "positive money read and committed")
Check(panel.sessionChange:GetText() == a:T("FOREVER.SESSION_UNCHANGED"), "first verified observation sets session baseline")
local balanceText=panel.balance:GetText()
Check(balanceText:match("12 .*UI%-GoldIcon") and balanceText:match("34 .*UI%-SilverIcon")
    and balanceText:match("56 .*UI%-CopperIcon"), "exact gold silver copper with coin icons")
a.AccountPage:Refresh(panel,{characters={},fields=a.AccountPage:Fields()})
Check(not panel.renderedSnapshot and panel.balance:GetText() == a:T("FOREVER.NO_BALANCE"), "Core character exclusion respected")
c.AccountView:NotifyPageChanged("currency"); flush()
Check(panel.refresh.label:GetText() == a:T("FOREVER.REFRESH"), "Core button label")
row.moneyCopper = 999
Check(a.Store:Get(e.TEST_GUID).moneyCopper == 123456, "detached public snapshot")
Check(not a.Store:Get("Other"), "other characters excluded")
local before = d.reads
for i=1,20 do fire("PLAYER_MONEY") end
flush(); Check(d.reads - before == 2, "money burst coalesced")
d.money = 654321; fire("PLAYER_MONEY"); flush()
Check(a.Store:Get(e.TEST_GUID).moneyCopper == 654321, "money changes update")
Check(panel.sessionChange:GetText():match("^%+53 .*UI%-GoldIcon"), "positive session net uses exact signed denomination")
for _, flag in ipairs({ "fail", "change", "secret" }) do
    d[flag] = true; e.SlashCmdList.YCU("scan")
    row,state = a.Store:Get(e.TEST_GUID)
    Check(row.moneyCopper == 654321 and state == "error", "error preserves previous snapshot: " .. flag)
    d[flag] = false
end
for _, value in ipairs({ -1, 0/0, math.huge, 1.5, 9007199254740992 }) do
    d.money = value; a.Scanner:Scan(true)
    Check(a.Store:Get(e.TEST_GUID).moneyCopper == 654321, "invalid money rejected")
end
d.money = 0; fire("PLAYER_ENTERING_WORLD"); flush()
row,state = a.Store:Get(e.TEST_GUID)
Check(row.moneyCopper == 654321 and state == "stale", "entry zero not certified by delay")
e.SlashCmdList.YCU("scan")
Check(a.Store:Get(e.TEST_GUID).moneyCopper == 0 and select(2,a.Store:Get(e.TEST_GUID)) == "known", "manual true zero committed")
flush()
Check(panel.sessionChange:GetText():match("^−12 .*UI%-GoldIcon"), "session net includes spending down to zero")
fire("PLAYER_LEAVING_WORLD"); flush()
before = d.reads; fire("PLAYER_MONEY"); flush()
Check(d.reads == before and select(2,a.Store:Get(e.TEST_GUID)) == "stale", "outside world never reads; prior snapshot stale")
fire("PLAYER_ENTERING_WORLD"); flush(); fire("PLAYER_MONEY"); flush()
Check(select(2,a.Store:Get(e.TEST_GUID)) == "known", "native event confirms zero")
Check(panel.sessionChange:GetText():match("^−12 .*UI%-GoldIcon"), "world transition preserves the session baseline")
c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("currency", e.Minimap), "Core preview opens")
Check(panel.matrixRows[1].cells[e.TEST_GUID].count:GetText()==a.AccountPage:Format(0) and not panel.refresh:IsShown() and not panel.sessionChange:IsShown(), "same balance snapshot in preview without session details")
local archiveFields = c.Fields:GetByConsumer("character-archive")
local goldField
for _, field in ipairs(archiveFields) do if field.id == "character.money" then goldField = field end end
local goldValue, goldState = c.ArchiveFields:GetCell(c.Characters:GetCurrent(),goldField)
Check(goldValue==0 and goldState=="known" and goldField.defaultPreviewVisible,"Core archive resolves confirmed zero through Currency provider")
c.AccountView:HidePreview(); c.AccountView:Toggle("currency")
local saved = c.Defaults:Copy(e.YiboCurrencyForeverDB)
local e2,c2,a2,f2,fl2,d2 = Boot(saved)
row,state = a2.Store:Get(e2.TEST_GUID)
Check(row.moneyCopper == 0 and state == "stale", "save restored as stale until new observation")
e2.SlashCmdList.YCU(""); fl2()
Check(c2.AccountView.frame.instances.currency.balance:GetText():match("^0 .*UI%-GoldIcon"), "restored zero balance displayed")
local panel2=c2.AccountView.frame.instances.currency
Check(panel2.sessionChange:GetText() == a2:T("FOREVER.SESSION_UNAVAILABLE") and saved.sessionStart == nil,
    "historical balance restores without inventing a session baseline")
e2.TEST_GUID = nil; f2("PLAYER_ENTERING_WORLD"); fl2()
Check(d2.reads == 0, "missing GUID prevents save")
e2.TEST_GUID = "Player-Test-1"; f2("BAG_UPDATE_DELAYED"); fl2()
Check(a2.Store:Get(e2.TEST_GUID).moneyCopper == 123456, "late identity recovered")
Check(panel2.sessionChange:GetText() == a2:T("FOREVER.SESSION_UNCHANGED"), "new session starts at its own first verified balance")
d2.money = 7; f2("PLAYER_MONEY")
a2.Store:Delete({id=e2.TEST_GUID}); fl2()
Check(not a2.Store:Get(e2.TEST_GUID), "cleanup cancels queued scan and removes cache")
f2("PLAYER_MONEY"); fl2()
Check(a2.Store:Get(e2.TEST_GUID).moneyCopper == 7, "subsequent native fact can repopulate")
Check(panel2.sessionChange:GetText() == a2:T("FOREVER.SESSION_UNCHANGED"), "cleanup also resets the active character baseline")
a2.Store:Delete({id=e2.TEST_GUID},{replay=true,deletedAt=199999})
Check(a2.Store:Get(e2.TEST_GUID).moneyCopper == 7, "cleanup replay preserves newer local observation")
d2.money = 5; f2("PLAYER_MONEY"); fl2()
Check(panel2.sessionChange:GetText():match("^−0 "), "negative copper change remains visible")
f2("PLAYER_LOGOUT"); fl2()
Check(panel2.sessionChange:GetText() == a2:T("FOREVER.SESSION_UNAVAILABLE"), "logout discards the session baseline")
for _, mutate in ipairs({
    function(db) db.schema = 2 end,
    function(db) db.clientScope.projectID = 19 end,
    function(db) db.clientScope.scope = "account" end,
    function(db) db.characters["Other"] = {moneyCopper=-1,observedAt=1} end,
    function(db) db.settings.previewColumns = false end,
}) do
    local bad = c.Defaults:Copy(saved); mutate(bad)
    local _,_,addon = Boot(bad)
    Check(not addon.initialized and not addon.Store.db, "invalid schema/scope stays untouched")
end
for _, cap in ipairs({ "localization", "character-name-format", "account-surface-budget", "character-cleanup" }) do
    local env,_,addon = Boot(nil,function(_,core)
        local original = core.HasCapability
        core.HasCapability = function(self,name,minimum) if name == cap then return false end; return original(self,name,minimum) end
    end)
    Check(not addon.initialized and env.YiboCurrencyForeverDB == nil, "missing Core capability stops before DB: " .. cap)
end
local badEnv,_,bad = Boot(nil, function(env) env.WOW_PROJECT_ID = 19 end)
Check(not bad.initialized and badEnv.YiboCurrencyForeverDB == nil and not badEnv.SlashCmdList.YCU, "wrong client rejected before storage and slash registration")
local le,lc,la,lf,lflush = Boot(nil,function(_,core) core._currencyTestInitialized = core.IsInitialized; core.IsInitialized = function() return false end end)
Check(not la.initialized and le.YiboCurrencyForeverDB == nil, "Core not ready stops before save")
lc.IsInitialized = lc._currencyTestInitialized
lc.Events:Fire("CORE_READY"); Check(la.initialized, "late Core readiness starts target")
local saveDB, entry = la.Store.db, lc.Entry
Check(la:Initialize() and la.Store.db == saveDB and lc.Entry == entry, "initialization idempotent")
local ne,_,na = Boot(nil,function(_,core) core.Locale = nil end)
Check(not na.initialized and ne.YiboCurrencyForeverDB == nil, "missing Locale gives bootstrap diagnostic without writing")
local de,dc,da,df = Boot(nil,nil,"YiboCurrency_Mists.toc")
df("PLAYER_LOGIN")
Check(de.YiboCurrencyDB.sentinel == "mists" and not de.YiboCurrencyDB.settings and not da.CoreIntegration.initialized and not de.SlashCmdList.YCU, "forced Mists manifest cannot write or register on Forever")
local he,_,ha = Boot(nil,nil,"YiboCurrency.toc")
Check(ha == nil and he.YiboCurrencyForeverDB == nil and not he.YiboCurrencyDB.settings and not he.SlashCmdList.YCU, "default manifest is diagnostic only")
for _, case in ipairs({ {"zhCN","auto","zh"}, {"enUS","auto","en"}, {"zhCN","en","en"}, {"enUS","zh","zh"} }) do
    local coreSave = c.Defaults:Copy(c.Database:GetDB()); coreSave.settings.language = case[2]
    local env, core, addon, native, drain = Boot(nil,nil,nil,{client=case[1],savedCore=coreSave})
    native("PLAYER_ENTERING_WORLD"); drain(); env.SlashCmdList.YCU(""); drain()
    local page = core.AccountView.frame.instances.currency
    Check(core.Locale:GetLanguage() == case[3] and page.balanceTitle:GetText() == addon:T("FOREVER.BALANCE")
        and page.balance:GetText() == balanceText, "language mode " .. case[1] .. "/" .. case[2])
    Check(#core.Locale:GetMissingEnglish("YiboCurrency") == 0 and not page.status:GetText():match("%[YiboCurrency:"), "target resources complete")
end
local me,_,ma,mf,mflush,md = Boot()
me.GetMoney = nil; mf("PLAYER_ENTERING_WORLD"); mflush()
Check(not ma.Store:Get(me.TEST_GUID) and select(2,ma.Store:Get(me.TEST_GUID)) == "error", "missing native API is not zero")
me.GetMoney = function() return 50 end; me.IsLoggedIn = function() return false end
Check(not ma.Scanner:Scan(true) and not ma.Store:Get(me.TEST_GUID), "logged-out read blocked")
me.IsLoggedIn = function() return true end; me.GetMoney = function() return 9007199254740991 end
Check(ma.Scanner:Scan(true) and ma.Store:Get(me.TEST_GUID).moneyCopper == 9007199254740991, "largest exact integer retained")
local ie,ic,ia,ifire,iflush,items = Boot(nil,function(env, _, data)
    data.itemCount=3
    env.StaticPopup_Show=function() return {} end
    env.C_Item.GetItemInfo=function(id)
        if id==1234 then return "Native token", "|Hitem:1234:0|h[Native token]|h" end
    end
    env.C_Item.GetItemCount=function(id, bank, uses, reagent, account)
        assert(bank==false and uses==false and reagent==false and account==false)
        data.itemReads=(data.itemReads or 0)+1
        if id==2345 then return data.otherCount end
        assert(id==1234)
        return data.itemCount
    end
end)
ifire("PLAYER_ENTERING_WORLD"); iflush()
ie.SlashCmdList.YCU(""); iflush()
local host=ie.CreateFrame("Frame",nil,ie.UIParent)
host:SetWidth(550)
local settingsContext={}
settingsContext.refreshPanel=function() ia.CustomItems:CreateSettingsPanel(host,settingsContext) end
settingsContext.refreshPanel()
local picker=host.currencyCustomItems
picker.IsVisible=picker.IsShown
Check(host.currencyCatalog.state=="disabled","empty catalog has no selection")
picker:SetValue("Native token"); picker:Resolve("add")
Check(not ic.ItemConfirmation.active and not ia.Store:Items()[1234],"custom field requires an item ID")
picker:SetValue("1234"); picker:Resolve("add")
Check(ic.ItemConfirmation.active and not ia.Store:Items()[1234],"resolved native item waits for confirmation")
ie.StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM.OnAccept(nil,ic.ItemConfirmation.active); iflush()
local ip=ic.AccountView.frame.instances.currency
Check(ia.Store:Items()[1234]=="Native token" and ip.itemRows[1].count:GetText()=="3","confirmed ID appears with the native quantity")
Check(ip.itemChangeTitle:IsShown() and ip.itemRows[1].change:GetText()=="0","first valid count establishes the session baseline")
Check(ip.itemSearch:IsShown() and ip.itemTitle:IsShown() and ip.itemTitle.points[1][3]==-289 and ip.itemScroll.points[1][3]==-315
    and ip.sessionChange:IsShown(),"custom item list starts below the session panel")
Check(host.currencyCatalog.state=="default" and host.currencyCatalog.options[1].value==1234,
    "added item immediately appears in the managed catalog")
picker:SetValue("1234"); picker:Resolve("add")
Check(not ic.ItemConfirmation.active and picker.preview:GetText()==ia:T("FOREVER.CUSTOM_DUPLICATE"),"duplicate item ID is rejected")
items.itemCount=7
ifire("BAG_UPDATE_DELAYED"); iflush()
Check(ip.itemRows[1].count:GetText()=="7" and ip.itemRows[1].change:GetText()=="+4","item increases are shown relative to the first count")
items.itemCount,items.fail=0,true
ifire("BAG_UPDATE_DELAYED"); iflush()
Check(ip.itemRows[1].count:GetText()=="0" and ia.Store:Get(ie.TEST_GUID).moneyCopper==123456,"confirmed zero item count survives separate gold read failure")
Check(ip.itemRows[1].change:GetText()=="-3","confirmed zero reports a decrease even when gold cannot be read")
ifire("PLAYER_MONEY"); iflush()
Check(ip.itemRows[1].count:GetText()=="0","unrelated money event does not make a verified zero stale")
items.itemCount=nil
ifire("BAG_UPDATE_DELAYED"); iflush()
Check(ip.itemRows[1].count:GetText()==ia:T("FOREVER.CUSTOM_STALE","0"),"item read failure retains last count as stale")
Check(ip.itemRows[1].change:GetText()==ia:T("FOREVER.CUSTOM_NO_SESSION"),"a stale count has no current session change")
local savedItems=ic.Defaults:Copy(ie.YiboCurrencyForeverDB)
local re,_,ra=Boot(savedItems)
Check(ra.Store:Items()[1234]=="Native token" and ra.Store:GetItemCount(re.TEST_GUID,1234)==0,"catalog and observation restore independently")
Check(select(3,ra.Store:GetItemCount(re.TEST_GUID,1234))==nil,"session baseline is not persisted")
local page
for _,candidate in ipairs(ic.AccountView:GetRegisteredPages()) do if candidate.id=="currency" then page=candidate; break end end
ic.AccountView.frame:Hide()
Check(ic.AccountView:ShowPreview("currency",ie.Minimap) and ip.matrixRowCount==1 and ip.matrixRows[1].fieldID=="money",
    "custom items are excluded from preview by default")
Check(page.SetPreviewFieldVisible("item:1234",true) and page.GetPreviewFields()["item:1234"] and page.GetPreviewFields().money,
    "enabling item preview does not change the money selection")
ic.AccountView:HidePreview()
Check(ic.AccountView:ShowPreview("currency",ie.Minimap) and ip.matrixRowCount==2
    and ip.matrixRows[2].fieldID=="item:1234" and not ip.sessionChange:IsShown(),
    "money and item counts share the matrix")
local matrixAlt = {id="CurrencyMatrixAlt", name="Alt", realm="Realm"}
ia.Store.db.characters[matrixAlt.id] = {moneyCopper=20000,observedAt=1}
ia.AccountPage:Refresh(ip,{preview=true,surfaceAvailableWidth=620,characters={ic.Characters:GetCurrent(),matrixAlt}})
Check(ip.matrixRows[1].cells[matrixAlt.id].count:GetText()==ia:T("FOREVER.CUSTOM_STALE",ia.AccountPage:Format(20000))
    and ip.matrixRows[2].cells[matrixAlt.id].count:GetText()==ia:T("FOREVER.CUSTOM_UNKNOWN"),
    "offline balance is historical and missing item observations are unknown")
Check(ip.matrixRows[2].cells.total.count:GetText()==ia:T("FOREVER.CUSTOM_STALE","0"),"partial total is marked even when the observed count is zero")
ia.Store.db.characters[matrixAlt.id] = nil
Check(page.SetPreviewFieldVisible("money",false) and page.GetPreviewFields()["item:1234"] and not page.GetPreviewFields().money
    and not page.SetPreviewFieldVisible("item:01234",true),"money and item choices are independent and use canonical field IDs")
ic.AccountView:HidePreview()
Check(ic.AccountView:ShowPreview("currency",ie.Minimap) and ip.matrixRowCount==1 and ip.matrixRows[1].fieldID=="item:1234",
    "item-only preview uses the available area")
picker:SetValue("")
host.currencyCatalog:Fire("OnClick")
host.currencyCatalog.menu.buttons[1]:Fire("OnClick")
Check(picker.input:GetText()=="1234" and not ic.ItemConfirmation.active,"catalog selection fills the picker without removing anything")
picker:Resolve("remove")
Check(ic.ItemConfirmation.active and ia.Store:Items()[1234],"removal waits for confirmation")
ie.StaticPopupDialogs.YIBO_CORE_ITEM_CONFIRM.OnAccept(nil,ic.ItemConfirmation.active); iflush()
Check(not ia.Store:Items()[1234] and not ia.Store.db.settings.previewColumns["item:1234"]
    and ia.Store.db.itemSnapshots[ie.TEST_GUID][1234].count==0 and host.currencyCatalog.state=="disabled",
    "removal refreshes the catalog and clears its preview preference while retaining history")
items.itemCount=0
Check(ia.CustomItems:Add({itemID=1234,name="Native token"}),"removed item can be tracked again")
iflush()
Check(select(3,ia.Store:GetItemCount(ie.TEST_GUID,1234))==0,"re-adding establishes a fresh baseline at confirmed zero")
items.itemCount=2
ifire("PLAYER_LEAVING_WORLD"); iflush()
Check(select(3,ia.Store:GetItemCount(ie.TEST_GUID,1234))==nil,"world transition hides the delta while the count is stale")
ifire("PLAYER_ENTERING_WORLD"); iflush()
Check(select(3,ia.Store:GetItemCount(ie.TEST_GUID,1234))==2,"entering another map preserves a zero baseline")
items.otherCount=5
ia.CustomItems:Add({itemID=2345,name="Second token"})
iflush()
items.otherCount=4
ifire("BAG_UPDATE_DELAYED"); iflush()
Check(select(3,ia.Store:GetItemCount(ie.TEST_GUID,1234))==2 and select(3,ia.Store:GetItemCount(ie.TEST_GUID,2345))==-1,
    "tracked items have independent session baselines")
ifire("PLAYER_LOGOUT"); iflush()
ifire("PLAYER_ENTERING_WORLD"); iflush()
Check(select(3,ia.Store:GetItemCount(ie.TEST_GUID,1234))==0 and select(3,ia.Store:GetItemCount(ie.TEST_GUID,2345))==0,
    "logout clears the baselines without removing tracked items")
ic.AccountView:HidePreview(); ic.AccountView:Toggle("currency"); iflush()
local tokenRow=ip.itemRows[1]
tokenRow:Fire("OnEnter")
Check(#ie.GameTooltip.lines==2 and ie.GameTooltip.lines[2].value=="2","unavailable Vault leaves carried item details usable")
assert(ic:RegisterAddon("YiboVault",{version="fixture",requiredAPI=13}))
local equipped,bank={completedScan=true,status="known-empty"},{completedScan=true,status="stale"}
local requested,fail,bankSupported
local service={
    name="vault.items",kind="service",providerID="YiboVault:inventory",version={major=1,minor=0},
    methods={
        HasCapability=function(request)
            return request.name~="source.bank" or bankSupported
        end,
        Query=function(request)
            if fail then error("fixture failure") end
            requested=request
            return {coverage={equipment={[ie.TEST_GUID]={locations={equipment=equipped}}},
                bank={[ie.TEST_GUID]={locations={["5"]=bank}}}},totals={bySource={bank=4}}}
        end,
    },
}
local ref=assert(ic.Contracts:Register("YiboVault",service))
tokenRow:Fire("OnEnter")
Check(#ie.GameTooltip.lines==2 and requested==nil,"older Vault contract is ignored")
assert(ic.Contracts:Unregister("YiboVault",ref))
service.version.minor=1
ref=assert(ic.Contracts:Register("YiboVault",service))
bankSupported=true
tokenRow:Fire("OnEnter")
Check(requested.itemID==1234 and requested.scope.characterIDs[1]==ie.TEST_GUID and #requested.sources==2
    and requested.includeStale and requested.identityMode=="item-id","late Vault discovery queries exact item and current character")
Check(ie.GameTooltip.lines[3].value=="0" and ie.GameTooltip.lines[4].value==ia:T("FOREVER.CUSTOM_STALE","4"),
    "complete empty equipment and stale bank counts are labeled separately")
bank.completedScan=false
tokenRow:Fire("OnEnter")
Check(ie.GameTooltip.lines[4].value==ia:T("FOREVER.CUSTOM_UNKNOWN"),"incomplete bank coverage does not show a partial total or a zero")
bankSupported=false
tokenRow:Fire("OnEnter")
Check(#requested.sources==1 and requested.sources[1]=="equipment" and #ie.GameTooltip.lines==3,"only supported sources are queried")
fail=true
tokenRow:Fire("OnEnter")
Check(#ie.GameTooltip.lines==2 and tokenRow.count:GetText()=="2","provider failure preserves independent carried count")
assert(ic.Contracts:Unregister("YiboVault",ref))
tokenRow:Fire("OnEnter")
Check(#ie.GameTooltip.lines==2,"provider removal drops optional details on the next hover")
local itemReads=items.itemReads
ip.itemSearch:SetValue("  SECOND  ",true); iflush()
Check(ip.itemRows[1].itemID==2345 and not ip.itemRows[2]:IsShown()
    and ip.itemMatches:GetText()==ia:T("FOREVER.CUSTOM_MATCHES",1,2),"trimmed case-insensitive name search filters the tracked items")
ip.itemSearch:SetValue("1234",true); iflush()
Check(ip.itemRows[1].itemID==1234 and ip.itemRows[1].count:GetText()=="2","numeric input finds the exact item ID")
ip.itemSearch:SetValue("123",true); iflush()
Check(not ip.itemScroll:IsShown() and ip.itemMatches:GetText()==ia:T("FOREVER.CUSTOM_NO_MATCH")
    and ip.balance:IsShown() and ip.sessionChange:IsShown(),"no match preserves balance and leaves the filter available")
page.SetPreviewFieldVisible("item:1234",true); page.SetPreviewFieldVisible("item:2345",true)
ic.AccountView.frame:Hide()
Check(ic.AccountView:ShowPreview("currency",ie.Minimap) and not ip.itemSearch:IsShown() and not ip.itemMatches:IsShown()
    and ip.matrixRowCount==2 and ip.matrixRows[1].fieldID=="item:1234" and ip.matrixRows[2].fieldID=="item:2345","entry preview does not inherit the main search")
ic.AccountView:HidePreview(); ic.AccountView:Toggle("currency"); iflush()
Check(ip.itemSearch:GetText()=="123" and not ip.itemScroll:IsShown(),"main search returns after preview")
ip.itemSearch.clearButton:Fire("OnClick"); iflush()
Check(ip.itemRows[1]:IsShown() and ip.itemRows[2]:IsShown() and items.itemReads==itemReads,
    "clearing search shows both cached items without native scans")
print("CurrencyForever Smoke passed: " .. checks .. " checks (actual Core/Currency manifests, simulated client/UI)")
