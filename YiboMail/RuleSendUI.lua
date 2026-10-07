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
    -- The rule list replaces the body region. Native attachment controls stay put.
    if SendMailAttachment1 then root:SetPoint("BOTTOMRIGHT", SendMailAttachment1, "TOPLEFT", MailFrame:GetWidth() - 48, 10)
    else root:SetPoint("BOTTOMRIGHT", MailFrame, "TOPRIGHT", -16, -245) end
    root:SetFrameLevel(native.send:GetFrameLevel() + 6)
    root:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    root:SetBackdropColor(unpack(theme.Colors.bg))
    root.title = theme:CreateText(root, theme.Font.body, theme.Colors.text, "LEFT")
    root.title:SetPoint("TOPLEFT", 8, -8); root.title:SetText("命中规则")
    root.manage = theme:CreateButton(root, 88, "管理规则")
    root.manage:SetPoint("TOPRIGHT", -80, -4); root.manage:SetHeight(theme.Size.compact); root.manage:SetScript("OnClick", function() U:OpenSettings() end)
    root.scroll = theme:CreateScrollFrame(root); root.scroll:SetPoint("TOPLEFT", 6, -38); root.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    root.content = CreateFrame("Frame", nil, root.scroll); root.content:SetSize(1, 1); root.scroll:SetScrollChild(root.content)
    root.rows = {}
    self.action = theme:CreateButton(native.send, 80, "装填", "primary")
    self.action:SetPoint("RIGHT", SendMailCancelButton, "LEFT", -6, 0)
    self.action:SetScript("OnClick", function() Run(Addon.RuleSendController.Primary) end)
    self.undo = theme:CreateButton(native.send, 64, "撤下", "secondary")
    self.undo:SetPoint("RIGHT", self.action, "LEFT", -6, 0)
    self.undo:SetScript("OnClick", function() Run(Addon.RuleSendController.Undo) end)
    self.status = theme:CreateText(native.send, theme.Font.assist, theme.Colors.muted, "LEFT")
    self.status:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8, 42)
    self.status:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, 42); self.status:SetHeight(20); self.status:SetWordWrap(false)
    if hooksecurefunc and MailFrameTab_OnClick then hooksecurefunc("MailFrameTab_OnClick", function(_, page)
        if page == 1 or page == 2 then U:SetActive(false) end
    end) end
    self:Layout(); self:SetActive(false)
end
function U:Layout()
    if not self.root then return end
    local native, theme = Addon.NativeUI, Addon.Core.UITheme
    self.root:ClearAllPoints(); self.root:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 8, -6)
    if SendMailAttachment1 then
        self.root:SetPoint("BOTTOMRIGHT", SendMailAttachment1, "TOPLEFT", MailFrame:GetWidth() - 16, 10)
    else self.root:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, 140) end
    self.action:SetHeight(theme.Size.compact); self.undo:SetHeight(theme.Size.compact)
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
    self.root:SetShown(active); self.action:SetShown(active); self.undo:SetShown(active); self.status:SetShown(active)
    local send = _G.SendMailMailButton or _G.SendMailSendButton
    if send then send:SetShown(not active) end
    local controls = { Addon.NativeUI.send.recipientField, Addon.NativeUI.send.subjectField, Addon.NativeUI.send.contacts }
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
    Addon.NativeUI:LayoutBasicSend()
    if Addon.NativeUI.readySend then Addon.NativeUI:RefreshFavoriteButtons() end
