local Boot=dofile("_NonRelease/MailForever/Harness.lua")
local e,core,mail,fire,flush,box,load=Boot(nil,function(e,_,box)
    box.total=3;box.headers[1].money=0;box.headers[1].count=1
    box.items[1][16]=nil
    e.C_Container.GetContainerNumSlots=function() return 0 end
    e.C_Container.GetContainerItemInfo=function() return end
    e.C_Container.GetContainerNumFreeSlots=function() return 10,0 end
    e.GetInventoryItemID=function() return end
end)
fire("PLAYER_ENTERING_WORLD");box.open=true;fire("MAIL_SHOW");flush()
local current=core.Characters:GetCurrent()
local state=mail.Items:GetState(current.id)
assert(state.status=="partial" and state.currentCount==2 and state.totalCount==3 and state.unscannedCount==1)
assert(mail.AccountPage:GetSummary(current).count=="2/3","overview cannot label partial inbox complete")
assert(mail.Items:GetByCharacter(current.id,{includeStale=false}).quantity==3,"visible attachment remains live")
for line in io.lines("YiboVault/YiboVault_Forever.toc") do
    line=line:gsub("\r","")
    if line:match("%.lua$") then load("YiboVault/"..line:gsub("\\","/"),"YiboVault") end
end
fire("ADDON_LOADED","YiboVault")
local snapshot=assert(e.YiboVault.MailProvider:GetSnapshot(current.id))
assert(snapshot.coverage.inbox.status=="partial" and snapshot.coverage.inbox.unscannedCount==1)
assert(e.YiboVault.Items:Query({sources={"mail"},includeStale=false}).totals.totalQuantity==3,"Vault counts only observed partial records")
local calls=0
e.TakeInboxItem=function(index,slot)
    assert(index==1 and slot==1);calls=calls+1
    e.C_Timer.After(0.04,function()
        box.headers[1]=box.headers[2]
        box.headers[2]={sender="New",subject="Previously unloaded",count=1,money=0,cod=0}
        box.items={[2]={[1]={id=7003,quantity=7}}};box.total=2
        fire("MAIL_SUCCESS");fire("MAIL_INBOX_UPDATE")
    end)
end
local context={characters={current}}
local entry=mail.ViewModel:GetMails(context,{})[1]
local selected={[mail.ViewModel:ActionID(current.id,entry.key,1)]=true}
assert(mail.Queue:Start(assert(mail.Queue:Prepare(selected,context))));flush()
assert(calls==1 and mail.Queue.completed==1 and mail.Queue.state=="complete","refilled visible window confirms one intended action")
assert(mail.Items:GetState(current.id).status=="known" and mail.Items:GetByCharacter(current.id).quantity==7,
    "refill reconciles newly visible content without duplicate collection")
box.count=0;box.total=1;fire("MAIL_INBOX_UPDATE");flush()
state=mail.Items:GetState(current.id)
assert(state.status=="partial" and state.unscannedCount==1 and mail.Items:GetByCharacter(current.id).quantity==0,
    "zero loaded with unseen mail is never known-empty")
print("PASS: Forever partial snapshot/overview/Vault, refilled collection window and unloaded-not-empty")
