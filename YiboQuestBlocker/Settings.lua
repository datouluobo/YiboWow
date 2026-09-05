local YQB = _G.YQB
local Core = _G.YiboCore
local Theme = Core.UITheme

function YQB.CreateSettingsPanel(parent, context)
    local panel = parent.yqbSettings or CreateFrame("Frame", nil, parent)
    parent.yqbSettings = panel
    -- The settings host can report zero width during its first layout pass.
    -- Anchor both sides and retain a safe width/height until Core has finished
    -- calculating its scroll child, otherwise every hosted section is drawn at
    -- zero size and the business page looks empty.
    local width = math.max(560, parent:GetWidth() or 0)
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0); panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    panel:SetWidth(width); panel:SetHeight(332); panel:Show()
    panel.controls = panel.controls or {}

    local runtime = YQB.GetRuntimeSettings()
    local y = 0
    local section = context.createSection(panel, "业务设置", width, 194)
    section:ClearAllPoints(); section:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); section:Show()
    local note = section.note or context.createText(section, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    section.note = note; note:ClearAllPoints(); note:SetPoint("TOPLEFT", 12, -38); note:SetPoint("TOPRIGHT", -12, -38)
    note:SetWordWrap(true); note:SetText("直接拒绝是最终防线。自动续办仅对已验证适配器开放；未知或版本待验证的自动接任务插件会安全停在直接拒绝，不替其选择任务。"); note:Show()

    local definitions = {
        { key = "directReject", label = "直接拒绝已屏蔽任务" },
        { key = "continueKnownAutomation", label = "与已验证自动接任务插件续办" },
        { key = "continueUnknownAutomation", label = "未验证插件续办（不建议）" },
        { key = "grayNPCList", label = "NPC 列表灰显已屏蔽任务" },
    }
    for index, definition in ipairs(definitions) do
        local control = panel.controls[index] or context.createCheckbox(section, definition.label)
        panel.controls[index] = control
        control:ClearAllPoints()
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        control:SetPoint("TOPLEFT", section, "TOPLEFT", 14 + column * 280, -88 - row * 34)
        control.label:SetText(definition.label); control:SetChecked(runtime[definition.key])
        control:SetScript("OnClick", function(self)
            self:SetChecked(not self:GetChecked())
            YQB.SetRuntimeSetting(definition.key, self:GetChecked())
            context.notifyPageChanged()
        end)
        control:Show()
    end
    y = y + 204

    local adapterSection = context.createSection(panel, "适配状态", width, 118)
    adapterSection:ClearAllPoints(); adapterSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); adapterSection:Show()
    local adapterText = adapterSection.text or context.createText(adapterSection, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    adapterSection.text = adapterText; adapterText:ClearAllPoints(); adapterText:SetPoint("TOPLEFT", 12, -38); adapterText:SetPoint("TOPRIGHT", -12, -38); adapterText:SetWordWrap(true)
    local lines = {}
    for _, adapter in ipairs(YQB.GetAutomationAdapters()) do
        if adapter.loaded then
            local status = adapter.continuationVerified and "已验证列表过滤" or "仅直接拒绝，续办待实机验证"
            lines[#lines + 1] = string.format("%s%s：%s", adapter.label, adapter.version and (" " .. adapter.version) or "", status)
        end
    end
    adapterText:SetText(#lines > 0 and table.concat(lines, "\n") or "未检测到已加载的已知自动接任务插件。未知插件同样只启用直接拒绝。")
    adapterText:Show()
    y = y + 128

    -- Diagnostics are retained as bounded support data, but clearing them is
    -- not a player-facing action: it neither fixes quest rules nor improves
    -- normal operation.  Keep this workbench focused on meaningful controls.
    return y
end
