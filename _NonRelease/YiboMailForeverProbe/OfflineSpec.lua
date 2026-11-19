local function Boot(project)
    local scripts, hooks = {}, {}
    local env = {WOW_PROJECT_ID=project, WOW_PROJECT_CAMELOT=18, SlashCmdList={}, time=function() return 1 end,
        GetBuildInfo=function() return "1.60.1", "test", "date", 16001 end,
        CreateFrame=function() return {RegisterEvent=function() end, SetScript=function(_,name,fn) scripts[name]=fn end} end}
    setmetatable(env,{__index=_G}); env._G=env
    env.hooksecurefunc=function(name, callback) hooks[name]=callback end
    for _, name in ipairs({"TakeInboxItem","TakeInboxMoney","ReturnInboxItem","DeleteInboxItem","SendMail","ClickSendMailItemButton"}) do
        env[name]=function() error("probe attempted mutation") end
    end
    local chunk=assert(loadfile("_NonRelease/YiboMailForeverProbe/Probe.lua")); setfenv(chunk,env); chunk()
    scripts.OnEvent(nil,"ADDON_LOADED","YiboMailForeverProbe")
    return env,scripts,hooks
end
local wrong=Boot(19); assert(not wrong.YiboMailForeverProbeDB and not wrong.SlashCmdList.YIBOMAILFOREVERPROBE)
local env,scripts,hooks=Boot(18)
assert(#env.YiboMailForeverProbeDB.entries==0)
env.SlashCmdList.YIBOMAILFOREVERPROBE("on")
hooks.SendMail("Secret-Realm","Secret subject","Secret body")
local action=env.YiboMailForeverProbeDB.entries[2]
assert(action.kind=="action" and action.data.name=="SendMail" and action.data.index==nil)
assert(action.data[1]==nil and action.data.subject==nil and action.data.body==nil)
scripts.OnEvent(nil,"MAIL_FAILED","Secret error")
assert(env.YiboMailForeverProbeDB.entries[3].data.name=="MAIL_FAILED")
env.SlashCmdList.YIBOMAILFOREVERPROBE("off")
local count=#env.YiboMailForeverProbeDB.entries; hooks.TakeInboxItem(1,2)
assert(#env.YiboMailForeverProbeDB.entries==count)
env.MailFrame={IsShown=function() return true end}
env.SendMailFrame={IsShown=function() return true end}
env.SendMailNameEditBox={GetText=function() return "Private recipient" end}
env.SendMailSubjectEditBox={GetText=function() return "Private subject" end}
env.SendMailBodyEditBox={GetText=function() error("Body text must never be read") end}
env.SendMailMoney={}; env.MoneyInputFrame_GetCopper=function() return 123 end
env.SendMailCODButton={GetChecked=function() return true end}
env.ATTACHMENTS_MAX_SEND,env.ATTACHMENTS_MAX_RECEIVE=12,16
env.GetInboxNumItems=function() return 0,0 end
env.GetSendMailItem=function(slot) if slot==12 then return "Private item",42,1,3 end end
env.GetSendMailItemLink=function(slot) return "item:42" end
local mouseDown
env.SendMailMailButton={HookScript=function(_,event,fn) assert(event=="OnMouseDown"); mouseDown=fn end}
env.SlashCmdList.YIBOMAILFOREVERPROBE("on")
local send=env.YiboMailForeverProbeDB.entries[#env.YiboMailForeverProbeDB.entries].data.send
assert(send.copper==123 and send.cod and send.items[1].slot==12 and send.items[1].quantity==3)
assert(type(send.recipientHash)=="number" and send.recipient==nil and send.subject==nil and send.body==nil)
mouseDown(); assert(env.YiboMailForeverProbeDB.entries[#env.YiboMailForeverProbeDB.entries].data.reason=="send-mouse-down")
env.GetInboxNumItems=function() return 1,1 end
env.GetInboxHeaderInfo=function() return nil,nil,"Private sender","Private subject",0,0,30,nil,false,false,nil,true,false end
env.GetInboxItem=function() return nil end
env.InboxItemCanDelete=function() return false end
env.GetInboxText=function() error("Received body text must never be read") end
env.SlashCmdList.YIBOMAILFOREVERPROBE("sample")
local header=env.YiboMailForeverProbeDB.entries[#env.YiboMailForeverProbeDB.entries].data.headers[1]
assert(header.canReply==true and header.isGM==false and header.canDelete==false)
assert(type(header.sender)=="number" and type(header.subject)=="number")
env.SlashCmdList.YIBOMAILFOREVERPROBE("off")
env.GetInboxNumItems=function() error("Inactive probe must not read") end
scripts.OnEvent(nil,"MAIL_INBOX_UPDATE")
print("PASS: probe target protection, inactive default, mutation guards, no SendMail payload, event payload exclusion, stop")
