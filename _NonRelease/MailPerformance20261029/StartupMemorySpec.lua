
-- Login with a hidden mailbox must not construct the native mailbox UI.
local frames,hooks=0,0
function CreateFrame() frames=frames+1; return {} end
MailFrame={IsShown=function() return false end,HookScript=function() hooks=hooks+1 end}
InboxFrame={}; SendMailFrame={}; SendMailNameEditBox={}; SendMailCancelButton={}
function InCombatLockdown() return false end
for _,file in ipairs({'Namespace','Store','NativeUI','Mists/InboxUI'}) do dofile('YiboMail/'..file..'.lua') end
local A=YiboMail; local loaded=frames
for i=1,10 do A.NativeUI:Install() end
assert(frames==loaded and hooks==1 and not A.NativeUI.installed and not A.NativeUI.readyInbox)
print('PASS: login with hidden mailbox constructs zero mailbox controls; one deferred install hook')
local function Clone(v) if type(v)~='table' then return v end; local c={}; for k,x in pairs(v) do c[k]=Clone(x) end; return c end
local function Equal(a,b)
    if a==b then return true end
    if type(a)~='table' or type(b)~='table' then return false end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local item={itemID=123,variantKey='link:item:123:1',itemLink='item:123:1',quantity=2,attachmentIndex=1,name='Item',extra={binding='account'}}
YiboMailDB={byCharacter={},settings={},mailNoticeVersion=1}
for i=1,20 do
    local first,second=Clone(item),Clone(item)
    first.extra.binding='soulbound' -- Same index key; differing metadata must remain distinct.
    YiboMailDB.byCharacter['c'..i]={records={m={state='observed',attachments={Clone(item),first}}},visibleKeys={'m'},coverage={},history={
        {eventID='h'..i,sourceMailKey='m',state='discovered',attachments={second},mail={attachments={Clone(second)}}},
        {eventID='c'..i,sourceMailKey='m',state='collected-archived',item=Clone(item),mail={attachments={Clone(item)}}},
    }}
end
local original=Clone(YiboMailDB.byCharacter)
assert(A:InitializeDatabase())
assert(Equal(original,A.db.byCharacter),'Every stored value and event must survive startup sharing')
local first=A.db.byCharacter.c1.records.m.attachments
local other=A.db.byCharacter.c2.records.m.attachments
assert(first[1]==other[1] and first[2]==other[2] and first[1]~=first[2])
assert(A.db.byCharacter.c1.history[2].item==first[1])
assert(A:ShareStoredAttachments()==0,'Sharing is idempotent and keeps no persistent index')
local record={state='in-transit',attachments={Clone(item)}}
A:AppendHistory(A.db.byCharacter.c1,record)
record.attachments[1].quantity=999
assert(A.db.byCharacter.c1.history[3].attachments[1].quantity==2,'New history still isolates caller-owned input')
-- Unknown fields, unknown identities and distinct links must not be discarded.
local unknown={quantity=1,annotation={value='retained'}}
local variant=Clone(item); variant.itemLink='item:123:2'
A.db.byCharacter.c1.records.m.attachments={unknown,variant,Clone(item)}
local values=Clone(A.db.byCharacter)
A:ShareStoredAttachments(); assert(Equal(values,A.db.byCharacter))
assert(A.db.byCharacter.c1.records.m.attachments[2]~=first[1])
local malformed={itemID=1,quantity=0/0,attachmentIndex=0/0}
A.db.byCharacter.c1.history[4]={state='unknown',item=malformed}
assert(pcall(function() A:ShareStoredAttachments() end))
assert(A.db.byCharacter.c1.history[4].item==malformed,'Invalid legacy metadata remains untouched')
print('PASS: startup shares equal immutable observations only; full values/events, divergent metadata, input isolation and unknown legacy data preserved')
