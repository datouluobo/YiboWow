local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Theme = Core.UITheme
local CATALOG_PAGE_SIZE = 24

local function FindCatalogItem(itemID)
    for _, entry in ipairs(Addon:GetCatalog()) do
        if tonumber(entry.itemID) == itemID then return entry end
    end
end

local RemoveOperation = {
    label = Addon:T("UI.CATALOG_REMOVE"),
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
local function RefreshSettings(context)
    local refresh = context.refreshPanel or context.refreshPage
    if refresh then refresh() end
end

local function ItemPicker(panel, context)
    local picker = panel.itemPicker
    if not picker then
        picker = Core:CreateItemPicker(panel, {
            resolve = { allowID = true, allowLink = true, allowName = true, match = "exact", includeBags = true,
                candidates = function() return Addon:GetCatalog() end },
            enterAction = "add", dropMode = "add",
            Exists = function(info) return FindCatalogItem(info.itemID) ~= nil end,
            add = {
                label = Addon:T("UI.CATALOG_ADD"),
                Validate = function(info)
                    if FindCatalogItem(info.itemID) then return false, Addon:T("CURRENCY.THIS_ITEM_IS_ALREADY_IN_THE_CURRENCY_CATALOG_52D88F") end
                    return true
                end,
                Confirm = function(info) return Addon:T("CURRENCY.ADD_S_ITEMID_S_TO_THE_CUSTOM_CURRENCY_CATALOG_A3D0C3", info.name, info.itemID) end,
                Execute = function(info)
                    local entry, err = Addon:AddCustomItem(info.itemID)
                    if not entry then return false, err end
                    panel.catalogFilter = "custom"
                    panel.catalogPage = math.max(1, math.ceil(#Addon:GetSettings().customItems / CATALOG_PAGE_SIZE))
                    panel.pendingCatalogID = entry.id
                    Addon:NotifyChanged()
                    return true, Addon:T("UI.CUSTOM_ADDED", entry.title)
                end,
            },
            remove = RemoveOperation,
        })
        panel.itemPicker = picker
    end
    picker.config.OnSuccess = function()
        context.notifyPageChanged(); RefreshSettings(context)
        -- Success feedback can change the page capacity before this final layout.
        panel.pendingCatalogID = nil
    end
    picker.config.OnLayoutChanged = function() RefreshSettings(context) end
    return picker
end

local function CatalogList(panel, picker, context, y, reservedHeight)
    panel.catalogFilter = panel.catalogFilter or "builtin"
    local catalog, lists = Addon:GetCatalog(), { builtin = {}, custom = {} }
    for _, entry in ipairs(catalog) do
        local list = entry.isCustom and lists.custom or lists.builtin
        list[#list + 1] = entry
    end
    panel.catalogTabs = panel.catalogTabs or {}
    local x = 0
    for _, id in ipairs({ "builtin", "custom" }) do
        local text = Addon:T(id == "builtin" and "UI.CATALOG_BUILTIN" or "UI.CATALOG_CUSTOM", #lists[id])
        local width = math.min(Theme:MeasureText(Theme.Font.body, text) + Theme.Space.xl, math.max(1, (picker.layoutContentWidth - Theme.Space.sm) / 2))
        local tab = panel.catalogTabs[id] or Theme:CreateButton(panel, width, text, "secondary")
        panel.catalogTabs[id] = tab
        tab:ClearAllPoints(); tab:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y); tab:SetWidth(width); tab:SetText(text)
        tab:SetState(panel.catalogFilter == id and "selected" or "default"); tab:Show()
        Theme:BindTooltip(tab, text, {})
        tab:SetScript("OnClick", function() panel.catalogFilter, panel.catalogPage, panel.pendingCatalogID = id, 1, nil; RefreshSettings(context) end)
        x = x + width + Theme.Space.sm
    end
    y = y + Theme.Size.standard + Theme.Space.sm
    local entries = lists[panel.catalogFilter]
    local size, gap, width = CATALOG_PAGE_SIZE, Theme.Space.md, math.max(1, picker.layoutContentWidth)
    local mainWidth = math.max(48, Theme:MeasureText(Theme.Font.assist, Addon:T("UI.DISPLAY_MAIN")) + Theme.Space.md)
    local hoverWidth = math.max(48, Theme:MeasureText(Theme.Font.assist, Addon:T("UI.DISPLAY_HOVER")) + Theme.Space.md)
    local columns = width >= (200 + mainWidth + hoverWidth) * 2 + gap and 2 or 1
    if context.availableHeight then
        local chrome = Theme.Size.compact + Theme.Size.standard + Theme.Space.sm * 2 + Theme.Space.md
        local linesAvailable = math.max(1, math.floor((context.availableHeight - y - chrome - reservedHeight) / Theme.Size.standard))
        size = math.min(size, linesAvailable * columns)
    end
    if panel.pendingCatalogID then
        for index, entry in ipairs(entries) do
            if entry.id == panel.pendingCatalogID then panel.catalogPage = math.floor((index - 1) / size) + 1; break end
        end
    end
    panel.catalogPageSize = size
    local groupWidth = (width - (columns - 1) * gap) / columns
    local nameWidth = math.max(1, groupWidth - mainWidth - hoverWidth)
    panel.catalogHeaders = panel.catalogHeaders or {}
    for column = 1, 2 do
        local header = panel.catalogHeaders[column] or {}
        panel.catalogHeaders[column] = header
        for index, definition in ipairs({ { "UI.CATALOG_NAME", 0, nameWidth, "LEFT" },
            { "UI.DISPLAY_MAIN", nameWidth, mainWidth, "CENTER" }, { "UI.DISPLAY_HOVER", nameWidth + mainWidth, hoverWidth, "CENTER" } }) do
            local label = header[index] or Theme:CreateText(panel, Theme.Font.assist, Theme.Colors.muted, definition[4])
            header[index] = label
            label:ClearAllPoints(); label:SetPoint("TOPLEFT", panel, "TOPLEFT", (column - 1) * (groupWidth + gap) + definition[2], -y)
            label:SetWidth(definition[3]); label:SetText(Addon:T(definition[1])); label:SetShown(column <= columns)
        end
    end
    y = y + Theme.Size.compact
    local pages = math.max(1, math.ceil(#entries / size))
    panel.catalogPage = math.max(1, math.min(panel.catalogPage or 1, pages))
    local first = (panel.catalogPage - 1) * size + 1
    local count = math.min(size, math.max(0, #entries - first + 1))
    local lines = math.ceil(count / columns)
    panel.rows = panel.rows or {}
    for used = 1, count do
        local entry = entries[first + used - 1]
        local row = panel.rows[used] or CreateFrame("Button", nil, panel, "BackdropTemplate")
        panel.rows[used] = row; row.entry, row.itemID = entry, entry.itemID
        local column, line = math.floor((used - 1) / lines), (used - 1) % lines
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", panel, "TOPLEFT", column * (groupWidth + gap), -y - line * Theme.Size.standard); row:SetSize(groupWidth, Theme.Size.standard)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); row:SetBackdropColor(unpack(Theme:GetDataRowColor(line + 1)))
        row.label = row.label or Theme:CreateText(row, Theme.Font.body, Theme.Colors.text, "LEFT")
        row.label:ClearAllPoints(); row.label:SetPoint("LEFT", row, "LEFT", Theme.Space.xs, 0); row.label:SetWidth(math.max(1, nameWidth - Theme.Space.sm)); row.label:SetWordWrap(false)
        row.label:SetText("|T" .. tostring(Addon:GetIcon(entry)) .. ":16:16:0:0|t " .. entry.title); row.label:Show()
        for _, surface in ipairs({ "main", "hover" }) do
            local control = row[surface] or Theme:CreateCheckbox(row, ""); row[surface] = control
            local offset = surface == "main" and nameWidth + (mainWidth - 16) / 2 or nameWidth + mainWidth + (hoverWidth - 16) / 2
            control:ClearAllPoints(); control:SetPoint("LEFT", row, "LEFT", offset, 0); control:SetWidth(24)
            control:SetChecked(surface == "main" and Addon:IsVisible(entry) or surface == "hover" and Addon:IsMonitored(entry)); control:Show()
            control:SetScript("OnClick", function(button)
                local enabled = surface == "main" and not Addon:IsVisible(entry) or surface == "hover" and not Addon:IsMonitored(entry)
                Addon:SetCurrencyDisplay(entry.id, surface, enabled); button:SetChecked(enabled)
                RefreshSettings(context)
            end)
            Theme:BindTooltip(control, entry.title, { Addon:T(surface == "main" and "UI.DISPLAY_MAIN_HINT" or "UI.DISPLAY_HOVER_HINT") })
        end
        row:SetScript("OnClick", entry.isCustom and function() picker:SetValue(tostring(entry.itemID)) end or nil)
        Theme:BindTooltip(row, entry.title, { entry.isCustom and Addon:T("UI.CATALOG_SELECT_CUSTOM", tostring(entry.itemID)) or Addon:T("UI.CATALOG_BUILTIN_HINT") })
        row:Show()
    end
    for index = count + 1, #panel.rows do panel.rows[index]:Hide() end
    local empty = Label(panel, "catalogEmpty", Addon:T("UI.CUSTOM_ITEMS_EMPTY"), y, Theme.Colors.muted)
    empty:SetShown(count == 0)
    y = y + math.max(1, lines) * Theme.Size.standard + Theme.Space.sm
    if not panel.catalogPrevious then
        panel.catalogPrevious = Theme:CreateButton(panel, 40, "<", "secondary")
        panel.catalogNext = Theme:CreateButton(panel, 40, ">", "secondary")
        panel.catalogPageLabel = Theme:CreateText(panel, Theme.Font.assist, Theme.Colors.muted, "CENTER")
    end
    local previous, nextButton, pageLabel = panel.catalogPrevious, panel.catalogNext, panel.catalogPageLabel
    previous:SetShown(pages > 1); nextButton:SetShown(pages > 1); pageLabel:SetShown(pages > 1)
    if pages > 1 then
        previous:ClearAllPoints(); previous:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
        pageLabel:ClearAllPoints(); pageLabel:SetPoint("LEFT", previous, "RIGHT", Theme.Space.sm, 0); pageLabel:SetWidth(100); pageLabel:SetText(Addon:T("UI.PAGE", panel.catalogPage, pages))
        nextButton:ClearAllPoints(); nextButton:SetPoint("LEFT", pageLabel, "RIGHT", Theme.Space.sm, 0)
        previous:SetEnabled(panel.catalogPage > 1); nextButton:SetEnabled(panel.catalogPage < pages)
        previous:SetScript("OnClick", function() panel.catalogPage = panel.catalogPage - 1; RefreshSettings(context) end)
        nextButton:SetScript("OnClick", function() panel.catalogPage = panel.catalogPage + 1; RefreshSettings(context) end)
        y = y + Theme.Size.standard + Theme.Space.sm
    end
    return y + Theme.Space.md
end

function Addon:CreateSettingsPanel(parent, context)
    local panel = parent.ycuSettings or CreateFrame("Frame", nil, parent); parent.ycuSettings = panel
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", parent, "TOPLEFT"); panel:SetWidth(parent:GetWidth()); panel:Show()
    local picker = ItemPicker(panel, context)
    local pickerHeight = picker:Layout(panel:GetWidth())
    local transpose = panel.transpose or Theme:CreateCheckbox(panel, Addon:T("UI.HOVER_TRANSPOSE")); panel.transpose = transpose
    transpose:SetWidth(panel:GetWidth())
    transpose.label:SetWordWrap(true); transpose:SetHeight(math.max(Theme.Size.standard, transpose.label:GetStringHeight() + Theme.Space.sm))
    transpose:SetChecked(Addon:GetSettings().hoverTranspose == true); transpose:Show()
    transpose:SetScript("OnClick", function(control)
        local enabled = not Addon:GetSettings().hoverTranspose
        Addon:GetSettings().hoverTranspose = enabled; control:SetChecked(enabled)
        context.notifyPageChanged(); RefreshSettings(context)
    end)
    local note = Label(panel, "catalogHelp", Addon:T("UI.CATALOG_MANAGE_HINT"), 0, Theme.Colors.muted)
    note:SetWidth(picker.layoutContentWidth); note:SetWordWrap(true)
    local reservedHeight = Theme.Size.standard * 2 + transpose:GetHeight() + Theme.Space.md + note:GetStringHeight() + Theme.Space.sm + pickerHeight
    local y = 0
    Label(panel, "display", Addon:T("UI.CATALOG_DISPLAY"), y); y = y + Theme.Size.standard
    y = CatalogList(panel, picker, context, y, panel.catalogFilter == "custom" and reservedHeight or 0)
    if panel.catalogFilter ~= "custom" then
        transpose:Hide(); picker:Hide()
        for _, key in ipairs({ "business", "custom", "catalogHelp" }) do
            if panel.ycuLabels[key] then panel.ycuLabels[key]:Hide() end
        end
        panel:SetHeight(y); return y
    end
    Label(panel, "business", Addon:T("UI.BUSINESS_SETTINGS"), y); y = y + Theme.Size.standard
    transpose:ClearAllPoints(); transpose:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); transpose:Show()
    y = y + transpose:GetHeight() + Theme.Space.md
    Label(panel, "custom", Addon:T("UI.CATALOG_MANAGE"), y); y = y + Theme.Size.standard
    note:ClearAllPoints(); note:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); note:Show()
    y = y + note:GetStringHeight() + Theme.Space.sm
    picker:ClearAllPoints(); picker:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y); picker:Show()
    y = y + pickerHeight
    panel:SetHeight(y); return y
end
