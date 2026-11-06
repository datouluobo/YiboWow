
function CreateFrame() return {} end
function GetServerTime() return 1000 end
YiboMailDB={mailNoticeVersion=1,byCharacter={}}
dofile('YiboMail/Namespace.lua');dofile('YiboMail/Store.lua')
local A=YiboMail
local function Item() return {itemID=1,variantKey='item:1',quantity=2,attachmentIndex=1} end
for i=1,20 do
    YiboMailDB.byCharacter['c'..i]={records={m={attachments={Item()}}},visibleKeys={'m'},coverage={},history={{state='discovered',eventID='h'..i,mail={attachments={Item()}},attachments={Item()}}}}
end
local expected=A.Copy(YiboMailDB.byCharacter)
A:InitializeDatabase()
local first=A.db.byCharacter.c1.records.m.attachments
assert(first==A.db.byCharacter.c2.records.m.attachments and first==A.db.byCharacter.c1.history[1].attachments)
local function Equal(a,b)
 if a==b then return true end
 if type(a)~='table' or type(b)~='table' then return false end
 for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
assert(Equal(expected,A.db.byCharacter))
local distinct={Item()};distinct.annotation={value='kept'}
A.db.byCharacter.c1.history[1].attachments=distinct
A:ShareStoredAttachments()
assert(A.db.byCharacter.c1.history[1].attachments==distinct and distinct~=first,'Array metadata must not disappear into an equal-looking item list')
local source={state='in-transit',attachments={Item()}}
A:AppendHistory(A.db.byCharacter.c1,source);source.attachments[1].quantity=999
assert(A.db.byCharacter.c1.history[2].attachments[1].quantity==2)
local items,arrays=A:ShareStoredAttachments();items,arrays=A:ShareStoredAttachments();assert(items==0 and arrays==0)
print('PASS: equal readonly attachment arrays share on startup; every value/event, unknown array metadata and input isolation preserved; idempotent')
