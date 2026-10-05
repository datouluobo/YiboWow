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
local function Name(character) return Core.Characters:GetDisplayName(character, "short") end
local function ColoredName(character)
    local color = character.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class]
    local name = Escape(Name(character))
    if color then return string.format("|cff%02x%02x%02x%s|r", math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5), name) end
    return name
end
local function Identity(character) return ColoredName(character) .. " · " .. Escape(character.realm) end
local function Stamp(time) return time and date("%m-%d %H:%M", time) or "时间未知" end
local function Enable(button, enabled)
    button:SetEnabled(enabled); button:SetState(enabled and "default" or "disabled")
end
local function Tooltip(control, lines, item, wrap)
    control:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        if item and item.itemLink and item.itemLink ~= "" then GameTooltip:SetHyperlink(item.itemLink)
        elseif item and item.itemID then GameTooltip:SetHyperlink("item:" .. tostring(item.itemID))
        else GameTooltip:SetText(lines[1] or "邮件") end
        for index = item and 1 or 2, #lines do GameTooltip:AddLine(lines[index], 1, 1, 1, wrap ~= false) end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
function UI:AttachmentTooltip(group)
    local lines = { Escape(group.item.name or ("物品 " .. tostring(group.item.itemID))),
        "合计 " .. group.quantity .. "件 · " .. group.mailCount .. "封邮件",
        "普通附件 " .. group.normalQuantity .. " · COD附件 " .. group.codQuantity }
    for _, source in ipairs(group.sources) do
        local entry = source.entry
        lines[#lines + 1] = "邮箱：" .. Identity(entry.character) .. " · 发件人：" .. Escape(entry.mail.sender)
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
        { id = "inbox", title = "收件箱", width = 112 }, { id = "overview", title = "账号总览", width = 126 },
        { id = "history", title = "历史记录", width = 126 },
    }, function(id) Addon.WorkspaceState:Get().tab = id; root.notice = nil; Refresh() end)
    root.heading = Text(root, Theme.Font.section)
    root.note = Text(root, Theme.Font.assist, Theme.Colors.muted)
    root.search = Theme:CreateInput(root, {
        width = 260, placeholder = "全局搜索角色、对方、主题、物品 / ID", maxLetters = 120, clearable = true,
        OnChanged = function(value)
            if root.syncing then return end
            root.searchQuery = value
            local state = Addon.WorkspaceState:Get()
            if state.tab == "inbox" then Addon.WorkspaceState:Search(value)
            else state.history.search, state.history.scroll, state.history.anchor, state.history.detail = value, 0, nil, nil end
            Refresh()
        end,
    })
    root.clear = Button("清除条件", function()
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
    root.mail = Button("按邮件", function() local s = Addon.WorkspaceState:Get().inbox; s.mode, s.scroll, s.detail, s.detailReturn, s.anchor = "mail", 0, nil, nil, nil; Refresh() end, 84)
    root.items = Button("附件汇总", function() local s = Addon.WorkspaceState:Get().inbox; s.mode, s.scroll, s.detail, s.detailReturn, s.anchor = "items", 0, nil, nil, nil; Refresh() end, 96)
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
    root.scope = Dropdown({ { value = "latest", label = "最新快照" }, { value = "unverified", label = "待核实缓存" } }, "scope", 148)
    root.kind = Dropdown({}, "kind", 134)
    root.risk = Dropdown({ { value = "all", label = "风险：全部" }, { value = "urgent", label = "24小时内" },
        { value = "soon", label = "1–3天" }, { value = "threeDays", label = "三天内到期" },
        { value = "sevenDays", label = "七天内到期" }, { value = "attention", label = "全部到期提醒" },
        { value = "expired", label = "到期待核实" }, { value = "unknown", label = "期限未知" } }, "risk", 150)
    root.sort = Dropdown({ { value = "expiry", label = "临期优先" }, { value = "character", label = "角色顺序" } }, "sort", 154)
    root.days = Dropdown({ { value = 7, label = "近7天" }, { value = 30, label = "近30天" }, { value = 90, label = "近90天" }, { value = 0, label = "保留范围内全部" } }, "days", 160)
    root.historyCharacter = Dropdown({}, "character", 190)
    root.historyCharacter:SetMenuPageSize(8)
    root.result = Dropdown({ { value = "all", label = "结果：全部" }, { value = "collected-archived", label = "已收取" },
        { value = "in-transit", label = "已发送 / 在途" }, { value = "unverified", label = "待核实" },
        { value = "received-confirmed", label = "确认收到" }, { value = "return-confirmed", label = "确认退回" } }, "result", 154)
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
        local index = math.floor(offset / layout.pitch) * layout.columns + 1
        state.scroll, state.anchorOffset = offset, offset % layout.pitch
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
    root.overview.mailAlert.action:SetText("查看邮件 →")
    root.previous = Button("上一页", function() local s = Addon.WorkspaceState:Get(); s[s.tab].page = s[s.tab].page - 1; s[s.tab].anchor = nil; Refresh() end, 90)
    root.next = Button("下一页", function() local s = Addon.WorkspaceState:Get(); s[s.tab].page = s[s.tab].page + 1; s[s.tab].anchor = nil; Refresh() end, 90)
    root.pages = Text(root, Theme.Font.assist, Theme.Colors.muted)
    root.back = Button("返回", function()
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
    local total, left = 0, 0
    for _, entry in ipairs(controls) do total = total + entry[2] end
    local scale = math.min(1, math.max(1, width - (#controls - 1) * 6) / math.max(1, total))
    for _, entry in ipairs(controls) do
        local control, wanted = entry[1], entry[2]
        local actual = wanted * scale
        Place(control, x + left, y, actual, 30); control:Show(); left = left + actual + 6
    end
    return y + 38
end
function UI:Columns(root, prefix, global)
    local columns = {}
    for _, field in ipairs(Addon.AccountPage.Fields) do
        if field.group == ({ inbox = "收件箱", history = "历史记录", attachment = "附件汇总" })[prefix] and root.context:GetFieldVisible(field.id)
            and not (prefix == "inbox" and field.key == "character" and not global) then columns[#columns + 1] = field end
    end
    return columns
end
function UI:FitColumns(fields, width, prefix)
    local result = {}; for _, field in ipairs(fields) do result[#result + 1] = field end
    local priorities = prefix == "inbox" and { "coverage", "items", "sender" } or { "content", "counterpart", "result" }
    local function Total() local total = 0; for _, field in ipairs(result) do total = total + field.width end; return total end
    for _, key in ipairs(priorities) do
        if Total() <= width then break end
        for index, field in ipairs(result) do if field.key == key then table.remove(result, index); break end end
    end
    return result
end
function UI:TableRow(root, row, fields, values, width, height, header)
    row.cells = row.cells or {}
    local total = 0; for _, field in ipairs(fields) do total = total + field.width end
    local left = 0
    for index, field in ipairs(fields) do
        local cell = row.cells[index] or Text(row, Theme.Font.body); row.cells[index] = cell
        local cellWidth = width * field.width / math.max(1, total)
        Place(cell, left + 6, 4, cellWidth - 12, height - 8)
        cell:SetText(header and field.title or values[field.key] or "—")
        cell:SetTextColor(unpack(Theme.Colors.text)); cell:Show()
        if not header and (field.key == "items" or field.key == "content") and values.icon then
            row.icon = row.icon or row:CreateTexture(nil, "ARTWORK")
            Place(row.icon, left + 5, (height - 22) / 2, 22, 22)
            row.icon:SetTexture(values.icon.texture or "Interface\\Icons\\INV_Misc_QuestionMark"); row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); row.icon:Show()
            Place(cell, left + 31, 4, cellWidth - 37, height - 8)
        end
        if not header and field.key == "expiry" then
            local color = values.expirySeverity == 2 and Theme.Colors.limitReached or (values.expirySeverity == 1 and Theme.Colors.warning or Theme.Colors.text)
            cell:SetTextColor(unpack(color))
        end
        left = left + cellWidth
    end
    for index = #fields + 1, #row.cells do row.cells[index]:Hide() end
end
function UI:Owners(root, characters, entries, state, x, top, width, height)
    Place(root.owners, x, top, width, height); root.owners:Show()
    local matches = {}
    for _, entry in ipairs(entries) do matches[entry.character.id] = (matches[entry.character.id] or 0) + 1 end
    local list = { { name = "全部角色", count = #entries } }
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
        local rowWidth = width - (#list * 34 > height and Theme.Geometry.scrollbarGutter or 0)
        Place(row, 0, (index - 1) * 34, rowWidth, 32)
        local searching = (state.search or ""):find("%S") ~= nil
        local selected = not searching and state.character == character.id
        row:SetBackdropColor(unpack(selected and Theme.Colors.selected or Theme:GetDataRowColor(index)))
        row:SetBackdropBorderColor(unpack(selected and Theme.Colors.accent or Theme.Colors.lineSoft))
        local coords = character.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.class]
        row.icon:SetTexture(coords and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or "Interface\\Icons\\INV_Letter_15")
        if coords then row.icon:SetTexCoord(unpack(coords)) else row.icon:SetTexCoord(0, 1, 0, 1) end
        Place(row.name, 36, 4, rowWidth - 133, 24); Place(row.meta, rowWidth - 91, 4, 48, 24); Place(row.risk, rowWidth - 44, 4, 28, 24)
        local summary = character.id and Addon.AccountPage:GetSummary(character)
        row.name:SetText(character.id and Escape(Name(character)) or "全部角色")
        local color = character.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class]
        if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(unpack(Theme.Colors.text)) end
        row.current:SetShown(character.id and current and current.id == character.id or false)
        row.meta:SetText(searching and tostring(matches[character.id] or (#entries * (not character.id and 1 or 0))) .. "封"
            or (character.id and summary.count .. "封" or #entries .. "封"))
        local counts = summary and summary._counts
        row.risk:SetText(counts and (counts.expired > 0 and "核" or (counts.urgent > 0 and "急" or (counts.soon > 0 and "临" or ""))) or "")
        row.risk:SetTextColor(unpack(counts and (counts.expired + counts.urgent) > 0 and Theme.Colors.limitReached or Theme.Colors.warning))
        row:SetScript("OnClick", function()
            Addon.WorkspaceState:SelectCharacter(character.id, characters, root.data, root.capacity)
            root.refresh()
        end)
        local lines = { character.id and Identity(character) or "全部角色", summary and summary.alert or "在当前 Core 范围内查看所有角色" }
        if character.id then lines[#lines + 1] = Model:Coverage(character) end
        Tooltip(row, lines); row:Show()
    end
    for index = #list + 1, #root.ownerRows do root.ownerRows[index]:Hide() end
    root.ownersContent:SetSize(width, #list * 34); root.owners:SetContentHeight(#list * 34)
end
local function ItemsText(items)
    local parts = {}
    for _, item in ipairs(items or {}) do parts[#parts + 1] = Escape(item.name or ("物品 " .. tostring(item.itemID))) .. " ×" .. tostring(item.quantity or 0) end
    return #parts > 0 and table.concat(parts, "，") or "无物品附件"
end
function UI:MailValues(entry, global)
    local expiry = tonumber(entry.mail.expiresAtEstimate)
    local remaining = expiry and expiry > 0 and expiry - Addon:Now()
    return { character = Identity(entry.character), sender = Escape(entry.mail.sender), subject = ((entry.mail.wasReturned or entry.mail.returned) and "[退回] " or "") .. Escape(entry.mail.subject),
        items = ItemsText(entry.mail.attachments), icon = (entry.mail.attachments or {})[1],
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
    local detail, lines, title = state.detail, {}, "详情"
    local function Add(text, item, callback) lines[#lines + 1] = { text = text, item = item, onClick = callback } end
    if detail.type == "mail" then
        local character
        for _, candidate in ipairs(root.context.characters) do if candidate.id == detail.character then character = candidate end end
        local snapshot = character and Addon.db.byCharacter[character.id]
        local mail = snapshot and snapshot.records[detail.key]
        if mail then
            title = Identity(character) .. " · " .. Escape(mail.subject)
            Add("发件人：" .. Escape(mail.sender)); Add(Model:Coverage(character))
            Add(Model:MailDetail({ mail = mail }))
            Add("最后可见 " .. Stamp(mail.observedAt) .. (mail.state == "unverified" and " · 待核实缓存" or ""))
            Add(mail.firstSeenAt and ("首次发现 " .. Stamp(mail.firstSeenAt) .. "（扫描时间）") or "首次发现时间未知")
            for _, item in ipairs(mail.attachments or {}) do Add(ItemsText({ item }) .. " · 附件槽 " .. tostring(item.attachmentIndex or "—"), item) end
            if #(mail.attachments or {}) == 0 then Add("无物品附件") end
        else Add("来源已变化，请返回列表重新核对。") end
    elseif detail.type == "item" then
        local group
        for _, candidate in ipairs(data) do if candidate.id == detail.id then group = candidate; break end end
        if group then
            title = Escape(group.item.name or ("物品 " .. tostring(group.item.itemID))) .. " · 来源"
            Add("普通附件 " .. group.normalQuantity .. " · COD附件 " .. group.codQuantity .. " · " .. group.mailCount .. " 封邮件")
            for _, source in ipairs(group.sources) do
                local entry = source.entry
                Add(Identity(entry.character) .. " · " .. Escape(entry.mail.sender) .. " · " .. Escape(entry.mail.subject)
                    .. " · ×" .. source.item.quantity .. " · " .. View:Expiry(entry.mail)
                    .. " · 最后可见 " .. Stamp(entry.mail.observedAt)
                    .. ((entry.mail.cod or 0) > 0 and (" · 整封COD " .. View:Money(entry.mail.cod)) or ""), source.item,
                    function() UI:OpenMail(root, entry) end)
            end
        else Add("物品来源已变化，请返回结果重新核对。") end
    else
        local entry
        for _, candidate in ipairs(data) do if candidate.id == detail.id then entry = candidate; break end end
        if entry then
            title = entry.event .. " · " .. Identity(entry.character) .. " · " .. Escape(entry.subject)
            Add("对方：" .. Escape(entry.counterpart)); Add("时间：" .. Stamp(entry.time) .. (entry.state == "discovered" and "（首次扫描发现）" or ""))
            if entry.record.cacheProjection then Add("时间为扫描转入待核实的时间；最后可见 " .. Stamp(entry.mail.observedAt)) end
            Add("结果：" .. entry.result); Add("来源记录：" .. tostring(entry.sourceKey or "未知"))
            for _, item in ipairs(entry.items) do Add(ItemsText({ item }), item) end
            Add(Addon.HistoryModel:Content(entry))
            if entry.record.attemptedAt then Add("发送操作 " .. Stamp(entry.record.attemptedAt)) end
            if (entry.record.codAmount or 0) > 0 then Add("整封付款金额：" .. View:Money(entry.record.codAmount)) end
        else Add("记录已超出当前过滤或保留范围，请返回列表。") end
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
    local first = math.floor((offset or 0) / layout.pitch) * layout.columns + 1
    local capacity = (math.ceil(root.list:GetHeight() / layout.pitch) + 1) * layout.columns
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
            local values, lines
            if workspace.tab == "history" then
                values = { time = Stamp(value.time), character = Identity(value.character), event = value.event,
                    counterpart = Escape(value.counterpart), subject = Escape(value.subject), content = Addon.HistoryModel:Content(value), result = value.result, icon = value.items[1] }
                lines = { value.event .. " · " .. Identity(value.character), Escape(value.subject), Escape(value.counterpart), values.content, Stamp(value.time) .. " · " .. value.result }
            else
                values = self:MailValues(value, true)
                lines = { "邮箱：" .. Identity(value.character) .. " · 发件人：" .. values.sender, values.subject, values.items, values.amount .. " · " .. values.expiry, values.coverage }
            end
            Place(row, 0, (index - 1) * layout.pitch, layout.width, layout.pitch - 2)
            row.background:SetColorTexture(unpack(value.id == state.focusedID and Theme.Colors.selected or Theme:GetDataRowColor(index)))
            self:TableRow(root, row, layout.fields, values, layout.width, layout.pitch - 2, false)
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
        root.empty:SetText(root.overview.mailColumnsHidden and "账号总览字段全部隐藏，请在 Core 的显示与入口中启用字段。" or "打开对应角色邮箱完成一次扫描后，可查看账号邮件。")
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
        root.heading:SetText(global and ("全局搜索结果（当前范围 · " .. #characters .. "角色）") or (selected and Identity(selected) or ("全部角色（当前范围 · " .. #characters .. "角色）")))
        root.note:SetText(global and "搜索全部有效角色，不受左侧角色选择限制；点击角色定位其命中记录。"
            or (selected and Model:Coverage(selected) or "数量与期限按各角色最后一次成功扫描估算。"))
        Place(root.heading, left, 44, contentWidth, 24); Place(root.note, left, 72, contentWidth, 22)
        local searchWidth = math.max(160, contentWidth - 108)
        top = Flow({ { root.search, searchWidth }, { root.clear, 100 } }, left, top, contentWidth)
        root.scope:SetValue(state.scope); root.sort:SetValue(state.sort); root.risk:SetValue(state.risk)
        root.kind:SetOptions({ { value = "all", label = "类别：全部" }, { value = "items", label = "含物品附件" }, { value = "money", label = "含金币" },
            { value = "cod", label = "付款取信" }, { value = "returned", label = "退回邮件" }, { value = "empty", label = "无附件及金币" } }); root.kind:SetValue(state.kind)
        top = Flow({ { root.scope, 126 }, { root.kind, 128 }, { root.risk, 130 }, { root.sort, 114 }, { root.mail, 78 }, { root.items, 96 } }, left, top, contentWidth)
        root.mail:SetState(state.mode == "mail" and "selected" or "default"); root.items:SetState(state.mode == "items" and "selected" or "default")
        local totals = Model:Totals(entries)
        root.summary:SetText((state.scope == "unverified" and "曾扫描，待确认" or "筛选结果") .. " · " .. totals.count .. "封 · 含附件 " .. totals.attachmentMails
            .. "封 · 待取 " .. View:Money(totals.money) .. " · COD " .. totals.cod .. "封 · 紧急 " .. totals.urgent .. " / 临期 " .. totals.soon .. " / 到期待核实 " .. totals.expired)
        if state.mode == "items" then root.summary:SetText(root.summary:GetText() .. " · " .. #data .. "个物品组") end
        fields = self:Columns(root, "inbox", global or not state.character)
        if state.mode == "mail" then fields = self:FitColumns(fields, contentWidth, "inbox") end
    else
        root.heading:SetText("历史记录")
        root.note:SetText("首次发现是扫描时间；成功发送不代表已送达。已确认保留 " .. Addon.db.settings.historyDays .. "天，待核实 " .. Addon.db.settings.unverifiedDays .. "天。")
        local options, valid = { { value = "all", label = "全部角色" } }, not state.character
        for _, character in ipairs(context.characters) do
            if Addon.HistoryModel:HasHistory(character) then
                options[#options + 1] = { value = character.id, label = Identity(character) }
                if state.character == character.id then valid = true end
            end
        end
        if not valid then state.character, state.scroll, state.anchor = nil, 0, nil end
        root.historyCharacter:SetOptions(options); root.historyCharacter:SetValue(state.character or "all")
        root.days:SetValue(state.days); root.result:SetValue(state.result)
        root.kind:SetOptions({ { value = "all", label = "事件：全部" }, { value = "inbox", label = "收件相关" }, { value = "send", label = "发件相关" },
            { value = "discovered", label = "首次发现" }, { value = "collected", label = "实际收取" } }); root.kind:SetValue(state.kind)
        top = Flow({ { root.search, math.max(200, contentWidth - 108) }, { root.clear, 100 } }, left, top, contentWidth)
        top = Flow({ { root.days, 160 }, { root.historyCharacter, 190 }, { root.kind, 134 }, { root.result, 154 } }, left, top, contentWidth)
        data = Addon.HistoryModel:Query(context, state); fields = self:FitColumns(self:Columns(root, "history", true), contentWidth, "history"); rowHeight = 38
        root.summary:SetText("筛选结果 " .. #data .. " 条 · 按事件时间倒序")
    end
    if workspace.tab ~= "overview" then
        Place(root.summary, left, top, contentWidth, 40); root.summary:SetWordWrap(true); top = top + 44
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
            local listWidth = contentWidth - (contentHeight > viewportHeight and Theme.Geometry.scrollbarGutter or 0)
            if items then columns = math.max(1, math.floor((listWidth - 8) / pitch)); contentHeight = math.ceil(#data / columns) * pitch + 8 end
            Place(root.list, left, viewportTop, listWidth, viewportHeight); root.list:Show()
            root.listLayout = { fields = fields, width = listWidth, pitch = pitch, columns = columns, items = items }
            root.listContent:SetSize(listWidth, math.max(1, contentHeight)); root.list:SetContentHeight(contentHeight)
            if not items then
                Place(root.tableHeader, left, top, listWidth, 28); root.tableHeader:Show()
                self:TableRow(root, root.tableHeader, fields, {}, listWidth, 28, true)
            end
            local offset = state.scroll or 0
            if state.anchor then
                for index, value in ipairs(data) do
                    if value.id == state.anchor then offset = math.floor((index - 1) / columns) * pitch + (state.anchorOffset or 0); break end
                end
            end
            offset = math.max(0, math.min(offset, math.max(0, contentHeight - viewportHeight)))
            root.list:SetVerticalScroll(offset); state.scroll = offset
            self:RenderList(root, offset)
            local first = math.floor(offset / pitch) * columns + 1
            state.anchor, state.anchorOffset = data[first] and data[first].id, offset % pitch
            Place(root.empty, left + 12, top + 54, contentWidth - 24, 64); root.empty:SetShown(#data == 0)
            root.empty:SetText(workspace.tab == "history" and "当前时间与筛选范围没有历史记录，可调整条件。"
                or ((state.search or ""):find("%S") and "全局搜索没有匹配结果，请清除搜索或调整筛选。"
                or (#characters == 0 and "请打开对应角色邮箱完成首次扫描。"
                or (state.scope == "unverified" and "此范围没有待核实缓存。" or (state.mode == "items" and "此范围没有物品附件，可切换按邮件查看。" or "此范围最新快照没有邮件，或没有符合筛选的邮件。")))))
        end
    end
    Place(root.back, width - 64, height - 38, 72, 30)
    local overview = workspace.tab == "overview"
    root.previous:SetShown(overview); root.next:SetShown(overview); root.pages:SetShown(overview)
    if overview then
        Place(root.previous, left, height - 38, 90, 30); Place(root.next, left + 98, height - 38, 90, 30)
        Place(root.pages, left + 198, height - 36, contentWidth - 278, 26)
        root.pages:SetText(state.page .. " / " .. root.pageCount .. " 页 · " .. root.total .. " 角色")
        Enable(root.previous, state.page > 1); Enable(root.next, state.page < root.pageCount)
    end
    root.back:SetShown(state.detail ~= nil or workspace.returnTo ~= nil)
    root.syncing = false
end
