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
    if not Addon.Scanner:IsOpen() then return nil, Addon:T("UI.TEXT_0525") end
    if InCombatLockdown and InCombatLockdown() then return nil, Addon:T("UI.TEXT_0307") end
    if Addon.Queue.pending or Addon.Queue.state == "running" then return nil, Addon:T("UI.TEXT_0534") end
    if SendMailFrameLockSendMail and SendMailFrameLockSendMail:IsShown() then return nil, Addon:T("UI.TEXT_0521") end
    if not allowCursor and CursorHasItem and CursorHasItem() then return nil, Addon:T("UI.TEXT_0527") end
    if Addon.Compose.pendingSend or self.state == "sending" or self.state == "filling" then return nil, Addon:T("UI.TEXT_0551") end
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
    self.state, self.notice = "invalid", message or Addon:T("UI.TEXT_0510")
end
function C:ReconcileDraft()
    if self.state == "sending" or self.state == "filling" then return end
    if self.owned and self:DraftEmpty() then
        self.owned, self.packet, self.fingerprint, self.draftFields = nil, nil, nil, nil
        self.state, self.notice = "idle", nil
    elseif self.state == "ready" and self:Fingerprint() ~= self.fingerprint then
        self:Invalidate(Addon:T("UI.TEXT_0593"))
    end
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
    local attachments = Addon.Compose:GetAttachments()
    if not self.owned and #attachments == 0 then return true end
    local body = Addon.Compose:GetBodyEditBox()
    if not SendMailSubjectEditBox or not body then return nil, Addon:T("UI.TEXT_0262") end
    if #attachments > 0 and not ClickSendMailItemButton then return nil, Addon:T("UI.TEXT_0222") end
    -- Undo is an explicit request to return the actual attachments, including
    -- manual additions. A stale plan must never prevent recovering the draft.
    for index = #attachments, 1, -1 do
        local success = pcall(ClickSendMailItemButton, attachments[index].slot, true)
        if not success then return nil, Addon:T("UI.TEXT_0330") end
    end
    if #Addon.Compose:GetAttachments() > 0 then return nil, Addon:T("UI.TEXT_0627") end
    -- Remove only generated text that the player has left unchanged.
    local fields = self.draftFields
    if fields and Text(SendMailSubjectEditBox) == fields.subject then SendMailSubjectEditBox:SetText("") end
    if fields and Text(body) == fields.body then body:SetText("") end
    self.draftFields = nil
    self.owned, self.fingerprint, self.packet, self.state = nil, nil, nil, "idle"
    self.notice = not self:DraftEmpty() and Addon:T("UI.TEXT_0628") or nil
    self:Scan(); self:Changed(); return true
end
function C:Select(scope)
    if self.state == "ready" and self.scope and self.scope.kind == scope.kind and self.scope.value == scope.value then return self:Send() end
    local ok, err = self:Guard(); if not ok then return nil, err end
    local body = Addon.Compose:GetBodyEditBox()
    if not SendMailSubjectEditBox or not body then return nil, Addon:T("UI.TEXT_0262") end
    local attachments = Addon.Compose:GetAttachments()
    if #attachments > 0 and not ClickSendMailItemButton then return nil, Addon:T("UI.TEXT_0222") end
    for index = #attachments, 1, -1 do
        local success = pcall(ClickSendMailItemButton, attachments[index].slot, true)
        if not success then self:Invalidate(); return nil, Addon:T("UI.TEXT_0330") end
    end
    if #Addon.Compose:GetAttachments() > 0 then self:Invalidate(); return nil, Addon:T("UI.TEXT_0626") end
    if self.owned or #attachments > 0 then
        SendMailSubjectEditBox:SetText("")
        body:SetText("")
    end
    self.owned, self.packet, self.fingerprint = nil, nil, nil
    self.draftFields = nil
    self.scope, self.state = scope, "idle"; self:Scan()
    if #self:ScopeItems() == 0 then self.notice = Addon:T("UI.TEXT_0428"); self:Changed(); return nil, self.notice end
    return self:Fill()
