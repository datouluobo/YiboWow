local Addon = _G.YiboBuilds
if not Addon then return end

local View = {}
Addon.EquipmentView = View
View.MainContentWidth = 1120
View.MinBuildPaneWidth = 720
View.RosterMaxWidth = 210

function View.SelectCharacter(characters, preferredID, currentID)
    local current
    for _, character in ipairs(characters) do
        if character.id == preferredID then return character end
        if character.id == currentID then current = character end
    end
    return current or characters[1]
end

function View.CharacterLabel(character, context)
    local core = _G.YiboCore
    return core.Characters:FormatName(character, {
        nameMode="short", realmMode=context and context.scope == "all" and "full" or "omit",
    }) or core:Text("CORE.UNKNOWN_CHARACTER")
end

function View.CreateCharacterSelector(parent, title, onSelect)
    local theme = _G.YiboCore.UITheme
    local roster = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    theme:ApplyPixelBackdrop(roster)
    local color = theme.Colors
    roster:SetBackdropColor(color.nav[1], color.nav[2], color.nav[3], 0.95)
    roster:SetBackdropBorderColor(unpack(color.lineSoft))
    local heading = theme:CreateText(roster, theme.Font.section, color.text)
    heading:SetPoint("TOPLEFT", theme.Space.sm, -theme.Space.sm)
    heading:SetText(title)
    local scroll = theme:CreateScrollFrame(roster)
    scroll:SetPoint("TOPLEFT", theme.Space.xs, -38)
    scroll:SetPoint("BOTTOMRIGHT", -theme.Space.xs, theme.Space.xs)
    local body = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(body)
    scroll:HookScript("OnSizeChanged", function() body:SetWidth(math.max(1, scroll:GetWidth())) end)
    local picker = theme:CreateDropdown(parent, 178, {})
    picker:SetMenuPageSize(8)
    picker:SetOnValueChanged(onSelect)
    roster.scroll, roster.body, roster.picker, roster.rows, roster.onSelect = scroll, body, picker, {}, onSelect
    return roster
end

function View.GetMainLayout(width, minPaneWidth, preferredRosterWidth)
    local theme = _G.YiboCore.UITheme
    local inset = theme:GetMatrixInsets(false)
    local rosterWidth = preferredRosterWidth or (width >= 1050 and View.RosterMaxWidth or (width >= 850 and 185 or 160))
    local left = inset.left + rosterWidth + theme.Space.sm
    if width - left - inset.right < (minPaneWidth or View.MinBuildPaneWidth) then rosterWidth, left = nil, inset.left end
    return {inset=inset, rosterWidth=rosterWidth, left=left, width=math.max(1, width-left-inset.right)}
end

function View.RenderCharacterSelector(roster, parent, layout, characters, selected, context)
    local theme = _G.YiboCore.UITheme
    local inset, width = layout.inset, layout.rosterWidth
    local picker = roster.picker
    roster:SetShown(width ~= nil and #characters > 0)
    picker:SetShown(width == nil and #characters > 0)
    if #characters == 0 then return end
    if not width then
        local entries = {}
        for index, character in ipairs(characters) do
            entries[index] = {value=character.id, label=View.CharacterLabel(character, context)}
        end
        picker:ClearAllPoints()
        picker:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
        picker:SetOptions(entries)
        picker:SetValue(selected and selected.id)
        return
    end
    roster:ClearAllPoints()
    roster:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    roster:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset.left, inset.bottom)
    roster:SetWidth(width)
    local rowHeight = 56
    roster.body:SetSize(math.max(1, roster.scroll:GetWidth()), #characters * rowHeight)
    roster.scroll:SetContentHeight(roster.body:GetHeight())
    for index, character in ipairs(characters) do
        local row = roster.rows[index]
        if not row then
            row = theme:CreateButton(roster.body, 1, "", "secondary")
            row.classIcon = row:CreateTexture(nil, "ARTWORK")
            row.classIcon:SetSize(30, 30)
            row.classIcon:SetPoint("LEFT", 7, 0)
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row.classIcon, "RIGHT", 8, 0)
            row.label:SetPoint("RIGHT", -30, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)
            row.level = theme:CreateText(row, theme.Font.assist, theme.Colors.muted, "RIGHT")
            row.level:SetPoint("RIGHT", -8, 0)
            row:HookScript("OnEnter", function(self)
                if not self.label:IsTruncated() then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self.label:GetText())
                GameTooltip:Show()
            end)
            local function HideName(self)
                if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end
            row:HookScript("OnLeave", HideName)
            row:SetScript("OnHide", HideName)
            row:SetScript("OnClick", function(self) roster.onSelect(self.characterID) end)
            roster.rows[index] = row
        end
        row.characterID = character.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", roster.body, "TOPLEFT", 0, -(index - 1) * rowHeight)
        row:SetPoint("RIGHT", roster.body, "RIGHT", 0, 0)
        row:SetHeight(rowHeight - 2)
        row:SetText(View.CharacterLabel(character, context))
        row.level:SetText(character.level or "")
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.class]
        if coords then
            row.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            row.classIcon:SetTexCoord(unpack(coords))
        end
        row.classIcon:SetShown(coords ~= nil)
        row:SetState(selected and character.id == selected.id and "selected" or "default")
        local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        local classColor = colors and colors[character.class]
        if classColor then row.label:SetTextColor(classColor.r, classColor.g, classColor.b) end
        row:Show()
    end
    for index = #characters + 1, #roster.rows do roster.rows[index]:Hide() end
