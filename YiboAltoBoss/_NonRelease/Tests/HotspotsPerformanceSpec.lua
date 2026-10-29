-- Run with Lua 5.1 from the repository root; counters cover production functions.
local function upvalue(fn, name)
 for i=1,100 do local n,v=debug.getupvalue(fn,i); if not n then break end; if n==name then return v end end
 error('missing upvalue '..name)
end
local units, splits, now = 0, 0, 1000
UnitName=function() return 'Tester' end; GetRealmName=function() return 'Realm' end
UnitGUID=function(unit) units=units+1; return unit=='player' and 'Player-1' or nil end
GetServerTime=function() return now end; time=os.time
strsplit=function(_, value) splits=splits+1; local t={}; for s in (value..'-'):gmatch('(.-)%-') do t[#t+1]=s end; return unpack(t) end
YiboCore={Locale={Get=function(_,_,key) return key end}}
YAB={}; YiboAltoBossDB={}; local frames={}
CreateFrame=function() local f={}; function f:RegisterEvent() end; function f:SetScript(_,cb) self.cb=cb end; frames[#frames+1]=f; return f end
local combat={0,'SPELL_DAMAGE',false,'Player-1',false,false,false,'Creature-0-0-0-0-999-1'}
CombatLogGetCurrentEventInfo=function() return unpack(combat) end
dofile('YiboAltoBoss/Core.lua')
local handler=upvalue(frames[1].cb,'HandleCombatLogEvent')
local start=os.clock(); for i=1,100000 do handler() end
print(string.format('combat 100000 ordinary damage: %.3f s, UnitGUID=%d strsplit=%d',os.clock()-start,units,splits))
local targets=upvalue(upvalue(handler,'RememberLiveBossFromCombat'),'npcTargets'); targets[999]={{key='test'}}
local observed=0; YAB.TrackingV3={ApplyGUID=function(_,guid) observed=observed+1; assert(guid==combat[8]); return false end,ConsumeDiagnosticsDirty=function() return false end}
handler(); assert(observed==1,'tracked damage still observed')
local recent=upvalue(upvalue(handler,'HasRecentPersonalCombatEvidence'),'recentPersonalCombatTargets')
assert(recent[combat[8]]==now,'personal damage evidence retained')
local killed=0; YAB.RecordKillByNpcID=function(id) assert(id==999); killed=killed+1 end
YAB.TrackingV3.ApplyGUID=function() return false end
combat[2]='UNIT_DIED'; handler(); assert(killed==1 and not recent[combat[8]],'death consumes personal evidence')
-- Actual target projection, using an immutable contract snapshot.
local gets=0; local catalogToken={}; local definitions={}
local config={autoDisplay=true,targets={C={}}}
for i=1,30 do local key='b'..i; config.targets.C[i]={active=true,catalogID=key}; definitions[key]={bossKey=key} end
YiboCore.Characters={ResolveLegacyKey=function(_,key) return key end}
YAB={PlannedTargets={providerRef=true,Configuration=function() return config end},TargetCatalog={value=catalogToken,Get=function(_,id) gets=gets+1; return definitions[id] end},GetBossList=function() return {} end,GetAllBossList=function() return {} end,GetLockoutColumns=function() return {} end,GetLockoutStatus=function() end,GetLockoutTooltip=function() end}
dofile('YiboAltoBoss/Common/TargetProjection.lua')
start=os.clock(); for i=1,10000 do local ok,id,target=YAB.PlannedTargets:IsPlanned('C','b30'); assert(ok and id=='C' and target.catalogID=='b30') end
print(string.format('target 10000 lookups, 30 goals: %.3f s, catalog Get=%d',os.clock()-start,gets))
local plans=YAB.PlannedTargets
assert(not plans:IsPlanned('C','missing'), 'missing target remains absent')
definitions.b30={bossKey='changed'}; YAB.TargetCatalog.value={}
assert(not plans:IsPlanned('C','b30') and plans:IsPlanned('C','changed'), 'catalog replacement invalidates index')
config={autoDisplay=true, targets={C={{active=true,catalogID='b1'}}}}
assert(plans:IsPlanned('C','b1') and not plans:IsPlanned('C','changed'), 'new configuration replaces index')
config.autoDisplay=false; assert(not plans:IsPlanned('C','b1'), 'disabled projection stays hidden')
-- Saved lockout scan with one instance and ten encounters.
local resolutions=0
YiboAltoBossDB={characters={},settings={}}; YAB={LockoutLocaleReady=true, GetCurrentCharKey=function() return 'Tester-Realm' end, TargetCatalog={ResolveSavedEncounter=function(_,_,_,name) resolutions=resolutions+1; return tonumber(name) end,ObserveLegacyLockout=function() return false end}}
GetNumSavedInstances=function() return 1 end
GetSavedInstanceInfo=function() return 'Dungeon',1,500,1,true,false,nil,nil,5,'Normal',10,nil,nil,34 end
GetSavedInstanceEncounterInfo=function(_,i) if i<=10 then return tostring(i),nil,true end end
GetDifficultyInfo=function() return 'Normal' end
frames={}; GetInstanceInfo=function() return nil, 'none' end; dofile('YiboAltoBoss/InstanceLockouts.lua')
start=os.clock(); for i=1,1000 do YAB.RefreshInstanceLockouts() end
print(string.format('lockout 1000 scans, 10 encounters: %.3f s, encounter resolutions=%d',os.clock()-start,resolutions))
assert(resolutions==10000, 'unchanged directory resolves each encounter once')
YAB.TargetCatalog.ObserveLegacyLockout=function() return true end
YAB.RefreshInstanceLockouts(); assert(resolutions==10020, 'changed directory resolves again')
assert(YiboAltoBossDB.characters['Tester-Realm'].instanceLockouts['34:1'].bosses[10].encounterID==10, 'resolved encounter retained')


-- Directory lookups over a cached catalog, including ambiguity checks.
YAB={}; dofile('YiboAltoBoss/Common/TargetCatalog.lua')
local catalog=YAB.TargetCatalog; local entries={}
for map=1,100 do local encounters={}; for i=1,10 do encounters[i]={id=map*100+i,name='Boss'..i,aliases={'Alias'..i}} end; entries[map]={kind='instance',mapID=map,difficulties={{id=1,complete=true,encounters=encounters}}} end
catalog.value={targets=entries}
start=os.clock(); for i=1,10000 do assert(catalog:ResolveSavedEncounter(99,1,'Alias10')==9910) end
print(string.format('directory 10000 lookups, 100 maps: %.3f s',os.clock()-start))
entries[#entries+1]={kind='instance',mapID=99,difficulties={{id=1,complete=true,encounters={{id=7,name='Other',aliases={'Alias10'}}}}}}
catalog.value={targets=entries}
assert(catalog:ResolveSavedEncounter(99,1,'Alias10')==nil, 'ambiguous aliases remain unresolved')
assert(catalog:ResolveSavedEncounter(99,1,'Boss1')==9901, 'unambiguous names remain resolved')
assert(catalog:ResolveSavedEncounter(99,2,'Boss1')==nil, 'difficulty remains isolated')
catalog:Invalidate(); assert(catalog.savedEncounterIndex==nil, 'invalidation clears directory index')
