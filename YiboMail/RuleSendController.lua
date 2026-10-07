local Addon = _G.YiboMail
local C = { state = "idle", skipped = {} }; Addon.RuleSendController = C
local function Text(box) return box and box:GetText() or "" end
function C:Changed()
    if Addon.RuleSendUI then Addon.RuleSendUI:Refresh() end
end
function C:GetRuleIDs()
    local ids, seen = {}, {}
    for _, item in ipairs(self.packet or {}) do
        for _, id in ipairs(item.ruleIDs or { item.ruleID }) do
            if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        end
    end
    table.sort(ids); return ids
end
function C:Guard(allowCursor)
    if not Addon.Scanner:IsOpen() then return nil, "请先打开游戏邮箱。" end
    if InCombatLockdown and InCombatLockdown() then return nil, "战斗中无法寄件。" end
    if Addon.Queue.pending or Addon.Queue.state == "running" then return nil, "请先结束收件操作。" end
    if SendMailFrameLockSendMail and SendMailFrameLockSendMail:IsShown() then return nil, "请先处理原生确认提示。" end
    if not allowCursor and CursorHasItem and CursorHasItem() then return nil, "请先放下鼠标上的物品。" end
    if Addon.Compose.pendingSend or self.state == "sending" or self.state == "filling" then return nil, "请等待当前操作结果。" end
    return true
end
function C:DraftEmpty()
    local copper = MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney) or 0
    return #Addon.Compose:GetAttachments() == 0 and not Text(SendMailSubjectEditBox):match("%S")
        and not Text(Addon.Compose:GetBodyEditBox()):match("%S") and copper == 0
        and not (SendMailCODButton and SendMailCODButton:GetChecked())
