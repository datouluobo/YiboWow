local Addon = _G.YiboAutoOpen
local Settings = {}; Addon.Settings = Settings
local function Text(parent, size, color) return _G.YiboCore.UITheme:CreateText(parent, size, color, "LEFT") end
local DELETE_POPUP = "YIBOAUTOOPEN_DELETE_CATALOG_ITEM"
local DELETE_CONFIRM_SOURCE_POPUP = "YIBOAUTOOPEN_DELETE_CONFIRM_SOURCE"
StaticPopupDialogs[DELETE_POPUP] = {
    text = "确定从自动开包目录删除“%s”吗？\n这不会删除背包中的物品。",
    button1 = "删除", button2 = "取消", timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) Addon.Database:RemoveItem(data); Addon:Refresh(); if Addon.Settings.panel and Addon.Settings.panel.host then Addon.Settings.panel.host.refreshPage() end end,
}
StaticPopupDialogs[DELETE_CONFIRM_SOURCE_POPUP] = {
    text = "确定从确认框来源白名单删除“%s”吗？\n删除后该来源的确认框将保留游戏原生位置。",
    button1 = "删除", button2 = "取消", timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data)
        Addon.Database:RemoveConfirmSource(data)
        if Addon.Settings.panel and Addon.Settings.panel.host then Addon.Settings.panel.host.refreshPage() end
    end,
}
function Settings:CreatePanel(parent, host)
    -- Core can render this settings-only panel immediately after addon files
    -- load, before our ADDON_LOADED handler initializes SavedVariables.
    Addon.Database:EnsureInitialized()
    local theme, colors = _G.YiboCore.UITheme, _G.YiboCore.UITheme.Colors
    local panel = parent.autoOpenSettingsPanel
    if not panel then
        panel = CreateFrame("Frame", nil, parent); parent.autoOpenSettingsPanel = panel; panel:SetPoint("TOPLEFT"); panel:SetPoint("TOPRIGHT"); panel.checks, panel.rows = {}, {}
        panel.status = Text(panel, theme.Font.meta, colors.muted); panel.status:SetPoint("TOPLEFT", 12, -8)
        panel.spaceLabel = Text(panel, theme.Font.meta, colors.muted)
        panel.space = CreateFrame("EditBox", nil, panel, "InputBoxTemplate"); panel.space:SetSize(64, 22); panel.space:SetAutoFocus(false)
        panel.mode = theme:CreateDropdown(panel, 160, { { value="silent", label="静默" }, { value="issues", label="仅问题" }, { value="verbose", label="详细" } })
        panel.retry = theme:CreateButton(panel, 96, "重新尝试", "secondary")
        panel.add = CreateFrame("EditBox", nil, panel, "InputBoxTemplate"); panel.add:SetSize(300, 22); panel.add:SetAutoFocus(false)
        panel.addButton = theme:CreateButton(panel, 60, "添加")
        panel.drop = theme:CreateButton(panel, 180, "拖放背包物品到这里", "secondary"); panel.drop:RegisterForDrag("LeftButton")
        panel.message = Text(panel, theme.Font.meta, colors.muted)
        panel.catalog = Text(panel, theme.Font.meta, colors.muted)
        panel.confirmHeader = Text(panel, theme.Font.meta, colors.text)
        panel.confirmSourceHeader = Text(panel, theme.Font.meta, colors.text)
        panel.confirmSourceInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate"); panel.confirmSourceInput:SetSize(300, 22); panel.confirmSourceInput:SetAutoFocus(false)
        panel.confirmSourceAddButton = theme:CreateButton(panel, 60, "添加")
        panel.confirmSourceRows = {}
        panel.recentSourceHeader = Text(panel, theme.Font.meta, colors.text)
        panel.recentSourceRows = {}
        panel.refresh = theme:CreateButton(panel, 80, "刷新", "secondary")
        panel.checks[1] = host.createCheckbox(panel, "启用自动开包"); panel.checks[1]:SetWidth(200)
        panel.checks[2] = host.createCheckbox(panel, "登录时扫描已有包裹"); panel.checks[2]:SetWidth(260)
        panel.checks[3] = host.createCheckbox(panel, "允许白名单确认框跟随鼠标"); panel.checks[3]:SetWidth(300)
        panel.itemInfoEvents = CreateFrame("Frame")
        panel.itemInfoEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        panel.itemInfoEvents:SetScript("OnEvent", function(_, _, itemID, success)
            if success == false or not (Addon.db and Addon.db.catalog and Addon.db.catalog.entries[tonumber(itemID)]) or not panel:IsShown() then return end
            panel.itemInfoRefreshToken = (panel.itemInfoRefreshToken or 0) + 1
            local token = panel.itemInfoRefreshToken
            local function RefreshNames()
                if token == panel.itemInfoRefreshToken and panel.host then panel.host.refreshPage() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0.1, RefreshNames) else RefreshNames() end
        end)
        if host.bindTooltip then host.bindTooltip(panel.refresh, "刷新目录", { "重新请求目录物品名称。", "同时清除本次登录的失败隔离并重新扫描背包。" }) end
    end
    panel.host = host; self.panel = panel; panel:Show()
    local availableWidth = math.max(parent:GetWidth() or 0, panel:GetWidth() or 0)
    local compact = availableWidth >= 1100
    local medium = availableWidth >= 700
    local function Anchor(frame, point, relativeTo, relativePoint, x, y)
        frame:ClearAllPoints(); frame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
    if compact then
        Anchor(panel.checks[1], "TOPLEFT", panel, "TOPLEFT", 12, -34)
        Anchor(panel.checks[2], "TOPLEFT", panel, "TOPLEFT", 220, -34)
        Anchor(panel.confirmHeader, "TOPLEFT", panel, "TOPLEFT", 12, -62)
        Anchor(panel.checks[3], "TOPLEFT", panel, "TOPLEFT", 12, -82)
        Anchor(panel.spaceLabel, "TOPLEFT", panel, "TOPLEFT", 12, -110)
        Anchor(panel.space, "LEFT", panel.spaceLabel, "RIGHT", 8, 0)
        Anchor(panel.mode, "TOPLEFT", panel, "TOPLEFT", 250, -100)
        Anchor(panel.retry, "LEFT", panel.mode, "RIGHT", 10, 0)
        Anchor(panel.add, "TOPLEFT", panel, "TOPLEFT", 540, -110); panel.add:SetWidth(238)
        Anchor(panel.addButton, "LEFT", panel.add, "RIGHT", 8, 0)
        Anchor(panel.drop, "LEFT", panel.addButton, "RIGHT", 8, 0); panel.drop:SetWidth(230)
        Anchor(panel.message, "TOPLEFT", panel, "TOPLEFT", 12, -140)
        Anchor(panel.catalog, "TOPLEFT", panel, "TOPLEFT", 12, -166)
        Anchor(panel.refresh, "TOPRIGHT", panel, "TOPRIGHT", -12, -154)
        panel.listTop = 190
    elseif medium then
        -- The normal Core settings page is wide enough for three compact
        -- control rows even when it is not wide enough for the two-row form.
        -- Keep the checkboxes together so the business controls start higher.
        Anchor(panel.checks[1], "TOPLEFT", panel, "TOPLEFT", 12, -34)
        Anchor(panel.checks[2], "TOPLEFT", panel, "TOPLEFT", 220, -34)
        Anchor(panel.confirmHeader, "TOPLEFT", panel, "TOPLEFT", 12, -62)
        Anchor(panel.checks[3], "TOPLEFT", panel, "TOPLEFT", 12, -82); panel.checks[3]:SetWidth(300)
        Anchor(panel.spaceLabel, "TOPLEFT", panel, "TOPLEFT", 12, -110)
        Anchor(panel.space, "LEFT", panel.spaceLabel, "RIGHT", 8, 0)
        Anchor(panel.mode, "TOPLEFT", panel, "TOPLEFT", 300, -100)
        Anchor(panel.retry, "LEFT", panel.mode, "RIGHT", 10, 0)
        Anchor(panel.add, "TOPLEFT", panel, "TOPLEFT", 12, -144); panel.add:SetWidth(370)
        Anchor(panel.addButton, "LEFT", panel.add, "RIGHT", 8, 0)
        Anchor(panel.drop, "LEFT", panel.addButton, "RIGHT", 8, 0); panel.drop:SetWidth(235)
        Anchor(panel.message, "TOPLEFT", panel, "TOPLEFT", 12, -174)
        Anchor(panel.catalog, "TOPLEFT", panel, "TOPLEFT", 12, -200)
        Anchor(panel.refresh, "TOPRIGHT", panel, "TOPRIGHT", -12, -188)
        panel.listTop = 224
    else
        Anchor(panel.checks[1], "TOPLEFT", panel, "TOPLEFT", 12, -34)
        Anchor(panel.checks[2], "TOPLEFT", panel, "TOPLEFT", 220, -34)
        Anchor(panel.confirmHeader, "TOPLEFT", panel, "TOPLEFT", 12, -58)
        Anchor(panel.checks[3], "TOPLEFT", panel, "TOPLEFT", 12, -78)
        Anchor(panel.spaceLabel, "TOPLEFT", panel, "TOPLEFT", 12, -106)
        Anchor(panel.space, "LEFT", panel.spaceLabel, "RIGHT", 8, 0)
        Anchor(panel.mode, "TOPLEFT", panel, "TOPLEFT", 300, -96)
        Anchor(panel.retry, "LEFT", panel.mode, "RIGHT", 10, 0)
        Anchor(panel.add, "TOPLEFT", panel, "TOPLEFT", 12, -144); panel.add:SetWidth(300)
        Anchor(panel.addButton, "LEFT", panel.add, "RIGHT", 8, 0)
        Anchor(panel.drop, "LEFT", panel.addButton, "RIGHT", 8, 0); panel.drop:SetWidth(180)
        Anchor(panel.message, "TOPLEFT", panel, "TOPLEFT", 12, -174)
        Anchor(panel.catalog, "TOPLEFT", panel, "TOPLEFT", 12, -204)
        Anchor(panel.refresh, "TOPRIGHT", panel, "TOPRIGHT", -12, -192)
        panel.listTop = 228
    end
    panel.confirmHeader:SetText("确认框位置")
    local function Refresh() host.refreshPage() end
    panel.checks[1]:SetChecked(Addon.db.enabled); panel.checks[1]:SetScript("OnClick", function(c) Addon.db.enabled = not c:GetChecked(); if not Addon.db.enabled then Addon.Queue:Clear() else Addon:Refresh() end; Refresh() end)
    panel.checks[2]:SetChecked(Addon.db.scanExistingOnLogin); panel.checks[2]:SetScript("OnClick", function(c) Addon.db.scanExistingOnLogin = not c:GetChecked(); Refresh() end)
    panel.checks[3]:SetChecked(Addon.db.bindConfirmFollowCursor); panel.checks[3]:SetScript("OnClick", function(c) Addon.db.bindConfirmFollowCursor = not c:GetChecked(); Refresh() end)
    panel.spaceLabel:SetText("最低通用背包空位（1–20）") ; panel.space:SetText(Addon.db.minFreeSlots)
    local function SaveSpace(c)
        local value = tonumber(c:GetText())
        if not value or value < 1 or value > 20 or value ~= math.floor(value) then c:SetText(Addon.db.minFreeSlots); return false end
        if value == Addon.db.minFreeSlots then return false end
        Addon.db.minFreeSlots = value; Addon:Refresh(); return true
    end
    panel.space:SetScript("OnEnterPressed", function(c) SaveSpace(c); c:ClearFocus() end)
    panel.space:SetScript("OnEditFocusLost", function(c) if SaveSpace(c) then Refresh() end end)
    panel.mode:SetOptions({ { value="silent", label="聊天提示：静默" }, { value="issues", label="聊天提示：仅问题" }, { value="verbose", label="聊天提示：详细" } }); panel.mode:SetValue(Addon.db.notificationMode); panel.mode:SetOnValueChanged(function(v) Addon.db.notificationMode = v; Refresh() end)
    local state, reason = Addon.Queue:GetStatus(); local quarantined = 0; for _ in pairs(Addon.runtime.quarantined) do quarantined = quarantined + 1 end
    local catalogued = Addon.BagAdapter:CountCatalogued(Addon.db.catalog.entries)
    panel.status:SetText("当前状态：" .. state .. (reason and (" · " .. reason) or "") .. " · 背包目录物品 " .. catalogued .. " 项 · 本次登录隔离 " .. quarantined .. " 项")
    local function RetryScan()
        Addon:ResetAllItemRuntimeState()
        if Addon.Safety and Addon.Safety.ReconcileSensitiveFrames then Addon.Safety:ReconcileSensitiveFrames() end
        if Addon.Queue then Addon.Queue:RequestRecoveryScan(5) else Addon:Refresh() end
        Refresh()
    end
    panel.retry:SetShown(quarantined > 0); panel.retry:SetScript("OnClick", RetryScan)
    local items = Addon.Database:GetOrderedItems()
    -- Core resolves the hosted row width before invoking this panel.  Using
    -- that stable width avoids locking the catalog to a stale two-column
    -- layout during the child's first layout pass.
    availableWidth = math.max(600, parent:GetWidth() or 600)
    local minimumColumnWidth = 280
    local columnCount = math.max(1, math.min(3, math.floor((availableWidth - 24 + 12) / (minimumColumnWidth + 12))))
    local rowsPerColumn = math.max(1, math.ceil(#items / columnCount))
    local columnGap = 12
    local columnWidth = math.floor((availableWidth - 24 - columnGap * (columnCount - 1)) / columnCount)
    local rowHeight = (theme.Size and theme.Size.compact) or 26
    local rowStep = rowHeight + 4
    panel.catalog:SetText("目录物品：" .. #items .. " 项 · " .. columnCount .. " 列（按列排列）")
    panel.refresh:SetScript("OnClick", function()
        RetryScan()
        for _, id in ipairs(items) do
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            if GetItemInfo then GetItemInfo(id) end
        end
        panel.message:SetText("已刷新目录名称与运行状态，并重新扫描背包。若敏感界面仍处于打开状态，自动开包会继续暂停。")
    end)
    for i = 1, #items do
        local column = math.floor((i - 1) / rowsPerColumn)
        local rowIndex = (i - 1) % rowsPerColumn
        local row = panel.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, panel)
            row.name = Text(row, theme.Font.body, colors.text); row.name:SetPoint("LEFT"); row.name:SetPoint("RIGHT", -56, 0); row.name:SetWordWrap(false)
            row.delete = theme:CreateButton(row, 44, "删除", "danger"); row.delete:SetPoint("RIGHT")
            panel.rows[i] = row
        end
        row.delete:SetHeight(rowHeight)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12 + column * (columnWidth + columnGap), -(panel.listTop + rowIndex * rowStep)); row:SetSize(columnWidth, rowHeight)
        local id = items[i]; local name, link = GetItemInfo(id); local label = link or name or ("物品 #" .. id)
        local manualOnly = Addon.Catalog and Addon.Catalog:IsManualOnly(id)
        row.name:SetText(i .. ". " .. label .. " · " .. id .. (manualOnly and " · 仅手动开启（不会自动开启）" or "")); row.delete:SetScript("OnClick", function() StaticPopup_Show(DELETE_POPUP, label, nil, id) end); row:Show()
    end
    for i = #items + 1, #panel.rows do panel.rows[i]:Hide() end
    local confirmSources = Addon.Database:GetConfirmSources()
    local confirmSourceTop = panel.listTop + rowsPerColumn * rowStep + 22
    Anchor(panel.confirmSourceHeader, "TOPLEFT", panel, "TOPLEFT", 12, -confirmSourceTop)
    panel.confirmSourceHeader:SetText("确认框来源白名单：" .. #confirmSources .. " 项 · 输入对象 ID 添加")
    Anchor(panel.confirmSourceInput, "TOPLEFT", panel, "TOPLEFT", 12, -(confirmSourceTop + 28))
    panel.confirmSourceInput:SetWidth(math.max(260, math.min(420, availableWidth - 190)))
    panel.confirmSourceInput:SetText("")
    panel.confirmSourceInput:SetScript("OnEnterPressed", function(c) panel.confirmSourceAddButton:Click(); c:ClearFocus() end)
    Anchor(panel.confirmSourceAddButton, "LEFT", panel.confirmSourceInput, "RIGHT", 8, 0)
    local confirmRowTop = confirmSourceTop + 62
    local confirmColumnCount = columnCount
    local confirmColumnWidth = columnWidth
    local confirmRowsPerColumn = math.max(1, math.ceil(#confirmSources / confirmColumnCount))
    for i, source in ipairs(confirmSources) do
        local column = math.floor((i - 1) / confirmRowsPerColumn)
        local rowIndex = (i - 1) % confirmRowsPerColumn
        local row = panel.confirmSourceRows[i]
        if not row then
            row = CreateFrame("Frame", nil, panel)
            row.enabled = host.createCheckbox(row, ""); row.enabled:SetSize(24, 24); row.enabled:SetPoint("LEFT")
            row.name = Text(row, theme.Font.body, colors.text); row.name:SetPoint("LEFT", 28, 0); row.name:SetPoint("RIGHT", -176, 0); row.name:SetWordWrap(false)
            row.id = Text(row, theme.Font.body, colors.muted); row.id:SetJustifyH("RIGHT"); row.id:SetPoint("RIGHT", -84, 0); row.id:SetWidth(54)
            row.alias = CreateFrame("EditBox", nil, row, "InputBoxTemplate"); row.alias:SetAutoFocus(false); row.alias:SetHeight(rowHeight); row.alias:SetPoint("LEFT", 28, 0); row.alias:SetPoint("RIGHT", -104, 0); row.alias:Hide()
            row.edit = theme:CreateButton(row, 32, "改", "secondary"); row.edit:SetPoint("RIGHT", -44, 0)
            row.save = theme:CreateButton(row, 44, "保存", "secondary"); row.save:SetPoint("RIGHT", -50, 0); row.save:Hide()
            row.delete = theme:CreateButton(row, 44, "删除", "danger"); row.delete:SetPoint("RIGHT")
            panel.confirmSourceRows[i] = row
        end
        row.delete:SetHeight(rowHeight)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12 + column * (confirmColumnWidth + columnGap), -(confirmRowTop + rowIndex * rowStep)); row:SetSize(confirmColumnWidth, rowHeight)
        local builtin = source.key == "auto-open-catalog"
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", 28, 0); row.name:SetPoint("RIGHT", builtin and -12 or -138, 0)
        row.name:SetText(i .. ". " .. source.label)
        row.id:SetText(source.kind == "object" and tostring(source.objectID) or "")
        row.alias:SetText(source.label)
        local function SetEditing(editing)
            row.editing = editing
            row.name:SetShown(not editing)
            row.id:SetShown(not editing and source.kind == "object")
            row.alias:SetShown(editing)
            row.edit:SetShown(not editing and not builtin)
            row.save:SetShown(editing)
            row.delete:SetShown(not builtin)
            if editing then row.alias:SetFocus() end
        end
        local function SaveAlias(text)
            local label = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
            if Addon.Database:SetConfirmSourceLabel(source.key, label) then
                source.label = label
                row.alias:SetText(label)
                row.name:SetText(i .. ". " .. label)
                SetEditing(false)
                return true
            end
            return false
        end
        row.alias:SetScript("OnEnterPressed", function(c)
            SaveAlias(c:GetText())
            c:ClearFocus()
        end)
        row.edit:SetScript("OnClick", function() SetEditing(true) end)
        row.save:SetScript("OnClick", function()
            SaveAlias(row.alias:GetText())
        end)
        row.enabled:SetChecked(source.enabled)
        row.enabled:SetScript("OnClick", function(c)
            Addon.Database:SetConfirmSourceEnabled(source.key, c:GetChecked())
            row.enabled:SetChecked(c:GetChecked())
        end)
        row.delete:SetScript("OnClick", function() StaticPopup_Show(DELETE_CONFIRM_SOURCE_POPUP, source.label, nil, source.key) end)
        SetEditing(false)
        row:Show()
    end
    for i = #confirmSources + 1, #panel.confirmSourceRows do panel.confirmSourceRows[i]:Hide() end
    panel.confirmSourceAddButton:SetScript("OnClick", function()
        local ok, result = Addon.Database:AddConfirmObject(panel.confirmSourceInput:GetText())
        if ok then
            panel.confirmSourceInput:SetText("")
            Addon:Refresh(); Refresh()
        elseif result == "already_exists" then
            panel.message:SetText("该对象 ID 已在确认框来源白名单中。")
        else
            panel.message:SetText("请输入有效的对象 ID，例如 210565。")
        end
    end)
    local recentSources = Addon.BindConfirmAssist and Addon.BindConfirmAssist.GetRecentConfirmObjects
        and Addon.BindConfirmAssist:GetRecentConfirmObjects() or {}
    local recentSourceTop = confirmRowTop + confirmRowsPerColumn * rowStep + 22
    Anchor(panel.recentSourceHeader, "TOPLEFT", panel, "TOPLEFT", 12, -recentSourceTop)
    panel.recentSourceHeader:SetText("最近可添加对象：" .. #recentSources .. " 项 · 本次登录")
    local recentRowTop = recentSourceTop + 28
    for i, source in ipairs(recentSources) do
        local column = math.floor((i - 1) / confirmRowsPerColumn)
        local rowIndex = (i - 1) % confirmRowsPerColumn
        local row = panel.recentSourceRows[i]
        if not row then
            row = CreateFrame("Frame", nil, panel)
            row.name = Text(row, theme.Font.body, colors.text); row.name:SetPoint("LEFT"); row.name:SetPoint("RIGHT", -86, 0); row.name:SetWordWrap(false)
            row.add = theme:CreateButton(row, 74, "添加", "secondary"); row.add:SetPoint("RIGHT")
            panel.recentSourceRows[i] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12 + column * (confirmColumnWidth + columnGap), -(recentRowTop + rowIndex * rowStep)); row:SetSize(confirmColumnWidth, rowHeight)
        row.name:SetText(i .. ". " .. source.label .. " · " .. tostring(source.objectID))
        local sourceKey = "object:" .. source.objectID
        local alreadyAdded = Addon.Database:HasConfirmSource(sourceKey)
        row.add:SetText(alreadyAdded and "已在名单" or "添加")
        row.add:SetEnabled(not alreadyAdded)
        row.add:SetScript("OnClick", function()
            local ok, result = Addon.Database:AddConfirmObject(source.objectID, source.label)
            if ok then Addon:Refresh(); Refresh()
            elseif result == "already_exists" then panel.message:SetText("该对象已在确认框来源白名单中。") end
        end)
        row:Show()
    end
    for i = #recentSources + 1, #panel.recentSourceRows do panel.recentSourceRows[i]:Hide() end
    local function AddInput(raw, fromDrop)
        local id, err = Addon.ItemResolver:Resolve(raw)
        if not id then panel.message:SetText(err == "ambiguous" and "名称不唯一，请使用链接或 ID。" or "未找到物品，请使用物品链接或 ID。"); return end
        local ok, result = Addon.Database:AddItem(id)
        local manualOnly = Addon.Catalog and Addon.Catalog:IsManualOnly(id)
        if ok then
            panel.add:SetText(""); panel.message:SetText(manualOnly and "已加入目录，但受游戏限制不会自动开启，请手动右键。" or (fromDrop and "已通过拖放加入目录。" or "已加入目录。")); Addon:Refresh()
        elseif result == "already_exists" and manualOnly then panel.message:SetText("该物品已在目录中，但受游戏限制不会自动开启，请手动右键。")
        else panel.message:SetText(result == "already_exists" and "该物品已在目录中。" or "无法添加物品。") end
        Refresh()
    end
    local function AddCursorItem()
        local cursorType, itemID, itemLink
        if GetCursorInfo then cursorType, itemID, itemLink = GetCursorInfo() end
        if cursorType ~= "item" then panel.message:SetText("请从背包拖动物品到这里。"); return end
        if ClearCursor then ClearCursor() end
        AddInput(itemLink or itemID, true)
    end
    panel.addButton:SetScript("OnClick", function() AddInput(panel.add:GetText(), false) end)
    panel.drop:SetScript("OnReceiveDrag", AddCursorItem)
    panel.drop:SetScript("OnClick", AddCursorItem)
    panel:SetHeight(recentRowTop + confirmRowsPerColumn * rowStep + 8); return panel:GetHeight()
end
