local _, ns = ...
if not ns.YBP_TARGET_OK then return end

local capabilities = {
    { "runtime", 1 }, { "events", 1 }, { "characters", 1 },
    { "character-identity", 1 }, { "character-name-format", 1 },
    { "character-cleanup", 2 }, { "account-view", 2 },
    { "account-character-admission", 1 }, { "account-surface-budget", 2 },
    { "account-entry", 2 }, { "builtin-entry-bar", 3 }, { "localization", 1 }, { "basic-input", 1 },
}
local methods = {
    { "Characters", "GetCurrentID" }, { "Characters", "GetCurrent" },
    { "Characters", "GetAll" }, { "Characters", "FormatName" },
    { "CharacterCleanup", "RegisterOwner" }, { "AccountView", "RegisterPage" },
    { "AccountView", "UnregisterPage" }, { "AccountView", "NotifyPageChanged" },
    { "AccountView", "ShowPage" }, { "AccountView", "Toggle" },
    { "AccountView", "GetScrollSurfaceWidth" }, { "Entry", "RegisterBusinessEntry" },
    { "Locale", "Register" }, { "Locale", "Get" },
    { "Events", "Register" }, { "Events", "Unregister" },
    { "UITheme", "CreateText" }, { "UITheme", "CreateScrollFrame" },
    { "UITheme", "CreateBusinessTabs" }, { "UITheme", "CreateInput" }, { "UITheme", "CreateButton" },
    { "UITheme", "CreateDropdown" },
}

function ns.CheckOfflinePetCore(core)
    if not core then return false, "missing" end
    for _, name in ipairs({ "CheckAPIVersion", "IsInitialized", "HasCapability", "RegisterAddon" }) do
        if type(core[name]) ~= "function" then return false, "upgrade" end
    end
    if not core:CheckAPIVersion(13) then return false, "upgrade" end
    if not core:IsInitialized() then return false, "not-ready" end
    for _, required in ipairs(capabilities) do
        if not core:HasCapability(required[1], required[2]) then return false, "upgrade" end
    end
    for _, required in ipairs(methods) do
        if type(core[required[1]]) ~= "table" or type(core[required[1]][required[2]]) ~= "function" then
            return false, "upgrade"
        end
    end
    if type(core.UITheme.Font) ~= "table" or type(core.UITheme.Colors) ~= "table" then
        return false, "upgrade"
    end
    return true
end
