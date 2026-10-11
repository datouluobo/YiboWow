local Core = _G.YiboCore

-- Resources belong to their addon; Core only owns selection and lookup.
local Locale = { resources = {}, bindings = {}, missing = {}, initialized = false }
Core.Locale = Locale
local MODES = { auto = true, zh = true, en = true }

local function ClientLanguage()
    local locale = GetLocale and GetLocale() or "enUS"
    return (locale == "zhCN" or locale == "zhTW") and "zh" or "en"
end

local function Normalize(mode) return MODES[mode] and mode or "auto" end

function Locale:Register(owner, language, resources)
    assert(type(owner) == "string" and owner ~= "", "Locale owner required")
    assert(language == "zh" or language == "en", "Locale language must be zh or en")
    assert(type(resources) == "table", "Locale resources must be a table")
    self.resources[owner] = self.resources[owner] or {}
    local target = self.resources[owner][language] or {}
    -- Validate before mutation so a conflict cannot leave a partial catalog.
    for key, value in pairs(resources) do
        assert(type(key) == "string" and type(value) == "string" and value ~= "", "Locale key/value required")
        assert(target[key] == nil or target[key] == value, "Conflicting locale key: " .. key)
    end
    for key, value in pairs(resources) do
        target[key] = value
        if language == "en" and self.missing[owner] then self.missing[owner][key] = nil end
    end
    self.resources[owner][language] = target
end

function Locale:GetLanguage()
    return self.previewLanguage or self.language or ClientLanguage()
end

function Locale:GetPreference()
    local db = Core.Database and Core.Database:GetDB()
    return Normalize(db and db.settings and db.settings.language)
end

function Locale:SetPreference(mode)
    if not MODES[mode] then return false, "invalid-language-mode" end
    local db = Core.Database and Core.Database:GetDB()
    if not db or not db.settings then return false, "not-ready" end
    db.settings.language = mode
    return true
end

function Locale:IsReloadPending()
    return self.initialized and self:GetPreference() ~= self.sessionPreference
end

function Locale:Get(owner, key, ...)
    local catalog = self.resources[owner] or {}
    local zh = catalog.zh or {}
    local en = catalog.en or {}
    if not en[key] then
        self.missing[owner] = self.missing[owner] or {}
        self.missing[owner][key] = true
    end
    local value = self:GetLanguage() == "en" and en[key] or zh[key]
    value = value or zh[key] or en[key]
    if not value then
        self.missing[owner] = self.missing[owner] or {}
        self.missing[owner][key] = true
        return "[" .. tostring(owner) .. ":" .. tostring(key) .. "]"
    end
    if select("#", ...) == 0 then return value end
    local ok, formatted = pcall(string.format, value, ...)
    if ok then return formatted end
    -- A bad English format falls back to the original Chinese contract.
    if zh[key] then
        ok, formatted = pcall(string.format, zh[key], ...)
        if ok then return formatted end
    end
    return value
end

function Core:Text(key, ...) return self.Locale:Get("YiboCore", key, ...) end

-- Keep existing table identities: consumers may retain references to labels.
-- Only Core-owned display metadata uses bindings; never bind SavedVariables.
function Locale:Bind(builder)
    local target = builder()
    self.bindings[#self.bindings + 1] = function()
        local values = builder()
        for key in pairs(target) do target[key] = nil end
        for key, value in pairs(values) do target[key] = value end
    end
    return target
end

function Locale:RefreshBindings()
    for _, refresh in ipairs(self.bindings) do refresh() end
end

function Locale:BindText(target, field, key, owner)
    local function Refresh() target[field] = self:Get(owner or "YiboCore", key) end
    self.bindings[#self.bindings + 1] = Refresh
    Refresh()
end

function Locale:Initialize()
    if self.initialized then return end
    local db = Core.Database:GetDB()
    db.settings.language = Normalize(db.settings.language)
    self.sessionPreference = db.settings.language
    self.language = self.sessionPreference == "auto" and ClientLanguage() or self.sessionPreference
    self.initialized = true
    self:RefreshBindings()
end

function Locale:GetMissingEnglish(owner)
    local result = {}
    for addon, catalog in pairs(self.resources) do
        if not owner or addon == owner then
            local keys = {}
            for key in pairs(catalog.zh or {}) do
                if not (catalog.en and catalog.en[key]) then keys[key] = true end
            end
            for key in pairs(self.missing[addon] or {}) do keys[key] = true end
            for key in pairs(keys) do result[#result + 1] = { owner = addon, key = key } end
        end
    end
    for addon, keys in pairs(self.missing) do
        if not self.resources[addon] and (not owner or owner == addon) then
            for key in pairs(keys) do result[#result + 1] = { owner = addon, key = key } end
        end
    end
    table.sort(result, function(a, b) return a.owner == b.owner and a.key < b.key or a.owner < b.owner end)
    return result
end

Core.Capabilities:Register("localization", 1)
