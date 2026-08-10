local Core = _G.YiboCore

local Database = {}
Core.Database = Database

local DEFAULTS = {
    schemaVersion = 0,
    characters = {
        byID = {},
        aliases = {},
        seenOrder = {},
    },
    settings = {
        debug = false,
        accountView = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 1120,
            height = 650,
            pages = {},
            fields = {},
            hiddenCharacters = {},
            characterSort = "seen",
            entry = {
                minimap = { show = true, angle = 225 },
                broker = { show = true },
                pageModes = {},
                pagePositions = {},
            },
        },
    },
    migrationHistory = {},
}

function Database:GetDB()
    return self.db
end

function Database:Initialize()
    if self.db then
        return true
    end

    if type(_G.YiboCoreDB) ~= "table" then
        _G.YiboCoreDB = {}
    end

    self.db = _G.YiboCoreDB
    Core.Defaults:Apply(self.db, DEFAULTS)

    local migrated, errorMessage = Core.Migrations:Run(self.db)
    if not migrated then
        Core:Print("数据库未加载: " .. errorMessage)
        return false, errorMessage
    end

    Core.Defaults:Apply(self.db, DEFAULTS)
    Core.db = self.db
    return true
end

function Core:Initialize()
    local initialized, errorMessage = self.Database:Initialize()
    if not initialized then
        return false, errorMessage
    end

    self._private.initialized = true
    self:RegisterAddon(self.NAME, {
        version = self.VERSION,
        requiredAPI = self.API_VERSION,
        internal = true,
    })

    if self.Characters then
        self.Characters:RefreshCurrent()
    end
    if self.Events then
        self.Events:Fire("CORE_READY", self.VERSION)
    end
    return true
end

Core.Capabilities:Register("database", 1)
