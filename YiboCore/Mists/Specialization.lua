local Core = _G.YiboCore

Core.DataDomains:Register("YiboCore", {
    id = "specialization", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, PLAYER_SPECIALIZATION_CHANGED = true },
    Collect = function()
        local index = GetSpecialization and GetSpecialization()
        if not GetSpecialization or not GetSpecializationInfo then return nil, "unavailable" end
        if not index then return nil, "not-yet-scanned" end
        local id, name, _, icon = GetSpecializationInfo(index)
        if not id or type(name) ~= "string" or name == "" then return nil, "not-yet-scanned" end
        return { specialization = { id = id, name = name, icon = icon } }, "known"
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}
        record.observedAt = record.observedAt or {}
        if domain.state == "known" then record.profile.specialization = data.specialization; record.observedAt.specialization = domain.updatedAt end
        record.availability = record.availability or {}; record.availability.specialization = domain.state
    end,
})
