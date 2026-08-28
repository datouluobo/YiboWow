local Core = _G.YiboCore

Core.DataDomains:Register("YiboCore", {
    id = "specialization", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, PLAYER_SPECIALIZATION_CHANGED = true },
    Collect = function()
        local index = GetSpecialization and GetSpecialization()
        if not (index and GetSpecializationInfo) then return {}, "not-yet-scanned" end
        local id, name, _, icon = GetSpecializationInfo(index)
        return { specialization = { id = id, name = name, icon = icon } }, "known"
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}; record.profile.specialization = data.specialization
        record.observedAt = record.observedAt or {}; record.observedAt.specialization = domain.updatedAt
        record.availability = record.availability or {}; record.availability.specialization = domain.state
    end,
})
