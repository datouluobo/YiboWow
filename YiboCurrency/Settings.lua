local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Theme = Core.UITheme

local function FindCatalogItem(itemID)
    for _, entry in ipairs(Addon:GetCatalog()) do
        if tonumber(entry.itemID) == itemID then return entry end
    end
end

local RemoveOperation = {
    label = "删除自定义物品",
    Validate = function(info)
        if Addon:GetCustomItem(info.itemID) then return true end
        return false, FindCatalogItem(info.itemID) and "内置目录项目不能删除。" or "该物品不在自定义目录中。"
    end,
    Confirm = function(info)
        local entry = Addon:GetCustomItem(info.itemID)
        return string.format("确定从自定义货币目录删除“%s”（itemID: %s）吗？\n该项目的显示、监控和排序设置也会清除；背包物品保留。", entry.title, info.itemID)
    end,
    Execute = function(info)
        local entry, err = Addon:RemoveCustomItem(info.itemID)
        if not entry then return false, err end
        Addon:NotifyChanged()
        return true, "已从自定义目录删除：" .. entry.title
    end,
}

function Addon:ConfirmRemoveCustomItem(itemID, refreshPage, owner)
    if not (self.CoreIntegration and self.CoreIntegration.initialized) then
        self:Print("需要 YiboCore 1.6.1 或更新版本（API v7）。"); return
    end
    local info = { itemID = tonumber(itemID) }
    local ok, message = RemoveOperation.Validate(info)
    if not ok then self:Print(message); return end
    local request
    request = Core.ItemConfirmation:Show({ text = RemoveOperation.Confirm(info),
        IsCurrent = function() return (not owner or owner:IsVisible()) and Addon:GetCustomItem(info.itemID) ~= nil end,
        OnAccept = function()
            local valid, reason = RemoveOperation.Validate(info)
            if not valid then Addon:Print(reason); return end
            local saved, result = RemoveOperation.Execute(info)
            Addon:Print(result)
            if saved and refreshPage then refreshPage() end
        end })
    if owner then
        if owner.currencyItemConfirmation then owner.currencyItemConfirmation:Cancel() end
        owner.currencyItemConfirmation = request
        if not owner.currencyItemConfirmationHooked then
            owner.currencyItemConfirmationHooked = true
            owner:HookScript("OnHide", function(control)
                if control.currencyItemConfirmation then control.currencyItemConfirmation:Cancel(); control.currencyItemConfirmation = nil end
            end)
        end
    end
    return request
