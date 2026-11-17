local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, name) checks = checks + 1; assert(value, name) end
local function Boot(saved, configure, forever)
    if forever == nil then forever = true end
    local e, core, event, _, load = BootCore(forever)
    e.TEST_GUID = "Player-Test-1"
    local clock = 100
    e.GetServerTime = function() return clock end
    e.GetTime = function() return clock end
    event("ADDON_LOADED"); event("PLAYER_LOGIN")
    e.YiboMailDB = forever and { sentinel = "mists" } or saved
    e.YiboMailForeverDB = forever and saved or { sentinel = "forever" }
    local data = { open = false, count = 2, total = 2, reads = 0,
        headers = { { sender = "Sender", subject = "Parcel", count = 2, money = 5, cod = 0 }, { sender = "Sender", subject = "Letter", money = 0, cod = 0 } },
        items = { [1] = { [1] = { id = 7001, quantity = 3 }, [16] = { id = 7002, quantity = 2 } } } }
    e.ATTACHMENTS_MAX_RECEIVE = 16
    e.GetInboxNumItems = function() assert(data.open, "closed mailbox read"); data.reads = data.reads + 1; return data.count, data.total end
    e.GetInboxHeaderInfo = function(index)
        if data.fail then error("read failure") end
        local h = data.headers[index]
        if not h then return end
        local subject = data.changing and data.reads % 2 == 0 and "Changed" or h.subject
        return nil, nil, h.sender, subject, h.money, h.cod, h.days or 30, h.count, false, h.returned == true
    end
    e.GetInboxItem = function(index, slot)
        assert(slot >= 1 and slot <= 16, "attachment bounds")
        local item = data.items[index] and data.items[index][slot]
        if item then return "Item", item.id, 1, item.quantity, 1, true, data.currency end
    end
    e.GetInboxItemLink = function(index, slot)
        local item = data.items[index] and data.items[index][slot]
        if item and not data.missingLink then return "item:" .. (data.badLink and 9000 or item.id) end
    end
    e.C_Mail = { IsCommandPending = function()
        if data.pendingReads and data.pendingReads > 0 then
            data.pendingReads = data.pendingReads - 1
            return true
        end
        return data.pending == true
    end }
    e.C_Item.GetItemInfo = function(id) return "NativeItem" .. id, "item:" .. id end
    for _, action in ipairs({ "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem", "SendMail", "DeleteInboxItem", "ReturnInboxItem", "CheckInbox" }) do
        e[action] = function() error("unexpected mailbox action " .. action) end
    end
    local function Flush()
        local guard = 0
        while #e.TEST_TIMERS > 0 do
            guard = guard + 1; assert(guard < 30, "timer loop")
            local pending = e.TEST_TIMERS; e.TEST_TIMERS = {}
            table.sort(pending, function(a,b) return a[1] < b[1] end)
            for _, timer in ipairs(pending) do clock = clock + timer[1]; timer[2]() end
        end
    end
    if configure then configure(e, core, data, load, event, Flush) end
    for line in io.lines("YiboMail/" .. (forever and "YiboMail_Forever.toc" or "YiboMail.toc")) do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then load("YiboMail/" .. line:gsub("\\", "/"), "YiboMail") end
    end
    event("ADDON_LOADED", "YiboMail")
    return e, core, e.YiboMail, event, Flush, data, load
