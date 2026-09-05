local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Theme = Core.UITheme

StaticPopupDialogs["YIBO_CURRENCY_CONFIRM_ITEM"] = {
    text = "将 %s（itemID: %s）加入自定义货币目录？", button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) local entry, err = Addon:AddCustomItem(data.itemID); if entry then Addon:Print("已加入自定义货币：" .. entry.title); Addon:NotifyChanged() else Addon:Print(err) end end,
}
local function Label(parent, key, text, y, color)
    parent.ycuLabels = parent.ycuLabels or {}
    local control = parent.ycuLabels[key] or Theme:CreateText(parent, Theme.Font.body, color or Theme.Colors.accent, "LEFT")
    parent.ycuLabels[key] = control; control:ClearAllPoints(); control:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y); control:SetText(text); control:Show()
    return control
end
local function CatalogLabel(entry)
    return "|T" .. tostring(Addon:GetIcon(entry)) .. ":16:16:0:0|t " .. entry.title
end

function Addon:CreateSettingsPanel(parent, context)
    local panel = parent.ycuSettings or CreateFrame("Frame", nil, parent); parent.ycuSettings = panel; panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", parent, "TOPLEFT"); panel:SetWidth(parent:GetWidth()); panel:Show(); panel.rows = panel.rows or {}
    local settings, catalog, y = self:GetSettings(), self:GetCatalog(), 0
    local rowHeight = Theme.Size.compact
    Label(panel, "display", "显示与悬停监控", y); y = y + 24
    local monitored = self:GetMonitoredCount(); local note = panel.note or Theme:CreateText(panel, Theme.Font.assist, Theme.Colors.muted, "LEFT"); panel.note = note; note:ClearAllPoints(); note:SetPoint("TOPLEFT", 0, -y); note:SetWidth(math.max(260, panel:GetWidth() - 8)); note:SetText(string.format("主窗口按固定目录展示；悬停使用独立的有序监控矩阵（%d / 16）。达到上限后，其它开关会禁用。", monitored)); note:Show(); y = y + 36
    local restore = panel.restore or Theme:CreateButton(panel, 132, "恢复全部显示", "secondary"); panel.restore=restore; restore:ClearAllPoints(); restore:SetPoint("TOPLEFT",0,-y); restore:SetScript("OnClick",function() settings.visible={}; context.notifyPageChanged(); context.refreshPage() end); restore:Show()
    local reset = panel.reset or Theme:CreateButton(panel, 154, "恢复跟随全局顺序", "secondary"); panel.reset=reset; reset:ClearAllPoints(); reset:SetPoint("LEFT",restore,"RIGHT",8,0); reset:SetScript("OnClick",function() self:ResetHoverOrder(); context.notifyPageChanged(); context.refreshPage() end); reset:Show(); y=y+38
    Label(panel, "catalog", "货币目录", y); y=y+24
    local availableWidth = math.max(1, panel:GetWidth() or 1)
    -- Each complete currency name and its switches form one semantic group.
    -- Measure the longest actual label instead of reserving a generic 500px
    -- row, which prevents both overlap and the large unused middle column.
    local labelWidth = Theme:MeasureText(Theme.Font.assist, "货币")
    for _, entry in ipairs(catalog) do labelWidth = math.max(labelWidth, 16 + Theme.Space.xs + Theme:MeasureText(Theme.Font.assist, entry.title)) end
    local columnGap = Theme.Space.xl * 2
    local groupWidth = labelWidth + Theme.Space.xs + 104 + Theme.Space.xs + 108
    local columnCount = availableWidth >= groupWidth * 2 + columnGap and 2 or 1
    local columnWidth = groupWidth
    local catalogTop = y
    local rowsPerColumn = math.ceil(#catalog / columnCount)
    for index,entry in ipairs(catalog) do
        -- Fill top-to-bottom before beginning the next column.  The catalog's
        -- fixed order then remains readable in each vertical scan.
        local localIndex = index - 1; local column = math.floor(localIndex / rowsPerColumn); local line = localIndex % rowsPerColumn
        local x = column * (columnWidth + columnGap); local rowY = catalogTop + line * rowHeight
        local row=panel.rows[index] or CreateFrame("Frame",nil,panel); panel.rows[index]=row; row:SetSize(columnWidth,rowHeight); row:ClearAllPoints(); row:SetPoint("TOPLEFT",panel,"TOPLEFT",x,-rowY)
        row.label=row.label or Theme:CreateText(row,Theme.Font.assist,Theme.Colors.text,"LEFT"); row.label:ClearAllPoints(); row.label:SetPoint("LEFT",row,"LEFT",0,0); row.label:SetWidth(labelWidth); row.label:SetWordWrap(false); row.label:SetText(CatalogLabel(entry)); row.label:Show()
        row.visible=row.visible or Theme:CreateCheckbox(row,"主窗口显示"); row.visible:ClearAllPoints(); row.visible:SetSize(104,rowHeight); row.visible:SetPoint("LEFT",row.label,"RIGHT",8,0); row.visible.label:SetText("主窗口显示"); row.visible:SetChecked(self:IsVisible(entry)); row.visible:SetScript("OnClick",function(control) local wanted=not self:IsVisible(entry); self:SetVisible(entry,wanted); control:SetChecked(wanted); context.notifyPageChanged(); context.refreshPage() end); row.visible:Show()
        row.monitor=row.monitor or Theme:CreateCheckbox(row,"悬停监控"); row.monitor:ClearAllPoints(); row.monitor:SetSize(108,rowHeight); row.monitor:SetPoint("LEFT",row.visible,"RIGHT",8,0); row.monitor.label:SetText("悬停监控"); local active=self:IsMonitored(entry); row.monitor:SetChecked(active); local disabled=not active and monitored>=16; row.monitor:SetEnabled(not disabled); row.monitor:SetAlpha(disabled and .45 or 1); row.monitor:SetScript("OnClick",function(control) local wanted=not self:IsMonitored(entry); local ok,err=self:SetMonitored(entry,wanted); if not ok then Addon:Print(err); control:SetChecked(false); return end; control:SetChecked(wanted); context.notifyPageChanged(); context.refreshPage() end); row.monitor:Show()
        row:Show()
    end
    for index=#catalog+1,#panel.rows do panel.rows[index]:Hide() end
    y = catalogTop + math.ceil(#catalog / columnCount) * rowHeight + Theme.Space.sm; Label(panel,"order","监控排序（只显示已监控货币）",y); y=y+24
    local ordered = self:GetMonitoredCatalog(); panel.orderRows = panel.orderRows or {}
    if #ordered == 0 then
        local empty = panel.orderEmpty or Theme:CreateText(panel,Theme.Font.assist,Theme.Colors.muted,"LEFT"); panel.orderEmpty=empty; empty:ClearAllPoints(); empty:SetPoint("TOPLEFT",0,-y); empty:SetText("尚未选择悬停监控货币。"); empty:Show(); y=y+26
    else
        if panel.orderEmpty then panel.orderEmpty:Hide() end
        local orderLabelWidth = Theme:MeasureText(Theme.Font.assist, "1. 货币")
        for index, entry in ipairs(ordered) do orderLabelWidth = math.max(orderLabelWidth, Theme:MeasureText(Theme.Font.assist, index .. ". " .. entry.title)) end
        for index,entry in ipairs(ordered) do
            local orderLabel = index .. ". " .. entry.title
            local row=panel.orderRows[index] or CreateFrame("Frame",nil,panel); panel.orderRows[index]=row; row:SetSize(orderLabelWidth + Theme.Space.xs + 60,rowHeight); row:ClearAllPoints(); row:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-y)
            row.label=row.label or Theme:CreateText(row,Theme.Font.assist,Theme.Colors.text,"LEFT"); row.label:ClearAllPoints(); row.label:SetPoint("LEFT",row,"LEFT",0,0); row.label:SetWidth(orderLabelWidth); row.label:SetWordWrap(false); row.label:SetText(orderLabel); row.label:Show()
            row.up=row.up or Theme:CreateButton(row,26,"↑","secondary"); row.up:ClearAllPoints(); row.up:SetSize(26,rowHeight); row.up:SetPoint("LEFT",row.label,"RIGHT",Theme.Space.xs,0); row.up:SetEnabled(index>1); row.up:SetScript("OnClick",function() self:MoveMonitored(entry.id,-1); context.notifyPageChanged(); context.refreshPage() end); row.up:Show()
            row.down=row.down or Theme:CreateButton(row,26,"↓","secondary"); row.down:ClearAllPoints(); row.down:SetSize(26,rowHeight); row.down:SetPoint("LEFT",row.up,"RIGHT",4,0); row.down:SetEnabled(index<#ordered); row.down:SetScript("OnClick",function() self:MoveMonitored(entry.id,1); context.notifyPageChanged(); context.refreshPage() end); row.down:Show(); row:Show(); y=y+rowHeight
        end
    end
    for index=#ordered+1,#panel.orderRows do panel.orderRows[index]:Hide() end
    y=y+8; Label(panel,"custom","自定义物品代币",y); y=y+24
    local input=panel.customInput or CreateFrame("EditBox",nil,panel,"BackdropTemplate"); panel.customInput=input; input:SetSize(164,Theme.Size.standard); input:SetAutoFocus(false); input:SetFont(STANDARD_TEXT_FONT,Theme.Font.body,""); input:SetTextInsets(8,8,0,0); input:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1}); input:SetBackdropColor(Theme.Colors.bg[1],Theme.Colors.bg[2],Theme.Colors.bg[3],1); input:SetBackdropBorderColor(Theme.Colors.lineSoft[1],Theme.Colors.lineSoft[2],Theme.Colors.lineSoft[3],1); input:ClearAllPoints(); input:SetPoint("TOPLEFT",0,-y)
    local add=panel.customAdd or Theme:CreateButton(panel,112,"添加 itemID","secondary"); panel.customAdd=add; add:ClearAllPoints(); add:SetPoint("LEFT",input,"RIGHT",8,0); add:SetScript("OnClick",function() local itemID=tonumber(input:GetText() or ""); local name=itemID and GetItemInfo(itemID); if not itemID then Addon:Print("请输入有效的 itemID。") elseif not name then Addon:Print("客户端尚未缓存该物品；请先在游戏内查看该物品后重试。") else StaticPopup_Show("YIBO_CURRENCY_CONFIRM_ITEM",name,itemID,{itemID=itemID}) end end); add:Show(); y=y+38
    panel:SetHeight(y); return y
end