end

function View.CreateEquipmentPane(parent)
    local color = _G.YiboCore.UITheme.Colors.bg
    local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pane:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
    pane:SetBackdropColor(color[1], color[2], color[3], 0.55)
    return pane
end

function View.SplitEquipmentPane(width)
    local gap = _G.YiboCore.UITheme.Space.sm
    local equipment = math.floor((width - gap) * 0.55)
    return equipment, equipment + gap, width - equipment - gap
end

function View.LayoutEquipmentPane(pane, width, availableHeight, anchor, anchorPoint, y)
    local height = math.max(300, availableHeight)
    pane:ClearAllPoints()
    pane:SetPoint("TOPLEFT", anchor, anchorPoint, 0, y)
    pane:SetSize(width, height)
    return height
end

function View.PaperDollSlots(weapons)
    local left = {1, 2, 3, 15, 5, 4, 19, 9}
    local right = {10, 6, 7, 8, 11, 12, 13, 14}
    local slots, positions = {}, {}
    for _, group in ipairs({{side="left", slots=left}, {side="right", slots=right}, {side="weapon", slots=weapons}}) do
        for index, slot in ipairs(group.slots) do
            slots[#slots + 1] = slot
            positions[slot] = {side=group.side, index=index}
        end
    end
    return slots, positions
end

function View.EquipmentPreviewRowHeight()
    return _G.YiboCore.UITheme.Table.previewRowHeight + 16
end

local function PreviewModeWidth(theme, option)
    return math.max(82, math.ceil(theme:MeasureText(theme.Font.body, option.label)) + 12)
end

function View.GetPreviewModesWidth(options)
    local theme, width = _G.YiboCore.UITheme, -4
    for _, option in ipairs(options) do width = width + PreviewModeWidth(theme, option) + 4 end
    return width
end

function View.RenderPreviewModes(strip, options, selectedID, onSelect, context)
    local theme = _G.YiboCore.UITheme
    local buttons = strip.buttons or {}
    strip.buttons = buttons
    local width = -4
    for index, option in ipairs(options) do
        local buttonWidth = PreviewModeWidth(theme, option)
        local button = buttons[index] or theme:CreateButton(strip, buttonWidth, "", "disclosure")
        buttons[index] = button
        button:SetSize(buttonWidth, theme.Size.compact)
        width = width + buttonWidth + 4
        button:ClearAllPoints()
        if index == 1 then button:SetPoint("LEFT")
        else button:SetPoint("LEFT", buttons[index - 1], "RIGHT", 4, 0) end
        local selected = option.id == selectedID
        button:SetText(option.label)
        button:SetState(selected and "selected" or "default")
        button.label:SetTextColor(unpack(selected and theme.Colors.accent or theme.Colors.text))
        button:SetScript("OnClick", function() onSelect(option) end)
        button:Show()
    end
    for index = #options + 1, #buttons do buttons[index]:Hide() end
    strip:SetSize(width, theme.Size.compact)
    if context and context.SetTitleBarControl then
        context:SetTitleBarControl(strip, width)
    else
        strip:Hide()
    end
end

function View.ItemQualityColor(link, quality)
    if type(link) == "string" then
        local red, green, blue = link:match("^|c%x%x(%x%x)(%x%x)(%x%x)")
        if red then return tonumber(red, 16) / 255, tonumber(green, 16) / 255, tonumber(blue, 16) / 255 end
        quality = tonumber(link:match("^|cnIQ(%d+):")) or quality
    end
    if type(quality) ~= "number" then return end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r or color[1], color.g or color[2], color.b or color[3] end
    if GetItemQualityColor then return GetItemQualityColor(quality) end
end

function View.CreatePaperDollItemLevel(parent)
    local theme = _G.YiboCore.UITheme
    local label = theme:CreateText(parent, theme.Font.section, {0.78, 0.62, 1}, "RIGHT")
    label:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 2)
    label:SetHeight(18)
    label:SetFont(STANDARD_TEXT_FONT, theme.Font.section, "OUTLINE")
    label:SetDrawLayer("OVERLAY", 7)
    label:Hide()
    return label