end
local e,c,m,fire,flush,data,load = Boot()
Check(m.initialized and m.VERSION == "0.1.5-api1", "real Forever Mail manifest starts")
Check(e.YiboMailDB.sentinel == "mists" and not e.YiboMailDB.byCharacter, "Mail Mists store untouched")
Check(not m.Queue and not m.Compose and not m.NativeUI and not m.Recipients and not m.ActionTodo, "operation modules excluded")
Check(not m.Frame.events.MAIL_SEND_SUCCESS and not m.Items:HasCapability("mail-items.transfers",1), "operations and transfer capability not claimed")
fire("PLAYER_ENTERING_WORLD"); flush()
Check(data.reads == 0 and m.Items:GetState(e.TEST_GUID).status == "not-yet-scanned", "unvisited mailbox stays unknown")
e.SlashCmdList.YIBOMAIL("open"); flush()
Check(c.AccountView.activePageID == "mail-inbox", "Mail opens Core account page")
local panel = c.AccountView.frame.instances["mail-inbox"]
Check(panel.refresh.label:GetText() == m:T("FOREVER.REFRESH") and panel.refresh.state == "disabled", "Mail action label and closed state correct")
data.open = true; fire("MAIL_SHOW"); flush()
Check(m.Items:GetState(e.TEST_GUID).status == "known" and #panel.renderedMails == 2, "full inbox and text-only letter displayed")
local query = m.Items:GetByCharacter(e.TEST_GUID,{includeStale=true})
Check(#query.records == 2 and query.quantity == 5 and query.records[2].location.attachmentIndex == 16, "all attachment slots saved through public API")
Check(panel.rows[1].labels.sender:GetText() == "Sender" and panel.rows[1].labels.subject:GetText() == "Parcel", "real inbox header fields rendered")
Check(panel.renderedMails[1].money == 5 and panel.renderedMails[1].cod == 0, "inbox snapshot preserves header copper and COD")
Check(panel.rows[1].labels.attachments:GetText():match("NativeItem"), "Core resolves attachment names")
local mailKey = m.db.byCharacter[e.TEST_GUID].visibleKeys[1]
m.Scanner:Scan(false)
Check(m.db.byCharacter[e.TEST_GUID].visibleKeys[1] == mailKey, "repeated stable observation retains local key")
query.records[1].quantity = 999
Check(m.Items:GetByCharacter(e.TEST_GUID).quantity == 5, "Mail API detached from internal store")
Check(not m.Items:GetByCharacter("Other") and not m.Items:Query({scope={mode="account"}}), "other character and account scope rejected")
Check(not m.Items:GetTransfers(e.TEST_GUID), "unimplemented transfer API unavailable")
c:RegisterAddon("MailConsumer",{requiredAPI=13})
local descriptor = assert(c.Contracts:Resolve("mail.items",{major=1,minMinor=0}))
Check(descriptor.version.minor == 0 and c.Contracts:Call("MailConsumer",descriptor,"GetByCharacter",{characterID=e.TEST_GUID}).quantity == 5, "Core routes versioned Mail snapshot contract")
c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("mail-inbox",e.Minimap), "Core owns Mail preview")
Check(panel.summaryRows[1].labels.mailCount:GetText() == "2" and not panel.rows[1]:IsShown(), "Mail preview summarizes one character")
Check(panel.summaryRows[1].labels.attachmentCount:GetText() == "2"
    and panel.summaryRows[1].labels.claimable:GetText() == "5", "Mail summary counts attachment slots and claimable copper")
local summaryAlt = {id="MailSummaryAlt", name="Alt", realm="Realm"}
local summaryCache = m.Copy(m.db.byCharacter[e.TEST_GUID])
summaryCache.visibleKeys = {}
summaryCache.coverage.status = "known-empty"
m.db.byCharacter[summaryAlt.id] = summaryCache
m.AccountPage:Refresh(panel,{preview=true,characters={c.Characters:GetCurrent(),summaryAlt}})
Check(panel.summaryRows[1].labels.mailCount:GetText()=="2" and panel.summaryRows[2].labels.mailCount:GetText()=="0"
    and panel.summaryRows[2].labels.updated:GetText():sub(1,1)=="~", "other GUID keeps its own empty historical summary")
m.db.byCharacter[summaryAlt.id] = nil
local savedExpiry = m.db.byCharacter[e.TEST_GUID].records[mailKey].expiresAtEstimate
local summaryRecord = m.db.byCharacter[e.TEST_GUID].records[mailKey]
summaryRecord.expiresAtEstimate = m:Now() - 1
m.AccountPage:Refresh(panel,{preview=true,characters={c.Characters:GetCurrent()}})
Check(panel.expiryNotice:GetText()==m:T("FOREVER.SUMMARY_EXPIRED",1), "expired estimate requests mailbox verification")
Check(panel.summaryRows[1].labels.mailCount:GetText()=="2", "estimated expiry retains historical mail count")
summaryRecord.expiresAtEstimate = m:Now() + 3 * 86400
m.AccountPage:Refresh(panel,{preview=true,characters={c.Characters:GetCurrent()}})
Check(panel.expiryNotice:GetText()==m:T("FOREVER.SUMMARY_URGENT",1,3), "three-day boundary uses urgent reminder")
summaryRecord.expiresAtEstimate = m:Now() + 7 * 86400
m.AccountPage:Refresh(panel,{preview=true,characters={c.Characters:GetCurrent()}})
Check(panel.expiryNotice:GetText()==m:T("FOREVER.SUMMARY_SOON",1,7), "seven-day boundary uses upcoming reminder")
summaryRecord.expiresAtEstimate = savedExpiry
panel.openInbox:Fire("OnClick")
Check(not c.AccountView.frame.preview and panel.toolbar:IsShown() and #panel.renderedMails==2,
    "summary action opens the inbox detail")
local before = data.reads
for i=1,20 do fire("MAIL_INBOX_UPDATE") end
flush()
Check(data.reads - before == 2, "Mail event bursts coalesce")
data.items[1][1].quantity = 7; fire("MAIL_INBOX_UPDATE"); flush()
Check(m.Items:GetByCharacter(e.TEST_GUID).quantity == 9, "Mail quantity changes committed")
data.total = 3; fire("MAIL_INBOX_UPDATE"); flush()
Check(m.Items:GetState(e.TEST_GUID).status == "stale" and m.Items:GetByCharacter(e.TEST_GUID).quantity == 9, "incomplete inbox retains old snapshot")
Check(#m.Items:GetByCharacter(e.TEST_GUID,{includeStale=false}).records == 0, "incomplete inbox excluded from fresh data")
data.total = 2
for _, flag in ipairs({"fail","badLink","currency","changing"}) do
    data[flag] = true; fire("MAIL_INBOX_UPDATE"); flush()
    Check(m.Items:GetState(e.TEST_GUID).status == "error" and m.Items:GetByCharacter(e.TEST_GUID).quantity == 9, "invalid Mail candidate preserves prior snapshot: " .. flag)
    data[flag] = false; fire("MAIL_INBOX_UPDATE"); flush()
    Check(m.Items:GetState(e.TEST_GUID).status == "known", "Mail error recovery: " .. flag)
end
data.headers[1].count = 3; fire("MAIL_INBOX_UPDATE"); flush()
Check(m.Items:GetState(e.TEST_GUID).status == "error", "header attachment multiplicity validated")
data.headers[1].count = 2; data.pending = true; fire("MAIL_INBOX_UPDATE"); flush()
Check(m.Scanner.pending and m.Items:GetByCharacter(e.TEST_GUID).quantity == 9, "native operation pending defers read")
data.pending = false; fire("MAIL_INBOX_UPDATE"); flush()
local saved = m.Copy(m.db)
data.open = false; fire("MAIL_CLOSED"); flush()
Check(m.Items:GetState(e.TEST_GUID).status == "stale" and panel.refresh.state == "disabled", "Mail close preserves stale snapshot")
before = data.reads; panel.refresh.scripts.OnClick(); flush()
Check(data.reads == before, "closed Mail does not read")
data.open = true; fire("MAIL_SHOW"); data.open=false; fire("MAIL_CLOSED"); flush()
Check(data.reads == before, "close cancels deferred Mail scan")
local se,sc,sm,sf,sd,sdata = Boot(saved)
sf("PLAYER_ENTERING_WORLD"); sd()
Check(sm.Items:GetState(se.TEST_GUID).status == "stale" and sm.Items:GetByCharacter(se.TEST_GUID).quantity == 9, "saved Mail snapshot restored independently")
sdata.open,sdata.count,sdata.total,sdata.items=true,0,0,{}
sf("MAIL_SHOW"); sd()
Check(sm.Items:GetByCharacter(se.TEST_GUID).quantity == 9, "initial zero inbox cannot erase saved attachments")
sf("MAIL_INBOX_UPDATE"); sd()
Check(sm.Items:GetState(se.TEST_GUID).status == "known-empty" and #sm.db.byCharacter[se.TEST_GUID].visibleKeys == 0, "ready empty inbox committed without deleting historical evidence")
sf("PLAYER_LEAVING_WORLD"); before=sdata.reads; sf("MAIL_SHOW"); sd()
Check(sdata.reads == before, "Mail show outside world ignored")
local _,_,future = Boot({schemaVersion=999,sentinel=true})
Check(not future.initialized and not future.db, "future Mail schema stopped before mutation")
local _,_,oldCore = Boot(nil,function(_,core) core.CheckAPIVersion=function() return false end end)
Check(not oldCore.initialized and not oldCore.db, "old Core stops Mail before DB creation")
local _,_,wrong = Boot(nil,function(env) env.WOW_PROJECT_ID=19 end)
Check(not wrong.initialized and not wrong.db, "wrong Forever client stopped")
local foreignSave={schemaVersion=1,clientScope={target="Mists",projectID=19,scope="account"},sentinel=true}
local _,_,foreignStore=Boot(foreignSave)
Check(not foreignStore.initialized and not foreignStore.db and foreignSave.sentinel and not foreignSave.byCharacter,"foreign scope store preserved before initialization")
local _,_,budget=Boot(nil,function(_,core)
    local original=core.HasCapability
    core.HasCapability=function(self,name,minimum) if name=="account-surface-budget" then return false end; return original(self,name,minimum) end
end)
Check(not budget.initialized and not budget.db,"required Core surface capability checked before DB initialization")
local ie,_,inputMissing=Boot(nil,function(_,core)
    local original=core.HasCapability
    core.HasCapability=function(self,name,minimum) return name~="basic-input" and original(self,name,minimum) end
end)
Check(not inputMissing.initialized and not inputMissing.db and not ie.YiboMailForeverDB.byCharacter,
    "input capability is required before writing Mail DB")
local defaultEnv,_,defaultMail=Boot(nil,function(env) env.WOW_PROJECT_CAMELOT=18; env.WOW_PROJECT_ID=18 end,false)
Check(not defaultMail.initialized and not defaultEnv.YiboMailDB,"forced Mists manifest cannot write on Forever")
local ge,gc,gm,gf,gd,gdata=Boot(nil,function(_,core) core.Characters.GetCurrent=function() return nil end end)
gf("PLAYER_ENTERING_WORLD"); gdata.open=true; gf("MAIL_SHOW"); gd()
Check(gdata.reads==0 and not next(gm.db.byCharacter),"missing public GUID does not create temporary character or read mail")
Check(#e.TEST_MESSAGES==0 and #se.TEST_MESSAGES==0, "no hidden Mail callback errors: " .. table.concat(e.TEST_MESSAGES," | "))
do
    local me,mc,mm,mf,md,mailbox = Boot(nil,nil,false)
    local expectedVersion
    for line in io.lines("YiboMail/YiboMail.toc") do expectedVersion = line:match("^## Version:%s*(%S+)") or expectedVersion end
    Check(mm.initialized and mm.VERSION == expectedVersion, "real Mists Mail manifest starts with matching source/TOC version")
    Check(mm.Queue and mm.Compose and mm.NativeUI and mm.Recipients and mm.ActionTodo and mm.Items:HasCapability("mail-items.transfers",1), "Mists original operation and transfer modules retained")
    Check(me.YiboMailForeverDB.sentinel == "forever" and not me.YiboMailForeverDB.byCharacter, "Mists leaves Forever saved table untouched")
    mailbox.open = true
    me.MailFrame = { IsShown=function() return true end }
    mm.Scanner.open,mm.Scanner.updated = true,true
    Check(mm.Scanner:Scan(), "original Mists inbox scanner succeeds")
    Check(mm.Items:Query({scope={mode="account"}}).quantity == 5, "Mists original inbox store and account query retained")
    me.SlashCmdList.YIBOMAIL("open"); md()
    Check(mc.AccountView.activePageID == "mail-inbox", "Mists original Mail window opens through Core")
    Check(#me.TEST_MESSAGES==0,"Mists has no startup callback errors: " .. table.concat(me.TEST_MESSAGES," | "))
end
do
    local function VaultSetup(env, core, mailbox, loader, event, drain)
        env.YiboVaultDB = { sentinel="mists" }
        env.C_Container = { GetContainerNumSlots=function(id) return id==0 and 1 or 0 end,
            GetContainerItemInfo=function() end, GetContainerNumFreeSlots=function(id) return id==0 and 1 or 0 end }
        env.GetInventoryItemID=function() end
        for line in io.lines("YiboVault/YiboVault_Forever.toc") do
            line=line:gsub("\r","")
            if line:match("%.lua$") then loader("YiboVault/" .. line:gsub("\\","/"),"YiboVault") end
        end
        event("ADDON_LOADED","YiboVault"); event("PLAYER_ENTERING_WORLD")
        mailbox.open=true; event("MAIL_SHOW"); drain()
        Check(env.YiboVault.Items:Query({sources={"mail"}}).totals.totalQuantity==5,"Vault standalone scanner works before Mail late registration")
    end
    local ie,ic,im,ef,dr,box = Boot(nil,VaultSetup)
    local vault=ie.YiboVault
    Check(vault.initialized and vault.MailProvider:Connect(),"late Mail registration discovered through Core contract")
    Check(vault.Items:Query({sources={"mail"}}).totals.totalQuantity==0,"ready provider with unknown inbox does not reuse local authority")
    Check(vault:GetCachedCharacterRecords(ie.TEST_GUID,"mail")[1]~=nil,"prior Vault fallback cache retained as dormant archive")
    ef("PLAYER_ENTERING_WORLD"); ef("MAIL_SHOW"); dr()
    Check(vault.Items:Query({sources={"mail"}}).totals.totalQuantity==5,"Vault projects public Mail attachment snapshot")
    local reads=box.reads
    box.items[1][1].quantity=8
    ef("MAIL_INBOX_UPDATE"); dr()
    Check(box.reads-reads==2 and vault.Items:Query({sources={"mail"}}).totals.totalQuantity==10,"both addons use one native Mail scan and public change notification")
    ie.SlashCmdList.YIBOVAULT("open"); dr()
    local vp=ic.AccountView.frame.instances["vault-items"]
    vp.tabs.mail.scripts.OnClick(); dr()
    Check(#vp.renderedRecords==2 and vp.renderedStatus=="known","Vault mail page uses same provider snapshot")
    ie.SlashCmdList.YIBOMAIL(""); dr()
    local mailPage=ic.AccountView.frame.instances["mail-inbox"]
    mailPage.search:SetValue("nothing matches",true); dr()
    Check(#mailPage.renderedMails==0 and vault.Items:Query({sources={"mail"}}).totals.totalQuantity==10,
        "Mail UI filters do not change the Vault provider snapshot")
    ie.SlashCmdList.YIBOVAULT("open"); dr()
    local snapshot=im.db.byCharacter[ie.TEST_GUID]
    box.pending=true; box.items[1][16]=nil; box.headers[1].count=1
    ef("MAIL_INBOX_UPDATE"); dr()
    Check(vault.Items:Query({sources={"mail"}}).totals.totalQuantity==10,"pending attachment take keeps the last completed Vault snapshot")
    box.pending=false
    box.pendingReads=1
    ef("MAIL_INBOX_UPDATE"); dr()
    Check(im.Items:GetByCharacter(ie.TEST_GUID).quantity==8 and #vp.renderedRecords==1
        and vault.Items:Query({sources={"mail"}}).totals.totalQuantity==8,"retry after pending command updates Vault without a second inbox event")
    local archived
    for _, observation in ipairs(snapshot.history or {}) do
        for _, item in ipairs(observation.attachments or {}) do
            if item.attachmentIndex==16 and item.quantity==2 then archived=true end
        end
    end
    Check(archived,"attachment take retains the previously discovered item in Mail history")
    box.items[1][16]={ id=7002, quantity=2 }; box.headers[1].count=2
    ef("MAIL_INBOX_UPDATE"); dr()
    box.open=false; ef("MAIL_CLOSED"); dr()
    Check(vault.AccountPage:Status("mail",ie.TEST_GUID)=="stale" and #vault.Items:Query({sources={"mail"},includeStale=false}).records==0,"provider close invalidates Vault fresh view")
    box.open=true; ef("MAIL_SHOW"); dr()
    Check(ic.Contracts:Unregister("YiboMail",im.Items.serviceRef),"Mail provider unregisters through Core")
    dr()
    Check(not vault.MailProvider:Connect() and vault.Items:Query({sources={"mail"}}).totals.totalQuantity==10,"provider removal resumes Vault native base scanner")
    Check(im.Items:RegisterService(),"Mail public service can register again")
    reads=box.reads; ef("MAIL_INBOX_UPDATE"); dr()
    Check(vault.MailProvider:Connect() and box.reads-reads==2,"provider restoration stops duplicate native Vault scan")
    local revision=vault.Items:GetRevision()
    im:DeleteCharacter({id=ie.TEST_GUID}); dr()
    Check(vault.Items:Query({sources={"mail"}}).totals.totalQuantity==0 and vault.Items:GetRevision()>revision,"Mail cleanup invalidates Vault without copying authoritative state")
    ic.Contracts:Unregister("YiboMail",im.Items.serviceRef)
    ic:RegisterAddon("BadMail",{requiredAPI=13})
    local badRef=assert(ic.Contracts:Register("BadMail",{name="mail.items",kind="service",providerID="BadMail:inbox",version={major=1,minor=0},methods={GetRevision=function() return 1 end}}))
    dr()
    Check(not vault.MailProvider:Connect() and vault.Items:Query({sources={"mail"}}).totals.totalQuantity==10,"incompatible provider methods leave Vault native base usable")
    ic.Contracts:Unregister("BadMail",badRef)
    Check(#ie.TEST_MESSAGES==0,"Mail/Vault integration has no hidden callback errors: " .. table.concat(ie.TEST_MESSAGES," | "))
end
do
    local fe,fc,fm,ff,fd,box=Boot()
    box.headers[1].days=2
    box.headers[2].returned=true
    box.headers[3]={sender="Courier",subject="Order",money=0,cod=10,days=0}
    box.count,box.total=3,3
    ff("PLAYER_ENTERING_WORLD"); box.open=true; ff("MAIL_SHOW"); fd()
    fe.SlashCmdList.YIBOMAIL(""); fd()
    local inbox=fc.AccountView.frame.instances["mail-inbox"]
    local reads,revision=box.reads,fm.Items:GetRevision()
    for index,subject in ipairs({"Parcel","Parcel","Order","Letter","Parcel"}) do
        inbox.filter.menu.buttons[index+1].scripts.OnClick(); fd()
        Check(#inbox.renderedMails==1 and inbox.renderedMails[1].subject==subject,"mail kind filter: "..inbox.filter.value)
    end
    inbox.search:SetValue("  NATIVEITEM7002  ",true); fd()
    Check(#inbox.renderedMails==1 and inbox.matchCount:GetText()==fm:T("FOREVER.MATCH_COUNT",1,3),"attachment name search and kind filter intersect")
    inbox.search:SetValue("Courier",true); fd()
    Check(#inbox.renderedMails==0 and inbox.matchCount:GetText()==fm:T("FOREVER.NO_MATCH"),"sender match excluded by active kind")
    inbox.filter.menu.buttons[1].scripts.OnClick(); fd()
    Check(#inbox.renderedMails==1 and inbox.renderedMails[1].subject=="Order","all-mail filter finds sender")
    inbox.search:SetValue("7002",true); fd()
    Check(#inbox.renderedMails==1 and inbox.renderedMails[1].subject=="Parcel","attachment ID matches")
    fc.AccountView.frame:Hide()
    Check(fc.AccountView:ShowPreview("mail-inbox",fe.Minimap) and inbox.summaryRows[1].labels.mailCount:GetText()=="3" and not inbox.toolbar:IsShown(),
        "mail preview summarizes complete snapshot without transient filters")
    fc.AccountView:HidePreview(); fe.SlashCmdList.YIBOMAIL(""); fd()
    Check(#inbox.renderedMails==1 and inbox.toolbar:IsShown(),"mail filter resumes on return")
    inbox.search.clearButton.scripts.OnClick(); fd()
    Check(#inbox.renderedMails==3 and box.reads==reads and fm.Items:GetRevision()==revision,"clearing UI filters restores all mail without scanning or publishing")
end
print("MailForever Smoke passed: " .. checks .. " checks (real Core/Mail manifests, simulated client)")
return Boot
