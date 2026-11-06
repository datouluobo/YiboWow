local Renderer=dofile('_NonRelease/PerformanceAudit20261028/MinimapComputeSpec.lua')
local before=Renderer('_NonRelease/PerformanceAudit20261028/MinimapRenderer-before-compute.lua')
local after=Renderer('YiboBeastPaths/MinimapRenderer.lua')
before.rotate,after.rotate=true,true
before:Draw();after:Draw()
local state
for i=1,100 do
    local name,value=debug.getupvalue(after.addon.RefreshMinimapLayer,i)
    if name=='minimapState' then state=value;break end
end
local projection=assert(state).routesByMap[376][1].projection
for i=1,100 do
    before.angle,after.angle=i*0.07331,i*0.07331
    local old,new=before:Draw(),after:Draw()
    assert(#old==#new,'rotating line count')
    for j=1,#old do for k=1,5 do assert(math.abs(old[j][k]-new[j][k])<0.000001) end end
    assert(state.routesByMap[376][1].projection==projection,'rotation reuses smoothed geometry')
end
for _,scene in ipairs({before,after}) do
    scene.footprints={}
    for i=1,100 do scene.footprints[i]={mapID=376,x=0.2+i*0.00113,y=0.217+i*0.00071} end
    scene.addon.GetMinimapNearbyPointLimit=function() return 3 end
    scene.addon:InvalidateMinimapRouteCache();scene:Draw(true)
end
local function Footprints(scene)
    local result={}
    for _,f in ipairs(scene.frames) do if f.icon and f.shown then result[#result+1]={f.x,f.y} end end
    return result
end
local a,b=Footprints(before),Footprints(after)
assert(#a==3 and #b==3)
for i=1,3 do for k=1,2 do assert(math.abs(a[i][k]-b[i][k])<0.000001,'nearest footprint selection matches full sort') end end
before.x,after.x=100000,100000
assert(#before:Draw()==0 and #after:Draw()==0,'off-screen routes remain invisible')
print('PASS: 100 rotations preserve coordinates and reuse one projection; nearest 3 of 100 match full sort; distant clipping agrees')
