local ADDON_NAME, NS = ...

NS.NAME = ADDON_NAME
NS.VERSION = "1.0.0"
NS.INTERFACE = 50504
NS.Locale = NS.Locale or {}
NS.DefaultSettings = {
    collectionStatus = {
        showCollected = true,
        showUncollected = true,
    },
}

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = type(target[key]) == "table" and target[key] or {}
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function NS:EnsureDB()
    YiboMountsDB = YiboMountsDB or {}
    ApplyDefaults(YiboMountsDB, { version = 1, settings = self.DefaultSettings })
    YiboMountsDB.version = math.max(tonumber(YiboMountsDB.version) or 0, 1)
    return YiboMountsDB
end

function NS:GetSettings()
    return self:EnsureDB().settings
end

function NS:GetLocaleTable()
    if self.CoreIntegration and self.CoreIntegration.localeAvailable and _G.YiboCore
        and _G.YiboCore.Locale and _G.YiboCore.Locale.GetLanguage then
        return _G.YiboCore.Locale:GetLanguage() == "zh" and self.Locale.zhCN or self.Locale.enUS or {}
    end
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "zhTW" then locale = "zhCN" end
    return self.Locale[locale] or self.Locale.enUS or {}
end

function NS:L(key)
    if self.CoreIntegration and self.CoreIntegration.localeAvailable then
        return _G.YiboCore.Locale:Get(self.NAME, key)
    end
    local active = self:GetLocaleTable()
    return active[key] or (self.Locale.enUS and self.Locale.enUS[key]) or key
end

function NS:GetLocalizedText(values)
    if type(values) ~= "table" then return nil end
    local language = self:GetLocaleTable() == self.Locale.zhCN and "zhCN" or "enUS"
    return values[language] or values.enUS or values.zhCN
end

function NS:SafeCall(callback, ...)
    local ok, result = pcall(callback, ...)
    if ok then return result end
    return nil
end
