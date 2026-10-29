local ADDON_NAME = ...
local Addon = _G.YiboReputation or {}
_G.YiboReputation = Addon
Addon.NAME, Addon.VERSION = "YiboReputation", "1.7.3"
Addon.CLIENT_SUPPORTED = not (type(WOW_PROJECT_CAMELOT) == "number" and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
if Addon.CLIENT_SUPPORTED then YiboReputationDB = YiboReputationDB or {} end

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
function Addon:T(key, ...)
    local core = _G.YiboCore
    if core and core.Locale and type(core.Locale.Get) == "function" then
        return core.Locale:Get("YiboReputation", key, ...)
    end
    if key == "ERROR.CORE_REQUIRED" then
        local locale = GetLocale and GetLocale() or "enUS"
        return (locale == "zhCN" or locale == "zhTW")
            and "YiboReputation 需要 YiboCore 1.12.4 / API13，以及 account-surface-budget:2、语言、账号视图、角色身份、角色缓存清理、事件与标准控件能力。请升级 YiboCore。"
            or "YiboReputation requires YiboCore 1.12.4 / API13 with account-surface-budget:2, localization, account views, character identity, character cleanup, events, and standard controls. Please update YiboCore."
    end
    local value = "[YiboReputation:" .. tostring(key) .. "]"
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end
function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. self:T("PAGE.TITLE") .. ": " .. tostring(message)) end
end
function Addon:PrintBootstrapRequirement()
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. self:T("ERROR.CORE_REQUIRED")) end
end
local function Initialize()
    local core = _G.YiboCore
    if core and core.IsInitialized and core:IsInitialized() then
        local ok, err = Addon.CoreIntegration:Initialize()
        if not ok then Addon:Print(Addon:T("ERROR.CORE_PREFIX", tostring(err))) end
    else Addon:PrintBootstrapRequirement() end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then return end
    if not Addon.CLIENT_SUPPORTED then Addon:Print(Addon:T("FOREVER.WRONG_MANIFEST")); return end
    Addon:EnsureDB()
    local core = _G.YiboCore
    if core and core.IsInitialized and core:IsInitialized() then Initialize()
    elseif core and core.Events and core.Events.Register then
        core.Events:Register("CORE_READY", Addon.CoreIntegration, Initialize)
    else Addon:PrintBootstrapRequirement() end
end)
