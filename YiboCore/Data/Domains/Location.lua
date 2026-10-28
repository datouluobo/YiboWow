local Core = _G.YiboCore

Core.DataDomains:Register("YiboCore", {
    id = "location", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true },
    Collect = function()
        return Core.Client:ReadLocation()
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}
        record.observedAt = record.observedAt or {}
        if domain.state == "known" then
            record.profile.zone, record.profile.subZone, record.profile.mapID = data.zone, data.subZone, data.mapID
            record.observedAt.profile = domain.updatedAt
        end
        record.availability = record.availability or {}; record.availability.profile = domain.state
    end,
})
