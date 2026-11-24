-- Production lockout page refresh with a simulated frame surface.
local copies, binds, statusCalls = 0, {}, 0
local function frame()
 return setmetatable({}, {__index=function(t,k) if k=="label" or k=="cells" or k=="text" or k=="tooltipTitle" then return nil end; local f=function() end; rawset(t,k,f); return f end})
end
CreateFrame=function() return frame() end
local colors={}; setmetatable(colors,{__index=function() return {1,1,1,1} end})
local theme={Colors=colors,Font={body=1},Space={lg=2,xs=1},Table={headerHeight=20,cellPadding=6},
 GetMatrixInsets=function() return {left=0,right=0,bottom=0} end,MeasureText=function() return 10 end,
 CreateMatrixHeader=function() return frame() end,SetMatrixHeader=function() end,CreateText=function() return frame() end,BindTooltip=function() end,
 ApplyPixelBackdrop=function(_,f) return f end,ApplyPixelRule=function(_,t) return t end,GetPixelSize=function(_,_,n) return n or 1 end,
 SetPixelAnchor=function(_,r,fn) if fn then fn() end end,
 CreatePixelBorder=function(_,f,o) rawset(f,'pixelSides',o.sides); return {SetColor=function() end,SetShown=function() end,SetSides=function() end} end}
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
YiboAltoBossDB={settings={}}; dofile('YiboAltoBoss/Common/LockoutsPage.lua')
dofile("YiboAltoBoss/Mists/LockoutsPage.lua")
local instance={businessTabs=frame(),header=frame(),scroll=frame(),body=frame(),headers={},rows={},
 lockoutFilters={SetShown=function() end,expansion={menu=frame()},kind={menu=frame()}}}
local function Refresh() YAB.RefreshLockoutsPage(instance,{preview=true}) end
local start=os.clock(); for i=1,20 do Refresh() end
print(string.format('lockout page 20 refreshes, 20 characters, 10 columns, 100 catalog entries: %.3f s; catalog copies=%d status=%d binds=%d',os.clock()-start,copies,statusCalls,#binds))
assert(statusCalls==4000 and #binds==4000 and binds[1]=='C1:instance:1' and binds[200]=='C20:instance:10')
assert(copies==20, 'one catalog copy per visible refresh')
local s1, s2 = instance.rows[1].cells[1].pixelSides, instance.rows[1].cells[2].pixelSides
assert(s1.left and s1.top and s1.right and s1.bottom and s2.top and s2.right and s2.bottom and not s2.left, 'adjacent lockout cells share one vertical boundary')
YAB.GoalTargets.ref=nil; Refresh(); assert(copies==20, 'disabled goal actions skip catalog')
YAB.GoalTargets.ref=true; local savedKeys=keys; keys={}; Refresh(); assert(copies==20, 'empty roster skips catalog'); keys=savedKeys
defs[1].id='changed'; binds={}; Refresh()
assert(copies==21 and binds[1]=='C1:changed', 'next refresh uses updated catalog')
defs[1]={kind='instance', id='first', mapID=1}; defs[2]={kind='instance', id='planned', mapID=1}
columns[1].plannedCatalogID='planned'; binds={}; Refresh()
assert(binds[1]=='C1:first', 'first matching catalog entry retains original precedence')
