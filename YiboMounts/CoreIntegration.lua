local _, NS = ...

local Core = _G.YiboCore
local Integration = {}
NS.CoreIntegration = Integration

local SETTINGS_ID = "mounts"

local function WarnUnavailable()
    if Integration.warned then return end
    Integration.warned = true
    local message = NS:L("CORE_REQUIRED")
    if Core and type(Core.Print) == "function" then
        Core:Print(message)
    elseif DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r YiboMounts: " .. message)
    end
end

function Integration:IsCollectionStatusAvailable()
    return self.initialized == true
end

local function AddText(context, parent, text, size, color)
    local label = context.createText(parent, size, color, "LEFT")
    -- Keep the client's localized Blizzard font object.  Replacing it with
    -- STANDARD_TEXT_FONT can bypass the CJK fallback and produce distorted
    -- glyphs on some clients.
    label:SetFontObject("GameFontNormalSmall")
    label:SetText(text)
    label:SetWordWrap(true)
    return label
end

function Integration:CreateSettingsPanel(parent, context)
    local Theme = Core.UITheme
    local settings = NS:GetSettings().collectionStatus
    local section = context.createSection(parent, NS:L("SETTINGS_COLLECTION_STATUS"), parent:GetWidth() or 600, 154)
    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    section:SetWidth(parent:GetWidth() or 600)
    local description = AddText(context, section, NS:L("SETTINGS_COLLECTION_STATUS_DESCRIPTION"), Theme.Font.assist, Theme.Colors.muted)
    description:SetPoint("TOPLEFT", 12, -42)
    description:SetPoint("TOPRIGHT", -12, 0)
    description:SetHeight(34)

    local collected = context.createCheckbox(section, NS:L("SETTINGS_COLLECTION_STATUS_COLLECTED"))
    collected:SetPoint("TOPLEFT", 12, -82)
    collected.label:SetFontObject("GameFontNormalSmall")
    collected:SetChecked(settings.showCollected)

    local uncollected = context.createCheckbox(section, NS:L("SETTINGS_COLLECTION_STATUS_UNCOLLECTED"))
    uncollected:SetPoint("LEFT", collected, "RIGHT", 28, 0)
    uncollected.label:SetFontObject("GameFontNormalSmall")
    uncollected:SetChecked(settings.showUncollected)

    collected:SetScript("OnClick", function(control)
        settings.showCollected = control:GetCheckState() ~= "checked"
        control:SetChecked(settings.showCollected)
    end)
    uncollected:SetScript("OnClick", function(control)
        settings.showUncollected = control:GetCheckState() ~= "checked"
        control:SetChecked(settings.showUncollected)
    end)

    parent.yiboMountsSettings = parent.yiboMountsSettings or {}
    parent.yiboMountsSettings.section = section
    return 154
end

function Integration:Initialize()
    if self.initialized then return true end
    if not Core then
        WarnUnavailable()
        return nil, "core-unavailable"
    end
    if not (Core.CheckAPIVersion and Core:CheckAPIVersion(13)
        and Core.HasCapability and Core:HasCapability("localization", 1)
        and Core.IsInitialized and Core:IsInitialized()
        and Core.RegisterAddon and Core.RegisterSettingsPanel and Core.UITheme
        and Core.Locale and Core.Locale.Register and Core.Locale.Get) then
        WarnUnavailable()
        return nil, "core-api-incompatible"
    end

    Core.Locale:Register(NS.NAME, "zh", NS.Locale.zhCN)
    Core.Locale:Register(NS.NAME, "en", NS.Locale.enUS)
    self.localeAvailable = true

    local addon, addonError = Core:RegisterAddon(NS.NAME, { version = NS.VERSION, requiredAPI = 13 })
    if not addon then
        self.localeAvailable = false
        if type(Core.Print) == "function" then Core:Print(addonError) end
        return nil, addonError
    end
    local panel, panelError = Core:RegisterSettingsPanel(NS.NAME, {
        id = SETTINGS_ID,
        title = NS:L("SETTINGS_TITLE"),
        icon = "Interface\\AddOns\\YiboMounts\\Media\\YiboMountsIcon",
        CreateSettingsPanel = function(parent, context) return self:CreateSettingsPanel(parent, context) end,
    })
    if not panel then
        self.localeAvailable = false
        if type(Core.Print) == "function" then Core:Print(panelError) end
        return nil, panelError
    end
    self.initialized = true
    return true
end
