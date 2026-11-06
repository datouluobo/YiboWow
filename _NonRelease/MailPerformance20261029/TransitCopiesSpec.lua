
dofile('YiboVault/_NonRelease/Tests/MailProviderSpec.lua')
local M,V=YiboMail,YiboVault
local recipient
for _,r in ipairs(M.Core.Characters:GetAll({identityOnly=true})) do if r.id=='B' then recipient=r.name..'-'..r.realm end end
M:AddHistory('A',{state='in-transit',recipient=recipient,attachments={{itemID=45678,quantity=3}},observedAt=GetServerTime()+1000})
local api=V.MailProvider.api
assert(api:GetTransfers('B'))
local copy,count=M.Copy,0
M.Copy=function(value,...)
    if type(value)=='table' and value.apiVersion==1 and type(value.records)=='table' then count=count+1 end
    return copy(value,...)
end
local result=assert(api:GetTransfers('B'))
assert(count==0,'Core service boundary must not pre-copy the entire cached transfer payload inside Mail')
local record
for _,r in ipairs(result.records) do if r.itemID==45678 then record=r end end
assert(record and record.quantity==3); record.quantity=999
local public=M.Items:GetTransfers('B'); assert(count==1,'Direct API retains its isolation copy')
for _,r in ipairs(public.records) do if r.itemID==45678 then assert(r.quantity==3); r.quantity=555 end end
local again=api:GetTransfers('B')
for _,r in ipairs(again.records) do if r.itemID==45678 then assert(r.quantity==3) end end
assert(count==1)
M.Copy=copy
print('PASS: transit service performs no redundant Mail payload copy; real Core contract and direct public API both isolate callers')
