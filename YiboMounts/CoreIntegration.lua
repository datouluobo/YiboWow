local _, NS = ...

local Core = _G.YiboCore
local Integration = {}
NS.CoreIntegration = Integration

local SETTINGS_ID = "mounts"

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
    if not (Core and Core.CheckAPIVersion and Core.RegisterAddon and Core.RegisterSettingsPanel and Core.UITheme) then
        return nil, "YiboCore 设置 API 不可用。"
    end
    if not Core:CheckAPIVersion(5) then return nil, "需要 YiboCore API v5。" end

    local addon, addonError = Core:RegisterAddon(NS.NAME, { version = NS.VERSION, requiredAPI = 5 })
    if not addon then return nil, addonError end
    local panel, panelError = Core:RegisterSettingsPanel(NS.NAME, {
        id = SETTINGS_ID,
        title = "坐骑图鉴",
        icon = "Interface\\AddOns\\YiboMounts\\Media\\YiboMountsIcon-v1",
        CreateSettingsPanel = function(parent, context) return self:CreateSettingsPanel(parent, context) end,
    })
    if not panel then return nil, panelError end
    self.initialized = true
    return true
end
