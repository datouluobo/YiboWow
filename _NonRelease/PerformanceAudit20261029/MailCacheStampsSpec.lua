dofile('YiboVault/_NonRelease/Tests/MailProviderSpec.lua')
local mail,vault=YiboMail,YiboVault
local provider=vault.MailProvider
provider:GetSnapshot('B',true)
local queries=0
local contracts=vault.Core.Contracts
local call=contracts.Call
function contracts:Call(caller,descriptor,method,request)
    if request and request.characterID=='B' and (method=='GetByCharacter' or method=='GetTransfers') then queries=queries+1 end
    return call(self,caller,descriptor,method,request)
end
for i=1,100 do
    mail:Publish('A',{}, {},'status',true)
    provider:GetSnapshot('B')
end
assert(queries==0,'another role status-only publications must not copy this mailbox')
mail:Publish('A',{}, {},'archive',false)
provider:GetSnapshot('B')
assert(queries==1,'real global transfer-evidence changes must invalidate other recipients')
queries=0;vault.Core.Events:Fire('CHARACTER_UPDATED','B')
assert(queries==1,'directory changes invalidate transfer matching independently of Mail revisions')
local state=mail.Items.GetState
mail.Items.GetState=function(self,id)
    local value=state(self,id);if value then value.transfersRevision=nil end;return value
end
provider.cache={};provider:GetSnapshot('B');queries=0
mail:Publish('A',{}, {},'status',true);provider:GetSnapshot('B')
assert(queries==1,'older providers without optional stamps retain global-revision invalidation')
print('PASS: 100 unrelated status publications copy B zero times; real transfer changes invalidate once; older-provider fallback preserved')
