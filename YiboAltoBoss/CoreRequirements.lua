local Core = _G.YiboCore
local YAB = _G.YAB or {}
_G.YAB = YAB
YAB.CoreReady = false
local required = {
    { "localization", 1 }, { "characters", 1 }, { "character-identity", 1 },
    { "character-name-format", 1 }, { "basic-input", 1 }, { "account-view", 2 },
    { "account-preview-field-groups", 1 }, { "account-entry", 2 }, { "character-cleanup", 1 }, { "level-filter", 1 },
}
local ready = Core and Core.CheckAPIVersion and Core:CheckAPIVersion(13)
    and Core.HasCapability and Core.IsInitialized and Core:IsInitialized()
    and Core.ItemConfirmation and type(Core.ItemConfirmation.Show) == "function"
    and Core.Locale and type(Core.Locale.Register) == "function" and type(Core.Locale.Get) == "function"
    and Core.Characters and type(Core.Characters.Get) == "function"
    and type(Core.Characters.FormatName) == "function" and type(Core.Characters.ResolveLegacyKey) == "function"
    and Core.UITheme and type(Core.UITheme.CreateInput) == "function"
    and Core.AccountView and type(Core.AccountView.RegisterPage) == "function"
    and Core.Entry and type(Core.Entry.RegisterBusinessEntry) == "function"
    and Core.CharacterCleanup and type(Core.CharacterCleanup.RegisterOwner) == "function"
    and Core.LevelFilter and type(Core.LevelFilter.Validate) == "function" and type(Core.LevelFilter.Normalize) == "function"
if ready then
    for _, item in ipairs(required) do
        if not Core:HasCapability(item[1], item[2]) then ready = false; break end
    end
end
if not ready then
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r YiboAltoBoss requires YiboCore API13 and current UI/locale capabilities. Please upgrade YiboCore. 请升级 YiboCore。")
    end
    return
end
YAB.CoreReady = true
function YAB.Text(key, ...) return Core.Locale:Get("YiboAltoBoss", key, ...) end
