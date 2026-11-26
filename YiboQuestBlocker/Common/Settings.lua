local YQB = _G.YQB
if not (_G.YiboCore and _G.YiboCore.UITheme) then return end
local Core = _G.YiboCore
local Theme = Core.UITheme

YQB.ProcessingOptions = {
    { key = "autoReject", label = "SETTINGS.AUTO_REJECT" },
    { key = "autoAbandon", label = "SETTINGS.AUTO_ABANDON" },
    { key = "paused", label = "SETTINGS.PAUSE" },
}

function YQB.CreateProcessingCheckboxes(parent, refresh)
    local controls = {}
    for index, option in ipairs(YQB.ProcessingOptions) do
        local key = option.key
        local control = Theme:CreateCheckbox(parent, YQB.T(option.label))
        control:SetScript("OnClick", function(self)
            local enabled = not self:GetChecked()
            self:SetChecked(enabled)
            YQB.SetProcessingOption(key, enabled)
            refresh()
        end)
        controls[index] = control
    end
    return controls
end

function YQB.RefreshProcessingCheckboxes(controls)
    local runtime = YQB.GetRuntimeSettings()
    for index, option in ipairs(YQB.ProcessingOptions) do
        controls[index]:SetChecked(runtime[option.key] == true)
    end
end

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
    panel.refreshProcessing = context.refreshPage
    panel.processingChecks = panel.processingChecks or YQB.CreateProcessingCheckboxes(section, function()
        panel.refreshProcessing()
    end)
    YQB.RefreshProcessingCheckboxes(panel.processingChecks)
    local reportChat = panel.reportChat or Theme:CreateCheckbox(section, YQB.T("SETTINGS.REPORT_CHAT"))
    panel.reportChat = reportChat
    reportChat:SetChecked(YQB.IsChatReportingEnabled())
    reportChat:SetScript("OnClick", function(control)
        control:SetChecked(not control:GetChecked())
        YQB.GetDatabase().filters.reportChat = control:GetChecked()
        YQB.PersistDB()
    end)
    reportChat:Show()
    local innerWidth = width - 28
    local columnWidth = (innerWidth - Theme.Space.sm) / 2
    local columns = 2
    for _, option in ipairs(YQB.ProcessingOptions) do
        if Theme:MeasureText(Theme.Font.body, YQB.T(option.label)) + 26 > columnWidth then columns = 1; break end
    end
    if Theme:MeasureText(Theme.Font.body, YQB.T("SETTINGS.REPORT_CHAT")) + 26 > columnWidth then columns = 1 end
    local rowHeight = Theme.Size.standard + Theme.Space.xxs
    local controls = { panel.processingChecks[1], panel.processingChecks[2], panel.processingChecks[3], reportChat }
    for index, control in ipairs(controls) do
        local row, column = math.floor((index - 1) / columns), (index - 1) % columns
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", section, "TOPLEFT", 14 + column * (columnWidth + Theme.Space.sm), -42 - row * rowHeight)
        control:SetWidth(columns == 2 and columnWidth or innerWidth)
    end
    local noteTop = 42 + math.ceil(#controls / columns) * rowHeight + Theme.Space.xs
    local note = section.note or context.createText(section, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    section.note = note; note:ClearAllPoints(); note:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -noteTop); note:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, -noteTop)
    note:SetWordWrap(true)
    note:SetText(YQB.T(YQB.Target.modeHelp or "SETTINGS.MODE_HELP"))
    note:Show()
    local modeHeight = noteTop + note:GetStringHeight() + Theme.Space.sm
    section:SetHeight(modeHeight)
    y = y + modeHeight + Theme.Space.xs
    if not YQB.GetAutomationAdapters then
        panel:SetHeight(y)
        return y
    end

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
