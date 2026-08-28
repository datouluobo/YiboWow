local Core = _G.YiboCore

Core.DataDomains:Register("YiboCore", {
    id = "location", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true },
    Collect = function()
        return {
            zone = GetZoneText and GetZoneText(), subZone = GetSubZoneText and GetSubZoneText(),
            mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"),
        }, "known"
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}
        record.profile.zone, record.profile.subZone, record.profile.mapID = data.zone, data.subZone, data.mapID
        record.observedAt = record.observedAt or {}; record.observedAt.profile = domain.updatedAt
        record.availability = record.availability or {}; record.availability.profile = domain.state
    end,
})
