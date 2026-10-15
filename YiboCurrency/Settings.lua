local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Theme = Core.UITheme

local function FindCatalogItem(itemID)
    for _, entry in ipairs(Addon:GetCatalog()) do
        if tonumber(entry.itemID) == itemID then return entry end
    end
end

local RemoveOperation = {
    label = Addon:T("CURRENCY.REMOVE_CUSTOM_ITEM_B536FE"),
    Validate = function(info)
        if Addon:GetCustomItem(info.itemID) then return true end
        return false, FindCatalogItem(info.itemID) and Addon:T("CURRENCY.BUILT_IN_CATALOG_ENTRIES_CANNOT_BE_REMOVED_9762CB") or Addon:T("CURRENCY.THIS_ITEM_IS_NOT_IN_THE_CUSTOM_CATALOG_DA96D2")
    end,
    Confirm = function(info)
        local entry = Addon:GetCustomItem(info.itemID)
        return string.format(Addon:T("CURRENCY.REMOVE_S_ITEMID_S_FROM_THE_CUSTOM_CURRENCY_CATALOG_ITS__CCE950"), entry.title, info.itemID)
    end,
    Execute = function(info)
        local entry, err = Addon:RemoveCustomItem(info.itemID)
        if not entry then return false, err end
        Addon:NotifyChanged()
        return true, Addon:T("UI.CUSTOM_REMOVED", entry.title)
    end,
}

