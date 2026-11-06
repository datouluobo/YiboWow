dofile('YiboMail/_NonRelease/Tests/RuleSendSpec.lua')
local addon,c=YiboMail,YiboMail.RuleSendController
local now,timers,changes=100,{},0
GetTime=function() return now end
C_Timer={After=function(delay,callback) timers[#timers+1]={delay=delay,run=callback} end}
c.Guard=function() return true end
c.Fingerprint=function() return 'draft' end
c.Changed=function() changes=changes+1 end
addon.Recipients.CanRuleSend=function() return true end
SendMailFrame_Update=function() end
SendMailMailButton={GetScript=function() return function() end end,IsEnabled=function() return true end}
local function Send()
    c.state,c.packet,c.fingerprint,c.revision='ready',nil,'draft',addon.db.sendRuleRevision
    assert(c:Send());return timers[#timers]
end
local first=Send();assert(c.state=='sending' and first.delay>15)
c:OnEvent('MAIL_CLOSED');local second=Send()
now=now+16;local previous=changes;first.run()
assert(c.state=='sending' and changes==previous,'stale send deadline cannot touch a new send at the same clock tick')
second.run();assert(c.state=='invalid','active send still times out without an OnUpdate')
local third=Send();c:OnEvent('MAIL_CLOSED');previous=changes;now=now+16;third.run()
assert(c.state=='idle' and changes==previous,'close cancels the logical deadline')

dofile('YiboMail/_NonRelease/Tests/NativeInboxSpec.lua')
addon=YiboMail
local native=addon.NativeUI
timers={};C_Timer={After=function(delay,callback) timers[#timers+1]={delay=delay,run=callback} end}
local character=addon.Core.Characters:GetCurrent({identityOnly=true})
local empty={signature='empty',inboxIndex=1,attachments={},money=0,cod=0}
addon.Queue.state,addon.Queue.pending='idle',nil
addon.Scanner.ReadVisible=function() return {empty},1,1 end
addon.Scanner.Schedule=function() end
native.RefreshInbox=function() end
InboxItemCanDelete=function() return true end
DeleteInboxItem=function() end
native.deleting=nil
local entry={character=character,mail=empty}
native:DeleteEmptyMail(entry);local oldTicket=native.deleting;local oldTimeout=timers[#timers]
assert(oldTicket and oldTimeout.delay>12)
native.deleting=nil;native:DeleteEmptyMail(entry);local newTicket=native.deleting;local newTimeout=timers[#timers]
oldTimeout.run();assert(native.deleting==newTicket,'stale delete timeout cannot clear a later deletion')
newTimeout.run();assert(not native.deleting and native.inbox.notice)
assert(not addon.Frame.hooks or not addon.Frame.hooks.OnUpdate,'native UI has no idle per-frame timeout hook')
print('PASS: send/delete single deadlines; stale callback isolation; mailbox close; no native idle OnUpdate')
