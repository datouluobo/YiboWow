local ADDON_NAME = ...
local Addon = _G.YiboCurrency or {}
_G.YiboCurrency = Addon
Addon.NAME, Addon.VERSION = "YiboCurrency", "1.1.0"

local function Defaults(target, values)
    for key, value in pairs(values) do
        if type(value) == "table" then target[key] = type(target[key]) == "table" and target[key] or {}; Defaults(target[key], value)
        elseif target[key] == nil then target[key] = value end end
end

function Addon:EnsureDB()
    YiboCurrencyDB = YiboCurrencyDB or {}
    local version = tonumber(YiboCurrencyDB.version) or 0
    YiboCurrencyDB.settings = YiboCurrencyDB.settings or {}
    if version < 2 and YiboCurrencyDB.settings.levelExpr == "90" then YiboCurrencyDB.settings.levelExpr = "" end
    Defaults(YiboCurrencyDB, { version = 4, settings = { visible = {}, monitored = {}, hoverOrderOverride = nil, hoverTranspose = false, levelExpr = "", customItems = {} } })
    if version < 4 then
        if type(YiboCurrencyDB.settings.previewColumns) ~= "table" then
            YiboCurrencyDB.settings.previewColumns = {}
            for id, enabled in pairs(YiboCurrencyDB.settings.monitored or {}) do
                YiboCurrencyDB.settings.previewColumns[id] = enabled == true
            end
        end
    end
    YiboCurrencyDB.settings.previewColumns = type(YiboCurrencyDB.settings.previewColumns) == "table" and YiboCurrencyDB.settings.previewColumns or {}
    YiboCurrencyDB.version = math.max(version, 4)
    return YiboCurrencyDB
end
function Addon:GetSettings() return self:EnsureDB().settings end
function Addon:T(key, ...)
    local core = _G.YiboCore
    if core and core.Locale and type(core.Locale.Get) == "function" then return core.Locale:Get(self.NAME, key, ...) end
    return "[" .. self.NAME .. ":" .. key .. "]"
end
function Addon:UpgradeMessage()
    local core = _G.YiboCore
    if core and core.Locale and type(core.Locale.Get) == "function" then return self:T("UI.CORE_UPGRADE") end
    return "YiboCurrency requires YiboCore 1.12.4 / API13 with account-dynamic-fields:1; upgrade Core and reload."
end
function Addon:Print(message)
    if not DEFAULT_CHAT_FRAME then return end
    local core = _G.YiboCore
    if core and core.Locale and type(core.Locale.Get) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(self:T("CHAT.MESSAGE", tostring(message)))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r Currency: " .. tostring(message))
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED"); frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then Addon:EnsureDB()
    elseif event == "PLAYER_LOGIN" and Addon.CoreIntegration then
        local ok, err = Addon.CoreIntegration:Initialize(); if not ok then Addon:Print(tostring(err)) end
    end
end)
