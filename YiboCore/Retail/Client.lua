local Core = _G.YiboCore
local names = { GUID = "UnitGUID", Name = "UnitName", Realm = "GetRealmName", Class = "UnitClass",
    Level = "UnitLevel", IsSecret = "issecretvalue" }
Core.Client:Configure("Retail", Core._private.CreateClientReader(function(key)
    if key == "Time" then return GetServerTime or time end
    return names[key] and _G[names[key]]
end, { directoryOnly = true }))