end

function View.RenderPaperDollItemLevel(label, level, size)
    label:SetWidth(math.max(1, size - 6))
    label:SetText(level or "")
    label:SetShown(level ~= nil and level ~= "")
end

function View.FitEquipmentColumns(columns, availableWidth)
    local count = #columns - 1
    if count == 0 then return end
    local gaps = 0
    for index = 2, #columns do
        if columns[index].gapAfter then gaps = gaps + 1 end
    end
    local nameWidth = columns[1].width
    local fitWidth = availableWidth or nameWidth + count * 40 + gaps * 6
    local gap = fitWidth - nameWidth >= count * 40 + gaps * 6 and 6 or 4
    nameWidth = math.min(nameWidth, math.max(92, fitWidth - count * 32 - gaps * gap))
    columns[1].width = nameWidth
    local itemWidth = math.max(1, math.min(40, math.floor((fitWidth - nameWidth - gaps * gap) / count)))
    for index = 2, #columns do
        local column = columns[index]
        column.width = itemWidth
        if column.gapAfter then column.gapAfter = gap end
    end
end

function View.RenderPreviewHeader(header, columns)
    local theme = _G.YiboCore.UITheme
    header.columns = header.columns or {}
    local x, height = 0, theme.Table.headerHeight
    for index, column in ipairs(columns) do
        local cell = header.columns[index] or theme:CreateMatrixHeader(header)
        header.columns[index] = cell
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", header, "TOPLEFT", x, 0)
        cell:SetSize(column.width, height)
        theme:SetMatrixHeader(cell, column.title, {height=height, inset=2})
        cell:Show()
        column.x = x
        x = x + column.width + (column.gapAfter or 0)
    end
    for index = #columns + 1, #header.columns do header.columns[index]:Hide() end
    header:SetSize(x, height)
    return x
end

function View.CreatePreviewItem(cell)
    local theme = _G.YiboCore.UITheme
    local frame = CreateFrame("Frame", nil, cell, "BackdropTemplate")
    frame:SetPoint("CENTER")
    theme:ApplyPixelBackdrop(frame, {background=false})
    frame:EnableMouse(false)
    frame:Hide()
    cell.itemFrame = frame
    cell.itemIcon = frame:CreateTexture(nil, "ARTWORK")
    cell.itemIcon:SetPoint("TOPLEFT", 2, -2)
    cell.itemIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    cell.itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    cell.itemLevel = theme:CreateText(frame, theme.Font.body, theme.Colors.text, "CENTER")
    cell.itemLevel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)
    cell.itemLevel:SetHeight(15)
    cell.itemLevel:SetJustifyV("BOTTOM")
    cell.itemLevel:SetDrawLayer("OVERLAY", 7)
    cell.itemChanged = theme:CreateText(frame, theme.Font.body, theme.Colors.warning, "RIGHT")
    cell.itemChanged:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -1)
    cell.itemChanged:SetSize(14, 16)
    cell.itemChanged:SetText("!")
    cell.itemChanged:SetDrawLayer("OVERLAY", 7)
end

function View.RenderPreviewItem(cell, size, icon, color, level, changed)
    local theme = _G.YiboCore.UITheme
    local equipped = icon ~= nil
    if not equipped then color = theme.Colors.muted end
    cell.itemFrame:SetSize(size, size)
    cell.itemFrame:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    cell.itemIcon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    cell.itemIcon:SetDesaturated(not equipped)
    if equipped then cell.itemIcon:SetVertexColor(1, 1, 1, 1)
    else cell.itemIcon:SetVertexColor(0.45, 0.5, 0.5, 0.65) end
    cell.itemLevel:SetWidth(size)
    cell.itemLevel:SetText(level or "")
    cell.itemLevel:SetShown(equipped and level ~= nil and level ~= "")
    cell.itemChanged:SetShown(not not changed)
    cell.itemFrame:Show()
