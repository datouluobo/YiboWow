local Addon = _G.YiboTaskHub
local Page = {}
Addon.AccountPage = Page

local function Theme() return Addon.Core.UITheme end

function Page:CharacterLabel(character, context, full)
    if not character then return Addon:T("TEXT.CHARACTER_UNAVAILABLE.70FBCA") end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local realmMode = full and "full" or (context.scope == "all" and (current and current.realm and "sameRealm" or "full") or "omit")
    return Addon.Core.Characters:FormatName(character,
        { nameMode = full and "original" or "short", realmMode = realmMode, referenceRealm = current and current.realm }) or Addon:T("TEXT.CHARACTER_UNAVAILABLE.70FBCA")
end

function Page:Status(task, candidate)
    local theme = Theme()
    if task.state == "completed" then return Addon:T("TEXT.COMPLETE_REMOVED_WHEN_CLOSED.243E43"), theme.Colors.muted end
    if task.readiness == "unknown" then
        local expired = task.freshness.validUntil and task.freshness.validUntil <= Addon:Now()
        local suffix = expired and Addon:T("TEXT.EXPIRED.5A4938") or (task.freshness.state == "stale" and Addon:T("TEXT.REVIEW_NEEDED.D5F2A3") or Addon:T("TEXT.UNVERIFIED.C6301E"))
        return (candidate and Addon:T("TEXT.CANDIDATE.0461E4") or Addon:T("TEXT.UNVERIFIED.8708E4")) .. suffix, theme.Colors.muted
    end
    if candidate then return Addon:T("TEXT.SHARED_CANDIDATE.55BB19"), theme.Colors.text end
    if task.readiness == "preparation" then
        local label = task.confidence == "profession" and Addon:T("TEXT.READY_COOLDOWN_TO_CONFIRM.BC16D3")
            or (task.confidence == "estimated" and Addon:T("TEXT.READY_EXPECTED_AVAILABLE.90DFF5") or Addon:T("TEXT.READY_CHECK_MATERIALS.391A8F"))
        return label, theme.Colors.accent
    end
    if task.readiness == "actionable" then return task.reason or Addon:T("TEXT.ACTIONABLE.F5D1DA"), theme.Colors.accent end
    return task.reason or Addon:T("TEXT.WAITING.25D23B"), theme.Colors.warning
end

