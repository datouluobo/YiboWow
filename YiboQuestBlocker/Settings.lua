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
    panel:SetWidth(width); panel:SetHeight(388); panel:Show()
    panel.controls = panel.controls or {}

    local y = 0
    local section = context.createSection(panel, "处理模式", width, 250)
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
    note:SetText("拒绝模式（推荐）：在选择与接取阶段跳过或拒绝已屏蔽任务；若任务异常进入日志，会在交互结束后安全放弃。\n\n放弃模式（旧版兼容）：不干预选择与接取；已屏蔽任务进入日志后，在任务交互结束时自动放弃。\n\n暂停模式：不拦截、不自动放弃，也不能使用手动放弃；规则和矩阵继续保留，切回任一处理模式即可恢复。")
    note:Show()
    y = y + 260

    local adapterSection = context.createSection(panel, "适配状态", width, 118)
    adapterSection:ClearAllPoints(); adapterSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); adapterSection:Show()
    local adapterText = adapterSection.text or context.createText(adapterSection, Theme.Font.assist, Theme.Colors.muted, "LEFT")
    adapterSection.text = adapterText; adapterText:ClearAllPoints(); adapterText:SetPoint("TOPLEFT", 12, -38); adapterText:SetPoint("TOPRIGHT", -12, -38); adapterText:SetWordWrap(true)
    local lines = {}
    for _, adapter in ipairs(YQB.GetAutomationAdapters()) do
        if adapter.loaded then
            local status
            if adapter.continuationStatus == "incompatible" then
                status = "不兼容，请关闭自动接任务功能"
            elseif adapter.continuationVerified then
                status = "支持自动接任务"
            else
                status = "仅直接拒绝，续办待实机验证"
            end
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
