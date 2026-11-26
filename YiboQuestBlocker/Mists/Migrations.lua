local YQB = _G.YQB
local Core = _G.YiboCore
local ADDON_NAME = ...
local SCHEMA_VERSION = 3

local function ResolveV1CharacterID(key)
    return Core.Characters:ResolveLegacyKey(key)
end

local function BuildV1RealmSet(knownChars)
    local realms, firstPartCounts = {}, {}
    for _, character in ipairs(Core.Characters:GetAll({ identityOnly = true })) do
        if character.realm and character.realm ~= "" then realms[character.realm] = true end
    end
    for oldKey in pairs(knownChars) do
        local left = tostring(oldKey):match("^(.-)%-")
        if left then firstPartCounts[left] = (firstPartCounts[left] or 0) + 1 end
    end
    -- A server appears as the first component for multiple v1 characters;
    -- character names normally occur only once.  This also recognizes realms
    -- not yet present in Core without depending on Lua table iteration order.
    for value, count in pairs(firstPartCounts) do if count >= 2 then realms[value] = true end end
    return realms
end

local function BuildV1Identity(oldKey, identity, assumeRealmFirst, knownRealms)
    local existingID = ResolveV1CharacterID(oldKey)
    local left, right = tostring(oldKey or ""):match("^(.-)%-(.+)$")
    if not left or not right then return existingID end

    local realms = knownRealms

    local name, realm
    if realms[left] and not realms[right] then
        realm, name = left, right
    elseif realms[right] and not realms[left] then
        name, realm = left, right
    else
        local current = Core.Characters:GetCurrent({ identityOnly = true })
        if current and ((left == current.realm and right == current.name) or (left == current.name and right == current.realm)) then
            name, realm = current.name, current.realm
        elseif assumeRealmFirst then
            -- QuestBlocker v1's canonical durable key was `服务器-角色名`.
            -- Reversed aliases introduced by intermediate builds will already
            -- resolve through Core before reaching this fallback.
            realm, name = left, right
        end
    end
    if not name or not realm then return existingID end

    local imported = {
        name = name,
        realm = realm,
        class = identity and identity.class,
        level = identity and identity.level,
        seenOrder = identity and identity.seenOrder,
    }
    return Core.Characters:ImportLegacyCharacter(ADDON_NAME, oldKey, imported)
end

local function MigrateCharacters(db)
    local characterData = type(db.characterData) == "table" and db.characterData or {}
    local sourceSnapshots = db.perChar or {}
    local sourceCount, migratedCount = 0, 0
    local knownRealms = BuildV1RealmSet(db.knownChars or {})

    -- One-time upgrade only: hand v1 identity metadata to Core first, then
    -- translate business snapshots to Core IDs.  v1 fields are erased only
    -- after every business snapshot has a durable Core identity.
    for oldKey, identity in pairs(db.knownChars or {}) do
        BuildV1Identity(oldKey, identity, false, knownRealms)
    end
    for oldKey, data in pairs(sourceSnapshots) do
        sourceCount = sourceCount + 1
        local characterID = ResolveV1CharacterID(oldKey) or BuildV1Identity(oldKey, nil, true, knownRealms)
        if characterID then
            characterData[characterID] = YQB.MergeTables(characterData[characterID], data)
            migratedCount = migratedCount + 1
        end
    end
    db.characterData = characterData
    db.schemaVersion = SCHEMA_VERSION
    if migratedCount == sourceCount then
        db.knownChars = nil
        db.perChar = nil
        db.customCharOrder = nil
        db.characterOrder = nil
        db.characterKeyVersion = nil
        db.migrationError = nil
    else
        db.migrationError = {
            sourceCount = sourceCount,
            migratedCount = migratedCount,
        }
    end
end

function YQB.MigrateDatabase(db)
    if db.knownChars or db.perChar or (db.schemaVersion and db.schemaVersion < SCHEMA_VERSION) then
        MigrateCharacters(db)
    end
    db.filters = db.filters or { showDaily = true, showNormal = true, hideComplete = true }
    local filters = db.filters
    if filters.autoAbandon == nil then filters.autoAbandon = false end
    if filters.levelExpr == nil then
        local minimum, maximum = tonumber(filters.levelMin) or 0, tonumber(filters.levelMax) or 90
        local operator = filters.levelOp
        if operator == "以上" then
            filters.levelExpr = ">=" .. minimum
        elseif operator == "以下" then
            filters.levelExpr = "<=" .. maximum
        elseif operator == "等于" then
            filters.levelExpr = tostring(minimum)
        elseif operator == "至" and not (minimum == 0 and maximum == 90) then
            filters.levelExpr = minimum .. "-" .. maximum
        end
    end
    if filters.levelExpr == nil or filters.levelExpr == "" then filters.levelExpr = "90" end
    db.settings = db.settings or {}
    db.settings.runtime = db.settings.runtime or {}
    local runtime = db.settings.runtime
    if runtime.processMode == nil then
        runtime.processMode = runtime.directReject == false and "abandon" or "direct"
    end
end
