
dofile('YiboMail/_NonRelease/Tests/WorkspaceSpec.lua')
local A=YiboMail; local role=YiboCore.Characters:GetAllCached()[1]
local snapshot=A.db.byCharacter[role.id];snapshot.coverage.revision=100001
local visits=0;local used=A.ViewModel.IsCollectedEmptyMail
A.ViewModel.IsCollectedEmptyMail=function(self,...) visits=visits+1;return used(self,...) end
local first=A.AccountPage:GetSummary(role);local scanned=visits
assert(scanned==#snapshot.visibleKeys)
for i=1,100 do assert(A.AccountPage:GetSummary(role).count==first.count) end
assert(visits==scanned,'One owner version/time should scan the mailbox once across all summary consumers')
first._counts.expired=999
assert(A.AccountPage:GetSummary(role)._counts.expired~=999,'Returned display values cannot mutate cached business statistics')
snapshot.records[snapshot.visibleKeys[1]].money=10000;snapshot.coverage.revision=snapshot.coverage.revision+1
assert(A.AccountPage:GetSummary(role).money~=first.money and visits==scanned*2)
local time=GetServerTime;GetServerTime=function() return time()+1 end
A.AccountPage:GetSummary(role);assert(visits==scanned*3)
GetServerTime=time
local getState=A.Items.GetState;A.Items.GetState=function() return {status='error'} end
assert(A.AccountPage:GetSummary(role).status:find(A:T('UI.TEXT_0562'),1,true),'Live status still queried even when raw summary statistics can be reused')
A.Items.GetState=getState
local old=setmetatable({snapshot.records,snapshot.visibleKeys},{__mode="v"})
snapshot.records={};snapshot.visibleKeys={}
collectgarbage("collect");collectgarbage("collect")
assert(old[1]==nil and old[2]==nil,"Dormant summary cache must not retain replaced mailbox maps")
print('PASS: version/time-bound raw summary scans once; live status, expiry clock, owner changes and returned-value isolation preserved')
