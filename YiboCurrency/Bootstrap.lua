local ADDON_NAME = ...
local Addon = _G.YiboCurrency or {}
_G.YiboCurrency = Addon
Addon.NAME, Addon.VERSION = "YiboCurrency", "0.1.0"

local function Defaults(target, values)
    for key, value in pairs(values) do
        if type(value) == "table" then
            target[key] = type(target[key]) == "table" and target[key] or {}
            Defaults(target[key], value)
        elseif target[key] == nil then target[key] = value end
    end
end

function Addon:EnsureDB()
    YiboCurrencyDB = YiboCurrencyDB or {}
    local version = tonumber(YiboCurrencyDB.version) or 0
    -- The first development build added a level-90 default without an
    -- explicit player choice.  Currency is an account ledger, so retain all
    -- eligible characters unless the player later enters a filter.
    if version < 2 and YiboCurrencyDB.settings and YiboCurrencyDB.settings.levelExpr == "90" then
        YiboCurrencyDB.settings.levelExpr = ""
    end
    Defaults(YiboCurrencyDB, { version = 2, settings = { visible = {}, monitored = {}, previewColumns = { value = true }, levelExpr = "", customItems = {} } })
    YiboCurrencyDB.version = math.max(version, 2)
    return YiboCurrencyDB
end
function Addon:GetSettings() return self:EnsureDB().settings end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] 货币管家:|r " .. tostring(message)) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then Addon:EnsureDB()
    elseif event == "PLAYER_LOGIN" and Addon.CoreIntegration then
        local ok, err = Addon.CoreIntegration:Initialize()
        if not ok then Addon:Print("Core 接入失败：" .. tostring(err)) end
    end
end)
