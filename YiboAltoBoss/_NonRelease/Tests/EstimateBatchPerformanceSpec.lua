-- Actual estimate and initialization paths; synthetic tracking samples.
local ensures=0
UnitName=function() return 'Tester' end; GetRealmName=function() return 'Realm' end
UnitLevel=function() ensures=ensures+1; return 90 end; UnitClass=function() return 'Class','MAGE' end
date=os.date; GetServerTime=function() return 1000 end; time=function() return 1000 end
wipe=function(t) for k in pairs(t) do t[k]=nil end end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
YiboCore={Locale={Get=function(_,_,key) return key end}}; YAB={}; YiboAltoBossDB={}
dofile('YiboAltoBoss/Core.lua')
local samples={}; for i=1,20 do samples[i]={bossKey='ordos',elapsedSeconds=120+i,modelEligible=true,status='complete',provenance='v3',realmKey='Realm',completedAt=900+i} end
YAB.TrackingV3={GetSamples=function() return samples end,GetPendingCount=function() return 0 end}
local bosses={'ordos','nalak','oondasta','galleon','sha_of_anger','warbringer_jade_forest','warbringer_kun_lai_summit','warbringer_townlong_steppes','warbringer_krasarang_wilds','warbringer_dread_wastes'}
local start=os.clock(); for run=1,200 do local context={}; for _,boss in ipairs(bosses) do local estimate=YAB.GetBossRespawnEstimate(boss,context); if boss=='ordos' then assert(estimate and estimate.sampleCount==20) end end end
print(string.format('estimate batches: 200 x 10 bosses: %.3f s; full database preparations=%d',os.clock()-start,ensures))


assert(ensures==200, 'one database preparation per batch')
local context={}; local a=YAB.GetBossRespawnEstimate('ordos',context); samples[20].elapsedSeconds=150
local b=YAB.GetBossRespawnEstimate('ordos',context)
assert(a.lastRespawnSampleSeconds~=b.lastRespawnSampleSeconds and b.lastRespawnSampleSeconds==150, 'sample model is recalculated within a batch')
local count=ensures; YAB.GetBossRespawnEstimate('ordos',{}); assert(ensures==count+1, 'next batch prepares again')
YAB.GetBossRespawnEstimate('ordos'); YAB.GetBossRespawnEstimate('ordos'); assert(ensures==count+3, 'standalone calls each prepare')
YAB.TrackingV3.GetPhaseState=function(_,realm,boss,phase) return {realm=realm,phaseKey=phase} end
local phaseContext={}; count=ensures
local state=YAB.GetBossPhaseState('ordos',{realm='Realm',phaseKey='p1'},phaseContext)
YAB.GetBossPhaseState('nalak',{realm='Realm',phaseKey='p1'},phaseContext)
assert(state.respawnEstimateSamples==20 and ensures==count+1, 'phase context shares real database preparation between bosses')
