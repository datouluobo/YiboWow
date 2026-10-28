local Core = _G.YiboCore
local names = { GUID = "UnitGUID", Name = "UnitName", Realm = "GetRealmName", Class = "UnitClass",
    Level = "UnitLevel", Race = "UnitRace", Faction = "UnitFactionGroup", Sex = "UnitSex",
    Guild = "GetGuildInfo", InGuild = "IsInGuild", Zone = "GetZoneText", SubZone = "GetSubZoneText", IsSecret = "issecretvalue" }
Core.Client:Configure("Mists", Core._private.CreateClientReader(function(key)
    if key == "Map" then return C_Map and C_Map.GetBestMapForUnit end
    if key == "Time" then return GetServerTime or time end
    return names[key] and _G[names[key]]
end))
