local YQB = _G.YQB
if not (YQB and YQB.CoreCompatible) then return end
local Core = _G.YiboCore
local Theme = Core.UITheme

function YQB.CreateSettingsPanel(parent, context)
    local panel = parent.yqbSettings or CreateFrame("Frame", nil, parent)
    parent.yqbSettings = panel
    local width = parent:GetWidth()
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0); panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    panel:SetWidth(width); panel:Show()
    panel.controls = panel.controls or {}

    local y = 0
    local section = panel.modeSection or context.createSection(panel, YQB.T("SETTINGS.MODE"), width, 250)
    panel.modeSection = section
    section:SetWidth(width)
    section:ClearAllPoints(); section:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); section:Show()
    local options = YQB.GetProcessModeOptions()
    local modeControl = panel.modeControl or Theme:CreateDropdown(section, 188, options)
    panel.modeControl = modeControl; modeControl:ClearAllPoints(); modeControl:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -42)
    modeControl:SetOptions(options); modeControl:SetValue(YQB.GetProcessMode())
    modeControl:SetOnValueChanged(function(mode)
        YQB.SetProcessMode(mode)
        context.refreshPage()
    end)
    modeControl:Show()
    local note = section.note or context.createText(section, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    section.note = note; note:ClearAllPoints(); note:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -84); note:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, -84)
    note:SetWordWrap(true)
    note:SetText(YQB.T("SETTINGS.MODE_HELP"))
    note:Show()
    local modeHeight = math.max(112, 96 + note:GetStringHeight())
    section:SetHeight(modeHeight)
    y = y + modeHeight + Theme.Space.xs

    local adapterSection = panel.adapterSection or context.createSection(panel, YQB.T("SETTINGS.ADAPTER_STATUS"), width, 118)
    panel.adapterSection = adapterSection
    adapterSection:SetWidth(width)
    adapterSection:ClearAllPoints(); adapterSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); adapterSection:Show()
    local adapterText = adapterSection.text or context.createText(adapterSection, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    adapterSection.text = adapterText; adapterText:ClearAllPoints(); adapterText:SetPoint("TOPLEFT", 12, -38); adapterText:SetPoint("TOPRIGHT", -12, -38); adapterText:SetWordWrap(true)
    local lines = {}
    for _, adapter in ipairs(YQB.GetAutomationAdapters()) do
        if adapter.loaded then
            local status
            if adapter.continuationStatus == "incompatible" then
                status = YQB.T("SETTINGS.ADAPTER_INCOMPATIBLE")
            elseif adapter.continuationVerified then
                status = YQB.T("SETTINGS.ADAPTER_SUPPORTED")
            else
                status = YQB.T("SETTINGS.ADAPTER_UNVERIFIED")
            end
            lines[#lines + 1] = YQB.T("SETTINGS.ADAPTER_LINE", adapter.label, adapter.version and (" " .. adapter.version) or "", status)
        end
    end
    adapterText:SetText(#lines > 0 and table.concat(lines, "\n") or YQB.T("SETTINGS.NO_ADAPTERS"))
    adapterText:Show()
    local adapterHeight = math.max(66, 50 + adapterText:GetStringHeight())
    adapterSection:SetHeight(adapterHeight)
    y = y + adapterHeight + Theme.Space.xs
    panel:SetHeight(y)

    -- Diagnostics are retained as bounded support data, but clearing them is
    -- not a player-facing action: it neither fixes quest rules nor improves
    -- normal operation.  Keep this workbench focused on meaningful controls.
    return y
end
