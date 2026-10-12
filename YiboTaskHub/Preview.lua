local Addon = _G.YiboTaskHub
local Preview = {}
Addon.Preview = Preview

function Preview:Build(context, sessionFrame)
    local value = Addon.Snapshot:Build(context.characters)
    local rows = Addon.AccountPage:Filter(value)
    local active = sessionFrame or (self.frame and self.frame:IsShown() and self.frame)
    rows = Addon.AccountPage:Retain(rows, active, context)
    local groups, byID = {}, {}
    for _, pair in ipairs(rows) do
        local row, id = pair.row, pair.row.character.id
        local group = byID[id]
        if not group and #groups < 20 then
            group = { character = row.character, rows = {}, entries = {} }
            groups[#groups + 1], byID[id] = group, group
        end
        if group then
            group.rows[#group.rows + 1] = row
            group.entries[#group.entries + 1] = pair
        end
    end
    local lines = #groups
    for _, group in ipairs(groups) do
        group.entries = Addon.AccountPage:Organize(group.entries, {})
        group.counts = Addon.Presentation:Counts(group.rows)
        lines = lines + #group.entries
    end
    local current, order = Addon.Core.Characters:GetCurrent({ identityOnly = true }), {}
    for index, group in ipairs(groups) do order[group], group.current = index, current and group.character.id == current.id end
    table.sort(groups, function(a, b)
        local ac, bc = current and a.character.id == current.id, current and b.character.id == current.id
        if ac ~= bc then return ac == true end
        local ap, bp = Addon.Presentation:Priority(a.entries[1].row), Addon.Presentation:Priority(b.entries[1].row)
        if ap ~= bp then return ap < bp end
        return order[a] < order[b]
    end)
    return { value = value, rows = rows, groups = groups, lines = lines }
end

function Preview:GetMetrics(context)
    local view = self:Build(context)
    local theme = Addon.Core.UITheme
    local naturalHeight = (math.max(1, view.lines) + 2) * theme.Table.rowHeight + theme.Table.headerHeight + 12
    local tokens = self:Plan(view, context.surfaceAvailableHeight or naturalHeight)
    return { minContentWidth = 570, naturalContentWidth = 820, minContentHeight = 130,
        naturalContentHeight = (math.max(1, #tokens) + 2) * theme.Table.rowHeight + theme.Table.headerHeight + 12,
        horizontalOverflow = "content", verticalOverflow = "none" }
end

function Preview:Status(counts)
    return Addon.Presentation:CountText(counts, nil, true)
end

function Preview:Create(parent)
    local frame = CreateFrame("Frame", nil, parent); parent.taskPreview = frame
    self.frame = frame
    frame:HookScript("OnHide", function() frame.sessionRows, frame.sessionKey = nil, nil end)
    frame:SetAllPoints(); frame.rows = {}
    local theme = Addon.Core.UITheme
    frame.summary = theme:CreateText(frame, theme.Font.assist, theme.Colors.text)
    frame.summary:SetPoint("TOPLEFT", 4, -4); frame.summary:SetPoint("TOPRIGHT", -4, -4)
    frame.header = Addon.Presentation:Band(frame, 6)
    frame.footer = theme:CreateText(frame, theme.Font.assist, theme.Colors.muted)
    frame.footer:SetPoint("BOTTOMLEFT", 4, 4); frame.footer:SetPoint("BOTTOMRIGHT", -4, 4)
    frame:Hide()
end

function Preview:Plan(view, height)
    local theme = Addon.Core.UITheme
    local capacity = math.max(1, math.floor((height - 2 * theme.Table.rowHeight - theme.Table.headerHeight - 12) / theme.Table.rowHeight))
    local spare = math.max(0, capacity - #view.groups)
    local compact, currentRemaining = false, 0
    local tokens = {}
    for _, group in ipairs(view.groups) do
        local entries = group.entries or group.rows
        local shown = group.current and math.min(spare, #entries) or 0
        if not group.current or shown == 0 then
            tokens[#tokens + 1] = { group = group, compact = true }; compact = true
        else
            tokens[#tokens + 1] = { group = group, heading = true }
            for i = 1, shown do
                local pair = entries[i]
                tokens[#tokens + 1] = { group = group, row = group.entries and pair.row or pair, members = pair.members }
            end
            spare = spare - shown
        end
        if group.current then for i = shown + 1, #entries do
            currentRemaining = currentRemaining + (entries[i].members and #entries[i].members or 1)
        end end
    end
    local shown = {}
    for i = 1, math.min(capacity, #tokens) do shown[i] = tokens[i] end
    local remaining = 0
    for index = #shown + 1, #tokens do if tokens[index].compact or tokens[index].heading then remaining = remaining + 1 end end
    return shown, compact, remaining, currentRemaining
end

local function Distinct(rows, callback)
    local seen, values = {}, {}
    for _, row in ipairs(rows) do
        local text = callback(row)
        if not seen[text] then seen[text] = true; values[#values + 1] = text end
    end
    return table.concat(values, Addon:T("TEXT.LIST_SEPARATOR"))
end

function Preview:Refresh(frame, context)
    local theme, view = Addon.Core.UITheme, self:Build(context, frame)
    local width, h = math.max(1, frame:GetWidth() - 8), theme.Table.rowHeight
    local tokens, compact, remaining, currentRemaining = self:Plan(view, frame:GetHeight())
    frame.view, frame.tokens, frame.compact = view, tokens, compact
    frame:Show(); frame.summary:SetHeight(h)
    local countRows = {}; for _, pair in ipairs(view.rows) do countRows[#countRows + 1] = pair.row end
    frame.summary:SetText(Addon.Presentation:CountText(Addon.Presentation:Counts(countRows), Addon.AccountPage:Stats(view.rows), true))
    local fields, total = Addon.Presentation:Columns(context)
    local function Place(band)
        local x = 0
        band.workOffset = nil
        for i, field in ipairs(fields) do
            local size = width * field.weight / total
            band.cells[i]:ClearAllPoints(); band.cells[i]:SetPoint("LEFT", x + 6, 0)
            band.cells[i]:SetSize(math.max(1, size - 12), h); band.cells[i]:Show(); x = x + size
            if field.id == "work" then band.workOffset = x - size + 6 end
        end
        for i = #fields + 1, #band.cells do band.cells[i]:Hide() end
    end
    frame.header:ClearAllPoints(); frame.header:SetPoint("TOPLEFT", 4, -(h + 6)); frame.header:SetSize(width, theme.Table.headerHeight)
    frame.header.fill:SetColorTexture(unpack(theme.Colors.toolbar)); Place(frame.header)
    for i, field in ipairs(fields) do frame.header.cells[i]:SetText((compact and i == 1 and Addon:T("TEXT.CHARACTER.E8190C") or "") .. field.title) end
    for _, band in ipairs(frame.rows) do band:Hide() end
    local y = h + 6 + theme.Table.headerHeight
    for index, token in ipairs(tokens) do
        local band = frame.rows[index]
        if not band then
            band = Addon.Presentation:Band(frame, 6); frame.rows[index] = band; band:EnableMouse(true)
            band:SetScript("OnEnter", function(control) theme:ShowTooltip(control, control.title, control.lines, "ANCHOR_RIGHT") end)
            band:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end
        band:ClearAllPoints(); band:SetPoint("TOPLEFT", 4, -y); band:SetSize(width, h); Place(band)
        Addon.Presentation:ResetIdentities(band)
        if Addon.TaskActions then Addon.TaskActions:Bind(band, nil, nil) end
        local name = Addon.AccountPage:CharacterLabel(token.group.character, context)
        local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
        if current and token.group.character.id == current.id then name = name .. Addon:T("TEXT.CURRENT.97408D") end
        band.title, band.lines = name, Addon.Presentation:GroupDetails(token.group.rows, context)
        band.fill:SetColorTexture(unpack(token.heading and theme.Colors.toolbar or
            (token.row and Addon.Presentation:RowColor(token.row, index) or theme:GetDataRowColor(index))))
        if token.heading then
            for _, cell in ipairs(band.cells) do cell:Hide() end
            band.cells[1]:Show(); band.cells[1]:SetWidth(width * 0.52); band.cells[1]:SetText(name)
            band.cells[1]:SetTextColor(unpack(theme.Colors.text))
            Addon.Presentation:IdentityCell(band, 1, token.group.character, context, name)
            band.cells[6]:ClearAllPoints(); band.cells[6]:SetPoint("RIGHT", -6, 0); band.cells[6]:SetSize(width * 0.45, h)
            band.cells[6]:SetJustifyH("RIGHT"); band.cells[6]:SetText(self:Status(Addon.Presentation:Counts(token.group.rows)))
            theme:ApplyTextStyle(band.cells[6], theme.Font.assist)
            band.cells[6]:SetTextColor(unpack(theme.Colors.muted)); band.cells[6]:Show()
        elseif token.row then
            local workCell
            for i, field in ipairs(fields) do
                if field.id == "work" then workCell = band.cells[i] end
                local text, color = Addon.Presentation:Cell(token.row, field, context)
                if token.members then
                    if field.id == "work" then text = Addon:T("TEXT.UNVERIFIED_TASKS.281DE3") .. #token.members .. Addon:T("TEXT.ITEMS.12DE8E")
                    elseif field.id == "status" then text, color = Addon:T("TEXT.UNVERIFIED.457540") .. #token.members .. Addon:T("TEXT.ITEMS.12DE8E"), theme.Colors.muted end
                end
                band.cells[i]:SetText(text); band.cells[i]:SetTextColor(unpack(color or theme.Colors.text))
                if field.id == "character" then Addon.Presentation:IdentityCell(band, i, token.group.character, context)
                elseif field.id == "beneficiary" and token.row.task.beneficiary.mode == "character"
                    and token.row.task.beneficiary.characterID ~= token.group.character.id then
                    Addon.Presentation:IdentityCell(band, i, Addon.Core.Characters:Get(token.row.task.beneficiary.characterID, { identityOnly = true }), context)
                end
            end
            band.title = token.members and Addon:T("TEXT.UNVERIFIED_TASKS.64C59C") or Addon.Presentation:Title(token.row.task)
            band.lines = token.members and Addon.Presentation:GroupDetails(token.members, context) or Addon.Presentation:Details(token.row, context)
            if not token.members then Addon.Presentation:BindWork(band, workCell, token.row.task) end
            if Addon.TaskActions and not token.members then Addon.TaskActions:Bind(band, workCell and band.workOffset, token.row.task) end
        else
            local counts = Addon.Presentation:Counts(token.group.rows)
            for i, field in ipairs(fields) do
                local text
                if field.id == "status" then
                    text = self:Status(counts)
                elseif field.id == "work" then text = #token.group.rows .. Addon:T("TEXT.TASKS.08777B")
                elseif field.id == "source" then
                    local sources = {}; for _, row in ipairs(token.group.rows) do sources[row.task.providerID] = true end
                    local count = 0; for _ in pairs(sources) do count = count + 1 end
                    text = count > 1 and (count .. Addon:T("TEXT.SOURCES.BB64E7")) or token.group.rows[1].task.sourceTitle
                else text = Distinct(token.group.rows, function(row) return Addon.Presentation:Cell(row, field, context) end) end
                if i == 1 then text = name .. Addon.Presentation:Muted(" · " .. text) end
                local color = (field.id == "source" or field.id == "beneficiary" or (counts.actionable == 0 and counts.preparation == 0)) and theme.Colors.muted or theme.Colors.text
                band.cells[i]:SetText(text); band.cells[i]:SetTextColor(unpack(color))
                if i == 1 then Addon.Presentation:IdentityCell(band, i, token.group.character, context, text) end
            end
        end
        band:Show(); y = y + h
    end
    local footer = #view.groups .. Addon:T("TEXT.CHARACTERS_CLICK_THE_ENTRY_TO_OPEN_T.1613D4")
    if remaining > 0 then footer = Addon:T("TEXT.PLUS.202859") .. remaining .. Addon:T("TEXT.MORE_CHARACTERS_VIEW_THEM_IN_THE_MAI.8E2CBC") end
    if currentRemaining > 0 then footer = footer .. Addon:T("TEXT.CURRENT_CHARACTER_HAS.924181") .. currentRemaining .. Addon:T("TEXT.MORE_VIEW_THEM_IN_THE_MAIN_WINDOW.097A25") end
    if #view.groups == 0 then footer = view.value.providerCount == 0 and Addon:T("TEXT.NO_COMPATIBLE_TASK_SOURCES.1BC5F0") or Addon:T("TEXT.NO_TASKS_TO_SHOW_IN_THIS_SCOPE.5CC91E") end
    if #view.value.errors > 0 or view.value.uncoveredCount > 0 then footer = footer .. Addon:T("TEXT.SOME_DATA_NEEDS_VERIFICATION.7D67BB") end
    frame.footer:SetHeight(h); frame.footer:SetText(footer)
end