end
function C:Fingerprint()
    local values = { Text(SendMailNameEditBox), Text(SendMailSubjectEditBox), Text(Addon.Compose:GetBodyEditBox()),
        MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney) or 0,
        SendMailCODButton and SendMailCODButton:GetChecked() and 1 or 0 }
    for _, item in ipairs(Addon.Compose:GetAttachments()) do
        values[#values + 1] = Addon.Encode({ item.slot, item.itemLink or item.itemID, item.quantity })
    end
    return Addon.Encode(values)
end
function C:Scan()
    self.match = Addon.SendRules:Match(Addon.Compose:BagItems(), self.skipped)
    self.revision = Addon.db.sendRuleRevision
    return self.match
end
function C:Invalidate(message)
    if self.state == "sending" or self.state == "filling" then self.dirty = true; return end
    self.state, self.notice = "invalid", message or "计划已变化，请重新匹配。"
end
function C:ScopeItems()
    local items = {}
    for _, item in ipairs((self.match or {}).items or {}) do
        if not self.scope or self.scope.kind == "rule" and item.ruleID == self.scope.value
            or self.scope.kind == "recipient" and Addon.Recipients:Key(item.recipient) == self.scope.value then items[#items + 1] = item end
    end
    return items
end
function C:Undo()
    local ok, err = self:Guard(); if not ok then return nil, err end
    if not self.owned then return true end
    local body = Addon.Compose:GetBodyEditBox()
    if not SendMailSubjectEditBox or not body then return nil, "当前客户端发件界面未就绪。" end
    if self:Fingerprint() ~= self.fingerprint then self.state = "invalid"; return nil, "邮件已被手动修改，请先整理实际附件。" end
    for index = #self.owned, 1, -1 do
        local success = pcall(ClickSendMailItemButton, self.owned[index].slot, true)
        if not success then return nil, "撤下失败，请检查附件。" end
    end
    if #Addon.Compose:GetAttachments() > 0 then return nil, "附件尚未归还，请检查邮箱。" end
    SendMailSubjectEditBox:SetText(""); body:SetText("")
    self.owned, self.fingerprint, self.packet, self.state = nil, nil, nil, "idle"
    self:Scan(); self:Changed(); return true
end
function C:Select(scope)
    if self.state == "ready" and self.scope and self.scope.kind == scope.kind and self.scope.value == scope.value then return self:Send() end
    local ok, err = self:Guard(); if not ok then return nil, err end
    local body = Addon.Compose:GetBodyEditBox()
    if not SendMailSubjectEditBox or not body then return nil, "当前客户端发件界面未就绪。" end
    local attachments = Addon.Compose:GetAttachments()
    if #attachments > 0 and not ClickSendMailItemButton then return nil, "客户端撤下接口不可用。" end
    for index = #attachments, 1, -1 do
        local success = pcall(ClickSendMailItemButton, attachments[index].slot, true)
        if not success then self:Invalidate(); return nil, "撤下失败，请检查附件。" end
    end
    if #Addon.Compose:GetAttachments() > 0 then self:Invalidate(); return nil, "附件尚未归还，请检查背包空间。" end
    if self.owned or #attachments > 0 then
        SendMailSubjectEditBox:SetText("")
        body:SetText("")
    end
    self.owned, self.packet, self.fingerprint = nil, nil, nil
    self.scope, self.state = scope, "idle"; self:Scan()
    if #self:ScopeItems() == 0 then self.notice = "此目标当前没有可寄物品。"; self:Changed(); return nil, self.notice end
    return self:Fill()
end
function C:Fill(advance)
    local ok, err = self:Guard(); if not ok then return nil, err end
    local body = Addon.Compose:GetBodyEditBox()
    if not SendMailNameEditBox or not SendMailSubjectEditBox or not body then return nil, "当前客户端发件界面未就绪。" end
    if not self:DraftEmpty() then return nil, "请先处理当前邮件草稿。" end
    self:Scan()
    local items = self:ScopeItems()
    if #items == 0 and self.scope and advance then self.scope = nil; items = self:ScopeItems() end
    if #items == 0 then
        self.state = self.match.pending > 0 and "invalid" or "done"
        self.notice = self.match.blockedSender and "当前角色在全局黑名单中。" or self.match.pending > 0 and "物品分类尚未加载，请稍后重新匹配。" or "当前没有可寄物品。"
        self:Changed(); return nil, self.notice
    end
    if not ClickSendMailItemButton then return nil, "客户端装填接口不可用。" end
    local pickup = C_Container and C_Container.PickupContainerItem or PickupContainerItem
    if not pickup then return nil, "客户端背包接口不可用。" end
    local recipient, packet = items[1].recipient, {}
    local allowed, reason = Addon.Recipients:CanRuleSend(recipient)
    if not allowed then self:Invalidate(reason); return nil, reason end
    for _, item in ipairs(items) do
        if item.recipient == recipient and #packet < (ATTACHMENTS_MAX_SEND or 12) then packet[#packet + 1] = Addon.Copy(item) end
    end
    self.state, self.dirty, self.packet, self.owned = "filling", nil, packet, {}
    local bagItems = Addon.Compose:BagItems()
    for _, candidate in ipairs(packet) do
        local found
        for _, item in ipairs(bagItems) do
            if item.bag == candidate.bag and item.slot == candidate.slot and item.itemLink == candidate.itemLink
                and item.quantity == candidate.quantity then found = true end
        end
        if not found then self.state, self.owned, self.packet = "invalid", nil, nil; return nil, "背包内容已变化，请重新匹配。" end
    end
    SendMailNameEditBox:SetText(recipient)
    local distinct = {}
    for _, item in ipairs(packet) do distinct[item.itemID] = true end
    local kinds = 0; for _ in pairs(distinct) do kinds = kinds + 1 end
    SendMailSubjectEditBox:SetText((packet[1].name or "物品寄送") .. (kinds > 1 and ("等 " .. kinds .. " 种物品") or ""))
    body:SetText("")
    self.fingerprint = self:Fingerprint()
    for index, candidate in ipairs(packet) do
        local success = pcall(function() pickup(candidate.bag, candidate.slot); ClickSendMailItemButton(index) end)
        local actual
        for _, item in ipairs(Addon.Compose:GetAttachments()) do if item.slot == index then actual = item end end
        if not success or (CursorHasItem and CursorHasItem()) or not actual or actual.itemLink ~= candidate.itemLink
            or actual.quantity ~= candidate.quantity then
            if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
            self.state, self.notice = "invalid", "客户端未确认装填，请检查附件后撤下或重新匹配。"
            self.fingerprint = self:Fingerprint(); self:Changed(); return nil, self.notice
        end
        self.owned[#self.owned + 1] = actual
        self.fingerprint = self:Fingerprint()
    end
    self.state, self.notice, self.dirty = "ready", "请核对收件人和附件，再点击发送。", nil
    self:Scan()
    self:Changed(); return true
end
function C:Send()
    local ok, err = self:Guard(); if not ok then return nil, err end
    local allowed, reason = Addon.Recipients:CanRuleSend(Text(SendMailNameEditBox))
    if not allowed then self:Invalidate(reason); self:Changed(); return nil, reason end
    if self.state ~= "ready" or self.revision ~= Addon.db.sendRuleRevision or self:Fingerprint() ~= self.fingerprint then
        self:Invalidate("邮件或规则已变化，请检查附件。")
        self:Changed(); return nil, self.notice
    end
    local button = _G.SendMailMailButton or _G.SendMailSendButton
    local click = button and button:GetScript("OnClick")
    if not click then return nil, "原生发送按钮不可用。" end
    if SendMailFrame_Update then SendMailFrame_Update() end
    if not button:IsEnabled() then return nil, "原生发件条件未满足，请检查收件人、附件和邮资。" end
    self.state, self.notice, self.startedAt = "sending", "正在发送，请等待结果。", GetTime and GetTime() or 0
    self:Changed()
    ok, err = pcall(click, button, "LeftButton")
    if not ok then self.state, self.notice = "invalid", "发送调用失败，请检查邮件。"; self:Changed(); return nil, tostring(err) end
    return true
end
function C:Primary()
    if self.state == "ready" then return self:Send() end
    if self.state == "invalid" then
        local ok, err = self:Guard(); if not ok then return nil, err end
        if self.owned or not self:DraftEmpty() then return nil, "请撤下或整理当前草稿，再重新匹配。" end
        self:Scan(); self.state, self.notice = "idle", "已重新匹配，点击填入附件。"; self:Changed(); return true
    end
    return self:Fill(true)
end
function C:Contact(address)
    local key = Addon.Recipients:Key(address)
    if self.state == "ready" and self.packet and Addon.Recipients:Key(self.packet[1].recipient) == key then return self:Send() end
    return self:Select({ kind = "recipient", value = key })
end
function C:Skip(id, restore)
    local ok, err = self:Undo(); if not ok then return nil, err end
    self.skipped[id] = not restore or nil
    self.scope, self.state = nil, "idle"; self:Scan(); self:Changed(); return true
end
function C:OnEvent(event)
    if event == "MAIL_CLOSED" then
        self.state, self.skipped, self.scope, self.owned, self.packet, self.fingerprint = "idle", {}, nil, nil, nil, nil
        self.match, self.notice, self.dirty = nil, nil, nil
    elseif event == "MAIL_SEND_SUCCESS" and self.state == "sending" then
        self.state, self.owned, self.fingerprint, self.packet = "idle", nil, nil, nil
        self.notice = "发送成功，点击填入下一封。"; self:Scan()
    elseif (event == "MAIL_FAILED" or event == "ADDON_ACTION_BLOCKED") and self.state == "sending" then
        self.state, self.notice = "invalid", "发送未确认，请检查当前邮件；不会自动重试。"
    elseif event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then
        if self.state ~= "sending" and self.state ~= "filling" then self:Scan() end
    elseif event == "MAIL_SEND_INFO_UPDATE" and self.state == "ready" and self:Fingerprint() ~= self.fingerprint then self:Invalidate() end
    self:Changed()
end
function C:Tick()
    if self.state == "sending" and GetTime and GetTime() - (self.startedAt or GetTime()) > 15 then
        self.state, self.notice = "invalid", "发送结果超时，请检查邮箱；不会自动重试。"
        self:Changed()
    end
end
function C:ButtonState()
    if self.state == "ready" then return "发送", true end
    if self.state == "sending" then return "正在发送", false end
    if self.state == "filling" then return "正在装填", false end
    if self.state == "invalid" then return "重新匹配", true end
    local count = #(self.match and self.match.items or {})
    if count == 0 and self.match and self.match.pending > 0 then return "重新匹配", true end
    return count > 0 and (self.notice and "填入下一封" or "填入附件") or "已完成", count > 0
end
