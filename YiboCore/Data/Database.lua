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
    characterDisplay = {},
    settings = {
        debug = false,
        language = "auto",
        accountView = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 1120,
            height = 650,
            pages = {},
            pageCharacterFilters = {},
            fields = {},
            firstUseHints = {},
            hiddenCharacters = {},
            characterSort = {
                mode = "recent",
                direction = "desc",
                pinCurrent = false,
            },
            pageCharacterSorts = {},
            pageSizes = {},
            pageSizeSchema = 2,
            customCharacterOrder = {},
            entry = {
                -- New channel defaults are applied by EntryConfig after legacy migration.
                -- Keep legacy flags/angles as migration inputs; never prefill channels here.

                minimap = { show = true, angle = 225 },
                broker = { show = true },
                showPreviewWhileMainWindowOpen = false,
                pageModes = {},
                pagePositions = {},
            },
        },
    },
    migrationHistory = {},
    characterDeletionHistory = {},
}

function Database:GetDB()
    return self.db
end

function Database:Prepare(staged)
    local target = Core._private.target
    if not target or target.supported ~= true then
        return false, Core:Text("CORE.CLIENT_MANIFEST_MISMATCH")
    end
    if self.db and not staged then return true end
    local name = target.savedVariable
    local saved = _G[name]
    if not Core._private.ValidateStore(saved) then
        return false, Core:Text("CORE.CLIENT_STORE_MISMATCH")
    end
    if target.requireStampedStore and saved and next(saved) and not saved.clientScope then
        return false, Core:Text("CORE.CLIENT_STORE_MISMATCH")
    end
    if saved and saved.clientScope and (saved.clientScope.target ~= target.id or
        saved.clientScope.projectID ~= target.projectID) then
        return false, Core:Text("CORE.CLIENT_STORE_MISMATCH")
    end
    if saved and (tonumber(saved.schemaVersion) or 0) > Core.Migrations.CURRENT_SCHEMA then
        return false, Core:Text("CORE.YIBOCORE_DATA_IS_NEWER_THAN_THIS_ADDON")
    end
    local candidate = Core.Defaults:Copy(saved or {})
    Core.Defaults:Apply(candidate, DEFAULTS)
    local migrated, errorMessage = Core.Migrations:Run(candidate)
    if not migrated then
        return false, errorMessage
    end
    Core.Defaults:Apply(candidate, DEFAULTS)
    candidate.clientScope = { target = target.id, projectID = target.projectID, rulesetState = target.rulesetState }
    self._prepared = { name = name, original = saved }
    self.db, Core.db = candidate, candidate
    return true
end

function Database:Commit()
    local pending = self._prepared
    if not pending then return end
    local saved = pending.original or {}
    for key in pairs(saved) do saved[key] = nil end
    for key, value in pairs(self.db) do saved[key] = value end
    _G[pending.name] = saved
    self.db = saved
    Core.db = self.db
    self._prepared = nil
end

function Database:Initialize()
    local ok, initialized, message = pcall(self.Prepare, self)
    if not ok then return false, Core:Text("CORE.INITIALIZATION_FAILED", tostring(initialized)) end
    if not initialized then return false, message end
    self:Commit()
    return true
end

function Core:Initialize()
    if self:IsInitialized() then return true end
    if not self._private.lifecycleFrame then return false, self:Text("CORE.CLIENT_NOT_READY") end
    if self._private.lifecycleError then
        local message = self:Text("CORE.INITIALIZATION_FAILED", self._private.lifecycleError)
        self:Print(message)
        return false, message
    end
    if self._private.initializing then return false, self:Text("CORE.INITIALIZATION_IN_PROGRESS") end
    self._private.initializing = true
    local database, locale = self.Database, self.Locale
    local oldDB, oldCoreDB, oldPrepared = database.db, self.db, database._prepared
    local oldLanguage, oldPreference, oldLocaleReady = locale.language, locale.sessionPreference, locale.initialized
    local oldRegistration = self.Defaults:Copy(self.Registry:Get(self.NAME))
    local ok, initialized, errorMessage = pcall(function()
        local prepared, message = database:Prepare(true)
        if not prepared then return false, message end
        locale:Initialize()
        local registered, registerError = self:RegisterAddon(self.NAME, {
            version = self.VERSION, requiredAPI = self.API_VERSION, internal = true,
        })
        if not registered then return false, registerError end
        if self.Characters then self.Characters:RefreshCurrent() end
        database:Commit()
        return true
    end)
    self._private.initializing = nil
    if not ok or not initialized then
        database.db, self.db, database._prepared = oldDB, oldCoreDB, oldPrepared
        locale.language, locale.sessionPreference, locale.initialized = oldLanguage, oldPreference, oldLocaleReady
        self.Registry._addons[self.NAME] = oldRegistration
        self._private.characterPending = nil
        if self.Characters then self.Characters:InvalidateAllCache() end
        pcall(locale.RefreshBindings, locale)
        local message = ok and errorMessage or self:Text("CORE.INITIALIZATION_FAILED", tostring(initialized))
        message = message or self:Text("CORE.CLIENT_NOT_READY")
        self:Print(message)
        return false, message
    end
    self._private.initialized = true
    self.Events:FireIsolated("CORE_READY", self.VERSION)
    return true
end

Core.Capabilities:Register("database", 1)
