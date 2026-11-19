local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local e, core, mail, fire, flush, box = Boot()
fire("PLAYER_ENTERING_WORLD"); box.open=true; fire("MAIL_SHOW"); flush()
local calls=0
e.C_Container.GetContainerNumFreeSlots=function() return 10,0 end
e.TakeInboxItem=function(index,slot)
    calls=calls+1
    e.C_Timer.After(0.04,function()
        box.items[index][slot]=nil
        box.headers[index].count=box.headers[index].count-1
        mail.Scanner:OnEvent("MAIL_INBOX_UPDATE")
        mail.Queue:OnEvent("MAIL_SUCCESS")
        mail.Queue:OnEvent("MAIL_INBOX_UPDATE")
    end)
end
local character=core.Characters:GetCurrent()
local context={characters={character}}
local entry=mail.ViewModel:GetMails(context,{})[1]
local selection={[mail.ViewModel:ActionID(character.id,entry.key,1)]=true}
local actions=assert(mail.Queue:Prepare(selection,context))
assert(mail.Queue:Start(actions)); flush()
assert(calls==1 and mail.Queue.completed==1 and mail.Queue.state=="complete", "shared queue confirms Forever item delta")
assert(mail.Items:GetByCharacter(character.id).quantity==2, "full reconciliation publishes remaining attachment")
local history=mail.db.byCharacter[character.id].history
assert(#history>0,"confirmed operation records history")
entry=mail.ViewModel:GetMails(context,{})[1]
selection={[mail.ViewModel:ActionID(character.id,entry.key,16)]=true}
e.TakeInboxItem=function() calls=calls+1 end
actions=assert(mail.Queue:Prepare(selection,context)); assert(mail.Queue:Start(actions))
mail.Scanner:OnEvent("MAIL_CLOSED"); box.open=false; flush()
assert(not mail.Queue.pending and mail.Queue.pauseCode=="mailbox-closed", "closing archives uncertain result and cancels queue")
e.GetInboxText=function() return "" end
e.InboxItemCanDelete=function() return true end
local empty={attachments={},money=0,cod=0,inboxIndex=1}
assert(mail.CollectionRuntime:CanDeleteEmpty(empty))
e.GetInboxText=function() return "system message" end
assert(not mail.CollectionRuntime:CanDeleteEmpty(empty), "Forever does not inherit MoP system-letter deletion")
print("PASS: Forever shared collection, authoritative delta/history, close cancellation and empty-letter policy")
