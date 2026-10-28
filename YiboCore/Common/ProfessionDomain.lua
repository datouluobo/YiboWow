local Core = _G.YiboCore
function Core._private.RegisterProfessionDomain(events, collect)
    return Core.DataDomains:Register("YiboCore", {
        id = "professions", version = 1, events = events, Collect = collect,
        ProjectLegacy = function(record, data, domain)
            record.profile = record.profile or {}
            record.observedAt = record.observedAt or {}
            if domain.state == "known" then
                record.profile.professions, record.profile.primaryProfessions = data.professions, data.primaryProfessions
                record.profile.skillLineIDsAuthoritative = data.skillLineIDsAuthoritative
                record.observedAt.professions = data.observedAt or domain.updatedAt
            end
            record.availability = record.availability or {}
            record.availability.professions = domain.state
        end,
    })
end
