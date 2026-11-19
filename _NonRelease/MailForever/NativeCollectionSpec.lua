local Boot=dofile("_NonRelease/MailForever/Harness.lua")
local e,core,mail,fire,flush,box=Boot(nil,function(e)
    local methods=getmetatable(e.UIParent).__index
    methods.GetRegions=function() return end
    methods.SetParent=function(self,parent) self.parent=parent end
    e.MailFrame=e.CreateFrame("Frame",nil,e.UIParent); e.MailFrame:Hide()
    e.InboxFrame=e.CreateFrame("Frame",nil,e.MailFrame)
    e.OpenMailFrame=e.CreateFrame("Frame",nil,e.MailFrame);e.OpenMailFrame:Hide()
    e.OpenMail_Update=nil;e.InboxFrame_Update=nil
    e.OpenMailFrame.Update=function(self) assert(self:IsShown());e.letterUpdates=(e.letterUpdates or 0)+1 end
    e.InboxFrame.Update=function(self) assert(self==e.InboxFrame);e.inboxUpdates=(e.inboxUpdates or 0)+1 end
    e.ShowUIPanel=function(frame) frame:Show() end
    e.OpenMailAttachment_OnClick=function(_,slot) e.codSlot=slot end
    e.SendMailFrame=e.CreateFrame("Frame",nil,e.MailFrame); e.SendMailFrame:Hide()
    for _,name in ipairs({"SendMailNameEditBox","SendMailSubjectEditBox","SendMailBodyEditBox","SendMailCancelButton","SendMailMailButton","SendMailMoney","SendMailCODButton"}) do
        e[name]=e.CreateFrame("Button",nil,e.SendMailFrame)
    end
    e.SendMailMailButton:SetScript("OnClick",function() end)
    e.originalSendHandler=e.SendMailMailButton:GetScript("OnClick")
    e.GetMoney=function() return 10000 end
    e.GetSendMailItem=function() return end
    e.MoneyInputFrame_GetCopper=function() return 0 end
    e.MailFrameTab1=e.CreateFrame("Button",nil,e.MailFrame)
    e.MailFrameTab2=e.CreateFrame("Button",nil,e.MailFrame)
    e.MailFrameTab_OnClick=function(_,page)
        e.InboxFrame:SetShown(page==1);e.SendMailFrame:SetShown(page==2)
    end
end)
assert(mail.initialized and mail.FEATURES.collect and not mail.NativeUI.installed)
fire("PLAYER_ENTERING_WORLD"); box.open=true;e.MailFrame:Show();fire("MAIL_SHOW");flush()
assert(mail.NativeUI.installed and mail.NativeUI.inbox:IsShown(),"Forever installs shared inbox on mailbox show")
assert(mail.NativeUI.mailboxTabs.mail and mail.NativeUI.mailboxTabs.items and mail.NativeUI.mailboxTabs.send
    and mail.NativeUI.mailboxTabs.rules,"implemented navigation is exposed")
assert(mail.NativeUI.inbox.used>0,"actual scanner snapshot renders in native rows")
assert(e.SendMailMailButton:GetScript("OnClick")==e.originalSendHandler
    and not mail.NativeUI.moneyConfirmationInstalled,"Forever retains native money-transfer confirmation")
local current=core.Characters:GetCurrent()
local entry=mail.ViewModel:GetMails({characters={current}},{})[1]
assert(mail.NativeUI:OpenMail(entry,true) and e.letterUpdates==1 and e.inboxUpdates==1,
    "modern frame methods open the native letter without legacy globals")
flush();box.headers[1].cod=10;fire("MAIL_INBOX_UPDATE");flush()
entry=mail.ViewModel:GetMails({characters={current}},{})[1]
mail.NativeUI:CollectCOD(entry,entry.mail.attachments[1])
assert(e.codSlot==1,"COD delegates to native confirmation after modern-frame update")
box.headers[1].cod=0;box.headers[1].isGM=true
e.GetInboxText=function(index) assert(index~=1,"GM mail must not be auto-read");return "ordinary" end
fire("MAIL_INBOX_UPDATE");flush()
entry=mail.ViewModel:GetMails({characters={current}},{})[1]
assert(not entry.actionable and not mail.Queue:Prepare({[mail.ViewModel:ActionID(current.id,entry.key,1)]=true},{characters={current}}),
    "GM mail is excluded from collection and automatic acknowledgement")
local closed=e.MailFrame
fire("MAIL_CLOSED");box.open=false;closed:Hide();flush()
assert(not mail.Scanner:IsOpen() and not mail.Queue.pending,"mail close disables native collection")
local denied,_,stopped=Boot(nil,function(_,c) c.ItemConfirmation.Show=nil end)
assert(not stopped.initialized and not denied.YiboMailForeverDB.byCharacter,"confirmation dependency rejected before business writes")
print("PASS: real Forever manifest installs native collection UI and renders scanner snapshot")
