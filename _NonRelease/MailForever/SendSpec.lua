local Boot=dofile("_NonRelease/MailForever/Harness.lua")
local clicks,sends=0,0
local fields={recipient="",subject="Parcel",body="Private draft",copper=0,cod=false}
local e,core,mail,fire,flush,box,load=Boot(nil,function(e)
    e.hooksecurefunc=function(name,callback)
        local original=e[name]
        e[name]=function(...) local result=original(...);callback(...);return result end
    end
    local function Edit(key) return {GetText=function() return fields[key] end,SetText=function(_,v) fields[key]=v end} end
    e.SendMailNameEditBox=Edit("recipient");e.SendMailSubjectEditBox=Edit("subject");e.SendMailBodyEditBox=Edit("body")
    e.SendMailCODButton={GetChecked=function() return fields.cod end,SetChecked=function(_,v) fields.cod=v end}
    e.SendMailMoney={};e.MoneyInputFrame_GetCopper=function() return fields.copper end
    e.MoneyInputFrame_SetCopper=function(_,value) fields.copper=value end
    e.GetSendMailItem=function(slot) if slot==12 then return "Item",7001,123,3 end end
    e.GetSendMailItemLink=function(slot) if slot==12 then return "item:7001" end end
    e.SendMail=function() sends=sends+1 end
    e.SendMailMailButton={IsEnabled=function() return true end,Click=function()
        clicks=clicks+1;e.SendMail(fields.recipient,fields.subject,fields.body)
    end,GetScript=function() error("Forever must dispatch native button instead of replaying script") end}
end)
e.HasNewMail=function() return true end
fire("PLAYER_ENTERING_WORLD")
assert(mail.db.mailArrivalSignals[e.TEST_GUID].awaitingScan,"unopened new mail records an arrival without fabricating a snapshot")
box.open=true;fire("MAIL_SHOW");flush()
assert(not mail.db.mailArrivalSignals[e.TEST_GUID].awaitingScan,"completed scan resolves pending arrival")
local current=core.Characters:GetCurrent()
local alt={id="Player-SendAlt",name="Receiver Second",realm=current.realm,faction=current.faction}
local cached=core.Characters.GetAllCached
core.Characters.GetAllCached=function() return {current,alt} end
mail.Compose:WriteDraftFields({recipient=alt.name.."-"..alt.realm})
assert(fields.recipient==alt.name,"native Forever sends only the complete two-part name")
local action=assert(mail.Compose:PrepareSendAction());action()
assert(clicks==1 and sends==1 and mail.Compose.pendingSend.attachments[1].slot==12,"native dispatch captures final attachment slot")
fire("MAIL_SEND_SUCCESS")
assert(not mail.Compose.pendingSend,"success clears pending send")
local transfers=assert(mail.Items:GetTransfers(alt.id))
assert(#transfers.records==1 and transfers.records[1].quantity==3,"successful send exposes recipient transfer through public API")
local history=mail.db.byCharacter[current.id].history
local sent=history[#history]
assert(sent.state=="in-transit" and sent.body==nil,"persist sending facts without private body")
mail.Compose:WriteDraftFields({recipient=alt.name.."-"..alt.realm,subject="Failed"});action=assert(mail.Compose:PrepareSendAction());action();fire("MAIL_FAILED")
assert(history[#history].state=="unverified" and #mail.Items:GetTransfers(alt.id).records==1,"failed send never creates a successful transfer")
e.C_Container.GetContainerNumSlots=function() return 0 end
e.C_Container.GetContainerItemInfo=function() return end
e.C_Container.GetContainerNumFreeSlots=function() return 10,0 end
e.GetInventoryItemID=function() return end
for line in io.lines("YiboVault/YiboVault_Forever.toc") do
    line=line:gsub("\r","")
    if line:match("%.lua$") then load("YiboVault/"..line:gsub("\\","/"),"YiboVault") end
end
fire("ADDON_LOADED","YiboVault")
local vault=e.YiboVault
assert(vault.initialized,"actual Forever Vault initializes")
local snapshot=assert(vault.MailProvider:GetSnapshot(alt.id))
assert(#snapshot.records==1 and snapshot.records[1].state=="in-transit" and snapshot.coverage.transit.recordCount==1,
    "Forever Vault reads offline recipient transfers exclusively through Core contract")
snapshot.records[1].quantity=999
assert(vault.MailProvider:GetSnapshot(alt.id).records[1].quantity==3,"consumer snapshot remains isolated")
core.Characters.GetAllCached=cached
print("PASS: Forever native-button dispatch, 12th attachment, send success/failure, public transfer and body privacy")
