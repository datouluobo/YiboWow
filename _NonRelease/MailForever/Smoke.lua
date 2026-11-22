local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local checks = 0
local function Check(value, name) checks = checks + 1; assert(value, name) end
local e,c,m,fire,flush,data,load = Boot()
Check(m.initialized and m.VERSION == "0.3.0-api1", "real Forever Mail manifest starts")
Check(e.YiboMailDB.sentinel == "mists" and not e.YiboMailDB.byCharacter, "Mail Mists store untouched")
Check(m.Queue and m.Returns and m.CollectionRuntime and m.FEATURES.collect and m.NativeUI
    and m.Compose and m.Recipients and m.ActionTodo, "shared collection/send/contact/action modules enabled")
Check(m.Frame.events.MAIL_SEND_SUCCESS and m.Items:HasCapability("mail-items.transfers",1), "send events and transfer capability registered")
fire("PLAYER_ENTERING_WORLD"); flush()
Check(data.reads == 0 and m.Items:GetState(e.TEST_GUID).status == "not-yet-scanned", "unvisited mailbox stays unknown")
e.SlashCmdList.YIBOMAIL("open"); flush()
Check(c.AccountView.activePageID == "mail-inbox", "Mail opens Core account page")
local panel = c.AccountView.frame.instances["mail-inbox"]
local workspace = panel.mailWorkspace
local function PreviewFor(characters)
    local context = c.AccountView:BuildContext(c.AccountView._pages["mail-inbox"],{preview=true})
    context.characters=characters
    return context
end
local function RowContains(row, text)
    for _, cell in ipairs(row.cells) do if cell:GetText():find(text,1,true) then return true end end
end
Check(workspace and workspace.tabs.buttons.overview and workspace.tabs.buttons.history,
    "Forever loads the shared inbox, overview and history workspace")
