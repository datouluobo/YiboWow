-- Exercise the actual combat log callback and its private cache.
local now, frames, event = 1000, {}, {}
GetServerTime=function() return now end
time=GetServerTime
strsplit=function(separator,value)
    local parts={};for part in value:gmatch('[^'..separator..']+') do parts[#parts+1]=part end
    return unpack(parts)
end
UnitName=function() return 'Player' end
GetRealmName=function() return 'Realm' end
UnitGUID=function(unit) return unit=='player' and 'Player-1-1' or nil end
CombatLogGetCurrentEventInfo=function() return unpack(event) end
CreateFrame=function()
    local f={RegisterEvent=function() end,SetScript=function(self,k,v) self[k]=v end}
    frames[#frames+1]=f;return f
end
YiboCore={Locale={Get=function(_,_,key) return key end}}
YAB={}
assert(loadfile('YiboAltoBoss/Core.lua'))('YiboAltoBoss')
local function Up(fn,key)
    for i=1,100 do local name,value=debug.getupvalue(fn,i);if name==key then return value end;if not name then break end end
    error('missing upvalue '..key)
end
local callback=frames[#frames].OnEvent
local combat=Up(callback,'HandleCombatLogEvent')
local remember=Up(combat,'RememberPersonalCombatTarget')
local cache=Up(remember,'recentPersonalCombatTargets')
Up(remember,'npcTargets')[1]={{id=1}}
local tracks,kills=0,0
YAB.TrackingV3={ApplyGUID=function() tracks=tracks+1;return false end,ConsumeDiagnosticsDirty=function() return false end}
YAB.RecordKillByNpcID=function(id) assert(id==1);kills=kills+1 end
local function Emit(kind,id,index)
    event={now,kind,false,'Player-1-1','Player',0,0,'Creature-0-1-1-1-'..id..'-'..index}
    callback(nil,'COMBAT_LOG_EVENT_UNFILTERED')
end
local function Count() local n=0;for _ in pairs(cache) do n=n+1 end;return n end
for i=1,10000 do Emit('SPELL_DAMAGE',99999,i) end
assert(Count()==0 and tracks==0,'untracked mobs must not allocate evidence or build tracking events')
for i=1,2000 do Emit('SPELL_DAMAGE',1,i) end
assert(Count()==512,'combat evidence cache has a hard capacity')
now=1046;Emit('SPELL_DAMAGE',1,2001)
assert(Count()==1,'expired escaped/despawned targets are evicted during incoming activity')
Emit('UNIT_DIED',1,2001);assert(kills==1 and Count()==0,'recent tracked kill retains attribution and releases evidence')
Emit('SPELL_DAMAGE',1,2002);now=1092;Emit('UNIT_DIED',1,2002)
assert(kills==1 and Count()==0,'expired evidence cannot complete a kill')
print('PASS: 10000 ordinary mobs allocate no combat entries; tracked cap=512; TTL/death cleanup; valid kill attribution preserved')
