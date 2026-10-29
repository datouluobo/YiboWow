-- Account phase action and summary, using the production helper functions.
local scans, states=0,0
local colors=setmetatable({}, {__index=function() return {1,1,1,1} end})
YiboCore={UITheme={Colors=colors,Table={groupHeight=1,headerHeight=1,rowHeight=1},GetCharacterMatrixColumnWidth=function() return 80 end},Locale={Get=function(_,_,key) return key end}}
local cols={}; for i=1,12 do cols[i]={realm='Realm',phaseKey='p'..i,displayId=tostring(i)} end
YAB={GetPhaseColumns=function() scans=scans+1; return cols end,GetBossPhaseState=function(_,column) states=states+1; return {observedAt=1000,phaseDisplayId=column.displayId} end,GetServerTimestamp=function() return 1000 end,GetCurrentRealm=function() return 'Realm' end}
dofile('YiboAltoBoss/AccountPage.lua')
local function upvalue(fn,name) for i=1,100 do local n,v=debug.getupvalue(fn,i); if not n then break end; if n==name then return v end end; error('missing '..name) end
local action=upvalue(YAB.RefreshAccountPage,'PickBestAction'); local summary=upvalue(YAB.RefreshAccountPage,'BuildPhaseSummary')
local snapshot=upvalue(YAB.RefreshAccountPage,'CreatePhaseSnapshot')
local bosses={}; for i=1,10 do bosses[i]={key='b'..i} end
local start=os.clock(); for i=1,500 do local get=snapshot('all'); for _,boss in ipairs(bosses) do assert(action(boss,'all',get(boss)).kind=='observed'); local s=summary(boss,'all',get(boss)); assert(s~='—') end end
print(string.format('phase 500 refreshes, 10 bosses, 12 phases: %.3f s, phase column scans=%d, state lookups=%d',os.clock()-start,scans,states))

assert(scans==500 and states==60000, 'one phase scan per refresh and one lookup per boss/phase')
local prior=states; local a=snapshot('all'); a(bosses[1]); a(bosses[1]); assert(states-prior==12); local b=snapshot('all'); b(bosses[1]); assert(states-prior==24, 'new refresh rebuilds observations')
