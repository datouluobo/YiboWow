local Addon = _G.YiboVault

function Addon:InitializeDatabase()
    local db = type(_G.YiboVaultDB) == "table" and _G.YiboVaultDB or {}
    if tonumber(db.schemaVersion) ~= self.SCHEMA_VERSION then
        db.byCharacter = type(db.byCharacter) == "table" and db.byCharacter or {}
        db.revision = tonumber(db.revision) or 0
        db.schemaVersion = self.SCHEMA_VERSION
    end
    db.byCharacter = type(db.byCharacter) == "table" and db.byCharacter or {}
    db.byGuild = type(db.byGuild) == "table" and db.byGuild or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.tooltipRealmScope ~= "all" then db.settings.tooltipRealmScope = "current" end
    if type(db.settings.tooltipEnabled) ~= "boolean" then db.settings.tooltipEnabled = true end
    db.settings.hiddenTooltipItems = type(db.settings.hiddenTooltipItems) == "table" and db.settings.hiddenTooltipItems or {}
    db.revision = tonumber(db.revision) or 0
    for _, character in pairs(db.byCharacter) do
        for _, source in ipairs({ "bags", "equipment", "bank", "auction", "mail" }) do
            for _, coverage in pairs(character.coverage and character.coverage[source] or {}) do
                if coverage.status == "known" or coverage.status == "known-empty" or coverage.status == "partial" then coverage.status = "stale" end
            end
        end
    end
    for _, guild in pairs(db.byGuild) do
        for _, coverage in pairs(guild.coverage or {}) do
            if coverage.status == "known" or coverage.status == "known-empty" or coverage.status == "partial" then coverage.status = "stale" end
        end
    end
    _G.YiboVaultDB = db
    self.db = db
    self._dirtyBags = {}
    self._dirtyBank = {}
    self._bankOpen = false
end
