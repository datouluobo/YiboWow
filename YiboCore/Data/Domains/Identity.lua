local Core = _G.YiboCore

Core.DataDomains:Register("YiboCore", {
    id = "identity", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, PLAYER_LEVEL_UP = true },
    Collect = function(context)
        local raceName, raceFile = UnitRace and UnitRace("player")
        local factionName, factionFile = UnitFactionGroup and UnitFactionGroup("player")
        return {
            id = context.characterID, name = context.character and context.character.name, realm = context.character and context.character.realm,
            class = context.character and context.character.class, level = context.character and context.character.level,
            race = raceFile or raceName, faction = factionFile or factionName,
            sex = UnitSex and UnitSex("player"), guild = GetGuildInfo and select(1, GetGuildInfo("player")),
        }, "known"
    end,
    ProjectLegacy = function(record, data, domain)
        record.race, record.faction, record.sex = data.race, data.faction, data.sex
        record.profile = record.profile or {}; record.profile.guild = data.guild
        record.observedAt = record.observedAt or {}; record.observedAt.identity = domain.updatedAt
        record.availability = record.availability or {}; record.availability.profile = domain.state
    end,
})