function Page:Filter(value)
    local filter, available = Addon.db.settings.sourceFilter, false
    for _, source in ipairs(value.sources) do if source.id == filter then available = true end end
    if filter ~= "all" and not available then filter = "all"; Addon.db.settings.sourceFilter = filter end
    local rows, accountSeen = { inactiveGoals = value.inactiveGoals }, {}
    for _, pair in ipairs({ { value.current, "current" }, { value.others, "others" } }) do
        for _, row in ipairs(pair[1]) do
            local mode, state = Addon.db.settings.workFilter, row.task.readiness
            local matches = mode == nil or mode == "all" or (mode == "ready" and (state == "actionable" or state == "preparation"))
                or (mode == "unknown" and state == "unknown") or (mode == "waiting" and state == "blocked")
            local compact = Addon.db.settings.showOtherCharacters == false
            local account = row.task.execution.mode == "account"
            local visible = not compact or pair[2] == "current" or (account and not accountSeen[row.task.identity])
            if matches and visible and (filter == "all" or row.task.providerID == filter) then
                rows[#rows + 1] = { row = row, section = pair[2] }
                if account then accountSeen[row.task.identity] = true end
            end
        end
    end
    return rows
end

-- Only this open view retains completed rows. Business snapshots and goals
-- remain authoritative; removed/paused goals and changed view scopes clear it.
function Page:Retain(rows, frame, context)
    if not frame then return rows end
    local ids = {}; for _, c in ipairs(context.characters or {}) do ids[#ids + 1] = c.id end
    local key = table.concat(ids, "|") .. ":" .. tostring(Addon.db.settings.sourceFilter) .. ":" .. tostring(Addon.db.settings.workFilter) .. ":" .. tostring(Addon.db.settings.showOtherCharacters)
    if frame.sessionKey ~= key then frame.sessionRows, frame.sessionKey = {}, key end
    local present, result = {}, {}
    local function RowKey(pair) return pair.row.character.id .. ":" .. tostring(pair.row.task.goalID or pair.row.task.identity) end
    for _, pair in ipairs(rows) do present[RowKey(pair)] = pair end
    for _, old in ipairs(frame.sessionRows or {}) do
        local id, pair = RowKey(old), present[RowKey(old)]
        if not pair then
            local task = old.row.task
            local goal = task.goalID and Addon.db.goals and Addon.db.goals.byID[task.goalID]
            if goal and not (rows.inactiveGoals and rows.inactiveGoals[task.goalID])
                and (goal.state == "completed" or (goal.state == "active" and goal.lastCompletedCycle ~= nil and goal.lastCompletedCycle == task.temporal.cycleKey)) then
                pair = Addon.Core.Defaults:Copy(old)
                pair.row.task.state, pair.row.task.readiness = "completed", "not-applicable"
                pair.row.task.retainedInView = true
            end
        end
        if pair then pair.sessionOrder = #result + 1; result[#result + 1] = pair end
        present[id] = nil
    end
    for _, pair in ipairs(rows) do if present[RowKey(pair)] then
        pair.sessionOrder = #result + 1; result[#result + 1] = pair; present[RowKey(pair)] = nil
    end end
    frame.sessionRows = result
    return result
end

-- A view-only group: every member keeps its original task identity. Never sum
-- quantities or change source readiness when folding unverified observations.
function Page:Organize(rows, expanded)
    local ordered = {}
    for index, pair in ipairs(rows) do ordered[#ordered + 1] = { pair = pair, order = index } end
    table.sort(ordered, function(a, b)
        if a.pair.section ~= b.pair.section then return a.pair.section == "current" end
        if a.pair.sessionOrder and b.pair.sessionOrder then return a.pair.sessionOrder < b.pair.sessionOrder end
        local ap, bp = Addon.Presentation:Priority(a.pair.row), Addon.Presentation:Priority(b.pair.row)
        if ap ~= bp then return ap < bp end
        return a.order < b.order
    end)
    rows = {}; for _, value in ipairs(ordered) do rows[#rows + 1] = value.pair end
    local groups, keys, result = {}, {}, {}
    for _, pair in ipairs(rows) do
        local row, parts = pair.row, {}
        if row.task.readiness == "unknown" and (pair.section ~= "current" or not row.task.goalID) then
            for _, value in ipairs({ row.character.id, row.task.providerID, row.task.businessRef.sourceEpoch,
                tostring(row.candidate), row.task.beneficiary.mode, row.task.beneficiary.characterID or "" }) do
                parts[#parts + 1] = #value .. ":" .. value
            end
            local key = table.concat(parts, "|")
            keys[pair] = key
            groups[key] = groups[key] or { row = row, section = pair.section, groupKey = key, members = {} }
            groups[key].members[#groups[key].members + 1] = row
        end
    end
    local seen = {}
    for _, pair in ipairs(rows) do
        local key, group = keys[pair], groups[keys[pair]]
        if not group or #group.members < 2 then result[#result + 1] = pair
        elseif not seen[key] then
            seen[key] = true; result[#result + 1] = group
            if expanded and expanded[key] then
                for _, row in ipairs(group.members) do result[#result + 1] = { row = row, section = pair.section } end
            end
        end
    end
    return result
end

function Page:OpenCurrent()
    Addon.db.settings.sourceFilter, Addon.db.settings.workFilter = "all", "all"
    self.resetPage = true
    Addon.Core.AccountView:SetPageScope(Addon.PAGE_ID, "all")
    Addon.Core.AccountView:ShowPage(Addon.PAGE_ID)
end

function Page:Stats(rows)
    local seen, total, candidates, unknown = {}, 0, 0, 0
    for _, pair in ipairs(rows) do
        local row = pair.row
        if not seen[row.task.identity] then
            seen[row.task.identity], total = true, total + 1
            if row.candidate then candidates = candidates + 1 end
            if row.task.readiness == "unknown" then unknown = unknown + 1 end
        end
    end
    return total, candidates, unknown
end

-- Spend the available row slots on the actual section bars on each page.
function Page:Slice(rows, requestedPage, height)
    if #rows == 0 then return 1, 0, 1, 1 end
    local h, ranges, first = Theme().Table.rowHeight, {}, 1
    local slots = math.max(2, math.floor((height - 2 * h - Theme().Table.headerHeight - 16) / h))
    while first <= #rows do
        local used = #ranges == 0 and rows[first].section == "others" and 1 or 0
        local last, section = first - 1, nil
        while last < #rows do
            local nextSection = rows[last + 1].section
            local cost = 1 + (section ~= nextSection and 1 or 0)
            if last >= first and used + cost > slots then break end
            used, section, last = used + cost, nextSection, last + 1
        end
        ranges[#ranges + 1] = { first, last }
        first = last + 1
    end
    local page = math.max(1, math.min(requestedPage or 1, #ranges))
    return ranges[page][1], ranges[page][2], page, #ranges
end

local function Band(parent)
    return Addon.Presentation:Band(parent, 6)
end

local function PlaceCells(band, width, context)
    local fields, total = Addon.Presentation:Columns(context)
    band.actionWidth = nil
    band.workOffset = nil
    local x = 0
    for i, field in ipairs(fields) do
        local size = width * field.weight / total
        local text = band.cells[i]
        text:ClearAllPoints(); text:SetPoint("LEFT", x + 6, 0); text:SetWidth(math.max(1, size - 12)); text:SetHeight(Theme().Table.rowHeight)
        text:Show()
        if field.id == "action" then band.actionWidth = size end
        if field.id == "work" then band.workOffset = x + 6 end
        x = x + size
    end
    for i = #fields + 1, #band.cells do band.cells[i]:Hide() end
    return fields
end

function Page.Create(frame)
    Page.frame = frame
    local theme = Theme()
    frame.rows, frame.bars, frame.expanded = {}, {}, {}
    frame.source = theme:CreateDropdown(frame, 182, {})
    frame.source:SetPoint("TOPLEFT", 4, -4); frame.source:SetHeight(theme.Table.rowHeight)
    frame.source:SetMenuPageSize(8)
    frame.workFilter = theme:CreateDropdown(frame, 140, {
        { value = "all", label = Addon:T("TEXT.STATUS_ALL.3A6C62") }, { value = "ready", label = Addon:T("TEXT.ACTIONABLE_READY.D5698D") },
        { value = "unknown", label = Addon:T("TEXT.UNVERIFIED_ONLY.63672A") }, { value = "waiting", label = Addon:T("TEXT.WAITING_ONLY.E0B107") },
    })
    frame.workFilter:SetPoint("LEFT", frame.source, "RIGHT", 6, 0); frame.workFilter:SetHeight(theme.Table.rowHeight)
    frame.summary = theme:CreateText(frame, theme.Font.assist, theme.Colors.text)
    frame.summary:SetPoint("LEFT", frame.workFilter, "RIGHT", 12, 0); frame.summary:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    frame.summary:SetJustifyH("RIGHT")
    frame.header = Band(frame)
    frame.header.fill:SetColorTexture(unpack(theme.Colors.toolbar))
    frame.previous = theme:CreateButton(frame, 58, Addon:T("TEXT.PREVIOUS.B41561"), "secondary")
    frame.next = theme:CreateButton(frame, 58, Addon:T("TEXT.NEXT.67A246"), "secondary")
    frame.previous:SetHeight(theme.Table.rowHeight); frame.next:SetHeight(theme.Table.rowHeight)
    frame.previous:SetPoint("BOTTOMRIGHT", frame.next, "BOTTOMLEFT", -4, 0)
    frame.next:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.footer = theme:CreateText(frame, theme.Font.assist, theme.Colors.muted)
    frame.footer:SetPoint("BOTTOMLEFT", 4, 4); frame.footer:SetPoint("RIGHT", frame.previous, "LEFT", -8, 0); frame.footer:SetHeight(theme.Table.rowHeight)
    frame.previous:SetScript("OnClick", function() frame.pageIndex = (frame.pageIndex or 1) - 1; Page.Refresh(frame, frame.context) end)
    frame.next:SetScript("OnClick", function() frame.pageIndex = (frame.pageIndex or 1) + 1; Page.Refresh(frame, frame.context) end)
    frame.source:SetOnValueChanged(function(id)
        Addon.db.settings.sourceFilter = id
        frame.expanded = {}
        frame.pageIndex = 1; Page.Refresh(frame, frame.context)
    end)
    frame.workFilter:SetOnValueChanged(function(id)
        Addon.db.settings.workFilter = id
        frame.pageIndex = 1; Page.Refresh(frame, frame.context)
    end)
    frame:SetScript("OnSizeChanged", function()
        if frame.context and not frame.refreshing then Page.Refresh(frame, frame.context) end
    end)
    Addon.Preview:Create(frame)
    frame:HookScript("OnHide", function() frame.sessionRows, frame.sessionKey = nil, nil end)
end

function Page.Refresh(frame, context)
    if frame.refreshing then return end
    frame.refreshing, frame.context = true, context
    if context.preview then
        for _, control in ipairs({ frame.source, frame.workFilter, frame.summary, frame.header, frame.footer, frame.previous, frame.next }) do control:Hide() end
        for _, list in ipairs({ frame.rows, frame.bars }) do for _, control in ipairs(list) do control:Hide() end end
        Addon.Preview:Refresh(frame.taskPreview, context)
        frame.refreshing = false
        return
    end
    frame.taskPreview:Hide()
    frame.source:Show(); frame.workFilter:Show(); frame.summary:Show(); frame.header:Show(); frame.footer:Show()
    local theme, h = Theme(), Theme().Table.rowHeight
    local width = math.max(1, (context.surfaceAvailableWidth or frame:GetWidth()) - 8)
    local value = Addon.Snapshot:Build(context.characters)
    frame.value = value
    local rawRows = Page:Retain(Page:Filter(value), frame, context)
    local rows = Page:Organize(rawRows, frame.expanded)
    if Page.resetPage then frame.pageIndex = 1; Page.resetPage = nil end
    frame.displayRows = rows
    local first, last, page, pages = Page:Slice(rows, frame.pageIndex, frame:GetHeight())
    local viewed = {}
    for index = first, last do viewed[#viewed + 1] = rows[index] end
    Addon.Reminders:Acknowledge(viewed)
    frame.pageIndex = page
    local choices = { { value = "all", label = Addon:T("TEXT.SOURCE_ALL.32691E") } }
    for _, source in ipairs(value.sources) do choices[#choices + 1] = { value = source.id, label = Addon:T("TEXT.SOURCE.64B3B5") .. source.title } end
    frame.source:SetOptions(choices); frame.source:SetValue(Addon.db.settings.sourceFilter)
    frame.workFilter:SetValue(Addon.db.settings.workFilter)
    local countRows, sections = {}, { current = {}, others = {} }
    for _, pair in ipairs(rawRows) do countRows[#countRows + 1] = pair.row; sections[pair.section][#sections[pair.section] + 1] = pair.row end
    frame.summary:SetText(Addon.Presentation:CountText(Addon.Presentation:Counts(countRows), Page:Stats(rawRows), true))
    frame.header:ClearAllPoints(); frame.header:SetPoint("TOPLEFT", 4, -(h + 8)); frame.header:SetSize(width, theme.Table.headerHeight)
    for i, field in ipairs(PlaceCells(frame.header, width, context)) do frame.header.cells[i]:SetText(field.title) end
    for _, row in ipairs(frame.rows) do row:Hide() end
    for _, bar in ipairs(frame.bars) do bar:Hide() end
    local y, rowIndex, barIndex, section = h + 8 + theme.Table.headerHeight, 0, 0, nil
    local function Section(title, key, character)
        barIndex = barIndex + 1
        local bar = frame.bars[barIndex]
        if not bar then bar = Band(frame); frame.bars[barIndex] = bar end
        Addon.Presentation:ResetIdentities(bar)
        bar.cells[1]:Show()
        for i = 2, 6 do bar.cells[i]:SetText("") end
        bar.cells[1]:SetText(title); bar.cells[1]:SetWidth(width * 0.52)
        bar.cells[1]:ClearAllPoints(); bar.cells[1]:SetPoint("LEFT", 6, 0); bar.cells[1]:SetHeight(h)
        bar.cells[6]:ClearAllPoints(); bar.cells[6]:SetPoint("RIGHT", -6, 0); bar.cells[6]:SetSize(width * 0.45, h)
        bar.cells[6]:SetJustifyH("RIGHT"); bar.cells[6]:SetTextColor(unpack(theme.Colors.muted))
        theme:ApplyTextStyle(bar.cells[6], theme.Font.assist)
        if key then bar.cells[6]:SetText(Addon.Presentation:CountText(Addon.Presentation:Counts(sections[key]), nil, true)) end
        bar.fill:SetColorTexture(unpack(theme.Colors.toolbar))
        if character then Addon.Presentation:IdentityCell(bar, 1, character, context, title) end
        bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", 4, -y); bar:SetSize(width, h); bar:Show(); y = y + h
    end
    if page == 1 and rows[1] and rows[1].section == "others" then
        local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
        Section(Addon.Presentation:Muted(Addon:T("TEXT.CURRENT_CHARACTER.F565FD")) .. Page:CharacterLabel(current, context)
            .. Addon.Presentation:Muted(Addon:T("TEXT.NO_TASKS_TO_SHOW.EC4783")), nil, current)
    end
    for index = first, last do
        local pair, row = rows[index], rows[index].row
        if section ~= pair.section then
            section = pair.section
            local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
            Section(section == "current" and (Addon.Presentation:Muted(Addon:T("TEXT.CURRENT_CHARACTER.F565FD")) .. Page:CharacterLabel(current, context))
                or Addon:T("TEXT.OTHER_CHARACTERS_TODAY_S_TASKS.E54F4D"), section, section == "current" and current or nil)
        end
        rowIndex = rowIndex + 1
        local band = frame.rows[rowIndex]
        if not band then
            band = Band(frame); band:EnableMouse(true)
            band.action = theme:CreateButton(band, 78, Addon:T("TEXT.VIEW.F7ACEF"), "secondary"); band.action:SetHeight(h - 4)
            band.action:SetPoint("RIGHT", -4, 0)
            band.action:SetScript("OnClick", function(control)
                local owner = control:GetParent()
                if owner.group then
                    frame.expanded[owner.group.groupKey] = not frame.expanded[owner.group.groupKey]
                    Page.Refresh(frame, frame.context); return
                end
                local action = owner.task and owner.task.nextAction
                if action then Addon.Core.AccountView:ShowPage(action.pageID) end
            end)
            band:SetScript("OnMouseUp", function(control, button)
                if button == "LeftButton" and control.group then
                    frame.expanded[control.group.groupKey] = not frame.expanded[control.group.groupKey]
                    Page.Refresh(frame, frame.context)
                end
            end)
            band:SetScript("OnEnter", function(control)
                theme:ShowTooltip(control, control.group and (Addon:T("TEXT.UNVERIFIED_TASKS.51F47E") .. #control.group.members .. Addon:T("TEXT.ITEMS.12DE8E")) or Addon.Presentation:Title(control.row.task),
                    control.group and Addon.Presentation:GroupDetails(control.group.members, frame.context)
                        or Addon.Presentation:Details(control.row, frame.context), "ANCHOR_RIGHT")
            end)
            band:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            frame.rows[rowIndex] = band
        end
        local task = row.task
        band.task, band.row, band.group = task, row, pair.members and pair or nil
        band:ClearAllPoints(); band:SetPoint("TOPLEFT", 4, -y); band:SetSize(width, h)
        band.fill:SetColorTexture(unpack(Addon.Presentation:RowColor(row, rowIndex)))
        Addon.Presentation:ResetIdentities(band)
        local workCell
        for i, field in ipairs(PlaceCells(band, width, context)) do
            if field.id == "work" then workCell = band.cells[i] end
            local text, color = Addon.Presentation:Cell(row, field, context)
            if pair.members then
                if field.id == "work" then text = (frame.expanded[pair.groupKey] and "[-] " or "[+] ") .. Addon:T("TEXT.UNVERIFIED_TASKS.51F47E") .. #pair.members .. Addon:T("TEXT.ITEMS.12DE8E")
                elseif field.id == "status" then text, color = Addon:T("TEXT.UNVERIFIED.055C5D") .. #pair.members .. Addon:T("TEXT.ITEMS.12DE8E"), theme.Colors.muted end
            end
            band.cells[i]:SetText(text); band.cells[i]:SetTextColor(unpack(color or theme.Colors.text))
            if field.id == "character" then Addon.Presentation:IdentityCell(band, i, row.character, context)
            elseif field.id == "beneficiary" and task.beneficiary.mode == "character" and task.beneficiary.characterID ~= row.character.id then
                Addon.Presentation:IdentityCell(band, i, Addon.Core.Characters:Get(task.beneficiary.characterID, { identityOnly = true }), context)
            end
        end
        if not pair.members then Addon.Presentation:BindWork(band, workCell, task) end
        if Addon.TaskActions then Addon.TaskActions:Bind(band, not pair.members and workCell and band.workOffset or nil, not pair.members and task or nil) end
        band.action:SetWidth(math.max(30, (band.actionWidth or 0) - 8)); band.action:SetShown(band.actionWidth ~= nil and (pair.members ~= nil or task.nextAction ~= nil))
        band.action.kind = pair.members and "disclosure" or "secondary"
        band.action:SetState("default")
        band.action.label:SetTextColor(unpack(task.readiness == "actionable" and not pair.members and theme.Colors.accent or theme.Colors.muted))
        if pair.members then band.action:SetText((frame.expanded[pair.groupKey] and Addon:T("TEXT.COLLAPSE.2A712E") or Addon:T("TEXT.EXPAND.E6B5F9")) .. #pair.members)
        elseif task.nextAction then band.action:SetText(task.nextAction.title or Addon:T("TEXT.VIEW.F7ACEF")) end
        band:Show(); y = y + h
    end
    if #rows == 0 then
        local message
        if value.providerCount == 0 then message = Addon:T("TEXT.NO_GOALS_YET_ADD_ONE_FROM_A_SPECIFIC.1F2D59")
        elseif #value.errors > 0 then message = Addon:T("TEXT.SOME_SOURCES_ARE_TEMPORARILY_UNAVAIL.7B4A64")
        elseif value.uncoveredCount > 0 then message = Addon:T("TEXT.BUSINESS_DATA_IS_INCOMPLETE_OPEN_THE.4E0ABF")
        else message = Addon:T("TEXT.NO_TASKS_IN_THIS_SCOPE_MANAGE_GOALS_.C23966") end
        Section(message)
    end
    local remaining = math.max(0, #rows - last)
    local footer = string.format(Addon:T("TEXT.PAGE_D_D_SHOWING_D_OF_D_ROWS.BFADEF"), page, pages, math.max(0, last - first + 1), #rows)
    if #rows < #rawRows then footer = footer .. Addon:T("TEXT.UNVERIFIED_DETAILS_COLLAPSED.862054") elseif remaining > 0 then footer = footer .. Addon:T("TEXT..6520CB") .. remaining .. Addon:T("TEXT.MORE_ROWS.0A4E6B") end
    if #value.errors > 0 then footer = footer .. " · " .. #value.errors .. Addon:T("TEXT.UNAVAILABLE_SOURCES.7032E2") end
    if value.uncoveredCount > 0 then footer = footer .. Addon:T("TEXT.SOME_DATA_NEEDS_VERIFICATION.7D67BB") end
    frame.footer:SetText(footer)
    frame.previous:SetEnabled(page > 1); frame.next:SetEnabled(page < pages)
    frame.previous:SetShown(pages > 1); frame.next:SetShown(pages > 1)
    frame.refreshing = false
end

function Page.GetSurfaceMetrics(context)
    if context.preview then return Addon.Preview:GetMetrics(context) end
    local value = Addon.Snapshot:Build(context.characters)
    local active = Page.frame and Page.frame:IsShown() and Page.frame
    local rows = Page:Organize(Page:Retain(Page:Filter(value), active, context), {})
    local count, bars, previous = #rows, #rows == 0 and 1 or (rows[1].section == "others" and 1 or 0), nil
    for _, pair in ipairs(rows) do
        if pair.section ~= previous then bars, previous = bars + 1, pair.section end
    end
    local theme = Theme()
    local height = theme.Table.headerHeight + (count + bars + 2) * theme.Table.rowHeight + 16
    return { minContentWidth = 860, naturalContentWidth = 1040, minContentHeight = 180,
        naturalContentHeight = height, horizontalOverflow = "content", verticalOverflow = "none" }
end
