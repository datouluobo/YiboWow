local Addon = {}
_G.YiboMail = Addon
Addon.NAME, Addon.VERSION, Addon.API_VERSION = "YiboMail", "1.2.14-api1", 1
Addon.REQUIRED_CORE_API = 13
Addon.FEATURES = { send = true, sendAssist = false, account = true, settings = true }
Addon.CAPABILITIES = { ["mail-items.query"] = 1, ["mail-items.state"] = 1, ["mail-items.events"] = 1,
    ["mail-items.transfers"] = 1 }
Addon.Frame = CreateFrame("Frame")
function Addon:IsRecipientSourceVisible(id)
    local settings = self.db and self.db.settings
    return not (settings and settings.recipientGroups and settings.recipientGroups[id] == false)
end
function Addon:GetShortcutLayout()
    local settings = self.db and self.db.settings or {}
    local function Dimension(value, fallback, maximum)
        value = tonumber(value)
        if not value or value ~= value then return fallback end
        return math.max(1, math.min(maximum, math.floor(value)))
    end
    return Dimension(settings.shortcutRows, 8, 12), Dimension(settings.shortcutColumns, 2, 6)
end
function Addon.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, entry in pairs(value) do result[key] = Addon.Copy(entry) end; return result
end
function Addon:Now()
    if GetServerTime then return GetServerTime(), "server" end
    return time(), "client"
end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(self:T("APP.PREFIX") .. tostring(message)) end
end
function Addon:T(key, ...)
    local core = self.Core or _G.YiboCore
    if core and core.Locale and type(core.Locale.Get) == "function" then
        return core.Locale:Get(self.NAME, key, ...)
    end
    return "[" .. self.NAME .. ":" .. tostring(key) .. "]"
end
-- Length prefixes prevent subjects containing delimiters from colliding.
function Addon.Encode(values)
    local result = {}; for _, value in ipairs(values) do value = tostring(value); result[#result + 1] = #value .. ":" .. value end
    return table.concat(result)
end
