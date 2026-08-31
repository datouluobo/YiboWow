local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Theme = Core.UITheme

StaticPopupDialogs["YIBO_CURRENCY_CONFIRM_ITEM"] = {
    text = "将 %s（itemID: %s）加入自定义货币目录？",
    button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data)
        local entry, err = Addon:AddCustomItem(data.itemID)
        if not entry then Addon:Print(err) else Addon:Print("已加入自定义货币：" .. entry.title); Addon:NotifyChanged() end
    end,
}

function Addon:CreateSettingsPanel(parent, context)
    local panel = parent.ycuSettings or CreateFrame("Frame", nil, parent); parent.ycuSettings = panel
    panel.yiboSettingsOwner = "currency"
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", parent, "TOPLEFT"); panel:SetWidth(parent:GetWidth()); panel:Show(); panel.rows = panel.rows or {}
    local y, settings = 0, self:GetSettings()
    local heading = panel.heading or Theme:CreateText(panel, Theme.Font.body, Theme.Colors.accent, "LEFT"); panel.heading = heading; heading:ClearAllPoints(); heading:SetPoint("TOPLEFT", 0, -y); heading:SetText("货币显示"); heading:Show(); y = y + 26
    local note = panel.note or Theme:CreateText(panel, Theme.Font.assist, Theme.Colors.muted, "LEFT"); panel.note = note; note:ClearAllPoints(); note:SetPoint("TOPLEFT", 0, -y); note:SetText("关闭“主窗口”会隐藏该货币；悬停监控只决定 Broker/小地图预览是否显示它。"); note:Show(); y = y + 34
    local restore = panel.restore or Theme:CreateButton(panel, 156, "恢复全部显示", "secondary"); panel.restore = restore; restore:ClearAllPoints(); restore:SetPoint("TOPLEFT", 0, -y); restore:SetScript("OnClick", function() settings.visible = {}; context.notifyPageChanged(); context.refreshPage() end); restore:Show(); y = y + 38
    local customTitle = panel.customTitle or Theme:CreateText(panel, Theme.Font.body, Theme.Colors.accent, "LEFT"); panel.customTitle = customTitle; customTitle:ClearAllPoints(); customTitle:SetPoint("TOPLEFT", 0, -y); customTitle:SetText("自定义物品代币"); customTitle:Show(); y = y + 26
    local input = panel.customInput or CreateFrame("EditBox", nil, panel, "BackdropTemplate"); panel.customInput = input; input:SetSize(164, Theme.Size.standard); input:SetAutoFocus(false); input:SetFont(STANDARD_TEXT_FONT, Theme.Font.body, ""); input:SetTextInsets(8, 8, 0, 0); input:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 }); input:SetBackdropColor(Theme.Colors.bg[1], Theme.Colors.bg[2], Theme.Colors.bg[3], 1); input:SetBackdropBorderColor(Theme.Colors.lineSoft[1], Theme.Colors.lineSoft[2], Theme.Colors.lineSoft[3], 1); input:ClearAllPoints(); input:SetPoint("TOPLEFT", 0, -y); input:SetText(input:GetText() or "")
    local add = panel.customAdd or Theme:CreateButton(panel, 112, "添加 itemID", "secondary"); panel.customAdd = add; add:ClearAllPoints(); add:SetPoint("LEFT", input, "RIGHT", 8, 0); add:SetScript("OnClick", function()
        local itemID = tonumber(input:GetText() or ""); local name = itemID and GetItemInfo(itemID)
        if not itemID then Addon:Print("请输入有效的 itemID。")
        elseif not name then Addon:Print("客户端尚未缓存该物品；请先在游戏内查看该物品后重试。")
        else StaticPopup_Show("YIBO_CURRENCY_CONFIRM_ITEM", name, itemID, { itemID = itemID }) end
    end); add:Show(); y = y + 38
    local title = panel.title or Theme:CreateText(panel, Theme.Font.body, Theme.Colors.accent, "LEFT"); panel.title = title; title:ClearAllPoints(); title:SetPoint("TOPLEFT", 0, -y); title:SetText("显示与悬停监控"); title:Show(); y = y + 26
    for index, entry in ipairs(self:GetCatalog()) do
        local row = panel.rows[index] or CreateFrame("Frame", nil, panel); panel.rows[index] = row; row:SetSize(560, 28); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y)
        row.label = row.label or Theme:CreateText(row, Theme.Font.assist, Theme.Colors.text, "LEFT"); row.label:SetPoint("LEFT", 0, 0); row.label:SetWidth(250); row.label:SetText(entry.title)
        row.visible = row.visible or Theme:CreateCheckbox(row, "主窗口显示"); row.visible:ClearAllPoints(); row.visible:SetPoint("LEFT", 258, 0); row.visible.label:SetText("主窗口显示"); row.visible:SetChecked(self:IsVisible(entry)); row.visible:SetScript("OnClick", function(control) control:SetChecked(not control:GetChecked()); self:SetVisible(entry, control:GetChecked()); context.notifyPageChanged() end)
        row.monitor = row.monitor or Theme:CreateCheckbox(row, "悬停监控"); row.monitor:ClearAllPoints(); row.monitor:SetPoint("LEFT", 390, 0); row.monitor.label:SetText("悬停监控"); row.monitor:SetChecked(self:IsMonitored(entry)); row.monitor:SetScript("OnClick", function(control) control:SetChecked(not control:GetChecked()); self:SetMonitored(entry, control:GetChecked()); context.notifyPageChanged() end); row:Show(); y = y + 28
    end
    for index = #self:GetCatalog() + 1, #panel.rows do panel.rows[index]:Hide() end
    panel:SetHeight(y + 4); return y + 4
end
