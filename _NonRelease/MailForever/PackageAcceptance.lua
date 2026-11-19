-- Execute extracted player packages, including saved data from the old package.
local root,target,baseline,vaultRoot=assert(arg[1]),assert(arg[2]),arg[3],arg[4]
if baseline=="-" then baseline=nil end
local forever=target=="Forever"
local realLines,realLoadfile=io.lines,loadfile
local active,loads=root,{}
io.lines=function(path,...)
    if path=="YiboMail/YiboMail_Forever.toc" or path=="YiboMail/YiboMail_Mists.toc" then return realLines(active.."/YiboMail.toc") end
    if vaultRoot and path=="YiboVault/package.toc" then return realLines(vaultRoot.."/YiboVault.toc") end
    return realLines(path,...)
end
loadfile=function(path,...)
    if path:sub(1,9)=="YiboMail/" then
        local relative=path:sub(10);loads[relative]=(loads[relative] or 0)+1
        return realLoadfile(active.."/"..relative,...)
    end
    if vaultRoot and path:sub(1,10)=="YiboVault/" then return realLoadfile(vaultRoot.."/"..path:sub(11),...) end
    return realLoadfile(path,...)
end
local Boot=dofile("_NonRelease/MailForever/Harness.lua")
local function Configure(e)
    if not forever then
        e.CheckInbox=function() end
        e.MailFrame=e.CreateFrame("Frame",nil,e.UIParent);e.MailFrame:Hide()
    end
