dofile('YiboTaskHub/_NonRelease/Tests/ActionIntegrationSpec.lua')
local addon,core=YiboTodo,YiboCore
local domainGet=core.DataDomains.Get
local reads=0
core.DataDomains.Get=function(self,id,domain)
    if domain=='professions' then reads=reads+1 end
    return domainGet(self,id,domain)
end
local nativePairs,scans=pairs,0
pairs=function(t)
    if t==addon.Catalog.recipes then scans=scans+1 end
    return nativePairs(t)
end
addon.Snapshot:Invalidate()
local snapshot=addon.Snapshot:Build()
local characters=core.Characters:GetAll({identityOnly=true})
assert(reads==#characters,'one profession domain snapshot per role per build')
assert(scans==1,'group membership is indexed once, not once per group and character')
for i=1,200 do assert(addon.Snapshot:Build()==snapshot) end
assert(reads==#characters and scans==1,'unchanged queries reuse the complete snapshot')
addon.Snapshot:Invalidate();addon.Snapshot:Build()
assert(reads==#characters*2 and scans==2,'real changes rebuild domain facts and catalog index')
pairs=nativePairs
print('PASS: one profession read per character; one recipe pass per rebuild; 200 unchanged snapshot reads add zero work')
