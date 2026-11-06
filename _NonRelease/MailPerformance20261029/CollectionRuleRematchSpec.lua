dofile('YiboMail/_NonRelease/Tests/RuleSendSpec.lua')
local A=YiboMail
local C=A.RuleSendController
dofile('YiboMail/Mists/Queue.lua')
local Q=A.Queue
local scans,scan=0,C.Scan
C.Scan=function(self,...) scans=scans+1;return scan(self,...) end
C.state,C.scanQueued,C.scanDirty='idle',nil,nil
Q.state='running'
local history=A.db.byCharacter
for i=1,100 do C:OnEvent('BAG_UPDATE_DELAYED') end
assert(scans==0 and C.scanDirty and not C.scanQueued,'Collection bag events only invalidate the pending rule match')
Q.state='complete';Q:Notify()
assert(scans==1 and not C.scanDirty,'Terminal collection refreshes matching once against current bags')
local timers={}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
Q.state='idle';C:QueueScan();assert(#timers==1)
Q.state='running';table.remove(timers,1)()
assert(scans==1 and C.scanDirty and not C.scanQueued,'A queued rematch cannot run after collection starts')
Q.state='paused';Q.pending={};Q:Notify();assert(#timers==0)
Q.pending=nil;Q:Notify();assert(#timers==1)
table.remove(timers,1)();assert(scans==2 and not C.scanDirty,'Pause without an outstanding action flushes pending matching')
Q.state='running';C:OnEvent('BAG_UPDATE_DELAYED')
C:OnEvent('MAIL_CLOSED')
assert(not C.scanDirty)
local open=A.Scanner.IsOpen;A.Scanner.IsOpen=function() return false end
Q.state='idle';Q:Notify();assert(scans==2)
A.Scanner.IsOpen=open
Q:Notify();assert(scans==2,'Reopening does not resurrect closed-session rematches')
assert(A.db.byCharacter==history)
print('PASS: 100 collection bag events defer matching; completion/pause refresh once; queued callbacks, pending actions and close preserve live send guards')
