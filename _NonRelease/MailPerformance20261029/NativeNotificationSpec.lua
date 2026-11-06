
dofile('YiboMail/_NonRelease/Tests/NativeInboxSpec.lua')
local A,N=YiboMail,YiboMail.NativeUI
local callback
A.Items.Events.RegisterSignal=function(_,owner,fn) assert(owner==N);callback=fn;return true end
A.FEATURES.send=false
N.RestoreBrowsePageWhenShown=function() end
N.installed=nil;MailFrame:Show();InboxFrame:Show();N:Install()
assert(callback)
local refreshes=0
N.Refresh=function() refreshes=refreshes+1 end
A.Queue.state,A.Queue.notifyPending='running',true
callback();assert(refreshes==0,'Committed queue progress already has an authoritative refresh pending')
A.Queue.notifyPending=nil;callback();assert(refreshes==1)
A.Queue.state,A.Queue.notifyPending='paused',true;callback();assert(refreshes==2,'Paused and terminal views still refresh')
print('PASS: native signal skips only duplicated pending running-queue refresh; ordinary and paused observations still refresh')

A.Scanner.committingObservation=true;callback();assert(refreshes==2,'Scanner owns exactly one refresh after committing an observation')
A.Scanner.committingObservation=nil;callback();assert(refreshes==3,'Ordinary notifications continue after a scan')
