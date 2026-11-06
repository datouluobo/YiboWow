local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Boot(saved, configure, defaultManifest, localeCase)
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
    for line in io.lines("YiboCurrency/" .. (defaultManifest and "YiboCurrency.toc" or "YiboCurrency_Forever.toc")) do
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
Check(a.initialized and a.VERSION == "0.1.0", "Forever manifest starts")
Check(e.YiboCurrencyDB.sentinel == "mists" and not e.YiboCurrencyDB.settings, "Mists store untouched")
Check(not a.Migration and not a.VaultIntegration and not a.GoalTargets and not a.Catalog, "only money target modules loaded")
Check(not a.Store:Get(e.TEST_GUID) and not a.Scanner:Scan(true) and d.reads == 0, "no scans before world entry")
e.SlashCmdList.YCU(""); flush()
local panel = c.AccountView.frame.instances.currency
Check(c.AccountView.activePageID == "currency" and panel.balance:GetText() == a:T("FOREVER.NO_BALANCE"), "unknown displayed rather than zero")
fire("PLAYER_ENTERING_WORLD"); flush()
local row,state = a.Store:Get(e.TEST_GUID)
Check(row.moneyCopper == 123456 and state == "known", "positive money read and committed")
Check(panel.balance:GetText() == a.AccountPage:Format(123456), "exact gold silver copper displayed")
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
fire("PLAYER_LEAVING_WORLD"); flush()
before = d.reads; fire("PLAYER_MONEY"); flush()
Check(d.reads == before and select(2,a.Store:Get(e.TEST_GUID)) == "stale", "outside world never reads; prior snapshot stale")
fire("PLAYER_ENTERING_WORLD"); flush(); fire("PLAYER_MONEY"); flush()
Check(select(2,a.Store:Get(e.TEST_GUID)) == "known", "native event confirms zero")
c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("currency", e.Minimap), "Core preview opens")
Check(panel.renderedSnapshot.moneyCopper == 0 and not panel.refresh:IsShown(), "same snapshot in preview")
c.AccountView:HidePreview(); c.AccountView:Toggle("currency")
local saved = c.Defaults:Copy(e.YiboCurrencyForeverDB)
local e2,c2,a2,f2,fl2,d2 = Boot(saved)
row,state = a2.Store:Get(e2.TEST_GUID)
Check(row.moneyCopper == 0 and state == "stale", "save restored as stale until new observation")
e2.SlashCmdList.YCU(""); fl2()
Check(c2.AccountView.frame.instances.currency.balance:GetText() == a2.AccountPage:Format(0), "restored balance displayed")
e2.TEST_GUID = nil; f2("PLAYER_ENTERING_WORLD"); fl2()
Check(d2.reads == 0, "missing GUID prevents save")
e2.TEST_GUID = "Player-Test-1"; f2("BAG_UPDATE_DELAYED"); fl2()
Check(a2.Store:Get(e2.TEST_GUID).moneyCopper == 123456, "late identity recovered")
d2.money = 7; f2("PLAYER_MONEY")
a2.Store:Delete({id=e2.TEST_GUID}); fl2()
Check(not a2.Store:Get(e2.TEST_GUID), "cleanup cancels queued scan and removes cache")
f2("PLAYER_MONEY"); fl2()
Check(a2.Store:Get(e2.TEST_GUID).moneyCopper == 7, "subsequent native fact can repopulate")
a2.Store:Delete({id=e2.TEST_GUID},{replay=true,deletedAt=199999})
Check(a2.Store:Get(e2.TEST_GUID).moneyCopper == 7, "cleanup replay preserves newer local observation")
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
Check(not bad.initialized and badEnv.YiboCurrencyForeverDB == nil, "wrong client rejected")
local le,lc,la,lf,lflush = Boot(nil,function(_,core) core._currencyTestInitialized = core.IsInitialized; core.IsInitialized = function() return false end end)
Check(not la.initialized and le.YiboCurrencyForeverDB == nil, "Core not ready stops before save")
lc.IsInitialized = lc._currencyTestInitialized
lc.Events:Fire("CORE_READY"); Check(la.initialized, "late Core readiness starts target")
local saveDB, entry = la.Store.db, lc.Entry
Check(la:Initialize() and la.Store.db == saveDB and lc.Entry == entry, "initialization idempotent")
local ne,_,na = Boot(nil,function(_,core) core.Locale = nil end)
Check(not na.initialized and ne.YiboCurrencyForeverDB == nil, "missing Locale gives bootstrap diagnostic without writing")
local de,dc,da,df = Boot(nil,nil,true)
df("PLAYER_LOGIN")
Check(de.YiboCurrencyDB.sentinel == "mists" and not de.YiboCurrencyDB.settings and not da.CoreIntegration.initialized, "forced Mists manifest cannot write on Forever")
for _, case in ipairs({ {"zhCN","auto","zh"}, {"enUS","auto","en"}, {"zhCN","en","en"}, {"enUS","zh","zh"} }) do
    local coreSave = c.Defaults:Copy(c.Database:GetDB()); coreSave.settings.language = case[2]
    local env, core, addon, native, drain = Boot(nil,nil,nil,{client=case[1],savedCore=coreSave})
    native("PLAYER_ENTERING_WORLD"); drain(); env.SlashCmdList.YCU(""); drain()
    local page = core.AccountView.frame.instances.currency
    Check(core.Locale:GetLanguage() == case[3] and page.balance:GetText() == addon.AccountPage:Format(123456), "language mode " .. case[1] .. "/" .. case[2])
    Check(#core.Locale:GetMissingEnglish("YiboCurrency") == 0 and not page.status:GetText():match("%[YiboCurrency:"), "target resources complete")
end
local me,_,ma,mf,mflush,md = Boot()
me.GetMoney = nil; mf("PLAYER_ENTERING_WORLD"); mflush()
Check(not ma.Store:Get(me.TEST_GUID) and select(2,ma.Store:Get(me.TEST_GUID)) == "error", "missing native API is not zero")
me.GetMoney = function() return 50 end; me.IsLoggedIn = function() return false end
Check(not ma.Scanner:Scan(true) and not ma.Store:Get(me.TEST_GUID), "logged-out read blocked")
me.IsLoggedIn = function() return true end; me.GetMoney = function() return 9007199254740991 end
Check(ma.Scanner:Scan(true) and ma.Store:Get(me.TEST_GUID).moneyCopper == 9007199254740991, "largest exact integer retained")
print("CurrencyForever Smoke passed: " .. checks .. " checks (actual Core/Currency manifests, simulated client/UI)")
