
dofile('_NonRelease/MailPerformance20261029/IdentityCacheSpec.lua')
local C=YiboCore;YiboMailDB={}
dofile('YiboMail/Namespace.lua');dofile('YiboMail/Store.lua');dofile('YiboMail/Recipients.lua');dofile('YiboMail/Items.lua')
local A=YiboMail;A.Core=C;A.FEATURES.account=false;A:InitializeDatabase()
A.db.byCharacter.A={records={},visibleKeys={},coverage={},history={{state='in-transit',recipient='B-Two',eventID='send',observedAt=10,attachments={{itemID=123,quantity=2}}}}}
A:Publish('A',{}, {},'archive')
C.Characters:InvalidateAllCache()
local get,builds=C.Characters.GetAll,0
C.Characters.GetAll=function(self,...) builds=builds+1;return get(self,...) end
local encode,identities=A.Encode,0
A.Encode=function(values)
    if #values==3 and (values[3]=='One' or values[3]=='Two') then identities=identities+1 end
    return encode(values)
end
for i=1,100 do
    assert(#A.Items:GetTransfers('B').records==1)
    A.Items:GetTransfers('A'); A.Items:GetTransfers('Hidden')
end
print('DIRECTORY COUNTS',builds,identities,C.Characters._allSnapshot==nil)
assert(builds==1 and identities==3 and C.Characters._allSnapshot==nil,'Recipients share one identity directory and one fingerprint')
for i=1,10 do A:Publish('A',{}, {},'archive');assert(#A.Items:GetTransfers('B').records==1) end
assert(builds==1 and identities==3,'Mail revisions do not rebuild an unchanged directory')
C.Database:GetDB().characters.byID.B.name='Updated';C.Characters:InvalidateAllCache()
assert(#A.Items:GetTransfers('B').records==0 and builds==2 and identities==6,'Owner invalidation is visible before any listener-order-dependent event')
A.Items:ReleaseCaches(true);assert(A.Items.transferDirectory==nil and A.Items.transferKey==nil)
print('PASS: 300 recipient queries build one directory/fingerprint; mail epochs reuse it, identity changes invalidate immediately, close releases Mail projection')
