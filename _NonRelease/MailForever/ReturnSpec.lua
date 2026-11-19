local Boot=dofile("_NonRelease/MailForever/Harness.lua")
local e,core,mail,fire,flush,box=Boot()
local header=e.GetInboxHeaderInfo
local reply,gm,deletable,invoice=true,false,false,nil
e.GetInboxHeaderInfo=function(index)
    local _,_,sender,subject,money,cod,days,count,read,returned=header(index)
    return nil,nil,sender,subject,money,cod,days,count,read,returned,nil,reply,gm
end
e.InboxItemCanDelete=function() return deletable end
e.GetInboxInvoiceInfo=function() return invoice end
local calls=0
e.ReturnInboxItem=function(index)
    calls=calls+1
    e.C_Timer.After(0.04,function()
        table.remove(box.headers,index);box.items={};box.count=box.count-1;box.total=box.total-1
        fire("MAIL_SUCCESS");fire("MAIL_INBOX_UPDATE")
    end)
end
fire("PLAYER_ENTERING_WORLD");box.open=true;fire("MAIL_SHOW");flush()
local function Current() return assert(mail.Scanner:ReadTarget(1)) end
assert(mail.Returns:CanReturn(Current()),"native sender and return permission admitted")
reply=false;assert(not mail.Returns:CanReturn(Current()),"disabled reply blocked")
reply=true;gm=true;assert(not mail.Returns:CanReturn(Current()),"GM letter blocked")
gm=false;invoice="seller";assert(not mail.Returns:CanReturn(Current()),"invoice letter blocked")
invoice=nil;deletable=nil;assert(not mail.Returns:CanReturn(Current()),"unknown native permission blocked")
deletable=false;mail.Scanner:Scan(false)
local current=core.Characters:GetCurrent();local context={characters={current}}
local entry=mail.ViewModel:GetMails(context,{})[1]
local selection={[mail.Returns:MailID(entry)]=true}
local plan=assert(mail.Returns:Prepare(selection,context));assert(mail.Queue:StartReturn(plan));flush()
assert(calls==1 and mail.Queue.completed==1 and mail.Queue.state=="complete","Forever event wiring confirms return")
local found=false
for _,item in ipairs(mail.db.byCharacter[current.id].history) do if item.state=="returned-archived" then found=true end end
assert(found,"only confirmed return becomes archived history")
print("PASS: Forever return permission/GM/invoice guards and real lifecycle return/history confirmation")
