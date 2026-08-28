local Addon = _G.YiboTodo

local DEFAULTS = {
    schemaVersion = 3,
    catalogVersion = 3,
    settings = {
        modeOverrides = { activityType = {}, expansion = {}, profession = {}, cooldownGroup = {}, activity = {} },
        previewColumnsVersion = 3,
        previewColumns = { projects = true },
    },
    byCharacter = {},
    byAccount = {},
    diagnostics = { lastProbe = nil },
}

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function Addon.Database:Initialize()
    _G.YiboTodoDB = _G.YiboTodoDB or {}
    self.db = _G.YiboTodoDB
    local version = tonumber(self.db.schemaVersion) or 0
    if version < 1 then self.db.schemaVersion = 1 end
    if version < 2 then
        self.db.settings = self.db.settings or {}
        self.db.settings.previewColumnsVersion = 2
        self.db.settings.previewColumns = { projects = true, status = true }
        self.db.schemaVersion = 2
    end
    if version < 3 then
        self.db.settings = self.db.settings or {}
        self.db.settings.previewColumnsVersion = 3
        self.db.settings.previewColumns = { projects = true }
        self.db.schemaVersion = 3
    end
    CopyDefaults(self.db, DEFAULTS)
    self.db.catalogVersion = math.max(tonumber(self.db.catalogVersion) or 0, Addon.CATALOG_VERSION)
    Addon.db = self.db
    return self.db
end

function Addon.Database:GetCharacter(characterID, create)
    local data = Addon.db and Addon.db.byCharacter and Addon.db.byCharacter[characterID]
    if not data and create then
        data = { lastSeenAt = Addon:Now(), providers = {} }
        Addon.db.byCharacter[characterID] = data
    end
    return data
end

function Addon.Database:GetProvider(characterID, providerID, create)
    local character = self:GetCharacter(characterID, create)
    if not character then return nil end
    local provider = character.providers[providerID]
    if not provider and create then
        provider = { revision = 0, lastAttemptAt = 0, lastSuccessAt = 0, state = "not-yet-scanned", observations = {} }
        character.providers[providerID] = provider
    end
    return provider
end

function Addon.Database:DeleteCharacter(characterID)
    if Addon.db and Addon.db.byCharacter then Addon.db.byCharacter[characterID] = nil end
end
