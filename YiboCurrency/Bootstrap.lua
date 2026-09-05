local ADDON_NAME = ...
local Addon = _G.YiboCurrency or {}
_G.YiboCurrency = Addon
Addon.NAME, Addon.VERSION = "YiboCurrency", "0.2.0"

local function Defaults(target, values)
    for key, value in pairs(values) do
        if type(value) == "table" then target[key] = type(target[key]) == "table" and target[key] or {}; Defaults(target[key], value)
        elseif target[key] == nil then target[key] = value end end
end

function Addon:EnsureDB()
    YiboCurrencyDB = YiboCurrencyDB or {}
    local version = tonumber(YiboCurrencyDB.version) or 0
    YiboCurrencyDB.settings = YiboCurrencyDB.settings or {}
    -- Monitoring changed from a field projection into its own ordered matrix.
    -- Do not guess at a player's former selection: it had different semantics.
    if version < 3 then
        YiboCurrencyDB.settings.previewColumns = nil
        YiboCurrencyDB.settings.monitored = {}
        YiboCurrencyDB.settings.hoverOrderOverride = nil
    end
    if version < 2 and YiboCurrencyDB.settings.levelExpr == "90" then YiboCurrencyDB.settings.levelExpr = "" end
    Defaults(YiboCurrencyDB, { version = 3, settings = { visible = {}, monitored = {}, hoverOrderOverride = nil, levelExpr = "", customItems = {} } })
    YiboCurrencyDB.version = math.max(version, 3)
    return YiboCurrencyDB
end
function Addon:GetSettings() return self:EnsureDB().settings end
function Addon:Print(message) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] 货币管家:|r " .. tostring(message)) end end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED"); frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then Addon:EnsureDB()
    elseif event == "PLAYER_LOGIN" and Addon.CoreIntegration then
        local ok, err = Addon.CoreIntegration:Initialize(); if not ok then Addon:Print("Core 接入失败：" .. tostring(err)) end
    end
end)
