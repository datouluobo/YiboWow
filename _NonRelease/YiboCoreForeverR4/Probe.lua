-- Non-release, target-scoped final-package acceptance. No pet data or business consumers.
local addon = ...
local config = _G.YiboCoreR4ProbeTarget
if type(config) ~= "table" or WOW_PROJECT_ID ~= config.project
    or type(_G[config.constant]) ~= "number" or _G[config.constant] ~= config.project then return end
local Core = _G.YiboCore
if not Core or type(Core.IsInitialized) ~= "function" or not Core:IsInitialized()
    or not Core:CheckAPIVersion(13) or not Core:HasCapability("characters", 1)
    or not Core:HasCapability("character-identity", 1) or not Core:HasCapability("localization", 1)
    or not Core.AccountView or type(Core.AccountView.SetDefaultCharacterSort) ~= "function" then
    print("[CoreR4] unavailable=core-not-ready-or-incompatible")
    return
end
local store = Core.Database:GetDB()
if not store or not store.clientScope or store.clientScope.target ~= config.target then return end
Core.Locale:Register(addon, "zh", { MARKED = "测试排序标记已写入内存；请按步骤重载后检查。" })
Core.Locale:Register(addon, "en", { MARKED = "Test sorting marker set in memory; reload when instructed, then check again." })
local function SortCopy(value)
    return { mode = value.mode, direction = value.direction, pinCurrent = value.pinCurrent == true }
end
local function Matches(left, right)
    return left and right and left.mode == right.mode and left.direction == right.direction
        and left.pinCurrent == right.pinCurrent
end
local function Report()
    local version, build, _, interface = GetBuildInfo()
    local ownName = ({ Retail = "YiboCoreRetailDB", Mists = "YiboCoreDB", Forever = "YiboCoreForeverDB" })[config.target]
    local current = Core.Characters:GetCurrent({ identityOnly = true })
    local indexCount = 0; for _ in pairs(Core.PackagedAddonVersions or {}) do indexCount = indexCount + 1 end
    local repeatedReady = 0
    local listener = function() repeatedReady = repeatedReady + 1 end
    Core.Events:Register("CORE_READY", addon, listener)
    local repeatOK = Core:Initialize() and Core:Initialize()
    Core.Events:Unregister("CORE_READY", addon, listener)
    local state = _G[config.savedVariable]
    local marker = state and state.expectedSort and tostring(Matches(Core.AccountView:GetDefaultCharacterSort(), state.expectedSort)) or "unset"
    print(string.format("[CoreR4] target=%s client=%s build=%s interface=%s project=%s locale=%s",
        config.target, tostring(version), tostring(build), tostring(interface), tostring(WOW_PROJECT_ID), tostring(GetLocale())))
    print(string.format("[CoreR4] ready=%s version=%s api=%s schema=%s ownStore=%s index=%s indexCount=%s repeatOK=%s repeatedReady=%s",
        tostring(Core:IsInitialized()), Core:GetVersion(), tostring(Core.API_VERSION), tostring(store.schemaVersion),
        tostring(store == _G[ownName]), tostring(type(Core.PackagedAddonVersions) == "table"), tostring(indexCount),
        tostring(repeatOK), tostring(repeatedReady)))
    print(string.format("[CoreR4] characters=%s currentIdentity=%s marker=%s sort=%s/%s/%s",
        tostring(#Core.Characters:GetAll({ identityOnly = true })), tostring(current ~= nil), marker,
        tostring(Core.AccountView:GetDefaultCharacterSort().mode), tostring(Core.AccountView:GetDefaultCharacterSort().direction),
        tostring(Core.AccountView:GetDefaultCharacterSort().pinCurrent)))
end
SlashCmdList[config.slashID] = function(message)
    if (message or ""):lower():match("^%s*mark%s*$") then
        local before = Core.AccountView:GetDefaultCharacterSort()
        local after = { mode = before.mode == "recent" and "level" or "recent",
            direction = before.direction == "asc" and "desc" or "asc", pinCurrent = not before.pinCurrent }
        local selected = Core.AccountView:SetDefaultCharacterSort(after)
        _G[config.savedVariable] = { originalSort = SortCopy(before), expectedSort = SortCopy(selected) }
        print("[CoreR4] " .. Core.Locale:Get(addon, "MARKED"))
    end
    Report()
end
_G["SLASH_" .. config.slashID .. "1"] = config.slash
