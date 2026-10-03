local Addon = _G.YiboMail
local UI = {}; Addon.MailUI = UI
local Theme, View = _G.YiboCore.UITheme, Addon.ViewModel
local function Text(parent, size, color) return Theme:CreateText(parent, size or Theme.Font.body, color or Theme.Colors.text, "LEFT") end
local function Enabled(button, enabled)
    button:SetEnabled(not not enabled); button:SetState(enabled and "default" or "disabled")
end
function UI:Input(parent, width, label, maxLetters)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 26); box:SetAutoFocus(false); box:SetMaxLetters(maxLetters or 200)
    box:SetScript("OnEscapePressed", function(control) control:ClearFocus() end)
    box.hint = Text(box, Theme.Font.assist, Theme.Colors.muted); box.hint:SetPoint("LEFT", 2, 0); box.hint:SetPoint("RIGHT", -4, 0); box.hint:SetText(label)
    box:HookScript("OnTextChanged", function(control) control.hint:SetShown(control:GetText() == "") end)
    Theme:BindTooltip(box, label, { label }); return box
end
local function Button(parent, width, label, callback, kind)
    local button = Theme:CreateButton(parent, width, label, kind or "secondary"); button:SetScript("OnClick", callback); return button
end
function UI:Create(parent)
    local root = CreateFrame("Frame", nil, parent); root:SetAllPoints(); parent.mailWorkspace = root
    local preferences = Addon:GetInboxPreferences()
    root.selection, root.expanded, root.tab, root.mode = {}, {}, "inbox", preferences.mode
    root.rows, root.options = {}, { kind = preferences.kind, search = "", sort = preferences.sort }
    root.tabs = {}
    local tabNames = { { "inbox", "收件箱" }, { "send", "发件箱" }, { "history", "历史／待核实" }, { "overview", "账号总览" } }
    for index, tab in ipairs(tabNames) do
        local id = tab[1]
        root.tabs[index] = Button(root, index == 3 and 132 or 98, tab[2], function() root.tab, root.previewActions = id, nil; UI:Refresh(parent, root.context) end)
        root.tabs[index]:SetPoint("TOPLEFT", 8 + (index - 1) * 136, -8)
    end
    root.toolbar = CreateFrame("Frame", nil, root); root.toolbar:SetPoint("TOPLEFT", 8, -43); root.toolbar:SetPoint("TOPRIGHT", -8, -43); root.toolbar:SetHeight(28)
    root.mailMode = Button(root.toolbar, 58, "邮件", function() root.mode, root.previewActions = "mail", nil; UI:Refresh(parent, root.context) end)
    root.mailMode:SetPoint("LEFT", 0, 0)
    root.itemMode = Button(root.toolbar, 58, "附件", function() root.mode, root.previewActions = "items", nil; UI:Refresh(parent, root.context) end)
    root.itemMode:SetPoint("LEFT", 64, 0)
    root.search = self:Input(root.toolbar, 190, "搜索物品、发件人、主题或角色", 100); root.search:SetPoint("LEFT", 138, 0)
    root.search:SetScript("OnTextChanged", function(control) root.options.search = control:GetText(); if root.context then UI:Refresh(parent, root.context) end end)
    root.filter = Theme:CreateDropdown(root.toolbar, 116, {
        { value = "all", label = "全部邮件" }, { value = "items", label = "含附件" }, { value = "money", label = "含金币" },
        { value = "cod", label = "付款取信" }, { value = "returned", label = "退回邮件" }, { value = "urgent", label = "三天内到期" },
    }); root.filter:SetPoint("LEFT", 346, 0); root.filter:SetValue(root.options.kind)
    root.filter:SetOnValueChanged(function(value) root.options.kind = value; UI:Refresh(parent, root.context) end)
    root.sort = Theme:CreateDropdown(root.toolbar, 102, { { value = "expiry", label = "临期优先" }, { value = "inbox", label = "邮箱顺序" } })
    root.sort:SetPoint("RIGHT", 0, 0); root.sort:SetValue(root.options.sort)
    root.sort:SetOnValueChanged(function(value) root.options.sort = value; UI:Refresh(parent, root.context) end)
    root.scroll = Theme:CreateScrollFrame(root); root.scroll:SetPoint("TOPLEFT", 8, -80); root.scroll:SetPoint("BOTTOMRIGHT", -8, 58)
    root.content = CreateFrame("Frame", nil, root.scroll); root.content:SetSize(1, 1); root.scroll:SetScrollChild(root.content)
    root.footer = CreateFrame("Frame", nil, root); root.footer:SetPoint("BOTTOMLEFT", 8, 8); root.footer:SetPoint("BOTTOMRIGHT", -8, 8); root.footer:SetHeight(44)
    root.status = Text(root.footer, Theme.Font.assist, Theme.Colors.muted); root.status:SetPoint("TOPLEFT", 0, 0); root.status:SetPoint("TOPRIGHT", 0, 0); root.status:SetHeight(18)
    root.selectAll = Button(root.footer, 88, "全选可收", function()
        root.notice = nil
        for _, action in ipairs(root.available or {}) do if Addon:SelectByDefault(action) then root.selection[action.id] = true end end
        UI:Refresh(parent, root.context)
    end); root.selectAll:SetPoint("BOTTOMLEFT", 0, 0)
    root.clear = Button(root.footer, 66, "清空", function()
        local ok, err = Addon.Queue:Discard(); if ok then root.selection, root.previewActions, root.notice = {}, nil, nil else root.notice = err end
        UI:Refresh(parent, root.context)
    end); root.clear:SetPoint("LEFT", root.selectAll, "RIGHT", 8, 0)
    root.action = Button(root.footer, 164, "预览收取", function() UI:PrimaryAction(parent) end, "default"); root.action:SetPoint("BOTTOMRIGHT", 0, 0)
    root.stop = Button(root.footer, 78, "暂停", function()
        if root.previewActions then root.previewActions = nil else Addon.Queue:Pause("玩家已暂停，确认中的一步仍等待结果。") end
        UI:Refresh(parent, root.context)
    end); root.stop:SetPoint("RIGHT", root.action, "LEFT", -8, 0)
    root.send = self:CreateCompose(root)
    root.overview = CreateFrame("Frame", nil, root); root.overview:SetPoint("TOPLEFT", 0, -44); root.overview:SetPoint("BOTTOMRIGHT", 0, 0)
    Addon.AccountPage:CreateSummary(root.overview)
    root:HookScript("OnHide", function() if root.search:HasFocus() then root.search:ClearFocus() end end)
    Addon.Queue.onSuccess = function(id) root.selection[id] = nil end
