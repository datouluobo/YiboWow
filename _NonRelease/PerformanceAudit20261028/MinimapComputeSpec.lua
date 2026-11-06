-- Compare actual old/new renderers under identical simulated geometry/native APIs.
local function Renderer(path)
    local scene={x=17.37,y=19.81,angle=0,rotate=false,radius=100,w=183,h=177,frames={},worldReads=0}
    local noop=function() end
    local methods={SetAllPoints=noop,SetFrameStrata=noop,SetFrameLevel=noop,EnableMouse=noop,
        SetTexture=function(self,v) self.texture=v end,SetBlendMode=noop,SetTexCoord=noop,
        SetVertexColor=noop,RegisterEvent=noop,GetFrameLevel=function() return 1 end,
        SetScript=function(self,k,v) self[k]=v end,ClearAllPoints=noop,
        SetSize=function(self,w,h) self.w,self.h=w,h end,
        SetPoint=function(self,_,_,_,x,y) self.x,self.y=x,y end,
        SetRotation=function(self,a) self.angle=a end,
        GetWidth=function() return scene.w end,GetHeight=function() return scene.h end,
        Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,
        IsVisible=function() return true end,GetZoom=function() return 0 end}
    local function Object() return setmetatable({}, {__index=methods}) end
    methods.CreateTexture=Object
    local env=setmetatable({}, {__index=_G});env._G=env
    env.CreateFrame=function() local f=Object();scene.frames[#scene.frames+1]=f;return f end
    env.wipe=function(t) for k in pairs(t) do t[k]=nil end end
    env.Minimap=Object()
    env.GetCVar=function(k) return k=='rotateMinimap' and (scene.rotate and '1' or '0') or '0' end
    env.GetPlayerFacing=function() return scene.angle end
    env.C_Minimap={GetViewRadius=function() return scene.radius end}
    env.C_Map={GetMapInfo=function() return nil end}
    local hbd={GetPlayerWorldPosition=function() return scene.x,scene.y,1 end,
        GetPlayerZone=function() return 376 end,
        GetWorldCoordinatesFromZone=function(_,x,y)
            scene.worldReads=scene.worldReads+1
            if scene.failFootprints and (x==0.3 or x==0.5) then return nil end
            return x*100,y*100,1
        end}
    env.LibStub=function() return hbd end
    local points={}
    for i=0,120 do points[#points+1]={x=i/87,y=0.23+math.sin(i/8)*0.17} end
    local ns={pets={[1]={mapID=376}}}
    env.YiboBeastPaths={db={visible=true},GetResolvedRoute=function()
        return {mapID=376,color={0.1,0.8,0.5,1},segments={{points=points}}} end,
        GetFootprintsForPet=function() return scene.footprints or {{x=0.3,y=0.2,mapID=376},{x=0.5,y=0.3,mapID=376}} end}
    setfenv(assert(loadfile(path)),env)('YiboBeastPaths',ns)
    scene.addon=env.YiboBeastPaths
    scene.addon:InitializeMinimapRenderer()
    function scene:Draw(force)
        self.addon:RefreshMinimapLayer(force)
        local lines={}
        for _,f in ipairs(self.frames) do if f.line and f.shown then
            lines[#lines+1]={f.x,f.y,f.line.w,f.line.h,f.line.angle}
        end end
        return lines
    end
    return scene
end
local before=Renderer('_NonRelease/PerformanceAudit20261028/MinimapRenderer-before-compute.lua')
local after=Renderer('YiboBeastPaths/MinimapRenderer.lua')
local maxError=0
for i=1,30 do
    for _,scene in ipairs({before,after}) do
        scene.x=17.37+i*0.237;scene.y=19.81+i*0.179
        scene.rotate=i>10;scene.angle=i>20 and 0.71 or 0.293
        scene.radius=i>15 and 73.37 or 100
        scene.w=i>25 and 207 or 183
    end
    local a,b=before:Draw(),after:Draw()
    assert(#a==#b,'line count must agree: '..#a..'/'..#b)
    for j=1,#a do for k=1,5 do
        local err=math.abs(a[j][k]-b[j][k]);maxError=math.max(maxError,err)
        assert(err<0.000001,'projection/smoothing must preserve geometry')
    end end
end
local function Measure(scene)
    collectgarbage('collect');collectgarbage('stop')
    local kb,started,reads=collectgarbage('count'),os.clock(),scene.worldReads
    for i=1,200 do scene.x=21.123+i*0.137;scene:Draw() end
    local elapsed,allocated,worldReads=os.clock()-started,collectgarbage('count')-kb,scene.worldReads-reads
    collectgarbage('restart');collectgarbage('collect')
    return elapsed,allocated,worldReads
end
local oldTime,oldKB,oldReads=Measure(before)
local newTime,newKB,newReads=Measure(after)
assert(newReads==0 and oldReads>0,'movement reuses footprint world positions')
assert(newKB<oldKB*0.75,'movement must eliminate repeated smoothing allocations')
after.addon:InvalidateMinimapRouteCache();local reads=after.worldReads;after:Draw()
assert(after.worldReads>reads,'edits invalidate both route geometry and footprint coordinates')
after.failFootprints=true;after.x=55.137;after:Draw(true)
after.failFootprints=false;after.x=55.437;reads=after.worldReads;after:Draw()
assert(after.worldReads>reads,'temporarily unavailable footprint coordinates are retried')
local visible=0
for _,f in ipairs(after.frames) do if f.icon and f.shown then visible=visible+1 end end
assert(visible==2,'footprints recover without a manual cache reset')
print(string.format('PASS: 30 geometry comparisons, max error %.3g; 200 moving draws old %.3fs/%.1fKB/%d world reads, new %.3fs/%.1fKB/%d reads',
    maxError,oldTime,oldKB,oldReads,newTime,newKB,newReads))
return Renderer