data.open = true; fire("MAIL_SHOW"); flush()
Check(m.Items:GetState(e.TEST_GUID).status == "known" and #workspace.data == 2, "full inbox and text-only letter displayed")
local query = m.Items:GetByCharacter(e.TEST_GUID,{includeStale=true})
Check(#query.records == 2 and query.quantity == 5 and query.records[2].location.attachmentIndex == 16, "all attachment slots saved through public API")
Check(RowContains(workspace.rows[1],"Sender") and RowContains(workspace.rows[1],"Parcel"), "real inbox header fields rendered")
Check(workspace.data[1].mail.money == 5 and workspace.data[1].mail.cod == 0, "inbox snapshot preserves header copper and COD")
Check(m.Core.ItemResolver:GetInfo(7001).name:match("NativeItem"), "Core resolves attachment names")
local mailKey = m.db.byCharacter[e.TEST_GUID].visibleKeys[1]
m.Scanner:Scan(false)
Check(m.db.byCharacter[e.TEST_GUID].visibleKeys[1] == mailKey, "repeated stable observation retains local key")
local originalExpiry=m.db.byCharacter[e.TEST_GUID].records[mailKey].expiresAtEstimate
local originalDays=data.headers[1].days
data.headers[1].days=30-1/86400
m.Scanner:Scan(false)
Check(m.db.byCharacter[e.TEST_GUID].records[mailKey].expiresAtEstimate==originalExpiry,
    "shared commit suppresses sub-two-second expiry jitter without changing identity")
data.headers[1].days=30-10/86400
m.Scanner:Scan(false)
Check(m.db.byCharacter[e.TEST_GUID].records[mailKey].expiresAtEstimate==originalExpiry-10,
    "shared commit preserves substantive expiry corrections")
data.headers[1].days=originalDays
m.Scanner:Scan(false)
Check(m.Scanner.stable==nil,"Forever does not inherit the Mists visible-window cleanup policy")
query.records[1].quantity = 999
Check(m.Items:GetByCharacter(e.TEST_GUID).quantity == 5, "Mail API detached from internal store")
Check(#m.Items:GetByCharacter("Other").records==0 and m.Items:Query({scope={mode="account"}}).quantity==5,
    "unknown GUID adds no records while account scope returns cached inbox content")
Check(#m.Items:GetTransfers(e.TEST_GUID).records==0, "no sending evidence produces no transfer")
local targetConfig = m.Target
m.Target = nil
local otherState, scopeError = m.Items:GetState("Player-Other")
Check(otherState and otherState.status=="not-yet-scanned" and scopeError==nil,
    "unknown character state stays unknown independently of target object presence")
local transfers, transferError = m.Items:GetTransfers(e.TEST_GUID)
Check(transfers and #transfers.records==0 and transferError==nil, "transfer query follows declared capability without target-object inference")
m.Target = targetConfig
c:RegisterAddon("MailConsumer",{requiredAPI=13})
local descriptor = assert(c.Contracts:Resolve("mail.items",{major=1,minMinor=0}))
Check(descriptor.version.minor == 1 and c.Contracts:Call("MailConsumer",descriptor,"GetByCharacter",{characterID=e.TEST_GUID}).quantity == 5, "Core routes versioned Mail snapshot contract")
c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("mail-inbox",e.Minimap), "Core owns Mail preview")
Check(panel.mailPreview:IsShown() and not workspace:IsShown() and m.AccountPage:GetSummary(c.Characters:GetCurrent()).count=="2", "Mail preview summarizes one character")
Check(m.AccountPage:GetSummary(c.Characters:GetCurrent()).attachments=="2"
    and RowContains(panel.mailPreview.mailRows[1],"2"), "Mail summary counts attachment slots and renders snapshot")
local summaryAlt = {id="MailSummaryAlt", name="Alt", realm="Realm"}
local summaryCache = m.Copy(m.db.byCharacter[e.TEST_GUID])
local originalRoster = c.Characters.GetAllCached
c.Characters.GetAllCached = function() return {c.Characters:GetCurrent(), summaryAlt} end
m.db.byCharacter[summaryAlt.id] = summaryCache
local staleAlt = m.Items:GetByCharacter(summaryAlt.id,{includeStale=true})
Check(staleAlt.quantity==5 and staleAlt.coverage[summaryAlt.id].status=="stale",
    "another Core GUID exposes its own historical snapshot with stale coverage")
Check(m.Items:GetByCharacter(summaryAlt.id,{includeStale=false}).quantity==0
    and summaryCache.coverage.status=="known", "fresh-only excludes offline content without rewriting saved coverage")
staleAlt.records[1].quantity=999
Check(m.Items:GetByCharacter(summaryAlt.id).quantity==5 and m.Items:GetByCharacter(e.TEST_GUID).quantity==5,
    "multi-role public snapshots remain detached and isolated")
summaryCache.visibleKeys = {}
summaryCache.coverage.status = "known-empty"
m.db.byCharacter[summaryAlt.id] = summaryCache
m.AccountPage:Refresh(panel,PreviewFor({c.Characters:GetCurrent(),summaryAlt}))
Check(m.AccountPage:GetSummary(summaryAlt).count=="0" and m.Items:GetState(summaryAlt.id).status=="stale"
    and panel.mailPreview.mailRows[2]:IsShown(), "other GUID keeps its own empty historical summary")
m.db.byCharacter[summaryAlt.id] = nil
c.Characters.GetAllCached = originalRoster
local savedExpiry = m.db.byCharacter[e.TEST_GUID].records[mailKey].expiresAtEstimate
local summaryRecord = m.db.byCharacter[e.TEST_GUID].records[mailKey]
summaryRecord.expiresAtEstimate = m:Now() - 1
m.db.byCharacter[e.TEST_GUID].coverage.revision=m.db.byCharacter[e.TEST_GUID].coverage.revision+1
m.AccountPage:Refresh(panel,PreviewFor({c.Characters:GetCurrent()}))
Check(panel.mailPreview.mailAlert:IsShown() and panel.mailPreview.mailAlert.text:GetText()=="1"..m:T("UI.TEXT_0036"), "expired estimate requests mailbox verification")
Check(m.AccountPage:GetSummary(c.Characters:GetCurrent()).count=="2", "estimated expiry retains historical mail count")
summaryRecord.expiresAtEstimate = m:Now() + 3 * 86400
m.db.byCharacter[e.TEST_GUID].coverage.revision=m.db.byCharacter[e.TEST_GUID].coverage.revision+1
m.AccountPage:Refresh(panel,PreviewFor({c.Characters:GetCurrent()}))
Check(panel.mailPreview.mailAlert.text:GetText():find(m:T("UI.TEXT_0034"),1,true), "three-day boundary uses urgent reminder")
summaryRecord.expiresAtEstimate = m:Now() + 7 * 86400
m.db.byCharacter[e.TEST_GUID].coverage.revision=m.db.byCharacter[e.TEST_GUID].coverage.revision+1
m.AccountPage:Refresh(panel,PreviewFor({c.Characters:GetCurrent()}))
Check(panel.mailPreview.mailAlert.text:GetText():find(m:T("UI.TEXT_0035"),1,true), "seven-day boundary uses upcoming reminder")
summaryRecord.expiresAtEstimate = savedExpiry
m.db.byCharacter[e.TEST_GUID].coverage.revision=m.db.byCharacter[e.TEST_GUID].coverage.revision+1
panel.mailPreview.mailAlert.action:Fire("OnClick")
Check(not c.AccountView.frame.preview and workspace:IsShown() and #workspace.data==2,
    "summary action opens the inbox detail")
local before = data.reads
for i=1,20 do fire("MAIL_INBOX_UPDATE") end
flush()
Check(data.reads - before == 2, "Mail event bursts coalesce")
data.items[1][1].quantity = 7; fire("MAIL_INBOX_UPDATE"); flush()
Check(m.Items:GetByCharacter(e.TEST_GUID).quantity == 9, "Mail quantity changes committed")
data.total = 3; fire("MAIL_INBOX_UPDATE"); flush()
Check(m.Items:GetState(e.TEST_GUID).status == "partial" and m.Items:GetState(e.TEST_GUID).unscannedCount==1
    and m.Items:GetByCharacter(e.TEST_GUID).quantity == 9, "partial inbox publishes observed rows and explicit unseen count")
Check(#m.Items:GetByCharacter(e.TEST_GUID,{includeStale=false}).records == 2, "partial visible attachments remain fresh without claiming completeness")
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
Check(m.Items:GetState(e.TEST_GUID).status == "stale" and not m.Scanner:IsOpen(), "Mail close preserves stale snapshot and blocks operations")
before = data.reads; m.AccountPage:Refresh(panel,c.AccountView:BuildContext(c.AccountView._pages["mail-inbox"])); flush()
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
local wrongMistsEnv,_,wrongMists=Boot(nil,function(env) env.WOW_PROJECT_ID=1 end,false)
Check(not wrongMists.initialized and not wrongMistsEnv.YiboMailDB,
    "Mists manifest rejects an unrelated client before store creation")
local futureMists = {schemaVersion=2, sentinel="preserve"}
local futureMistsEnv,_,futureMistsMail=Boot(futureMists,nil,false)
Check(not futureMistsMail.initialized and not futureMistsMail.db and futureMistsEnv.YiboMailDB==futureMists
    and futureMists.schemaVersion==2 and futureMists.byCharacter==nil,
    "Mists future schema is preserved without initialization")
local foreignMists = {schemaVersion=1,clientScope={target="Forever",projectID=18,scope="current-character"}}
local _,_,foreignMistsMail=Boot(foreignMists,nil,false)
Check(not foreignMistsMail.initialized and foreignMists.byCharacter==nil,
    "Mists rejects a foreign target scope without importing its store")
local hintEnv,_,hintMail=Boot(nil,nil,true,true)
Check(hintMail == nil and not hintEnv.YiboMailForeverDB.byCharacter and not hintEnv.YiboMailDB.byCharacter,
    "default hint manifest creates no business object or saved store")
local ge,gc,gm,gf,gd,gdata=Boot(nil,function(_,core) core.Characters.GetCurrent=function() return nil end end)
gf("PLAYER_ENTERING_WORLD"); gdata.open=true; gf("MAIL_SHOW"); gd()
Check(gdata.reads==0 and not next(gm.db.byCharacter),"missing public GUID does not create temporary character or read mail")
Check(#e.TEST_MESSAGES==0 and #se.TEST_MESSAGES==0, "no hidden Mail callback errors: " .. table.concat(e.TEST_MESSAGES," | "))
do
    local me,mc,mm,mf,md,mailbox = Boot(nil,nil,false)
    local expectedVersion
    for line in io.lines("YiboMail/YiboMail_Mists.toc") do expectedVersion = line:match("^## Version:%s*(%S+)") or expectedVersion end
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
    mailPage.mailWorkspace.search:SetValue("nothing matches",true); dr()
    Check(#mailPage.mailWorkspace.data==0 and vault.Items:Query({sources={"mail"}}).totals.totalQuantity==10,
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
    local inboxPanel=fc.AccountView.frame.instances["mail-inbox"]; local inbox=inboxPanel.mailWorkspace
    local reads,revision=box.reads,fm.Items:GetRevision()
    for _,choice in ipairs({{"items","Parcel"},{"money","Parcel"},{"cod","Order"},{"returned","Letter"}}) do
        inbox.kind.onValueChanged(choice[1]); fd()
        Check(#inbox.data==1 and inbox.data[1].mail.subject==choice[2],"mail kind filter: "..choice[1])
    end
    inbox.kind.onValueChanged("all"); inbox.risk.onValueChanged("threeDays"); fd()
    Check(#inbox.data==1 and inbox.data[1].mail.subject=="Parcel","urgent filter uses shared expiry state")
    inbox.search:SetValue("  NATIVEITEM7002  ",true); fd()
    Check(#inbox.data==1 and inbox.total==1,"attachment name search and kind filter intersect")
    inbox.search:SetValue("Courier",true); fd()
    Check(#inbox.data==0 and inbox.empty:IsShown(),"sender match excluded by active kind")
    inbox.risk.onValueChanged("all"); fd()
    Check(#inbox.data==1 and inbox.data[1].mail.subject=="Order","all-mail filter finds sender")
    inbox.search:SetValue("7002",true); fd()
    Check(#inbox.data==1 and inbox.data[1].mail.subject=="Parcel","attachment ID matches")
    fc.AccountView.frame:Hide()
    Check(fc.AccountView:ShowPreview("mail-inbox",fe.Minimap) and fm.AccountPage:GetSummary(fc.Characters:GetCurrent()).count=="3" and not inbox:IsShown(),
        "mail preview summarizes complete snapshot without transient filters")
    fc.AccountView:HidePreview(); fe.SlashCmdList.YIBOMAIL(""); fd()
    Check(#inbox.data==1 and inbox:IsShown(),"mail filter resumes on return")
    inbox.search.clearButton.scripts.OnClick(); fd()
    Check(#inbox.data==3 and box.reads==reads and fm.Items:GetRevision()==revision,"clearing UI filters restores all mail without scanning or publishing")
end
do
    local env,core,mail,event,drain,box=Boot()
    event("PLAYER_ENTERING_WORLD"); box.open=true; event("MAIL_SHOW"); drain()
    local current=core.Characters:GetCurrent()
    local alt={id="WorkspaceAlt",name="Alt",realm=current.realm,class=current.class}
    mail.db.byCharacter[alt.id]=mail.Copy(mail.db.byCharacter[current.id])
    mail:AddHistory(alt.id,{state="collected-archived",observedAt=mail:Now(),sender="Sender",subject="Historical parcel",attachments={{itemID=7001,quantity=1}}})
    core.Characters.GetAllCached=function() return {current,alt} end
    core.AccountView.GetVisibleCharacters=function() return {current,alt} end
    env.SlashCmdList.YIBOMAIL(""); drain()
    local host=core.AccountView.frame.instances["mail-inbox"]
    local root=host.mailWorkspace
    local reads,revision=box.reads,mail.Items:GetRevision()
    root.tabs.buttons.overview:Fire("OnClick")
    Check(root.total==2 and root.overview.mailRows[2]:IsShown(),"Forever shared overview renders both cached Core GUIDs")
    mail.WorkspaceState:Locate(alt.id)
    mail.AccountPage:Refresh(host,core.AccountView:BuildContext(core.AccountView._pages["mail-inbox"]))
    Check(#root.data==2 and root.data[1].character.id==alt.id,"overview navigation resolves the offline inbox")
    root.items:Fire("OnClick")
    Check(#root.data==2 and root.data[1].quantity+root.data[2].quantity==5,"Forever attachment aggregation keeps offline quantities")
    root.tabs.buttons.history:Fire("OnClick")
    Check(root.total==1 and root.data[1].subject=="Historical parcel" and root.data[1].character.id==alt.id,"Forever shared history displays actual stored evidence")
    Check(box.reads==reads and mail.Items:GetRevision()==revision,"account browsing neither scans nor changes authoritative mail data")
end
do
    local counts={page=0,entry=0,cleanup=0,service=0}
    local env,core,mail=Boot(nil,function(_,c)
        for _, binding in ipairs({{c.AccountView,"RegisterPage","page"},{c.Entry,"RegisterBusinessEntry","entry"},{c.CharacterCleanup,"RegisterOwner","cleanup"}}) do
            local object,method,key=binding[1],binding[2],binding[3]
            local original=object[method]
            object[method]=function(self,...) counts[key]=counts[key]+1; return original(self,...) end
        end
        local register=c.Contracts.Register
        c.Contracts.Register=function(self,owner,definition)
            if owner=="YiboMail" and definition.name=="mail.items" then
                counts.service=counts.service+1
                if counts.service==1 then return nil,"injected-service-failure" end
            end
            return register(self,owner,definition)
        end
    end)
    Check(not mail.initialized and not mail.Items.serviceRef,"failed service registration leaves Mail unready")
    Check(mail:Initialize() and mail:Initialize(),"startup retries the failed stage and becomes ready")
    Check(counts.page==1 and counts.entry==1 and counts.cleanup==1 and counts.service==2,
        "startup retry never duplicates successful page, entry or cleanup registrations")
end
do
    local env,core,mail,event,drain,box=Boot()
    event("PLAYER_ENTERING_WORLD"); box.open=true; event("MAIL_SHOW"); drain()
    local revision=mail.Items:GetRevision()
    local scanner=mail.Scanner
    box.headerReads={}
    local target,count,total,err=scanner:ReadTarget(1)
    Check(target and count==2 and total==2 and not err and not box.headerReads[2]
        and box.headerReads[1]==2,"target read validates only the requested envelope")
    Check(scanner:Signature(target)==target.signature,"target/full reads share the existing Forever signature encoding")
    local snapshot=mail.db.byCharacter[env.TEST_GUID]
    local key=snapshot.visibleKeys[1]
    local entry={character={id=env.TEST_GUID},key=key,mail=snapshot.records[key]}
    Check(scanner:ReadEntry(entry)~=nil,"current snapshot entry revalidates without committing")
    local before=box.reads
    Check(scanner:ReadEntry({character={id="Other"},mail=entry.mail})==nil and box.reads==before,
        "foreign role entry rejected before native read")
    box.headers[1].subject="Changed"
    Check(scanner:ReadEntry(entry)==nil,"changed envelope cannot satisfy an old entry")
    box.headers[1].subject="Parcel"
    box.pending=true; before=box.reads
    local _,_,_,pending=scanner:ReadTarget(1)
    Check(pending and box.reads==before,"native pending command blocks target reads")
    box.pending=false; box.currency=true
    local _,_,_,currency=scanner:ReadTarget(1)
    Check(currency~=nil,"currency attachments cannot be interpreted as item operations")
    box.currency=false; box.badLink=true
    local _,_,_,badLink=scanner:ReadTarget(1)
    Check(badLink~=nil,"mismatched attachment identity blocks target validation")
    box.badLink=false; box.total=3
    box.targetRace=1
    local _,_,_,raceError=scanner:ReadTarget(1)
    Check(raceError~=nil,"same-count attachment changes during recheck are rejected")
    box.items[1][1].quantity=3
    local visible=scanner:ReadVisible()
    local partial,loaded,all=scanner:ReadTarget(1)
    Check(visible and #visible==2 and partial and loaded==2 and all==3,"visible and single-target reads preserve partial inbox counts")
    box.count,box.total=1,1
    local missing,one,oneTotal,missingError=scanner:ReadTarget(2)
    Check(missing==nil and one==1 and oneTotal==1 and missingError==nil,"removed row differs from unreadable row")
    box.count,box.total=2,2
    Check(mail.Items:GetRevision()==revision and snapshot.visibleKeys[1]==key,
        "operation rechecks do not mutate authoritative snapshots or revision")
    box.open=false; event("MAIL_CLOSED"); before=box.reads
    Check(scanner:ReadTarget(1)==nil and scanner:ReadVisible()==nil and box.reads==before,"closed rechecks never read cached native mail")
end
for _,language in ipairs({"zh","en"}) do
    for _,failure in ipairs({{"addon","ERROR.CORE_REGISTER"},{"cleanup","ERROR.CLEANUP_REGISTER"},
        {"page","ERROR.PAGE_REGISTER"},{"service","ERROR.ITEMS_REGISTER"}}) do
        local env,core,mail=Boot(nil,function(_,c)
            c.Locale.language=language
            if failure[1]=="addon" then
                local original=c.RegisterAddon
                c.RegisterAddon=function(self,name,...) if name=="YiboMail" then return nil end; return original(self,name,...) end
            elseif failure[1]=="cleanup" then c.CharacterCleanup.RegisterOwner=function() return nil end
            elseif failure[1]=="page" then c.AccountView.RegisterPage=function() return nil end
            else
                local original=c.Contracts.Register
                c.Contracts.Register=function(self,name,...) if name=="YiboMail" then return nil end; return original(self,name,...) end
            end
        end)
        local expected=mail:T(failure[2])
        Check(not mail.initialized and expected~=failure[2]
            and table.concat(env.TEST_MESSAGES," | "):find(expected,1,true),
            "translated startup registration failure: "..language.."/"..failure[1])
    end
end
print("MailForever Smoke passed: " .. checks .. " checks (real Core/Mail manifests, simulated client)")
return Boot
