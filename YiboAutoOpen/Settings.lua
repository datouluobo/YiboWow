local Addon = _G.YiboAutoOpen
local Settings = {}; Addon.Settings = Settings
local function Text(parent, size, color) return _G.YiboCore.UITheme:CreateText(parent, size, color, "LEFT") end
local DELETE_POPUP = "YIBOAUTOOPEN_DELETE_CATALOG_ITEM"
local DELETE_CONFIRM_SOURCE_POPUP = "YIBOAUTOOPEN_DELETE_CONFIRM_SOURCE"
StaticPopupDialogs[DELETE_POPUP] = {
    text = Addon:T("CONFIRM.DELETE_ITEM"),
    button1 = Addon:T("ACTION.DELETE"), button2 = Addon:T("ACTION.CANCEL"), timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) Addon.Database:RemoveItem(data); Addon:Refresh(); if Addon.Settings.panel and Addon.Settings.panel.host then Addon.Settings.panel.host.refreshPage() end end,
}
StaticPopupDialogs[DELETE_CONFIRM_SOURCE_POPUP] = {
    text = Addon:T("CONFIRM.DELETE_SOURCE"),
    button1 = Addon:T("ACTION.DELETE"), button2 = Addon:T("ACTION.CANCEL"), timeout = 0, whileDead = true, hideOnEscape = true,
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
        panel.space = theme:CreateInput(panel, { width = 64, height = 22, numeric = true, OnSubmit = function(_, c) if c.onSubmit then c.onSubmit(c) end end, OnFocus = function(focused, c) if not focused and c.onBlur then c.onBlur(c) end end }); panel.space:SetSize(64, 22); panel.space:SetAutoFocus(false)
        panel.mode = theme:CreateDropdown(panel, 160, { { value="silent", label=Addon:T("MODE.SILENT") }, { value="issues", label=Addon:T("MODE.ISSUES") }, { value="verbose", label=Addon:T("MODE.VERBOSE") } })
        panel.retry = theme:CreateButton(panel, 96, Addon:T("ACTION.RETRY"), "secondary")
        panel.add = theme:CreateInput(panel, { width = 300, height = 22, OnSubmit = function(_, c) if c.onSubmit then c.onSubmit(c) end end }); panel.add:SetSize(300, 22); panel.add:SetAutoFocus(false)
        panel.addButton = theme:CreateButton(panel, 60, Addon:T("ACTION.ADD"))
        panel.drop = theme:CreateButton(panel, 180, Addon:T("ACTION.DROP"), "secondary"); panel.drop:RegisterForDrag("LeftButton")
        panel.message = Text(panel, theme.Font.meta, colors.muted)
        panel.catalog = Text(panel, theme.Font.meta, colors.muted)
        panel.confirmHeader = Text(panel, theme.Font.meta, colors.text)
        panel.confirmSourceHeader = Text(panel, theme.Font.meta, colors.text)
        panel.confirmSourceInput = theme:CreateInput(panel, { width = 300, height = 22, OnSubmit = function(_, c) if c.onSubmit then c.onSubmit(c) end end }); panel.confirmSourceInput:SetSize(300, 22); panel.confirmSourceInput:SetAutoFocus(false)
        panel.confirmSourceAddButton = theme:CreateButton(panel, 60, Addon:T("ACTION.ADD"))
        panel.confirmSourceRows = {}
        panel.recentSourceHeader = Text(panel, theme.Font.meta, colors.text)
        panel.recentSourceRows = {}
        panel.refresh = theme:CreateButton(panel, 80, Addon:T("ACTION.REFRESH"), "secondary")
        panel.checks[1] = host.createCheckbox(panel, Addon:T("SETTING.ENABLED")); panel.checks[1]:SetWidth(200)
        panel.checks[2] = host.createCheckbox(panel, Addon:T("SETTING.LOGIN")); panel.checks[2]:SetWidth(260)
        panel.checks[3] = host.createCheckbox(panel, Addon:T("SETTING.CURSOR")); panel.checks[3]:SetWidth(300)
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
        if host.bindTooltip then host.bindTooltip(panel.refresh, Addon:T("TOOLTIP.REFRESH"), { Addon:T("TOOLTIP.NAMES"), Addon:T("TOOLTIP.RETRY") }) end
    end
    panel.host = host; self.panel = panel; panel:Show()
    local availableWidth = parent:GetWidth()
    local compact = availableWidth >= 1100
    local medium = availableWidth >= 700
    local function Anchor(frame, point, relativeTo, relativePoint, x, y)
        frame:ClearAllPoints(); frame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
    if medium then
        panel.checks[1]:SetWidth(200); panel.checks[2]:SetWidth(260); panel.checks[3]:SetWidth(300)
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
        for index, check in ipairs(panel.checks) do
            check:SetWidth(math.max(1, availableWidth - 24))
            Anchor(check, "TOPLEFT", panel, "TOPLEFT", 12, index == 3 and -104 or -34 - (index - 1) * 26)
        end
        Anchor(panel.confirmHeader, "TOPLEFT", panel, "TOPLEFT", 12, -86)
        Anchor(panel.spaceLabel, "TOPLEFT", panel, "TOPLEFT", 12, -134)
        Anchor(panel.space, "LEFT", panel.spaceLabel, "RIGHT", 8, 0)
        Anchor(panel.mode, "TOPLEFT", panel, "TOPLEFT", 12, -160)
        Anchor(panel.retry, "LEFT", panel.mode, "RIGHT", 10, 0)
        local dropWidth = math.min(180, math.floor(availableWidth * 0.36))
        Anchor(panel.add, "TOPLEFT", panel, "TOPLEFT", 12, -198)
        panel.add:SetWidth(math.max(1, availableWidth - dropWidth - 100))
        Anchor(panel.addButton, "LEFT", panel.add, "RIGHT", 8, 0)
        Anchor(panel.drop, "LEFT", panel.addButton, "RIGHT", 8, 0); panel.drop:SetWidth(math.max(1, dropWidth))
        Anchor(panel.message, "TOPLEFT", panel, "TOPLEFT", 12, -230)
        Anchor(panel.catalog, "TOPLEFT", panel, "TOPLEFT", 12, -265)
        Anchor(panel.refresh, "TOPRIGHT", panel, "TOPRIGHT", -12, -253)
        panel.listTop = 293
    end
    panel.confirmHeader:SetText(Addon:T("SETTING.CONFIRM"))
    panel.status:SetWidth(math.max(1, availableWidth - 24)); panel.status:SetWordWrap(false)
    panel.message:SetWidth(math.max(1, availableWidth - 24)); panel.message:SetWordWrap(false)
    local function Refresh() host.refreshPage() end
    panel.checks[1]:SetChecked(Addon.db.enabled); panel.checks[1]:SetScript("OnClick", function(c) Addon.db.enabled = not c:GetChecked(); if not Addon.db.enabled then Addon.Queue:Clear() else Addon:Refresh() end; Refresh() end)
    panel.checks[2]:SetChecked(Addon.db.scanExistingOnLogin); panel.checks[2]:SetScript("OnClick", function(c) Addon.db.scanExistingOnLogin = not c:GetChecked(); Refresh() end)
    panel.checks[3]:SetChecked(Addon.db.bindConfirmFollowCursor); panel.checks[3]:SetScript("OnClick", function(c) Addon.db.bindConfirmFollowCursor = not c:GetChecked(); Refresh() end)
    panel.spaceLabel:SetText(Addon:T("SETTING.SPACE")) ; panel.space:SetText(Addon.db.minFreeSlots)
    local function SaveSpace(c)
        local value = tonumber(c:GetText())
        if not value or value < 1 or value > 20 or value ~= math.floor(value) then c:SetText(Addon.db.minFreeSlots); return false end
        if value == Addon.db.minFreeSlots then return false end
        Addon.db.minFreeSlots = value; Addon:Refresh(); return true
    end
    panel.space.onSubmit = function(c) SaveSpace(c); c:ClearFocus() end
    panel.space.onBlur = function(c) if SaveSpace(c) then Refresh() end end
    panel.mode:SetOptions({ { value="silent", label=Addon:T("MODE.CHAT_SILENT") }, { value="issues", label=Addon:T("MODE.CHAT_ISSUES") }, { value="verbose", label=Addon:T("MODE.CHAT_VERBOSE") } }); panel.mode:SetValue(Addon.db.notificationMode); panel.mode:SetOnValueChanged(function(v) Addon.db.notificationMode = v; Refresh() end)
    local state, reason = Addon.Queue:GetStatus(); local quarantined = 0; for _ in pairs(Addon.runtime.quarantined) do quarantined = quarantined + 1 end
    local catalogued = Addon.BagAdapter:CountCatalogued(Addon.db.catalog.entries)
    panel.status:SetText(Addon:T("STATUS.SUMMARY", Addon:StatusText(state, reason), catalogued, quarantined))
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
    local minimumColumnWidth = 280
    local columnCount = math.max(1, math.min(3, math.floor((availableWidth - 24 + 12) / (minimumColumnWidth + 12))))
    local rowsPerColumn = math.max(1, math.ceil(#items / columnCount))
    local columnGap = 12
    local columnWidth = math.floor((availableWidth - 24 - columnGap * (columnCount - 1)) / columnCount)
    local rowHeight = (theme.Size and theme.Size.compact) or 26
    local rowStep = rowHeight + 4
    panel.catalog:SetText(Addon:T("CATALOG.COUNT", #items, columnCount))
    panel.refresh:SetScript("OnClick", function()
        RetryScan()
        for _, id in ipairs(items) do
            Addon.Core.ItemResolver:Request(id, function() if panel:IsShown() and panel.host then panel.host.refreshPage() end end, { retry = true })
        end
        panel.message:SetText(Addon:T("STATUS.REFRESHED"))
    end)
    for i = 1, #items do
        local column = math.floor((i - 1) / rowsPerColumn)
        local rowIndex = (i - 1) % rowsPerColumn
        local row = panel.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, panel)
            row.name = Text(row, theme.Font.body, colors.text); row.name:SetPoint("LEFT"); row.name:SetPoint("RIGHT", -56, 0); row.name:SetWordWrap(false)
            row.delete = theme:CreateButton(row, 44, Addon:T("ACTION.DELETE"), "danger"); row.delete:SetPoint("RIGHT")
            panel.rows[i] = row
        end
        row.delete:SetHeight(rowHeight)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12 + column * (columnWidth + columnGap), -(panel.listTop + rowIndex * rowStep)); row:SetSize(columnWidth, rowHeight)
        local id = items[i]; local info = Addon.Core.ItemResolver:GetInfo(id); local name, link = info and info.name, info and info.link; local label = link or name or (Addon:T("ITEM.UNKNOWN", id))
        local manualOnly = Addon.Catalog and Addon.Catalog:IsManualOnly(id)
        row.name:SetText(i .. ". " .. label .. " · " .. id .. (manualOnly and Addon:T("ITEM.MANUAL") or "")); row.delete:SetScript("OnClick", function() StaticPopup_Show(DELETE_POPUP, label, nil, id) end); row:Show()
    end
    for i = #items + 1, #panel.rows do panel.rows[i]:Hide() end
    local confirmSources = Addon.Database:GetConfirmSources()
    local confirmSourceTop = panel.listTop + rowsPerColumn * rowStep + 22
    Anchor(panel.confirmSourceHeader, "TOPLEFT", panel, "TOPLEFT", 12, -confirmSourceTop)
    panel.confirmSourceHeader:SetText(Addon:T("SOURCE.COUNT", #confirmSources))
    Anchor(panel.confirmSourceInput, "TOPLEFT", panel, "TOPLEFT", 12, -(confirmSourceTop + 28))
    panel.confirmSourceInput:SetWidth(math.max(1, math.min(420, availableWidth - 92)))
    panel.confirmSourceInput:SetText("")
    panel.confirmSourceInput.onSubmit = function(c) panel.confirmSourceAddButton:Click(); c:ClearFocus() end
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
            row.alias = theme:CreateInput(row, { height = rowHeight, OnSubmit = function(_, c) if c.onSubmit then c.onSubmit(c) end end }); row.alias:SetAutoFocus(false); row.alias:SetHeight(rowHeight); row.alias:SetPoint("LEFT", 28, 0); row.alias:SetPoint("RIGHT", -104, 0); row.alias:Hide()
            row.edit = theme:CreateButton(row, 32, Addon:T("ACTION.EDIT"), "secondary"); row.edit:SetPoint("RIGHT", -44, 0)
            row.save = theme:CreateButton(row, 44, Addon:T("ACTION.SAVE"), "secondary"); row.save:SetPoint("RIGHT", -50, 0); row.save:Hide()
            row.delete = theme:CreateButton(row, 44, Addon:T("ACTION.DELETE"), "danger"); row.delete:SetPoint("RIGHT")
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
        row.alias.onSubmit = function(c)
            SaveAlias(c:GetText())
            c:ClearFocus()
        end
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
            panel.message:SetText(Addon:T("SOURCE.EXISTS_ID"))
        else
            panel.message:SetText(Addon:T("SOURCE.INVALID"))
        end
    end)
    local recentSources = Addon.BindConfirmAssist and Addon.BindConfirmAssist.GetRecentConfirmObjects
        and Addon.BindConfirmAssist:GetRecentConfirmObjects() or {}
    local recentSourceTop = confirmRowTop + confirmRowsPerColumn * rowStep + 22
    Anchor(panel.recentSourceHeader, "TOPLEFT", panel, "TOPLEFT", 12, -recentSourceTop)
    panel.recentSourceHeader:SetText(Addon:T("SOURCE.RECENT", #recentSources))
    local recentRowTop = recentSourceTop + 28
    for i, source in ipairs(recentSources) do
        local column = math.floor((i - 1) / confirmRowsPerColumn)
        local rowIndex = (i - 1) % confirmRowsPerColumn
        local row = panel.recentSourceRows[i]
        if not row then
            row = CreateFrame("Frame", nil, panel)
            row.name = Text(row, theme.Font.body, colors.text); row.name:SetPoint("LEFT"); row.name:SetPoint("RIGHT", -86, 0); row.name:SetWordWrap(false)
            row.add = theme:CreateButton(row, 74, Addon:T("ACTION.ADD"), "secondary"); row.add:SetPoint("RIGHT")
            panel.recentSourceRows[i] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12 + column * (confirmColumnWidth + columnGap), -(recentRowTop + rowIndex * rowStep)); row:SetSize(confirmColumnWidth, rowHeight)
        row.name:SetText(i .. ". " .. source.label .. " · " .. tostring(source.objectID))
        local sourceKey = "object:" .. source.objectID
        local alreadyAdded = Addon.Database:HasConfirmSource(sourceKey)
        row.add:SetText(alreadyAdded and Addon:T("SOURCE.ALREADY") or Addon:T("ACTION.ADD"))
        row.add:SetEnabled(not alreadyAdded)
        row.add:SetScript("OnClick", function()
            local ok, result = Addon.Database:AddConfirmObject(source.objectID, source.label)
            if ok then Addon:Refresh(); Refresh()
            elseif result == "already_exists" then panel.message:SetText(Addon:T("SOURCE.EXISTS")) end
        end)
        row:Show()
    end
    for i = #recentSources + 1, #panel.recentSourceRows do panel.recentSourceRows[i]:Hide() end
    local function AddInput(raw, fromDrop)
        local id, err = Addon.ItemResolver:Resolve(raw)
        if not id then panel.message:SetText(err == "ambiguous" and Addon:T("ITEM.AMBIGUOUS") or Addon:T("ITEM.NOT_FOUND")); return end
        local ok, result = Addon.Database:AddItem(id)
        local manualOnly = Addon.Catalog and Addon.Catalog:IsManualOnly(id)
        if ok then
            panel.add:SetText(""); panel.message:SetText(manualOnly and Addon:T("ITEM.ADDED_MANUAL") or (fromDrop and Addon:T("ITEM.ADDED_DROP") or Addon:T("ITEM.ADDED"))); Addon:Refresh()
        elseif result == "manual_only" then panel.message:SetText(Addon:T("CATALOG.MANUAL_ONLY_REJECTED", (Addon.Core.ItemResolver:GetInfo(id).name or tostring(id))))
        elseif result == "already_exists" and manualOnly then panel.message:SetText(Addon:T("ITEM.EXISTS_MANUAL"))
        else panel.message:SetText(result == "already_exists" and Addon:T("ITEM.EXISTS") or Addon:T("ITEM.ADD_FAILED")) end
        Refresh()
    end
    local function AddCursorItem()
        local cursorType, itemID, itemLink
        if GetCursorInfo then cursorType, itemID, itemLink = GetCursorInfo() end
        if cursorType ~= "item" then panel.message:SetText(Addon:T("ITEM.DROP_REQUIRED")); return end
        if ClearCursor then ClearCursor() end
        AddInput(itemLink or itemID, true)
    end
    panel.addButton:SetScript("OnClick", function() AddInput(panel.add:GetText(), false) end)
    panel.drop:SetScript("OnReceiveDrag", AddCursorItem)
    panel.drop:SetScript("OnClick", AddCursorItem)
    panel:SetHeight(recentRowTop + confirmRowsPerColumn * rowStep + 8); return panel:GetHeight()
end
