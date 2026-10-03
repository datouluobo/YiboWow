local Addon = _G.YiboMail
local Compose = { draft = { recipient = "", subject = "", body = "", copper = 0, cod = false } }; Addon.Compose = Compose
function Compose:DraftFingerprint()
    local values = { self.draft.recipient, self.draft.subject, self.draft.body, self.draft.copper, self.draft.cod }
    for _, item in ipairs(self:GetAttachments()) do values[#values + 1] = Addon.Encode({ item.slot, item.itemLink or item.itemID, item.quantity }) end
    return Addon.Encode(values)
end
function Compose:GetAttachments()
    local result = {}
    if not Addon.Scanner:IsOpen() or not GetSendMailItem then return result end
    for slot = 1, ATTACHMENTS_MAX_SEND or 12 do
        local name, id, texture, quantity = GetSendMailItem(slot)
        if name then result[#result + 1] = { slot = slot, name = name, itemID = id, texture = texture, quantity = quantity,
            itemLink = GetSendMailItemLink and GetSendMailItemLink(slot) } end
    end
    return result
end
function Compose:OpenNative()
    if SendMailFrameLockSendMail and SendMailFrameLockSendMail:IsShown() then return nil, "请先处理原生附件确认提示。" end
    if Addon.Queue.state == "running" or Addon.Queue.pending then return nil, "请先暂停收件队列并等待当前操作结束。" end
    if not Addon.Scanner:IsOpen() then return nil, "请先在游戏中打开邮箱。" end
    if InCombatLockdown and InCombatLockdown() then return nil, "战斗中无法装填邮件。" end
    if not MailFrameTab_OnClick or not SendMailNameEditBox or not SendMailSubjectEditBox or not SendMailBodyEditBox then return nil, "当前客户端发件界面未就绪。" end
    MailFrameTab_OnClick(nil, 2); return true
end
function Compose:ApplyDraft()
    local ok, err = self:OpenNative(); if not ok then return nil, err end
    if self.draft.recipient == "" then return nil, "请填写收件人。" end
    if self.draft.cod and #self:GetAttachments() == 0 then return nil, "付款取信需要附件。" end
    if self.draft.copper > 0 and (not MoneyInputFrame_SetCopper or not SendMailMoney or not SendMailRadioButton_OnClick) then return nil, "当前客户端无法装填寄送金额，请在原生发件箱填写。" end
    SendMailNameEditBox:SetText(self.draft.recipient); SendMailSubjectEditBox:SetText(self.draft.subject); SendMailBodyEditBox:SetText(self.draft.body)
    if MoneyInputFrame_SetCopper and SendMailMoney and SendMailRadioButton_OnClick then
        MoneyInputFrame_SetCopper(SendMailMoney, self.draft.copper); SendMailRadioButton_OnClick(self.draft.cod and 2 or 1)
    end
    return true
end
function Compose:ClickSlot(slot, clear)
    local ok, err = self:OpenNative(); if not ok then return nil, err end
    if not ClickSendMailItemButton then return nil, "当前客户端未提供附件装填接口。" end
    local success, errorMessage = pcall(ClickSendMailItemButton, slot, clear); return success, errorMessage
end
function Compose:BagItems()
    local result = {}
    local count = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local info = C_Container and C_Container.GetContainerItemInfo
    if not count then return result end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, count(bag) do
            local item
            if info then item = info(bag, slot)
            elseif GetContainerItemInfo then
                local texture, quantity, locked, _, _, _, link, _, _, id, bound = GetContainerItemInfo(bag, slot)
                if texture then item = { iconFileID = texture, stackCount = quantity, isLocked = locked, hyperlink = link, itemID = id, isBound = bound } end
            end
            if item and item.hyperlink and not item.isLocked and not item.isBound then
                local id = item.itemID or tonumber(item.hyperlink:match("item:(%d+)"))
                if id then result[#result + 1] = { bag = bag, slot = slot, itemID = id, itemLink = item.hyperlink, quantity = item.stackCount,
                    texture = item.iconFileID, name = item.hyperlink } end
            end
        end
    end
    return result
end
function Compose:GetSuggestions()
    local results = {}
    local bags = self:BagItems()
    local ids = {}; for id in pairs(Addon.db.rules) do ids[#ids + 1] = id end; table.sort(ids)
    for _, id in ipairs(ids) do
        local rule = Addon.db.rules[id]
        if rule.enabled ~= false then
            local address = Addon.Rules and Addon.Rules:NormalizeAddress(rule.recipient) or rule.recipient
            local group = { itemID = id, recipient = address or rule.recipient, items = {}, quantity = 0 }
            for _, item in ipairs(bags) do
                if item.itemID == id and #group.items < (ATTACHMENTS_MAX_SEND or 12) then
                    group.items[#group.items + 1] = item; group.quantity = group.quantity + item.quantity
                end
            end
            if #group.items > 0 then results[#results + 1] = group end
        end
    end
    return results
end
function Compose:PrepareFill(suggestion)
    local existing = self:GetAttachments()
    if #existing > 0 then return nil, "请先整理原生发件箱中的附件，再预览规则装填。" end
    if #suggestion.items > (ATTACHMENTS_MAX_SEND or 12) then return nil, "本规则超过单封附件格数，请先减少背包中的候选整叠数量。" end
    self.fill = Addon.Copy(suggestion); self.fill.index = 1; self.fill.staged = {}
    return true
end
function Compose:FillNext()
    local plan = self.fill; if not plan then return nil, "请先预览规则装填。" end
    local ok, err = self:OpenNative(); if not ok then return nil, err end
    if CursorHasItem and CursorHasItem() then return nil, "请先放下鼠标上的物品。" end
    local candidate = plan.items[plan.index]; if not candidate then return nil, "本封装填已完成。" end
    local current
    for _, item in ipairs(self:BagItems()) do if item.bag == candidate.bag and item.slot == candidate.slot then current = item end end
    if not current or current.itemLink ~= candidate.itemLink or current.quantity ~= candidate.quantity then return nil, "背包内容已变化，请重新预览。" end
    local attached = self:GetAttachments()
    if #attached ~= #plan.staged then return nil, "发件附件已被修改，请重新预览。" end
    for _, item in ipairs(attached) do
        local prior = plan.staged[item.slot]; if not prior or prior.itemLink ~= item.itemLink or prior.quantity ~= item.quantity then return nil, "发件附件已变化，请重新预览。" end
    end
    local pickup = C_Container and C_Container.PickupContainerItem or PickupContainerItem
    if not pickup or not ClickSendMailItemButton then return nil, "装填接口不可用。" end
    local slot = plan.index
    local success, errorMessage = pcall(function() pickup(candidate.bag, candidate.slot); ClickSendMailItemButton(slot) end)
    if not success then return nil, tostring(errorMessage) end
    local staged
    for _, item in ipairs(self:GetAttachments()) do if item.slot == slot then staged = item end end
    if not staged or staged.itemLink ~= candidate.itemLink or staged.quantity ~= candidate.quantity then return nil, "客户端未确认装填，请在原生发件箱检查。" end
    plan.staged[slot] = staged; plan.index = plan.index + 1
    self.draft.recipient = plan.recipient; SendMailNameEditBox:SetText(plan.recipient)
    return true
end
function Compose:UndoFill()
    local plan = self.fill; if not plan then return true end
    local ok, err = self:OpenNative(); if not ok then return nil, err end
    local attached = self:GetAttachments()
    for _, item in ipairs(attached) do
        local prior = plan.staged[item.slot]
        if prior and (prior.itemLink ~= item.itemLink or prior.quantity ~= item.quantity) then return nil, "附件已被修改，请在原生发件箱手动整理。" end
    end
    for index = #attached, 1, -1 do if plan.staged[attached[index].slot] then ClickSendMailItemButton(attached[index].slot, true) end end
    self.fill = nil; return true
end
function Compose:Install()
    if self.hooked or not hooksecurefunc or not SendMail then return end
    hooksecurefunc("SendMail", function(recipient, subject)
        local character = Addon.Core.Characters:GetCurrent()
        if character then Compose.pendingSend = { characterID = character.id, recipient = recipient, subject = subject,
            attachments = Compose:GetAttachments(), observedAt = Addon:Now(), state = "unverified",
            copper = MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney) or 0,
            cod = SendMailCODButton and SendMailCODButton:GetChecked() or false } end
    end)
    self.hooked = true
end
function Compose:OnEvent(event)
    if event == "MAIL_SEND_SUCCESS" and self.pendingSend then
        self.pendingSend.state = "in-transit"
        Addon:AddHistory(self.pendingSend.characterID, self.pendingSend)
        self.pendingSend, self.fill = nil, nil; self.draft = { recipient = "", subject = "", body = "", copper = 0, cod = false }
    elseif (event == "MAIL_FAILED" or event == "MAIL_CLOSED") and self.pendingSend then
        Addon:AddHistory(self.pendingSend.characterID, self.pendingSend); self.pendingSend = nil
    elseif event == "MAIL_CLOSED" then self.fill = nil end
    if event == "MAIL_SEND_INFO_UPDATE" or event == "MAIL_SEND_SUCCESS" or event == "MAIL_FAILED" or event == "BAG_UPDATE_DELAYED" then
        Addon.Core.AccountView:NotifyPageChanged("mail-inbox")
    end
end
