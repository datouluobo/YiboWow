-- Headless smoke test for default debug-route selection and map following.
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
StaticPopupDialogs = {}

local visibleMapID, worldMapShown, playerMapID = 999, false, 37
WorldMapFrame = { IsShown = function() return worldMapShown end }
C_Map = {
    GetBestMapForUnit = function() return playerMapID end,
    GetMapInfo = function(mapID)
        return mapID == 37 and { parentMapID = 376 } or nil
    end,
}

local routes = { [376] = { 50812, 50885 }, [999] = { 50998 } }
local ybp = {}
_G.YiboBeastPaths = ybp
function ybp:GetCurrentWorldMapID() return visibleMapID end
function ybp:GetVisiblePetIDsForMap(mapID) return routes[mapID] or {} end
function ybp:RefreshMapLayer() end
local chunk = assert(loadfile("YiboBeastPaths/Maintenance/DebugCalibrator.lua"))
chunk("YiboBeastPaths", {})
ybp:InitDebugDB()

-- Opening the workbench with the world map closed chooses a route near the
-- player, not an old map retained by the Blizzard frame.
assert(ybp:GetDebugContextMapID() == 376)
assert(ybp:GetDebugPetIDsForCurrentMap()[1] == 50812)
assert(ybp:GetSelectedDebugPetID() == 50812)
assert(_G.YiboBeastPathsDebugDB.selectedPetIDByMap[376] == 50812)

-- A saved ID no longer present on the current map must not strand the page.
_G.YiboBeastPathsDebugDB.selectedPetIDByMap[376] = 12345
assert(ybp:GetSelectedDebugPetID() == 50812)
ybp:SetSelectedDebugPetID(50885)
assert(ybp:GetSelectedDebugPetID() == 50885)

-- When the world map opens, its displayed map remains authoritative.
worldMapShown = true
assert(ybp:GetDebugContextMapID() == 999)
assert(ybp:GetSelectedDebugPetID() == 50998)
visibleMapID = 376
assert(ybp:GetDebugContextMapID() == 376)
assert(ybp:GetSelectedDebugPetID() == 50885)
print("Debug context smoke: current-zone default and world-map following OK")