end
local function Serialize(value)
    if type(value)=="string" then return string.format("%q",value) end
    if type(value)~="table" then assert(type(value)=="number" or type(value)=="boolean" or value==nil);return tostring(value) end
    local parts={"{"}
    for key,item in pairs(value) do parts[#parts+1]="["..Serialize(key).."]="..Serialize(item).."," end
    return table.concat(parts).."}"
end
local saved
if baseline then
    active=baseline
    local e,_,mail,fire,flush,box=Boot(nil,Configure,forever)
    assert(mail.initialized,"old player package initializes")
    fire("PLAYER_ENTERING_WORLD");box.open=true;if e.MailFrame then e.MailFrame:Show() end;fire("MAIL_SHOW");flush()
    assert(mail.db.byCharacter[e.TEST_GUID],"old package collected its own snapshot")
    mail.db.settings.historyDays=45
    fire("MAIL_CLOSED");box.open=false
    local chunk=assert(loadstring("return "..Serialize(mail.db)));setfenv(chunk,{})
    saved=chunk()
end
active,loads=root,{}
local e,core,mail,fire,flush,box,load=Boot(saved,Configure,forever)
assert(mail.initialized,"new player package initializes")
if saved then
    assert(mail.db.settings.historyDays==45,"old settings survive serialized reload")
    assert(mail.Items:GetByCharacter(e.TEST_GUID,{includeStale=true}).quantity==5,"old attachments survive serialized reload")
    assert(mail.Items:GetState(e.TEST_GUID).status=="stale","restored snapshot is not advertised as live")
end
for path,count in pairs(loads) do assert(count==1,"duplicate package load: "..path) end
for _,path in ipairs({"Bootstrap.lua","Forever/Bootstrap.lua","Forever/AccountPage.lua","Mists/Queue.lua","Mists/Returns.lua",
    "Mists/InboxUI.lua","Mists/ReturnUI.lua","Mists/TransferMigration.lua","Mists/RecipientRuntime.lua","Mists/RuleCategories.lua"}) do
    assert(not loads[path],"old residual executed: "..path)
end
local listeners=#mail.Items.Events.listeners
local registration=assert(core.Contracts:Resolve("mail.items",{major=1,minMinor=1})).registrationRef
assert(mail:Initialize() and mail:Initialize())
assert(#mail.Items.Events.listeners==listeners,"repeat initialization preserves subscriptions")
assert(core.Contracts:Resolve("mail.items",{major=1,minMinor=1}).registrationRef==registration,"repeat initialization preserves service registration")
fire("PLAYER_ENTERING_WORLD");box.open=true;if e.MailFrame then e.MailFrame:Show() end;fire("MAIL_SHOW");flush()
assert(mail.Items:GetByCharacter(e.TEST_GUID).quantity==5,"new package reads inbox")
if forever then
    local items=mail.Items:GetByCharacter(e.TEST_GUID).records
    assert(items[1].name=="NativeItem7001" and items[1].texture==1,"player package retains native attachment metadata")
    box.headers[2].subject="Expired: Item [A]+(B)%"
    e.AUCTION_EXPIRED_MAIL_SUBJECT="Expired: %s"
    fire("MAIL_INBOX_UPDATE");flush()
    assert(mail.Scanner:ReadTarget(2).auctionMail,"player package recognizes invoice-free auction mail")
end
assert(mail.FEATURES.send and mail.FEATURES.rules and mail.FEATURES.collect and mail.Items:HasCapability("mail-items.transfers",1))
assert(forever and e.YiboMailDB.sentinel=="mists" or not forever and e.YiboMailForeverDB.sentinel=="forever","other target store remains untouched")
if vaultRoot then
    e.C_Container.GetContainerNumSlots=function() return 0 end
    e.C_Container.GetContainerItemInfo=function() return end
    e.C_Container.GetContainerNumFreeSlots=function() return 10,0 end
    e.GetInventoryItemID=function() return end
    for line in io.lines("YiboVault/package.toc") do
        line=line:gsub("\r","")
        if line:match("%.lua$") then load("YiboVault/"..line:gsub("\\","/"),"YiboVault") end
    end
    fire("ADDON_LOADED","YiboVault")
    assert(e.YiboVault.initialized,"player Vault package initializes")
    local snapshot=assert(e.YiboVault.MailProvider:GetSnapshot(e.TEST_GUID))
    local quantity=0;for _,item in ipairs(snapshot.records) do quantity=quantity+item.quantity end
    assert(quantity==5,"player Mail and Vault packages integrate through Core contract")
end
if forever then
    assert(mail.Items:GetTransfers(e.TEST_GUID))
    assert(mail.Items.transferDirectory,"player package can build transit queries")
    fire("MAIL_CLOSED");box.open=false;flush()
    assert(not mail.Items.transferDirectory and not mail.Items.transferEvidence,"player package releases derived data on close")
    assert(mail.Items:GetState(e.TEST_GUID).status=="stale","player package preserves a historical inbox after close")
    assert(mail.Items:GetByCharacter(e.TEST_GUID,{includeStale=true}).quantity==5,"close preserves saved attachments")
    if mail.FEATURES.currencyAttachments then
        local itemInfo, itemLink = e.GetInboxItem, e.GetInboxItemLink
        e.GetInboxItem = function(index, slot)
            if index==1 and slot==16 then return "Token7001",7001,654,25,1,true,true end
            return itemInfo(index,slot)
        end
        e.GetInboxItemLink = function(index,slot)
            if index==1 and slot==16 then return "currency:7001" end
            return itemLink(index,slot)
        end
        box.open=true;fire("MAIL_SHOW");flush()
        local currencies=mail.CacheModel:GetMails({characters={core.Characters:GetCurrent()}},{kind="currency"})
        assert(#currencies==1 and currencies[1].mail.attachments[2].currencyID==7001)
        assert(mail.Items:GetByCharacter(e.TEST_GUID).quantity==3,"package currency and same-ID item remain separate")
        local typedSave=assert(loadstring("return "..Serialize(mail.db)))()
        local nextEnv,nextCore,nextMail=Boot(typedSave,Configure,forever)
        assert(nextMail.Items:GetByCharacter(nextEnv.TEST_GUID,{includeStale=true}).quantity==3)
        assert(#nextMail.CacheModel:GetMails({characters={nextCore.Characters:GetCurrent()}},{kind="currency"})==1,
            "player package reload preserves typed currency snapshots")
    end
end
io.lines,loadfile=realLines,realLoadfile
print("PASS: "..target.." player package startup, "..(baseline and "old package save/overlay/reload" or "clean install")..", live scan and idempotency")
