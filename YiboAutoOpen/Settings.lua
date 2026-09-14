local Addon = _G.YiboAutoOpen
local Settings = {}; Addon.Settings = Settings
local function Text(parent, size, color) return _G.YiboCore.UITheme:CreateText(parent, size, color, "LEFT") end
local DELETE_POPUP = "YIBOAUTOOPEN_DELETE_CATALOG_ITEM"
StaticPopupDialogs[DELETE_POPUP] = {
    text = "确定从自动开包目录删除“%s”吗？\n这不会删除背包中的物品。",
    button1 = "删除", button2 = "取消", timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) Addon.Database:RemoveItem(data); Addon:Refresh("settings-delete"); if Addon.Settings.panel and Addon.Settings.panel.host then Addon.Settings.panel.host.refreshPage() end end,
}
function Settings:Release() end
function Settings:Refresh() if self.panel and self.panel.host then self:CreatePanel(self.panel:GetParent(), self.panel.host) end end
function Settings:CreatePanel(parent, host)
    -- Core can render this settings-only panel immediately after addon files
    -- load, before our ADDON_LOADED handler initializes SavedVariables.
    Addon.Database:EnsureInitialized()
    local theme, colors = _G.YiboCore.UITheme, _G.YiboCore.UITheme.Colors
    local panel = parent.autoOpenSettingsPanel
    if not panel then
        panel = CreateFrame("Frame", nil, parent); parent.autoOpenSettingsPanel = panel; panel:SetPoint("TOPLEFT"); panel:SetPoint("TOPRIGHT"); panel.checks, panel.rows = {}, {}
        panel.title = Text(panel, 14, colors.text); panel.title:SetPoint("TOPLEFT", 12, -12)
        panel.status = Text(panel, theme.Font.meta, colors.muted); panel.status:SetPoint("TOPLEFT", 12, -8)
        panel.spaceLabel = Text(panel, theme.Font.meta, colors.muted); panel.spaceLabel:SetPoint("TOPLEFT", 12, -68)
        panel.space = CreateFrame("EditBox", nil, panel, "InputBoxTemplate"); panel.space:SetSize(64, 22); panel.space:SetAutoFocus(false); panel.space:SetPoint("LEFT", panel.spaceLabel, "RIGHT", 8, 0)
        panel.mode = theme:CreateDropdown(panel, 160, { { value="silent", label="静默" }, { value="issues", label="仅问题" }, { value="verbose", label="详细" } }); panel.mode:SetPoint("TOPLEFT", 300, -58)
        panel.retry = theme:CreateButton(panel, 96, "重新尝试", "secondary"); panel.retry:SetPoint("LEFT", panel.mode, "RIGHT", 10, 0)
        panel.add = CreateFrame("EditBox", nil, panel, "InputBoxTemplate"); panel.add:SetSize(300, 22); panel.add:SetAutoFocus(false); panel.add:SetPoint("TOPLEFT", 12, -106)
        panel.addButton = theme:CreateButton(panel, 60, "添加"); panel.addButton:SetPoint("LEFT", panel.add, "RIGHT", 8, 0)
        panel.drop = theme:CreateButton(panel, 180, "拖放背包物品到这里", "secondary"); panel.drop:SetPoint("LEFT", panel.addButton, "RIGHT", 8, 0); panel.drop:RegisterForDrag("LeftButton")
        panel.message = Text(panel, theme.Font.meta, colors.muted); panel.message:SetPoint("TOPLEFT", 12, -136)
        panel.catalog = Text(panel, theme.Font.meta, colors.muted); panel.catalog:SetPoint("TOPLEFT", 12, -166)
        panel.refresh = theme:CreateButton(panel, 80, "刷新", "secondary"); panel.refresh:SetPoint("TOPRIGHT", -12, -154)
        panel.checks[1] = host.createCheckbox(panel, "启用自动开包"); panel.checks[1]:SetPoint("TOPLEFT", 12, -34); panel.checks[1]:SetWidth(200)
        panel.checks[2] = host.createCheckbox(panel, "登录时扫描已有包裹"); panel.checks[2]:SetPoint("TOPLEFT", 220, -34); panel.checks[2]:SetWidth(260)
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
    panel.host = host; self.panel = panel; panel:Show(); panel.title:Hide()
    local function Refresh() host.refreshPage() end
    panel.checks[1]:SetChecked(Addon.db.enabled); panel.checks[1]:SetScript("OnClick", function(c) Addon.db.enabled = not c:GetChecked(); if not Addon.db.enabled then Addon.Queue:Clear() else Addon:Refresh("enabled") end; Refresh() end)
    panel.checks[2]:SetChecked(Addon.db.scanExistingOnLogin); panel.checks[2]:SetScript("OnClick", function(c) Addon.db.scanExistingOnLogin = c:GetChecked(); Refresh() end)
    panel.spaceLabel:SetText("最低通用背包空位（1–20）") ; panel.space:SetText(Addon.db.minFreeSlots)
    local function SaveSpace(c) local value = tonumber(c:GetText()); if value and value >= 1 and value <= 20 and value == math.floor(value) then Addon.db.minFreeSlots = value; Addon:Refresh("space") else c:SetText(Addon.db.minFreeSlots) end end
    panel.space:SetScript("OnEnterPressed", function(c) SaveSpace(c); c:ClearFocus(); Refresh() end); panel.space:SetScript("OnEditFocusLost", SaveSpace)
    panel.mode:SetOptions({ { value="silent", label="聊天提示：静默" }, { value="issues", label="聊天提示：仅问题" }, { value="verbose", label="聊天提示：详细" } }); panel.mode:SetValue(Addon.db.notificationMode); panel.mode:SetOnValueChanged(function(v) Addon.db.notificationMode = v; Refresh() end)
    local state, reason = Addon.Queue:GetStatus(); local quarantined = 0; for _ in pairs(Addon.runtime.quarantined) do quarantined = quarantined + 1 end
    local catalogued = Addon.BagAdapter:CountCatalogued(Addon.db.catalog.entries)
    panel.status:SetText("当前状态：" .. state .. (reason and (" · " .. reason) or "") .. " · 背包目录物品 " .. catalogued .. " 项 · 本次登录隔离 " .. quarantined .. " 项")
    panel.retry:SetShown(quarantined > 0); panel.retry:SetScript("OnClick", function() Addon:ResetAllItemRuntimeState(); Addon:Refresh("retry-all"); Refresh() end)
    local items = Addon.Database:GetOrderedItems()
    -- Core resolves the hosted row width before invoking this panel.  Using
    -- that stable width avoids locking the catalog to a stale two-column
    -- layout during the child's first layout pass.
    local availableWidth = math.max(600, parent:GetWidth() or 600)
    local minimumColumnWidth = 280
    local columnCount = math.max(1, math.min(3, math.floor((availableWidth - 24 + 12) / (minimumColumnWidth + 12))))
    local rowsPerColumn = math.max(1, math.ceil(#items / columnCount))
    local columnGap = 12
    local columnWidth = math.floor((availableWidth - 24 - columnGap * (columnCount - 1)) / columnCount)
    local rowHeight = (theme.Size and theme.Size.compact) or 26
    local rowStep = rowHeight + 4
    panel.catalog:SetText("目录物品：" .. #items .. " 项 · " .. columnCount .. " 列（按列排列）")
    panel.refresh:SetScript("OnClick", function()
        Addon:ResetAllItemRuntimeState()
        for _, id in ipairs(items) do
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            if GetItemInfo then GetItemInfo(id) end
        end
        panel.message:SetText("已刷新目录名称、清除本次登录隔离并重新扫描背包。")
        Addon:Refresh("settings-refresh")
        Refresh()
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
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12 + column * (columnWidth + columnGap), -(190 + rowIndex * rowStep)); row:SetSize(columnWidth, rowHeight)
        local id = items[i]; local name, link = GetItemInfo(id); local label = link or name or ("物品 #" .. id)
        row.name:SetText(i .. ". " .. label .. " · " .. id); row.delete:SetScript("OnClick", function() StaticPopup_Show(DELETE_POPUP, label, nil, id) end); row:Show()
    end
    for i = #items + 1, #panel.rows do panel.rows[i]:Hide() end
    local function AddInput(raw, fromDrop)
        local id, err = Addon.ItemResolver:Resolve(raw)
        if not id then panel.message:SetText(err == "ambiguous" and "名称不唯一，请使用链接或 ID。" or "未找到物品，请使用物品链接或 ID。"); return end
        local ok, result = Addon.Database:AddItem(id)
        if ok then
            panel.add:SetText(""); panel.message:SetText(fromDrop and "已通过拖放加入目录。" or "已加入目录。"); Addon:Refresh("settings-add")
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
    panel:SetHeight(190 + rowsPerColumn * rowStep + 8); return panel:GetHeight()
end
