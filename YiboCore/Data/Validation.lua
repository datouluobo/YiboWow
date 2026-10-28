local Core = _G.YiboCore

-- Preflight only: do not normalize or mutate a player's saved table here.
local function Serializable(value, active, depth)
    local kind = type(value)
    if kind == "number" then return value == value and math.abs(value) < math.huge end
    if kind ~= "table" then return kind == "string" or kind == "boolean" or kind == "nil" end
    if depth > 64 or active[value] or getmetatable(value) ~= nil then return false end
    active[value] = true
    for key, child in pairs(value) do
        if (type(key) ~= "string" and type(key) ~= "number")
            or not Serializable(key, active, depth + 1) or not Serializable(child, active, depth + 1) then
            active[value] = nil
            return false
        end
    end
    active[value] = nil
    return true
end

local function Tables(value, keys)
    if value == nil then return true end
    if type(value) ~= "table" then return false end
    for _, key in ipairs(keys) do
        if value[key] ~= nil and type(value[key]) ~= "table" then return false end
    end
    return true
end

local function Records(value, validate)
    if value == nil then return true end
    for key, record in pairs(value) do
        if type(record) ~= "table" or (validate and not validate(record, key)) then return false end
    end
    return true
end

function Core._private.ValidateStore(saved)
    if saved == nil then return true end
    if type(saved) ~= "table" or not Serializable(saved, {}, 0) then return false end
    local schema = saved.schemaVersion == nil and 0 or tonumber(saved.schemaVersion)
    if not schema or schema < 0 or schema % 1 ~= 0 then return false end
    if not Tables(saved, { "characters", "characterDisplay", "settings", "migrationHistory",
        "characterDeletionHistory", "characterDataOwners", "clientScope" }) then return false end
    local characters = saved.characters
    if not Tables(characters, { "byID", "aliases", "seenOrder" }) then return false end
    if characters then
        if not Records(characters.byID, function(record, id)
            if type(id) ~= "string" or (record.id ~= nil and record.id ~= id) then return false end
            if not Tables(record, { "domains", "profile", "observedAt", "availability", "sources" }) then return false end
            if not Tables(record.profile, { "professions", "primaryProfessions", "specialization" }) then return false end
            if record.profile and (not Records(record.profile.professions) or not Records(record.profile.primaryProfessions)) then return false end
            return Records(record.domains, function(domain) return Tables(domain, { "data" }) end)
        end) then return false end
        for _, id in pairs(characters.aliases or {}) do if type(id) ~= "string" then return false end end
        for _, order in pairs(characters.seenOrder or {}) do if type(order) ~= "number" then return false end end
    end
    if not Records(saved.characterDisplay) then return false end
    if not Records(saved.characterDeletionHistory, function(record)
        return Tables(record, { "character", "aliases", "acknowledgedOwners", "failures", "requiredOwners" })
    end) then return false end
    if not Tables(saved.settings, { "accountView", "businessItemGesture", "businessItemActions" }) then return false end
    local view = saved.settings and saved.settings.accountView
    if not Tables(view, { "pages", "fields", "firstUseHints", "hiddenCharacters", "pageCharacterSorts",
        "pageSizes", "customCharacterOrder", "entry", "pageCharacterFilters", "pageViewModes", "pageScopes",
        "columnPages", "columnPageStructures", "pageLayouts", "characterArchive" }) then return false end
    if view then
        if view.characterSort ~= nil and type(view.characterSort) ~= "table"
            and not (schema < 5 and type(view.characterSort) == "string") then return false end
        if not Records(view.pageCharacterSorts) or not Records(view.pageSizes) or not Records(view.pageLayouts) then return false end
        if not Records(view.columnPages) or not Records(view.columnPageStructures) then return false end
        local entry = view.entry
        if not Tables(entry, { "minimap", "broker", "pageModes", "pagePositions", "coreChannels", "businessChannels", "bar" }) then return false end
        if entry and (not Records(entry.businessChannels) or not Tables(entry.bar, { "order" })) then return false end
        if entry then
            if entry.minimap and entry.minimap.angle ~= nil and not tonumber(entry.minimap.angle) then return false end
            for _, angle in pairs(entry.pagePositions or {}) do if not tonumber(angle) then return false end end
        end
        local archive = view.characterArchive
        if not Tables(archive, { "fields", "previewFields", "filters" }) then return false end
        if archive and not Tables(archive.filters, { "page", "preview" }) then return false end
    end
    return true
end