end
function U:Refresh()
    local c, root = Addon.RuleSendController, self.root
    if not root or not self.active then return end
    local match = c.match or { byRule = {}, conflicts = {}, items = {} }
    local entries = {}
    for _, rule in ipairs(Addon.SendRules:List()) do
        local row = match.byRule[rule.id]
        if c.owned and c.packet then
            local stagedQuantity, stagedStacks = 0, 0
            for _, item in ipairs(c.packet) do
                if item.ruleID == rule.id then stagedQuantity = stagedQuantity + item.quantity; stagedStacks = stagedStacks + 1 end
            end
            if stagedStacks > 0 then
                row = { rule = rule, quantity = (row and row.quantity or 0) + stagedQuantity,
                    stacks = (row and row.stacks or 0) + stagedStacks, staged = true }
            end
        end
        if row or c.skipped[rule.id] then entries[#entries + 1] = { rule = rule, row = row, skipped = c.skipped[rule.id] } end
    end
    for _, conflict in ipairs(match.conflicts) do entries[#entries + 1] = { conflict = conflict } end
    for _, issue in ipairs(match.factionIssues or {}) do entries[#entries + 1] = { factionIssue = issue } end
    if match.pending and match.pending > 0 then entries[#entries + 1] = { message = match.unavailable or ("待识别分类：" .. match.pending .. " 组") } end
    if #entries == 0 then entries[1] = { message = match.blockedSender and "当前角色已被排除" or "暂无可寄物品，点击管理规则设置。" } end
    local width = math.max(100, root.scroll:GetWidth() - 18)
    root.content:SetWidth(width)
    for index, entry in ipairs(entries) do
        local row = root.rows[index]
        if not row then
            row = CreateFrame("Frame", nil, root.content); root.rows[index] = row
            row.main = Addon.Core.UITheme:CreateButton(row, width - 64, "")
            row.main:SetPoint("LEFT", 0, 0)
            row.skip = Addon.Core.UITheme:CreateButton(row, 58, "跳过"); row.skip:SetPoint("RIGHT", 0, 0)
        end
        row:Show(); row:SetSize(width, 48); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 50)
        row.main:SetWidth(math.max(60, width - 64)); row.main:SetHeight(46)
        local rule, conflict = entry.rule, entry.conflict
        if rule then
            local label = Addon.SendRules:Label(rule) .. " → " .. rule.recipient
            label = label .. "\n" .. (entry.skipped and "本次已跳过" or (entry.row.quantity .. " 个 · " .. entry.row.stacks .. " 组" .. (entry.row.staged and " · 已装填" or "")))
            row.main:SetText(label); row.main:SetEnabled(not entry.skipped and c.state ~= "sending" and c.state ~= "filling")
            row.main:SetScript("OnClick", function() Run(c.Select, { kind = "rule", value = rule.id }) end)
            row.skip:Show(); row.skip:SetText(entry.skipped and "恢复" or "跳过")
            row.skip:SetEnabled(c.state ~= "sending" and c.state ~= "filling")
            row.skip:SetScript("OnClick", function() Run(c.Skip, rule.id, entry.skipped) end)
            Addon.Core.UITheme:BindTooltip(row.main, Addon.SendRules:Label(rule), { rule.recipient, "第一次点击装填，再次点击同一规则发送。" })
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
            row.main:SetWidth(width); row.main:SetHeight(46); row.main.label:SetWordWrap(true)
            row.main:SetText(entry.message); row.main:SetEnabled(false); row.skip:Hide()
        end
    end
    for index = #entries + 1, #root.rows do root.rows[index]:Hide() end
    root.content:SetHeight(#entries * 50); root.scroll:SetContentHeight(#entries * 50)
    local label, enabled = c:ButtonState()
    self.action:SetText(label == "填入附件" and "装填" or label == "填入下一封" and "下一封" or label); self.action:SetEnabled(enabled)
    self.action:SetState(enabled and "default" or "disabled")
    self.undo:SetEnabled(c.owned ~= nil and c.state ~= "sending" and c.state ~= "filling")
    self.undo:SetState(self.undo:IsEnabled() and "default" or "disabled")
    local recipient = SendMailNameEditBox and SendMailNameEditBox:GetText() or ""
    local remaining, packets, last, stacks = #match.items, 0, nil, 0
    for _, item in ipairs(c:ScopeItems()) do
        if item.recipient ~= last or stacks >= (ATTACHMENTS_MAX_SEND or 12) then packets = packets + 1; last, stacks = item.recipient, 0 end
        stacks = stacks + 1
    end
    local summary = "本封 " .. #Addon.Compose:GetAttachments() .. " · 待寄 " .. remaining .. " 组 / " .. packets .. " 封"
    self.status:SetText(c.notice or summary)
    Addon.Core.UITheme:BindTooltip(self.action, label, { summary, recipient ~= "" and ("收件人：" .. recipient) or "选择规则或快捷联系人装填，再次点击发送。" })
    Addon.NativeUI:RefreshFavoriteButtons()
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
            if rule.kind == "item" and rule.itemID == item.itemID and not next(rule.characters or {}) then existing = rule end
        end
        local text = "将「" .. item.name .. "」寄给「" .. address .. "」？"
        if existing then text = text .. "\n原收件人：" .. existing.recipient end
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
