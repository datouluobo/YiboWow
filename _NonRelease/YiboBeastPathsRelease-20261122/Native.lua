-- Minimal synthetic map/client API for loading the BeastPaths package in the
-- shared FrameFixture: empty map hierarchy, no player position.  A stub
-- WorldMapFrame exists only while the HereBeDragons libraries load (Pins needs it
-- at file scope); it is then cleared so the addon takes its "Blizzard_WorldMap not
-- loaded yet" path.  World map / minimap route rendering is not exercised here.
-- Unknown widget methods become recorded no-ops (names in env.TEST_FIXTURE_GAPS).
local Native = {}
function Native.AfterFile(line, env)
    if line:match('HereBeDragons%-Pins%-2%.0%.lua$') then env.WorldMapFrame = nil end
end
function Native.Setup(env)
    env.TEST_FIXTURE_GAPS = env.TEST_FIXTURE_GAPS or {}
    local gaps = env.TEST_FIXTURE_GAPS
    local methods = getmetatable(env.CreateFrame('Frame')).__index
    if not getmetatable(methods) then
        setmetatable(methods, { __index = function(_, name)
            if type(name) == 'string' and name:match('^[A-Z]') then gaps[name] = true; return function() end end
        end })
    end
    env.C_AddOns.IsAddOnLoaded = function() return false end
    env.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
    env.C_Map.GetMapInfo = function() return nil end
    env.C_Map.GetMapChildrenInfo = function() return {} end
    env.C_Map.GetBestMapForUnit = function() return nil end
    env.C_Map.GetWorldPosFromMapPos = function() return nil end
    env.C_Map.GetMapGroupID = function() return nil end
    env.UnitPosition = function() return nil end
    env.GetInstanceInfo = function() return nil end
    env.Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }
    env.CreateFromMixins = function(...) local r = {}; for i = 1, select('#', ...) do for k, v in pairs((select(i, ...))) do r[k] = v end end; return r end
    env.Mixin = function(target, ...) for i = 1, select('#', ...) do for k, v in pairs((select(i, ...))) do target[k] = v end end; return target end
    env.MapCanvasDataProviderMixin, env.MapCanvasPinMixin = {}, {}
    local canvasMap = { RemoveAllPinsByTemplate = function() end, EnumeratePinsByTemplate = function() return function() end end,
        RemovePin = function() end, AcquirePin = function() end, GetMapID = function() return nil end }
    env.MapCanvasDataProviderMixin.GetMap = function() return canvasMap end
    env.CreateFramePool = function() return { Acquire = function() return env.CreateFrame('Frame') end, Release = function() end, ReleaseAll = function() end, EnumerateActive = function() return function() end end } end
    env.GetCVar = function() return '0' end
    env.hooksecurefunc = function() end
    env.Minimap.GetZoom = function() return 0 end
    env.Minimap.GetScale = function() return 1 end
    env.Minimap.IsVisible = function() return true end
    local map = env.CreateFrame('Frame', 'WorldMapFrame')
    local canvas = env.CreateFrame('Frame', nil, map)
    map.pinPools = {}
    map.GetCanvas = function() return canvas end
    map.AddDataProvider = function() end
    map.GetMapID = function() return nil end
    map:Hide()
    env.IsLoggedIn = function() return true end
    env.print = function(...) local t = {}; for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end; env.TEST_MESSAGES[#env.TEST_MESSAGES + 1] = table.concat(t, ' ') end
end
return Native