end
function UI:BeginRows(root)
    root.used, root.top, root.available = 0, 0, {}
    root.width = math.max(1, root.scroll:GetWidth() - 18)
end
function UI:Row(root, data)
    root.used = root.used + 1
    local row = root.rows[root.used]
    if not row then
        row = CreateFrame("Button", nil, root.content, "BackdropTemplate")
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row.check = Theme:CreateCheckbox(row, ""); row.check:SetSize(20, 24); row.check:SetPoint("LEFT", 10, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(38, 38); row.icon:SetPoint("LEFT", 42, 0)
        row.count = Text(row, Theme.Font.body); row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 0, 0)
        row.title = Text(row); row.title:SetPoint("TOPLEFT", 90, -8); row.title:SetPoint("TOPRIGHT", -138, -8); row.title:SetHeight(20)
        row.detail = Text(row, Theme.Font.assist, Theme.Colors.muted); row.detail:SetPoint("TOPLEFT", 90, -30); row.detail:SetPoint("TOPRIGHT", -20, -30); row.detail:SetHeight(18)
        row.expiry = Text(row, Theme.Font.assist); row.expiry:SetPoint("TOPRIGHT", -12, -9); row.expiry:SetWidth(118); row.expiry:SetJustifyH("RIGHT")
        root.rows[root.used] = row
    end
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", data.indent and 24 or 0, -root.top); row:SetSize(root.width - (data.indent and 24 or 0), 58)
    local fill = Theme:GetDataRowColor(root.used)
    row:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
    row:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
    row.title:SetText(data.title or ""); row.detail:SetText(data.detail or ""); row.expiry:SetText(data.expiry or "")
    row.icon:SetTexture(data.texture or "Interface\\Icons\\INV_Letter_15"); row.count:SetText(data.quantity and tostring(data.quantity) or "")
    local actions, selected, eligible, eligibleSelected = data.actions or {}, 0, 0, 0
    for _, action in ipairs(actions) do
        if root.selection[action.id] then selected = selected + 1 end
        if action.actionable then
            root.available[#root.available + 1] = action; eligible = eligible + 1
            if root.selection[action.id] then eligibleSelected = eligibleSelected + 1 end
        end
    end
    row.check:SetShown(#actions > 0)
    row.check:SetCheckState(selected == 0 and "unchecked" or (selected == #actions and "checked" or "partial"))
    local enabled = false; for _, action in ipairs(actions) do if action.actionable then enabled = true end end
    row.check:SetEnabled(enabled and Addon.Queue.state ~= "running" and not root.previewActions)
    row.check:SetScript("OnClick", function()
        root.notice = nil
        for _, action in ipairs(actions) do if action.actionable then root.selection[action.id] = eligibleSelected < eligible or nil end end
        UI:Refresh(root:GetParent(), root.context)
    end)
    row:SetScript("OnClick", data.onClick)
    row:SetScript("OnEnter", function()
        row:SetBackdropBorderColor(unpack(Theme.Colors.accent))
        if GameTooltip then
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            if data.itemLink then GameTooltip:SetHyperlink(data.itemLink)
            else GameTooltip:SetText(data.title or ""); GameTooltip:AddLine(data.tooltip or data.detail or "", 1, 1, 1, true) end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() row:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft)); if GameTooltip then GameTooltip:Hide() end end)
    row:Show(); root.top = root.top + 60
end
function UI:EndRows(root)
    if root.used == 0 then self:Row(root, { title = "没有符合条件的记录", detail = "可清除筛选，或打开角色邮箱等待扫描。" }) end
    for index = root.used + 1, #root.rows do root.rows[index]:Hide() end
    root.content:SetSize(root.width, math.max(1, root.top)); root.scroll:SetContentHeight(root.top)
end
function UI:Actions(entry, onlyItem) return Addon:GetInboxActions(entry, onlyItem) end
function UI:MailRows(root, entry, history)
    local mail, label = entry.mail, View:Escape(entry.character.name .. " · " .. entry.mail.sender)
    local id = entry.character.id .. ":" .. entry.key
    local state = mail.state == "unverified" and "待核实 · " or ""
    self:Row(root, { title = state .. label .. " · " .. View:Escape(mail.subject),
        detail = (mail.cod > 0 and ("付款取信 " .. View:Money(mail.cod)) or ("附件 " .. #mail.attachments .. " 格 · 金币 " .. View:Money(mail.money))) .. " · " .. (entry.actionable and "可收取" or entry.restriction),
        expiry = View:Expiry(mail), texture = mail.attachments[1] and mail.attachments[1].texture,
        actions = not history and self:Actions(entry) or nil,
        tooltip = "扫描 " .. date("%m-%d %H:%M", mail.observedAt) .. " · " .. View:Escape(mail.subject),
        onClick = function() root.expanded[id] = not root.expanded[id]; UI:Refresh(root:GetParent(), root.context) end })
    if root.expanded[id] then
        for _, item in ipairs(mail.attachments) do
            self:Row(root, { title = item.itemLink or View:Escape(item.name), detail = "附件槽 " .. item.attachmentIndex .. " · " .. label,
                texture = item.texture, quantity = item.quantity, expiry = View:Expiry(mail), itemLink = item.itemLink,
                indent = true, actions = not history and self:Actions(entry, item) or nil })
        end
        if mail.money > 0 and not history then
            local actions = self:Actions(entry); local money = {}; for _, action in ipairs(actions) do if action.slot == "money" then money[1] = action end end
            self:Row(root, { title = "金币 " .. View:Money(mail.money), detail = label, texture = "Interface\\Icons\\INV_Misc_Coin_01", indent = true, actions = money })
        end
    end
end
function UI:PreviewRows(root)
    self:Row(root, { title = "确认本批收取 · " .. #root.previewActions .. " 项操作", detail = "仅处理下列项目。内容变化、背包不足或邮箱关闭时暂停。" })
    for _, action in ipairs(root.previewActions) do
        self:Row(root, { title = action.item and (action.item.itemLink or View:Escape(action.item.name)) or ("金币 " .. View:Money(action.original.money)),
            detail = View:Escape(action.original.sender .. " · " .. action.original.subject), texture = action.item and action.item.texture or "Interface\\Icons\\INV_Misc_Coin_01",
            quantity = action.item and action.item.quantity, expiry = View:Expiry(action.original) })
    end
end
function UI:PrimaryAction(parent)
    local root, queue = parent.mailWorkspace, Addon.Queue
    root.notice = nil
    if root.previewActions then
        local ok, err = queue:Start(root.previewActions)
        if not ok then root.notice = err else root.previewActions = nil end
    else
        if queue.state == "paused" and #queue.actions > 0 then
            local selection, err = queue:RemainingSelection(root.context)
            if not selection then root.notice = err; self:Refresh(parent, root.context); return end
            root.selection = selection
        end
        local actions, err = queue:Prepare(root.selection, root.context)
        root.previewActions, root.notice = actions, err
    end
    self:Refresh(parent, root.context)
end
function UI:Refresh(parent, context)
    local root = parent.mailWorkspace; root.context = context
    root:Show()
    local overview, send = root.tab == "overview", root.tab == "send"
    for index, button in ipairs(root.tabs) do button:SetState(({ "inbox", "send", "history", "overview" })[index] == root.tab and "selected" or "default") end
    root.toolbar:SetShown(not overview and not send); root.scroll:SetShown(not overview and not send)
    root.footer:SetShown(not overview and not send); root.overview:SetShown(overview); root.send:SetShown(send)
    if overview then Addon.AccountPage:RefreshSummary(root.overview, context); return end
    if send then self:RefreshCompose(root); return end
    local history = root.tab == "history"
    root.mailMode:SetShown(not history); root.itemMode:SetShown(not history)
    root.mailMode:SetState(root.mode == "mail" and "selected" or "default"); root.itemMode:SetState(root.mode == "items" and "selected" or "default")
    self:BeginRows(root)
    if root.previewActions then self:PreviewRows(root)
    elseif history then
        local options = Addon.Copy(root.options); options.history = true
        for _, entry in ipairs(View:GetMails(context, options)) do self:MailRows(root, entry, true) end
        local names = { ["collected-archived"] = "已收取", ["in-transit"] = "在途", unverified = "待核实", ["received-confirmed"] = "已确认收到" }
        for _, character in ipairs(context.characters or {}) do
            local snapshot = Addon.db.byCharacter[character.id]
            for index = #(snapshot and snapshot.history or {}), 1, -1 do
                local record = snapshot.history[index]
                local subject = record.subject or (record.mail and record.mail.subject) or ""
                local search = subject .. " " .. (record.recipient or "") .. " " .. character.name
                if record.item then search = search .. " " .. tostring(record.item.itemID) .. " " .. (record.item.name or "") end
                for _, item in ipairs(record.attachments or {}) do search = search .. " " .. tostring(item.itemID) .. " " .. (item.name or "") end
                search = string.lower(search)
                if root.options.search == "" or search:find(string.lower(root.options.search), 1, true) then
                    self:Row(root, { title = (names[record.state] or record.state) .. " · " .. View:Escape(character.name .. " · " .. subject),
                        detail = record.recipient and ("收件人 " .. View:Escape(record.recipient) .. " · 附件 " .. #(record.attachments or {}))
                            or (record.item and (record.item.itemLink or View:Escape(record.item.name)) .. " ×" .. record.item.quantity or ("金币 " .. View:Money(record.money))),
                        expiry = date("%m-%d %H:%M", record.observedAt) })
                end
            end
        end
    elseif root.mode == "mail" then
        for _, entry in ipairs(View:GetMails(context, root.options)) do self:MailRows(root, entry) end
    else
        for _, group in ipairs(View:GetGroups(context, root.options)) do
            local actions = {}; for _, source in ipairs(group.sources) do for _, action in ipairs(self:Actions(source.entry, source.item)) do actions[#actions + 1] = action end end
            self:Row(root, { title = group.item.itemLink or View:Escape(group.item.name), detail = "来自 " .. #group.sources .. " 个附件槽 · 点击展开来源",
                texture = group.item.texture, quantity = group.quantity, expiry = View:Expiry(group), actions = actions, itemLink = group.item.itemLink,
                onClick = function() root.expanded[group.id] = not root.expanded[group.id]; UI:Refresh(parent, context) end })
            if root.expanded[group.id] then
                for _, source in ipairs(group.sources) do
                    local entry = source.entry
                    self:Row(root, { title = View:Escape(entry.character.name .. " · " .. entry.mail.sender), detail = View:Escape(entry.mail.subject),
                        indent = true, quantity = source.item.quantity, texture = source.item.texture, expiry = View:Expiry(entry.mail), actions = self:Actions(entry, source.item),
                        onClick = function() root.mode = "mail"; root.expanded[entry.character.id .. ":" .. entry.key] = true; root.options.search = ""; root.search:SetText(""); UI:Refresh(parent, context) end })
                end
            end
        end
    end
    self:EndRows(root)
    local selected = 0; for _ in pairs(root.selection) do selected = selected + 1 end
    local queue = Addon.Queue
    local current = Addon.Core.Characters:GetCurrent()
    local snapshot = current and Addon.db.byCharacter[current.id]
    local coverage = snapshot and snapshot.coverage.currentCount and (" · 当前角色可见 " .. snapshot.coverage.currentCount .. "/" .. snapshot.coverage.totalCount .. " 封") or " · 当前角色未扫描"
    root.status:SetText(root.notice or (queue.state == "running" or queue.state == "paused") and (queue.message .. " · 已完成 " .. queue.completed .. "/" .. #queue.actions) or ("已选 " .. selected .. " 项" .. coverage))
    root.action:SetText(root.previewActions and "确认本批收取" or (queue.state == "paused" and "重新预览剩余项" or "预览收取"))
    root.stop:SetText(root.previewActions and "取消" or "暂停"); root.stop:SetShown(root.previewActions ~= nil or queue.state == "running")
    root.selectAll:SetShown(not history); root.clear:SetShown(not history); root.action:SetShown(not history)
    Enabled(root.action, not history and queue.state ~= "running" and not queue.pending)
    Enabled(root.selectAll, queue.state ~= "running" and not root.previewActions); Enabled(root.clear, queue.state ~= "running" and not queue.pending)
end

function UI:CreateCompose(root)
    local panel = CreateFrame("Frame", nil, root); panel:SetPoint("TOPLEFT", 8, -46); panel:SetPoint("BOTTOMRIGHT", -8, 8)
    panel.recipientLabel = Text(panel); panel.recipientLabel:SetPoint("TOPLEFT", 0, -4); panel.recipientLabel:SetText("收件人")
    panel.recipient = self:Input(panel, 280, "收件人：角色名-服务器", 100); panel.recipient:SetPoint("TOPLEFT", 80, 0)
    panel.contacts = Theme:CreateDropdown(panel, 214, {}); panel.contacts:SetPoint("TOPRIGHT", 0, 0)
    panel.contacts:SetOnValueChanged(function(value)
        if value == "__next" or value == "__prev" then panel.contactPage = (panel.contactPage or 1) + (value == "__next" and 1 or -1); UI:RefreshCompose(root)
        else panel.recipient:SetText(value) end
    end)
    panel.subjectLabel = Text(panel); panel.subjectLabel:SetPoint("TOPLEFT", 0, -39); panel.subjectLabel:SetText("主题")
    panel.subject = self:Input(panel, 400, "邮件主题", 200); panel.subject:SetPoint("TOPLEFT", 80, -35); panel.subject:SetPoint("TOPRIGHT", -4, -35)
    panel.bodyLabel = Text(panel); panel.bodyLabel:SetPoint("TOPLEFT", 0, -75); panel.bodyLabel:SetText("正文")
    panel.bodyScroll = Theme:CreateScrollFrame(panel); panel.bodyScroll:SetPoint("TOPLEFT", 80, -72); panel.bodyScroll:SetPoint("BOTTOMRIGHT", -4, 262)
    panel.bodyBackground = CreateFrame("Frame", nil, panel, "BackdropTemplate"); panel.bodyBackground:SetPoint("TOPLEFT", panel.bodyScroll, "TOPLEFT", -4, 4); panel.bodyBackground:SetPoint("BOTTOMRIGHT", panel.bodyScroll, "BOTTOMRIGHT", 4, -4)
    panel.bodyBackground:SetFrameLevel(math.max(panel:GetFrameLevel(), panel.bodyScroll:GetFrameLevel() - 1)); panel.bodyBackground:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    panel.bodyBackground:SetBackdropColor(unpack(Theme.Colors.panel)); panel.bodyBackground:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
    panel.body = CreateFrame("EditBox", nil, panel.bodyScroll); panel.body:SetMultiLine(true); panel.body:SetAutoFocus(false); panel.body:SetFontObject(ChatFontNormal); panel.body:SetMaxLetters(5000); panel.body:SetWidth(400); panel.body:SetHeight(120)
    panel.bodyScroll:SetScrollChild(panel.body)
    panel.body:SetScript("OnEscapePressed", function(control) control:ClearFocus() end)
    panel.body:SetScript("OnTextChanged", function(control)
        Addon.Compose.draft.body = control:GetText(); panel.preview = nil; panel.bodyScroll:SetContentHeight(math.max(120, control:GetHeight()))
    end)
    panel.body:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local position, viewport = panel.bodyScroll:GetVerticalScroll(), panel.bodyScroll:GetHeight()
        local bottom = -y + height
        if bottom > position + viewport then panel.bodyScroll:SetVerticalScroll(math.max(0, bottom - viewport)) elseif -y < position then panel.bodyScroll:SetVerticalScroll(math.max(0, -y)) end
    end)
    panel.recipient:SetScript("OnTextChanged", function(control) Addon.Compose.draft.recipient = control:GetText(); panel.preview = nil end)
    panel.subject:SetScript("OnTextChanged", function(control) Addon.Compose.draft.subject = control:GetText(); panel.preview = nil end)
    panel.attachments = {}; panel.slotHost = CreateFrame("Frame", nil, panel); panel.slotHost:SetPoint("BOTTOMLEFT", 80, 164); panel.slotHost:SetPoint("BOTTOMRIGHT", -4, 164); panel.slotHost:SetHeight(86)
    for slot = 1, ATTACHMENTS_MAX_SEND or 12 do
        local index = slot
        local button = CreateFrame("Button", nil, panel.slotHost, "BackdropTemplate"); button:SetSize(38, 38)
        button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); button:SetBackdropColor(unpack(Theme.Colors.panel)); button:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
        button.icon = button:CreateTexture(nil, "ARTWORK"); button.icon:SetAllPoints()
        button.count = Text(button, Theme.Font.assist); button.count:SetPoint("BOTTOMRIGHT", -1, 1)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(_, mouse)
            local ok, err = Addon.Compose:ClickSlot(index, mouse == "RightButton"); panel.notice, panel.preview = not ok and err or nil, nil; UI:RefreshCompose(root)
        end)
        button:SetScript("OnReceiveDrag", function() local ok, err = Addon.Compose:ClickSlot(index); panel.notice = not ok and err or nil; UI:RefreshCompose(root) end)
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT"); if button.itemLink then GameTooltip:SetHyperlink(button.itemLink) else GameTooltip:SetText("拖入附件 · 右键移除") end; GameTooltip:Show()
        end); button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        panel.attachments[slot] = button
    end
    panel.amountLabel = Text(panel); panel.amountLabel:SetPoint("BOTTOMLEFT", 0, 137); panel.amountLabel:SetText("寄送金额")
    panel.amount = self:Input(panel, 110, "金币金额（最多两位小数）", 12); panel.amount:SetPoint("BOTTOMLEFT", 80, 130); panel.amount:SetText("0")
    panel.amount:SetScript("OnTextChanged", function(control) local amount = tonumber(control:GetText()); panel.invalidAmount = not amount or amount < 0 or amount > 100000000 or amount ~= amount; Addon.Compose.draft.copper = not panel.invalidAmount and math.floor(amount * 100 + 0.5) * 100 or 0; panel.preview = nil end)
    panel.cod = Theme:CreateCheckbox(panel, "付款取信"); panel.cod:SetPoint("BOTTOMLEFT", 212, 130)
    panel.cod:SetScript("OnClick", function(control) control:SetChecked(not control:GetChecked()); Addon.Compose.draft.cod = control:GetChecked(); panel.preview = nil end)
    panel.saveContact = Button(panel, 116, "收藏收件人", function()
        local ok, err = View:SaveContact(panel.recipient:GetText(), panel.recipient:GetText()); panel.notice = ok and "已加入常用联系人。" or err; UI:RefreshCompose(root)
    end); panel.saveContact:SetPoint("BOTTOMRIGHT", 0, 130)
    panel.suggestion = Theme:CreateDropdown(panel, 300, {}); panel.suggestion:SetPoint("BOTTOMLEFT", 80, 93)
    panel.suggestion:SetOnValueChanged(function(value)
        if value == "__next" or value == "__prev" then panel.rulePage = (panel.rulePage or 1) + (value == "__next" and 1 or -1); panel.selectedSuggestion = nil
        elseif value == "__reset" then panel.skippedRules = {}; panel.rulePage, panel.selectedSuggestion = 1, nil
        else panel.selectedSuggestion = value end
        panel.preview = nil; UI:RefreshCompose(root)
    end)
    panel.rulePreview = Button(panel, 112, "预览规则装填", function()
        local suggestion = panel.suggestions and panel.suggestions[panel.selectedSuggestion]
        if not suggestion then panel.notice = "背包中没有匹配规则的可寄送整叠物品。"
        else local ok, err = Addon.Compose:PrepareFill(suggestion); panel.notice = ok and ("预览：" .. View:Escape(suggestion.recipient) .. " · " .. suggestion.quantity .. " 件 · " .. #suggestion.items .. " 格，点击逐格装填。") or err end
        UI:RefreshCompose(root)
    end); panel.rulePreview:SetPoint("BOTTOMRIGHT", 0, 93)
    panel.skip = Button(panel, 62, "跳过", function()
        local suggestion = panel.suggestions and panel.suggestions[panel.selectedSuggestion]
        panel.skippedRules = panel.skippedRules or {}; if suggestion then panel.skippedRules[suggestion.itemID] = true end
        panel.selectedSuggestion = nil; UI:RefreshCompose(root)
    end); panel.skip:SetPoint("RIGHT", panel.rulePreview, "LEFT", -8, 0)
    panel.fill = Button(panel, 112, "装填下一格", function() local ok, err = Addon.Compose:FillNext(); panel.notice = ok and "附件格已装填。" or err; panel.recipient:SetText(Addon.Compose.draft.recipient); UI:RefreshCompose(root) end)
    panel.fill:SetPoint("BOTTOMLEFT", 80, 58)
    panel.undo = Button(panel, 100, "撤销本次装填", function() local ok, err = Addon.Compose:UndoFill(); panel.notice = ok and "已撤销尚未发送的本次装填。" or err; UI:RefreshCompose(root) end)
    panel.undo:SetPoint("LEFT", panel.fill, "RIGHT", 8, 0)
    panel.rules = Button(panel, 110, "联系人与规则", function() Addon.Core.AccountView:ShowSettings("mail-inbox") end)
    panel.rules:SetPoint("BOTTOMRIGHT", 0, 58)
    panel.noticeText = Text(panel, Theme.Font.assist, Theme.Colors.muted); panel.noticeText:SetPoint("BOTTOMLEFT", 0, 31); panel.noticeText:SetPoint("BOTTOMRIGHT", 0, 31); panel.noticeText:SetHeight(22)
    panel.stage = Button(panel, 160, "预览本封邮件", function()
        if panel.invalidAmount then panel.notice = "请填写有效的非负金币金额。"
        elseif panel.preview then
            if panel.preview ~= Addon.Compose:DraftFingerprint() then panel.notice = "本封内容已变化，请重新预览。"
            else
                local ok, err = Addon.Compose:ApplyDraft(); panel.notice = ok and "已装填到原生发件箱，请核对并点击原生发送。" or err
                if ok then Addon:Print(panel.notice); Addon.Core.AccountView.frame:Hide() end
            end
            panel.preview = nil
        else panel.preview = Addon.Compose:DraftFingerprint(); panel.notice = "预览：" .. View:Escape(Addon.Compose.draft.recipient) .. " · " .. #Addon.Compose:GetAttachments() .. " 格 · " .. (Addon.Compose.draft.cod and "付款取信 " or "寄送 ") .. View:Money(Addon.Compose.draft.copper) end
        UI:RefreshCompose(root)
    end, "default"); panel.stage:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.cancel = Button(panel, 86, "取消预览", function() panel.preview, panel.notice = nil, nil; UI:RefreshCompose(root) end); panel.cancel:SetPoint("RIGHT", panel.stage, "LEFT", -8, 0)
    return panel
end
function UI:RefreshCompose(root)
    local panel, compose = root.send, Addon.Compose
    local width = math.max(1, panel:GetWidth())
    panel.recipient:SetWidth(math.max(140, width - 316)); panel.body:SetWidth(math.max(1, panel.bodyScroll:GetWidth() - 18))
    local contacts, roster = {}, View:GetContacts()
    panel.contactPage = math.max(1, math.min(panel.contactPage or 1, math.max(1, math.ceil(#roster / 8))))
    for index = (panel.contactPage - 1) * 8 + 1, math.min(#roster, panel.contactPage * 8) do
        local contact = roster[index]; contacts[#contacts + 1] = { value = contact.address, label = View:Escape(contact.label) }
    end
    if panel.contactPage > 1 then contacts[#contacts + 1] = { value = "__prev", label = "上一页联系人" } end
    if panel.contactPage * 8 < #roster then contacts[#contacts + 1] = { value = "__next", label = "下一页联系人" } end
    panel.contacts:SetOptions(contacts)
    panel.contacts:SetText("常用联系人 · " .. panel.contactPage)
    if panel.recipient:GetText() ~= compose.draft.recipient then panel.recipient:SetText(compose.draft.recipient) end
    if panel.subject:GetText() ~= compose.draft.subject then panel.subject:SetText(compose.draft.subject) end
    if panel.body:GetText() ~= compose.draft.body then panel.body:SetText(compose.draft.body) end
    if panel.syncedDraft ~= compose.draft then
        panel.amount:SetText(string.format("%.2f", compose.draft.copper / 10000)); panel.syncedDraft = compose.draft
    end
    panel.cod:SetChecked(compose.draft.cod)
    local attachments = {}; for _, item in ipairs(compose:GetAttachments()) do attachments[item.slot] = item end
    local columns = math.max(1, math.min(6, math.floor((width - 84) / 44)))
    for slot, button in ipairs(panel.attachments) do
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", ((slot - 1) % columns) * 44, -math.floor((slot - 1) / columns) * 44)
        local item = attachments[slot]; button.itemLink = item and item.itemLink
        button.icon:SetTexture(item and item.texture); button.count:SetText(item and tostring(item.quantity) or tostring(slot))
    end
    panel.suggestions = {}; for _, suggestion in ipairs(compose:GetSuggestions()) do if not (panel.skippedRules and panel.skippedRules[suggestion.itemID]) then panel.suggestions[#panel.suggestions + 1] = suggestion end end
    local suggestions = {}
    panel.rulePage = math.max(1, math.min(panel.rulePage or 1, math.max(1, math.ceil(#panel.suggestions / 6))))
    for index = (panel.rulePage - 1) * 6 + 1, math.min(#panel.suggestions, panel.rulePage * 6) do
        local suggestion = panel.suggestions[index]
        local name = GetItemInfo(suggestion.itemID) or ("物品 " .. suggestion.itemID)
        suggestions[#suggestions + 1] = { value = index, label = View:Escape(name) .. " → " .. View:Escape(suggestion.recipient) .. " ×" .. suggestion.quantity }
    end
    if panel.rulePage > 1 then suggestions[#suggestions + 1] = { value = "__prev", label = "上一页建议" } end
    if panel.rulePage * 6 < #panel.suggestions then suggestions[#suggestions + 1] = { value = "__next", label = "下一页建议" } end
    if panel.skippedRules and next(panel.skippedRules) then suggestions[#suggestions + 1] = { value = "__reset", label = "重新显示跳过的建议" } end
    panel.suggestion:SetWidth(math.max(120, width - 288)); panel.suggestion:SetOptions(suggestions)
    if panel.selectedSuggestion == nil or not panel.suggestions[panel.selectedSuggestion] then panel.selectedSuggestion = #panel.suggestions > 0 and ((panel.rulePage - 1) * 6 + 1) or nil end
    if panel.selectedSuggestion then panel.suggestion:SetValue(panel.selectedSuggestion) else panel.suggestion:SetText("暂无规则匹配") end
    local fill = compose.fill
    Enabled(panel.fill, fill and fill.index <= #fill.items and Addon.Scanner:IsOpen()); Enabled(panel.undo, fill and #fill.staged > 0)
    Enabled(panel.stage, Addon.Scanner:IsOpen()); Enabled(panel.rulePreview, panel.selectedSuggestion ~= nil and Addon.Scanner:IsOpen())
    Enabled(panel.skip, panel.selectedSuggestion ~= nil)
    panel.stage:SetText(panel.preview and "确认装填至原生" or "预览本封邮件")
    panel.noticeText:SetText(panel.notice or (Addon.Scanner:IsOpen() and "拖入物品到附件格；最终发送请点击原生发件箱的发送按钮。" or "请在游戏中打开邮箱后装填。"))
end
