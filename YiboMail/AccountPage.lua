local Addon = _G.YiboMail
local Core, Page = _G.YiboCore, {}
Addon.AccountPage = Page
Page.ID = "mail-inbox"

local Theme = Core.UITheme
local fields = {
    { id = "character", title = Addon:T("UI.TEXT_0504") },
    { id = "count", title = Addon:T("UI.TEXT_0598") },
    { id = "attachments", title = Addon:T("UI.TEXT_0630") },
    { id = "money", title = Addon:T("UI.TEXT_0197") },
    { id = "expires", title = Addon:T("UI.TEXT_0392") },
    { id = "status", title = Addon:T("UI.TEXT_0386") },
    { id = "alert", title = Addon:T("UI.TEXT_0160") },
    { id = "cod", title = Addon:T("UI.TEXT_0068") },
    { id = "backlog", title = Addon:T("UI.TEXT_0290"), defaultVisible = false },
}
for _, field in ipairs(fields) do field.group, field.groupID = Addon:T("UI.TEXT_0564"), "overview" end
local pageFields = {}
for _, field in ipairs(fields) do pageFields[#pageFields + 1] = field end
for _, group in ipairs({
    { Addon:T("UI.TEXT_0344"), "inbox", { { "character", Addon:T("UI.TEXT_0504"), 130 }, { "sender", Addon:T("UI.TEXT_0176"), 110 }, { "subject", Addon:T("UI.TEXT_0100"), 160 },
        { "items", Addon:T("UI.TEXT_0624"), 160 }, { "amount", Addon:T("UI.TEXT_0618"), 100 }, { "expiry", Addon:T("UI.TEXT_0397"), 100 }, { "coverage", Addon:T("UI.TEXT_0386"), 180 } } },
    { Addon:T("UI.TEXT_0170"), "history", { { "time", Addon:T("UI.TEXT_0371"), 120 }, { "character", Addon:T("UI.TEXT_0504"), 180 },
        { "counterpart", Addon:T("UI.TEXT_0232"), 180 }, { "subject", Addon:T("UI.TEXT_0100"), 240, 240 }, { "content", Addon:T("UI.TEXT_0625"), 280, 280 }, { "result", Addon:T("UI.TEXT_0103"), 160 } } },
}) do
    for _, definition in ipairs(group[3]) do
        pageFields[#pageFields + 1] = { id = group[2] .. "." .. definition[1], key = definition[1], title = definition[2],
            width = definition[3], maxWidth = definition[4], group = group[1], groupID = group[2], preview = false }
    end
end
Page.Fields, Page.SummaryFields = pageFields, fields

local VALID_SCAN = { known = true, ["known-empty"] = true, partial = true }

local function Escape(value)
    return tostring(value or ""):gsub("|", "||")
end

function Page:HasSnapshot(character)
    local snapshot = Addon.db and Addon.db.byCharacter[character and character.id]
    local coverage = snapshot and snapshot.coverage
    return type(coverage) == "table" and VALID_SCAN[coverage.status] == true
        and type(coverage.observedAt) == "number" and type(snapshot.visibleKeys) == "table"
end

local function Summary(character, context)
    local snapshot = Addon.db.byCharacter[character.id]
    local coverage = snapshot.coverage
    local now = Addon:Now()
    local counts = { expired = 0, urgent = 0, soon = 0, unknown = 0, within3Days = 0, within7Days = 0 }
    local nextExpiry, visibleCount, attachmentSlots, availableMoney, codCount, backlog = nil, 0, 0, 0, 0, 0
    local expiryColorSeverity = 0

    local usedMarkers = {}
    for _, mail in pairs(snapshot.records or {}) do if mail.state == "unverified" then backlog = backlog + 1 end end
    for _, key in ipairs(snapshot.visibleKeys or {}) do
        local mail = snapshot.records[key]
        if mail and not Addon.ViewModel:IsCollectedEmptyMail(character.id, mail, usedMarkers) then
            visibleCount = visibleCount + 1
            attachmentSlots = attachmentSlots + #(mail.attachments or {})
            if (tonumber(mail.cod) or 0) <= 0 then
                availableMoney = availableMoney + (tonumber(mail.money) or 0)
            else codCount = codCount + 1 end
            local expires = tonumber(mail.expiresAtEstimate)
            if expires and expires > 0 then
                local remaining = expires - now
                if remaining <= 0 then
                    counts.expired = counts.expired + 1
                    expiryColorSeverity = 2
                else
                    nextExpiry = math.min(nextExpiry or math.huge, remaining)
                    if remaining <= 3 * 86400 then
                        expiryColorSeverity = 2
                        counts.within3Days = counts.within3Days + 1
                    elseif remaining <= 7 * 86400 then
                        expiryColorSeverity = math.max(expiryColorSeverity, 1)
                        counts.within7Days = counts.within7Days + 1
                    end
                    if remaining <= 86400 then counts.urgent = counts.urgent + 1
                    elseif remaining <= 3 * 86400 then counts.soon = counts.soon + 1 end
                end
            else counts.unknown = counts.unknown + 1 end
        end
    end

    local mailCount
    if coverage.status == "partial" then
        mailCount = tostring(visibleCount) .. "/" .. tostring(coverage.totalCount or "?")
    else
        mailCount = tostring(visibleCount)
    end

    local expires = "—"
    if counts.expired > 0 then
        expires = Addon:T("UI.TEXT_0288") .. counts.expired
    elseif nextExpiry then
        if nextExpiry < 86400 then expires = string.format(Addon:T("UI.TEXT_0485"), nextExpiry / 3600)
        else expires = string.format(Addon:T("UI.TEXT_0484"), nextExpiry / 86400) end
    elseif counts.unknown > 0 then expires = Addon:T("UI.TEXT_0398")
    end
    counts.nearest = counts.expired > 0 and Addon:T("UI.TEXT_0253") or (expires ~= "—" and (Addon:T("UI.TEXT_0391") .. expires) or nil)

    local status = coverage.observedAt and date("%m-%d %H:%M", coverage.observedAt) or "—"
    local live = Addon.Items:GetState(character.id)
    if live.status == "error" then status = Addon:T("UI.TEXT_0562") .. status
    elseif coverage.status == "partial" then status = Addon:T("UI.TEXT_0609") .. status end
    local alerts = {}
    if counts.expired > 0 then alerts[#alerts + 1] = Addon:T("UI.TEXT_0158") .. counts.expired end
    if counts.urgent > 0 then alerts[#alerts + 1] = Addon:T("UI.TEXT_0483") .. counts.urgent end
    if counts.soon > 0 then alerts[#alerts + 1] = Addon:T("UI.TEXT_0097") .. counts.soon end

    local severity = counts.expired > 0 and 3 or (counts.urgent > 0 and 2 or (counts.soon > 0 and 1 or 0))
    local current = Core.Characters:GetCurrent({ identityOnly = true })
    local referenceRealm = context and context.scope and context.scope:match("^realm:(.+)$") or (current and current.realm)
    local name = Core.Characters:FormatName(character, { nameMode = "short" }) or Addon:T("UI.TEXT_0400")
    local identity = Core.Characters:FormatName(character, { nameMode = "short",
        realmMode = referenceRealm and "sameRealm" or "full", referenceRealm = referenceRealm })
    return {
        character = name,
        realm = identity and identity ~= name and character.realm or "",
        class = character.class,
        count = mailCount,
        attachments = tostring(attachmentSlots),
        money = availableMoney > 0 and string.format(Addon:T("UI.TEXT_0058"), availableMoney / 10000) or "—",
        expires = expires,
        status = status,
        alert = #alerts > 0 and table.concat(alerts, " · ") or "—",
        cod = tostring(codCount), backlog = tostring(backlog),
        _counts = counts,
        _severity = severity,
        _expiryColorSeverity = expiryColorSeverity,
        _nextExpiry = nextExpiry,
    }, snapshot
end

local function GetPreviewAlert(context)
    local expired, within3Days, within7Days, nearest = 0, 0, 0, nil
    for _, character in ipairs(context and context.characters or {}) do
        local summary = Summary(character)
        local counts = summary._counts
        expired = expired + counts.expired
        within3Days = within3Days + counts.within3Days
        within7Days = within7Days + counts.within7Days
        if summary._nextExpiry then nearest = math.min(nearest or math.huge, summary._nextExpiry) end
    end
    if expired > 0 then
        return { title = Addon:T("UI.TEXT_0289"), text = expired .. Addon:T("UI.TEXT_0036"), severity = 2 }
    elseif within3Days > 0 then
        local when = nearest and string.format(Addon:T("UI.TEXT_0393"), nearest / 86400) or ""
        return { title = Addon:T("UI.TEXT_0168"), text = within3Days .. Addon:T("UI.TEXT_0034") .. (when ~= "" and (" · " .. when) or ""), severity = 2 }
    elseif within7Days > 0 then
        local when = nearest and string.format(Addon:T("UI.TEXT_0393"), nearest / 86400) or ""
        return { title = Addon:T("UI.TEXT_0168"), text = within7Days .. Addon:T("UI.TEXT_0035") .. (when ~= "" and (" · " .. when) or ""), severity = 1 }
    end
end

local function GetPreviewColumns(context)
    local columns, widths, totalWidth = {}, {}, 0
    local function Measure(value)
        return Theme:MeasureText(Theme.Font.body, value)
    end
    for _, field in ipairs(fields) do
        if context:GetFieldVisible(field.id) then
            columns[#columns + 1] = field
            widths[field.id] = Measure(field.title) + 8
        end
    end
    for _, character in ipairs(context.characters or {}) do
        local values = Summary(character, context)
        for _, field in ipairs(columns) do
            local needed
            if field.id == "character" then
                local realm = values.realm and values.realm ~= "" and ("· " .. values.realm) or ""
                needed = Measure(values.character) + (realm ~= "" and (4 + Measure(realm)) or 0) + 12
            else
                needed = Measure(values[field.id]) + 8
            end
            widths[field.id] = math.max(widths[field.id], needed)
        end
    end
    for _, field in ipairs(columns) do totalWidth = totalWidth + widths[field.id] end
    return columns, widths, totalWidth
end

function Page:GetSummary(character)
    if not self:HasSnapshot(character) then return nil end
    return Summary(character)
end
function Page:SetRetention(key, value, onChanged)
    value = tonumber(value)
    if (key ~= "historyDays" and key ~= "unverifiedDays") or not value or value < 1 or value > 3650 or value ~= math.floor(value) then return false end
    local previous = Addon.db.settings[key]
    local function Apply()
        if Addon.db.settings[key] ~= previous then return end
        Addon.db.settings[key] = value
        if value < previous then Addon:PruneHistory() end
        Core.AccountView:NotifyPageChanged(Page.ID)
        if onChanged then onChanged(value) end
    end
    if value >= previous then Apply(); return true end
    if not StaticPopupDialogs or not StaticPopup_Show then return false end
    StaticPopupDialogs.YIBOMAIL_RETENTION = StaticPopupDialogs.YIBOMAIL_RETENTION or {
        text = "%s", button1 = Addon:T("UI.TEXT_0463"), button2 = Addon:T("UI.TEXT_0192"), timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3,
        OnAccept = function(_, data) if data then data.Apply() end end,
    }
    StaticPopup_Show("YIBOMAIL_RETENTION", Addon:T("UI.TEXT_0123") .. previous .. Addon:T("UI.TEXT_0031") .. value .. Addon:T("UI.TEXT_0030"), nil, { Apply = Apply })
    return false -- Keep the old selection until the player accepts.
end

function Page:CreateSummary(parent)
    parent.mailRows = {}

    parent.mailAlert = CreateFrame("Frame", nil, parent)
    parent.mailAlert:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -6)
    parent.mailAlert:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -6)
    parent.mailAlert:SetHeight(26)
    parent.mailAlert.background = parent.mailAlert:CreateTexture(nil, "BACKGROUND")
    parent.mailAlert.background:SetAllPoints()
    parent.mailAlert.title = Theme:CreateText(parent.mailAlert, Theme.Font.assist, Theme.Colors.warning, "LEFT")
    parent.mailAlert.title:SetPoint("LEFT", 8, 0)
    parent.mailAlert.title:SetWidth(76)
    parent.mailAlert.text = Theme:CreateText(parent.mailAlert, Theme.Font.assist, Theme.Colors.text, "LEFT")
    parent.mailAlert.text:SetPoint("LEFT", parent.mailAlert.title, "RIGHT", 4, 0)
    parent.mailAlert.text:SetPoint("RIGHT", parent.mailAlert, "RIGHT", -116, 0)
    parent.mailAlert.action = Theme:CreateButton(parent.mailAlert, 104, Addon:T("UI.TEXT_0314"), "secondary")
    parent.mailAlert.action:SetPoint("RIGHT", parent.mailAlert, "RIGHT", -5, 0)
    parent.mailAlert.action:SetHeight(20)
    parent.mailAlert.action:SetScript("OnClick", function() Core.AccountView:Toggle(Page.ID) end)
    parent.mailAlert:Hide()

    parent.mailScroll = Theme:CreateScrollFrame(parent)
    parent.mailScroll:SetPoint("BOTTOMRIGHT", -8, 8)
    parent.mailHeader = CreateFrame("Frame", nil, parent)
    parent.mailHeader:SetHeight(24)
    parent.mailHeaderRow = nil
    parent.mailContent = CreateFrame("Frame", nil, parent.mailScroll)
    parent.mailContent:SetSize(1, 1)
    parent.mailScroll:SetScrollChild(parent.mailContent)
end

function Page:RefreshSummary(parent, context)
    local content, used, top = parent.mailContent, 0, 0
    local width = math.max(1, parent:GetWidth() - 30)
    local alert = GetPreviewAlert(context)
    parent.mailHasAlert = alert ~= nil
    parent.mailAlert:SetShown(alert ~= nil)
    if alert then
        local color = alert.severity >= 2 and Theme.Colors.limitReached or Theme.Colors.warning
        local surface = alert.severity >= 2 and Theme.Colors.dangerSurface or Theme.Colors.panel
        parent.mailAlert.background:SetColorTexture(surface[1], surface[2], surface[3], surface[4] or 1)
        parent.mailAlert.title:SetText(alert.title)
        parent.mailAlert.title:SetWidth(Theme:MeasureText(Theme.Font.assist, alert.title) + 2)
        local actionWidth = math.max(104, Theme:MeasureText(Theme.Font.body, parent.mailAlert.action.label:GetText()) + 18)
        parent.mailAlert.action:SetWidth(actionWidth)
        parent.mailAlert.text:ClearAllPoints()
        parent.mailAlert.text:SetPoint("LEFT", parent.mailAlert.title, "RIGHT", 8, 0)
        parent.mailAlert.text:SetPoint("RIGHT", parent.mailAlert, "RIGHT", -actionWidth - 16, 0)
        Theme:BindTooltip(parent.mailAlert, alert.title, { alert.text })
        parent.mailAlert.title:SetTextColor(color[1], color[2], color[3])
        parent.mailAlert.text:SetText(alert.text)
        parent.mailScroll:ClearAllPoints()
        parent.mailHeader:ClearAllPoints()
        parent.mailHeader:SetPoint("TOPLEFT", 8, -36)
    else
        parent.mailScroll:ClearAllPoints()
        parent.mailHeader:ClearAllPoints()
        parent.mailHeader:SetPoint("TOPLEFT", 8, -10)
    end
    parent.mailScroll:SetPoint("TOPLEFT", parent.mailHeader, "BOTTOMLEFT", 0, -1)
    parent.mailScroll:SetPoint("BOTTOMRIGHT", -8, 8)
    local columns, columnWidths, tableWidth = GetPreviewColumns(context)
    parent.mailColumnsHidden = #columns == 0
    if not context.preview then
        -- The host has already expanded to its safe screen edge. Fit the final
        -- main table to that viewport; full values remain available on hover.
        if tableWidth > width then
            for _, field in ipairs(columns) do columnWidths[field.id] = columnWidths[field.id] * width / tableWidth end
            tableWidth = width
        end
        local capacity = math.max(1, math.floor((parent:GetHeight() - (alert and 36 or 10) - 38) / 25))
        local state = parent.pageState or Addon.WorkspaceState:Get().overview
        local pages = math.max(1, math.ceil(#context.characters / capacity))
        state.page = math.max(1, math.min(state.page, pages))
        parent.pageCount, parent.total, parent.capacity = pages, #context.characters, capacity
    end
    if #columns == 0 then
        for _, row in ipairs(parent.mailRows) do row:Hide() end
        if parent.mailHeaderRow then parent.mailHeaderRow:Hide() end
        content:SetSize(1, 1); parent.mailScroll:SetContentHeight(1); return
    end

    local function Row(values, header, character)
        local row
        if header then
            row = parent.mailHeaderRow
        else
            used = used + 1
            row = parent.mailRows[used]
        end
        if not row then
            row = CreateFrame("Button", nil, header and parent.mailHeader or content)
            row.cells = {}
            row.realmLabels = {}
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            if header then parent.mailHeaderRow = row else parent.mailRows[used] = row end
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -top)
        row:SetSize(tableWidth, 24)
        local color = header and Theme.Colors.toolbar or Theme:GetDataRowColor(used)
        row.background:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        local rendered = columns
        local left = 0
        local visibleRealmLabel
        for index, field in ipairs(rendered) do
            local cell = row.cells[index] or Theme:CreateText(row, Theme.Font.body, Theme.Colors.text, "LEFT")
            row.cells[index] = cell
            local cellWidth = columnWidths[field.id]
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", left + 4, 0)
            cell:SetWidth(math.max(1, cellWidth - 8))
            cell:SetHeight(20)
            cell:SetWordWrap(false)
            cell:SetText(field.id == "character" and (values.character or "") or (values[field.id] or ""))
            local cellColor = Theme.Colors.text
            if field.id == "character" then
                local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[values.class or ""]
                if classColor then cell:SetTextColor(classColor.r, classColor.g, classColor.b)
                else cell:SetTextColor(cellColor[1], cellColor[2], cellColor[3]) end
                local realmLabel = row.realmLabels[index]
                if not realmLabel then
                    realmLabel = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text, "LEFT")
                    row.realmLabels[index] = realmLabel
                end
                realmLabel:ClearAllPoints()
                local realmText = values.realm and values.realm ~= "" and ("· " .. values.realm) or ""
                local nameWidth = Theme:MeasureText(Theme.Font.body, values.character)
                if not context.preview and values.realm and values.realm ~= "" then nameWidth = math.min(nameWidth, cellWidth * 0.6 - 8) end
                cell:SetWidth(math.max(1, nameWidth))
                local realmStart = nameWidth + 4
                realmLabel:SetPoint("LEFT", left + 4 + realmStart, 0)
                realmLabel:SetWidth(math.max(1, cellWidth - realmStart - 4))
                realmLabel:SetHeight(20)
                realmLabel:SetWordWrap(false)
                realmLabel:SetText(realmText)
                local realmColor = Theme.Colors.text
                realmLabel:SetTextColor(realmColor[1], realmColor[2], realmColor[3])
                realmLabel:Show()
                visibleRealmLabel = realmLabel
            elseif field.id == "expires" then
                local colorSeverity = values._expiryColorSeverity or 0
                if colorSeverity >= 2 then cellColor = Theme.Colors.limitReached
                elseif colorSeverity == 1 then cellColor = Theme.Colors.warning end
                cell:SetTextColor(cellColor[1], cellColor[2], cellColor[3])
            else
                cell:SetTextColor(cellColor[1], cellColor[2], cellColor[3])
            end
            cell:Show()
            left = left + cellWidth
        end
        for index = #rendered + 1, #row.cells do row.cells[index]:Hide() end
        for _, label in ipairs(row.realmLabels) do if label ~= visibleRealmLabel then label:Hide() end end
        row:SetScript("OnClick", character and not context.preview and function()
            if parent.onCharacter then parent.onCharacter(character.id) end
        end or nil)
        if character and not context.preview and Addon.GoalTargets and Addon.GoalTargets.ref then
            Addon.GoalTargets:Bind(row, "view-mailbox", character.id, row:GetScript("OnClick"))
        elseif Core.BusinessItemActions then Core.BusinessItemActions:Unbind(row) end
        row:SetScript("OnEnter", character and function()
            if GameTooltip then
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT"); GameTooltip:SetText(values.character)
                GameTooltip:AddLine(Addon.CacheModel:Coverage(character), 1, 1, 1, true)
                GameTooltip:AddLine(values.alert, 1, 1, 1, true)
                for _, field in ipairs(columns) do
                    GameTooltip:AddLine(field.title .. Addon:T("UI.TEXT_0653") .. tostring(values[field.id] or "—"), 1, 1, 1, true)
                end
                if Addon.GoalTargets and Addon.GoalTargets.ref then GameTooltip:AddLine(Core.BusinessItemActions:GestureLabel() .. Addon:T("UI.TEXT_0656")) end
                GameTooltip:Show()
            end
        end or nil)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        row.links = row.links or {}
        for _, link in ipairs(row.links) do link:Hide() end
        if character and not context.preview then
            local offset, linkCount = 0, 0
            for _, field in ipairs(columns) do
                if field.id == "alert" or field.id == "expires" then
                    local risk = field.id == "alert" and "attention" or (values._counts.expired > 0 and "expired" or (values._nextExpiry and values._nextExpiry <= 604800 and "sevenDays" or "all"))
                    linkCount = linkCount + 1
                    local link = row.links[linkCount] or CreateFrame("Button", nil, row); row.links[linkCount] = link
                    link:ClearAllPoints(); link:SetPoint("TOPLEFT", offset, 0); link:SetSize(columnWidths[field.id], 24)
                    link:SetScript("OnClick", function() if parent.onCharacter then parent.onCharacter(character.id, risk) end end)
                    link:SetScript("OnEnter", row:GetScript("OnEnter")); link:SetScript("OnLeave", row:GetScript("OnLeave")); link:Show()
                end
                offset = offset + columnWidths[field.id]
            end
        end
        row:Show()
        if header then parent.mailHeader:SetWidth(tableWidth)
        else top = top + row:GetHeight() + 1 end
    end

    local titles = {}
    for _, field in ipairs(fields) do titles[field.id] = field.title end
    Row(titles, true)
    local first, last = 1, #context.characters
    if not context.preview then
        first = ((parent.pageState or Addon.WorkspaceState:Get().overview).page - 1) * parent.capacity + 1
        last = math.min(last, first + parent.capacity - 1)
    end
    for index = first, last do
        local character = context.characters[index]
        local values = Summary(character, context)
        Row(values, false, character)
    end
    if #(context.characters or {}) == 0 then
        -- No synthetic row: the preview only lists roles with eligible snapshots.
    end
    for index = used + 1, #parent.mailRows do parent.mailRows[index]:Hide() end
    content:SetSize(tableWidth, math.max(1, top))
    parent.mailScroll:SetContentHeight(math.max(1, top - 1))
end

function Page:Create(parent)
    parent.mailPreview = CreateFrame("Frame", nil, parent)
    parent.mailPreview:SetAllPoints()
    self:CreateSummary(parent.mailPreview)
    Addon.CacheUI:Create(parent)
end

function Page:Refresh(parent, context)
    parent.mailPreview:SetShown(context.preview)
    parent.mailWorkspace:SetShown(not context.preview)
    if context.preview then
        self:RefreshSummary(parent.mailPreview, context)
        parent.mailPreview.elapsed = 0
        parent.mailPreview:SetScript("OnUpdate", function(frame, elapsed)
            frame.elapsed = (frame.elapsed or 0) + elapsed
            if frame.elapsed >= 30 then
                frame.elapsed = 0
                if frame:IsShown() then
                    local hasAlert = GetPreviewAlert(context) ~= nil
                    if hasAlert ~= frame.mailHasAlert then context:Refresh()
                    else Page:RefreshSummary(frame, context) end
                end
            end
        end)
    else
        parent.mailPreview:SetScript("OnUpdate", nil)
        Addon.CacheUI:Refresh(parent, context)
    end
end

local function ReminderRows(context)
    local rows = {}
    for order, character in ipairs(context.characters or {}) do
        local summary = Page:GetSummary(character)
        if summary and summary._severity > 0 then
            rows[#rows + 1] = {
                id = character.id,
                order = order,
                name = character.name,
                counts = summary._counts,
                severity = summary._severity,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.severity ~= b.severity then return a.severity > b.severity end
        return a.order < b.order
    end)
    return rows
end

function Page:OnLogin()
    if Addon.db.settings.loginReminderEnabled == false or not C_Timer or not C_Timer.After then return end
    C_Timer.After(5, function()
        local page = Core.AccountView and Core.AccountView._pages[Page.ID]
        if not page then return end
        local context = Core.AccountView:BuildContext(page, { preview = false })
        local rows = ReminderRows(context)
        if #rows == 0 then return end

        local parts, signatureParts, stateRows, level = {}, {}, {}, 0
        for _, row in ipairs(rows) do
            local counts = row.counts
            local label = row.name .. Addon:T("UI.TEXT_0653")
            if counts.expired > 0 then label = label .. Addon:T("UI.TEXT_0158") .. counts.expired .. Addon:T("UI.TEXT_0235") end
            if counts.urgent > 0 then label = label .. Addon:T("UI.TEXT_0483") .. counts.urgent .. Addon:T("UI.TEXT_0235") end
            if counts.soon > 0 then label = label .. Addon:T("UI.TEXT_0097") .. counts.soon .. Addon:T("UI.TEXT_0239") end
            if counts.nearest then label = label:gsub(" · $", "") .. Addon:T("UI.TEXT_0646") .. counts.nearest .. Addon:T("UI.TEXT_0649") end
            parts[#parts + 1] = label:gsub(" · $", "")
            signatureParts[#signatureParts + 1] = Addon.Encode({ row.id, counts.expired, counts.urgent, counts.soon })
            stateRows[row.id] = { expired = counts.expired, urgent = counts.urgent, soon = counts.soon }
            level = math.max(level, row.severity)
        end
        local signature = Addon.Encode(signatureParts)
        local day = date("%Y-%m-%d", Addon:Now())
        local previous = Addon.db.settings.loginReminderState
        local increased = false
        if previous and previous.day == day then
            if previous.signature == signature then return end
            for characterID, counts in pairs(stateRows) do
                local old = previous.rows and previous.rows[characterID]
                if not old and (counts.expired + counts.urgent + counts.soon) > 0 then increased = true; break end
                if old and (counts.expired > (old.expired or 0) or counts.urgent > (old.urgent or 0) or counts.soon > (old.soon or 0)) then increased = true; break end
            end
            if not increased and level <= (previous.level or 0) then return end
        end

        local visible = {}
        for index = 1, math.min(3, #parts) do visible[#visible + 1] = parts[index] end
        if #parts > #visible then visible[#visible + 1] = Addon:T("UI.TEXT_0193") .. (#parts - #visible) .. Addon:T("UI.TEXT_0024") end
        Addon:Print(table.concat(visible, Addon:T("UI.TEXT_0657")) .. Addon:T("UI.TEXT_0080"))
        Addon.db.settings.loginReminderState = { day = day, signature = signature, level = level, rows = stateRows }
    end)
end

function Page:RefreshShortcutPreview(section)
    local rows, columns = Addon:GetShortcutLayout()
    local step = math.min(26, math.floor(104 / columns), math.floor(208 / rows))
    for index, slot in ipairs(section.previewSlots or {}) do
        slot:ClearAllPoints(); slot:SetSize(step - 4, step - 4)
        slot:SetPoint("TOPLEFT", section.previewX + ((index - 1) % columns) * step,
            -(section.previewY + math.floor((index - 1) / columns) * step))
        slot:SetShown(index <= rows * columns)
    end
    section.gridCount:SetText(Addon:T("UI.TEXT_0268") .. rows * columns .. Addon:T("UI.TEXT_0041"))
end

function Page:Register()
    local registered, err = Core.AccountView:RegisterPage(Addon.NAME, {
        id = self.ID,
        title = Addon:T("UI.TEXT_0592"),
        fields = pageFields,
        defaultEnabled = true,
        previewEnabled = true,
        settings = {
            title = Addon:T("UI.TEXT_0592"),
            description = Addon:T("UI.TEXT_0161"),
            CreateSettingsPanel = function(parent, host)
                local width = math.max(280, parent:GetWidth() or 600)
                local narrow = width < 600
                local columnWidth = narrow and width - 24 or (width - 48) / 2
                local businessHeight = narrow and 776 or 448
                local section = parent.mailBusinessSettings or host.createSection(parent, Addon:T("UI.TEXT_0093"), width, businessHeight)
                parent.mailBusinessSettings = section
                section:SetSize(width, businessHeight); section:Show(); section:ClearAllPoints()
                section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
                if not section.cleanupHook then
                    section.cleanupHook = true
                    section:HookScript("OnHide", function()
                        if section.shortcutRows then section.shortcutRows.menu:Hide() end
                        if section.shortcutColumns then section.shortcutColumns.menu:Hide() end
                    end)
                end
                local function Text(key, value, x, y, textWidth, height, muted)
                    local label = section[key] or Theme:CreateText(section, Theme.Font.assist, muted and Theme.Colors.muted or Theme.Colors.text, "LEFT")
                    section[key] = label; label:ClearAllPoints(); label:SetPoint("TOPLEFT", x, -y)
                    label:SetWidth(textWidth); label:SetHeight(height or 24); label:SetWordWrap(true); label:SetText(value)
                    return label
                end
                Text("groupsTitle", Addon:T("UI.TEXT_0586"), 12, 40, columnWidth)
                Text("groupsHelp", Addon:T("UI.TEXT_0583"), 12, 68, columnWidth, 24, true)
                section.groups = section.groups or {}
                for index, source in ipairs(Addon.RECIPIENT_SOURCES) do
                    local sourceID = source.id
                    local checkbox = section.groups[sourceID] or host.createCheckbox(section, source.label)
                    section.groups[sourceID] = checkbox; checkbox:ClearAllPoints()
                    checkbox:SetPoint("TOPLEFT", 12 + ((index - 1) % 2) * (columnWidth / 2), -(100 + math.floor((index - 1) / 2) * 34))
                    checkbox:SetWidth(columnWidth / 2 - 6); checkbox:SetChecked(Addon:IsRecipientSourceVisible(sourceID))
                    checkbox:SetScript("OnClick", function(control)
                        local visible = not control:GetChecked(); control:SetChecked(visible)
                        Addon.db.settings.recipientGroups = Addon.db.settings.recipientGroups or {}
                        Addon.db.settings.recipientGroups[sourceID] = visible
                        if Addon.Recipients then Addon.Recipients:Changed() end
                    end)
                end
                Text("groupsNote", Addon:T("UI.TEXT_0636"), 12, 204, columnWidth, 40, true)
                Text("reminderTitle", Addon:T("UI.TEXT_0160"), 12, 258, columnWidth)
                local checkbox = section.reminder or host.createCheckbox(section, Addon:T("UI.TEXT_0462"))
                section.reminder = checkbox; checkbox:ClearAllPoints(); checkbox:SetPoint("TOPLEFT", 12, -290)
                checkbox:SetWidth(columnWidth); checkbox:SetChecked(Addon.db.settings.loginReminderEnabled ~= false)
                checkbox.label:SetWordWrap(true)
                checkbox.label:SetHeight(32)
                checkbox:SetScript("OnClick", function(control)
                    control:SetChecked(not control:GetChecked()); Addon.db.settings.loginReminderEnabled = control:GetChecked()
                end)
                Text("reminderNote", Addon:T("UI.TEXT_0321"), 12, 322, columnWidth, 42, true)
                Text("goldConfirmationTitle", Addon:T("UI.TEXT_0673"), 12, 370, columnWidth)
                local goldCheckbox = section.goldConfirmation or host.createCheckbox(section, Addon:T("UI.TEXT_0674"))
                section.goldConfirmation = goldCheckbox; goldCheckbox:ClearAllPoints(); goldCheckbox:SetPoint("TOPLEFT", 12, -402)
                goldCheckbox:SetWidth(columnWidth); goldCheckbox:SetChecked(Addon.db.settings.confirmGoldSend ~= false)
                goldCheckbox.label:SetWordWrap(true); goldCheckbox.label:SetHeight(32)
                goldCheckbox:SetScript("OnClick", function(control)
                    control:SetChecked(not control:GetChecked()); Addon.db.settings.confirmGoldSend = control:GetChecked()
                end)
                Text("goldConfirmationNote", Addon:T("UI.TEXT_0675"), 12, 434, columnWidth, 36, true)
                local gridX, gridY = narrow and 12 or 36 + columnWidth, narrow and 448 or 40
                Text("gridTitle", Addon:T("UI.TEXT_0294"), gridX, gridY, columnWidth)
                local rows, columns = Addon:GetShortcutLayout()
                local function GridOption(key, title, x, maximum, current)
                    local fieldWidth = (columnWidth - 12) / 2
                    Text(key .. "Title", title, x, gridY + 32, fieldWidth)
                    local options = {}; for value = 1, maximum do options[#options + 1] = { value = value, label = value .. (key == "shortcutRows" and Addon:T("UI.TEXT_0048") or Addon:T("UI.TEXT_0029")) } end
                    local dropdown = section[key] or Theme:CreateDropdown(section, fieldWidth, options)
                    section[key] = dropdown; dropdown:ClearAllPoints(); dropdown:SetWidth(fieldWidth); dropdown:SetOptions(options)
                    dropdown:SetPoint("TOPLEFT", x, -(gridY + 58)); dropdown:SetValue(current)
                    dropdown:SetOnValueChanged(function(value)
                        Addon.db.settings[key] = value
                        if Addon.RecipientUI then Addon.RecipientUI:Hide() end
                        if Addon.NativeUI and Addon.NativeUI.readySend then
                            Addon.NativeUI:LayoutBasicSend(); Addon.NativeUI:RefreshFavoriteButtons()
                        end
                        Page:RefreshShortcutPreview(section)
                    end)
                end
                GridOption("shortcutRows", Addon:T("UI.TEXT_0376"), gridX, 12, rows)
                GridOption("shortcutColumns", Addon:T("UI.TEXT_0375"), gridX + (columnWidth + 12) / 2, 6, columns)
                section.previewSlots = section.previewSlots or {}
                for index = 1, 72 do
                    local slot = section.previewSlots[index] or CreateFrame("Frame", nil, section, "BackdropTemplate")
                    section.previewSlots[index] = slot
                    slot:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
                    slot:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
                end
                section.previewX, section.previewY = gridX, gridY + 104
                Text("gridCount", "", gridX + 114, gridY + 104, columnWidth - 114, 26, true)
                Text("gridNote", Addon:T("UI.TEXT_0147"), gridX + 114, gridY + 138, columnWidth - 114, 66, true)
                Page:RefreshShortcutPreview(section)
                local cache = parent.mailCacheSettings or host.createSection(parent, Addon:T("UI.TEXT_0353"), width, 156)
                parent.mailCacheSettings = cache; cache:SetSize(width, 156); cache:Show()
                if not cache.cleanupHook then
                    cache.cleanupHook = true; cache:HookScript("OnHide", function()
                        if cache.historyDays then cache.historyDays.menu:Hide() end
                        if cache.unverifiedDays then cache.unverifiedDays.menu:Hide() end
                    end)
                end
                cache:ClearAllPoints(); cache:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(businessHeight + 8))
                local columnWidth = (width - 36) / 2
                local function Retention(x, label, key, choices)
                    local title = cache[key .. "Title"] or Theme:CreateText(cache, Theme.Font.assist, Theme.Colors.text, "LEFT")
                    cache[key .. "Title"] = title; title:ClearAllPoints()
                    title:SetPoint("TOPLEFT", x, -36); title:SetWidth(columnWidth); title:SetText(label)
                    local found = false; for _, choice in ipairs(choices) do if choice.value == Addon.db.settings[key] then found = true end end
                    if not found then choices[#choices + 1] = { value = Addon.db.settings[key], label = Addon.db.settings[key] .. Addon:T("UI.TEXT_0212") } end
                    local dropdown = cache[key] or Theme:CreateDropdown(cache, columnWidth, choices)
                    dropdown:ClearAllPoints(); dropdown:SetWidth(columnWidth); dropdown:SetOptions(choices)
                    dropdown:SetPoint("TOPLEFT", x, -58); dropdown:SetValue(Addon.db.settings[key])
                    dropdown:SetOnValueChanged(function(value)
                        local applied = Page:SetRetention(key, value, function(accepted) dropdown:SetValue(accepted) end)
                        if not applied then dropdown:SetValue(Addon.db.settings[key]) end
                    end)
                    cache[key] = dropdown
                end
                Retention(12, Addon:T("UI.TEXT_0254"), "historyDays", { { value = 7, label = Addon:T("UI.TEXT_0064") }, { value = 30, label = Addon:T("UI.TEXT_0063") }, { value = 90, label = Addon:T("UI.TEXT_0065") }, { value = 180, label = Addon:T("UI.TEXT_0060") } })
                Retention(24 + columnWidth, Addon:T("UI.TEXT_0291"), "unverifiedDays", { { value = 7, label = Addon:T("UI.TEXT_0064") }, { value = 30, label = Addon:T("UI.TEXT_0063") }, { value = 90, label = Addon:T("UI.TEXT_0065") } })
                local note = cache.note or Theme:CreateText(cache, Theme.Font.assist, Theme.Colors.muted, "LEFT")
                cache.note = note; note:ClearAllPoints()
                note:SetPoint("TOPLEFT", 12, -98); note:SetPoint("TOPRIGHT", -12, -98); note:SetHeight(48); note:SetWordWrap(true)
                note:SetText(Addon:T("UI.TEXT_0490"))
                if Addon.SendRulesSettings then return Addon.SendRulesSettings:Host(parent, host, section, cache, width, businessHeight) end
                return businessHeight + 8 + 156
            end,
        },
        scope = { mode = "realms", allTitle = Addon:T("UI.TEXT_0311") },
        previewCharacterLimit = false,
        HasCharacterSnapshot = function(character) return Page:HasSnapshot(character) or Addon.HistoryModel:HasHistory(character) end,
        GetEligibleCharacters = function(characters, baseContext)
            local eligible = {}
            for _, character in ipairs(characters or {}) do
                if Page:HasSnapshot(character) or (not (baseContext and baseContext.preview) and Addon.HistoryModel:HasHistory(character)) then eligible[#eligible + 1] = character end
            end
            return eligible
        end,
        GetPreviewFields = function()
            local projection = {}
            for _, field in ipairs(pageFields) do projection[field.id] = field.preview ~= false and Addon.db.settings.previewColumns[field.id] == true end
            return projection
        end,
        SetPreviewFieldVisible = function(id, visible)
            Addon.db.settings.previewColumns[id] = not not visible
        end,
        GetHoverMetrics = function(context)
            local rows = #(context and context.characters or {}) + 1
            local hasAlert = GetPreviewAlert(context) ~= nil
            local _, _, tableWidth = GetPreviewColumns(context)
            -- GetHoverMetrics returns the whole window, including Core's
            -- title bar/borders. The header is outside the scroll viewport.
            local shellHeight = Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2
            local height = shellHeight + (hasAlert and 36 or 10) + 24 + 1 + 8 + (rows - 1) * 25
            return {
                minWidth = 440,
                preferredWidth = math.max(480, tableWidth + 34),
                minHeight = shellHeight + (hasAlert and 36 or 10) + 24 + 1 + 8 + 25,
                preferredHeight = height,
                horizontalOverflow = "content",
                verticalOverflow = "content",
            }
        end,
        GetSurfaceMetrics = function(context)
            local eligible = Addon.CacheModel:Characters(context)
            local measuredContext = { characters = eligible, GetFieldVisible = context.GetFieldVisible }
            local _, _, width = GetPreviewColumns(measuredContext)
            local sidebarWidth = 230
            for _, character in ipairs(eligible) do
                sidebarWidth = math.max(sidebarWidth, Theme:MeasureText(Theme.Font.body, Core.Characters:GetDisplayName(character, "short")) + 132)
            end
            local inboxWidth, historyWidth = math.min(284, sidebarWidth + 24) + 8, 32
            for _, field in ipairs(pageFields) do
                if field.width and context:GetFieldVisible(field.id) then
                    if field.groupID == "inbox" then inboxWidth = inboxWidth + field.width
                    elseif field.groupID == "history" then historyWidth = historyWidth + field.width end
                end
            end
            return { minContentWidth = 1000, naturalContentWidth = math.max(1154, width + 34, inboxWidth, historyWidth),
                minContentHeight = 480, naturalContentHeight = 620, horizontalOverflow = "none", verticalOverflow = "none" }
        end,
        Create = function(parent) Page:Create(parent) end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end,
    })
    if not registered then return nil, err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "yma",
        brokerName = "YiboMail",
        pageID = self.ID,
        text = Addon:T("ENTRY.TITLE"),
        icon = "Interface\\AddOns\\YiboMail\\Media\\YiboMailIcon",
        defaultChannels = { minimap = false, broker = false, builtinBar = false },
    })
end
