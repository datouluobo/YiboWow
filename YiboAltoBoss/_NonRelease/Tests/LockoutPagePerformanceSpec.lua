-- Production lockout page refresh with a simulated frame surface.
local copies, binds, statusCalls = 0, {}, 0
local function frame()
 return setmetatable({}, {__index=function(t,k) if k=="label" or k=="cells" or k=="text" then return nil end; local f=function() end; rawset(t,k,f); return f end})
end
CreateFrame=function() return frame() end
local colors={}; setmetatable(colors,{__index=function() return {1,1,1,1} end})
local theme={Colors=colors,Font={body=1},Space={lg=2,xs=1},Table={headerHeight=20},
 GetMatrixInsets=function() return {left=0,right=0,bottom=0} end,MeasureText=function() return 10 end,
 CreateMatrixHeader=function() return frame() end,SetMatrixHeader=function() end,CreateText=function() return frame() end,BindTooltip=function() end}
YiboCore={UITheme=theme,Locale={Get=function(_,_,key) return key end},AccountView={GetScrollSurfaceWidth=function() return 2000 end,GetColumnPage=function(_,_,_,columns) return columns,{} end,UpdateColumnPager=function() end}}
local keys,columns,defs={},{},{}
for i=1,20 do keys[i]='C'..i end
for i=1,10 do columns[i]={instanceID=i,name='Instance'..i,difficultyID=1}; defs[i]={kind='instance',id='instance:'..i,mapID=i} end
for i=11,100 do defs[i]={kind='instance',id='instance:'..i,mapID=i,metadata={encounters={1,2,3,4,5,6,7,8,9,10}}} end
local function copy(x) if type(x)~='table' then return x end local r={}; for k,v in pairs(x) do r[k]=copy(v) end; return r end
YAB={GetAccountCharacterKeys=function() return keys end,GetLockoutColumns=function() return columns end,
 GetLockoutStatus=function() statusCalls=statusCalls+1; return 'clear','ok' end, GetLockoutTooltip=function() return {} end,
 FormatCharacterName=function(key) return key end,GetCharacterIdentity=function() return {} end,
 TargetCatalog={Query=function() copies=copies+1; return {targets=copy(defs)} end},
 GoalTargets={ref=true,Bind=function(_,_,key,target) binds[#binds+1]=key..':'..target.catalogID end}}
YiboAltoBossDB={settings={}}; dofile('YiboAltoBoss/LockoutsPage.lua')
local instance={businessTabs=frame(),header=frame(),scroll=frame(),body=frame(),headers={},rows={}}
local start=os.clock(); for i=1,20 do YAB.RefreshLockoutsPage(instance,{}) end
print(string.format('lockout page 20 refreshes, 20 characters, 10 columns, 100 catalog entries: %.3f s; catalog copies=%d status=%d binds=%d',os.clock()-start,copies,statusCalls,#binds))
assert(statusCalls==4000 and #binds==4000 and binds[1]=='C1:instance:1' and binds[200]=='C20:instance:10')
assert(copies==20, 'one catalog copy per visible refresh')
YAB.GoalTargets.ref=nil; YAB.RefreshLockoutsPage(instance,{}); assert(copies==20, 'disabled goal actions skip catalog')
YAB.GoalTargets.ref=true; local savedKeys=keys; keys={}; YAB.RefreshLockoutsPage(instance,{}); assert(copies==20, 'empty roster skips catalog'); keys=savedKeys
defs[1].id='changed'; binds={}; YAB.RefreshLockoutsPage(instance,{})
assert(copies==21 and binds[1]=='C1:changed', 'next refresh uses updated catalog')
defs[1]={kind='instance', id='first', mapID=1}; defs[2]={kind='instance', id='planned', mapID=1}
columns[1].plannedCatalogID='planned'; binds={}; YAB.RefreshLockoutsPage(instance,{})
assert(binds[1]=='C1:first', 'first matching catalog entry retains original precedence')