end
function C:Fill(advance)
    local ok, err = self:Guard(); if not ok then return nil, err end
    local body = Addon.Compose:GetBodyEditBox()
    if not SendMailNameEditBox or not SendMailSubjectEditBox or not body then return nil, Addon:T("UI.TEXT_0262") end
    if not self:DraftEmpty() then return nil, Addon:T("UI.TEXT_0523") end
    self:Scan()
    local items = self:ScopeItems()
    if #items == 0 and self.scope and advance then self.scope = nil; items = self:ScopeItems() end
    if #items == 0 then
        self.state = self.match.pending > 0 and "invalid" or "done"
        self.notice = self.match.blockedSender and Addon:T("UI.TEXT_0277") or self.match.pending > 0 and Addon:T("UI.TEXT_0456") or Addon:T("UI.TEXT_0270")
        self:Changed(); return nil, self.notice
    end
    if not ClickSendMailItemButton then return nil, Addon:T("UI.TEXT_0229") end
    local pickup = C_Container and C_Container.PickupContainerItem or PickupContainerItem
    if not pickup then return nil, Addon:T("UI.TEXT_0228") end
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
        if not found then self.state, self.owned, self.packet = "invalid", nil, nil; return nil, Addon:T("UI.TEXT_0492") end
    end
    SendMailNameEditBox:SetText(recipient)
    local distinct = {}
    for _, item in ipairs(packet) do distinct[item.itemID] = true end
    local kinds = 0; for _ in pairs(distinct) do kinds = kinds + 1 end
    SendMailSubjectEditBox:SetText((packet[1].name or Addon:T("UI.TEXT_0457")) .. (kinds > 1 and (Addon:T("UI.TEXT_0474") .. kinds .. Addon:T("UI.TEXT_0044")) or ""))
    body:SetText("")
    self.draftFields = { subject = Text(SendMailSubjectEditBox), body = Text(body) }
    self.fingerprint = self:Fingerprint()
    for index, candidate in ipairs(packet) do
        local success = pcall(function() pickup(candidate.bag, candidate.slot); ClickSendMailItemButton(index) end)
        local actual
        for _, item in ipairs(Addon.Compose:GetAttachments()) do if item.slot == index then actual = item end end
        if not success or (CursorHasItem and CursorHasItem()) or not actual or actual.itemLink ~= candidate.itemLink
            or actual.quantity ~= candidate.quantity then
            if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
            self.state, self.notice = "invalid", Addon:T("UI.TEXT_0225")
            self.fingerprint = self:Fingerprint(); self:Changed(); return nil, self.notice
        end
        self.owned[#self.owned + 1] = actual
        self.fingerprint = self:Fingerprint()
    end
    self.state, self.notice, self.dirty = "ready", Addon:T("UI.TEXT_0545"), nil
    self:Scan()
    self:Changed(); return true
end
function C:Send()
    local ok, err = self:Guard(); if not ok then return nil, err end
    local allowed, reason = Addon.Recipients:CanRuleSend(Text(SendMailNameEditBox))
    if not allowed then self:Invalidate(reason); self:Changed(); return nil, reason end
    if self.state ~= "ready" or self.revision ~= Addon.db.sendRuleRevision or self:Fingerprint() ~= self.fingerprint then
        self:Invalidate(Addon:T("UI.TEXT_0597"))
        self:Changed(); return nil, self.notice
    end
    local button = _G.SendMailMailButton or _G.SendMailSendButton
    local click = button and button:GetScript("OnClick")
    if not click then return nil, Addon:T("UI.TEXT_0173") end
    if SendMailFrame_Update then SendMailFrame_Update() end
    if not button:IsEnabled() then return nil, Addon:T("UI.TEXT_0172") end
    self.state, self.notice, self.startedAt = "sending", Addon:T("UI.TEXT_0421"), GetTime and GetTime() or 0
    self:Changed()
    ok, err = pcall(click, button, "LeftButton")
    if not ok then self.state, self.notice = "invalid", Addon:T("UI.TEXT_0191"); self:Changed(); return nil, tostring(err) end
    return true
end
function C:Primary()
    self:ReconcileDraft()
    if self.state == "ready" then return self:Send() end
    if self.state == "invalid" then
        local ok, err = self:Guard(); if not ok then return nil, err end
        if self.owned or not self:DraftEmpty() then return nil, Addon:T("UI.TEXT_0544") end
        self:Scan(); self.state, self.notice = "idle", Addon:T("UI.TEXT_0258"); self:Changed(); return true
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
    for _, ruleID in ipairs(type(id) == "table" and id or { id }) do self.skipped[ruleID] = not restore or nil end
    self.scope, self.state = nil, "idle"; self:Scan(); self:Changed(); return true
end
function C:QueueScan()
    if self.scanQueued then return end
    self.scanQueued = true
    local function Run()
        self.scanQueued = nil
        if Addon.Scanner:IsOpen() and self.state ~= "sending" and self.state ~= "filling" then
            self:Scan(); self:Changed()
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.1, Run) else Run() end
end

function C:OnEvent(event, itemID)
    if event == "MAIL_CLOSED" then
        self.state, self.skipped, self.scope, self.owned, self.packet, self.fingerprint = "idle", {}, nil, nil, nil, nil
        self.match, self.notice, self.dirty = nil, nil, nil
        self.draftFields = nil
    elseif event == "MAIL_SEND_SUCCESS" and (self.state == "sending" or self.owned) then
        self.state, self.owned, self.fingerprint, self.packet = "idle", nil, nil, nil
        self.draftFields = nil
        self.notice = Addon:T("UI.TEXT_0185"); self:Scan()
    elseif (event == "MAIL_FAILED" or event == "ADDON_ACTION_BLOCKED") and self.state == "sending" then
        self.state, self.notice = "invalid", Addon:T("UI.TEXT_0189")
    elseif event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then
        -- Rule matching is a mailbox operation. Ordinary looting must not scan
        -- every bag and repeatedly copy Core character snapshots in the background.
        if Addon.Scanner:IsOpen() and self.state ~= "sending" and self.state ~= "filling"
            and (event == "BAG_UPDATE_DELAYED" or self.match and self.match.pendingItemIDs and self.match.pendingItemIDs[tonumber(itemID)]) then
            self:QueueScan()
        end
        return
    elseif event == "MAIL_SEND_INFO_UPDATE" then self:ReconcileDraft() end
    self:Changed()
end
function C:Tick()
    if self.state == "sending" and GetTime and GetTime() - (self.startedAt or GetTime()) > 15 then
        self.state, self.notice = "invalid", Addon:T("UI.TEXT_0190")
        self:Changed()
    end
end
function C:ButtonState()
    if self.state == "ready" then return Addon:T("UI.TEXT_0182"), true end
    if self.state == "sending" then return Addon:T("UI.TEXT_0420"), false end
    if self.state == "filling" then return Addon:T("UI.TEXT_0425"), false end
    if self.state == "invalid" then return Addon:T("UI.TEXT_0614"), true end
    local count = #(self.match and self.match.items or {})
    if count == 0 and self.match and self.match.pending > 0 then return Addon:T("UI.TEXT_0614"), true end
    return count > 0 and (self.notice and Addon:T("UI.TEXT_0208") or Addon:T("UI.TEXT_0209")) or Addon:T("UI.TEXT_0248"), count > 0
end
