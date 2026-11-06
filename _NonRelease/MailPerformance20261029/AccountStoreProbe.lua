
local env={}
do
    local f=assert(loadfile(arg[1])); setfenv(f,env)
    local ticks=0; debug.sethook(function() ticks=ticks+1; assert(ticks<100) end,'',1000000)
    local ok,e=pcall(f); debug.sethook(); assert(ok,e)
end
YiboCore={Capabilities={Register=function() end}}
dofile('YiboCore/Util/Defaults.lua'); dofile('YiboCore/Data/Characters.lua')
local C=YiboCore
for name,db in pairs(env) do
    if type(name)=='string' and name:match('^YiboCore[%w_]*DB$') and type(db)=='table' and db.characters and db.characters.byID then
        C.Database={GetDB=function() return db end}; C.Characters:InvalidateAllCache()
        collectgarbage('collect'); collectgarbage('stop'); local before=collectgarbage('count')
        local rows=C.Characters:GetAllCached(); local fullKB=collectgarbage('count')-before; local count=#rows
        rows=nil; C.Characters:InvalidateAllCache(); collectgarbage('restart'); collectgarbage('collect')
        collectgarbage('stop'); before=collectgarbage('count')
        local identity=C.Characters:GetAll({identityOnly=true}); local identityKB=collectgarbage('count')-before
        assert(#identity==count and C.Characters._allSnapshot==nil)
        collectgarbage('restart')
        print(string.format('{"store":"%s","characters":%d,"fullCopyKB":%.3f,"identityCopyKB":%.3f}',name,count,fullKB,identityKB))
    end
end
