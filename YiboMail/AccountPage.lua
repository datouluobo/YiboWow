local Addon = _G.YiboMail
local Core, Page = _G.YiboCore, {}
Addon.AccountPage = Page
Page.ID = "mail-inbox"

local Theme = Core.UITheme
local fields = {
    { id = "character", title = "角色" },
    { id = "count", title = "邮件数" },
    { id = "attachments", title = "附件数" },
    { id = "money", title = "可收金币" },
    { id = "expires", title = "最早到期" },
    { id = "status", title = "更新状态" },
    { id = "alert", title = "到期提醒" },
    { id = "cod", title = "COD邮件" },
    { id = "backlog", title = "待核实缓存", defaultVisible = false },
}
for _, field in ipairs(fields) do field.group = "账号总览" end
local pageFields = {}
for _, field in ipairs(fields) do pageFields[#pageFields + 1] = field end
for _, group in ipairs({
    { "收件箱", "inbox", { { "character", "角色", 130 }, { "sender", "发件人", 110 }, { "subject", "主题", 160 },
        { "items", "附件", 160 }, { "amount", "金币/COD", 100 }, { "expiry", "期限", 100 }, { "coverage", "更新状态", 180 } } },
    { "历史记录", "history", { { "time", "时间", 110 }, { "character", "角色", 130 }, { "event", "事件", 85 },
        { "counterpart", "对方", 110 }, { "subject", "主题", 140 }, { "content", "附件/金币", 170 }, { "result", "结果", 110 } } },
}) do
    for _, definition in ipairs(group[3]) do
        pageFields[#pageFields + 1] = { id = group[2] .. "." .. definition[1], key = definition[1], title = definition[2],
            width = definition[3], group = group[1], preview = false }
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

local function Summary(character)
    local snapshot = Addon.db.byCharacter[character.id]
    local coverage = snapshot.coverage
    local now = Addon:Now()
    local counts = { expired = 0, urgent = 0, soon = 0, unknown = 0, within3Days = 0, within7Days = 0 }
    local nextExpiry, visibleCount, attachmentQuantity, availableMoney, codCount, backlog = nil, 0, 0, 0, 0, 0
    local expiryColorSeverity = 0

    local usedMarkers = {}
    for _, mail in pairs(snapshot.records or {}) do if mail.state == "unverified" then backlog = backlog + 1 end end
    for _, key in ipairs(snapshot.visibleKeys or {}) do
        local mail = snapshot.records[key]
        if mail and not Addon.ViewModel:IsCollectedEmptyMail(character.id, mail, usedMarkers) then
            visibleCount = visibleCount + 1
            for _, item in ipairs(mail.attachments or {}) do
                attachmentQuantity = attachmentQuantity + (tonumber(item.quantity) or 0)
            end
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
        expires = "待核实 " .. counts.expired
    elseif nextExpiry then
        if nextExpiry < 86400 then expires = string.format("约%.1f小时", nextExpiry / 3600)
        else expires = string.format("约%.1f天", nextExpiry / 86400) end
    elseif counts.unknown > 0 then expires = "期限未知"
    end
    counts.nearest = counts.expired > 0 and "已有邮件到估算期限" or (expires ~= "—" and ("最早 " .. expires) or nil)

    local status = coverage.observedAt and date("%m-%d %H:%M", coverage.observedAt) or "—"
    local live = Addon.Items:GetState(character.id)
    if live.status == "error" then status = "读取失败 · " .. status
    elseif coverage.status == "partial" then status = "部分 · " .. status end
    local alerts = {}
    if counts.expired > 0 then alerts[#alerts + 1] = "到期待核实 " .. counts.expired end
    if counts.urgent > 0 then alerts[#alerts + 1] = "紧急 " .. counts.urgent end
    if counts.soon > 0 then alerts[#alerts + 1] = "临期 " .. counts.soon end

    local severity = counts.expired > 0 and 3 or (counts.urgent > 0 and 2 or (counts.soon > 0 and 1 or 0))
    return {
        character = Core.Characters:GetDisplayName(character, "short"),
        realm = character.realm or "",
        class = character.class,
        count = mailCount,
        attachments = tostring(attachmentQuantity),
        money = availableMoney > 0 and string.format("%.1f 金", availableMoney / 10000) or "—",
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
        return { title = "待核实", text = expired .. " 封邮件已到估算期限 · 请打开邮箱重新核对", severity = 2 }
    elseif within3Days > 0 then
        local when = nearest and string.format("最早约 %.1f 天", nearest / 86400) or ""
        return { title = "即将到期", text = within3Days .. " 封邮件将在 3 天内到期" .. (when ~= "" and (" · " .. when) or ""), severity = 2 }
    elseif within7Days > 0 then
        local when = nearest and string.format("最早约 %.1f 天", nearest / 86400) or ""
        return { title = "即将到期", text = within7Days .. " 封邮件将在 7 天内到期" .. (when ~= "" and (" · " .. when) or ""), severity = 1 }
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
        local values = Summary(character)
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
        text = "%s", button1 = ACCEPT or "确认", button2 = CANCEL or "取消", timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3,
        OnAccept = function(_, data) if data then data.Apply() end end,
    }
    StaticPopup_Show("YIBOMAIL_RETENTION", "保留期限从 " .. previous .. " 天缩短为 " .. value .. " 天。确认后按新期限清理超期历史与待核实记录，无法恢复。", nil, { Apply = Apply })
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
    parent.mailAlert.action = Theme:CreateButton(parent.mailAlert, 104, "打开邮件页 →", "secondary")
    parent.mailAlert.action:SetPoint("RIGHT", parent.mailAlert, "RIGHT", -5, 0)
    parent.mailAlert.action:SetHeight(20)
    parent.mailAlert.action:SetScript("OnClick", function() Core.AccountView:Toggle(Page.ID) end)
    parent.mailAlert:Hide()

    parent.mailScroll = Theme:CreateScrollFrame(parent)
    parent.mailScroll:SetPoint("TOPLEFT", 8, -32)
    parent.mailScroll:SetPoint("BOTTOMRIGHT", -8, 8)
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
        parent.mailAlert.title:SetTextColor(color[1], color[2], color[3])
        parent.mailAlert.text:SetText(alert.text)
        parent.mailScroll:ClearAllPoints()
        parent.mailScroll:SetPoint("TOPLEFT", 8, -36)
    else
        parent.mailScroll:ClearAllPoints()
        parent.mailScroll:SetPoint("TOPLEFT", 8, -10)
    end
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
        content:SetSize(1, 1); parent.mailScroll:SetContentHeight(1); return
    end

    local function Row(values, header, character)
        used = used + 1
        local row = parent.mailRows[used]
        if not row then
            row = CreateFrame("Button", nil, content)
            row.cells = {}
            row.realmLabels = {}
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            parent.mailRows[used] = row
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
        row:SetScript("OnEnter", character and function()
            if GameTooltip then
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT"); GameTooltip:SetText(values.character)
                GameTooltip:AddLine(Addon.CacheModel:Coverage(character), 1, 1, 1, true)
                GameTooltip:AddLine(values.alert, 1, 1, 1, true)
                for _, field in ipairs(columns) do
                    GameTooltip:AddLine(field.title .. "：" .. tostring(values[field.id] or "—"), 1, 1, 1, true)
                end
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
        top = top + row:GetHeight() + 1
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
        local values = Summary(character)
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
            local label = row.name .. "："
            if counts.expired > 0 then label = label .. "到期待核实 " .. counts.expired .. "封 · " end
            if counts.urgent > 0 then label = label .. "紧急 " .. counts.urgent .. "封 · " end
            if counts.soon > 0 then label = label .. "临期 " .. counts.soon .. "封" end
            if counts.nearest then label = label:gsub(" · $", "") .. "（" .. counts.nearest .. "）" end
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
        if #parts > #visible then visible[#visible + 1] = "另有 " .. (#parts - #visible) .. " 个角色需处理" end
        Addon:Print(table.concat(visible, "；") .. "。按上次扫描估算，请打开邮件页查看。")
        Addon.db.settings.loginReminderState = { day = day, signature = signature, level = level, rows = stateRows }
    end)
end

function Page:Register()
    local registered, err = Core.AccountView:RegisterPage(Addon.NAME, {
        id = self.ID,
        title = "邮件助手",
        fields = pageFields,
        defaultEnabled = true,
        previewEnabled = true,
        settings = {
            title = "邮件助手",
            description = "到期提醒使用最后一次成功扫描的邮件估算。",
            CreateSettingsPanel = function(parent, host)
                local width = math.max(280, parent:GetWidth() or 600)
                local section = parent.mailBusinessSettings or host.createSection(parent, "业务设置", width, 96)
                parent.mailBusinessSettings = section; section:SetSize(width, 96); section:Show()
                section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
                local checkbox = section.reminder or host.createCheckbox(section, "登录时提醒临期或到期邮件")
                section.reminder = checkbox
                checkbox:SetPoint("TOPLEFT", 12, -38)
                checkbox:SetWidth(width - 24)
                checkbox:SetChecked(Addon.db.settings.loginReminderEnabled ~= false)
                checkbox:SetScript("OnClick", function(control)
                    control:SetChecked(not control:GetChecked())
                    Addon.db.settings.loginReminderEnabled = control:GetChecked()
                end)
                local cache = parent.mailCacheSettings or host.createSection(parent, "数据与缓存", width, 156)
                parent.mailCacheSettings = cache; cache:SetSize(width, 156); cache:Show()
                if not cache.cleanupHook then
                    cache.cleanupHook = true; cache:HookScript("OnHide", function()
                        if cache.historyDays then cache.historyDays.menu:Hide() end
                        if cache.unverifiedDays then cache.unverifiedDays.menu:Hide() end
                    end)
                end
                cache:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -104)
                local columnWidth = (width - 36) / 2
                local function Retention(x, label, key, choices)
                    local title = cache[key .. "Title"] or Theme:CreateText(cache, Theme.Font.assist, Theme.Colors.text, "LEFT")
                    cache[key .. "Title"] = title; title:ClearAllPoints()
                    title:SetPoint("TOPLEFT", x, -36); title:SetWidth(columnWidth); title:SetText(label)
                    local found = false; for _, choice in ipairs(choices) do if choice.value == Addon.db.settings[key] then found = true end end
                    if not found then choices[#choices + 1] = { value = Addon.db.settings[key], label = Addon.db.settings[key] .. "天" } end
                    local dropdown = cache[key] or Theme:CreateDropdown(cache, columnWidth, choices)
                    dropdown:ClearAllPoints(); dropdown:SetWidth(columnWidth); dropdown:SetOptions(choices)
                    dropdown:SetPoint("TOPLEFT", x, -58); dropdown:SetValue(Addon.db.settings[key])
                    dropdown:SetOnValueChanged(function(value)
                        local applied = Page:SetRetention(key, value, function(accepted) dropdown:SetValue(accepted) end)
                        if not applied then dropdown:SetValue(Addon.db.settings[key]) end
                    end)
                    cache[key] = dropdown
                end
                Retention(12, "已确认历史保留", "historyDays", { { value = 7, label = "7天" }, { value = 30, label = "30天" }, { value = 90, label = "90天" }, { value = 180, label = "180天" } })
                Retention(24 + columnWidth, "待核实记录保留", "unverifiedDays", { { value = 7, label = "7天" }, { value = 30, label = "30天" }, { value = 90, label = "90天" } })
                local note = cache.note or Theme:CreateText(cache, Theme.Font.assist, Theme.Colors.muted, "LEFT")
                cache.note = note; note:ClearAllPoints()
                note:SetPoint("TOPLEFT", 12, -98); note:SetPoint("TOPRIGHT", -12, -98); note:SetHeight(48); note:SetWordWrap(true)
                note:SetText("展示时间范围不改变保留期限。登录时清理超期数据；缩短期限需确认，确认后立即清理超期历史和待核实记录。")
                return 268
            end,
        },
        scope = { mode = "realms", allTitle = "所有服务器" },
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
            -- Match the actual scroll viewport exactly: top offset (alert or
            -- no alert), 24px rows with 1px gaps, and the 8px bottom inset.
            local height = (hasAlert and 36 or 10) + 8 + rows * 25 + 2
            return {
                minWidth = 440,
                preferredWidth = math.max(480, tableWidth + 34),
                minHeight = height,
                preferredHeight = height,
                horizontalOverflow = "content",
                verticalOverflow = "none",
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
                    if field.group == "收件箱" then inboxWidth = inboxWidth + field.width
                    elseif field.group == "历史记录" then historyWidth = historyWidth + field.width end
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
        text = "[Yibo] YiboMail - 邮件助手",
        icon = "Interface\\AddOns\\YiboMail\\Media\\YiboMailIcon-v1",
    })
end
