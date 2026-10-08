local Addon = _G.YiboMail
local U = {}; Addon.RuleSendUI = U
local function Run(method, ...)
    local ok, err = method(Addon.RuleSendController, ...)
    if not ok then Addon.RuleSendController.notice = err end
    U:Refresh()
end
function U:OpenSettings(id)
    Addon.SendRulesSettings.requestedTab, Addon.SendRulesSettings.requestedRule = "rules", id
    Addon.Core.AccountView:ShowSettings("mail-inbox")
end
function U:Install()
    if self.root or not Addon.NativeUI.send then return end
    local theme, native = Addon.Core.UITheme, Addon.NativeUI
    -- Keep addon tabs out of Blizzard's tab registry and secure panel fields.
    -- PanelTemplates_SetNumTabs/SetTab write MailFrame.numTabs/selectedTab.
    native:InstallMailboxTabs()
    self.tab = native.mailboxTabs and native.mailboxTabs.rules
    local root = CreateFrame("Frame", nil, native.send, "BackdropTemplate"); self.root = root
    root:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 8, -6)
    -- The rule list occupies the body region above the shared send controls.
    if SendMailAttachment1 then root:SetPoint("BOTTOMRIGHT", SendMailAttachment1, "TOPLEFT", MailFrame:GetWidth() - 48, 10)
    else root:SetPoint("BOTTOMRIGHT", MailFrame, "TOPRIGHT", -16, -245) end
    root:SetFrameLevel(native.send:GetFrameLevel() + 6)
    root:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    root:SetBackdropColor(unpack(theme.Colors.bg))
    root.manage = theme:CreateButton(native.send, 88, "管理规则")
    root.manage:SetHeight(theme.Size.compact); root.manage:SetScript("OnClick", function() U:OpenSettings() end)
    root.scroll = theme:CreateScrollFrame(root); root.scroll:SetPoint("TOPLEFT", 6, -6); root.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    root.content = CreateFrame("Frame", nil, root.scroll); root.content:SetSize(1, 1); root.scroll:SetScrollChild(root.content)
    root.rows = {}
    root.scroll:HookScript("OnSizeChanged", function() U:Refresh() end)
    self.action = theme:CreateButton(native.send, 80, "装填", "primary")
    self.action:SetPoint("RIGHT", SendMailCancelButton, "LEFT", -6, 0)
    self.action:SetScript("OnClick", function() Run(Addon.RuleSendController.Primary) end)
    self.undo = theme:CreateButton(native.send, 64, "撤下", "secondary")
    self.undo:SetPoint("RIGHT", self.action, "LEFT", -6, 0)
    self.undo:SetScript("OnClick", function() Run(Addon.RuleSendController.Undo) end)
    self.status = theme:CreateText(native.send, theme.Font.assist, theme.Colors.muted, "LEFT")
    self.status:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8, 42)
    self.status:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, 42); self.status:SetHeight(20); self.status:SetWordWrap(false)
    self.recipient = CreateFrame("Button", nil, native.send.recipientField)
    self.recipient.value = theme:CreateText(self.recipient, theme.Font.body, theme.Colors.text, "LEFT")
    self.recipient.value:SetAllPoints(); self.recipient.value:SetWordWrap(false)
    if hooksecurefunc and MailFrameTab_OnClick then hooksecurefunc("MailFrameTab_OnClick", function(_, page)
        if page == 1 or page == 2 then U:SetActive(false) end
    end) end
    self:Layout(); self:SetActive(false)
end
function U:LayoutFooter()
    if not self.recipient then return end
    local native, theme = Addon.NativeUI, Addon.Core.UITheme
    local layout, field = native:SendRegionLayout(), native.send.recipientField
    self.recipient:ClearAllPoints(); self.recipient:SetPoint("LEFT", field, "LEFT", 74, 0)
    self.recipient:SetSize(math.max(80, field:GetWidth() - 80), theme.Size.standard)
    self.recipient:SetFrameLevel(field:GetFrameLevel() + 2)
    local width = math.max(1, MailFrame:GetWidth() - 16)
    local usedColumns = layout.count % layout.columns
    local spareWidth = usedColumns > 0 and width - usedColumns * (layout.size + layout.gap) or 0
    self.root.manage:ClearAllPoints(); self.root.manage:SetWidth(88)
    if spareWidth >= 88 then
        self.root.manage:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, layout.attachmentBottom + (layout.size - theme.Size.compact) / 2)
    else
        self.root.manage:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, layout.controlsBottom)
        width = math.max(1, width - 94)
    end
    self.root.manage:SetFrameLevel(native.send:GetFrameLevel() + 6)
    self.status:ClearAllPoints(); self.status:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8, layout.controlsBottom + 3)
    self.status:SetSize(width, 20)
