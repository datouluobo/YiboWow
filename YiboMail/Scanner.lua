local Addon = _G.YiboMail
local Scanner = { publishedStatus = {} }; Addon.Scanner = Scanner
function Scanner:IsOpen() return self.open and MailFrame and MailFrame:IsShown() end
function Scanner:PublishStatus(characterID)
    if not characterID or not Addon.db then return end
    local status = Addon.Items:GetState(characterID).status
    local previous = self.publishedStatus[characterID] or (Addon.db.byCharacter[characterID] and "stale" or "not-yet-scanned")
    if previous ~= status then
        self.publishedStatus[characterID] = status
        Addon:Publish(characterID, {}, {}, "scan")
    end
end
function Scanner:Close()
    if Addon.Queue then Addon.Queue:OnEvent("MAIL_CLOSED") end
    if Addon.Compose then Addon.Compose:OnEvent("MAIL_CLOSED") end
    self.open, self.updated, self.stable, self.validAt, self.lastError = false, false, nil, nil, nil
    self.generation = (self.generation or 0) + 1
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    self:PublishStatus(character and character.id)
    if Addon.FEATURES.account and Addon.Core and Addon.Core.AccountView then Addon.Core.AccountView:NotifyPageChanged("mail-inbox") end
end
function Scanner:InstallHooks()
    if MailFrame and not self.hooked then
        MailFrame:HookScript("OnHide", function() Scanner:Close() end); self.hooked = true
    end
end
local function ReadMail(index, now, clock)
    local _, _, sender, subject, money, cod, days, expectedAttachments, wasRead, wasReturned = GetInboxHeaderInfo(index)
    if type(sender) ~= "string" or type(subject) ~= "string" or type(days) ~= "number" then error("header-unavailable") end
    local mail = { inboxIndex = index, sender = sender, subject = subject, money = tonumber(money) or 0,
        cod = tonumber(cod) or 0, daysLeftAtScan = days, observedAt = now, clockSource = clock,
        expiresAtEstimate = now + days * 86400, wasRead = not not wasRead, wasReturned = not not wasReturned, attachments = {} }
    mail.mailType = mail.cod > 0 and "cod" or (mail.wasReturned and "returned" or "ordinary")
    local identities = {}
    for slot = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        local name, itemID, texture, quantity = GetInboxItem(index, slot)
        if name or itemID then
            local link = GetInboxItemLink(index, slot)
            itemID = tonumber(itemID) or (link and tonumber(link:match("item:(%d+)")))
            if not itemID or type(quantity) ~= "number" or quantity <= 0 then error("attachment-unavailable") end
            local payload = link and link:match("|H([^|]+)|h")
            local itemKey = "item:" .. itemID
            local item = { attachmentIndex = slot, itemID = itemID, name = name, texture = texture, quantity = quantity,
                itemLink = link, itemKey = itemKey, variantKey = payload and ("link:" .. payload) or itemKey,
                identityQuality = payload and "full-link" or "item-id-only" }
            mail.attachments[#mail.attachments + 1] = item
            identities[#identities + 1] = Addon.Encode({ item.variantKey, quantity })
        end
    end
    if expectedAttachments ~= nil and (type(expectedAttachments) ~= "number" or expectedAttachments ~= #mail.attachments) then error("attachments-pending") end
    table.sort(identities)
    mail.signature = Addon.Encode({ sender, subject, mail.money, mail.cod, mail.wasReturned, table.concat(identities) })
    return mail
end
function Scanner:Signature(mail)
    local identities = {}
    for _, item in ipairs(mail.attachments) do identities[#identities + 1] = Addon.Encode({ item.variantKey, item.quantity }) end
    table.sort(identities)
    return Addon.Encode({ mail.sender, mail.subject, mail.money, mail.cod, mail.wasReturned, table.concat(identities) })
end
function Scanner:ReadVisible()
    if not self:IsOpen() or not self.updated then return nil, "请先打开邮箱并等待列表更新。" end
    local now, clock = Addon:Now()
    local ok, result = pcall(function()
        local count, total = GetInboxNumItems(); local mails = {}
        for index = 1, count do mails[index] = ReadMail(index, now, clock) end
        local after, all = GetInboxNumItems()
        if after ~= count or total ~= all then error("邮箱正在变化，请稍后重试。") end
        return mails
    end)
    if not ok then return nil, tostring(result) end
    return result
end
function Scanner:Scan()
    if not self:IsOpen() or not self.updated then self.stable = nil; return nil, "mailbox-unavailable" end
    local character = Addon.Core.Characters:GetCurrent(); if not character then return nil, "character-unavailable" end
    local now, clock = Addon:Now()
    local ok, mails, visible, total = pcall(function()
        local count, all = GetInboxNumItems()
        if type(count) ~= "number" or type(all) ~= "number" or count < 0 or all < count then error("counts-unavailable") end
        local result = {}; for index = 1, count do result[index] = ReadMail(index, now, clock) end
        local countAfter, allAfter = GetInboxNumItems()
        if countAfter ~= count or allAfter ~= all then error("inbox-changed") end
        return result, count, all
    end)
    if not ok then
        self.stable, self.validAt, self.lastError = nil, nil, tostring(mails)
        self:PublishStatus(character.id)
        if Addon.NativeUI then Addon.NativeUI:Refresh() end
        if Addon.FEATURES.account then Addon.Core.AccountView:NotifyPageChanged("mail-inbox") end
        return nil, self.lastError
    end
    local signatures = {}; for _, mail in ipairs(mails) do signatures[#signatures + 1] = mail.signature end; table.sort(signatures)
    local fingerprint = Addon.Encode(signatures)
    self.lastError, self.validAt = nil, now
    Addon:CommitScan(character, mails, { status = visible < total and "partial" or (total == 0 and "known-empty" or "known"),
        currentCount = visible, totalCount = total, unscannedCount = total - visible, observedAt = now, clockSource = clock })
    if visible == total and total <= 100 then
        local stable = self.stable
        if stable and stable.characterID == character.id and stable.fingerprint == fingerprint and stable.count == total then
            if now - stable.at >= 60 then Addon:CleanupBacklog(character.id) end
        else
            self.stable = { characterID = character.id, fingerprint = fingerprint, count = total, at = now }
        end
    else self.stable = nil end
    if Addon.Queue then Addon.Queue:OnScan(mails) end
    if Addon.NativeUI then Addon.NativeUI.deleting = nil; Addon.NativeUI:Refresh() end
    return true
end
function Scanner:Schedule()
    self.validAt = nil
    self.generation = (self.generation or 0) + 1
    local generation = self.generation
    if C_Timer and C_Timer.After then
        local function RunScan(attempt)
            if Scanner.generation ~= generation then return end
            if Scanner.open and not Scanner:IsOpen() and attempt < 10 then
                C_Timer.After(0.1, function() RunScan(attempt + 1) end); return
            end
            Scanner:Scan()
            C_Timer.After(60.1, function() if Scanner.generation == generation then Scanner:Scan() end end)
        end
        C_Timer.After(0.2, function() RunScan(0) end)
    else self:Scan() end
end
function Scanner:OnEvent(event)
    if event == "MAIL_SHOW" then self:Close(); self.open = true; self:InstallHooks()
    elseif event == "MAIL_CLOSED" then self:Close()
    elseif event == "MAIL_INBOX_UPDATE" then
        if self.open then self.updated = true; self:Schedule() end
    elseif event == "ADDON_LOADED" then self:InstallHooks() end
end
