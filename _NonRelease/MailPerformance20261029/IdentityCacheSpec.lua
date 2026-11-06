
dofile('_NonRelease/MailPerformance20261029/IdentityContextSpec.lua')
local C=YiboCore
C.Characters:InvalidateAllCache()
local get,count=C.Characters.GetAll,0
C.Characters.GetAll=function(self,options) count=count+1;return get(self,options) end
local directory=C.Characters:GetAllCached({identityOnly=true})
for i=1,1000 do assert(C.Characters:GetAllCached({identityOnly=true})==directory) end
assert(count==1 and #directory==3 and C.Characters._allSnapshot==nil)
for _,row in ipairs(directory) do assert(row.domains==nil) end
local mutable=C.Characters:GetAll({identityOnly=true});mutable[1].name='caller change'
assert(directory[1].name~='caller change')
local db=C.Database:GetDB();db.characters.byID.A.name='Renamed'
C.Characters:InvalidateAllCache()
local fresh=C.Characters:GetAllCached({identityOnly=true})
assert(fresh~=directory and fresh[1].name=='Renamed' and directory[1].name=='A')
assert(C.Characters:GetAllCached()[1].domains,'Default full-directory contract remains intact')
print('PASS: 1000 identity-cache reads build once; fresh mutable projection isolation, invalidation before reads, and default full directory preserved')
