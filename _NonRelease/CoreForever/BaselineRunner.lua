-- Generated baseline comparison: original versions of this task's modified files.
local baseline = {}
baseline["YiboCore/Bootstrap.lua"] = [=====[local ADDON_NAME = ...

local Core = _G.YiboCore or {}
_G.YiboCore = Core

Core.NAME = "YiboCore"
Core.VERSION = "1.12.7"
Core.API_VERSION = 13
Core._private = Core._private or {}
Core._private.addonName = ADDON_NAME or Core.NAME
Core._private.initialized = false

function Core:GetAddonName()
    return self._private.addonName
end

function Core:IsInitialized()
    return self._private.initialized == true
end

function Core:GetVersion()
    return self.VERSION
end

function Core:CheckAPIVersion(requiredVersion)
    requiredVersion = tonumber(requiredVersion) or 1
    return self.API_VERSION >= requiredVersion, self.API_VERSION
end

function Core:Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(Core:Text("CORE.CFF20E070_YIBO_R_CORE") .. tostring(message))
    end
end

local lifecycleFrame = CreateFrame("Frame")
lifecycleFrame:RegisterEvent("ADDON_LOADED")
lifecycleFrame:RegisterEvent("PLAYER_LOGIN")
lifecycleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycleFrame:RegisterEvent("PLAYER_LEVEL_UP")
lifecycleFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
lifecycleFrame:RegisterEvent("BAG_UPDATE_DELAYED")
lifecycleFrame:RegisterEvent("BANKFRAME_OPENED")
lifecycleFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
lifecycleFrame:RegisterEvent("SKILL_LINES_CHANGED")
lifecycleFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
lifecycleFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
lifecycleFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
lifecycleFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
lifecycleFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
lifecycleFrame:RegisterEvent("UI_SCALE_CHANGED")

lifecycleFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= Core:GetAddonName() or Core:IsInitialized() then
            return
        end

        Core:Initialize()
        return
    end

    if not Core:IsInitialized() then
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if Core.Characters then
            Core.Characters:RefreshCurrent()
        end
    end
    if Core.Profile and event ~= "ADDON_LOADED" then
        Core.Profile:RefreshCurrent(event)
    end

    if Core.Events then
        Core.Events:Fire(event)
    end
end)
]=====]
baseline["YiboCore/Data/Database.lua"] = [=====[local Core = _G.YiboCore

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
        Core:Print(Core:Text("CORE.DATABASE_NOT_LOADED") .. errorMessage)
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

    self.Locale:Initialize()
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
]=====]
baseline["YiboCore/Data/Characters.lua"] = [=====[local Core = _G.YiboCore

local Characters = {}
Core.Characters = Characters

local function GetTimestamp()
    return (GetServerTime and GetServerTime()) or time()
end

local function Snapshot(record, options)
    if type(record) ~= "table" then
        return nil
    end
    if options and options.identityOnly then
        -- Roster consumers do not need inventory/profession domain payloads.
        return { id = record.id, name = record.name, realm = record.realm,
            class = record.class, level = record.level, lastSeenAt = record.lastSeenAt, seenOrder = record.seenOrder }
    end
    return Core.Defaults:Copy(record)
end

local function GetStore()
    local db = Core.Database:GetDB()
    return db and db.characters
end

local function GetDisplayStore()
    local db = Core.Database:GetDB()
    if not db then return nil end
    db.characterDisplay = type(db.characterDisplay) == "table" and db.characterDisplay or {}
    return db.characterDisplay
end

local function BuildFallbackID(name, realm)
    return "legacy:" .. tostring(realm or "Unknown") .. ":" .. tostring(name or "Unknown")
end

local function AddAlias(store, characterID, alias)
    if type(alias) == "string" and alias ~= "" then
        store.aliases[alias] = characterID
    end
end

local function ReplaceCharacterID(store, oldID, newID)
    if oldID == newID or not store.byID[oldID] or store.byID[newID] then
        return false
    end

    local record = store.byID[oldID]
    record.id = newID
    store.byID[newID] = record
    store.byID[oldID] = nil

    store.seenOrder[newID] = store.seenOrder[oldID]
    store.seenOrder[oldID] = nil

    local display = GetDisplayStore()
    if display and display[oldID] and not display[newID] then display[newID] = display[oldID] end
    if display then display[oldID] = nil end

    for alias, characterID in pairs(store.aliases) do
        if characterID == oldID then
            store.aliases[alias] = newID
        end
    end
    Core.Events:Fire("CHARACTER_ID_CHANGED", oldID, newID, Snapshot(record))
    return true
end

local function NormalizeShortName(value)
    if value == nil then return "" end
    if type(value) ~= "string" then return nil, Core:Text("CORE.SHORT_NAME_MUST_BE_TEXT") end
    value = value:match("^%s*(.-)%s*$")
    if value == "" then return "" end
    if value:find("[%z\1-\31\127]") then return nil, Core:Text("CORE.SHORT_NAME_CANNOT_CONTAIN_CONTROL_CHARACTERS") end
    return value
end

function Characters:GetDisplayName(character, mode)
    local name = type(character) == "table" and character.name or ""
    if mode ~= "short" then return name end
    local display = character and character.id and GetDisplayStore()
    local shortName = display and display[character.id] and display[character.id].shortName
    return type(shortName) == "string" and shortName ~= "" and shortName or name
end

-- Display policy only: never resolve an address, import a contact, or mutate
-- the supplied identity / display preferences. The reference realm is explicit.
function Characters:FormatName(identity, options)
    if type(identity) ~= "table" then return nil, "invalid-identity" end
    if options ~= nil and type(options) ~= "table" then return nil, "invalid-options" end
    options = options or {}
    local nameMode, realmMode = options.nameMode, options.realmMode
    if nameMode == nil then nameMode = "original" end
    if realmMode == nil then realmMode = "omit" end
    if nameMode ~= "original" and nameMode ~= "short" then return nil, "invalid-name-mode" end
    if realmMode ~= "omit" and realmMode ~= "sameRealm" and realmMode ~= "full" then return nil, "invalid-realm-mode" end
    if type(identity.name) ~= "string" or identity.name == "" then return nil, "missing-name" end
    if identity.realm ~= nil and type(identity.realm) ~= "string" then return nil, "invalid-realm" end
    local name, realm = identity.name, identity.realm
    if realm == "" then realm = nil end
    if realmMode == "full" and not realm then return nil, "missing-realm" end
    local referenceRealm = options.referenceRealm
    if realmMode == "sameRealm" and (type(referenceRealm) ~= "string" or not referenceRealm:find("%S")) then
        return nil, "missing-reference-realm"
    end
    if nameMode == "short" and type(identity.id) == "string" then
        -- The caller supplies the Core character ID. Never infer it from a
        -- contact's name/realm; preferences keep the legacy ID lookup semantics.
        local db = Core.Database:GetDB()
        local preferences = db and db.characterDisplay
        local preference = type(preferences) == "table" and preferences[identity.id]
        local shortName = type(preference) == "table" and preference.shortName
        if type(shortName) == "string" and shortName ~= "" then name = shortName end
    end
    local showRealm = realmMode == "full"
    if realmMode == "sameRealm" and realm then
        -- API realm tokens may omit spaces. Compare tokens without rewriting
        -- the realm spelling used in the resulting display text.
        showRealm = realm:gsub("%s+", ""):lower() ~= referenceRealm:gsub("%s+", ""):lower()
    end
    return showRealm and (name .. "-" .. realm) or name
end

function Characters:SetShortName(characterID, value)
    local store = GetStore()
    if type(characterID) ~= "string" or not (store and store.byID[characterID]) then return nil, Core:Text("CORE.CHARACTER_CACHE_DOES_NOT_EXIST") end
    local normalized, errorMessage = NormalizeShortName(value)
    if normalized == nil then return nil, errorMessage end
    local display = GetDisplayStore()
    if normalized == "" then
        display[characterID] = nil
    else
        display[characterID] = display[characterID] or {}
        display[characterID].shortName = normalized
    end
    Core.Events:Fire("CHARACTER_DISPLAY_UPDATED", characterID, self:Get(characterID))
    return normalized
end

function Characters:GetShortNameDuplicates()
    local duplicates, grouped = {}, {}
    for _, character in ipairs(self:GetAll()) do
        local display = GetDisplayStore()
        local shortName = display and display[character.id] and display[character.id].shortName
        if type(shortName) == "string" and shortName ~= "" then
            grouped[shortName] = grouped[shortName] or {}
            grouped[shortName][#grouped[shortName] + 1] = character
        end
    end
    for shortName, characters in pairs(grouped) do if #characters > 1 then duplicates[shortName] = characters end end
    return duplicates
end

local function EnsureSeenOrder(store, characterID)
    if store.seenOrder[characterID] then
        return store.seenOrder[characterID]
    end

    local highest = 0
    for _, order in pairs(store.seenOrder) do
        highest = math.max(highest, tonumber(order) or 0)
    end
    store.seenOrder[characterID] = highest + 1
    return store.seenOrder[characterID]
end

function Characters:BuildLegacyAliases(name, realm)
    if not name or not realm then
        return {}
    end
    return {
        tostring(name) .. "-" .. tostring(realm),
        tostring(realm) .. "-" .. tostring(name),
    }
end

function Characters:GetCurrentID()
    local guid = UnitGUID and UnitGUID("player")
    if guid and guid ~= "" then
        return guid
    end
    return BuildFallbackID(UnitName("player"), GetRealmName())
end

function Characters:RefreshCurrent()
    local store = GetStore()
    if not store then
        return nil
    end

    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    local characterID = self:GetCurrentID()
    local aliases = self:BuildLegacyAliases(name, realm)

    -- ADDON_LOADED can run before UnitGUID is available.  When the player GUID
    -- arrives at PLAYER_LOGIN, promote the earlier fallback record instead of
    -- creating a second character.
    if string.sub(characterID, 1, 7) ~= "legacy:" and not store.byID[characterID] then
        for _, alias in ipairs(aliases) do
            local previousID = store.aliases[alias]
            if previousID and previousID ~= characterID then
                ReplaceCharacterID(store, previousID, characterID)
                break
            end
        end
    end

    local record = store.byID[characterID] or {}

    record.id = characterID
    record.name = name
    record.realm = realm
    record.class = select(2, UnitClass("player")) or "UNKNOWN"
    record.level = UnitLevel("player") or 1
    record.lastSeenAt = GetTimestamp()
    record.seenOrder = EnsureSeenOrder(store, characterID)
    store.byID[characterID] = record

    for _, alias in ipairs(aliases) do
        AddAlias(store, characterID, alias)
    end

    self:InvalidateAllCache()
    Core.Events:Fire("CHARACTER_UPDATED", characterID, Snapshot(record))
    return Snapshot(record)
end

function Characters:GetCurrent(options)
    return self:Get(self:GetCurrentID(), options)
end

function Characters:Get(characterID, options)
    local store = GetStore()
    return store and Snapshot(store.byID[characterID], options) or nil
end

function Characters:GetAll(options)
    local store = GetStore()
    local items = {}
    if not store then
        return items
    end

    for _, record in pairs(store.byID) do
        items[#items + 1] = Snapshot(record, options)
    end
    table.sort(items, function(left, right)
        if left.seenOrder ~= right.seenOrder then
            return (left.seenOrder or math.huge) < (right.seenOrder or math.huge)
        end
        return tostring(left.id) < tostring(right.id)
    end)
    return items
end

-- AccountView performs many read-only passes over the same roster while a
-- page is measured, rendered, and previewed.  Keep that read model stable
-- until the underlying character/domain data changes; callers must treat the
-- returned records as read-only snapshots.
function Characters:InvalidateAllCache()
    self._allSnapshot = nil
end

function Characters:GetAllCached()
    if not self._allSnapshot then
        self._allSnapshot = self:GetAll()
    end
    return self._allSnapshot
end

function Characters:GetAliases(characterID)
    local store, aliases = GetStore(), {}
    if not store then return aliases end
    for alias, resolvedID in pairs(store.aliases or {}) do
        if resolvedID == characterID then aliases[alias] = true end
    end
    return aliases
end

function Characters:CanDelete(characterID)
    local store = GetStore()
    if type(characterID) ~= "string" or characterID == "" then return false, Core:Text("CORE.NO_CHARACTER_SELECTED") end
    if characterID == self:GetCurrentID() then return false, Core:Text("CORE.CANNOT_DELETE_THE_LOGGED_IN_CHARACTER_SWITCH") end
    if not (store and store.byID and store.byID[characterID]) then return false, Core:Text("CORE.CHARACTER_CACHE_DOES_NOT_EXIST") end
    return true
end

function Characters:DeleteCached(characterID)
    local allowed, errorMessage = self:CanDelete(characterID)
    if not allowed then return nil, errorMessage end
    local db, store = Core.Database:GetDB(), GetStore()
    local deleted = Snapshot(store.byID[characterID])
    store.byID[characterID] = nil
    store.seenOrder[characterID] = nil
    local display = GetDisplayStore()
    if display then display[characterID] = nil end
    for alias, resolvedID in pairs(store.aliases or {}) do
        if resolvedID == characterID then store.aliases[alias] = nil end
    end
    local view = db.settings and db.settings.accountView
    if view then
        if view.hiddenCharacters then view.hiddenCharacters[characterID] = nil end
        if type(view.customCharacterOrder) == "table" then
            for index = #view.customCharacterOrder, 1, -1 do
                if view.customCharacterOrder[index] == characterID then table.remove(view.customCharacterOrder, index) end
            end
        end
    end
    self:InvalidateAllCache()
    return deleted
end

function Characters:ResolveLegacyKey(key)
    local store = GetStore()
    return store and store.aliases[key] or nil
end

function Characters:ImportLegacyCharacter(sourceAddon, legacyKey, data)
    local store = GetStore()
    if not store or type(data) ~= "table" then
        return nil, Core:Text("CORE.NO_VALID_CHARACTER_DATA")
    end

    local proposedID = data.id or self:ResolveLegacyKey(legacyKey)
    if Core.CharacterCleanup then
        local blocked = Core.CharacterCleanup:IsLegacyImportBlocked(sourceAddon, legacyKey, proposedID, data)
        if blocked then return nil, Core:Text("CORE.THIS_CHARACTER_CACHE_WAS_DELETED_BY_THE") end
    end

    local characterID = self:ResolveLegacyKey(legacyKey)
    local resolved = characterID and store.byID[characterID] or nil
    if resolved and data.name and data.realm
        and (tostring(resolved.name) ~= tostring(data.name) or tostring(resolved.realm) ~= tostring(data.realm)) then
        -- An alias created from a reversed historical key may point at the
        -- wrong record.  Prefer an existing exact identity before creating a
        -- fallback record, and let AddAlias repair the alias below.
        characterID = nil
        for id, candidate in pairs(store.byID) do
            if tostring(candidate.name) == tostring(data.name) and tostring(candidate.realm) == tostring(data.realm) then
                characterID = id
                break
            end
        end
    end
    if not characterID then
        characterID = data.id or BuildFallbackID(data.name or legacyKey, data.realm)
    end

    local record = store.byID[characterID] or {}
    record.id = characterID
    record.name = data.name or record.name or legacyKey or "Unknown"
    record.realm = data.realm or record.realm or "Unknown"
    record.class = data.class or record.class or "UNKNOWN"
    record.level = tonumber(data.level) or record.level or 1
    record.lastSeenAt = tonumber(data.lastSeenAt) or record.lastSeenAt
    record.seenOrder = tonumber(data.seenOrder) or record.seenOrder or EnsureSeenOrder(store, characterID)
    record.sources = record.sources or {}
    record.sources[tostring(sourceAddon or "legacy")] = true
    store.byID[characterID] = record
    store.seenOrder[characterID] = record.seenOrder

    AddAlias(store, characterID, legacyKey)
    for _, alias in ipairs(self:BuildLegacyAliases(record.name, record.realm)) do
        AddAlias(store, characterID, alias)
    end

    self:InvalidateAllCache()
    Core.Events:Fire("CHARACTER_IMPORTED", characterID, tostring(sourceAddon or "legacy"), Snapshot(record))
    return characterID, Snapshot(record)
end

if Core.Events then
    Core.Events:Register("DATA_DOMAIN_UPDATED", Characters, function()
        Characters:InvalidateAllCache()
    end)
end

Core.Capabilities:Register("characters", 1)
Core.Capabilities:Register("character-identity", 1)
Core.Capabilities:Register("character-name-format", 1)
]=====]
baseline["YiboCore/Data/Fields/CharacterArchive.lua"] = [=====[local Core = _G.YiboCore

local SECONDARY_SLOTS = { [3] = 794, [4] = 356, [5] = 185, [6] = 129 }

local function Profile(character) return character and character.profile or {} end
local function Profession(character, data, slot, skillLine)
    local profile = data or Profile(character)
    if slot then return (profile.primaryProfessions and profile.primaryProfessions[slot]) or (profile.professions and profile.professions[slot]) end
    for _, item in ipairs(profile.professions or {}) do
        if item.id == skillLine or SECONDARY_SLOTS[tonumber(item.slot)] == skillLine then return item end
    end
end
local function ProfessionValue(slot, skillLine)
    return function(character, data) return Profession(character, data, slot, skillLine) end
end
local function ProfessionFormat(value) return value and tostring(value.skillLevel or "?") or "—" end
local function ProfessionIcon(value) return value and value.icon end

local function Register(definition)
    definition.title = Core:Text(definition.titleKey)
    local entry = assert(Core.Fields:Register("YiboCore", definition))
    Core.Locale:BindText(entry, "title", definition.titleKey)
end

Register({ id = "character.identity", consumer = "character-archive", domain = "identity", titleKey = "CORE.CHARACTER", order = 10, width = 210, maxWidth = 260, defaultVisible = true, defaultPreviewVisible = true,
    Read = function(character) return character end, Format = function(value) return value and Core.Characters:FormatName({ name = tostring(value.name or Core:Text("CORE.UNKNOWN_CHARACTER")), realm = tostring(value.realm or Core:Text("CORE.UNKNOWN_REALM")) }, { realmMode = "full" }) or "—" end,
    GetColor = function(_, character) local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]; return color and { color.r, color.g, color.b } end })
Register({ id = "character.level", consumer = "character-archive", domain = "identity", titleKey = "CORE.LEVEL", order = 20, width = 42, gapAfter = 12, defaultVisible = true, defaultPreviewVisible = true,
    Read = function(character) return character and character.level end })
Register({ id = "character.item-level", consumer = "character-archive", domain = "equipment", titleKey = "CORE.ITEM_LEVEL", order = 30, width = 50, gapAfter = 12, defaultVisible = true, defaultPreviewVisible = true,
    Read = function(character, data) return data and data.itemLevel or Profile(character).itemLevel end, Format = function(value) return value and string.format("%.0f", value) or "—" end })
Register({ id = "character.zone", consumer = "character-archive", domain = "location", titleKey = "CORE.LOCATION", order = 40, width = 110, maxWidth = 140, defaultVisible = true, defaultPreviewVisible = true,
    Read = function(character, data) return data and data.zone or Profile(character).zone end, Format = function(value) return value or Core:Text("CORE.UNKNOWN_LOCATION") end })
Register({ id = "character.profession-primary", consumer = "character-archive", domain = "professions", titleKey = "CORE.PRIMARY_PROFESSION", order = 50, width = 92, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(1), Format = ProfessionFormat, GetIcon = ProfessionIcon })
Register({ id = "character.profession-secondary", consumer = "character-archive", domain = "professions", titleKey = "CORE.SECOND_PROFESSION", order = 60, width = 92, gapAfter = 4, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(2), Format = ProfessionFormat, GetIcon = ProfessionIcon })
Register({ id = "character.archaeology", consumer = "character-archive", domain = "professions", titleKey = "CORE.ARCHAEOLOGY", order = 70, width = 54, defaultVisible = false, defaultPreviewVisible = false, Read = ProfessionValue(nil, 794), Format = ProfessionFormat })
Register({ id = "character.fishing", consumer = "character-archive", domain = "professions", titleKey = "CORE.FISHING", order = 80, width = 54, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(nil, 356), Format = ProfessionFormat })
Register({ id = "character.cooking", consumer = "character-archive", domain = "professions", titleKey = "CORE.COOKING", order = 90, width = 54, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(nil, 185), Format = ProfessionFormat })
Register({ id = "character.first-aid", consumer = "character-archive", domain = "professions", titleKey = "CORE.FIRST_AID", order = 100, width = 54, defaultVisible = true, defaultPreviewVisible = true, Read = ProfessionValue(nil, 129), Format = ProfessionFormat })
]=====]
baseline["YiboCore/Runtime/Commands.lua"] = [=====[local Core = _G.YiboCore

-- /yco is a player-facing shortcut.  Release builds deliberately do not
-- expose registry, character-cache, or runtime diagnostics through chat.
SLASH_YIBOCORE1 = "/yco"
SlashCmdList.YIBOCORE = function(message)
    message = string.lower(strtrim(message or ""))
    if message == "" and Core.AccountView then
        Core.AccountView:Toggle()
    elseif message == "settings" and Core.AccountView then
        Core.AccountView:ShowSettings()
    else
        Core:Print(Core:Text("CORE.COMMAND_YCO_SETTINGS"))
    end
end
]=====]
baseline["YiboCore/Locales/enUS.lua"] = [=====[-- Core-owned resources. Keys are stable and independent of display text.
local Core = _G.YiboCore
Core.Locale:Register("YiboCore", "en", {
    ["ARCHIVE.FIELD_CONFLICT"] = "Archive field ID conflict; duplicate providers were isolated: %s",
    ["CORE.REPUTATION_CHARACTER_SNAPSHOTS"] = "Character reputation snapshots",
    ["CORE.CFF20E070_YIBO_R_CORE"] = "|cff20e070[Yibo]|r Core: ",
    ["CORE.BEAST_PATHS"] = "Beast Paths",
    ["CORE.BOSS_TRACKER"] = "Boss Tracker",
    ["CORE.TRACK_WORLD_BOSSES_HOLIDAY_BOSSES_AND_CUSTOM"] = "Track world bosses, holiday bosses, and custom targets across characters; instance lockout tracking is planned.",
    ["CORE.CHARACTER_BUILDS"] = "Character Builds",
    ["CORE.VIEW_EQUIPMENT_TALENTS_AND_GLYPH_BUILDS_ACROSS"] = "View equipment, talents, and glyph builds across characters.",
    ["CORE.CURRENCY_MANAGER"] = "Currency Manager",
    ["CORE.TRACK_CURRENCIES_ACROSS_CHARACTERS"] = "Track currencies across characters.",
    ["CORE.CRAFTING"] = "Crafting",
    ["CORE.VIEW_CONFIRMED_LEARNED_PROFESSION_RECIPES_ACROSS_CHARACTERS"] = "View confirmed learned profession recipes across characters.",
    ["CORE.LEGENDARY_PATHS"] = "Legendary Paths",
    ["CORE.TRACK_LEGENDARY_ITEM_COLLECTION_PROGRESS"] = "Track legendary item collection progress.",
    ["CORE.QUEST_BLOCKER"] = "Quest Blocker",
    ["CORE.QUEST_PREREQUISITES_AND_BLOCKING_CONDITIONS"] = "Quest prerequisites and blocking conditions.",
    ["CORE.ACCOUNT_TO_DO"] = "Account To-do",
    ["CORE.ACCOUNT_TASKS"] = "Account tasks.",
    ["CORE.ITEM_OVERVIEW"] = "Item Overview",
    ["CORE.FIND_ITEMS_IN_BAGS_EQUIPMENT_AND_OTHER"] = "Find items in bags, equipment, and other verified storage sources across characters.",
    ["CORE.MAIL_ASSISTANT"] = "Mail Assistant",
    ["CORE.MAIL_SNAPSHOTS_BACKLOG_CACHES_AND_ATTACHMENT_SOURCES"] = "Mail snapshots, backlog caches, and attachment sources across characters.",
    ["CORE.REPUTATION_PATHS"] = "Reputation Paths",
    ["CORE.REPUTATION_PROGRESS_ACROSS_CHARACTERS"] = "Reputation progress across characters.",
    ["CORE.AUTO_OPEN"] = "Auto Open",
    ["CORE.SAFELY_OPEN_CONTAINER_ITEMS_FROM_THE_ACCOUNT"] = "Safely open container items from the account catalog.",
    ["CORE.HIDDEN_HUNTER_PET_ROUTES_IN_PANDARIA"] = "Hidden hunter pet routes in Pandaria.",
    ["CORE.MOUNT_JOURNAL"] = "Mount Journal",
    ["CORE.SHOW_MOUNT_SOURCES_IN_AURAS_CHAT_LINKS"] = "Show mount sources in auras, chat links, and mount journal tooltips.",
    ["CORE.BOSS_TRACKER_CHARACTER_RECORDS"] = "Boss Tracker character records",
    ["CORE.LEGENDARY_PATHS_CHARACTER_PROGRESS"] = "Legendary Paths character progress",
    ["CORE.QUEST_BLOCKER_PERSONAL_SETTINGS"] = "Quest Blocker personal settings",
    ["CORE.ACCOUNT_INVENTORY_SNAPSHOTS"] = "Account inventory snapshots",
    ["CORE.MAIL_SNAPSHOTS_AND_BACKLOG_CACHE"] = "Mail snapshots and backlog cache",
    ["CORE.DATA_OWNER_DOES_NOT_PROVIDE"] = "Data owner does not provide ",
    ["CORE.DATA_OWNER_IS_CURRENTLY_UNAVAILABLE"] = "Data owner is currently unavailable.",
    ["CORE.FAILED_TO_DELETE_CHARACTER_CACHE"] = "Failed to delete character cache.",
    ["CORE.INVALID_CHARACTER_DATA_OWNER_REGISTRATION"] = "Invalid character data owner registration.",
    ["CORE.CHARACTER_DATA_OWNER_S_ADDON_IS_NOT"] = "Character data owner's addon is not registered: ",
    ["CORE.CHARACTER_DATA_OWNERS_MUST_PROVIDE_INSPECT_AND"] = "Character data owners must provide Inspect and Delete.",
    ["CORE.CHARACTER_DATA_OWNER_ALREADY_REGISTERED"] = "Character data owner already registered: ",
    ["CORE.CHARACTER_CACHE_DOES_NOT_EXIST"] = "Character cache does not exist.",
    ["CORE.CANNOT_READ_CACHE_SUMMARY"] = "Cannot read cache summary.",
    ["CORE.ADDON_NOT_LOADED_CLEAN_UP_WHEN_IT"] = "Addon not loaded; clean up when it next loads",
    ["CORE.CANNOT_READ_CHARACTER_CACHE"] = "Cannot read character cache.",
    ["CORE.ADDON_IS_NOT_LOADED"] = "Addon is not loaded.",
    ["CORE.SHORT_NAME_MUST_BE_TEXT"] = "Short name must be text.",
    ["CORE.SHORT_NAME_CANNOT_CONTAIN_CONTROL_CHARACTERS"] = "Short name cannot contain control characters.",
    ["CORE.NO_CHARACTER_SELECTED"] = "No character selected.",
    ["CORE.CANNOT_DELETE_THE_LOGGED_IN_CHARACTER_SWITCH"] = "Cannot delete the logged-in character. Switch to another character first.",
    ["CORE.NO_VALID_CHARACTER_DATA"] = "No valid character data.",
    ["CORE.THIS_CHARACTER_CACHE_WAS_DELETED_BY_THE"] = "This character cache was deleted by the user; reimport rejected.",
    ["CORE.DATABASE_NOT_LOADED"] = "Database not loaded: ",
    ["CORE.CHARACTER_NOT_FOUND"] = "Character not found: ",
    ["CORE.INVALID_DOMAIN_STATE"] = "Invalid domain state: ",
    ["CORE.UNREGISTERED_DOMAIN"] = "Unregistered domain: ",
    ["CORE.YIBOCORE_DATA_IS_NEWER_THAN_THIS_ADDON"] = "YiboCore data is newer than this addon version.",
    ["CORE.MISSING_DATABASE_MIGRATION_STEP_V"] = "Missing database migration step v",
    ["CORE.CHARACTER_PROFILE_COLLECTORS_REQUIRE_A_NAME_AND"] = "Character profile collectors require a name and callback.",
    ["CORE.CHARACTER_PROFILE_COLLECTOR_ALREADY_EXISTS"] = "Character profile collector already exists: ",
    ["CORE.CHARACTER_PROFILE_COLLECTOR"] = "Character profile collector \"",
    ["CORE.FAILED"] = "\" failed: ",
    ["CORE.COMMAND_YCO_SETTINGS"] = "Command: /yco [settings]",
    ["CORE.CURRENCY_CATALOGS_MUST_DECLARE_OWNER"] = "Currency catalogs must declare owner.",
    ["CORE.CURRENCY_CATALOG_ENTRIES_REQUIRE_A_STABLE_ID"] = "Currency catalog entries require a stable id.",
    ["CORE.IS_ALREADY_REGISTERED_BY"] = " is already registered by ",
    ["CORE.PUNCTUATION"] = ": ",
    ["CORE.STANDARD_CURRENCIES_REQUIRE_CURRENCYID"] = "Standard currencies require currencyID.",
    ["CORE.STANDARD_CURRENCY"] = "Standard currency",
    ["CORE.ITEM_CURRENCIES_REQUIRE_ITEMID"] = "Item currencies require itemID.",
    ["CORE.ITEM_CURRENCY"] = "Item currency",
    ["CORE.ITEM_CURRENCY_IS_NOT_IN_THE_CORE"] = "Item currency is not in the Core catalog.",
    ["CORE.ONLY_THE_REGISTERING_ADDON_CAN_REMOVE_THIS"] = "Only the registering addon can remove this item currency.",
    ["CORE.DOMAIN_EVENTS_MUST_BE_A_SET_OF"] = "Domain events must be a set of event names.",
    ["CORE.DOMAIN_EVENTS_MAY_ONLY_CONTAIN_ENABLED_EVENT"] = "Domain events may only contain enabled event names.",
    ["CORE.DOMAINS_MUST_DECLARE_OWNER"] = "Domains must declare owner.",
    ["CORE.DOMAIN_DEFINITION_CANNOT_BE_EMPTY"] = "Domain definition cannot be empty.",
    ["CORE.DOMAINS_REQUIRE_ID"] = "Domains require id.",
    ["CORE.DOMAIN_VERSION_MUST_BE_A_POSITIVE_INTEGER"] = "Domain version must be a positive integer.",
    ["CORE.DOMAINS_REQUIRE_A_COLLECT_CALLBACK"] = "Domains require a Collect callback.",
    ["CORE.DOMAIN_ID_IS_ALREADY_OWNED_BY"] = "Domain ID is already owned by ",
    ["CORE.PUNCTUATION_79"] = ": ",
    ["CORE.DOMAIN"] = "Domain \"",
    ["CORE.RETURNED_AN_INVALID_STATE"] = "\" returned an invalid state: ",
    ["CORE.COLLECTION_FAILED"] = "\" collection failed: ",
    ["CORE.EVENT_CALLBACK_FAILED"] = "Event callback failed: ",
    ["CORE.FIELDS_MUST_DECLARE_OWNER"] = "Fields must declare owner.",
    ["CORE.FIELD_DEFINITION_CANNOT_BE_EMPTY"] = "Field definition cannot be empty.",
    ["CORE.FIELDS_REQUIRE_ID"] = "Fields require id.",
    ["CORE.FIELDS_REQUIRE_CONSUMER"] = "Fields require consumer.",
    ["CORE.FIELDS_MUST_REFERENCE_A_REGISTERED_DOMAIN"] = "Fields must reference a registered domain.",
    ["CORE.FIELDS_MUST_REFERENCE_A_REGISTERED_RESOURCE"] = "Fields must reference a registered resource.",
    ["CORE.FIELDS_REQUIRE_A_READ_CALLBACK"] = "Fields require a Read callback.",
    ["CORE.FIELD_ID_IS_ALREADY_OWNED_BY"] = "Field ID is already owned by ",
    ["CORE.FIELDS_REQUIRE_A_NUMERIC_ORDER"] = "Fields require a numeric order.",
    ["CORE.ENTER_AN_ITEM_ID_LINK_OR_NAME"] = "Enter an item ID, link, or name.",
    ["CORE.ENTER_A_POSITIVE_ITEM_ID_OR_A"] = "Enter a positive item ID or a valid item link.",
    ["CORE.NO_MATCHING_ITEM_IN_BAGS_OR_KNOWN"] = "No matching item in bags or known catalogs; use an item ID or link.",
    ["CORE.ITEM_INFORMATION_COULD_NOT_LOAD_CHECK_THE"] = "Item information could not load; check the ID and retry.",
    ["CORE.ITEM_INFORMATION_CALLBACK_FAILED"] = "Item information callback failed: ",
    ["CORE.INVALID_ITEM_ID"] = "Invalid item ID.",
    ["CORE.ADDON_NAME_CANNOT_BE_EMPTY"] = "Addon name cannot be empty.",
    ["CORE.REQUIRES_API"] = "Requires API ",
    ["CORE.AVAILABLE_VERSION_IS"] = "; available version is ",
    ["CORE.RESOURCE_TYPE_AND_IDENTIFIER_CANNOT_BE_EMPTY"] = "Resource type and identifier cannot be empty.",
    ["CORE.IDENTIFIER_IS_RESERVED_BY_CORE"] = "Identifier is reserved by Core: ",
    ["CORE.RESOURCES_MUST_DECLARE_THEIR_ADDON_OWNER"] = "Resources must declare their addon owner.",
    ["CORE.S_ID_IS_ALREADY_OWNED_BY_ADDON"] = "%s ID is already owned by addon %s: %s",
    ["CORE.RESOURCE_DOES_NOT_BELONG_TO_THIS_ADDON"] = "Resource does not belong to this addon.",
    ["CORE.RESOURCES_MUST_DECLARE_OWNER"] = "Resources must declare owner.",
    ["CORE.RESOURCE_DEFINITION_CANNOT_BE_EMPTY"] = "Resource definition cannot be empty.",
    ["CORE.RESOURCES_REQUIRE_ID"] = "Resources require id.",
    ["CORE.RESOURCES_MUST_REFERENCE_A_REGISTERED_DOMAIN"] = "Resources must reference a registered domain.",
    ["CORE.RESOURCES_REQUIRE_A_READ_CALLBACK"] = "Resources require a Read callback.",
    ["CORE.RESOURCE_ID_IS_ALREADY_OWNED_BY"] = "Resource ID is already owned by ",
    ["CORE.SETTINGS_PANEL_S_ADDON_IS_NOT_REGISTERED"] = "Settings panel's addon is not registered.",
    ["CORE.SETTINGS_PANELS_REQUIRE_ID"] = "Settings panels require id.",
    ["CORE.SETTINGS_PANELS_REQUIRE_TITLE"] = "Settings panels require title.",
    ["CORE.SETTINGS_PANELS_REQUIRE_CREATESETTINGSPANEL"] = "Settings panels require CreateSettingsPanel.",
    ["CORE.SETTINGS_PANEL_DESCRIPTION_MUST_BE_A_STRING"] = "Settings panel description must be a string.",
    ["CORE.SETTINGS_PANEL_ICON_MUST_BE_A_STRING"] = "Settings panel icon must be a string.",
    ["CORE.SETTINGS_PANEL_ID_IS_ALREADY_OWNED_BY"] = "Settings panel ID is already owned by addon ",
    ["CORE.PUNCTUATION_120"] = ".",
    ["CORE.SETTINGS_PANEL_DOES_NOT_BELONG_TO_THIS"] = "Settings panel does not belong to this addon.",
    ["CORE.RECENT_LOGIN"] = "Recent login",
    ["CORE.CHARACTER_NAME"] = "Character name",
    ["CORE.CHARACTER_LEVEL"] = "Character level",
    ["CORE.CUSTOM"] = "Custom",
    ["CORE.CHARACTER"] = "Character",
    ["CORE.ACCOUNT_PAGE"] = "Account page \"",
    ["CORE.SIZE_MEASUREMENT_FAILED_USING_COMPATIBLE_DIMENSIONS"] = "\" size measurement failed; using compatible dimensions.",
    ["CORE.INVALID_PAGE_REGISTRATION"] = "Invalid page registration.",
    ["CORE.PAGES_REQUIRE_ID_AND_TITLE"] = "Pages require id and title.",
    ["CORE.PAGES_REQUIRE_CREATE_AND_REFRESH"] = "Pages require Create and Refresh.",
    ["CORE.PAGE_GETELIGIBLECHARACTERS_MUST_BE_A_FUNCTION"] = "Page GetEligibleCharacters must be a function.",
    ["CORE.PAGE_CHARACTERFILTER_REQUIRES_GETEXPRESSION_AND_SETEXPRESSION"] = "Page characterFilter requires GetExpression and SetExpression.",
    ["CORE.PAGE_GETSURFACEMETRICS_MUST_BE_A_FUNCTION"] = "Page GetSurfaceMetrics must be a function.",
    ["CORE.PAGE_GETLAYOUTMETRICS_MUST_BE_A_FUNCTION"] = "Page GetLayoutMetrics must be a function.",
    ["CORE.PAGE_GETMEASUREDHEIGHT_MUST_BE_A_FUNCTION"] = "Page GetMeasuredHeight must be a function.",
    ["CORE.PAGE_VIEWMODES_REQUIRES_AT_LEAST_TWO_OPTIONS"] = "Page viewModes requires at least two options.",
    ["CORE.PAGE_VIEWMODES_REQUIRES_ID_AND_TITLE"] = "Page viewModes requires id and title.",
    ["CORE.DUPLICATE_PAGE_VIEWMODE_ID"] = "Duplicate page viewMode ID: ",
    ["CORE.PAGE_GETHOVERMETRICS_MUST_BE_A_FUNCTION"] = "Page GetHoverMetrics must be a function.",
    ["CORE.PAGE_HASCHARACTERSNAPSHOT_MUST_BE_A_FUNCTION"] = "Page HasCharacterSnapshot must be a function.",
    ["CORE.PAGE_SCOPE_REQUIRES_DEFAULT_AND_VALUES"] = "Page scope requires default and values.",
    ["CORE.PAGE_SCOPE_VALUES_REQUIRES_ID_AND_TITLE"] = "Page scope.values requires id and title.",
    ["CORE.DUPLICATE_PAGE_SCOPE_ID"] = "Duplicate page scope ID: ",
    ["CORE.PAGE_SCOPE_DEFAULT_MUST_EXIST_IN_SCOPE"] = "Page scope.default must exist in scope.values.",
    ["CORE.PAGE_S_ADDON_HAS_NOT_REGISTERED_THROUGH"] = "Page's addon has not registered through Core:RegisterAddon: ",
    ["CORE.PAGE_SETTINGS_MUST_BE_A_TABLE"] = "Page settings must be a table.",
    ["CORE.PAGE_SETTINGS_TITLE_MUST_BE_A_STRING"] = "Page settings.title must be a string.",
    ["CORE.PAGE_SETTINGS_DESCRIPTION_MUST_BE_A_STRING"] = "Page settings.description must be a string.",
    ["CORE.PAGE_FIELDS_REQUIRE_ID"] = "Page fields require id.",
    ["CORE.DUPLICATE_PAGE_FIELD_ID"] = "Duplicate page field ID: ",
    ["CORE.PAGE_ID_IS_ALREADY_IN_USE"] = "Page ID is already in use: ",
    ["CORE.INVALID_LEVEL_RULE"] = "Invalid level rule: ",
    ["CORE.FAILED_154"] = " failed: ",
    ["CORE.THIS_PAGE_IS_TEMPORARILY_UNAVAILABLE_N"] = "This page is temporarily unavailable.\n",
    ["CORE.CREATE"] = "Create",
    ["CORE.SORT"] = "Sort: ",
    ["CORE.USES_SHARED_SETTINGS"] = "Uses shared settings.",
    ["CORE.USES_PAGE_SPECIFIC_SETTINGS"] = "Uses page-specific settings.",
    ["CORE.LEFT_CLICK_TO_CHANGE_SORT_SHIFT_CLICK"] = " Left-click to change sort; Shift-click to reverse direction.",
    ["CORE.ACCOUNT_PAGE_161"] = "Account page \"",
    ["CORE.COULD_NOT_READ_CHARACTER_SNAPSHOTS"] = "\" could not read character snapshots: ",
    ["CORE.ALL_REALMS"] = "All realms",
    ["CORE.OTHER_V"] = "Other v",
    ["CORE.ACCOUNT_OVERVIEW"] = "Account Overview",
    ["CORE.CHARACTER_STATUS"] = "Character status",
    ["CORE.SORT_RECENT_LOGIN"] = "Sort: Recent login ↓",
    ["CORE.CHARACTER_SORTING"] = "Character sorting",
    ["CORE.SETTINGS"] = "Settings",
    ["CORE.BACK"] = "‹ Back ",
    ["CORE.CORE_SETTINGS"] = "Core Settings",
    ["CORE.WINDOW"] = "Window",
    ["CORE.CHARACTERS_SORTING"] = "Characters & Sorting",
    ["CORE.DISPLAY_ENTRIES"] = "Display & Entries",
    ["CORE.CHARACTER_ELIGIBILITY_FAILED"] = ") character eligibility failed: ",
    ["CORE.CHARACTER_ELIGIBILITY_MUST_RETURN_A_TABLE"] = ") character eligibility must return a table.",
    ["CORE.REFRESH"] = "Refresh",
    ["CORE.CONTROLS"] = "Controls",
    ["CORE.ACCOUNT_OVERVIEW_CHARACTER_STATUS"] = "Account Overview · Character Status",
    ["CORE.HOVER_MEASUREMENT_FAILED_USING_COMPATIBLE_DIMENSIONS"] = "\" hover measurement failed; using compatible dimensions.",
    ["CORE.CANNOT_OPEN_SETTINGS_IN_COMBAT_TRY_AGAIN"] = "Cannot open settings in combat. Try again after combat.",
    ["CORE.LEFT_CLICK"] = "Left-click",
    ["CORE.RIGHT_CLICK"] = "Right-click",
    ["CORE.MIDDLE_CLICK"] = "Middle-click",
    ["CORE.MOUSE_4"] = "Mouse 4",
    ["CORE.MOUSE_5"] = "Mouse 5",
    ["CORE.LEAVE_COMBAT_BEFORE_CHANGING_HOW_TARGETS_ARE"] = "Leave combat before changing how targets are added.",
    ["CORE.TOP_RIGHT_BUTTON"] = "Top-right button",
    ["CORE.CTRL_CLICK"] = "Ctrl-click",
    ["CORE.CHOOSE_A_VALID_MOUSE_BUTTON"] = "Choose a valid mouse button",
    ["CORE.THIS_BINDING_CONFLICTS_WITH_A_BUSINESS_ACTION"] = "This binding conflicts with a business action. Choose another combination; secure action bindings cannot be reused.",
    ["CORE.ITEM_IS_NO_LONGER_AVAILABLE"] = "Item is no longer available",
    ["CORE.THIS_ITEM_HAS_NO_TARGET_TO_ADD"] = "This item has no target to add",
    ["CORE.ACTION_CENTER_IS_NOT_READY_ENABLE_A"] = "Action Center is not ready. Enable a compatible version.",
    ["CORE.REMOVING_TARGETS_REQUIRES_A_NEWER_ACTION_CENTER"] = "Removing targets requires a newer Action Center. Please upgrade.",
    ["CORE.REMOVAL_FAILED"] = "Removal failed",
    ["CORE.TARGET_REMOVED_FROM_ACTION_CENTER"] = "Target removed from Action Center.",
    ["CORE.ADD_FAILED"] = "Add failed",
    ["CORE.THIS_ITEM_REQUIRES_TARGET_DETAILS_CLICK_ITS"] = "This item requires target details. Click its + button to configure.",
    ["CORE.THIS_TARGET_IS_ALREADY_IN_ACTION_CENTER"] = "This target is already in Action Center.",
    ["CORE.ADDED_LOCATING_TARGET"] = "Added; locating target.",
    ["CORE.ADDED_TO_ACTION_CENTER"] = "Added to Action Center.",
    ["CORE.THIS_ADD_GESTURE_CONFLICTS_WITH_THE_ITEM"] = "This add gesture conflicts with the item action. Choose another in Core window settings.",
    ["CORE.TOP_RIGHT_ADD_CONFIGURE_CHECK_MARK_LOCATE"] = "Top-right +: add/configure; check mark: locate target",
    ["CORE.COMPACT_TARGET_TOGGLE"] = "%s: add/remove target",
    ["CORE.COMPACT_TARGET_MENU"] = "Top-right: add/view target",
    ["CORE.ADD_REMOVE_WHILE_KEEPING_THE_WINDOW_OPEN"] = ": add/remove while keeping the window open; use the temporary + for required details",
    ["CORE.TARGETS_ADDED"] = "Targets added · ",
    ["CORE.ACTIVE"] = " (active ",
    ["CORE.PAUSED"] = " / paused ",
    ["CORE.COMPLETE"] = " / complete ",
    ["CORE.ADD_TO_ACTION_CENTER"] = "Add to Action Center",
    ["CORE.CLICK_TO_ADD_OR_ENTER_DETAILS_OPEN"] = "Click to add or enter details; open the target if already added. Add gestures keep the current window open.",
    ["CORE.HIDDEN"] = "Hidden",
    ["CORE.BROKER_ONLY"] = "Broker only",
    ["CORE.MINIMAP_ONLY"] = "Minimap only",
    ["CORE.BOTH"] = "Both",
    ["CORE.BROKER_NAME_CONFLICT_DATA_SOURCE_LEFT_UNCHANGED"] = "Broker name conflict; data source left unchanged: ",
    ["CORE.YIBO_ACCOUNT_OVERVIEW"] = "[Yibo] Account Overview",
    ["CORE.BUSINESS_ENTRIES_REQUIRE_ADDON_NAME_ID_AND"] = "Business entries require addon name, id, and pageID.",
    ["CORE.ENTRY_S_ADDON_IS_NOT_REGISTERED"] = "Entry's addon is not registered: ",
    ["CORE.BUSINESS_ENTRY_BROKERNAME_MUST_BE_A_NON"] = "Business entry brokerName must be a non-empty string.",
    ["CORE.BUSINESS_ENTRY_RESOLVEPAGEID_MUST_BE_A_FUNCTION"] = "Business entry resolvePageID must be a function.",
    ["CORE.INVALID_BUSINESS_ENTRY_DEFAULTMODE"] = "Invalid business entry defaultMode.",
    ["CORE.ENTRY_TARGET_PAGE_DOES_NOT_EXIST"] = "Entry target page does not exist: ",
    ["CORE.ENTRIES_MAY_ONLY_BIND_TO_PAGES_OWNED"] = "Entries may only bind to pages owned by the same addon.",
    ["CORE.LEFT_CLICK_TO_OPEN_CHARACTER_STATUS"] = "Left-click to open character status",
    ["CORE.CHOOSE_GAME_ICON"] = "Choose Game Icon",
    ["CORE.AUTOMATIC_ICON"] = "Automatic icon",
    ["CORE.CONFIRM"] = "Confirm",
    ["CORE.CANCEL"] = "Cancel",
    ["CORE.PREVIOUS"] = "Previous",
    ["CORE.NEXT"] = "Next",
    ["CORE.CLIENT_ICON_LIST_IS_UNAVAILABLE_USE_AN"] = "Client icon list is unavailable. Use an automatic icon.",
    ["CORE.ICON_SELECTED_CONFIRM_TO_SAVE"] = "Icon selected. Confirm to save.",
    ["CORE.AUTOMATIC_ICON_USE_THE_RECIPIENT_S_CLASS"] = "Automatic icon: use the recipient's class icon, or a generic icon for unknown classes.",
    ["CORE.ICONS"] = " icons",
    ["CORE.ITEM"] = "Item",
    ["CORE.CHOOSE_MATCH"] = "Choose match · ",
    ["CORE.NO_MATCHES"] = "No matches",
    ["CORE.OPERATION_SUCCEEDED"] = "Operation succeeded.",
    ["CORE.OPERATION_FAILED"] = "Operation failed.",
    ["CORE.THIS_OPERATION_IS_DISABLED"] = "This operation is disabled.",
    ["CORE.CANCELLED_INPUT_PRESERVED"] = "Cancelled; input preserved.",
    ["CORE.CANNOT_OPEN_CONFIRMATION_PLEASE_RETRY"] = "Cannot open confirmation. Please retry.",
    ["CORE.FILL_IN_EVERY_ITEM_DO_NOT_LEAVE"] = "Fill in every item; do not leave empty entries between separators.",
    ["CORE.ITEM_245"] = "Item ",
    ["CORE.PUNCTUATION_246"] = ": ",
    ["CORE.HAS_MULTIPLE_MATCHES_USE_AN_ITEM_ID"] = " has multiple matches. Use an item ID or link.",
    ["CORE.LOADING"] = "Loading ",
    ["CORE.ITEMS"] = " items…",
    ["CORE.MULTIPLE_ITEMS_FOUND_SELECT_A_MATCH_BEFORE"] = "Multiple items found. Select a match before continuing.",
    ["CORE.LOADING_ITEM_INFORMATION"] = "Loading item information…",
    ["CORE.ITEM_ID_LINK_OR_NAME"] = "Item ID, link, or name",
    ["CORE.CLICK_THE_ACTION_BUTTON_AGAIN_TO_SUBMIT"] = "; click the action button again to submit.",
    ["CORE.ADD_ITEM"] = "Add Item",
    ["CORE.DROP_ITEM_HERE"] = "Drop item here",
    ["CORE.RETRY_LOAD"] = "Retry Load",
    ["CORE.THIS_OPERATION_IS_CURRENTLY_UNAVAILABLE"] = "This operation is currently unavailable.",
    ["CORE.DELETE_CUSTOM_ITEM"] = "Delete Custom Item",
    ["CORE.DRAG_AN_ITEM_HERE_FROM_YOUR_BAGS"] = "Drag an item here from your bags.",
    ["CORE.INVALID_ITEM_DROP"] = "Invalid item drop.",
    ["CORE.UNKNOWN"] = "Unknown",
    ["CORE.NOT_SYNCED"] = "Not synced",
    ["CORE.UNAVAILABLE"] = "Unavailable",
    ["CORE.EXPIRED"] = "Expired",
    ["CORE.ERROR"] = "Error",
    ["CORE.UNKNOWN_CHARACTER"] = "Unknown character",
    ["CORE.UNKNOWN_REALM"] = "Unknown realm",
    ["CORE.SHORT_NAME"] = "Short name",
    ["CORE.LAST_SYNCED"] = "Last synced",
    ["CORE.DATA_STATUS"] = "Data status",
    ["CORE.LOG_IN_TO_THIS_CHARACTER_TO_SYNC"] = "Log in to this character to sync.",
    ["CORE.FIELD"] = "Field",
    ["CORE.GENERAL"] = "General",
    ["CORE.COMPARE_CURRENCY_BALANCES_ACROSS_CHARACTERS_INCLUDING_STANDARD"] = "Compare currency balances across characters, including standard and item currencies.",
    ["CORE.TRACK_LEGENDARY_QUESTS_AND_EQUIPMENT_ACROSS_CHARACTERS"] = "Track legendary quests and equipment across characters.",
    ["CORE.IDENTIFY_QUEST_RESTRICTIONS_AND_RISKS_TO_AVOID"] = "Identify quest restrictions and risks to avoid accepting critical quests by mistake.",
    ["CORE.REVIEW_TASKS_AND_PROFESSION_COOLDOWNS_ACROSS_CHARACTERS"] = "Review tasks and profession cooldowns across characters to find your next action.",
    ["CORE.FIND_ITEMS_IN_BAGS_EQUIPMENT_BANKS_MAIL"] = "Find items in bags, equipment, banks, mail, and guild banks across characters.",
    ["CORE.COMPARE_REPUTATION_STANDINGS_AND_ADVANCEMENT_ACROSS_CHARACTERS"] = "Compare reputation standings and advancement across characters.",
    ["CORE.SHOW_RARE_HUNTER_PET_PATROL_ROUTES_ON"] = "Show rare hunter pet patrol routes on the map.",
    ["CORE.HIDE_LINK"] = "Hide Link",
    ["CORE.GET_LINK"] = "Get Link",
    ["CORE.OPTIONAL_INTEGRATION"] = "Optional integration",
    ["CORE.STANDALONE_ADDON"] = "Standalone addon",
    ["CORE.PRESS_CTRL_C_TO_COPY"] = "Press Ctrl+C to copy",
    ["CORE.MANAGE_YIBO_ACCOUNT_CHARACTERS_ENTRIES_AND_BUSINESS"] = "Manage Yibo account characters, entries, and business pages",
    ["CORE.CORE_DEPENDENT_ADDONS"] = "Core-dependent addons",
    ["CORE.OPTIONAL_INTEGRATIONS"] = "Optional integrations",
    ["CORE.EXPLORE_OTHER_YIBO_ADDONS"] = "Explore Other Yibo Addons",
    ["CORE.AUTHOR_YIBOSOFT_CURSEFORGE"] = "Author YiboSoft · CurseForge",
    ["CORE.CONNECTED"] = "Connected",
    ["CORE.ENABLED_NOT_CONNECTED"] = "Enabled, not connected",
    ["CORE.INSTALLED_DISABLED"] = "Installed, disabled",
    ["CORE.NOT_INSTALLED"] = "Not installed",
    ["CORE.INSTALLED"] = "Installed ",
    ["CORE.NOT_INSTALLED_LOCALLY"] = "Not installed locally",
    ["CORE.PACKAGED"] = " · Packaged ",
    ["CORE.UNKNOWN_STATUS"] = "Unknown status",
    ["CORE.CONNECTED_302"] = "Connected ",
    ["CORE.ADDONS"] = " addons",
    ["CORE.DATABASE_SCHEMA_V"] = " · Database schema v",
    ["CORE.ABOUT"] = "About",
    ["CORE.LEVEL"] = "Level",
    ["CORE.LOCATION"] = "Location",
    ["CORE.ITEM_LEVEL"] = "Item level",
    ["CORE.PROFESSIONS"] = "Professions",
    ["CORE.DELETE_CACHE"] = "Delete Cache",
    ["CORE.CHARACTER_CACHE_DELETION_FAILED"] = "Character cache deletion failed: ",
    ["CORE.CHARACTER_CACHE_REMOVED_FROM_THE_ACCOUNT_VIEW"] = "Character cache removed from the account view; ",
    ["CORE.ADDON_CACHES_WILL_RETRY_CLEANUP_WHEN_NEXT"] = " addon caches will retry cleanup when next loaded.",
    ["CORE.CHARACTER_CACHE_DELETED"] = "Character cache deleted.",
    ["CORE.DELETE_ADDON_CACHES_FOR"] = "Delete addon caches for \"",
    ["CORE.PUNCTUATION_316"] = "\"?",
    ["CORE.WILL_DELETE"] = "Will delete:",
    ["CORE.CORE_CHARACTER_PROFILE"] = "• Core character profile",
    ["CORE.CACHED"] = "Cached",
    ["CORE.NO_CACHE"] = "No cache",
    ["CORE.ACCOUNT_WIDE_SETTINGS_AND_THE_GAME_CHARACTER"] = "Account-wide settings and the game character will be kept.",
    ["CORE.DELETION_CANNOT_BE_UNDONE"] = "Deletion cannot be undone.",
    ["CORE.DEL"] = "Del",
    ["CORE.DELETE_CHARACTER_CACHE"] = "Delete Character Cache",
    ["CORE.DELETE_THIS_CHARACTER_S_CORE_AND_BUSINESS"] = "Delete this character's Core and business addon caches; the game character is kept.",
    ["CORE.CHARACTER_ARCHIVE"] = "Character Archive",
    ["CORE.YIBOCORE_ACCOUNT_OVERVIEW"] = "YiboCore · Account Overview",
    ["CORE.BROKER_MINIMAP_LEFT_CLICK_TO_TOGGLE_THE"] = "Broker/minimap: left-click to toggle the account view; right-click for settings; hover for character previews. Drag the minimap button to reposition it. Drag the window title bar to move the window. Click Sort to change character order; Shift-click to reverse direction. Drag bag items into the Core item picker's drop area when available.",
    ["CORE.YIBOALTOBOSS_BOSSES_LOCKOUTS"] = "YiboAltoBoss · Bosses & Lockouts",
    ["CORE.CLICK_A_CHARACTER_TARGET_STATUS_CELL_TO"] = "Click a character/target status cell to toggle its kill record, including manual holiday boss records. Press Enter to apply a level filter; Escape restores the saved filter.",
    ["CORE.YIBOLEGENDARY_LEGENDARY_PATHS"] = "YiboLegendary · Legendary Paths",
    ["CORE.CLICK_A_TARGET_COLUMN_OR_CHARACTER_PROGRESS"] = "Click a target column or character progress cell to open its route. For progress that supports manual confirmation, left-click to mark it obtained; right-click a manual record to undo.",
    ["CORE.YIBOQUESTBLOCKER_QUEST_BLOCKER"] = "YiboQuestBlocker · Quest Blocker",
    ["CORE.CLICK_A_QUEST_ROW_S_EXPAND_ICON"] = "Click a quest row's expand icon to expand or collapse its group. Click global or character status cells to toggle blocking. Press Enter to apply level conditions.",
    ["CORE.YIBOTODO_DAILY_ACTIONS"] = "YiboTodo · Daily Actions",
    ["CORE.CLICK_AN_AVAILABLE_ACTION_ICON_FOR_THE"] = "Click an available action icon for the current character to perform its action, such as using an item or opening a profession. Right-click icons that offer a second action. Tooltips and icon states describe the available actions.",
    ["CORE.YIBOMAIL_MAIL"] = "YiboMail · Mail",
    ["CORE.RULE_BASED_MAIL_DROP_A_BAG_ITEM"] = "Rule-based mail: drop a bag item onto a quick contact and confirm to create or update its sending rule. Outbox: drop an item onto a quick contact to fill recipient and subject and attempt to send; if sending is not confirmed, the filled mail remains for review and manual sending. Ctrl-click a bag item to attach all items of that type. Quick contacts: right-click to edit; drag to another slot to move or swap; drag out of the contact bar to remove. Inbox: left-click a message to toggle attachments, right-click to toggle the native message, and middle-click to collect its attachments. Alt-click an attachment group to collect one attachment from the earliest-expiring message.",
    ["CORE.YIBOCURRENCY_CURRENCY_OVERVIEW"] = "YiboCurrency · Currency Overview",
    ["CORE.RIGHT_CLICK_A_CURRENCY_ROW_TO_TOGGLE"] = "Right-click a currency row to toggle hover monitoring. Custom currencies ask for deletion confirmation first. Hover a row for details.",
    ["CORE.YIBOVAULT_ACCOUNT_STORAGE"] = "YiboVault · Account Storage",
    ["CORE.SELECT_A_CHARACTER_OR_GUILD_ON_THE"] = "Select a character or guild on the left to change the source, then select an area tab for bags, bank, or other storage. Hover an item for its tooltip and source information.",
    ["CORE.YIBOCRAFTING_PROFESSION_RECIPES"] = "YiboCrafting · Profession Recipes",
    ["CORE.CLICK_A_RECIPE_ROW_NAME_OR_ITEM"] = "Click a recipe row, name, or item icon to select it and view details. Use filters and search to narrow the list. Enter submits the search; Escape ends text entry.",
    ["CORE.YIBOREPUTATION_REPUTATION_OVERVIEW"] = "YiboReputation · Reputation Overview",
    ["CORE.CLICK_A_REPUTATION_NAME_TO_EXPAND_OR"] = "Click a reputation name to expand or collapse its category; click its star to toggle monitoring. Select a reputation entry to set it as watched.",
    ["CORE.YIBOBUILDS_EQUIPMENT_APPEARANCE"] = "YiboBuilds · Equipment & Appearance",
    ["CORE.MODEL_PREVIEW_DRAG_TO_ROTATE_AND_USE"] = "Model preview: drag to rotate and use the mouse wheel to zoom. Drop usable bag enchants or gems onto the matching equipment slot, then confirm to begin the game's native application flow. Use page buttons for other equipment, build, and appearance actions; replacing equipment requires confirmation.",
    ["CORE.YIBOAUTOOPEN_AUTO_OPEN"] = "YiboAutoOpen · Auto Open",
    ["CORE.IN_SETTINGS_DROP_A_BAG_ITEM_INTO"] = "In settings, drop a bag item into the drop area to add it to the auto-open catalog.",
    ["CORE.YIBOBEASTPATHS_BEAST_PATHS"] = "YiboBeastPaths · Beast Paths",
    ["CORE.CLICK_THE_ADDON_BUTTON_ON_THE_WORLD"] = "Click the addon button on the world map to toggle route display.",
    ["CORE.YIBOMOUNTS_MOUNT_JOURNAL"] = "YiboMounts · Mount Journal",
    ["CORE.USE_THE_COLLECTED_AND_NOT_COLLECTED_CHECKBOXES"] = "Use the Collected and Not Collected checkboxes in settings to control mount visibility.",
    ["CORE.ACCOUNT_OVERVIEW_355"] = "Account Overview",
    ["CORE.CHOOSE_A_BUSINESS_PAGE_ON_THE_LEFT"] = "Choose a business page on the left to compare characters' next actions.",
    ["CORE.DRAG_TO_ROTATE_MOUSE_WHEEL_TO_ZOOM"] = "Drag to rotate · Mouse wheel to zoom.",
    ["CORE.ACCOUNT_TO_DO_SETTINGS"] = "Account To-do Settings",
    ["CORE.EACH_SWITCH_CONTROLS_A_COLUMN_IN_THE"] = "Each switch controls a column in the account matrix. Columns with multiple items support individual selection.",
    ["CORE.REPUTATION_MONITORING_SETTINGS"] = "Reputation Monitoring Settings",
    ["CORE.ADD_STARS_QUICKLY_IN_THE_MAIN_MATRIX"] = "Add stars quickly in the main matrix; remove monitored reputations here in their current order.",
    ["CORE.QUICK_CONTROLS"] = "Quick Controls",
    ["CORE.MOUSE_AND_KEYBOARD_ACTIONS_BY_ADDON_ONLY"] = "Mouse and keyboard actions by addon. Only special gestures are listed; other buttons use a normal left-click.",
    ["CORE.INTERFACE_GUIDE"] = "Interface Guide",
    ["CORE.HELP"] = "Help",
    ["CORE.NEXT_ACTIONS"] = "Next Actions",
    ["CORE.ACCOUNT_OVERVIEW_COULD_NOT_READ_PAGE"] = "Account overview could not read page \"",
    ["CORE.S"] = ")'s ",
    ["CORE.NEXT_ACTIONS_SHOWING"] = "Next actions (showing ",
    ["CORE.NO_ACCOUNT_ACTIONS_NEED_ATTENTION"] = "No account actions need attention",
    ["CORE.ADDON"] = "Addon",
    ["CORE.OVERVIEW"] = "Overview",
    ["CORE.ALL_CHARACTERS"] = "All characters",
    ["CORE.WITH_PROFILES"] = "With profiles",
    ["CORE.WITHOUT_PROFILES"] = "Without profiles",
    ["CORE.RESET_LAYOUT"] = "Reset Layout",
    ["CORE.UP"] = "Up",
    ["CORE.DOWN"] = "Down",
    ["CORE.HIDE"] = "Hide",
    ["CORE.SHOW_PAGE"] = "Show page",
    ["CORE.SEPARATE_ENTRY"] = "Separate entry",
    ["CORE.WINDOW_HOVER"] = "Window hover",
    ["CORE.CORE_ENTRY"] = "Core entry",
    ["CORE.CLEAR"] = "Clear",
    ["CORE.DISPLAY_ENTRIES_385"] = "Display & Entries",
    ["CORE.CHARACTERS_SORTING_386"] = "Characters & Sorting",
    ["CORE.WINDOW_387"] = "Window",
    ["CORE.ADDON_388"] = "Addon",
    ["CORE.SETTINGS_389"] = " Settings",
    ["CORE.MANAGE_CORE_AND_ADDON_PAGES_SEPARATE_ENTRIES"] = "Manage Core and addon pages, separate entries, and visible fields.",
    ["CORE.MANAGE_CHARACTERS_SORTING_CACHES_AND_BUSINESS_PAGE"] = "Manage characters, sorting, caches, and business page character filters.",
    ["CORE.MANAGE_WINDOW_LAYOUT_TARGET_ADD_GESTURES_AND"] = "Manage window layout, target add gestures, and added-target marks.",
    ["CORE.ONLY_THIS_ADDON_S_BUSINESS_RULES_AND"] = "Only this addon's business rules and data management appear here.",
    ["CORE.INVALID_LEVEL_FILTER"] = "Invalid level filter: ",
    ["CORE.LEVEL_395"] = " · Level",
    ["CORE.COULD_NOT_SAVE_LEVEL_FILTER"] = "Could not save level filter: ",
    ["CORE.NO_SEPARATE_ENTRY"] = "No separate entry",
    ["CORE.TABLE"] = "Table",
    ["CORE.HOVER"] = "Hover",
    ["CORE.PAGE"] = "Page",
    ["CORE.VISIBLE"] = "Visible",
    ["CORE.ENTRY"] = "Entry",
    ["CORE.ENTRY_POSITION"] = "Entry position",
    ["CORE.PAGE_OPTIONS"] = "Page options",
    ["CORE.TABLE_FIELDS"] = "Table fields",
    ["CORE.HOVER_FIELDS"] = "Hover fields",
    ["CORE.HOVER_407"] = "Hover · ",
    ["CORE.ADDON_408"] = "Addon \"",
    ["CORE.BUSINESS_SETTINGS_REFRESH_FAILED"] = "\" business settings refresh failed: ",
    ["CORE.EMBEDDED_SETTINGS_CREATION_FAILED"] = "\" embedded settings creation failed: ",
    ["CORE.BUSINESS_SETTINGS_COULD_NOT_LOAD"] = "Business settings could not load: ",
    ["CORE.USE_SHARED_SETTINGS"] = "Use shared settings",
    ["CORE.SORT_DIRECTION"] = "Sort direction: ",
    ["CORE.ASCENDING"] = "Ascending ↑",
    ["CORE.DESCENDING"] = "Descending ↓",
    ["CORE.PIN_CURRENT_CHARACTER"] = "Pin current character",
    ["CORE.REBUILD_BY_RECENT_LOGIN"] = "Rebuild by recent login",
    ["CORE.RESTORE_REGISTRATION_ORDER"] = "Restore registration order",
    ["CORE.PREVIOUS_419"] = "Previous (",
    ["CORE.NEXT_420"] = "Next (",
    ["CORE.LEVELS"] = " levels",
    ["CORE.CURRENT_CHARACTER"] = "Current character",
    ["CORE.DUPLICATE_SHORT_NAME"] = " · Duplicate short name",
    ["CORE.COULD_NOT_SAVE_SHORT_NAME"] = "Could not save short name: ",
    ["CORE.DEFAULT_CHARACTER_SORTING"] = "Default Character Sorting",
    ["CORE.COLLAPSE_SHORT_NAMES"] = "Collapse short names",
    ["CORE.MANAGE_SHORT_NAMES"] = "Manage short names",
    ["CORE.CHARACTER_ORDER_CACHE"] = "Character Order & Cache",
    ["CORE.COLLAPSE_ORDER_AND_CACHE"] = "Collapse order and cache",
    ["CORE.OPEN_ORDER_AND_CACHE"] = "Open order and cache",
    ["CORE.BUSINESS_PAGE_CHARACTER_FILTERS"] = "Business Page Character Filters",
    ["CORE.RULES_90_LEVEL_90_ONLY_1_20"] = "Rules: 90 = level 90 only; 1-20 = level range; <=3 / >=85 = comparison; empty or 0 = no filter.",
    ["CORE.NO_BUSINESS_PAGES_SUPPORT_CHARACTER_FILTERS"] = "No business pages support character filters",
    ["CORE.CHARACTER_ARCHIVE_FILTERS"] = "Character Archive Filters",
    ["CORE.TABLE_FILTER"] = "Table filter: ",
    ["CORE.INCLUDE_HIDDEN_CHARACTERS_IN_TABLE_FILTER"] = "Include hidden characters in table filter",
    ["CORE.TABLE_LEVEL_FILTER"] = "Table level filter",
    ["CORE.CHARACTER_ARCHIVE_HOVER_FILTERS"] = "Character Archive Hover Filters",
    ["CORE.HOVER_FILTER"] = "Hover filter: ",
    ["CORE.INCLUDE_HIDDEN_CHARACTERS_IN_HOVER_FILTER"] = "Include hidden characters in hover filter",
    ["CORE.HOVER_LEVEL_FILTER"] = "Hover level filter",
    ["CORE.TOP_RIGHT_BUTTON_CHECK"] = "Top-right button (+/check)",
    ["CORE.MIDDLE_CLICK_443"] = "Middle-click",
    ["CORE.CTRL_CLICK_444"] = "Ctrl-click",
    ["CORE.PREVIOUS_CUSTOM_GESTURE"] = "Previous custom gesture: ",
    ["CORE.ADD_METHOD_CHOOSE_ONE"] = "Add method (choose one)",
    ["CORE.ADDED_TARGET_MARK"] = "Added-target mark",
    ["CORE.GOLD_CORNER_AT_BOTTOM_LEFT"] = "Gold corner at bottom left",
    ["CORE.TEAL_DOT_AT_BOTTOM_LEFT"] = "Teal dot at bottom left",
    ["CORE.MIDDLE_CLICK_OR_CTRL_CLICK_AGAIN_TO"] = "Middle-click or Ctrl-click again to remove.",
    ["CORE.WINDOW_LAYOUT"] = "Window Layout",
    ["CORE.RESET_WINDOW_POSITION"] = "Reset Window Position",
    ["CORE.WINDOW_SIZE_ADAPTS_TO_THE_CURRENT_PAGE"] = "Window size adapts to the current page content.",
    ["CORE.CORE_ADDON_PAGES"] = "Core & Addon Pages",
    ["CORE.NO_BUSINESS_ADDONS_REGISTERED"] = "No business addons registered",
    ["CORE.NO_ADDON_SPECIFIC_SETTINGS"] = "No addon-specific settings",
    ["CORE.UNKNOWN_LOCATION"] = "Unknown location",
    ["CORE.PRIMARY_PROFESSION"] = "Primary profession",
    ["CORE.SECOND_PROFESSION"] = "Second profession",
    ["CORE.ARCHAEOLOGY"] = "Archaeology",
    ["CORE.FISHING"] = "Fishing",
    ["CORE.COOKING"] = "Cooking",
    ["CORE.FIRST_AID"] = "First Aid",
    ["CORE.GOLD"] = "Gold",
    ["CORE.G"] = "g",
    ["LANGUAGE.TITLE"] = "Addon language",
    ["LANGUAGE.AUTO"] = "Follow client (default)",
    ["LANGUAGE.CHINESE"] = "中文",
    ["LANGUAGE.ENGLISH"] = "English",
    ["LANGUAGE.DESCRIPTION"] = "Changes addon text; game names stay unchanged.",
    ["LANGUAGE.PENDING"] = "Reload to apply.",
    ["LANGUAGE.RELOAD"] = "Reload UI",
    ["LANGUAGE.ACTIVE"] = "Current UI language: %s",
    ["FORMAT.COLON"] = ": ",
    ["FORMAT.CLOSE_PAREN"] = ")",
    ["FORMAT.NEXT_ACTIONS"] = "Next actions (showing %d / %d)",
    ["FORMAT.CACHE_CONFIRM"] = "Delete addon caches for \"%s\"?",
    ["FORMAT.PAGE_CALLBACK_FAILED"] = "Account overview: page \"%s\" (%s), %s failed: %s",
    ["FORMAT.ADDED_TARGETS"] = "Added targets · %d (active %d / paused %d / complete %d)",
    ["FORMAT.PERIOD"] = ".",
    ["FORMAT.QUOTE_OPEN_PAREN"] = "\" (",
})

Core.Locale:Register("YiboCore", "en", {
    ["ENTRY.INVALID_CHANNELS"] = "Entry defaultChannels must contain boolean channel values.",
    ["ENTRY.CHANNEL_MINIMAP"] = "Minimap",
    ["ENTRY.CHANNEL_BROKER"] = "External Broker",
    ["ENTRY.CHANNEL_BUILTINBAR"] = "Built-in bar",
    ["ENTRY.CHANNELS"] = "Entry channels",
    ["ENTRY.HOVER_OPTIONS"] = "Hover options",
    ["ENTRY.HOVER_MAIN"] = "Show hover previews while the main window is open",
    ["ENTRY.BAR_TITLE"] = "Built-in entry bar",
    ["ENTRY.BAR_ENABLED"] = "Enable built-in entry bar",
    ["ENTRY.BAR_COUNT"] = "Selected available entries: %d",
    ["ENTRY.BAR_DISABLED_HINT"] = "Enable the built-in bar to adjust its controls. Saved selections are retained.",
    ["ENTRY.BAR_EMPTY"] = "Select bar buttons in Display & entries.",
    ["ENTRY.BAR_LOCKED"] = "Lock position",
    ["ENTRY.BAR_NAMES"] = "Show entry names",
    ["ENTRY.BAR_RESET"] = "Reset bar position",
    ["ENTRY.BAR_SIZE"] = "Icon size",
    ["ENTRY.BAR_SPACING"] = "Icon spacing",
    ["ENTRY.BROKER_LIMIT"] = "Hide external icons in their display addon.",
})

Core.Locale:Register("YiboCore", "en", {
    ["ENTRY.TAB_GENERAL"] = "General",
    ["ENTRY.TAB_ENTRIES"] = "Pages & entries",
    ["ENTRY.TAB_BAR"] = "Entry bar",
    ["ENTRY.BAR_STATUS"] = "%d available buttons selected. Choose Built-in bar in Display & entries.",
    ["ENTRY.BAR_APPEARANCE"] = "Appearance & position",
    ["ENTRY.BAR_BORDER"] = "Show border",
    ["ENTRY.BAR_BACKGROUND"] = "Background",
    ["ENTRY.BAR_OPACITY"] = "Background opacity",
    ["ENTRY.COLOR_THEME"] = "Theme teal",
    ["ENTRY.COLOR_BLACK"] = "Black",
    ["ENTRY.COLOR_CHARCOAL"] = "Charcoal",
    ["ENTRY.COLOR_NAVY"] = "Navy",
    ["ENTRY.COLOR_FOREST"] = "Forest",
    ["ENTRY.BAR_ORDER"] = "Button order",
    ["ENTRY.ORDER_BUTTON"] = "Select button",
    ["ENTRY.ORDER_PREVIOUS"] = "Move earlier",
    ["ENTRY.ORDER_NEXT"] = "Move later",
    ["ENTRY.ORDER_RESET"] = "Reset button order",
    ["ENTRY.BAR_ORDER_HINT"] = "Drag bar icons to reorder.",
    ["ENTRY.ENTRIES_HINT"] = "Choose each entry channel independently. Enable and style the built-in bar in Entry bar.",
    ["ENTRY.PAGE_NUMBER"] = "Page %d of %d",
    ["ENTRY.PLUGIN_PAGES"] = "Addon list",
})

Core.Locale:Register("YiboCore", "en", {
    ["ENTRY.GENERAL_HINT"] = "Manage addon language and shared hover behavior.",
    ["ENTRY.PAGE_STATUS"] = "Page %d / %d · %d addons",
    ["ENTRY.PAGE_PREVIOUS"] = "Previous",
    ["ENTRY.PAGE_NEXT"] = "Next",
})

Core.Locale:Register("YiboCore", "en", {
    ["ENTRY.SETTINGS_ONLY"] = "Settings only",
    ["ENTRY.NO_SEPARATE_ENTRY"] = "No separate entry",
})

Core.Locale:Register("YiboCore", "en", {
    ["ENTRY.BAR_PAGE_HINT"] = "Manage the built-in bar appearance, position and button order.",
})

Core.Locale:Register("YiboCore", "en", {
    ["ENTRY.HEADER_PAGE"] = "Page",
    ["ENTRY.HEADER_SHOW"] = "Show",
    ["ENTRY.HEADER_BROKER"] = "Broker",
    ["ENTRY.HEADER_BAR"] = "Bar",
    ["ENTRY.HEADER_LAYOUT"] = "Layout",
    ["ENTRY.ADDON_COUNT"] = "%d business addons registered",
})
]=====]
baseline["YiboCore/Locales/zhCN.lua"] = [=====[-- Core-owned resources. Keys are stable and independent of display text.
local Core = _G.YiboCore
Core.Locale:Register("YiboCore", "zh", {
    ["ARCHIVE.FIELD_CONFLICT"] = "档案字段 ID 冲突，已隔离重复提供者：%s",
    ["CORE.REPUTATION_CHARACTER_SNAPSHOTS"] = "声望角色快照",
    ["CORE.CFF20E070_YIBO_R_CORE"] = "|cff20e070[Yibo]|r 核心：",
    ["CORE.BEAST_PATHS"] = "隐兽寻踪",
    ["CORE.BOSS_TRACKER"] = "首领追踪",
    ["CORE.TRACK_WORLD_BOSSES_HOLIDAY_BOSSES_AND_CUSTOM"] = "跨角色追踪世界首领、节日首领与自定义目标；副本 CD 监控即将加入。",
    ["CORE.CHARACTER_BUILDS"] = "角色构筑",
    ["CORE.VIEW_EQUIPMENT_TALENTS_AND_GLYPH_BUILDS_ACROSS"] = "跨角色查看装备、天赋与雕文构筑。",
    ["CORE.CURRENCY_MANAGER"] = "货币管家",
    ["CORE.TRACK_CURRENCIES_ACROSS_CHARACTERS"] = "跨角色货币追踪。",
    ["CORE.CRAFTING"] = "专业制造",
    ["CORE.VIEW_CONFIRMED_LEARNED_PROFESSION_RECIPES_ACROSS_CHARACTERS"] = "跨角色查看已确认学习的专业配方。",
    ["CORE.LEGENDARY_PATHS"] = "传说之路",
    ["CORE.TRACK_LEGENDARY_ITEM_COLLECTION_PROGRESS"] = "传说物品收集进度。",
    ["CORE.QUEST_BLOCKER"] = "任务阻断",
    ["CORE.QUEST_PREREQUISITES_AND_BLOCKING_CONDITIONS"] = "任务前置条件与阻断原因。",
    ["CORE.ACCOUNT_TO_DO"] = "账号待办",
    ["CORE.ACCOUNT_TASKS"] = "账号待办事项。",
    ["CORE.ITEM_OVERVIEW"] = "物品总览",
    ["CORE.FIND_ITEMS_IN_BAGS_EQUIPMENT_AND_OTHER"] = "跨角色查询背包、装备与后续已验证的库存来源。",
    ["CORE.MAIL_ASSISTANT"] = "邮件助手",
    ["CORE.MAIL_SNAPSHOTS_BACKLOG_CACHES_AND_ATTACHMENT_SOURCES"] = "跨角色邮件快照、积压缓存与附件来源。",
    ["CORE.REPUTATION_PATHS"] = "声望之路",
    ["CORE.REPUTATION_PROGRESS_ACROSS_CHARACTERS"] = "跨角色声望进度。",
    ["CORE.AUTO_OPEN"] = "自动开包",
    ["CORE.SAFELY_OPEN_CONTAINER_ITEMS_FROM_THE_ACCOUNT"] = "安全地自动开启账号目录中的容器物品。",
    ["CORE.HIDDEN_HUNTER_PET_ROUTES_IN_PANDARIA"] = "潘达利亚隐藏猎人宠物路线图。",
    ["CORE.MOUNT_JOURNAL"] = "坐骑图鉴",
    ["CORE.SHOW_MOUNT_SOURCES_IN_AURAS_CHAT_LINKS"] = "在光环、聊天链接与坐骑面板提示中显示坐骑获取来源。",
    ["CORE.BOSS_TRACKER_CHARACTER_RECORDS"] = "首领追踪角色记录",
    ["CORE.LEGENDARY_PATHS_CHARACTER_PROGRESS"] = "传说之路角色进度",
    ["CORE.QUEST_BLOCKER_PERSONAL_SETTINGS"] = "任务屏蔽个人设置",
    ["CORE.ACCOUNT_INVENTORY_SNAPSHOTS"] = "账号物品库存快照",
    ["CORE.MAIL_SNAPSHOTS_AND_BACKLOG_CACHE"] = "邮件快照与积压缓存",
    ["CORE.DATA_OWNER_DOES_NOT_PROVIDE"] = "数据所有者未提供 ",
    ["CORE.DATA_OWNER_IS_CURRENTLY_UNAVAILABLE"] = "数据所有者当前不可用。",
    ["CORE.FAILED_TO_DELETE_CHARACTER_CACHE"] = "角色缓存删除失败。",
    ["CORE.INVALID_CHARACTER_DATA_OWNER_REGISTRATION"] = "角色数据所有者注册参数无效。",
    ["CORE.CHARACTER_DATA_OWNER_S_ADDON_IS_NOT"] = "角色数据所有者所属插件尚未注册: ",
    ["CORE.CHARACTER_DATA_OWNERS_MUST_PROVIDE_INSPECT_AND"] = "角色数据所有者必须提供 Inspect 与 Delete。",
    ["CORE.CHARACTER_DATA_OWNER_ALREADY_REGISTERED"] = "角色数据所有者已注册: ",
    ["CORE.CHARACTER_CACHE_DOES_NOT_EXIST"] = "角色缓存不存在。",
    ["CORE.CANNOT_READ_CACHE_SUMMARY"] = "无法读取缓存摘要。",
    ["CORE.ADDON_NOT_LOADED_CLEAN_UP_WHEN_IT"] = "插件当前未加载；以后加载时清理",
    ["CORE.CANNOT_READ_CHARACTER_CACHE"] = "无法读取角色缓存。",
    ["CORE.ADDON_IS_NOT_LOADED"] = "插件当前未加载。",
    ["CORE.SHORT_NAME_MUST_BE_TEXT"] = "短名必须是文本。",
    ["CORE.SHORT_NAME_CANNOT_CONTAIN_CONTROL_CHARACTERS"] = "短名不能包含控制字符。",
    ["CORE.NO_CHARACTER_SELECTED"] = "未选择角色。",
    ["CORE.CANNOT_DELETE_THE_LOGGED_IN_CHARACTER_SWITCH"] = "当前登录角色不能删除，请切换到其它角色后再删除。",
    ["CORE.NO_VALID_CHARACTER_DATA"] = "无有效的角色数据。",
    ["CORE.THIS_CHARACTER_CACHE_WAS_DELETED_BY_THE"] = "该角色缓存已由用户删除，拒绝重新导入。",
    ["CORE.DATABASE_NOT_LOADED"] = "数据库未加载: ",
    ["CORE.CHARACTER_NOT_FOUND"] = "角色不存在: ",
    ["CORE.INVALID_DOMAIN_STATE"] = "非法领域状态: ",
    ["CORE.UNREGISTERED_DOMAIN"] = "未注册领域: ",
    ["CORE.YIBOCORE_DATA_IS_NEWER_THAN_THIS_ADDON"] = "YiboCore 数据版本高于当前插件版本。",
    ["CORE.MISSING_DATABASE_MIGRATION_STEP_V"] = "缺少数据库迁移步骤 v",
    ["CORE.CHARACTER_PROFILE_COLLECTORS_REQUIRE_A_NAME_AND"] = "角色档案采集器必须提供名称和回调。",
    ["CORE.CHARACTER_PROFILE_COLLECTOR_ALREADY_EXISTS"] = "角色档案采集器已存在: ",
    ["CORE.CHARACTER_PROFILE_COLLECTOR"] = "角色档案采集器 “",
    ["CORE.FAILED"] = "” 失败：",
    ["CORE.COMMAND_YCO_SETTINGS"] = "命令: /yco [settings]",
    ["CORE.CURRENCY_CATALOGS_MUST_DECLARE_OWNER"] = "货币目录必须声明 owner。",
    ["CORE.CURRENCY_CATALOG_ENTRIES_REQUIRE_A_STABLE_ID"] = "货币目录条目必须提供稳定 id。",
    ["CORE.IS_ALREADY_REGISTERED_BY"] = " 已被 ",
    ["CORE.PUNCTUATION"] = " 注册: ",
    ["CORE.STANDARD_CURRENCIES_REQUIRE_CURRENCYID"] = "标准货币必须提供 currencyID。",
    ["CORE.STANDARD_CURRENCY"] = "标准货币",
    ["CORE.ITEM_CURRENCIES_REQUIRE_ITEMID"] = "物品代币必须提供 itemID。",
    ["CORE.ITEM_CURRENCY"] = "物品代币",
    ["CORE.ITEM_CURRENCY_IS_NOT_IN_THE_CORE"] = "物品代币不在 Core 目录中。",
    ["CORE.ONLY_THE_REGISTERING_ADDON_CAN_REMOVE_THIS"] = "只有注册插件可以移除该物品代币。",
    ["CORE.DOMAIN_EVENTS_MUST_BE_A_SET_OF"] = "领域 events 必须是事件名集合。",
    ["CORE.DOMAIN_EVENTS_MAY_ONLY_CONTAIN_ENABLED_EVENT"] = "领域 events 只能包含启用的事件名。",
    ["CORE.DOMAINS_MUST_DECLARE_OWNER"] = "领域必须声明 owner。",
    ["CORE.DOMAIN_DEFINITION_CANNOT_BE_EMPTY"] = "领域定义不能为空。",
    ["CORE.DOMAINS_REQUIRE_ID"] = "领域必须提供 id。",
    ["CORE.DOMAIN_VERSION_MUST_BE_A_POSITIVE_INTEGER"] = "领域 version 必须为正整数。",
    ["CORE.DOMAINS_REQUIRE_A_COLLECT_CALLBACK"] = "领域必须提供 Collect 回调。",
    ["CORE.DOMAIN_ID_IS_ALREADY_OWNED_BY"] = "领域 ID 已被 ",
    ["CORE.PUNCTUATION_79"] = " 占用: ",
    ["CORE.DOMAIN"] = "领域 “",
    ["CORE.RETURNED_AN_INVALID_STATE"] = "” 返回了非法状态: ",
    ["CORE.COLLECTION_FAILED"] = "” 采集失败: ",
    ["CORE.EVENT_CALLBACK_FAILED"] = "事件回调失败：",
    ["CORE.FIELDS_MUST_DECLARE_OWNER"] = "字段必须声明 owner。",
    ["CORE.FIELD_DEFINITION_CANNOT_BE_EMPTY"] = "字段定义不能为空。",
    ["CORE.FIELDS_REQUIRE_ID"] = "字段必须提供 id。",
    ["CORE.FIELDS_REQUIRE_CONSUMER"] = "字段必须提供 consumer。",
    ["CORE.FIELDS_MUST_REFERENCE_A_REGISTERED_DOMAIN"] = "字段必须引用已注册领域。",
    ["CORE.FIELDS_MUST_REFERENCE_A_REGISTERED_RESOURCE"] = "字段必须引用已注册资源。",
    ["CORE.FIELDS_REQUIRE_A_READ_CALLBACK"] = "字段必须提供 Read 回调。",
    ["CORE.FIELD_ID_IS_ALREADY_OWNED_BY"] = "字段 ID 已被 ",
    ["CORE.FIELDS_REQUIRE_A_NUMERIC_ORDER"] = "字段必须提供数值 order。",
    ["CORE.ENTER_AN_ITEM_ID_LINK_OR_NAME"] = "请输入物品 ID、链接或名称。",
    ["CORE.ENTER_A_POSITIVE_ITEM_ID_OR_A"] = "请输入正整数物品 ID 或有效物品链接。",
    ["CORE.NO_MATCHING_ITEM_IN_BAGS_OR_KNOWN"] = "背包和已知目录中没有匹配物品；请使用物品 ID 或链接。",
    ["CORE.ITEM_INFORMATION_COULD_NOT_LOAD_CHECK_THE"] = "物品信息加载失败；请检查 ID 后点击重试。",
    ["CORE.ITEM_INFORMATION_CALLBACK_FAILED"] = "物品信息回调失败：",
    ["CORE.INVALID_ITEM_ID"] = "无效物品 ID。",
    ["CORE.ADDON_NAME_CANNOT_BE_EMPTY"] = "插件名称不能为空。",
    ["CORE.REQUIRES_API"] = "需要 API ",
    ["CORE.AVAILABLE_VERSION_IS"] = "，当前版本为 ",
    ["CORE.RESOURCE_TYPE_AND_IDENTIFIER_CANNOT_BE_EMPTY"] = "资源类型和标识符不能为空。",
    ["CORE.IDENTIFIER_IS_RESERVED_BY_CORE"] = "标识符为 Core 保留名称: ",
    ["CORE.RESOURCES_MUST_DECLARE_THEIR_ADDON_OWNER"] = "资源必须声明所属插件。",
    ["CORE.S_ID_IS_ALREADY_OWNED_BY_ADDON"] = "%s ID 已被插件 %s 占用: %s",
    ["CORE.RESOURCE_DOES_NOT_BELONG_TO_THIS_ADDON"] = "资源不属于此插件。",
    ["CORE.RESOURCES_MUST_DECLARE_OWNER"] = "资源必须声明 owner。",
    ["CORE.RESOURCE_DEFINITION_CANNOT_BE_EMPTY"] = "资源定义不能为空。",
    ["CORE.RESOURCES_REQUIRE_ID"] = "资源必须提供 id。",
    ["CORE.RESOURCES_MUST_REFERENCE_A_REGISTERED_DOMAIN"] = "资源必须引用已注册领域。",
    ["CORE.RESOURCES_REQUIRE_A_READ_CALLBACK"] = "资源必须提供 Read 回调。",
    ["CORE.RESOURCE_ID_IS_ALREADY_OWNED_BY"] = "资源 ID 已被 ",
    ["CORE.SETTINGS_PANEL_S_ADDON_IS_NOT_REGISTERED"] = "设置面板所属插件尚未注册。",
    ["CORE.SETTINGS_PANELS_REQUIRE_ID"] = "设置面板必须提供 id。",
    ["CORE.SETTINGS_PANELS_REQUIRE_TITLE"] = "设置面板必须提供 title。",
    ["CORE.SETTINGS_PANELS_REQUIRE_CREATESETTINGSPANEL"] = "设置面板必须提供 CreateSettingsPanel。",
    ["CORE.SETTINGS_PANEL_DESCRIPTION_MUST_BE_A_STRING"] = "设置面板 description 必须是 string。",
    ["CORE.SETTINGS_PANEL_ICON_MUST_BE_A_STRING"] = "设置面板 icon 必须是 string。",
    ["CORE.SETTINGS_PANEL_ID_IS_ALREADY_OWNED_BY"] = "设置面板 ID 已被插件 ",
    ["CORE.PUNCTUATION_120"] = " 占用。",
    ["CORE.SETTINGS_PANEL_DOES_NOT_BELONG_TO_THIS"] = "设置面板不属于此插件。",
    ["CORE.RECENT_LOGIN"] = "最近登录",
    ["CORE.CHARACTER_NAME"] = "角色名称",
    ["CORE.CHARACTER_LEVEL"] = "角色等级",
    ["CORE.CUSTOM"] = "自定义",
    ["CORE.CHARACTER"] = "角色",
    ["CORE.ACCOUNT_PAGE"] = "账号视图页面 “",
    ["CORE.SIZE_MEASUREMENT_FAILED_USING_COMPATIBLE_DIMENSIONS"] = "”尺寸测量失败，使用兼容尺寸。",
    ["CORE.INVALID_PAGE_REGISTRATION"] = "页面注册参数无效。",
    ["CORE.PAGES_REQUIRE_ID_AND_TITLE"] = "页面必须提供 id 和 title。",
    ["CORE.PAGES_REQUIRE_CREATE_AND_REFRESH"] = "页面必须提供 Create 与 Refresh。",
    ["CORE.PAGE_GETELIGIBLECHARACTERS_MUST_BE_A_FUNCTION"] = "页面 GetEligibleCharacters 必须是 function。",
    ["CORE.PAGE_CHARACTERFILTER_REQUIRES_GETEXPRESSION_AND_SETEXPRESSION"] = "页面 characterFilter 必须提供 GetExpression 与 SetExpression。",
    ["CORE.PAGE_GETSURFACEMETRICS_MUST_BE_A_FUNCTION"] = "页面 GetSurfaceMetrics 必须是 function。",
    ["CORE.PAGE_GETLAYOUTMETRICS_MUST_BE_A_FUNCTION"] = "页面 GetLayoutMetrics 必须是 function。",
    ["CORE.PAGE_GETMEASUREDHEIGHT_MUST_BE_A_FUNCTION"] = "页面 GetMeasuredHeight 必须是 function。",
    ["CORE.PAGE_VIEWMODES_REQUIRES_AT_LEAST_TWO_OPTIONS"] = "页面 viewModes 至少需要两个选项。",
    ["CORE.PAGE_VIEWMODES_REQUIRES_ID_AND_TITLE"] = "页面 viewModes 必须提供 id 与 title。",
    ["CORE.DUPLICATE_PAGE_VIEWMODE_ID"] = "页面 viewMode ID 重复: ",
    ["CORE.PAGE_GETHOVERMETRICS_MUST_BE_A_FUNCTION"] = "页面 GetHoverMetrics 必须是 function。",
    ["CORE.PAGE_HASCHARACTERSNAPSHOT_MUST_BE_A_FUNCTION"] = "页面 HasCharacterSnapshot 必须是 function。",
    ["CORE.PAGE_SCOPE_REQUIRES_DEFAULT_AND_VALUES"] = "页面 scope 必须提供 default 与 values。",
    ["CORE.PAGE_SCOPE_VALUES_REQUIRES_ID_AND_TITLE"] = "页面 scope.values 必须提供 id 与 title。",
    ["CORE.DUPLICATE_PAGE_SCOPE_ID"] = "页面 scope ID 重复: ",
    ["CORE.PAGE_SCOPE_DEFAULT_MUST_EXIST_IN_SCOPE"] = "页面 scope.default 必须存在于 scope.values。",
    ["CORE.PAGE_S_ADDON_HAS_NOT_REGISTERED_THROUGH"] = "页面所属插件尚未通过 Core:RegisterAddon 注册: ",
    ["CORE.PAGE_SETTINGS_MUST_BE_A_TABLE"] = "页面 settings 必须是 table。",
    ["CORE.PAGE_SETTINGS_TITLE_MUST_BE_A_STRING"] = "页面 settings.title 必须是 string。",
    ["CORE.PAGE_SETTINGS_DESCRIPTION_MUST_BE_A_STRING"] = "页面 settings.description 必须是 string。",
    ["CORE.PAGE_FIELDS_REQUIRE_ID"] = "页面字段必须提供 id。",
    ["CORE.DUPLICATE_PAGE_FIELD_ID"] = "页面字段 ID 重复: ",
    ["CORE.PAGE_ID_IS_ALREADY_IN_USE"] = "页面 ID 已被占用: ",
    ["CORE.INVALID_LEVEL_RULE"] = "无效等级规则：",
    ["CORE.FAILED_154"] = " 失败：",
    ["CORE.THIS_PAGE_IS_TEMPORARILY_UNAVAILABLE_N"] = "此页面暂时无法显示。\n",
    ["CORE.CREATE"] = "创建",
    ["CORE.SORT"] = "排序：",
    ["CORE.USES_SHARED_SETTINGS"] = "跟随通用设置。",
    ["CORE.USES_PAGE_SPECIFIC_SETTINGS"] = "此页面独立设置。",
    ["CORE.LEFT_CLICK_TO_CHANGE_SORT_SHIFT_CLICK"] = " 左键切换排序；Shift+左键切换方向。",
    ["CORE.ACCOUNT_PAGE_161"] = "账号视图页面“",
    ["CORE.COULD_NOT_READ_CHARACTER_SNAPSHOTS"] = "”读取角色快照失败：",
    ["CORE.ALL_REALMS"] = "所有服务器",
    ["CORE.OTHER_V"] = "其它 v",
    ["CORE.ACCOUNT_OVERVIEW"] = "账号总览",
    ["CORE.CHARACTER_STATUS"] = "多角色状态",
    ["CORE.SORT_RECENT_LOGIN"] = "排序：最近登录 ↓",
    ["CORE.CHARACTER_SORTING"] = "角色排序",
    ["CORE.SETTINGS"] = "设置",
    ["CORE.BACK"] = "‹ 返回",
    ["CORE.CORE_SETTINGS"] = "Core 常规设置",
    ["CORE.WINDOW"] = "窗口",
    ["CORE.CHARACTERS_SORTING"] = "角色与排序",
    ["CORE.DISPLAY_ENTRIES"] = "显示与入口",
    ["CORE.CHARACTER_ELIGIBILITY_FAILED"] = "）角色准入失败：",
    ["CORE.CHARACTER_ELIGIBILITY_MUST_RETURN_A_TABLE"] = "）角色准入必须返回 table。",
    ["CORE.REFRESH"] = "刷新",
    ["CORE.CONTROLS"] = "操作提示",
    ["CORE.ACCOUNT_OVERVIEW_CHARACTER_STATUS"] = "账号总览 · 多角色状态",
    ["CORE.HOVER_MEASUREMENT_FAILED_USING_COMPATIBLE_DIMENSIONS"] = "”悬停尺寸测量失败，使用兼容尺寸。",
    ["CORE.CANNOT_OPEN_SETTINGS_IN_COMBAT_TRY_AGAIN"] = "战斗中不能打开设置。脱离战斗后再试。",
    ["CORE.LEFT_CLICK"] = "左键",
    ["CORE.RIGHT_CLICK"] = "右键",
    ["CORE.MIDDLE_CLICK"] = "中键",
    ["CORE.MOUSE_4"] = "鼠标4",
    ["CORE.MOUSE_5"] = "鼠标5",
    ["CORE.LEAVE_COMBAT_BEFORE_CHANGING_HOW_TARGETS_ARE"] = "请脱离战斗后修改添加方式。",
    ["CORE.TOP_RIGHT_BUTTON"] = "右上角按钮",
    ["CORE.CTRL_CLICK"] = "Ctrl+左键",
    ["CORE.CHOOSE_A_VALID_MOUSE_BUTTON"] = "请选择有效鼠标按键",
    ["CORE.THIS_BINDING_CONFLICTS_WITH_A_BUSINESS_ACTION"] = "此按键与业务操作冲突，请选择其它组合（安全施法按键不可复用）。",
    ["CORE.ITEM_IS_NO_LONGER_AVAILABLE"] = "项目已失效",
    ["CORE.THIS_ITEM_HAS_NO_TARGET_TO_ADD"] = "该项目没有可添加目标",
    ["CORE.ACTION_CENTER_IS_NOT_READY_ENABLE_A"] = "行动中心未就绪，请启用兼容版本。",
    ["CORE.REMOVING_TARGETS_REQUIRES_A_NEWER_ACTION_CENTER"] = "取消目标需要新版行动中心，请升级。",
    ["CORE.REMOVAL_FAILED"] = "取消失败",
    ["CORE.TARGET_REMOVED_FROM_ACTION_CENTER"] = "已从行动中心移除目标。",
    ["CORE.ADD_FAILED"] = "添加失败",
    ["CORE.THIS_ITEM_REQUIRES_TARGET_DETAILS_CLICK_ITS"] = "此项目需要补充目标参数，请点击项目的＋打开配置。",
    ["CORE.THIS_TARGET_IS_ALREADY_IN_ACTION_CENTER"] = "此目标已加入行动中心。",
    ["CORE.ADDED_LOCATING_TARGET"] = "已添加，正在定位目标。",
    ["CORE.ADDED_TO_ACTION_CENTER"] = "已添加到行动中心。",
    ["CORE.THIS_ADD_GESTURE_CONFLICTS_WITH_THE_ITEM"] = "添加方式与此项目操作冲突，请在 Core 窗口设置选择其它方式。",
    ["CORE.TOP_RIGHT_ADD_CONFIGURE_CHECK_MARK_LOCATE"] = "右上角＋：添加／配置；勾选：定位目标",
    ["CORE.COMPACT_TARGET_TOGGLE"] = "%s：添加／取消目标",
    ["CORE.COMPACT_TARGET_MENU"] = "右上角：添加／查看目标",
    ["CORE.ADD_REMOVE_WHILE_KEEPING_THE_WINDOW_OPEN"] = "：添加／取消并保持窗口；缺参数时点临时＋补充",
    ["CORE.TARGETS_ADDED"] = "已加入目标 · ",
    ["CORE.ACTIVE"] = " 项（进行中 ",
    ["CORE.PAUSED"] = " / 暂停 ",
    ["CORE.COMPLETE"] = " / 已完成 ",
    ["CORE.ADD_TO_ACTION_CENTER"] = "添加到行动中心",
    ["CORE.CLICK_TO_ADD_OR_ENTER_DETAILS_OPEN"] = "点击添加或补充参数；已添加时打开目标。添加手势保持当前窗口。",
    ["CORE.HIDDEN"] = "不显示",
    ["CORE.BROKER_ONLY"] = "仅 Broker",
    ["CORE.MINIMAP_ONLY"] = "仅小地图",
    ["CORE.BOTH"] = "两者都显示",
    ["CORE.BROKER_NAME_CONFLICT_DATA_SOURCE_LEFT_UNCHANGED"] = "Broker 名称冲突，未接管数据源: ",
    ["CORE.YIBO_ACCOUNT_OVERVIEW"] = "[Yibo] 账号总览",
    ["CORE.BUSINESS_ENTRIES_REQUIRE_ADDON_NAME_ID_AND"] = "业务入口必须提供插件名、id 与 pageID。",
    ["CORE.ENTRY_S_ADDON_IS_NOT_REGISTERED"] = "入口所属插件尚未注册: ",
    ["CORE.BUSINESS_ENTRY_BROKERNAME_MUST_BE_A_NON"] = "业务入口 brokerName 必须是非空 string。",
    ["CORE.BUSINESS_ENTRY_RESOLVEPAGEID_MUST_BE_A_FUNCTION"] = "业务入口 resolvePageID 必须是 function。",
    ["CORE.INVALID_BUSINESS_ENTRY_DEFAULTMODE"] = "业务入口 defaultMode 无效。",
    ["CORE.ENTRY_TARGET_PAGE_DOES_NOT_EXIST"] = "入口目标页面不存在: ",
    ["CORE.ENTRIES_MAY_ONLY_BIND_TO_PAGES_OWNED"] = "入口只能绑定所属插件自己的页面。",
    ["CORE.LEFT_CLICK_TO_OPEN_CHARACTER_STATUS"] = "左键打开多角色状态视图",
    ["CORE.CHOOSE_GAME_ICON"] = "选择游戏图标",
    ["CORE.AUTOMATIC_ICON"] = "自动图标",
    ["CORE.CONFIRM"] = "确认",
    ["CORE.CANCEL"] = "取消",
    ["CORE.PREVIOUS"] = "上一页",
    ["CORE.NEXT"] = "下一页",
    ["CORE.CLIENT_ICON_LIST_IS_UNAVAILABLE_USE_AN"] = "客户端图标列表暂不可用，可使用自动图标。",
    ["CORE.ICON_SELECTED_CONFIRM_TO_SAVE"] = "已选择图标，确认后保存。",
    ["CORE.AUTOMATIC_ICON_USE_THE_RECIPIENT_S_CLASS"] = "自动图标：跟随收件人职业，未知职业使用通用图标。",
    ["CORE.ICONS"] = " 个",
    ["CORE.ITEM"] = "物品",
    ["CORE.CHOOSE_MATCH"] = "选择候选 · ",
    ["CORE.NO_MATCHES"] = "暂无候选",
    ["CORE.OPERATION_SUCCEEDED"] = "操作成功。",
    ["CORE.OPERATION_FAILED"] = "操作失败。",
    ["CORE.THIS_OPERATION_IS_DISABLED"] = "该操作未启用。",
    ["CORE.CANCELLED_INPUT_PRESERVED"] = "已取消；输入已保留。",
    ["CORE.CANNOT_OPEN_CONFIRMATION_PLEASE_RETRY"] = "无法打开确认框，请重试。",
    ["CORE.FILL_IN_EVERY_ITEM_DO_NOT_LEAVE"] = "请填写每一个物品；分隔符之间不能留空。",
    ["CORE.ITEM_245"] = "第 ",
    ["CORE.PUNCTUATION_246"] = " 项：",
    ["CORE.HAS_MULTIPLE_MATCHES_USE_AN_ITEM_ID"] = " 项有多个候选，请使用物品 ID 或链接。",
    ["CORE.LOADING"] = "正在加载 ",
    ["CORE.ITEMS"] = " 个物品…",
    ["CORE.MULTIPLE_ITEMS_FOUND_SELECT_A_MATCH_BEFORE"] = "找到多个物品，请明确选择候选后再操作。",
    ["CORE.LOADING_ITEM_INFORMATION"] = "正在加载物品信息…",
    ["CORE.ITEM_ID_LINK_OR_NAME"] = "物品 ID、链接或名称",
    ["CORE.CLICK_THE_ACTION_BUTTON_AGAIN_TO_SUBMIT"] = "；再次点击操作按钮提交。",
    ["CORE.ADD_ITEM"] = "添加物品",
    ["CORE.DROP_ITEM_HERE"] = "拖放物品到这里",
    ["CORE.RETRY_LOAD"] = "重试加载",
    ["CORE.THIS_OPERATION_IS_CURRENTLY_UNAVAILABLE"] = "当前无法执行该操作。",
    ["CORE.DELETE_CUSTOM_ITEM"] = "删除自定义物品",
    ["CORE.DRAG_AN_ITEM_HERE_FROM_YOUR_BAGS"] = "请从背包拖动物品到这里。",
    ["CORE.INVALID_ITEM_DROP"] = "无效物品拖放。",
    ["CORE.UNKNOWN"] = "未知",
    ["CORE.NOT_SYNCED"] = "未同步",
    ["CORE.UNAVAILABLE"] = "不可用",
    ["CORE.EXPIRED"] = "已过期",
    ["CORE.ERROR"] = "错误",
    ["CORE.UNKNOWN_CHARACTER"] = "未知角色",
    ["CORE.UNKNOWN_REALM"] = "未知服务器",
    ["CORE.SHORT_NAME"] = "短名",
    ["CORE.LAST_SYNCED"] = "最近同步",
    ["CORE.DATA_STATUS"] = "数据状态",
    ["CORE.LOG_IN_TO_THIS_CHARACTER_TO_SYNC"] = "登录该角色后同步。",
    ["CORE.FIELD"] = "字段",
    ["CORE.GENERAL"] = "常规",
    ["CORE.COMPARE_CURRENCY_BALANCES_ACROSS_CHARACTERS_INCLUDING_STANDARD"] = "汇总多角色货币余额，统一查看常规货币与物品代币。",
    ["CORE.TRACK_LEGENDARY_QUESTS_AND_EQUIPMENT_ACROSS_CHARACTERS"] = "追踪多角色传说任务与橙色传说装备进度。",
    ["CORE.IDENTIFY_QUEST_RESTRICTIONS_AND_RISKS_TO_AVOID"] = "识别任务限制与风险，避免误接关键任务。",
    ["CORE.REVIEW_TASKS_AND_PROFESSION_COOLDOWNS_ACROSS_CHARACTERS"] = "汇总多角色待办与专业冷却，明确下一项可做事务。",
    ["CORE.FIND_ITEMS_IN_BAGS_EQUIPMENT_BANKS_MAIL"] = "跨角色查询背包、装备、银行、邮件与公会银行物品。",
    ["CORE.COMPARE_REPUTATION_STANDINGS_AND_ADVANCEMENT_ACROSS_CHARACTERS"] = "汇总多角色声望，掌握阵营关系与晋升进度。",
    ["CORE.SHOW_RARE_HUNTER_PET_PATROL_ROUTES_ON"] = "在地图上显示稀有猎人宠物的巡逻路线。",
    ["CORE.HIDE_LINK"] = "收起链接",
    ["CORE.GET_LINK"] = "获取链接",
    ["CORE.OPTIONAL_INTEGRATION"] = "可选接入",
    ["CORE.STANDALONE_ADDON"] = "独立作品",
    ["CORE.PRESS_CTRL_C_TO_COPY"] = "按 Ctrl+C 复制",
    ["CORE.MANAGE_YIBO_ACCOUNT_CHARACTERS_ENTRIES_AND_BUSINESS"] = "统一管理 Yibo 系列的账号角色、入口与业务页面",
    ["CORE.CORE_DEPENDENT_ADDONS"] = "强依赖子插件",
    ["CORE.OPTIONAL_INTEGRATIONS"] = "可选接入插件",
    ["CORE.EXPLORE_OTHER_YIBO_ADDONS"] = "探索其它 Yibo 插件",
    ["CORE.AUTHOR_YIBOSOFT_CURSEFORGE"] = "作者 YiboSoft · CurseForge",
    ["CORE.CONNECTED"] = "已连接",
    ["CORE.ENABLED_NOT_CONNECTED"] = "已启用尚未连接",
    ["CORE.INSTALLED_DISABLED"] = "已安装但未启用",
    ["CORE.NOT_INSTALLED"] = "未安装",
    ["CORE.INSTALLED"] = "本机 ",
    ["CORE.NOT_INSTALLED_LOCALLY"] = "本机未安装",
    ["CORE.PACKAGED"] = " · 打包时 ",
    ["CORE.UNKNOWN_STATUS"] = "状态未知",
    ["CORE.CONNECTED_302"] = "已连接 ",
    ["CORE.ADDONS"] = " 个接入插件",
    ["CORE.DATABASE_SCHEMA_V"] = " · 数据库 Schema v",
    ["CORE.ABOUT"] = "关于",
    ["CORE.LEVEL"] = "等级",
    ["CORE.LOCATION"] = "地点",
    ["CORE.ITEM_LEVEL"] = "装等",
    ["CORE.PROFESSIONS"] = "专业",
    ["CORE.DELETE_CACHE"] = "删除缓存",
    ["CORE.CHARACTER_CACHE_DELETION_FAILED"] = "角色缓存删除失败：",
    ["CORE.CHARACTER_CACHE_REMOVED_FROM_THE_ACCOUNT_VIEW"] = "角色缓存已从账号视图移除；",
    ["CORE.ADDON_CACHES_WILL_RETRY_CLEANUP_WHEN_NEXT"] = " 个插件缓存等待下次加载重试。",
    ["CORE.CHARACTER_CACHE_DELETED"] = "角色缓存已删除。",
    ["CORE.DELETE_ADDON_CACHES_FOR"] = "确定删除“",
    ["CORE.PUNCTUATION_316"] = "”的插件缓存吗？",
    ["CORE.WILL_DELETE"] = "将删除：",
    ["CORE.CORE_CHARACTER_PROFILE"] = "• Core 角色档案",
    ["CORE.CACHED"] = "有缓存",
    ["CORE.NO_CACHE"] = "无缓存",
    ["CORE.ACCOUNT_WIDE_SETTINGS_AND_THE_GAME_CHARACTER"] = "不会删除账号共享设置，也不会删除游戏角色。",
    ["CORE.DELETION_CANNOT_BE_UNDONE"] = "删除后不可撤销。",
    ["CORE.DEL"] = "删",
    ["CORE.DELETE_CHARACTER_CACHE"] = "删除角色缓存",
    ["CORE.DELETE_THIS_CHARACTER_S_CORE_AND_BUSINESS"] = "删除此角色在 Core 与业务插件中的缓存；不会删除游戏角色。",
    ["CORE.CHARACTER_ARCHIVE"] = "角色档案",
    ["CORE.YIBOCORE_ACCOUNT_OVERVIEW"] = "YiboCore · 账号总览",
    ["CORE.BROKER_MINIMAP_LEFT_CLICK_TO_TOGGLE_THE"] = "Broker／小地图入口：左键打开或收起账号视图，右键打开对应设置；悬停查看多角色预览。拖动小地图入口可调整位置。拖动窗口标题栏可移动窗口。点击“排序”切换角色顺序，按住 Shift 点击可切换排序方向。Core 物品选择器出现拖放区时，可将背包物品拖入选取。",
    ["CORE.YIBOALTOBOSS_BOSSES_LOCKOUTS"] = "YiboAltoBoss · Boss 与副本进度",
    ["CORE.CLICK_A_CHARACTER_TARGET_STATUS_CELL_TO"] = "账号页中点击角色与目标交叉处的状态格，可切换该角色的击杀记录；节日首领的状态格也可点击切换手动记录。等级筛选框按 Enter 应用，按 Escape 恢复已保存条件。",
    ["CORE.YIBOLEGENDARY_LEGENDARY_PATHS"] = "YiboLegendary · 传说之路",
    ["CORE.CLICK_A_TARGET_COLUMN_OR_CHARACTER_PROGRESS"] = "点击目标列或角色进度格可打开对应路线。允许手动确认的进度行：左键标记已获得；对已有手动记录右键可撤销确认。",
    ["CORE.YIBOQUESTBLOCKER_QUEST_BLOCKER"] = "YiboQuestBlocker · 任务屏蔽",
    ["CORE.CLICK_A_QUEST_ROW_S_EXPAND_ICON"] = "点击任务行的展开图标可展开或折叠任务组。点击全局或角色状态格，可切换该任务的屏蔽状态。修改等级条件后按 Enter 应用。",
    ["CORE.YIBOTODO_DAILY_ACTIONS"] = "YiboTodo · 每日行动",
    ["CORE.CLICK_AN_AVAILABLE_ACTION_ICON_FOR_THE"] = "点击当前角色可执行的行动图标会触发图标对应操作（例如使用物品、打开专业或制造）。有第二操作的图标可右键执行；具体动作以悬停提示和图标状态为准。",
    ["CORE.YIBOMAIL_MAIL"] = "YiboMail · 邮件",
    ["CORE.RULE_BASED_MAIL_DROP_A_BAG_ITEM"] = "发规则寄页：把背包物品拖到快捷联系人图标，确认后建立或更新该物品的寄送规则。发件箱页：把背包物品拖到快捷联系人图标，会填入联系人与主题并尝试直接寄出；若客户端未确认发送，会保留已填邮件供你检查并手动发送。按住 Ctrl 点击背包物品，可把背包中同种物品一并加入附件。快捷联系人图标：右键编辑；左键拖到其它格可移动／交换，拖出联系人栏可移除。收件箱信件：左键展开／收起附件，右键打开／关闭原生信件，中键直接收取本封邮件附件；附件分组 Alt+左键只收最早到期邮件中的一个附件。",
    ["CORE.YIBOCURRENCY_CURRENCY_OVERVIEW"] = "YiboCurrency · 货币总览",
    ["CORE.RIGHT_CLICK_A_CURRENCY_ROW_TO_TOGGLE"] = "右键点击货币行，可将该货币加入或移出悬停监控；自定义货币右键会先要求确认删除。悬停货币行可查看明细。",
    ["CORE.YIBOVAULT_ACCOUNT_STORAGE"] = "YiboVault · 账号仓库",
    ["CORE.SELECT_A_CHARACTER_OR_GUILD_ON_THE"] = "点击左侧角色或公会可切换物品来源，点击上方区域标签切换背包、银行等区域。悬停物品可查看物品提示与来源信息。",
    ["CORE.YIBOCRAFTING_PROFESSION_RECIPES"] = "YiboCrafting · 专业配方",
    ["CORE.CLICK_A_RECIPE_ROW_NAME_OR_ITEM"] = "点击配方行、配方名称或物品图标可选中配方并查看详情；使用筛选和搜索缩小配方列表。搜索框按 Enter 提交当前搜索，按 Escape 仅结束输入。",
    ["CORE.YIBOREPUTATION_REPUTATION_OVERVIEW"] = "YiboReputation · 声望总览",
    ["CORE.CLICK_A_REPUTATION_NAME_TO_EXPAND_OR"] = "点击声望名称可展开／折叠分类；点击星标可加入或移出监控。点击具体声望条目可将其设为当前关注项。",
    ["CORE.YIBOBUILDS_EQUIPMENT_APPEARANCE"] = "YiboBuilds · 配装与外观",
    ["CORE.MODEL_PREVIEW_DRAG_TO_ROTATE_AND_USE"] = "装备模型预览：拖动模型可旋转，滚动鼠标滚轮可缩放。将背包中的可用附魔或宝石拖到角色装备栏对应部位，可在确认后进入游戏原生施加流程。其他装备、构筑与外观操作请使用页面上的按钮；覆盖装备前会显示确认框。",
    ["CORE.YIBOAUTOOPEN_AUTO_OPEN"] = "YiboAutoOpen · 自动开包",
    ["CORE.IN_SETTINGS_DROP_A_BAG_ITEM_INTO"] = "在设置页把背包物品拖到“拖放背包物品到这里”，可将该物品加入自动开包目录。",
    ["CORE.YIBOBEASTPATHS_BEAST_PATHS"] = "YiboBeastPaths · 隐兽寻踪",
    ["CORE.CLICK_THE_ADDON_BUTTON_ON_THE_WORLD"] = "点击世界地图上的插件按钮，可开关地图路线显示。",
    ["CORE.YIBOMOUNTS_MOUNT_JOURNAL"] = "YiboMounts · 坐骑图鉴",
    ["CORE.USE_THE_COLLECTED_AND_NOT_COLLECTED_CHECKBOXES"] = "在设置中点击“已收集”或“未收集”复选框，可切换对应坐骑是否显示。",
    ["CORE.ACCOUNT_OVERVIEW_355"] = "账号概览",
    ["CORE.CHOOSE_A_BUSINESS_PAGE_ON_THE_LEFT"] = "从左侧选择业务页，比较角色的下一步行动。",
    ["CORE.DRAG_TO_ROTATE_MOUSE_WHEEL_TO_ZOOM"] = "拖动旋转 · 滚轮缩放。",
    ["CORE.ACCOUNT_TO_DO_SETTINGS"] = "账号待办设置",
    ["CORE.EACH_SWITCH_CONTROLS_A_COLUMN_IN_THE"] = "每个开关控制账号矩阵的一列；包含多个项目的列可单独选择项目。",
    ["CORE.REPUTATION_MONITORING_SETTINGS"] = "声望监控设置",
    ["CORE.ADD_STARS_QUICKLY_IN_THE_MAIN_MATRIX"] = "星标可在主矩阵中快速添加；此处按当前顺序显示并可移除。",
    ["CORE.QUICK_CONTROLS"] = "快捷操作",
    ["CORE.MOUSE_AND_KEYBOARD_ACTIONS_BY_ADDON_ONLY"] = "按插件查看鼠标与键盘操作。仅列出有特殊行为的手势；未特别说明的按钮使用常规左键操作。",
    ["CORE.INTERFACE_GUIDE"] = "界面说明",
    ["CORE.HELP"] = "帮助",
    ["CORE.NEXT_ACTIONS"] = "下一步行动",
    ["CORE.ACCOUNT_OVERVIEW_COULD_NOT_READ_PAGE"] = "账号概览读取页面 “",
    ["CORE.S"] = "）的 ",
    ["CORE.NEXT_ACTIONS_SHOWING"] = "下一步行动（显示 ",
    ["CORE.NO_ACCOUNT_ACTIONS_NEED_ATTENTION"] = "暂无需要处理的账号行动",
    ["CORE.ADDON"] = "业务",
    ["CORE.OVERVIEW"] = "概览",
    ["CORE.ALL_CHARACTERS"] = "全部角色",
    ["CORE.WITH_PROFILES"] = "仅有档案",
    ["CORE.WITHOUT_PROFILES"] = "仅缺少档案",
    ["CORE.RESET_LAYOUT"] = "重置窗口布局",
    ["CORE.UP"] = "上移",
    ["CORE.DOWN"] = "下移",
    ["CORE.HIDE"] = "隐藏",
    ["CORE.SHOW_PAGE"] = "账号页显示",
    ["CORE.SEPARATE_ENTRY"] = "独立入口",
    ["CORE.WINDOW_HOVER"] = "窗口悬停",
    ["CORE.CORE_ENTRY"] = "Core 入口",
    ["CORE.CLEAR"] = "清除",
    ["CORE.DISPLAY_ENTRIES_385"] = "显示与入口",
    ["CORE.CHARACTERS_SORTING_386"] = "角色与排序",
    ["CORE.WINDOW_387"] = "窗口",
    ["CORE.ADDON_388"] = "插件",
    ["CORE.SETTINGS_389"] = "业务设置",
    ["CORE.MANAGE_CORE_AND_ADDON_PAGES_SEPARATE_ENTRIES"] = "集中管理 Core 与插件页面、独立入口及显示字段。",
    ["CORE.MANAGE_CHARACTERS_SORTING_CACHES_AND_BUSINESS_PAGE"] = "统一设置角色、排序、缓存和业务页面的角色过滤。",
    ["CORE.MANAGE_WINDOW_LAYOUT_TARGET_ADD_GESTURES_AND"] = "管理窗口布局、添加目标的操作方式与已加入标记。",
    ["CORE.ONLY_THIS_ADDON_S_BUSINESS_RULES_AND"] = "这里只保留该插件自身的业务规则与数据管理。",
    ["CORE.INVALID_LEVEL_FILTER"] = "等级过滤格式无效：",
    ["CORE.LEVEL_395"] = " · 等级",
    ["CORE.COULD_NOT_SAVE_LEVEL_FILTER"] = "等级过滤保存失败：",
    ["CORE.NO_SEPARATE_ENTRY"] = "无独立入口",
    ["CORE.TABLE"] = "主表",
    ["CORE.HOVER"] = "悬停",
    ["CORE.PAGE"] = "页面",
    ["CORE.VISIBLE"] = "显示",
    ["CORE.ENTRY"] = "入口",
    ["CORE.ENTRY_POSITION"] = "入口位置",
    ["CORE.PAGE_OPTIONS"] = "页面选项",
    ["CORE.TABLE_FIELDS"] = "主表字段",
    ["CORE.HOVER_FIELDS"] = "悬停字段",
    ["CORE.HOVER_407"] = "悬停·",
    ["CORE.ADDON_408"] = "插件 “",
    ["CORE.BUSINESS_SETTINGS_REFRESH_FAILED"] = "” 的业务设置局部刷新失败：",
    ["CORE.EMBEDDED_SETTINGS_CREATION_FAILED"] = "” 的嵌入设置创建失败：",
    ["CORE.BUSINESS_SETTINGS_COULD_NOT_LOAD"] = "业务设置加载失败：",
    ["CORE.USE_SHARED_SETTINGS"] = "跟随通用设置",
    ["CORE.SORT_DIRECTION"] = "排序方向：",
    ["CORE.ASCENDING"] = "升序 ↑",
    ["CORE.DESCENDING"] = "降序 ↓",
    ["CORE.PIN_CURRENT_CHARACTER"] = "当前角色置顶",
    ["CORE.REBUILD_BY_RECENT_LOGIN"] = "按最近登录顺序重建",
    ["CORE.RESTORE_REGISTRATION_ORDER"] = "恢复初始登记顺序",
    ["CORE.PREVIOUS_419"] = "上一页（",
    ["CORE.NEXT_420"] = "下一页（",
    ["CORE.LEVELS"] = "级",
    ["CORE.CURRENT_CHARACTER"] = "当前角色",
    ["CORE.DUPLICATE_SHORT_NAME"] = " · 短名重复",
    ["CORE.COULD_NOT_SAVE_SHORT_NAME"] = "短名保存失败：",
    ["CORE.DEFAULT_CHARACTER_SORTING"] = "默认角色排序",
    ["CORE.COLLAPSE_SHORT_NAMES"] = "收起短名管理",
    ["CORE.MANAGE_SHORT_NAMES"] = "管理自定义短名",
    ["CORE.CHARACTER_ORDER_CACHE"] = "角色顺序与缓存",
    ["CORE.COLLAPSE_ORDER_AND_CACHE"] = "收起顺序与缓存",
    ["CORE.OPEN_ORDER_AND_CACHE"] = "打开顺序与缓存",
    ["CORE.BUSINESS_PAGE_CHARACTER_FILTERS"] = "业务页面角色过滤",
    ["CORE.RULES_90_LEVEL_90_ONLY_1_20"] = "填写规则：90 = 仅 90 级；1-20 = 等级范围；<=3 / >=85 = 比较；留空或 0 = 不过滤。",
    ["CORE.NO_BUSINESS_PAGES_SUPPORT_CHARACTER_FILTERS"] = "暂无支持角色过滤的业务页面",
    ["CORE.CHARACTER_ARCHIVE_FILTERS"] = "角色档案角色过滤",
    ["CORE.TABLE_FILTER"] = "主表筛选：",
    ["CORE.INCLUDE_HIDDEN_CHARACTERS_IN_TABLE_FILTER"] = "主表筛选时包含已隐藏角色",
    ["CORE.TABLE_LEVEL_FILTER"] = "主表等级过滤",
    ["CORE.CHARACTER_ARCHIVE_HOVER_FILTERS"] = "角色档案悬停角色过滤",
    ["CORE.HOVER_FILTER"] = "悬停筛选：",
    ["CORE.INCLUDE_HIDDEN_CHARACTERS_IN_HOVER_FILTER"] = "悬停筛选时包含已隐藏角色",
    ["CORE.HOVER_LEVEL_FILTER"] = "悬停等级过滤",
    ["CORE.TOP_RIGHT_BUTTON_CHECK"] = "右上角按钮（＋／勾选）",
    ["CORE.MIDDLE_CLICK_443"] = "鼠标中键",
    ["CORE.CTRL_CLICK_444"] = "Ctrl＋左键",
    ["CORE.PREVIOUS_CUSTOM_GESTURE"] = "原自定义手势：",
    ["CORE.ADD_METHOD_CHOOSE_ONE"] = "添加方式（三选一）",
    ["CORE.ADDED_TARGET_MARK"] = "已加入目标标记",
    ["CORE.GOLD_CORNER_AT_BOTTOM_LEFT"] = "左下角金色直角",
    ["CORE.TEAL_DOT_AT_BOTTOM_LEFT"] = "左下角青绿圆点",
    ["CORE.MIDDLE_CLICK_OR_CTRL_CLICK_AGAIN_TO"] = "再次中键或 Ctrl＋左键可取消。",
    ["CORE.WINDOW_LAYOUT"] = "窗口布局",
    ["CORE.RESET_WINDOW_POSITION"] = "重置窗口位置",
    ["CORE.WINDOW_SIZE_ADAPTS_TO_THE_CURRENT_PAGE"] = "窗口尺寸会随当前页面内容自动适配。",
    ["CORE.CORE_ADDON_PAGES"] = "Core 与插件页面",
    ["CORE.NO_BUSINESS_ADDONS_REGISTERED"] = "暂无已注册的业务插件",
    ["CORE.NO_ADDON_SPECIFIC_SETTINGS"] = "暂无插件专属设置",
    ["CORE.UNKNOWN_LOCATION"] = "未知位置",
    ["CORE.PRIMARY_PROFESSION"] = "主专业",
    ["CORE.SECOND_PROFESSION"] = "副专业",
    ["CORE.ARCHAEOLOGY"] = "考古",
    ["CORE.FISHING"] = "钓鱼",
    ["CORE.COOKING"] = "烹饪",
    ["CORE.FIRST_AID"] = "急救",
    ["CORE.GOLD"] = "金币",
    ["CORE.G"] = "金",
    ["LANGUAGE.TITLE"] = "插件语言",
    ["LANGUAGE.AUTO"] = "跟随客户端（默认）",
    ["LANGUAGE.CHINESE"] = "中文",
    ["LANGUAGE.ENGLISH"] = "English",
    ["LANGUAGE.DESCRIPTION"] = "仅切换插件界面语言，游戏名称不变。",
    ["LANGUAGE.PENDING"] = "重载后生效。",
    ["LANGUAGE.RELOAD"] = "重载界面",
    ["LANGUAGE.ACTIVE"] = "当前界面语言：%s",
    ["FORMAT.COLON"] = "：",
    ["FORMAT.CLOSE_PAREN"] = "）",
    ["FORMAT.NEXT_ACTIONS"] = "下一步行动（显示 %d / %d）",
    ["FORMAT.CACHE_CONFIRM"] = "确定删除“%s”的插件缓存吗？",
    ["FORMAT.PAGE_CALLBACK_FAILED"] = "账号概览读取页面“%s”（%s）的 %s 失败：%s",
    ["FORMAT.ADDED_TARGETS"] = "已加入目标 · %d 项（进行中 %d / 暂停 %d / 已完成 %d）",
    ["FORMAT.PERIOD"] = "。",
    ["FORMAT.QUOTE_OPEN_PAREN"] = "”（",
})

Core.Locale:Register("YiboCore", "zh", {
    ["ENTRY.INVALID_CHANNELS"] = "入口 defaultChannels 必须包含布尔通道值。",
    ["ENTRY.CHANNEL_MINIMAP"] = "小地图",
    ["ENTRY.CHANNEL_BROKER"] = "外部 Broker",
    ["ENTRY.CHANNEL_BUILTINBAR"] = "内置条",
    ["ENTRY.CHANNELS"] = "入口展示",
    ["ENTRY.HOVER_OPTIONS"] = "通用悬停选项",
    ["ENTRY.HOVER_MAIN"] = "主窗口打开时仍显示悬停",
    ["ENTRY.BAR_TITLE"] = "内置信息条",
    ["ENTRY.BAR_ENABLED"] = "启用内置信息条",
    ["ENTRY.BAR_COUNT"] = "已选择且可用的入口：%d",
    ["ENTRY.BAR_DISABLED_HINT"] = "启用内置信息条后可调整；已有勾选会保留。",
    ["ENTRY.BAR_EMPTY"] = "请在“显示与入口”中选择内置条按钮。",
    ["ENTRY.BAR_LOCKED"] = "锁定位置",
    ["ENTRY.BAR_NAMES"] = "显示入口名称",
    ["ENTRY.BAR_RESET"] = "重置信息条位置",
    ["ENTRY.BAR_SIZE"] = "图标大小",
    ["ENTRY.BAR_SPACING"] = "图标间距",
    ["ENTRY.BROKER_LIMIT"] = "外部图标需在对应信息条中隐藏。",
})

Core.Locale:Register("YiboCore", "zh", {
    ["ENTRY.TAB_GENERAL"] = "通用",
    ["ENTRY.TAB_ENTRIES"] = "页面与入口",
    ["ENTRY.TAB_BAR"] = "信息条",
    ["ENTRY.BAR_STATUS"] = "已选择 %d 个可用按钮；在“显示与入口”中勾选内置条。",
    ["ENTRY.BAR_APPEARANCE"] = "外观与位置",
    ["ENTRY.BAR_BORDER"] = "显示外框",
    ["ENTRY.BAR_BACKGROUND"] = "背景颜色",
    ["ENTRY.BAR_OPACITY"] = "背景不透明度",
    ["ENTRY.COLOR_THEME"] = "主题深青",
    ["ENTRY.COLOR_BLACK"] = "纯黑",
    ["ENTRY.COLOR_CHARCOAL"] = "深灰",
    ["ENTRY.COLOR_NAVY"] = "深蓝",
    ["ENTRY.COLOR_FOREST"] = "深绿",
    ["ENTRY.BAR_ORDER"] = "按钮顺序",
    ["ENTRY.ORDER_BUTTON"] = "选择按钮",
    ["ENTRY.ORDER_PREVIOUS"] = "前移",
    ["ENTRY.ORDER_NEXT"] = "后移",
    ["ENTRY.ORDER_RESET"] = "恢复默认顺序",
    ["ENTRY.BAR_ORDER_HINT"] = "拖动条上图标可调序。",
    ["ENTRY.ENTRIES_HINT"] = "三处入口独立选择。内置条总开关和外观位于左侧“信息条”。",
    ["ENTRY.PAGE_NUMBER"] = "第 %d / %d 页",
    ["ENTRY.PLUGIN_PAGES"] = "插件列表",
})

Core.Locale:Register("YiboCore", "zh", {
    ["ENTRY.GENERAL_HINT"] = "统一管理插件语言与通用悬停行为。",
    ["ENTRY.PAGE_STATUS"] = "第 %d / %d 页 · 共 %d 个插件",
    ["ENTRY.PAGE_PREVIOUS"] = "上一页",
    ["ENTRY.PAGE_NEXT"] = "下一页",
})

Core.Locale:Register("YiboCore", "zh", {
    ["ENTRY.SETTINGS_ONLY"] = "仅业务设置",
    ["ENTRY.NO_SEPARATE_ENTRY"] = "无独立入口",
})

Core.Locale:Register("YiboCore", "zh", {
    ["ENTRY.BAR_PAGE_HINT"] = "管理内置信息条的外观、位置与按钮顺序。",
})

Core.Locale:Register("YiboCore", "zh", {
    ["ENTRY.HEADER_PAGE"] = "页面",
    ["ENTRY.HEADER_SHOW"] = "显示",
    ["ENTRY.HEADER_BROKER"] = "Broker",
    ["ENTRY.HEADER_BAR"] = "内置条",
    ["ENTRY.HEADER_LAYOUT"] = "布局",
    ["ENTRY.ADDON_COUNT"] = "已注册 %d 个业务插件",
})
]=====]
local original = dofile
dofile = function(path)
 local source = baseline[path:gsub("\\", "/")]
 if source then return assert(loadstring(source, "@" .. path))() end
 return original(path)
end
dofile(assert(arg[1]))
