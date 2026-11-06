
dofile('_NonRelease/MailPerformance20261029/IdentityContextSpec.lua')
local C,A=YiboCore,YiboMail
local page={id='mail-inbox',title='Mail',fields={},scope={mode='realms'},GetEligibleCharacters=function(rows) return rows end,HasCharacterSnapshot=function() return true end}
C.AccountView._pages[page.id]=page
C.Database:GetDB().settings.accountView.selectedRealmScope='all'
A.db.byCharacter={A={records={m={state='observed',attachments={},money=10,cod=0,sender='Sender',subject='Reminder',expiresAtEstimate=GetServerTime()+60}},visibleKeys={'m'},history={},coverage={status='known',observedAt=GetServerTime()}}}
A.db.settings.loginReminderEnabled=true
A.Scanner={IsOpen=function() return false end}; A.Items={GetState=function() return {status='stale'} end}
C.Characters:InvalidateAllCache()
local timers,prints={},{}
C_Timer={After=function(delay,callback) timers[#timers+1]=callback; assert(delay==5) end}
A.Print=function(_,message) prints[#prints+1]=message end
local contextWatch=setmetatable({},{__mode='v'})
local build=C.AccountView.BuildContext
function C.AccountView:BuildContext(p,options)
    assert(options.identityOnly==true,'Login reminder must choose the lightweight context')
    local result=build(self,p,options); contextWatch[1]=result; return result
end
A.AccountPage:OnLogin(); A.AccountPage:OnLogin()
assert(#timers==1 and C.Characters._allSnapshot==nil)
table.remove(timers,1)(); collectgarbage('collect')
assert(#prints==1 and contextWatch[1]==nil and C.Characters._allSnapshot==nil,'Reminder releases its transient context without caching domain snapshots')
A.AccountPage:OnLogin(); assert(#timers==0)
C.AccountView.BuildContext=build
print('PASS: real login reminder schedules once, preserves reminders, releases context, never warms full account cache')
for _,file in ipairs({'Recipients','Items','Mists/TransferMigration'}) do dofile('YiboMail/'..file..'.lua') end
assert(A.Items:MigrateLegacyTransfers())
assert(A.Items.transferIndex==nil and next(A.Items.transfersCache)==nil and C.Characters._allSnapshot==nil,'No legacy sends means no eager directory/transit materialization')
A.db.byCharacter.A.history={{eventID='send',state='in-transit',recipient='B-Two',observedAt=100,attachments={{itemID=123,quantity=2}}}}
A:Publish('A',{}, {},'archive')
local transfer=assert(A.Items:GetTransfers('B')); assert(#transfer.records==1)
transfer.records[1].quantity=999
assert(A.Items:GetTransfers('B').records[1].quantity==2 and C.Characters._allSnapshot==nil)
assert(A.Recipients:Current().domains==nil and C.Characters._allSnapshot==nil)
print('PASS: lazy transit queries and recipient identity/faction use public projections; isolated results and full cache stays cold')
dofile('YiboMail/SendRules.lua')
local scans=0
A.db.sendRuleRevision=0
A.RuleSendController={state='idle',Invalidate=function() end,Scan=function() scans=scans+1 end}
A.RuleSendUI={Refresh=function() end}
A.SendRules:Changed(true); assert(scans==0)
A.Scanner.IsOpen=function() return true end
A.SendRules:Changed(true); assert(scans==1)
print('PASS: identity/rule changes do not scan bags before mailbox opens; opening still permits matching')
local initialize=A.InitializeDatabase
local oldCore=_G.YiboCore
for _,missing in ipairs({'character-identity','account-identity-context','character-identity-cache'}) do
    local queried=false
    _G.YiboCore={CheckAPIVersion=function() return true end,IsInitialized=function() return true end,Locale=C.Locale,
        Contracts={Register=function() end,NotifyChanged=function() end},HasCapability=function(_,name,version)
            if name==missing then queried=true; return name=='character-identity' and version<=1 end
            return true
        end}
    A.initialized=nil; A.InitializeDatabase=function() error('Missing capability must stop before saved data initialization') end
    A.Frame.RegisterEvent=function() end
    dofile('YiboMail/Bootstrap.lua'); A:Initialize()
    assert(queried and not A.initialized)
end
_G.YiboCore=oldCore; A.InitializeDatabase=initialize
print('PASS: identity v1 and missing lightweight-account capability prompt upgrade and stop before database initialization')
