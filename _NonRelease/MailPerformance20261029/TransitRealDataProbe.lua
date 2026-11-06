-- Read-only replay; SavedVariables is evaluated without io/os/debug/tool access.
local function LoadSaved(path)
    local env={};local f=assert(loadfile(path));setfenv(f,env)
    local ticks=0;debug.sethook(function() ticks=ticks+1;assert(ticks<150,'saved budget exceeded') end,'',1000000)
    local ok,err=pcall(f);debug.sethook();assert(ok,err);return env
end
local m=LoadSaved(arg[1]);local ce=LoadSaved(arg[2]);local coreDB
for k,v in pairs(ce) do if type(v)=='table' and v.characters and v.characters.byID then coreDB=v;break end end
assert(coreDB)
YiboCore={Capabilities={Register=function() end},Database={GetDB=function() return coreDB end}}
dofile('YiboCore/Util/Defaults.lua');dofile('YiboCore/Data/Characters.lua')
function CreateFrame() return {} end
function GetServerTime() return os.time() end
YiboMailDB=assert(m.YiboMailDB);dofile('YiboMail/Namespace.lua')
local A=YiboMail;A.Core=YiboCore;A.T=function(_,key,...) return key end
local first,latest
for id,snapshot in pairs(YiboMailDB.byCharacter) do
    local at=snapshot.coverage and snapshot.coverage.observedAt or 0
    if not latest or at>latest then first,latest=id,at end
end
YiboCore.Characters.GetCurrentID=function() return first end
dofile('YiboMail/Store.lua');A:InitializeDatabase()
dofile('YiboMail/Recipients.lua')
if arg[3]=='before' then dofile('_NonRelease/MailPerformance20261029/TransitR5-before-Items.lua') else dofile('YiboMail/Items.lua') end
local function Fingerprint(value)
    local a,b=1,0
    local function Bytes(s)
        s=tostring(#s)..':'..s
        for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    end
    local Visit
    Visit=function(v)
        local kind=type(v); Bytes(kind)
        if kind=='table' then
            local keys={}; for k in pairs(v) do keys[#keys+1]=k end
            table.sort(keys,function(x,y) if type(x)~=type(y) then return type(x)<type(y) end; return tostring(x)<tostring(y) end)
            Bytes(tostring(#keys))
            for _,k in ipairs(keys) do Visit(k); Visit(v[k]) end
        else Bytes(tostring(v)) end
    end
    Visit(value); return string.format('%08x',b*65536+a)
end
local stats={characters=0,history=0,sends=0,archive=0,records=0}
for _,s in pairs(A.db.byCharacter) do
    stats.characters=stats.characters+1
    for _ in pairs(s.records or {}) do stats.records=stats.records+1 end
    for _,h in ipairs(s.history or {}) do
        stats.history=stats.history+1
        if h.state=='in-transit' then stats.sends=stats.sends+1 end
        if h.state=='collected-archived' then stats.archive=stats.archive+1 end
    end
end
local rows=YiboCore.Characters:GetAllCached({identityOnly=true})
local function Measure(n)
    collectgarbage('collect');collectgarbage('stop')
    local before=collectgarbage('count');local started=os.clock();local records=0
    for i=1,n do
        A:Publish(first,{}, {},'scan',false)
        for _,role in ipairs(rows) do local result=assert(A.Items:GetTransfers(role.id));records=records+#result.records end
    end
    local allocated=collectgarbage('count')-before
    collectgarbage('restart');collectgarbage('collect')
    return allocated/1024,os.clock()-started,records
end
collectgarbage('collect');local base=collectgarbage('count')
local one,t,records=Measure(1);local ten,t10=Measure(10)
for i=1,3 do collectgarbage('collect') end
local retained=(collectgarbage('count')-base)/1024
local results={}
for _,role in ipairs(rows) do results[role.id]=assert(A.Items:GetTransfers(role.id)) end
local fingerprint=Fingerprint(results)
print(string.format('{"characters":%d,"history":%d,"sends":%d,"archive":%d,"records":%d,"oneEpochMB":%.3f,"tenEpochMB":%.3f,"seconds":%.4f,"tenSeconds":%.4f,"outputRows":%d,"retainedMB":%.3f,"fingerprint":"%s"}',stats.characters,stats.history,stats.sends,stats.archive,stats.records,one,ten,t,t10,records,retained,fingerprint))
