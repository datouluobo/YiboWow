local Core = _G.YiboCore

Core.DataDomains:Register("YiboCore", {
    id = "identity", version = 1,
    events = Core._private.target.identityEvents or { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true,
        PLAYER_LEVEL_UP = true, PLAYER_GUILD_UPDATE = true },
    Collect = function(context)
        return Core.Client:ReadIdentity(context)
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}
        record.observedAt = record.observedAt or {}
        if domain.state == "known" then
            if not Core._private.target.directoryIdentityOnly then
                record.race, record.faction, record.sex = data.race, data.faction, data.sex
                record.profile.guild = data.guild
            end
            record.observedAt.identity = domain.updatedAt
        end
        record.availability = record.availability or {}; record.availability.profile = domain.state
    end,
})