function Addon:ConfirmRemoveCustomItem(itemID, refreshPage, owner)
    if not (self.CoreIntegration and self.CoreIntegration.initialized) then
        self:Print(self:UpgradeMessage()); return
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
local function CustomItemList(panel, picker, context, y)
    local items = Addon:GetSettings().customItems or {}
    Label(panel, "customCount", Addon:T("UI.CUSTOM_ITEM_COUNT", #items), y, Theme.Colors.muted)
    y = y + 26
    local size = 8
    local pages = math.max(1, math.ceil(#items / size))
    panel.customPage = math.max(1, math.min(panel.customPage or 1, pages))
    local gap, width, preferred = Theme.Space.sm, math.max(1, picker.layoutContentWidth), 240
    for _, entry in ipairs(items) do
        local idText = Addon:T("UI.CUSTOM_ITEM_ID", tostring(entry.itemID))
        preferred = math.max(preferred, Theme:MeasureText(Theme.Font.body, tostring(entry.title or entry.itemID))
            + Theme:MeasureText(Theme.Font.assist, idText) + 16 + Theme.Space.md + Theme.Space.sm * 3)
    end
    preferred = math.min(360, preferred)
    local columns = math.max(1, math.min(#items, math.floor((width + gap) / (preferred + gap))))
    local itemWidth = (width - (columns - 1) * gap) / columns
    local listTop = y
    local first, used = (panel.customPage - 1) * size + 1, 0
    for index = first, math.min(#items, first + size - 1) do
        local entry = items[index]
        local itemID = tonumber(entry.itemID)
        used = used + 1
        local row = panel.rows[used] or Theme:CreateButton(panel, itemWidth, "", "secondary")
        panel.rows[used] = row; row.itemID = itemID
        local column, line = (used - 1) % columns, math.floor((used - 1) / columns)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", panel, "TOPLEFT", column * (itemWidth + gap), -listTop - line * (Theme.Size.standard + 4)); row:SetWidth(itemWidth)
        row:SetText("|T" .. tostring(entry.icon or 134400) .. ":16:16:0:0|t " .. tostring(entry.title or itemID))
        row.idLabel = row.idLabel or Theme:CreateText(row, Theme.Font.assist, Theme.Colors.muted, "RIGHT")
        local idText = Addon:T("UI.CUSTOM_ITEM_ID", tostring(itemID))
        local idWidth = Theme:MeasureText(Theme.Font.assist, idText) + Theme.Space.md
        row.idLabel:ClearAllPoints(); row.idLabel:SetPoint("RIGHT", row, "RIGHT", -Theme.Space.sm, 0)
        row.idLabel:SetWidth(idWidth); row.idLabel:SetText(idText); row.idLabel:Show()
        row.label:ClearAllPoints(); row.label:SetPoint("LEFT", row, "LEFT", Theme.Space.sm, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -idWidth - Theme.Space.md, 0); row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false); row.label:Show()
        row:SetState(picker.input:GetText() == tostring(itemID) and "selected" or "default")
        row:SetScript("OnClick", function()
            picker:SetValue(tostring(itemID))
            for _, control in ipairs(panel.rows) do control:SetState(control.itemID == itemID and "selected" or "default") end
        end)
        Theme:BindTooltip(row, entry.title or tostring(itemID), { idText, Addon:T("UI.CUSTOM_ITEM_SELECT_HINT") })
        row:Show()
    end
    y = listTop + math.ceil(used / columns) * (Theme.Size.standard + 4)
    for index = used + 1, #panel.rows do panel.rows[index]:Hide() end
    local empty = Label(panel, "customEmpty", Addon:T("UI.CUSTOM_ITEMS_EMPTY"), y, Theme.Colors.muted)
    if #items == 0 then y = y + 26 else empty:Hide() end
    if not panel.customPrevious then
        panel.customPrevious = Theme:CreateButton(panel, 40, "<", "secondary")
        panel.customNext = Theme:CreateButton(panel, 40, ">", "secondary")
        panel.customPageLabel = Theme:CreateText(panel, Theme.Font.assist, Theme.Colors.muted, "CENTER")
    end
    local previous, nextButton, pageLabel = panel.customPrevious, panel.customNext, panel.customPageLabel
    previous:SetShown(pages > 1); nextButton:SetShown(pages > 1); pageLabel:SetShown(pages > 1)
    if pages > 1 then
        previous:ClearAllPoints(); previous:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
        pageLabel:ClearAllPoints(); pageLabel:SetPoint("LEFT", previous, "RIGHT", Theme.Space.sm, 0); pageLabel:SetWidth(100)
        pageLabel:SetText(Addon:T("UI.CUSTOM_ITEM_PAGE", panel.customPage, pages))
        nextButton:ClearAllPoints(); nextButton:SetPoint("LEFT", pageLabel, "RIGHT", Theme.Space.sm, 0)
        previous:SetEnabled(panel.customPage > 1); nextButton:SetEnabled(panel.customPage < pages)
        local function Turn(delta)
            panel.customPage = math.max(1, math.min(pages, panel.customPage + delta))
            local refresh = context.refreshPanel or context.refreshPage
            refresh()
        end
        previous:SetScript("OnClick", function() Turn(-1) end); nextButton:SetScript("OnClick", function() Turn(1) end)
        y = y + Theme.Size.standard + Theme.Space.sm
    end
    return y + Theme.Space.sm
end
function Addon:CreateSettingsPanel(parent, context)
    local panel = parent.ycuSettings or CreateFrame("Frame", nil, parent); parent.ycuSettings = panel; panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", parent, "TOPLEFT"); panel:SetWidth(parent:GetWidth()); panel:Show(); panel.rows = panel.rows or {}
    local y = 0
    Label(panel, "business", Addon:T("UI.BUSINESS_SETTINGS"), y); y = y + 28
    local transpose = panel.transpose or Theme:CreateCheckbox(panel, Addon:T("UI.HOVER_TRANSPOSE")); panel.transpose = transpose
    transpose:ClearAllPoints(); transpose:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); transpose:SetWidth(panel:GetWidth())
    transpose.label:SetWordWrap(true)
    transpose:SetHeight(math.max(Theme.Size.standard, transpose.label:GetStringHeight() + Theme.Space.sm))
    transpose:SetChecked(Addon:GetSettings().hoverTranspose == true); transpose:Show()
    transpose:SetScript("OnClick", function(control)
        local enabled = not Addon:GetSettings().hoverTranspose
        Addon:GetSettings().hoverTranspose = enabled; control:SetChecked(enabled)
        context.notifyPageChanged(); context.refreshPage()
    end)
    y = y + transpose:GetHeight() + Theme.Space.md
    Label(panel, "custom", Addon:T("CURRENCY.DATA_CACHE_CUSTOM_ITEM_TOKENS_E213AF"), y); y = y + 28
    local picker = panel.itemPicker
    if not picker then
        picker = Core:CreateItemPicker(panel, {
            resolve = { allowID = true, allowLink = true, allowName = true, match = "exact", includeBags = true,
                candidates = function() return Addon:GetCatalog() end },
            enterAction = "add", dropMode = "toggle",
            Exists = function(info) return FindCatalogItem(info.itemID) ~= nil end,
            add = {
                Validate = function(info)
                    if FindCatalogItem(info.itemID) then return false, Addon:T("CURRENCY.THIS_ITEM_IS_ALREADY_IN_THE_CURRENCY_CATALOG_52D88F") end
                    return true
                end,
                Confirm = function(info) return string.format(Addon:T("CURRENCY.ADD_S_ITEMID_S_TO_THE_CUSTOM_CURRENCY_CATALOG_A3D0C3"), info.name, info.itemID) end,
                Execute = function(info)
                    local entry, err = Addon:AddCustomItem(info.itemID)
                    if not entry then return false, err end
                    Addon:NotifyChanged()
                    return true, Addon:T("UI.CUSTOM_ADDED", entry.title)
                end,
            },
            remove = RemoveOperation,
        })
        panel.itemPicker = picker
    end
    picker.config.OnSuccess = function() context.notifyPageChanged(); context.refreshPage() end
    picker.config.OnLayoutChanged = context.refreshPanel or context.refreshPage
    local pickerHeight = picker:Layout(panel:GetWidth())
    y = CustomItemList(panel, picker, context, y)
    picker:ClearAllPoints(); picker:SetPoint("TOPLEFT", 0, -y); picker:Show()
    y = y + pickerHeight
    panel:SetHeight(y); return y
end
