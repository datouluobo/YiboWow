local Addon = _G.YiboMail
local Compose = Addon.Compose
function Compose:ReadDraftFields()
    local body = self:GetBodyEditBox()
    return {recipient=SendMailNameEditBox and SendMailNameEditBox:GetText() or "",
        subject=SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() or "",
        body=body and body:GetText() or "",
        copper=MoneyInputFrame_GetCopper and SendMailMoney and MoneyInputFrame_GetCopper(SendMailMoney) or 0,
        cod=SendMailCODButton and SendMailCODButton:GetChecked() and true or false,
        hasRecipient=SendMailNameEditBox~=nil, hasSubject=SendMailSubjectEditBox~=nil, hasBody=body~=nil}
end
function Compose:WriteDraftFields(fields)
    if fields.recipient~=nil then SendMailNameEditBox:SetText(self:NativeRecipient(fields.recipient)) end
    if fields.subject~=nil then SendMailSubjectEditBox:SetText(fields.subject) end
    if fields.body~=nil then self:GetBodyEditBox():SetText(fields.body) end
end
function Compose:IsInCombat() return InCombatLockdown and InCombatLockdown() end
function Compose:IsSendLocked() return SendMailFrameLockSendMail and SendMailFrameLockSendMail:IsShown() end
function Compose:HasCursorItem() return CursorHasItem and CursorHasItem() end
function Compose:ClearItemCursor() if self:HasCursorItem() and ClearCursor then ClearCursor() end end
function Compose:CanEditAttachments() return type(ClickSendMailItemButton)=="function" end
function Compose:CanPickupItems() return type(C_Container and C_Container.PickupContainerItem or PickupContainerItem)=="function" end
function Compose:AttachmentCapacity() return ATTACHMENTS_MAX_SEND or 12 end
function Compose:RemoveAttachment(slot) return pcall(ClickSendMailItemButton,slot,true) end
function Compose:AttachBagItem(candidate,index)
    local pickup=C_Container and C_Container.PickupContainerItem or PickupContainerItem
    return pcall(function() pickup(candidate.bag,candidate.slot); ClickSendMailItemButton(index) end)
end
function Compose:GetBodyEditBox()
    if _G.MailEditBox and type(_G.MailEditBox.GetEditBox) == "function" then return _G.MailEditBox:GetEditBox() end
    return _G.SendMailBodyEditBox
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
    self:WriteDraftFields(self.draft)
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
    for bag = 0, Addon.Target and Addon.Target.lastSendBag or NUM_BAG_SLOTS or 4 do
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
