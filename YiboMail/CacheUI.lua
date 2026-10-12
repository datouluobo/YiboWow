local Addon = _G.YiboMail
local UI = {}; Addon.CacheUI = UI
local Core, Theme, View, Model = _G.YiboCore, _G.YiboCore.UITheme, Addon.ViewModel, Addon.CacheModel
local function Text(parent, size, color)
    local control = Theme:CreateText(parent, size or Theme.Font.body, color or Theme.Colors.text, "LEFT")
    control:SetWordWrap(false); return control
end
local function Place(control, x, y, width, height)
    control:ClearAllPoints(); control:SetPoint("TOPLEFT", x, -y); control:SetSize(math.max(1, width), math.max(1, height))
end
local function Escape(value) return View:Escape(value or "") end
local function Name(character) return Core.Characters:FormatName(character, { nameMode = "short" }) or Addon:T("UI.TEXT_0400") end
local function Identity(character, full) return View:CharacterLabel(character, full) end
local function Counterpart(address, owner) return View:CounterpartLabel(address, owner) end
local function Stamp(time) return time and date("%m-%d %H:%M", time) or Addon:T("UI.TEXT_0373") end
local function Enable(button, enabled)
    button:SetEnabled(enabled); button:SetState(enabled and "default" or "disabled")
end
local function Tooltip(control, lines, item, wrap)
    control:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        if item and item.itemLink and item.itemLink ~= "" then GameTooltip:SetHyperlink(item.itemLink)
        elseif item and item.itemID then GameTooltip:SetHyperlink("item:" .. tostring(item.itemID))
        else GameTooltip:SetText(lines[1] or Addon:T("UI.TEXT_0589")) end
        for index = item and 1 or 2, #lines do GameTooltip:AddLine(lines[index], 1, 1, 1, wrap ~= false) end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
