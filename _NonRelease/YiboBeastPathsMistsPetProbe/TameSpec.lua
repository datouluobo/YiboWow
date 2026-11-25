local handler, timers
local frame = { RegisterEvent = function() end, SetScript = function(_, _, fn) handler = fn end }
CreateFrame = function() return frame end
WOW_PROJECT_ID = 19
YiboCore = { CheckAPIVersion = function() return true end, HasCapability = function() return true end,
    IsInitialized = function() return true end, Characters = { GetCurrentID = function() return "test" end } }
time = function() return 123 end
GetBuildInfo = function() return "5.5.4", "test", "", 50504 end
GetLocale = function() return "zhCN" end
UnitGUID = function(unit) return unit == "target" and "Creature-0-0-0-0-123-0" or "Pet-0-0-0-0-456-0" end
UnitName = function(unit) return unit end
UnitExists = function() return true end
C_Map = { GetBestMapForUnit = function() return 42 end, GetMapInfo = function() return { name = "test map" } end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.25, 0.75 end } end }
timers = {}; C_Timer = { After = function(delay, fn) timers[delay] = fn end }
assert(loadfile("_NonRelease/YiboBeastPathsMistsPetProbe/Probe.lua"))("YiboBeastPathsMistsPetProbe")
handler(frame, "PLAYER_LOGIN")
handler(frame, "UNIT_SPELLCAST_SENT", "player", "target", "cast", 1515)
handler(frame, "UNIT_SPELLCAST_START", "player", "cast", 1515)
handler(frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1515)
handler(frame, "UNIT_PET", "player")
for _, delay in ipairs({ 4, 10, 30, 60 }) do assert(timers[delay]); timers[delay]() end
local sample = YiboBeastPathsMistsPetProbeDB.characters.test.tameSamples[1]
assert(#sample.events == 8 and sample.events[1].event == "UNIT_SPELLCAST_SENT")
assert(sample.events[1].target.guid:match("Creature") and sample.events[1].position.mapID == 42)
assert(sample.events[1].position.x == 0.25 and sample.events[1].position.y == 0.75)
assert(sample.events[8].event == "TIMER_60" and sample.events[8].pet.guid:match("Pet"))
handler(frame, "UNIT_PET", "player")
assert(#sample.events == 8)
print("TameSpec: cast, map, pet events and bounded recording passed")
