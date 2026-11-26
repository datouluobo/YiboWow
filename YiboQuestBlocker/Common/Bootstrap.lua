local YQB = _G.YQB
local Core = _G.YiboCore
local ADDON_NAME = ...
local REQUIRED_CORE_API = 14
YQB.REQUIRED_CORE_API = REQUIRED_CORE_API

local capabilities = {
    ["localization"] = 1, ["character-identity"] = 1, ["character-name-format"] = 1,
    ["basic-input"] = 1, ["pixel-line"] = 1, ["account-view"] = 2,
    ["account-entry"] = 2, ["account-surface-budget"] = 2, ["level-filter"] = 1,
}

local function ReportRequirements()
    local message = Core and Core.Locale and Core.Locale.Get
        and Core.Locale:Get("YiboQuestBlocker", "CORE.STARTUP_REQUIREMENTS")
    if Core and Core.Print and message then Core:Print(message)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("YiboQuestBlocker requires the matching client and YiboCore API 14.")
    end
end

if Core and Core.Locale and Core.Locale.Register and Core.Locale.Get then
    YQB.RegisterLocales()
end

function YQB.Initialize()
    if YQB.initialized then return true end
    if not (YQB.Target.supported and Core and Core.CheckAPIVersion and Core:CheckAPIVersion(REQUIRED_CORE_API)
        and Core.IsInitialized and Core.HasCapability) then
        ReportRequirements()
        return false
    end
    if not Core:IsInitialized() then return false, "pending" end
    for capability, minimum in pairs(capabilities) do
        if not Core:HasCapability(capability, minimum) then
            ReportRequirements()
            return false
        end
    end
    if not (Core.Events and Core.Characters and Core.Characters.FormatName and Core.RegisterAddon
        and Core.Locale and Core.Locale.Register and Core.Locale.Get
        and Core.AccountView and Core.AccountView.RegisterPage and Core.AccountView.GetScrollSurfaceWidth
        and Core.Entry and Core.Entry.RegisterBusinessEntry and YQB.AccountPage
        and Core.UITheme and Core.UITheme.CreateInput
        and Core.UITheme.ApplyPixelBackdrop and Core.UITheme.CreatePixelBorder
        and Core.LevelFilter and Core.LevelFilter.Validate) then
        ReportRequirements()
        return false
    end
    if YQB.CanReadQuestLog and not YQB.CanReadQuestLog() then
        Core:Print(YQB.T("FOREVER.QUEST_API_UNAVAILABLE"))
        return false
    end
    if not Core.Characters:GetCurrentID() then return false, "pending" end
    if not YQB.CoreCompatible then
        YQB.InitializeStore()
        YQB.CoreCompatible = true
    end
    local connected, errorMessage = YQB.CoreIntegration:Initialize()
    if not connected then
        Core:Print(YQB.T("CORE.INTEGRATION_FAILED", tostring(errorMessage)))
        return false
    end
    YQB.StartQuestRuntime()
    SLASH_YQB1 = "/yqb"
    SlashCmdList["YQB"] = YQB.OpenAccountPage
    YQB.initialized = true
    Core.Events:Unregister("CORE_READY", YQB)
    Core.Events:Unregister("CHARACTER_UPDATED", YQB)
    return true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    local _, state = YQB.Initialize()
    if state == "pending" then
        Core.Events:Register("CORE_READY", YQB, YQB.Initialize)
        Core.Events:Register("CHARACTER_UPDATED", YQB, YQB.Initialize)
    end
end)
