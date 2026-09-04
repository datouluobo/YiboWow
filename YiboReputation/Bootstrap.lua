local ADDON_NAME = ...
local Addon = _G.YiboReputation or {}
_G.YiboReputation = Addon
Addon.NAME, Addon.VERSION = "YiboReputation", "1.2.0"
YiboReputationDB = YiboReputationDB or {}

local function Defaults(target, values)
    for key, value in pairs(values) do
        if type(value) == "table" then target[key] = type(target[key]) == "table" and target[key] or {}; Defaults(target[key], value)
        elseif target[key] == nil then target[key] = value end
    end
end
function Addon:EnsureDB()
    Defaults(YiboReputationDB, { settings = { hoverMode = "monitored", monitoredFactionIDs = {}, defaultExpansion = "auto", defaultMatrixFilter = "all", matrixLevelExpr = "", showFriendshipTotal = false }, matrixExpanded = {}, nomi = {} })
    local settings = YiboReputationDB.settings
    -- The old dual-view state and preview-column projection are deliberately
    -- not carried forward.  Keep the only meaningful preference: friendship
    -- detail.  Old tree expansion is useful as a starting matrix expansion.
    if YiboReputationDB.treeExpanded and not next(YiboReputationDB.matrixExpanded) then
        for key, value in pairs(YiboReputationDB.treeExpanded) do
            YiboReputationDB.matrixExpanded["matrix:" .. tostring(key)] = value
        end
    end
    settings.viewMode, settings.expansion, settings.category, settings.previewColumns = nil, nil, nil, nil
    -- Hover is an account-level preview.  The former current-character tree
    -- duplicated the game UI and produced a second, unrelated layout mode.
    settings.hoverMode = "monitored"
    if settings.defaultMatrixFilter ~= "monitored" then settings.defaultMatrixFilter = "all" end
    if _G.YiboCore and _G.YiboCore.LevelFilter then
        local valid, normalized = _G.YiboCore.LevelFilter:Validate(settings.matrixLevelExpr or "")
        settings.matrixLevelExpr = valid and normalized or ""
    else
        settings.matrixLevelExpr = ""
    end
    while #settings.monitoredFactionIDs > 10 do table.remove(settings.monitoredFactionIDs) end
    return YiboReputationDB
end
function Addon:GetSettings() return self:EnsureDB().settings end
function Addon:Print(message) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] 声望总览:|r " .. tostring(message)) end end
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED"); frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then Addon:EnsureDB()
    elseif event == "PLAYER_LOGIN" and Addon.CoreIntegration then local ok, err = Addon.CoreIntegration:Initialize(); if not ok then Addon:Print("Core 接入失败：" .. tostring(err)) end end
end)
