
-- Read-only disk snapshot replay. No game process or SavedVariables writes.
local function Stats(db)
    local n={characters=0,records=0,history=0,items=0,uniqueTables=0}; local seen={}
    local function Visit(t)
        if type(t)~='table' or seen[t] then return end
        seen[t]=true; n.uniqueTables=n.uniqueTables+1
        for _,v in pairs(t) do Visit(v) end
    end
    Visit(db)
    for _,s in pairs(db.byCharacter or {}) do
        n.characters=n.characters+1
        for _,mail in pairs(s.records or {}) do n.records=n.records+1; n.items=n.items+#(mail.attachments or {}) end
        for _,event in ipairs(s.history or {}) do n.history=n.history+1 end
    end
    return n
end

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
collectgarbage('collect'); local base=collectgarbage('count')
local saved={}
do
    local chunk=assert(loadfile(arg[1])); setfenv(chunk,saved)
    local ticks=0; debug.sethook(function() ticks=ticks+1; assert(ticks<100,'SavedVariables instruction budget exceeded') end,'',1000000)
    local ok,err=pcall(chunk); debug.sethook(); assert(ok,err)
end
local db=assert(saved.YiboMailDB); saved=nil
collectgarbage('collect'); local raw=collectgarbage('count')-base
local counts=Stats(db)
YiboMailDB=db
function CreateFrame() return {} end
for _,file in ipairs({'Namespace','Store'}) do dofile('YiboMail/'..file..'.lua') end
local share=YiboMail.ShareStoredAttachments
YiboMail.ShareStoredAttachments=function() end
assert(YiboMail:InitializeDatabase())
YiboMail.ShareStoredAttachments=share
collectgarbage('collect'); local previous=collectgarbage('count')-base
local previousCounts=Stats(db)
local fingerprint=Fingerprint(db)
local started=os.clock(); local reused=YiboMail:ShareStoredAttachments(); local seconds=os.clock()-started
local unchanged=Fingerprint(db)==fingerprint; assert(unchanged,'Storage values changed during sharing')
collectgarbage('collect'); local initialized=collectgarbage('count')-base
local after=Stats(db)
assert(counts.records==after.records and counts.history==after.history)
print(string.format('{"rawMB":%.3f,"previousInitializedMB":%.3f,"initializedMB":%.3f,"characters":%d,"records":%d,"history":%d,"visibleRecordItems":%d,"rawTables":%d,"previousTables":%d,"initializedTables":%d,"reusedItems":%d,"sharingSeconds":%.4f,"valuesPreserved":true}',raw/1024,previous/1024,initialized/1024,counts.characters,counts.records,counts.history,counts.items,counts.uniqueTables,previousCounts.uniqueTables,after.uniqueTables,reused,seconds))