end

function View.GetPaperDollLayout(width, height)
    local theme = _G.YiboCore.UITheme
    local header = theme.Size.standard + 12
    local weaponBottom = 24
    local rowStep = math.max(1, math.floor((height - header - weaponBottom - 20) / 9))
    local iconSize = math.max(1, math.min(42, rowStep - 4, math.floor(width * 0.15)))
    local inset = math.min(42, math.floor(width * 0.12))
    return {header=header, step=rowStep, iconSize=iconSize, inset=inset, weaponBottom=weaponBottom}
end

function View.CreateSlotLabel(button)
    local theme = _G.YiboCore.UITheme
    local label = theme:CreateText(button, theme.Font.meta, theme.Colors.muted, "RIGHT")
    label:SetWordWrap(false)
    return label
end

function View.AnchorEquipmentSlot(button, layout, side, index, weaponCount)
    button:ClearAllPoints()
    button:SetSize(layout.iconSize, layout.iconSize)
    if side == "left" or side == "right" then
        local left = side == "left"
        button:SetPoint(left and "TOPLEFT" or "TOPRIGHT", left and layout.inset or -layout.inset,
            -layout.header - (index - 1) * layout.step)
    else
        local gap = _G.YiboCore.UITheme.Space.sm
        local x = (index - (weaponCount + 1) / 2) * (layout.iconSize + gap)
        button:SetPoint("BOTTOM", x, layout.weaponBottom)
    end
    local label = button.slotLabel
    label:ClearAllPoints()
    label:SetWidth(math.max(1, layout.inset - 6))
    if side == "left" then
        label:SetPoint("RIGHT", button, "LEFT", -4, 0)
        label:SetJustifyH("RIGHT")
    elseif side == "right" then
        label:SetPoint("LEFT", button, "RIGHT", 4, 0)
        label:SetJustifyH("LEFT")
    else
        label:SetPoint("TOP", button, "BOTTOM", 0, -4)
        label:SetJustifyH("CENTER")
    end
end

function View.CreateAppearanceToggle(parent)
    return _G.YiboCore.UITheme:CreateButton(parent, 120, "", "secondary")
end

local function ApplyModelZoom(model)
    if model.SetCamDistanceScale then model:SetCamDistanceScale(model.buildsZoom)
    elseif model.SetModelScale then model:SetModelScale(1 / model.buildsZoom) end
end

function View.RestoreModelView(model)
    if model.buildsFacing and model.SetFacing then model:SetFacing(model.buildsFacing) end
    if model.buildsZoom then ApplyModelZoom(model) end
end

function View.CreateModelControl(parent, model)
    local control = CreateFrame("Frame", nil, parent)
    control:SetFrameLevel(model:GetFrameLevel() + 1)
    control:EnableMouse(true)
    control:EnableMouseWheel(true)
    control:RegisterForDrag("LeftButton")
    control:SetScript("OnDragStart", function(self) self.lastCursorX = GetCursorPosition() end)
    control:SetScript("OnDragStop", function(self) self.lastCursorX = nil end)
    control:SetScript("OnHide", function(self) self.lastCursorX = nil end)
    control:SetScript("OnUpdate", function(self)
        if not self.lastCursorX then return end
        local x = GetCursorPosition()
        local delta = (x - self.lastCursorX) / self:GetEffectiveScale()
        self.lastCursorX = x
        model.buildsFacing = (model.buildsFacing or (model.GetFacing and model:GetFacing()) or 0) + delta * 0.012
        if model.SetFacing then model:SetFacing(model.buildsFacing) end
    end)
    control:SetScript("OnMouseWheel", function(_, delta)
        model.buildsZoom = math.max(0.65, math.min(1.55, (model.buildsZoom or 1) - delta * 0.08))
        ApplyModelZoom(model)
    end)
    return control
end

function View.LayoutModel(panel, model, control, toggle, layout)
    local inset = layout.inset + layout.iconSize + 12
    toggle:ClearAllPoints()
    toggle:SetPoint("TOP", panel, "TOP", 0, -4)
    if not model then return end
    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -layout.header)
    model:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -inset, layout.weaponBottom + layout.iconSize + 4)
    control:ClearAllPoints()
    control:SetAllPoints(model)
end