end
function U:Layout()
    if not self.root then return end
    local native, theme = Addon.NativeUI, Addon.Core.UITheme
    self.root:ClearAllPoints(); self.root:SetPoint("TOPLEFT", native.send.recipientField, "BOTTOMLEFT", 0, -6)
    self.root:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, native:SendRegionLayout().controlsBottom + theme.Size.compact + 6)
    self.action:SetHeight(theme.Size.compact); self.undo:SetHeight(theme.Size.compact)
    self:LayoutFooter()
    native.send.close:SetFrameLevel(self.root:GetFrameLevel() + 2)
    native.send.favoriteToggle:SetFrameLevel(self.root:GetFrameLevel() + 2)
end
function U:Open()
    if not self.root then return end
    Addon.NativeUI:SelectMailboxTab("rules")
end
function U:SetActive(active)
    self.active = active
    if not self.root then return end
    Addon.NativeUI:RefreshMailboxTabs()
    self.root:SetShown(active); self.root.manage:SetShown(active); self.action:SetShown(active); self.undo:SetShown(active); self.status:SetShown(active); self.recipient:SetShown(active)
    local send = _G.SendMailMailButton or _G.SendMailSendButton
    if send then send:SetShown(not active) end
    local controls = { Addon.NativeUI.send.subjectField, Addon.NativeUI.send.contacts }
    local body = Addon.Compose:GetBodyEditBox()
    if body then controls[#controls + 1] = body end
    for _, name in ipairs({ "SendMailNameEditBox", "SendMailSubjectEditBox", "MailEditBox", "MailEditBoxScrollBar", "SendMailScrollFrame", "SendMailScrollFrameScrollBar", "SendMailMoneyButton", "SendMailMoney", "SendMailMoneyText", "SendMailSendMoneyButton", "SendMailSendMoneyButtonText", "SendMailCODButton", "SendMailCODButtonText", "SendMailCostMoneyFrame", "SendMailErrorText" }) do
        local control = _G[name]
        if control then controls[#controls + 1] = control end
    end
    if SendMailScrollFrame and SendMailScrollFrame.ScrollBar then controls[#controls + 1] = SendMailScrollFrame.ScrollBar end
    if active then
        self.hidden = self.hidden or {}
        for _, control in ipairs(controls) do
            if self.hidden[control] == nil then self.hidden[control] = control:IsShown() end
        end
        for _, control in ipairs(controls) do control:Hide() end
    else
        for _, control in ipairs(controls) do if self.hidden and self.hidden[control] then control:Show() end end
    end
    if not active then self.hidden = nil end
    Addon.NativeUI.send.recipientField:Show()
    Addon.NativeUI:LayoutBasicSend()
    if Addon.NativeUI.readySend then Addon.NativeUI:RefreshFavoriteButtons() end
end
function U:Refresh()
    local c, root = Addon.RuleSendController, self.root
    if not root or not self.active or self.refreshing then return end
    self.refreshing = true
    local current = Addon.Core.Characters:GetCurrent()
    local match = c.match or { byRule = {}, conflicts = {}, items = {} }
    local entries, groups = {}, {}
    for _, rule in ipairs(Addon.SendRules:List()) do
        local staged = false
        for _, item in ipairs(c.owned and c.packet or {}) do if item.ruleID == rule.id then staged = true; break end end
        if Addon.Recipients:CanRuleSend(rule.recipient, current) ~= false and (match.byRule[rule.id] or staged or c.skipped[rule.id]) then
            local key = Addon.Recipients:Key(rule.recipient)
            local group = groups[key]
            if not group then
                group = { key = key, recipient = rule.recipient, ruleIDs = {}, rules = {}, skipped = true, quantity = 0, stacks = 0, items = {}, byItem = {} }
                groups[key] = group; entries[#entries + 1] = group
            end
            group.ruleIDs[#group.ruleIDs + 1] = rule.id; group.rules[#group.rules + 1] = rule
            group.skipped = group.skipped and c.skipped[rule.id] == true
            group.staged = group.staged or staged
        end
    end
    for _, source in ipairs({ match.items or {}, c.owned and c.packet or {} }) do
        for _, item in ipairs(source) do
            local group = groups[Addon.Recipients:Key(item.recipient)]
            if group then
                group.quantity, group.stacks = group.quantity + item.quantity, group.stacks + 1
                local key = item.itemLink or tostring(item.itemID)
                if not group.byItem[key] then
                    local info = Addon.SendRules:GetItem(item.itemID) or {}
                    local copy = { itemID = item.itemID, name = info.name, texture = info.icon, itemLink = item.itemLink, quantity = 0 }
                    group.byItem[key] = copy; group.items[#group.items + 1] = copy
                end
                group.byItem[key].quantity = group.byItem[key].quantity + item.quantity
            end
        end
    end
    for _, conflict in ipairs(match.conflicts) do entries[#entries + 1] = { conflict = conflict } end
    for _, issue in ipairs(match.factionIssues or {}) do entries[#entries + 1] = { factionIssue = issue } end
    if match.pending and match.pending > 0 then entries[#entries + 1] = { message = match.unavailable or ("待识别分类：" .. match.pending .. " 组") } end
    if #entries == 0 then entries[1] = { message = match.blockedSender and "当前角色已被排除" or "暂无可寄物品，点击管理规则设置。" } end
    local width = math.max(1, root.scroll:GetWidth())
    root.content:SetWidth(width)
    local top = 0
    for index, entry in ipairs(entries) do
        local row = root.rows[index]
        if not row then
            row = CreateFrame("Frame", nil, root.content); root.rows[index] = row
            row.main = Addon.Core.UITheme:CreateButton(row, width, "")
            row.main:SetPoint("TOPLEFT", 0, 0)
            row.skip = Addon.Core.UITheme:CreateButton(row.main, 58, "跳过")
            row.skip:SetPoint("TOPRIGHT", -6, -3); row.skip:SetHeight(22)
        end
        row:Show(); row:SetSize(width, 48); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -top)
        if row.items then row.items:Hide(); for _, button in ipairs(row.items.itemButtons or {}) do button:Hide() end end
        row.entry = entry
        row.main.label:SetWordWrap(true); row.main.label:SetJustifyH("LEFT")
        row.main:SetWidth(width); row.main:SetHeight(32)
        local conflict = entry.conflict
        if entry.recipient then
            local label = "→ " .. Addon.ViewModel:CounterpartLabel(entry.recipient, current)
            label = label .. " · " .. (entry.skipped and "本次已跳过" or (entry.quantity .. "个 / " .. entry.stacks .. "组" .. (entry.staged and " · 已装填" or "")))
            row.main:SetText(label); row.main:SetEnabled(not entry.skipped and c.state ~= "sending" and c.state ~= "filling")
            row.main:SetScript("OnClick", function() Run(c.Select, { kind = "recipient", value = entry.key }) end)
            row.skip:Show(); row.skip:SetText(entry.skipped and "恢复" or "跳过")
            row.skip:SetEnabled(c.state ~= "sending" and c.state ~= "filling")
            row.skip:SetScript("OnClick", function() Run(c.Skip, entry.ruleIDs, entry.skipped) end)
            local lines = { entry.quantity .. " 个 · " .. entry.stacks .. " 组", "第一次点击装填，再次点击同一收件人发送。" }
            for _, rule in ipairs(entry.rules) do lines[#lines + 1] = Addon.SendRules:Label(rule) .. (c.skipped[rule.id] and " · 已跳过" or "") end
            Addon.Core.UITheme:BindTooltip(row.main, entry.recipient, lines)
            Addon.Core.UITheme:BindTooltip(row.skip, entry.skipped and "恢复收件人规则" or "跳过收件人规则", { entry.recipient, "本次邮箱会话对框内全部规则生效。" })
            if not row.items then
                row.items = CreateFrame("Button", nil, row.main)
                row.items.cell = Addon.Core.UITheme:CreateText(row.items, Addon.Core.UITheme.Font.body, Addon.Core.UITheme.Colors.text, "LEFT")
            end
            row.skip:SetFrameLevel(row.items:GetFrameLevel() + 2)
            local height = 28
            if #entry.items > 0 then
                local values = { itemList = entry.items, items = entry.recipient }
                local _; _, height = Addon.CacheUI:ItemLayout(values, width)
                row.items:ClearAllPoints(); row.items:SetPoint("TOPLEFT", 0, -24); row.items:SetSize(width, height)
                row.items:SetScript("OnClick", function() if row.main:IsEnabled() then row.main:GetScript("OnClick")() end end)
                Addon.CacheUI:ItemCell(row.items, row.items.cell, values, 0, width, height)
                row.items:Show()
            end
            row.main:SetHeight(height + 30); row:SetHeight(height + 30)
            row.main.label:ClearAllPoints(); row.main.label:SetPoint("TOPLEFT", 8, -4); row.main.label:SetPoint("TOPRIGHT", -72, -4)
            row.main.label:SetHeight(20); row.main.label:SetWordWrap(false)
        elseif entry.factionIssue then
            local issue = entry.factionIssue
            row.main:SetText(issue.rule.recipient .. "\n" .. issue.reason .. " · 点击处理")
            row.main:SetEnabled(true); row.skip:Hide()
            row.main:SetScript("OnClick", function() U:OpenSettings(issue.rule.id) end)
        elseif conflict then
            row.main:SetText("! " .. conflict.label .. "\n点击处理冲突")
            row.main:SetEnabled(true); row.skip:Hide()
            row.main:SetScript("OnClick", function() U:OpenSettings(conflict.ruleIDs[1]) end)
            local lines = {}
            for _, id in ipairs(conflict.ruleIDs) do
                local r = Addon.db.sendRules[id]; lines[#lines + 1] = r and (Addon.SendRules:Label(r) .. " → " .. r.recipient) or id
            end
            Addon.Core.UITheme:BindTooltip(row.main, conflict.label, lines)
        else
            row.main:SetWidth(width); row.main:SetHeight(32); row.main.label:SetWordWrap(true)
            row.main:SetText(entry.message); row.main:SetEnabled(false); row.skip:Hide()
            Addon.Core.UITheme:BindTooltip(row.main, entry.message, {})
        end
        if not entry.recipient then
            row.main.label:ClearAllPoints(); row.main.label:SetPoint("TOPLEFT", 8, -4); row.main.label:SetPoint("TOPRIGHT", -8, -4); row.main.label:SetHeight(0)
            local height = math.max(32, row.main.label:GetStringHeight() + 8)
            row.main.label:SetHeight(height - 8); row.main:SetHeight(height); row:SetHeight(height + 2)
        end
        top = top + row:GetHeight() + 2
    end
    for index = #entries + 1, #root.rows do root.rows[index]:Hide() end
    root.content:SetHeight(top); root.scroll:SetContentHeight(top)
    local label, enabled = c:ButtonState()
    self.action:SetText(label == "填入附件" and "装填" or label == "填入下一封" and "下一封" or label); self.action:SetEnabled(enabled)
    self.action:SetState(enabled and "default" or "disabled")
    self.undo:SetEnabled(c.owned ~= nil and c.state ~= "sending" and c.state ~= "filling")
    self.undo:SetState(self.undo:IsEnabled() and "default" or "disabled")
    local recipient = SendMailNameEditBox and SendMailNameEditBox:GetText() or ""
    self.recipient.value:SetText(recipient ~= "" and Addon.ViewModel:CounterpartLabel(recipient, current) or "待装填")
    self:Layout()
    local remaining, packets, last, stacks = #match.items, 0, nil, 0
    for _, item in ipairs(c:ScopeItems()) do
        if item.recipient ~= last or stacks >= (ATTACHMENTS_MAX_SEND or 12) then packets = packets + 1; last, stacks = item.recipient, 0 end
        stacks = stacks + 1
    end
    local summary = "本封 " .. #Addon.Compose:GetAttachments() .. " · 待寄 " .. remaining .. " 组 / " .. packets .. " 封"
    self.status:SetText(c.notice or summary)
    Addon.Core.UITheme:BindTooltip(self.recipient, "本封收件人", { recipient ~= "" and Addon.ViewModel:Escape(recipient) or "待装填", c.notice or summary })
    Addon.Core.UITheme:BindTooltip(self.action, label, { summary, recipient ~= "" and ("收件人：" .. recipient) or "选择规则或快捷联系人装填，再次点击发送。" })
    Addon.NativeUI:RefreshFavoriteButtons()
    self.refreshing = nil
    if math.abs(width - root.scroll:GetWidth()) > 0.1 then self:Refresh() end
end
function U:Drop(contact)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not contact then return end
    local address = contact.address
    if self.active then
        if ClearCursor then ClearCursor() end
        local item = Addon.SendRules:GetItem(itemID)
        if not item or not item.ready then Addon:Print("物品尚未加载，请稍后重试。"); return end
        local existing
        for _, rule in ipairs(Addon.SendRules:List()) do
            if rule.kind == "item" and Addon.SendRules:HasItem(rule, item.itemID)
                and Addon.SendRules:RecipientsOverlap(rule.recipient, address) and not next(rule.characters or {}) then
                existing = rule
                if Addon.Recipients:Key(rule.recipient) == Addon.Recipients:Key(address) then break end
            end
        end
        if existing and Addon.Recipients:Key(existing.recipient) == Addon.Recipients:Key(address) then
            local message = "该规则已存在，无需重复添加：" .. item.name .. " → " .. Addon.Recipients:Label(contact) .. "。"
            Addon.RuleSendController.notice = message; Addon:Print(message); U:Refresh(); return
        end
        local text = "将「" .. item.name .. "」寄给「" .. address .. "」？"
        if existing then text = text .. "\n将更新整条规则（" .. Addon.SendRules:Label(existing) .. "）的收件人；原收件人：" .. existing.recipient end
        local revision = Addon.db.sendRuleRevision
        Addon.Core.ItemConfirmation:Show({ text = text,
            IsCurrent = function() return Addon.db.sendRuleRevision == revision end,
            OnAccept = function()
                local draft = existing and Addon.Copy(existing) or { kind = "item", itemID = item.itemID, enabled = true }
                draft.recipient = address
                local ok, err = Addon.SendRules:Save(draft, existing and existing.id)
                if not ok then Addon:Print(err) end
                Addon.RuleSendController:Scan(); U:Refresh()
            end })
    else
        local ok, err = Addon.RuleSendController:Guard(true)
        if not ok or not Addon.RuleSendController:DraftEmpty() then Addon:Print(err or "请先处理当前邮件草稿。"); return end
        if not ClickSendMailItemButton then Addon:Print("客户端装填接口不可用。"); return end
        -- Stage only the exact cursor stack before attempting one player-triggered send.
        local success = pcall(ClickSendMailItemButton, 1)
        if not success or (CursorHasItem and CursorHasItem()) or #Addon.Compose:GetAttachments() ~= 1 then
            Addon:Print("客户端未确认装填，请检查鼠标与附件。"); return
        end
        Addon.NativeUI:SetMailRecipient(address); SendMailSubjectEditBox:SetText("物品寄送")
        local button = _G.SendMailMailButton or _G.SendMailSendButton
        if SendMailFrame_Update then SendMailFrame_Update() end
        local click = button and button:GetScript("OnClick")
        if click and button:IsEnabled() then
            Addon.Compose.nextSource = "shortcut-drop"
            local sent = pcall(click, button, "LeftButton")
            Addon.Compose.nextSource = nil
            if Addon.Compose.pendingSend then return end -- Await the result; never issue a second call.
            if sent and #Addon.Compose:GetAttachments() == 0 then return end
        end
        Addon:Print("客户端未确认直接发送，已填入物品和收件人；请检查邮件后点击发送。")
    end
end
