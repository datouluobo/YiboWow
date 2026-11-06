local now=2000000000
GetServerTime=function() return now end
dofile('YiboTodo/Namespace.lua')
dofile('YiboTodo/Database.lua')
local todo=YiboTodo
todo.Database:Initialize();todo.initialized=true
local cutoff=now-90*86400
local provider=todo.Database:GetProvider('C','daily-quest',true)
provider.days={old={observedAt=cutoff-2,state='completed'},boundary={observedAt=cutoff,state='in-progress'},
    recent={observedAt=now,state='actionable'},unknown={state='completed'}}
provider.cookingDays={baseline={observedAt=cutoff-100,state='completed'}}
provider.activityDays={one={old={nextResetAt=cutoff-1},new={nextResetAt=now+86400}},two={old={observedAt=1}}}
provider.activityDays.one.reobserved={nextResetAt=cutoff-100,observedAt=now}
provider.observations={cooldown={readyAt=now+500}}
-- Force one maintenance pass after fixture population.
now=now+3600
assert(todo.Database:PruneProviderHistory(provider,now)==3)
assert(not provider.days.old and not provider.days.boundary and provider.days.recent and provider.days.unknown)
assert(provider.cookingDays.baseline and provider.activityDays.two.old,'last eligibility baselines survive retention')
assert(not provider.activityDays.one.old and provider.activityDays.one.new)
assert(provider.activityDays.one.reobserved,'recent evidence overrides an older expiry timestamp')
assert(provider.observations.cooldown.readyAt==now-3600+500,'current cooldown facts are untouched')
provider.days.newOld={observedAt=1}
assert(todo.Database:PruneProviderHistory(provider,now)==0 and provider.days.newOld,'maintenance is throttled')
now=now+3600;todo.Database:GetProvider('C','daily-quest',false)
assert(not provider.days.newOld,'normal provider access runs due maintenance')

YiboTaskHub={Now=function() return now end,db={goals={revision=7,byID={}}}}
dofile('YiboTaskHub/Common/Goals.lua')
local hub=YiboTaskHub
local boundary=now-90*86400
local goal={state='active',lastCompletedCycle='cycle',intent={repeatPolicy='maintain'},history={
    {at=boundary-1,state='completed'},{at=boundary,state='completed'},{at=now,state='reopened'},{state='unknown-date'}}}
hub.db.goals.byID.x=goal
hub.db.goals.byID.legacy={history='unrecognized-history'}
hub.db.goals.byID.sparse={history={[1]={at=1},[3]={at=now}}}
assert(hub.Goals:PruneHistory(now)==1 and #goal.history==3)
assert(goal.history[1].at==boundary and goal.history[3].state=='unknown-date')
assert(goal.state=='active' and goal.lastCompletedCycle=='cycle' and goal.intent.repeatPolicy=='maintain')
assert(hub.db.goals.revision==8 and hub.Goals:PruneHistory(now)==0)
assert(hub.db.goals.byID.legacy.history=='unrecognized-history','unrecognized history remains untouched')
assert(hub.db.goals.byID.sparse.history[3].at==now,'sparse legacy arrays are not truncated')
print('PASS: 90-day history bounds, exact cutoff, unknown dates, eligibility baseline, live maintenance throttling; goals/current evidence preserved')
