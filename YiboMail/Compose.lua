local Addon = _G.YiboMail
local Compose = { draft = { recipient = "", subject = "", body = "", copper = 0, cod = false } }; Addon.Compose = Compose
function Compose:GetBodyEditBox()
    if _G.MailEditBox and type(_G.MailEditBox.GetEditBox) == "function" then return _G.MailEditBox:GetEditBox() end
    return _G.SendMailBodyEditBox
end
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
function Compose:SubjectForAttachments(items)
    if type(items) ~= "table" then items = {} end
    if #items == 0 then
        local copper = tonumber(MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney)) or 0
        return copper > 0 and Addon:T("UI.TEXT_0617") or nil
    end
    local firstName = type(items[1].name) == "string" and items[1].name:match("%S") and items[1].name or Addon:T("UI.TEXT_0457")
    local distinct, kinds = {}, 0
    for _, item in ipairs(items) do
        local key = item.itemID or item.name
        if key ~= nil and not distinct[key] then distinct[key], kinds = true, kinds + 1 end
    end
    return firstName .. (kinds > 1 and (Addon:T("UI.TEXT_0474") .. kinds .. Addon:T("UI.TEXT_0044")) or "")
end
function Compose:EnsureSubject(items)
    local box = _G.SendMailSubjectEditBox
    if not box or (box:GetText() or ""):match("%S") then return false end
    local subject = self:SubjectForAttachments(items or self:GetAttachments())
    if not subject then return false end
    box:SetText(subject)
    return true, subject
end
function Compose:HasSendMoney()
    return (tonumber(MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney)) or 0) > 0
end
function Compose:ClearDraft()
    self.draft = { recipient = "", subject = "", body = "", copper = 0, cod = false }
    if SendMailNameEditBox then SendMailNameEditBox:SetText("") end
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText("") end
    local body = self:GetBodyEditBox()
    if body then body:SetText("") end
    if SendMailRadioButton_OnClick then pcall(SendMailRadioButton_OnClick, 1)
    elseif SendMailCODButton and SendMailCODButton.SetChecked then SendMailCODButton:SetChecked(false) end
    if SendMailMoney then
        if MoneyInputFrame_ResetMoney then pcall(MoneyInputFrame_ResetMoney, SendMailMoney)
        elseif MoneyInputFrame_SetCopper then pcall(MoneyInputFrame_SetCopper, SendMailMoney, 0) end
    end
end
function Compose:OpenNative()
    if SendMailFrameLockSendMail and SendMailFrameLockSendMail:IsShown() then return nil, Addon:T("UI.TEXT_0522") end
    if Addon.Queue.state == "running" or Addon.Queue.pending then return nil, Addon:T("UI.TEXT_0528") end
    if not Addon.Scanner:IsOpen() then return nil, Addon:T("UI.TEXT_0520") end
    if InCombatLockdown and InCombatLockdown() then return nil, Addon:T("UI.TEXT_0309") end
    if not MailFrameTab_OnClick or not SendMailNameEditBox or not SendMailSubjectEditBox or not self:GetBodyEditBox() then return nil, Addon:T("UI.TEXT_0262") end
    if securecallfunction then securecallfunction(MailFrameTab_OnClick, nil, 2)
    else MailFrameTab_OnClick(nil, 2) end
    return true
end
function Compose:ApplyDraft()
    local ok, err = self:OpenNative(); if not ok then return nil, err end
    if self.draft.recipient == "" then return nil, Addon:T("UI.TEXT_0539") end
    if self.draft.cod and #self:GetAttachments() == 0 then return nil, Addon:T("UI.TEXT_0113") end
    if self.draft.copper > 0 and (not MoneyInputFrame_SetCopper or not SendMailMoney or not SendMailRadioButton_OnClick) then return nil, Addon:T("UI.TEXT_0263") end
    SendMailNameEditBox:SetText(self.draft.recipient); SendMailSubjectEditBox:SetText(self.draft.subject); self:GetBodyEditBox():SetText(self.draft.body)
    if MoneyInputFrame_SetCopper and SendMailMoney and SendMailRadioButton_OnClick then
        MoneyInputFrame_SetCopper(SendMailMoney, self.draft.copper); SendMailRadioButton_OnClick(self.draft.cod and 2 or 1)
    end
    return true
