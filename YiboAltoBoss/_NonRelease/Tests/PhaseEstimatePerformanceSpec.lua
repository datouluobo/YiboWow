-- Production phase-state path; mocked expensive sample model with stable output.
local function upvalue(fn,name) for i=1,100 do local n,v=debug.getupvalue(fn,i); if not n then break end; if n==name then return v end end; error(name) end
UnitName=function() return 'Tester' end; GetRealmName=function() return 'Realm' end; time=function() return 1000 end
YiboCore={Locale={Get=function(_,_,key) return key end}}; YAB={}; YiboAltoBossDB={worldState={realms={}}}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
dofile('YiboAltoBoss/Core.lua')
local byKey=upvalue(upvalue(YAB.GetBossPhaseState,'GetBossDefinition'),'bossByKey')
for i=1,10 do byKey['b'..i]={key='b'..i} end
local phaseReads, estimates=0,0
YAB.TrackingV3={GetPhaseState=function(_,_,boss,phase) phaseReads=phaseReads+1; if phase=='missing' then return nil end; return {observedAt=1000,phaseKey=phase} end}
YAB.GetBossRespawnEstimate=function() estimates=estimates+1; local n=0; for i=1,200 do n=n+i end; return {estimateSeconds=n,sampleCount=3} end
local start=os.clock()
for run=1,200 do local context={}; for boss=1,10 do for phase=1,12 do local state=YAB.GetBossPhaseState('b'..boss,{realm='Realm',phaseKey='p'..phase},context); assert(state.respawnEstimateSeconds==20100 and state.respawnEstimateSamples==3) end end end
print(string.format('phase estimates: 200 refreshes, 10 bosses, 12 phases: %.3f s, state reads=%d, estimates=%d',os.clock()-start,phaseReads,estimates))

assert(estimates==2000 and phaseReads==24000, 'one estimate per boss per refresh')
local context={}; local prior=estimates
assert(not YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='missing'},context) and estimates==prior,'missing phase does not compute estimate')
local state=YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='p1'},context)
assert(state.respawnEstimateSeconds==20100 and estimates==prior+1)
YAB.GetBossRespawnEstimate=function() estimates=estimates+1; return nil end
local fresh={}; local a=YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='p1'},fresh); local b=YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='p2'},fresh)
assert(a.respawnEstimateSeconds==nil and b.respawnEstimateSeconds==nil and estimates==prior+2, 'no estimate is cached within the refresh')
YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='p1'},{}); assert(estimates==prior+3, 'next refresh recalculates')
YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='p1'}); YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='p1'}); assert(estimates==prior+5, 'unscoped callers remain uncached')
local clocks=0; time=function() clocks=clocks+1; return 1000 end
local shared={}; YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='p1'},shared); YAB.GetBossPhaseState('b2',{realm='Realm',phaseKey='p2'},shared)
assert(clocks==1, 'legacy world cleanup runs once per synchronous view')
YAB.GetBossPhaseState('b1',{realm='Realm',phaseKey='p1'},{}); assert(clocks==2, 'next view repeats legacy cleanup')
