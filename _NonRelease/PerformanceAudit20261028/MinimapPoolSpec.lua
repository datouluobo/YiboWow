-- Actual renderer with synthetic map geometry; no WoW UI/GPU timing claims.
local flavor = arg[1] or "Mists"
WOW_PROJECT_MAINLINE, WOW_PROJECT_MISTS_CLASSIC = 1, 19
WOW_PROJECT_ID = flavor == "Retail" and 1 or 19
local frames, position, zone, footprints = {}, 0, 376, true
local calls = 0
local noop = function() end
local methods = { SetAllPoints=noop, SetFrameStrata=noop, SetFrameLevel=noop,
    EnableMouse=noop, ClearAllPoints=noop, SetPoint=noop, SetTexture=noop,
    SetBlendMode=noop, SetTexCoord=noop, SetRotation=noop, SetVertexColor=noop,
    RegisterEvent=noop, GetFrameLevel=function() return 1 end,
    SetScript=function(self, name, fn) self.scripts[name]=fn end,
    SetSize=function(self, w, h) self.w,self.h=w,h end,
    GetWidth=function(self) return self.w or 180 end,
    GetHeight=function(self) return self.h or 180 end,
    Show=function(self) self.shown=true end, Hide=function(self) self.shown=false end,
    IsVisible=function(self) return self.shown ~= false end,
    GetZoom=function() return 0 end }
local function Object() return setmetatable({ scripts={} }, { __index=methods }) end
methods.CreateTexture=Object
function CreateFrame() local f=Object(); frames[#frames+1]=f; return f end
function wipe(t) for k in pairs(t) do t[k]=nil end; return t end
Minimap=Object()
GetCVar=function() return "0" end
C_Minimap={ GetViewRadius=function() return 100 end }
C_Map={ GetMapInfo=function() return nil end }
local hbd={ GetWorldCoordinatesFromZone=function(_, x,y) return x*100,y*100,1 end,
    GetPlayerWorldPosition=function() calls=calls+1; return position,0,1 end,
    GetPlayerZone=function() return zone end }
LibStub=function() return hbd end
local ns={ pets={ [1]={mapID=376} } }
assert(loadfile("YiboBeastPaths/Flavor.lua"))("YiboBeastPaths",ns)
assert(ns.IS_MISTS == (flavor == "Mists") and ns.IS_RETAIL == (flavor == "Retail"))
YiboBeastPaths={ db={visible=true}, GetResolvedRoute=function()
    return {mapID=376,segments={{points={{x=0,y=0},{x=0.1,y=0.1}}}}} end,
    GetFootprintsForPet=function() return footprints and {{mapID=376,x=0.01,y=0.01}} or {} end }
local renderer = "YiboBeastPaths/MinimapRenderer.lua"
if arg[2] == "before-fix" then
    local file = assert(io.open(renderer, "rb"))
    local source = file:read("*a"); file:close()
    -- Reproduce the original code without changing the working tree.
    local count
    source, count = source:gsub("    minimapState.activeCount = 0\r?\n    minimapState.activeFootprintCount = 0", "    minimapState.activeCount = 0")
    assert(count == 1, "expected exactly one per-render reset pair")
    assert(loadstring(source, "@"..renderer))("YiboBeastPaths",ns)
else
    assert(loadfile(renderer))("YiboBeastPaths",ns)
end
local ybp=YiboBeastPaths
ybp:InitializeMinimapRenderer()
ybp:RefreshMinimapLayer(true)
local function Pool()
    for _,frame in ipairs(frames) do if frame.icon then return frame end end
end
local first=assert(Pool(), "fixture must draw a footprint")
local initial=#frames
for i=1,600 do position=(i%40)*0.11; ybp:RefreshMinimapLayer() end
local visible=0
for _,f in ipairs(frames) do if f.icon and f.shown then visible=visible+1 end end
print(string.format("%s moving refreshes=600 frames_initial=%d frames_final=%d visible_footprints=%d",flavor,initial,#frames,visible))
assert(#frames==initial, "moving refreshes must reuse the footprint pool")
assert(visible==1, "stale footprints must not remain shown")
footprints=false; position=6; ybp:InvalidateMinimapRouteCache(); ybp:RefreshMinimapLayer()
assert(first.shown==false, "an empty footprint result hides old slots")
footprints=true; ybp:RefreshMinimapLayer(true); assert(first.shown)
zone=999; ybp:RefreshMinimapLayer(); assert(not first.shown)
zone=376; ybp:RefreshMinimapLayer(); assert(first.shown)
ybp.db.visible=false; ybp:RefreshMinimapLayer(); assert(not first.shown)
ybp.db.visible=true; ybp:RefreshMinimapLayer(); assert(first.shown)
local update
for _,f in ipairs(frames) do if f.scripts.OnUpdate then update=f end end
calls=0
for i=1,600 do update.scripts.OnUpdate(update,1/60) end
print(string.format("%s stationary 10s context polls=%d frames_final=%d",flavor,calls,#frames))
assert(#frames==initial)
print("PASS: bounded frame pool, empty/map/visibility transitions")