end
function Compose:ClickSlot(slot, clear)
    local ok, err = self:OpenNative(); if not ok then return nil, err end
    if not ClickSendMailItemButton then return nil, Addon:T("UI.TEXT_0264") end
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
function Compose:AddMatchingBagItems(bag, slot)
    if not Addon.Scanner:IsOpen() or not SendMailFrame or not SendMailFrame:IsShown() then return nil, Addon:T("UI.TEXT_0524") end
    if InCombatLockdown and InCombatLockdown() then return nil, Addon:T("UI.TEXT_0309") end
    if CursorHasItem and CursorHasItem() then return nil, Addon:T("UI.TEXT_0527") end
    local selected
    for _, item in ipairs(self:BagItems()) do
        if item.bag == bag and item.slot == slot then selected = item; break end
    end
    if not selected then return nil, Addon:T("UI.TEXT_0515") end
    local attached, matching = self:GetAttachments(), {}
    local occupied = {}
    for _, item in ipairs(attached) do
        occupied[item.slot] = true
        if item.itemID == selected.itemID then matching[#matching + 1] = item end
    end
    local capacity = ATTACHMENTS_MAX_SEND or 12
    if #matching > 0 then return nil, Addon:T("UI.TEXT_0202") end
    local candidates = {}
    for _, item in ipairs(self:BagItems()) do
        if item.itemID == selected.itemID then candidates[#candidates + 1] = item end
    end
    local pickup = C_Container and C_Container.PickupContainerItem or PickupContainerItem
    if not pickup or not ClickSendMailItemButton then return nil, Addon:T("UI.TEXT_0497") end
    local added = 0
    for _, item in ipairs(candidates) do
        if added + #attached >= capacity then break end
        if not CursorHasItem or not CursorHasItem() then
            local target
            for index = 1, capacity do if not occupied[index] then target = index; break end end
            if not target then break end
            local ok = pcall(function() pickup(item.bag, item.slot); ClickSendMailItemButton(target) end)
            if not ok or (CursorHasItem and CursorHasItem()) then break end
            occupied[target] = true; added = added + 1
        else break end
    end
    return added > 0, added > 0 and (Addon:T("UI.TEXT_0245") .. added .. Addon:T("UI.TEXT_0047")) or Addon:T("UI.TEXT_0436")
end
function Compose:Install()
    if self.hooked or not hooksecurefunc or not SendMail then return end
    hooksecurefunc("SendMail", function(recipient, subject)
        local character = Addon.Recipients:Current()
        if character then Compose.pendingSend = { characterID = character.id, senderFaction = character.faction, recipient = recipient, subject = subject,
            attachments = Compose:GetAttachments(), observedAt = Addon:Now(), state = "unverified",
            copper = MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney) or 0,
            cod = SendMailCODButton and SendMailCODButton:GetChecked() or false,
            source = Compose.nextSource or (Addon.RuleSendUI and Addon.RuleSendUI.active and "rule-send" or "native-send"),
            ruleIDs = Addon.RuleSendController and Addon.RuleSendController.state == "sending" and Addon.RuleSendController:GetRuleIDs() or nil } end
    end)
    self.hooked = true
end
function Compose:OnEvent(event)
    if event == "MAIL_SEND_SUCCESS" and self.pendingSend then
        self.pendingSend.state = "in-transit"
        self.pendingSend.attemptedAt, self.pendingSend.observedAt = self.pendingSend.observedAt, Addon:Now()
        if Addon.Recipients and Addon.Recipients.ObserveSuccessfulMail then
            -- Gold proves an ordinary mail under this client's faction rules;
            -- attachment-only mail may contain cross-faction account-bound items.
            Addon.Recipients:ObserveSuccessfulMail(self.pendingSend.recipient, self.pendingSend.senderFaction, (self.pendingSend.copper or 0) > 0)
        end
        if Addon.Recipients then Addon.Recipients:RecordRecent(self.pendingSend.recipient) end
        Addon:AddHistory(self.pendingSend.characterID, self.pendingSend)
        self.pendingSend = nil; self:ClearDraft()
    elseif (event == "MAIL_FAILED" or event == "MAIL_CLOSED") and self.pendingSend then
        Addon:AddHistory(self.pendingSend.characterID, self.pendingSend); self.pendingSend = nil
    end
    if event == "MAIL_CLOSED" then self:ClearDraft() end
    if Addon.FEATURES.account and (event == "MAIL_SEND_INFO_UPDATE" or event == "MAIL_SEND_SUCCESS" or event == "MAIL_FAILED" or event == "BAG_UPDATE_DELAYED") then
        Addon.Core.AccountView:NotifyPageChanged("mail-inbox")
    end
end