end
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
    local monitored = self:GetMonitoredCount(); local note = panel.note or Theme:CreateText(panel, Theme.Font.assist, Theme.Colors.muted, "LEFT"); panel.note = note; note:ClearAllPoints(); note:SetPoint("TOPLEFT", 0, -y); note:SetWidth(math.max(260, panel:GetWidth() - 8)); note:SetText(string.format("主窗口按固定目录展示；悬停使用独立的有序监控矩阵（当前 %d 项）。", monitored)); note:Show(); y = y + 36
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
        local rowEntry = entry
        -- Fill top-to-bottom before beginning the next column.  The catalog's
        -- fixed order then remains readable in each vertical scan.
        local localIndex = index - 1; local column = math.floor(localIndex / rowsPerColumn); local line = localIndex % rowsPerColumn
        local x = column * (columnWidth + columnGap); local rowY = catalogTop + line * rowHeight
        local row=panel.rows[index] or CreateFrame("Button",nil,panel); panel.rows[index]=row; row:SetSize(columnWidth,rowHeight); row:ClearAllPoints(); row:SetPoint("TOPLEFT",panel,"TOPLEFT",x,-rowY); row:RegisterForClicks("RightButtonUp")
        row:SetScript("OnClick", nil)
        row.label=row.label or Theme:CreateText(row,Theme.Font.assist,Theme.Colors.text,"LEFT"); row.label:ClearAllPoints(); row.label:SetPoint("LEFT",row,"LEFT",0,0); row.label:SetWidth(labelWidth); row.label:SetWordWrap(false); row.label:SetText(CatalogLabel(entry)); row.label:Show()
        row.visible=row.visible or Theme:CreateCheckbox(row,"主窗口显示"); row.visible:ClearAllPoints(); row.visible:SetSize(104,rowHeight); row.visible:SetPoint("LEFT",row.label,"RIGHT",8,0); row.visible.label:SetText("主窗口显示"); row.visible:SetChecked(self:IsVisible(entry)); row.visible:SetScript("OnClick",function(control) local wanted=not self:IsVisible(entry); self:SetVisible(entry,wanted); control:SetChecked(wanted); context.notifyPageChanged(); context.refreshPage() end); row.visible:Show()
        row.monitor=row.monitor or Theme:CreateCheckbox(row,"悬停监控"); row.monitor:ClearAllPoints(); row.monitor:SetSize(108,rowHeight); row.monitor:SetPoint("LEFT",row.visible,"RIGHT",8,0); row.monitor.label:SetText("悬停监控"); local active=self:IsMonitored(entry); row.monitor:SetChecked(active); row.monitor:SetEnabled(true); row.monitor:SetAlpha(1); row.monitor:SetScript("OnClick",function(control) local wanted=not self:IsMonitored(entry); local ok,err=self:SetMonitored(entry,wanted); if not ok then Addon:Print(err); control:SetChecked(false); return end; control:SetChecked(wanted); context.notifyPageChanged(); context.refreshPage() end); row.monitor:Show()
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
        local orderColumnGap = Theme.Space.md
        local orderColumnWidth = orderLabelWidth + Theme.Space.xs + 60
        local orderColumnCount = math.max(1, math.floor((availableWidth + orderColumnGap) / (orderColumnWidth + orderColumnGap)))
        local orderRowsPerColumn = math.ceil(#ordered / orderColumnCount)
        for index,entry in ipairs(ordered) do
            local orderLabel = index .. ". " .. entry.title
            local localIndex = index - 1
            local column = math.floor(localIndex / orderRowsPerColumn)
            local line = localIndex % orderRowsPerColumn
            local row=panel.orderRows[index] or CreateFrame("Frame",nil,panel); panel.orderRows[index]=row; row:SetSize(orderColumnWidth,rowHeight); row:ClearAllPoints(); row:SetPoint("TOPLEFT",panel,"TOPLEFT",column*(orderColumnWidth+orderColumnGap),-(y+line*rowHeight))
            row.label=row.label or Theme:CreateText(row,Theme.Font.assist,Theme.Colors.text,"LEFT"); row.label:ClearAllPoints(); row.label:SetPoint("LEFT",row,"LEFT",0,0); row.label:SetWidth(orderLabelWidth); row.label:SetWordWrap(false); row.label:SetText(orderLabel); row.label:Show()
            row.up=row.up or Theme:CreateButton(row,26,"↑","secondary"); row.up:ClearAllPoints(); row.up:SetSize(26,rowHeight); row.up:SetPoint("LEFT",row.label,"RIGHT",Theme.Space.xs,0); row.up:SetEnabled(index>1); row.up:SetScript("OnClick",function() self:MoveMonitored(entry.id,-1); context.notifyPageChanged(); context.refreshPage() end); row.up:Show()
            row.down=row.down or Theme:CreateButton(row,26,"↓","secondary"); row.down:ClearAllPoints(); row.down:SetSize(26,rowHeight); row.down:SetPoint("LEFT",row.up,"RIGHT",4,0); row.down:SetEnabled(index<#ordered); row.down:SetScript("OnClick",function() self:MoveMonitored(entry.id,1); context.notifyPageChanged(); context.refreshPage() end); row.down:Show(); row:Show()
        end
        y = y + orderRowsPerColumn * rowHeight
    end
    for index=#ordered+1,#panel.orderRows do panel.orderRows[index]:Hide() end
    y=y+8; Label(panel,"custom","数据与缓存 · 自定义物品代币",y); y=y+24
    local picker = panel.itemPicker
    if not picker then
        picker = Core:CreateItemPicker(panel, {
            resolve = { allowID = true, allowLink = true, allowName = true, match = "exact", includeBags = true,
                candidates = function() return Addon:GetCatalog() end },
            enterAction = "add", dropMode = "toggle",
            Exists = function(info) return FindCatalogItem(info.itemID) ~= nil end,
            add = {
                Validate = function(info)
                    if FindCatalogItem(info.itemID) then return false, "该物品已在货币目录中。" end
                    return true
                end,
                Confirm = function(info) return string.format("将 %s（itemID: %s）加入自定义货币目录？", info.name, info.itemID) end,
                Execute = function(info)
                    local entry, err = Addon:AddCustomItem(info.itemID)
                    if not entry then return false, err end
                    Addon:NotifyChanged()
                    return true, "已加入自定义目录：" .. entry.title
                end,
            },
            remove = RemoveOperation,
        })
        panel.itemPicker = picker
    end
    picker.config.OnSuccess = function() context.notifyPageChanged(); context.refreshPage() end
    picker.config.OnLayoutChanged = context.refreshPanel or context.refreshPage
    picker:ClearAllPoints(); picker:SetPoint("TOPLEFT", 0, -y); picker:Show()
    y = y + picker:Layout(panel:GetWidth())
    panel:SetHeight(y); return y
end
