
function CreateFrame() return {} end
local stamp=1000
function GetServerTime() return stamp end
local char={id='A',name='Alpha',realm='Realm'}
local function Boot(path)
    YiboMailDB={}; dofile('YiboMail/Namespace.lua'); dofile(path)
    local A=YiboMail; A.FEATURES.account=false
    A.Core={Characters={GetCurrent=function() return char end}}
    A.emitted={}
    A.Items={OnPublish=function() end,Events={Emit=function(_,payload) A.emitted[#A.emitted+1]=A.Copy(payload) end}}
    A:InitializeDatabase(); return A
end
local old=Boot('_NonRelease/MailPerformance20261029/CollectionR2-before-Store.lua')
local new=Boot('YiboMail/Store.lua')
local function Equal(a,b)
    if a==b then return true end
    if type(a)~='table' or type(b)~='table' then return false end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Mail(sig,id)
    return {signature=sig,inboxIndex=0,subject=sig,sender='Sender',money=0,cod=0,attachments={{itemID=id,variantKey='item:'..id,quantity=1,attachmentIndex=1}}}
end
local function Commit(list,collecting)
    stamp=stamp+1
    for i,m in ipairs(list) do m.inboxIndex=i end
    for _,A in ipairs({old,new}) do
        A.Queue=collecting and {pending={targetIndex=1,expected={signature=list[1].signature},action={characterID='A',original={firstSeenAt=1000}}}} or nil
        A:CommitScan(char,A.Copy(list),{status=#list==0 and 'known-empty' or 'known',observedAt=stamp,currentCount=#list,totalCount=#list})
    end
    assert(Equal(old.db,new.db),'Optimized groups must preserve every saved value, key, state and history event')
    assert(Equal(old.emitted,new.emitted),'Public changed-key/item notifications must match the frozen Store')
end
Commit({Mail('A',1),Mail('B',2),Mail('B',2),Mail('C',3)})
Commit({Mail('A',1),Mail('B',2),Mail('B',2),Mail('C',3)})
Commit({Mail('A-partial',4),Mail('B',2),Mail('C',3)},true)
Commit({Mail('B',2),Mail('B',2),Mail('B',2),Mail('D',5)})
Commit({Mail('A',1),Mail('D',5)})
for _,A in ipairs({old,new}) do A.db.byCharacter.A.visibleKeys[#A.db.byCharacter.A.visibleKeys+1]='missing-record' end
Commit({Mail('D',5),Mail('New',6)})
Commit({})
print('PASS: unchanged/new/returned/collected/duplicate multiplicity and dangling visible keys match frozen Store values and complete history exactly')