function UI:AttachmentTooltip(group)
    local lines = { Escape(group.item.name or (Addon:T("UI.TEXT_0453") .. tostring(group.item.itemID))),
        Addon:T("UI.TEXT_0201") .. group.quantity .. Addon:T("UI.TEXT_0114") .. group.mailCount .. Addon:T("UI.TEXT_0240"),
        Addon:T("UI.TEXT_0378") .. group.normalQuantity .. Addon:T("UI.TEXT_0003") .. group.codQuantity }
    for _, source in ipairs(group.sources) do
        local entry = source.entry
        lines[#lines + 1] = Addon:T("UI.TEXT_0608") .. Identity(entry.character, true) .. Addon:T("UI.TEXT_0005") .. Escape(entry.mail.sender)
            .. " · ×" .. source.item.quantity .. " · " .. View:Expiry(entry.mail)
    end
    return lines
end
function UI:Create(parent)
    local root = CreateFrame("Frame", nil, parent); root:SetAllPoints(); parent.mailWorkspace = root
    root.parent, root.rows, root.tiles, root.ownerRows, root.detailRows = parent, {}, {}, {}, {}
    local function Refresh() if root.context then UI:Refresh(parent, root.context) end end
    root.refresh = Refresh
    local function Button(label, callback, width)
        local control = Theme:CreateButton(root, width or 100, label, "secondary")
        control:SetScript("OnClick", callback); return control
    end
    root.tabs = Theme:CreateBusinessTabs(root, {
        { id = "inbox", title = Addon:T("UI.TEXT_0344"), width = 112 }, { id = "overview", title = Addon:T("UI.TEXT_0564"), width = 126 },
        { id = "history", title = Addon:T("UI.TEXT_0170"), width = 126 },
    }, function(id) Addon.WorkspaceState:Get().tab = id; root.notice = nil; Refresh() end)
    root.heading = Text(root, Theme.Font.section)
    root.note = Text(root, Theme.Font.assist, Theme.Colors.muted)
    root.search = Theme:CreateInput(root, {
        width = 260, placeholder = Addon:T("UI.TEXT_0129"), maxLetters = 120, clearable = true,
        OnChanged = function(value)
            if root.syncing then return end
            root.searchQuery = value
            local state = Addon.WorkspaceState:Get()
            if state.tab == "inbox" then Addon.WorkspaceState:Search(value)
            else state.history.search, state.history.scroll, state.history.anchor, state.history.detail = value, 0, nil, nil end
            Refresh()
        end,
    })
    root.clear = Button(Addon:T("UI.TEXT_0445"), function()
        local workspace = Addon.WorkspaceState:Get()
        if workspace.tab == "inbox" then
            Addon.WorkspaceState:Search("")
            workspace.inbox.kind, workspace.inbox.risk, workspace.inbox.scope = "all", "all", "latest"
        else
            workspace.history.search, workspace.history.kind, workspace.history.result = "", "all", "all"
            workspace.history.character, workspace.history.days, workspace.history.scroll, workspace.history.detail = nil, 30, 0, nil
        end
        local state = workspace[workspace.tab]; state.scroll, state.anchor, state.anchorOffset = 0, nil, nil
        Refresh()
    end)
    root.mail = Button(Addon:T("UI.TEXT_0322"), function() local s = Addon.WorkspaceState:Get().inbox; s.mode, s.scroll, s.detail, s.detailReturn, s.anchor = "mail", 0, nil, nil, nil; Refresh() end, 84)
    root.items = Button(Addon:T("UI.TEXT_0634"), function() local s = Addon.WorkspaceState:Get().inbox; s.mode, s.scroll, s.detail, s.detailReturn, s.anchor = "items", 0, nil, nil, nil; Refresh() end, 96)
    local function Dropdown(choices, key, width)
        local control = Theme:CreateDropdown(root, width or 140, choices)
        control:SetOnValueChanged(function(value)
            local workspace = Addon.WorkspaceState:Get(); local state = workspace[workspace.tab]
            if key == "character" then state[key] = value ~= "all" and value or nil
            else state[key] = value end
            state.scroll, state.detail, state.detailReturn, state.anchor, state.anchorOffset = 0, nil, nil, nil, nil; Refresh()
        end)
        return control
    end
    root.scope = Dropdown({ { value = "latest", label = Addon:T("UI.TEXT_0390") }, { value = "unverified", label = Addon:T("UI.TEXT_0290") } }, "scope", 148)
    root.kind = Dropdown({}, "kind", 134)
    root.risk = Dropdown({ { value = "all", label = Addon:T("UI.TEXT_0638") }, { value = "urgent", label = Addon:T("UI.TEXT_0062") },
        { value = "soon", label = Addon:T("UI.TEXT_0061") }, { value = "threeDays", label = Addon:T("UI.TEXT_0084") },
        { value = "sevenDays", label = Addon:T("UI.TEXT_0083") }, { value = "attention", label = Addon:T("UI.TEXT_0133") },
        { value = "expired", label = Addon:T("UI.TEXT_0159") }, { value = "unknown", label = Addon:T("UI.TEXT_0398") } }, "risk", 150)
    root.sort = Dropdown({ { value = "expiry", label = Addon:T("UI.TEXT_0098") }, { value = "character", label = Addon:T("UI.TEXT_0508") } }, "sort", 154)
    root.days = Dropdown({ { value = 7, label = Addon:T("UI.TEXT_0573") }, { value = 30, label = Addon:T("UI.TEXT_0572") }, { value = 90, label = Addon:T("UI.TEXT_0574") }, { value = 0, label = Addon:T("UI.TEXT_0124") } }, "days", 160)
    root.historyCharacter = Dropdown({}, "character", 190)
    root.historyCharacter:SetMenuPageSize(8)
    root.result = Dropdown({ { value = "all", label = Addon:T("UI.TEXT_0488") }, { value = "collected-archived", label = Addon:T("UI.TEXT_0251") },
        { value = "in-transit", label = Addon:T("UI.TEXT_0246") }, { value = "unverified", label = Addon:T("UI.TEXT_0289") },
        { value = "received-confirmed", label = Addon:T("UI.TEXT_0464") }, { value = "return-confirmed", label = Addon:T("UI.TEXT_0468") } }, "result", 154)
    root.summary = Text(root, Theme.Font.assist)
    root.tableHeader = CreateFrame("Frame", nil, root); root.tableHeader.cells = {}
    root.tableHeader.background = root.tableHeader:CreateTexture(nil, "BACKGROUND"); root.tableHeader.background:SetAllPoints()
    root.tableHeader.background:SetColorTexture(unpack(Theme.Colors.toolbar))
    root.empty = Text(root, Theme.Font.body, Theme.Colors.muted); root.empty:SetWordWrap(true)
    root.owners = Theme:CreateScrollFrame(root)
    root.ownersContent = CreateFrame("Frame", nil, root.owners); root.owners:SetScrollChild(root.ownersContent)
    root.list = Theme:CreateScrollFrame(root)
    root.listContent = CreateFrame("Frame", nil, root.list); root.list:SetScrollChild(root.listContent)
    root.list:HookScript("OnVerticalScroll", function(_, offset)
        if not root.listLayout or not root.list:IsShown() then return end
        UI:RenderList(root, offset)
        if root.syncing then return end
        local state = Addon.WorkspaceState:Get()[root.renderedTab]
        local layout = root.listLayout
        local index, start = UI:ListIndex(layout, offset)
        state.scroll, state.anchorOffset = offset, offset - start
        state.anchor = root.data[index] and root.data[index].id
    end)
    root.detail = Theme:CreateScrollFrame(root); root.detailContent = CreateFrame("Frame", nil, root.detail); root.detail:SetScrollChild(root.detailContent)
    root.detail:HookScript("OnVerticalScroll", function(_, offset)
        if root.syncing then return end
        local workspace = Addon.WorkspaceState:Get(); local state = workspace[workspace.tab]
        if state.detail then state.detailScroll = offset end
    end)
    root.overview = CreateFrame("Frame", nil, root); Addon.AccountPage:CreateSummary(root.overview)
    root.overview.pageState = Addon.WorkspaceState:Get().overview
    root.overview.onCharacter = function(id, risk) Addon.WorkspaceState:Locate(id, risk); Refresh() end
    root.overview.mailAlert.action:SetScript("OnClick", function()
        Addon.WorkspaceState:Locate(nil, root.overview.alertExpired and "expired" or "sevenDays"); Refresh()
    end)
    root.overview.mailAlert.action:SetText(Addon:T("UI.TEXT_0415"))
    root.previous = Button(Addon:T("UI.TEXT_0087"), function() local s = Addon.WorkspaceState:Get(); s[s.tab].page = s[s.tab].page - 1; s[s.tab].anchor = nil; Refresh() end, 90)
    root.next = Button(Addon:T("UI.TEXT_0090"), function() local s = Addon.WorkspaceState:Get(); s[s.tab].page = s[s.tab].page + 1; s[s.tab].anchor = nil; Refresh() end, 90)
    root.pages = Text(root, Theme.Font.assist, Theme.Colors.muted)
    root.back = Button(Addon:T("UI.TEXT_0575"), function()
        local workspace = Addon.WorkspaceState:Get(); local s = workspace[workspace.tab]
        if s.detail then
            s.detail, s.detailScroll = s.detailReturn, s.detailReturnScroll or 0
            s.detailReturn, s.detailReturnScroll, s.detailPage = nil, nil, 1
        else Addon.WorkspaceState:Return() end
        root.notice = nil; Refresh()
    end, 72)
    root:HookScript("OnHide", function()
        root.search:ClearFocus()
        for _, control in ipairs({ root.scope, root.kind, root.risk, root.sort, root.days, root.historyCharacter, root.result }) do control.menu:Hide() end
    end)
    root:SetScript("OnUpdate", function(_, elapsed)
        root.elapsed = (root.elapsed or 0) + elapsed
        if root.elapsed >= 30 then root.elapsed = 0; if root.context and root:IsShown() then Refresh() end end
    end)
end
local function Flow(controls, x, y, width)
    local left = 0
    for _, entry in ipairs(controls) do
        local control, wanted = entry[1], entry[2]
        if control.label then
            wanted = math.max(wanted, Theme:MeasureText(Theme.Font.body, control.label:GetText()) + (control.menu and 38 or 20))
        end
        local actual = math.min(width, wanted)
        if left > 0 and left + actual > width then left, y = 0, y + 38 end
        Place(control, x + left, y, actual, 30); control:Show(); left = left + actual + 6
    end
    return y + 38
end
function UI:Columns(root, prefix, global)
    local columns = {}
    for _, field in ipairs(Addon.AccountPage.Fields) do
        if field.groupID == prefix and root.context:GetFieldVisible(field.id)
            and not (prefix == "inbox" and field.key == "character" and not global) then columns[#columns + 1] = Addon.Copy(field) end
    end
    return columns
end
function UI:FitColumns(fields, width, prefix)
    local result = {}; for _, field in ipairs(fields) do result[#result + 1] = field end
    local priorities = prefix == "inbox" and { "coverage", "sender" } or { "counterpart", "result" }
    local function Total() local total = 0; for _, field in ipairs(result) do total = total + field.width end; return total end
    for _, key in ipairs(priorities) do
        if Total() <= width then break end
        for index, field in ipairs(result) do if field.key == key then table.remove(result, index); break end end
    end
    return result
end
function UI:TableRow(root, row, fields, values, width, height, header)
    row.cells = row.cells or {}
    for _, item in ipairs(row.itemButtons or {}) do item:Hide() end
    local total = 0; for _, field in ipairs(fields) do total = total + field.width end
    local left = 0
    for index, field in ipairs(fields) do
        local cell = row.cells[index] or Text(row, Theme.Font.body); row.cells[index] = cell
        local cellWidth = field.fittedWidth or width * field.width / math.max(1, total)
        Place(cell, left + 6, 4, cellWidth - 12, height - 8)
        cell:SetWordWrap(false)
        cell:SetJustifyV("MIDDLE")
        cell:SetText(tostring(header and field.title or values[field.key] or "—"):gsub("[\r\n]+", " "))
        cell:SetTextColor(unpack(Theme.Colors.text)); cell:Show()
        if not header and (field.key == "items" or field.key == "content") and #(values.itemList or {}) > 0 then
            self:ItemCell(row, cell, values, left, cellWidth, height)
        end
        if not header and field.key == "expiry" then
            local color = values.expirySeverity == 2 and Theme.Colors.limitReached or (values.expirySeverity == 1 and Theme.Colors.warning or Theme.Colors.text)
            cell:SetTextColor(unpack(color))
        end
        left = left + cellWidth
    end
    for index = #fields + 1, #row.cells do row.cells[index]:Hide() end
end
function UI:ItemLayout(values, width, measure)
    local items, extra = values.itemList, values.extraContent or ""
    local available, x, y, positions = math.max(1, width - 12), 0, 0, {}
    for index, item in ipairs(items or {}) do
        local name = item.name or (Addon:T("UI.TEXT_0453") .. tostring(item.itemID))
        local needed = math.min(available, math.max(60, (measure and measure(name) or Theme:MeasureText(Theme.Font.body, name)) + 32))
        if x > 0 and x + needed > available then x, y = 0, y + 28 end
        positions[index] = { x = x, y = y, width = needed }
        x = x + needed + 6
    end
    local extraY = extra ~= "" and (#positions > 0 and y + 28 or 0) or nil
    local extraHeight = extraY and math.max(22, math.ceil((measure and measure(extra) or Theme:MeasureText(Theme.Font.body, extra)) / available) * (Theme.Font.body + 4)) or 0
    return positions, math.max(28, extraY and extraY + extraHeight or y + 28), extraY, extraHeight
end
function UI:ItemCell(row, cell, values, left, width, height)
    local items, extra = values.itemList, values.extraContent or ""
    local positions, _, extraY, extraHeight = self:ItemLayout(values, width)
    row.itemButtons = row.itemButtons or {}
    local function Click() local click = row:GetScript("OnClick"); if click then click(row) end end
    for index = 1, #items do
        local item = items[index]
        local button = row.itemButtons[index]
        if not button then
            button = CreateFrame("Button", nil, row)
            button.icon = button:CreateTexture(nil, "ARTWORK"); button.icon:SetSize(22, 22); button.icon:SetPoint("LEFT")
            button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            button.name = Text(button)
            button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            button.count:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 1, -1)
            row.itemButtons[index] = button
        end
        local position = positions[index]
        Place(button, left + 6 + position.x, 4 + position.y, position.width, 24)
        button.icon:SetSize(math.min(22, position.width), 22)
        button.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        button.count:SetText((tonumber(item.quantity) or 0) > 1 and tostring(item.quantity) or "")
        Place(button.name, 26, 1, math.max(1, position.width - 26), 22)
        button.name:SetText(Escape(item.name or (Addon:T("UI.TEXT_0453") .. tostring(item.itemID))):gsub("[\r\n]+", " "))
        button.name:SetShown(position.width >= 60)
        Tooltip(button, { Addon:T("UI.TEXT_0355") .. tostring(item.quantity or 0), values.content or values.items or "", Addon:T("UI.TEXT_0449") }, item)
        button:SetScript("OnClick", Click)
        button:SetScript("OnHide", function(control) if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(control) then GameTooltip:Hide() end end)
        button:Show()
    end
    if extraY then Place(cell, left + 6, 4 + extraY, width - 12, extraHeight) end
    cell:SetWordWrap(true); cell:SetText(extra:gsub("[\r\n]+", " ")); cell:SetShown(extra ~= "")
end
function UI:HistoryValues(value)
    return { history = true, time = Stamp(value.time), character = Identity(value.character), counterpart = Counterpart(value.counterpart, value.character),
        subject = Escape(value.subject):gsub("[\r\n]+", " "), content = Addon.HistoryModel:Content(value):gsub("[\r\n]+", " "), result = Addon.HistoryModel:Outcome(value),
        icon = value.items[1], itemList = value.items, extraContent = Addon.HistoryModel:Content(value, true) }
end
function UI:HistoryLayout(root, fields, width, data)
    local weight, minimum = 0, 0
    local budgets = { time = { 110, 110 }, character = { 100, 150 }, counterpart = { 100, 150 },
        subject = { 110, 200 }, content = { 160, 250 }, result = { 110, 160 } }
    for _, field in ipairs(fields) do
        local budget = budgets[field.key] or { 80, field.width }
        field.minimum = math.max(budget[1], Theme:MeasureText(Theme.Font.body, field.title) + 12)
        field.width = math.min(field.maxWidth or math.huge, math.max(field.minimum, budget[2]))
        minimum, weight = minimum + field.minimum, weight + field.width
    end
    if weight > width then
        local room = math.max(0, width - minimum)
        for _, field in ipairs(fields) do
            field.width = minimum > width and field.minimum * width / minimum
                or field.minimum + (field.width - field.minimum) * room / math.max(1, weight - minimum)
        end
    elseif weight < width then
        local flexible = 0
        for _, field in ipairs(fields) do if not field.maxWidth then flexible = flexible + 1 end end
        if flexible > 0 then
            for _, field in ipairs(fields) do if not field.maxWidth then field.width = field.width + (width - weight) / flexible end end
        end
    end
    for _, field in ipairs(fields) do field.fittedWidth = field.width end
    local offsets, heights, total = self:RecordHeights(fields, data, true)
    return offsets, heights, total, width
end
function UI:RecordHeights(fields, data, history)
    local offsets, heights, total = {}, {}, 0
    local measured = {}
    local function Measure(text)
        if not measured[text] then measured[text] = Theme:MeasureText(Theme.Font.body, text) end
        return measured[text]
    end
    for index, entry in ipairs(data) do
        -- Layout needs only attachments and money, never character-directory
        -- queries or complete display strings for thousands of hidden rows.
        local values = history and { itemList = entry.items, extraContent = Addon.HistoryModel:Content(entry, true) }
            or self:MailValues(entry, true)
        local height = 38
        for _, field in ipairs(fields) do
            if (field.key == "content" or field.key == "items") and #(values.itemList or {}) > 0 then
                local _, itemHeight = self:ItemLayout(values, field.fittedWidth or field.width, Measure)
                height = math.max(height, itemHeight + 10)
            end
        end
        offsets[index], heights[index], total = total, height, total + height
    end
    return offsets, heights, total
end
function UI:ListIndex(layout, offset)
    if not layout.offsets then
        local index = math.floor(offset / layout.pitch) * layout.columns + 1
        return index, math.floor(offset / layout.pitch) * layout.pitch
    end
    local low, high = 1, #layout.offsets
    while low <= high do
        local middle = math.floor((low + high) / 2)
        if layout.offsets[middle] + layout.heights[middle] <= offset then low = middle + 1 else high = middle - 1 end
    end
    return low, layout.offsets[low] or 0
end
function UI:Owners(root, characters, entries, state, x, top, width, height)
    Place(root.owners, x, top, width, height); root.owners:Show()
    local matches = {}
    for _, entry in ipairs(entries) do matches[entry.character.id] = (matches[entry.character.id] or 0) + 1 end
    local list = { { name = Addon:T("UI.TEXT_0136"), count = #entries } }
    for _, character in ipairs(characters) do list[#list + 1] = character end
    local current = Core.Characters:GetCurrent()
    for index, character in ipairs(list) do
        local row = root.ownerRows[index]
        if not row then
            row = CreateFrame("Button", nil, root.ownersContent, "BackdropTemplate")
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(24, 24); row.icon:SetPoint("LEFT", 6, 0)
            row.name = Text(row); row.meta = Text(row, Theme.Font.meta, Theme.Colors.muted)
            row.risk = Text(row, Theme.Font.meta, Theme.Colors.warning)
            row.current = Text(row, Theme.Font.meta, Theme.Colors.accent); row.current:SetText("●"); row.current:SetPoint("RIGHT", -5, 0)
            root.ownerRows[index] = row
        end
        local rowWidth = width - (#list * 42 > height and Theme.Geometry.scrollbarGutter or 0)
        Place(row, 0, (index - 1) * 42, rowWidth, 40)
        local searching = (state.search or ""):find("%S") ~= nil
        local selected = not searching and state.character == character.id
        row:SetBackdropColor(unpack(selected and Theme.Colors.selected or Theme:GetDataRowColor(index)))
        row:SetBackdropBorderColor(unpack(selected and Theme.Colors.accent or Theme.Colors.lineSoft))
        local coords = character.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.class]
        row.icon:SetTexture(coords and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or "Interface\\Icons\\INV_Letter_15")
        if coords then row.icon:SetTexCoord(unpack(coords)) else row.icon:SetTexCoord(0, 1, 0, 1) end
        Place(row.name, 36, 1, rowWidth - 54, 20)
        Place(row.meta, 36, 22, 70, 14); Place(row.risk, 112, 22, rowWidth - 132, 14)
        local summary = character.id and Addon.AccountPage:GetSummary(character)
        row.name:SetText(character.id and Identity(character) or Addon:T("UI.TEXT_0136"))
        local color = character.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class]
        if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(unpack(Theme.Colors.text)) end
        row.current:SetShown(character.id and current and current.id == character.id or false)
        row.meta:SetText(searching and tostring(matches[character.id] or (#entries * (not character.id and 1 or 0))) .. Addon:T("UI.TEXT_0239")
            or (character.id and summary.count .. Addon:T("UI.TEXT_0239") or #entries .. Addon:T("UI.TEXT_0239")))
        local counts = summary and summary._counts
        row.risk:SetText(counts and (counts.expired > 0 and Addon:T("UI.TEXT_0418") or (counts.urgent > 0 and Addon:T("UI.TEXT_0301") or (counts.soon > 0 and Addon:T("UI.TEXT_0096") or ""))) or "")
        row.risk:SetTextColor(unpack(counts and (counts.expired + counts.urgent) > 0 and Theme.Colors.limitReached or Theme.Colors.warning))
        row:SetScript("OnClick", function()
            Addon.WorkspaceState:SelectCharacter(character.id, characters, root.data, root.capacity)
            root.refresh()
        end)
        local lines = { character.id and Identity(character, true) or Addon:T("UI.TEXT_0136"), summary and summary.alert or Addon:T("UI.TEXT_0207") }
        if character.id then lines[#lines + 1] = Model:Coverage(character) end
        Tooltip(row, lines); row:Show()
    end
    for index = #list + 1, #root.ownerRows do root.ownerRows[index]:Hide() end
    root.ownersContent:SetSize(width, #list * 42); root.owners:SetContentHeight(#list * 42)
end
local function ItemsText(items)
    local parts = {}
    for _, item in ipairs(items or {}) do parts[#parts + 1] = Escape(item.name or (Addon:T("UI.TEXT_0453") .. tostring(item.itemID))) .. " ×" .. tostring(item.quantity or 0) end
    return #parts > 0 and table.concat(parts, Addon:T("UI.TEXT_0652")) or Addon:T("UI.TEXT_0369")
end
function UI:MailValues(entry, global)
    local expiry = tonumber(entry.mail.expiresAtEstimate)
    local remaining = expiry and expiry > 0 and expiry - Addon:Now()
    return { character = Identity(entry.character), sender = Counterpart(entry.mail.sender, entry.character), subject = ((entry.mail.wasReturned or entry.mail.returned) and Addon:T("UI.TEXT_0069") or "") .. Escape(entry.mail.subject),
        items = ItemsText(entry.mail.attachments), icon = (entry.mail.attachments or {})[1], itemList = entry.mail.attachments,
        amount = (entry.mail.cod or 0) > 0 and ("COD " .. View:Money(entry.mail.cod)) or View:Money(entry.mail.money),
        expiry = View:Expiry(entry.mail), coverage = Model:Coverage(entry.character),
        expirySeverity = remaining and (remaining <= 259200 and 2 or (remaining <= 604800 and 1 or 0)) or 0 }
end
function UI:OpenMail(root, entry)
    local state = Addon.WorkspaceState:Get().inbox
    if state.detail then state.detailReturn, state.detailReturnScroll = Addon.Copy(state.detail), state.detailScroll end
    state.detail, state.detailPage = { type = "mail", id = entry.id, character = entry.character.id, key = entry.key }, 1
    state.detailScroll = 0
    root.refresh()
end
function UI:Detail(root, state, data, x, top, width, height)
    local detail, lines, title = state.detail, {}, Addon:T("UI.TEXT_0519")
    local function Add(text, item, callback) lines[#lines + 1] = { text = text, item = item, onClick = callback } end
    if detail.type == "mail" then
        local character
        for _, candidate in ipairs(root.context.characters) do if candidate.id == detail.character then character = candidate end end
        local snapshot = character and Addon.db.byCharacter[character.id]
        local mail = snapshot and snapshot.records[detail.key]
        if mail then
            title = Identity(character) .. " · " .. Escape(mail.subject)
            Add(Addon:T("UI.TEXT_0177") .. Escape(mail.sender)); Add(Model:Coverage(character))
            Add(Model:MailDetail({ mail = mail }))
            Add(Addon:T("UI.TEXT_0389") .. Stamp(mail.observedAt) .. (mail.state == "unverified" and Addon:T("UI.TEXT_0012") or ""))
            Add(mail.firstSeenAt and (Addon:T("UI.TEXT_0639") .. Stamp(mail.firstSeenAt) .. Addon:T("UI.TEXT_0647")) or Addon:T("UI.TEXT_0641"))
            for _, item in ipairs(mail.attachments or {}) do Add(ItemsText({ item }) .. Addon:T("UI.TEXT_0020") .. tostring(item.attachmentIndex or "—"), item) end
            if #(mail.attachments or {}) == 0 then Add(Addon:T("UI.TEXT_0369")) end
        else Add(Addon:T("UI.TEXT_0409")) end
    elseif detail.type == "item" then
        local group
        for _, candidate in ipairs(data) do if candidate.id == detail.id then group = candidate; break end end
        if group then
            title = Escape(group.item.name or (Addon:T("UI.TEXT_0453") .. tostring(group.item.itemID))) .. Addon:T("UI.TEXT_0016")
            Add(Addon:T("UI.TEXT_0378") .. group.normalQuantity .. Addon:T("UI.TEXT_0003") .. group.codQuantity .. " · " .. group.mailCount .. Addon:T("UI.TEXT_0033"))
            for _, source in ipairs(group.sources) do
                local entry = source.entry
                Add(Identity(entry.character) .. " · " .. Escape(entry.mail.sender) .. " · " .. Escape(entry.mail.subject)
                    .. " · ×" .. source.item.quantity .. " · " .. View:Expiry(entry.mail)
                    .. Addon:T("UI.TEXT_0014") .. Stamp(entry.mail.observedAt)
                    .. ((entry.mail.cod or 0) > 0 and (Addon:T("UI.TEXT_0013") .. View:Money(entry.mail.cod)) or ""), source.item,
                    function() UI:OpenMail(root, entry) end)
            end
        else Add(Addon:T("UI.TEXT_0460")) end
    else
        local entry
        for _, candidate in ipairs(data) do if candidate.id == detail.id then entry = candidate; break end end
        if entry then
            title = entry.event .. " · " .. Identity(entry.character) .. " · " .. Escape(entry.subject)
            Add(Addon:T("UI.TEXT_0233") .. Escape(entry.counterpart)); Add(Addon:T("UI.TEXT_0374") .. Stamp(entry.time) .. (entry.state == "discovered" and Addon:T("UI.TEXT_0648") or ""))
            if entry.record.cacheProjection then Add(Addon:T("UI.TEXT_0372") .. Stamp(entry.mail.observedAt)) end
            Add(Addon:T("UI.TEXT_0487") .. entry.result); Add(Addon:T("UI.TEXT_0411") .. tostring(entry.sourceKey or Addon:T("UI.TEXT_0399")))
            local sourceNames = { ["rule-send"] = Addon:T("UI.TEXT_0498"), ["shortcut-drop"] = Addon:T("UI.TEXT_0295"), ["native-send"] = Addon:T("UI.TEXT_0179") }
            if sourceNames[entry.record.source] then Add(Addon:T("UI.TEXT_0187") .. sourceNames[entry.record.source]) end
            if entry.record.ruleIDs and #entry.record.ruleIDs > 0 then Add(Addon:T("UI.TEXT_0410") .. table.concat(entry.record.ruleIDs, Addon:T("UI.TEXT_0078"))) end
            for _, item in ipairs(entry.items) do Add(ItemsText({ item }), item) end
            Add(Addon.HistoryModel:Content(entry))
            if entry.record.attemptedAt then Add(Addon:T("UI.TEXT_0186") .. Stamp(entry.record.attemptedAt)) end
            if (entry.record.codAmount or 0) > 0 then Add(Addon:T("UI.TEXT_0357") .. View:Money(entry.record.codAmount)) end
        else Add(Addon:T("UI.TEXT_0512")) end
    end
    root.summary:SetText(title)
    Place(root.detail, x, top, width, height); root.detail:Show()
    for index, value in ipairs(lines) do
        local row = root.detailRows[index]
        if not row then row = CreateFrame("Button", nil, root.detailContent); row.text = Text(row); root.detailRows[index] = row end
        Place(row, 0, (index - 1) * 38, width - 18, 36); Place(row.text, 6, 3, width - 36, 30)
        row.text:SetText(value.text); row:SetScript("OnClick", value.onClick)
        row.icon = row.icon or row:CreateTexture(nil, "ARTWORK"); row.icon:Hide()
        if value.item then
            Place(row.icon, 5, 6, 24, 24); row.icon:SetTexture(value.item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); row.icon:Show(); Place(row.text, 36, 3, width - 66, 30)
        end
        Tooltip(row, { value.text }, value.item); row:Show()
    end
    for index = #lines + 1, #root.detailRows do root.detailRows[index]:Hide() end
    root.detailContent:SetSize(width - 18, math.max(1, #lines * 38)); root.detail:SetContentHeight(#lines * 38)
    root.detail:SetVerticalScroll(state.detailScroll or 0)
    root.renderedDetail = detail.id .. detail.type
end
function UI:RenderList(root, offset)
    local layout = root.listLayout
    if not layout then return end
    local workspace = Addon.WorkspaceState:Get()
    local state = workspace[workspace.tab]
    local first = self:ListIndex(layout, offset or 0)
    local capacity = (math.ceil(root.list:GetHeight() / layout.pitch) + 1) * layout.columns
    if layout.offsets then
        local last = self:ListIndex(layout, (offset or 0) + root.list:GetHeight())
        capacity = last - first + 2
    end
    local used = 0
    for index = first, math.min(#root.data, first + capacity - 1) do
        used = used + 1
        local value = root.data[index]
        if layout.items then
            local tile = root.tiles[used]
            if not tile then
                tile = CreateFrame("Button", nil, root.listContent, "BackdropTemplate")
                tile:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                tile.icon = tile:CreateTexture(nil, "ARTWORK"); tile.icon:SetPoint("TOPLEFT", 1, -1); tile.icon:SetPoint("BOTTOMRIGHT", -1, 1)
                tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                tile.count = tile:CreateFontString(nil, "OVERLAY", "NumberFontNormal"); tile.count:SetPoint("BOTTOMRIGHT", -3, 3)
                root.tiles[used] = tile
            end
            Place(tile, ((index - 1) % layout.columns) * 46 + 4, math.floor((index - 1) / layout.columns) * 46 + 4, 42, 42)
            tile.icon:SetTexture(value.item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            tile.count:SetText(tostring(value.normalQuantity + value.codQuantity)); tile:SetBackdropColor(0, 0, 0, 0)
            local border = View:AttachmentBorder(value)
            tile:SetBackdropBorderColor(unpack(border))
            Tooltip(tile, self:AttachmentTooltip(value), value.item, false)
            tile:SetScript("OnClick", function() state.detail = { type = "item", id = value.id }; state.detailScroll = 0; root.refresh() end)
            tile:Show()
        else
            local row = root.rows[used]
            if not row then
                row = CreateFrame("Button", nil, root.listContent)
                row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints(); root.rows[used] = row
            end
            if row.icon then row.icon:Hide() end
            if row.iconHover then row.iconHover:Hide() end
            local values, lines
            if workspace.tab == "history" then
                values = self:HistoryValues(value)
                lines = { value.event .. " · " .. Identity(value.character, true), Escape(value.subject), Escape(value.counterpart), values.content, Stamp(value.time) .. " · " .. value.result }
            else
                values = self:MailValues(value, true)
                lines = { Addon:T("UI.TEXT_0608") .. Identity(value.character, true) .. Addon:T("UI.TEXT_0005") .. Escape(value.mail.sender), values.subject, values.items, values.amount .. " · " .. values.expiry, values.coverage }
            end
            local rowTop, rowHeight = layout.offsets and layout.offsets[index] or (index - 1) * layout.pitch, (layout.heights and layout.heights[index] or layout.pitch) - 2
            Place(row, 0, rowTop, layout.width, rowHeight)
            row.background:SetColorTexture(unpack(value.id == state.focusedID and Theme.Colors.selected or Theme:GetDataRowColor(index)))
            self:TableRow(root, row, layout.fields, values, layout.width, rowHeight, false)
            row.recordID = value.id
            row:SetScript("OnClick", function()
                state.focusedID = value.id
                if workspace.tab == "inbox" then UI:OpenMail(root, value)
                else state.detail = { type = "history", id = value.id }; state.detailScroll = 0; root.refresh() end
            end)
            Tooltip(row, lines); row:Show()
        end
    end
    local pool = layout.items and root.tiles or root.rows
    for index = used + 1, #pool do pool[index]:Hide() end
end
function UI:Refresh(parent, context)
    local root, workspace = parent.mailWorkspace, Addon.WorkspaceState:Get()
    root.context, root.syncing = context, true
    local changedTab = root.renderedTab ~= workspace.tab
    if changedTab then
        root.search:ClearFocus()
        for _, control in ipairs({ root.scope, root.kind, root.risk, root.sort, root.days, root.historyCharacter, root.result }) do control.menu:Hide() end
        root.renderedTab = workspace.tab
    end
    local state = workspace[workspace.tab]
    local width, height = math.max(1, parent:GetWidth() - 16), math.max(1, parent:GetHeight())
    -- Keep the shared input visible while typing: its OnHide releases focus.
    if workspace.tab == "overview" then root.search:Hide() end
    for _, control in ipairs({ root.clear, root.mail, root.items, root.scope, root.kind, root.risk, root.sort, root.days,
        root.historyCharacter, root.result, root.owners, root.overview, root.tableHeader, root.list, root.detail, root.empty, root.back }) do control:Hide() end
    for _, row in ipairs(root.rows) do row:Hide() end
    for _, tile in ipairs(root.tiles) do tile:Hide() end
    root.tabs:SetActive(workspace.tab)
    local query = state.search or ""
    -- Sync only external changes; ordinary refreshes must leave native IME
    -- composition text and the user's caret untouched.
    if changedTab or root.searchQuery ~= query then root.search:SetValue(query); root.searchQuery = query end
    root.summary:Show(); root.heading:Show(); root.note:Show()
    local left, contentWidth, top = 8, width, 104
    Place(root.heading, 8, 44, width, 24); Place(root.note, 8, 72, width, 22)
    local data, fields, entries, characters, rowHeight = {}, {}, {}, Model:Characters(context), 46
    if workspace.tab == "overview" then
        local summaryContext = setmetatable({ characters = characters, preview = false }, { __index = context })
        Place(root.overview, 0, 38, width + 8, math.max(1, height - 80)); root.overview:Show()
        root.overview.pageState = state
        Addon.AccountPage:RefreshSummary(root.overview, summaryContext)
        root.overview.alertExpired = false
        for _, character in ipairs(characters) do if Addon.AccountPage:GetSummary(character)._counts.expired > 0 then root.overview.alertExpired = true end end
        root.heading:Hide(); root.note:Hide(); root.summary:Hide()
        root.pageCount, root.total, root.capacity = root.overview.pageCount, root.overview.total, root.overview.capacity
        root.empty:SetText(root.overview.mailColumnsHidden and Addon:T("UI.TEXT_0565") or Addon:T("UI.TEXT_0313"))
        Place(root.empty, 16, 110, width - 16, 48); root.empty:SetShown(#characters == 0 or root.overview.mailColumnsHidden)
    elseif workspace.tab == "inbox" then
        Addon.WorkspaceState:ValidateCharacters(characters)
        local identityWidth = 230
        for _, character in ipairs(characters) do
            identityWidth = math.max(identityWidth, Theme:MeasureText(Theme.Font.body, Name(character)) + 132,
                Theme:MeasureText(Theme.Font.meta, character.realm) + 42)
        end
        left = math.min(284, identityWidth + 24); contentWidth = width - left + 8
        local global = (state.search or ""):find("%S") ~= nil
        entries = Model:GetMails(context, state)
        data = state.mode == "items" and Model:GetGroups(entries, state.sort, state.search) or entries
        local selected
        for _, character in ipairs(characters) do if character.id == state.character then selected = character end end
        root.heading:SetText(global and (Addon:T("UI.TEXT_0128") .. #characters .. Addon:T("UI.TEXT_0509")) or (selected and Identity(selected) or (Addon:T("UI.TEXT_0137") .. #characters .. Addon:T("UI.TEXT_0509"))))
        root.note:SetText(global and Addon:T("UI.TEXT_0326")
            or (selected and Model:Coverage(selected) or Addon:T("UI.TEXT_0354")))
        Place(root.heading, left, 44, contentWidth, 24); Place(root.note, left, 72, contentWidth, 22)
        root.note:SetWordWrap(true); root.note:SetHeight(0)
        local noteHeight = math.max(22, root.note:GetStringHeight()); root.note:SetHeight(noteHeight)
        top = math.max(top, 72 + noteHeight + 10)
        local searchWidth = math.max(160, contentWidth - 108)
        top = Flow({ { root.search, searchWidth }, { root.clear, 100 } }, left, top, contentWidth)
        root.scope:SetValue(state.scope); root.sort:SetValue(state.sort); root.risk:SetValue(state.risk)
        root.kind:SetOptions({ { value = "all", label = Addon:T("UI.TEXT_0482") }, { value = "items", label = Addon:T("UI.TEXT_0203") }, { value = "money", label = Addon:T("UI.TEXT_0204") },
            { value = "cod", label = Addon:T("UI.TEXT_0110") }, { value = "returned", label = Addon:T("UI.TEXT_0578") }, { value = "empty", label = Addon:T("UI.TEXT_0370") } }); root.kind:SetValue(state.kind)
        top = Flow({ { root.scope, 126 }, { root.kind, 128 }, { root.risk, 130 }, { root.sort, 114 }, { root.mail, 78 }, { root.items, 96 } }, left, top, contentWidth)
        root.mail:SetState(state.mode == "mail" and "selected" or "default"); root.items:SetState(state.mode == "items" and "selected" or "default")
        local totals = Model:Totals(entries)
        root.summary:SetText((state.scope == "unverified" and (Addon:T("UI.TEXT_0388") .. " · ") or "")
            .. Addon:T("INBOX.SUMMARY", totals.count, totals.attachmentMails, View:Money(totals.money), totals.cod, totals.urgent, totals.soon, totals.expired))
        if state.mode == "items" then root.summary:SetText(root.summary:GetText() .. " · " .. #data .. Addon:T("UI.TEXT_0095")) end
        fields = self:Columns(root, "inbox", global or not state.character)
        if state.mode == "mail" then fields = self:FitColumns(fields, contentWidth, "inbox") end
    else
        root.heading:SetText(Addon:T("UI.TEXT_0170"))
        root.note:SetText(Addon:T("HISTORY.RETENTION_NOTE", Addon.db.settings.historyDays, Addon.db.settings.unverifiedDays))
        root.note:SetWordWrap(true); root.note:SetHeight(0)
        local noteHeight = math.max(22, root.note:GetStringHeight()); root.note:SetHeight(noteHeight)
        top = math.max(top, 72 + noteHeight + 10)
        local options, valid = { { value = "all", label = Addon:T("UI.TEXT_0136") } }, not state.character
        for _, character in ipairs(context.characters) do
            if Addon.HistoryModel:HasHistory(character) then
                options[#options + 1] = { value = character.id, label = Identity(character) }
                if state.character == character.id then valid = true end
            end
        end
        if not valid then state.character, state.scroll, state.anchor = nil, 0, nil end
        root.historyCharacter:SetOptions(options); root.historyCharacter:SetValue(state.character or "all")
        root.days:SetValue(state.days); root.result:SetValue(state.result)
        root.kind:SetOptions({ { value = "all", label = Addon:T("UI.TEXT_0104") }, { value = "inbox", label = Addon:T("UI.TEXT_0343") }, { value = "send", label = Addon:T("UI.TEXT_0178") },
            { value = "discovered", label = Addon:T("UI.TEXT_0640") }, { value = "collected", label = Addon:T("UI.TEXT_0220") } }); root.kind:SetValue(state.kind)
        top = Flow({ { root.search, math.max(200, contentWidth - 108) }, { root.clear, 100 } }, left, top, contentWidth)
        top = Flow({ { root.days, 160 }, { root.historyCharacter, 190 }, { root.kind, 134 }, { root.result, 154 } }, left, top, contentWidth)
        data = Addon.HistoryModel:Query(context, state); fields = self:Columns(root, "history", true); rowHeight = 38
        root.summary:SetText(Addon:T("HISTORY.RESULT_COUNT", #data))
    end
    if workspace.tab ~= "overview" then
        Place(root.summary, left, top, contentWidth, 1); root.summary:SetWordWrap(true); root.summary:SetHeight(0)
        local summaryHeight = math.max(26, root.summary:GetStringHeight())
        root.summary:SetHeight(summaryHeight); top = top + summaryHeight + 8
        root.data, root.capacity = data, math.max(1, math.floor((height - top - 76) / rowHeight))
        if workspace.tab == "inbox" then self:Owners(root, characters, entries, state, 8, 44, left - 24, height - 94) end
        root.total = #data
        if state.detail then
            self:Detail(root, state, data, left, top, contentWidth, math.max(1, height - top - 48))
            root.back:Show()
        else
            local items = workspace.tab == "inbox" and state.mode == "items"
            local pitch, columns = items and 46 or rowHeight, 1
            local viewportTop = top + (items and 0 or 30)
            local viewportHeight = math.max(1, height - viewportTop - (workspace.returnTo and 48 or 12))
            local contentHeight = items and math.ceil(#data / math.max(1, math.floor((contentWidth - 24) / 46))) * pitch + 8 or #data * pitch
            local offsets, heights, tableWidth
            local listWidth = contentWidth - (contentHeight > viewportHeight and Theme.Geometry.scrollbarGutter or 0)
            if workspace.tab == "history" then
                offsets, heights, contentHeight, tableWidth = self:HistoryLayout(root, fields, listWidth, data)
            elseif not items then
                local weight = 0; for _, field in ipairs(fields) do weight = weight + field.width end
                for _, field in ipairs(fields) do field.fittedWidth = listWidth * field.width / math.max(1, weight) end
                offsets, heights, contentHeight = self:RecordHeights(fields, data, false)
            end
            if items then columns = math.max(1, math.floor((listWidth - 8) / pitch)); contentHeight = math.ceil(#data / columns) * pitch + 8 end
            Place(root.list, left, viewportTop, listWidth, viewportHeight); root.list:Show()
            root.listLayout = { fields = fields, width = tableWidth or listWidth, pitch = pitch, columns = columns, items = items, offsets = offsets, heights = heights }
            root.listContent:SetSize(tableWidth or listWidth, math.max(1, contentHeight)); root.list:SetContentHeight(contentHeight)
            if not items then
                Place(root.tableHeader, left, top, listWidth, 28); root.tableHeader:Show()
                self:TableRow(root, root.tableHeader, fields, {}, tableWidth or listWidth, 28, true)
            end
            local offset = state.scroll or 0
            if state.anchor then
                for index, value in ipairs(data) do
                    if value.id == state.anchor then offset = (offsets and offsets[index] or math.floor((index - 1) / columns) * pitch) + (state.anchorOffset or 0); break end
                end
            end
            offset = math.max(0, math.min(offset, math.max(0, contentHeight - viewportHeight)))
            root.list:SetVerticalScroll(offset); state.scroll = offset
            self:RenderList(root, offset)
            local first, start = self:ListIndex(root.listLayout, offset)
            state.anchor, state.anchorOffset = data[first] and data[first].id, offset - start
            Place(root.empty, left + 12, top + 54, contentWidth - 24, 64); root.empty:SetShown(#data == 0)
            root.empty:SetText(workspace.tab == "history" and Addon:T("UI.TEXT_0267")
                or ((state.search or ""):find("%S") and Addon:T("UI.TEXT_0127")
                or (#characters == 0 and Addon:T("UI.TEXT_0543")
                or (state.scope == "unverified" and Addon:T("UI.TEXT_0430") or (state.mode == "items" and Addon:T("UI.TEXT_0431") or Addon:T("UI.TEXT_0429"))))))
        end
    end
    Place(root.back, width - 64, height - 38, 72, 30)
    local overview = workspace.tab == "overview"
    root.previous:SetShown(overview); root.next:SetShown(overview); root.pages:SetShown(overview)
    if overview then
        Place(root.previous, left, height - 38, 90, 30); Place(root.next, left + 98, height - 38, 90, 30)
        Place(root.pages, left + 198, height - 36, contentWidth - 278, 26)
        root.pages:SetText(Addon:T("OVERVIEW.PAGE_STATUS", state.page, root.pageCount, root.total))
        Enable(root.previous, state.page > 1); Enable(root.next, state.page < root.pageCount)
    end
    root.back:SetShown(state.detail ~= nil or workspace.returnTo ~= nil)
    root.syncing = false
end
