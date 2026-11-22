local YAB = _G.YAB or {}
_G.YAB = YAB
YAB.Version = "0.2.0"
YAB.CoreReady = false

if type(WOW_PROJECT_CAMELOT) ~= "number" or WOW_PROJECT_ID ~= WOW_PROJECT_CAMELOT then
    YAB.PrintStartupMessage("WRONG_FOREVER")
    return
end

local Core = _G.YiboCore
local ready = Core and Core.IsInitialized and Core:IsInitialized()
    and Core.CheckAPIVersion and Core:CheckAPIVersion(14) and Core.HasCapability
if ready then
    for capability, version in pairs({
        localization = 1, characters = 1, ["character-identity"] = 1, ["character-name-format"] = 1,
        ["character-cleanup"] = 1, ["account-view"] = 2, ["account-entry"] = 2,
        ["account-character-admission"] = 1, ["account-preview-characters"] = 1,
        ["account-surface-budget"] = 2, ["account-surface-realm-scope"] = 1, ["basic-input"] = 1,
        ["pixel-line"] = 1,
    }) do
        if not Core:HasCapability(capability, version) then ready = false; break end
    end
end
ready = ready and Core.Locale and Core.Locale.Register and Core.Locale.Get
    and Core.Characters and Core.Characters.GetCurrentID and Core.Characters.Get and Core.Characters.FormatName
    and Core.AccountView and Core.AccountView.RegisterPage and Core.AccountView.GetScrollSurfaceWidth
    and Core.AccountView.GetColumnPage and Core.AccountView.UpdateColumnPager
    and Core.AccountView.NotifyPageChanged and Core.AccountView.Toggle and Core.AccountView.ShowPage
    and Core.Entry and Core.Entry.RegisterBusinessEntry and Core.RegisterAddon
    and Core.CharacterCleanup and Core.CharacterCleanup.RegisterOwner
    and Core.UITheme and Core.UITheme.CreateInput
    and type(Core.UITheme.ApplyPixelBackdrop) == "function" and type(Core.UITheme.ApplyPixelRule) == "function"
    and type(Core.UITheme.CreatePixelBorder) == "function" and type(Core.UITheme.GetPixelSize) == "function"
    and type(Core.UITheme.SetPixelAnchor) == "function"
    and Core.ItemConfirmation and Core.ItemConfirmation.Show
if not ready then
    YAB.PrintStartupMessage("CORE_FOREVER")
    return
end

YAB.CoreReady = true
function YAB.Text(key, ...) return Core.Locale:Get("YiboAltoBoss", key, ...) end
