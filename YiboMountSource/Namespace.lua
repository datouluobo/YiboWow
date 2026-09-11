local ADDON_NAME, NS = ...

NS.NAME = ADDON_NAME
NS.VERSION = "0.5"
NS.INTERFACE = 50504
NS.Locale = NS.Locale or {}

function NS:GetLocaleTable()
    local locale = GetLocale and GetLocale() or "enUS"
    return self.Locale[locale] or self.Locale.enUS or {}
end

function NS:L(key)
    local active = self:GetLocaleTable()
    return active[key] or (self.Locale.enUS and self.Locale.enUS[key]) or key
end

function NS:GetLocalizedText(values)
    if type(values) ~= "table" then return nil end
    local locale = GetLocale and GetLocale() or "enUS"
    return values[locale] or values.enUS
end

function NS:SafeCall(callback, ...)
    local ok, result = pcall(callback, ...)
    if ok then return result end
    return nil
end
