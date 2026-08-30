local Addon = _G.YiboTodo

local DEFAULTS = {
    schemaVersion = 6,
    catalogVersion = 12,
    settings = {
        modeOverrides = { activityType = {}, expansion = {}, profession = {}, cooldownGroup = {}, activity = {} },
        previewColumnsVersion = 3,
        previewColumns = { projects = true },
        levelExpr = "",
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
    if version < 4 then
        self.db.settings = self.db.settings or {}
        -- This value came from the development default, not a user action.
        if self.db.settings.levelExpr == "90" then self.db.settings.levelExpr = "" end
        self.db.schemaVersion = 4
    end
    if version < 5 then
        local oldGroupID = "mop.tailoring.dreamcloth"
        local newGroupID = "mop.tailoring.celestial-cloth"
        local settings = self.db.settings
        local groups = settings and settings.modeOverrides and settings.modeOverrides.cooldownGroup
        if groups and groups[newGroupID] == nil then groups[newGroupID] = groups[oldGroupID] end
        if groups then groups[oldGroupID] = nil end
        for _, character in pairs(self.db.byCharacter or {}) do
            local provider = character.providers and character.providers["profession-cooldown"]
            local observations = provider and provider.observations
            if observations and observations[newGroupID] == nil then observations[newGroupID] = observations[oldGroupID] end
            if observations then observations[oldGroupID] = nil end
        end
        self.db.schemaVersion = 5
    end
    if version < 6 then
        -- Farm observations live in their own Provider record. No existing
        -- cooldown observation is read, moved, or reinterpreted here.
        self.db.schemaVersion = 6
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

local function ObservationTime(value)
    return tonumber(value and value.observedAt) or 0
end

local function MergeProvider(target, source)
    target.revision = math.max(tonumber(target.revision) or 0, tonumber(source.revision) or 0)
    target.lastAttemptAt = math.max(tonumber(target.lastAttemptAt) or 0, tonumber(source.lastAttemptAt) or 0)
    if (tonumber(source.lastSuccessAt) or 0) > (tonumber(target.lastSuccessAt) or 0) then
        target.lastSuccessAt, target.state, target.errorCode = source.lastSuccessAt, source.state, source.errorCode
    end
    if source.observations then
        target.observations = target.observations or {}
        for groupID, observation in pairs(source.observations) do
            if ObservationTime(observation) > ObservationTime(target.observations[groupID]) then
                target.observations[groupID] = observation
            end
        end
    end
    if source.days then
        target.days = target.days or {}
        for serverDay, day in pairs(source.days) do
            if ObservationTime(day) > ObservationTime(target.days[serverDay]) then target.days[serverDay] = day end
        end
    end
end

-- Core promotes early legacy name/realm IDs to stable GUIDs on login. Keep
-- business snapshots attached to that character rather than treating the
-- promotion as a fresh, immediately-craftable character.
function Addon.Database:MoveCharacterData(oldID, newID)
    if oldID == newID or not (Addon.db and Addon.db.byCharacter) then return false end
    local source = Addon.db.byCharacter[oldID]
    if not source then return false end
    local target = Addon.db.byCharacter[newID]
    if not target then
        Addon.db.byCharacter[newID], Addon.db.byCharacter[oldID] = source, nil
        return true
    end
    target.providers = target.providers or {}
    for providerID, sourceProvider in pairs(source.providers or {}) do
        local targetProvider = target.providers[providerID]
        if targetProvider then MergeProvider(targetProvider, sourceProvider) else target.providers[providerID] = sourceProvider end
    end
    target.lastSeenAt = math.max(tonumber(target.lastSeenAt) or 0, tonumber(source.lastSeenAt) or 0)
    Addon.db.byCharacter[oldID] = nil
    return true
end

function Addon.Database:DeleteCharacter(characterID)
    if Addon.db and Addon.db.byCharacter then Addon.db.byCharacter[characterID] = nil end
end
