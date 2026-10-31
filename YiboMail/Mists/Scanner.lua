local Addon = _G.YiboMail
local Scanner = { publishedStatus = {} }; Addon.Scanner = Scanner
function Scanner:ObserveArrivalSignal()
    if type(HasNewMail) ~= "function" or not Addon.db then return end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current then return end
    local ok, value = pcall(HasNewMail)
    if not ok then return end
    local present = value == true or value == 1
    local previous = Addon.db.mailArrivalSignals[current.id]
    if previous and previous.present == present then return end
    Addon.db.mailArrivalSignals[current.id] = { present = present, awaitingScan = present, observedAt = Addon:Now() }
    Addon:UpdateMailNoticeBatch(current.id)
    if present or (previous and previous.awaitingScan) then Addon:Publish(current.id, {}, {}, "scan", true) end
end
function Scanner:IsOpen() return self.open and MailFrame and MailFrame:IsShown() end
function Scanner:RequestInbox()
    if self.open and type(CheckInbox) == "function" then CheckInbox() end
end
function Scanner:PublishStatus(characterID)
    if not characterID or not Addon.db then return end
    local status = Addon.Items:GetState(characterID).status
    local previous = self.publishedStatus[characterID] or (Addon.db.byCharacter[characterID] and "stale" or "not-yet-scanned")
    if previous ~= status then
        self.publishedStatus[characterID] = status
        Addon:Publish(characterID, {}, {}, "scan", true)
    end
end
function Scanner:CancelRead()
    if self.scanJob then self.scanJob.mails, self.scanJob.hints = nil, nil; self.scanJob = nil end
end
function Scanner:Close()
    self:CancelRead()
    if Addon.Queue then Addon.Queue:OnEvent("MAIL_CLOSED") end
    if Addon.Compose then Addon.Compose:OnEvent("MAIL_CLOSED") end
    self.open, self.updated, self.stable, self.validAt, self.lastError, self.refreshPending = false, false, nil, nil, nil, nil
    self.scheduledScan = nil
    self.generation = (self.generation or 0) + 1
    local character = Addon.Core and Addon.Core.Characters:GetCurrent({ identityOnly = true })
    self:PublishStatus(character and character.id)
    if Addon.FEATURES.account and Addon.Core and Addon.Core.AccountView then Addon.Core.AccountView:NotifyPageChanged("mail-inbox") end
    -- Subscribers may query while the stale notification is delivered. Drop
    -- their newly derived index too; later public queries rebuild it on demand.
    Addon.Items:ReleaseCaches(true)
end
function Scanner:InstallHooks()
    if MailFrame and not self.hooked then
        MailFrame:HookScript("OnHide", function() Scanner:Close() end); self.hooked = true
    end
end
local AUCTION_SUBJECT_KEYS = {
    "AUCTION_SOLD_MAIL_SUBJECT", "AUCTION_EXPIRED_MAIL_SUBJECT", "AUCTION_REMOVED_MAIL_SUBJECT",
    "AUCTION_WON_MAIL_SUBJECT", "AUCTION_OUTBID_MAIL_SUBJECT", "AUCTION_INVOICE_MAIL_SUBJECT",
}
function Scanner:IsAuctionMail(index, subject)
    if type(GetInboxInvoiceInfo) == "function" then
        local ok, kind = pcall(GetInboxInvoiceInfo, index)
        if ok and (kind == "seller" or kind == "buyer" or kind == "seller_temp_invoice") then return true end
    end
    -- Expired/cancelled listings need not have an invoice. Use the client's
    -- native localized subject templates, independent of Core's UI language.
    for _, key in ipairs(AUCTION_SUBJECT_KEYS) do
        local template = _G[key]
        if type(template) == "string" and template ~= "" then
            local pattern = template:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                :gsub("%%%%s", ".+")
            if subject:match("^" .. pattern .. "$") then return true end
        end
    end
    return false
end
local function AuctionPlayer(index)
    if type(GetInboxInvoiceInfo) ~= "function" then return nil end
    local ok, kind, _, playerName = pcall(GetInboxInvoiceInfo, index)
    if ok and (kind == "seller" or kind == "seller_temp_invoice") and type(playerName) == "string" and playerName ~= "" then return playerName end
end
local ITEM_FIELDS = { attachmentIndex = true, itemID = true, name = true, texture = true, quantity = true,
    itemLink = true, itemKey = true, variantKey = true, identityQuality = true }
local function ReuseItem(prior, slot, itemID, name, texture, quantity, link, itemKey, variantKey, quality)
    if type(prior) ~= "table" or prior.attachmentIndex ~= slot or prior.itemID ~= itemID or prior.name ~= name
        or prior.texture ~= texture or prior.quantity ~= quantity or prior.itemLink ~= link or prior.itemKey ~= itemKey
        or prior.variantKey ~= variantKey or prior.identityQuality ~= quality then return nil end
    for key in pairs(prior) do if not ITEM_FIELDS[key] then return nil end end
    return prior
end
local function EncodePair(left, right)
    left, right = tostring(left), tostring(right)
    return #left .. ":" .. left .. #right .. ":" .. right
end
local function EnvelopeSignature(mail, attachments)
    if mail.sender == nil or mail.subject == nil or mail.money == nil or mail.cod == nil or mail.wasReturned == nil then
        return Addon.Encode({ mail.sender, mail.subject, mail.money, mail.cod, mail.wasReturned, attachments })
    end
    return EncodePair(mail.sender, mail.subject) .. EncodePair(mail.money, mail.cod) .. EncodePair(mail.wasReturned, attachments)
end
local function ObservationHints(characterID)
    local snapshot = Addon.db and Addon.db.byCharacter[characterID]
    local hints = {}
    for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
        local mail = snapshot.records[key]
        if mail and type(mail.inboxIndex) == "number" then hints[mail.inboxIndex] = mail end
    end
    return hints
end
local function ReadMail(index, now, clock, hint)
    local _, _, sender, subject, money, cod, days, expectedAttachments, wasRead, wasReturned, _, canReply, isGM = GetInboxHeaderInfo(index)
    if (sender ~= nil and type(sender) ~= "string") or type(subject) ~= "string" or type(days) ~= "number" then
        error(string.format("header-unavailable:index=%d:sender=%s:subject=%s:days=%s",
            index, type(sender), type(subject), type(days)))
    end
    -- A missing sender name does not invalidate an otherwise readable letter.
    -- Keep absence as data, rather than persisting a localized display label.
    sender = sender or ""
    local mail = { inboxIndex = index, sender = sender, subject = subject, money = tonumber(money) or 0,
        cod = tonumber(cod) or 0, daysLeftAtScan = days, observedAt = now, clockSource = clock,
        expiresAtEstimate = now + days * 86400, wasRead = not not wasRead, wasReturned = not not wasReturned, attachments = {} }
    mail.mailType = mail.cod > 0 and "cod" or (mail.wasReturned and "returned" or "ordinary")
    -- Return is a destructive operation: require positive sender evidence.
    -- nil/false is never proof of player mail, even when invoice data is late.
    mail.canReply = canReply == true or canReply == 1
    mail.isGM = isGM == true or isGM == 1
    mail.auctionMail = Scanner:IsAuctionMail(index, subject)
    mail.auctionPlayer = AuctionPlayer(index)
    -- Match the native delete/return decision; missing permission is unknown.
    if type(InboxItemCanDelete) == "function" then
        local ok, deletable = pcall(InboxItemCanDelete, index)
        if ok and (deletable == true or deletable == false or deletable == 0 or deletable == 1) then
            mail.canReturn = deletable == false or deletable == 0
        end
    end
    local identities = {}
    local hints = type(hint) == "table" and type(hint.attachments) == "table" and hint.attachments
    local hintIndex = 1
    for slot = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        local name, itemID, texture, quantity = GetInboxItem(index, slot)
        if name or itemID then
            local link = GetInboxItemLink(index, slot)
            itemID = tonumber(itemID) or (link and tonumber(link:match("item:(%d+)")))
            if not itemID or type(quantity) ~= "number" or quantity <= 0 then error("attachment-unavailable") end
            local payload = link and link:match("|H([^|]+)|h")
            local itemKey = "item:" .. itemID
            local variantKey, quality = payload and ("link:" .. payload) or itemKey, payload and "full-link" or "item-id-only"
            local prior = hints and hints[hintIndex]
            while type(prior) == "table" and type(prior.attachmentIndex) == "number" and prior.attachmentIndex < slot do
                hintIndex = hintIndex + 1; prior = hints[hintIndex]
            end
            -- Still read every native value. Reuse only an exactly matching
            -- immutable observation; the hint never proves readiness or success.
            local item = ReuseItem(prior, slot, itemID, name, texture, quantity, link, itemKey, variantKey, quality)
                or { attachmentIndex = slot, itemID = itemID, name = name, texture = texture, quantity = quantity,
                    itemLink = link, itemKey = itemKey, variantKey = variantKey, identityQuality = quality }
            mail.attachments[#mail.attachments + 1] = item
            identities[#identities + 1] = EncodePair(item.variantKey, quantity)
        end
    end
    if expectedAttachments ~= nil and (type(expectedAttachments) ~= "number" or expectedAttachments ~= #mail.attachments) then error("attachments-pending") end
    table.sort(identities)
    mail.signature = EnvelopeSignature(mail, table.concat(identities))
    return mail
end
function Scanner:Signature(mail)
    local identities = {}
    for _, item in ipairs(mail.attachments) do identities[#identities + 1] = EncodePair(item.variantKey, item.quantity) end
    table.sort(identities)
    return EnvelopeSignature(mail, table.concat(identities))
end
function Scanner:ReadVisible()
    if not self:IsOpen() or not self.updated then return nil, Addon:T("UI.TEXT_0526") end
    local now, clock = Addon:Now()
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local hints = ObservationHints(character and character.id)
    local ok, result, visible, total = pcall(function()
        local count, total = GetInboxNumItems(); local mails = {}
        for index = 1, count do mails[index] = ReadMail(index, now, clock, hints[index]) end
        local after, all = GetInboxNumItems()
        if after ~= count or total ~= all then error(Addon:T("UI.TEXT_0606")) end
        return mails, count, total
    end)
    if not ok then return nil, tostring(result) end
    return result, visible, total
end
-- A collection reads only its target. A missing row is a valid observation
-- after automatic removal; unreadable headers/attachments remain errors.
function Scanner:ReadTarget(index, hint)
    if not self:IsOpen() or not self.updated then return nil, nil, nil, "mailbox-unavailable" end
    local now, clock = Addon:Now()
    local ok, mail, visible, total = pcall(function()
        local count, all = GetInboxNumItems()
        if type(count) ~= "number" or type(all) ~= "number" or count < 0 or all < count then error("counts-unavailable") end
        local result = index <= count and ReadMail(index, now, clock, hint) or nil
        local after, afterAll = GetInboxNumItems()
        if after ~= count or afterAll ~= all then error("inbox-changed") end
        return result, count, all
    end)
    if not ok then return nil, nil, nil, tostring(mail) end
    return mail, visible, total
end
function Scanner:BeginCollection()
    self:CancelRead()
    self.refreshPending = self.validAt ~= nil or self.refreshPending
    self.validAt, self.stable, self.scheduledScan = nil, nil, nil
    self.generation = (self.generation or 0) + 1
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    self:PublishStatus(current and current.id)
end
function Scanner:CommitCollection(mails, visible, total, fullRead)
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local snapshot = current and Addon.db.byCharacter[current.id]
    if not snapshot then return end
    self.validAt, self.refreshPending = nil, true
    -- This is an observed action delta, not a fresh full-inbox sample. Keep
    -- the last full scan time and public stale status until final reconciliation.
    local coverage = Addon.Copy(snapshot.coverage)
    if fullRead then coverage.observedAt, coverage.clockSource = Addon:Now() end
    coverage.currentCount, coverage.totalCount, coverage.unscannedCount = visible, total, total - visible
    coverage.status = visible < total and "partial" or (total == 0 and "known-empty" or "known")
    Addon:CommitScan(current, mails, coverage)
    self.publishedStatus[current.id] = "stale"
end
function Scanner:ReadEntry(entry)
    if not self:IsOpen() or not self.updated then return nil, Addon:T("UI.TEXT_0526") end
    local index = entry and entry.mail and tonumber(entry.mail.inboxIndex)
    if not index or index < 1 or index % 1 ~= 0 then return nil, Addon:T("UI.TEXT_0591") end
    local now, clock = Addon:Now()
    local ok, current, count = pcall(function()
        local visible, total = GetInboxNumItems()
        if type(visible) ~= "number" or type(total) ~= "number" or visible < index or total < visible then error(Addon:T("UI.TEXT_0590")) end
        local mail = ReadMail(index, now, clock, entry.mail)
        local afterVisible, afterTotal = GetInboxNumItems()
        if afterVisible ~= visible or afterTotal ~= total then error(Addon:T("UI.TEXT_0606")) end
        return mail, visible
    end)
    if not ok then return nil, tostring(current) end
    if current.signature ~= entry.mail.signature then return nil, Addon:T("UI.TEXT_0594") end
    return current
end
local function CommitScan(character, mails, visible, total, now, clock)
    -- Header days are fractional while observation time is whole seconds.
    -- Reconstructing the same expiry can jitter around adjacent letters and
    -- reorder an untouched list. Retain only a matching envelope's estimate
    -- within the clock rounding tolerance; larger corrections still apply.
    local snapshot = Addon.db.byCharacter[character.id]
    local previous = {}
    for _, key in ipairs(snapshot and snapshot.visibleKeys or {}) do
        local mail = snapshot.records[key]
        if mail then previous[mail.inboxIndex] = mail end
    end
    for _, mail in ipairs(mails) do
        local prior = previous[mail.inboxIndex]
        if prior and prior.signature == mail.signature and type(prior.expiresAtEstimate) == "number"
            and math.abs(prior.expiresAtEstimate - mail.expiresAtEstimate) <= 2 then
            mail.expiresAtEstimate = prior.expiresAtEstimate
        end
    end
    local queueRefreshed
    -- Publication callbacks invalidate consumers, while this scan owns the
    -- native presentation refresh immediately after its complete commit.
    local previousCommit = Scanner.committingObservation
    Scanner.committingObservation = true
    local committed, commitError = pcall(Addon.WithPublicationBatch, Addon, function()
        local signatures = {}; for _, mail in ipairs(mails) do signatures[#signatures + 1] = mail.signature end; table.sort(signatures)
        local fingerprint = Addon.Encode(signatures)
        Scanner.lastError, Scanner.validAt, Scanner.refreshPending = nil, now, nil
        Addon:CommitScan(character, mails, { status = visible < total and "partial" or (total == 0 and "known-empty" or "known"),
            currentCount = visible, totalCount = total, unscannedCount = total - visible, observedAt = now, clockSource = clock })
        if visible == total and total <= 100 then
            local stable = Scanner.stable
            if stable and stable.characterID == character.id and stable.fingerprint == fingerprint and stable.count == total then
                if now - stable.at >= 60 then Addon:CleanupBacklog(character.id) end
            else Scanner.stable = { characterID = character.id, fingerprint = fingerprint, count = total, at = now } end
        else Scanner.stable = nil end
        queueRefreshed = Addon.Queue and Addon.Queue:OnScan(mails, visible, total)
    end)
    Scanner.committingObservation = previousCommit
    if not committed then error(commitError, 0) end
    if Addon.Queue and Addon.Queue.notifyPending then Addon.Queue:Notify() end
    if Addon.NativeUI then
        Addon.NativeUI.deleting = nil
        if not queueRefreshed then Addon.NativeUI:Refresh(true) end
    end
end
local function ScanError(character, err)
    Scanner.stable, Scanner.validAt, Scanner.lastError, Scanner.refreshPending = nil, nil, tostring(err), nil
    local previousCommit = Scanner.committingObservation
    Scanner.committingObservation = true
    local published, publishError = pcall(Scanner.PublishStatus, Scanner, character.id)
    Scanner.committingObservation = previousCommit
    if not published then error(publishError, 0) end
    if Addon.NativeUI then Addon.NativeUI:Refresh(true) end
    if Addon.FEATURES.account then Addon.Core.AccountView:NotifyPageChanged("mail-inbox") end
end
function Scanner:Scan()
    self:CancelRead()
    if not self:IsOpen() or not self.updated then self.stable = nil; return nil, "mailbox-unavailable" end
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true }); if not character then return nil, "character-unavailable" end
    local now, clock = Addon:Now()
    local hints = ObservationHints(character.id)
    local ok, mails, visible, total = pcall(function()
        local count, all = GetInboxNumItems()
        if type(count) ~= "number" or type(all) ~= "number" or count < 0 or all < count then error("counts-unavailable") end
        local result = {}; for index = 1, count do result[index] = ReadMail(index, now, clock, hints[index]) end
        local countAfter, allAfter = GetInboxNumItems()
        if countAfter ~= count or allAfter ~= all then error("inbox-changed") end
        return result, count, all
    end)
    if not ok then
        ScanError(character, mails)
        return nil, self.lastError
    end
    CommitScan(character, mails, visible, total, now, clock)
    return true
end
function Scanner:ScanAsync(generation)
    self:CancelRead()
    if not self:IsOpen() or not self.updated then self.stable = nil; return nil, "mailbox-unavailable" end
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true }); if not character then return nil, "character-unavailable" end
    local now, clock = Addon:Now()
    local ok, count, total = pcall(GetInboxNumItems)
    if not ok or type(count) ~= "number" or type(total) ~= "number" or count < 0 or total < count then
        ScanError(character, ok and "counts-unavailable" or count); return nil, self.lastError
    end
    local job = { mails = {}, hints = ObservationHints(character.id), index = 1 }; self.scanJob = job
    local function ReadChunk()
        if self.scanJob ~= job then return end
        if generation ~= self.generation or not self:IsOpen() then self:CancelRead(); return end
        local mails, index, hints = job.mails, job.index, job.hints
        local last = math.min(count, index + 4)
        local readOK, err = pcall(function()
            for current = index, last do mails[current] = ReadMail(current, now, clock, hints[current]) end
        end)
        if self.scanJob ~= job then return end
        if generation ~= self.generation or not self:IsOpen() then self:CancelRead(); return end
        if not readOK then self:CancelRead(); ScanError(character, err); return end
        job.index = last + 1
        if job.index <= count then C_Timer.After(0, ReadChunk); return end
        self:CancelRead()
        local stableOK, afterCount, afterTotal = pcall(GetInboxNumItems)
        if not stableOK or afterCount ~= count or afterTotal ~= total then ScanError(character, "inbox-changed"); return end
        CommitScan(character, mails, count, total, now, clock)
    end
    ReadChunk()
    return true
end
function Scanner:Schedule(force)
    if not force and Addon.Queue and Addon.Queue:OwnsRefresh() then
        Addon.Queue:ScheduleCheck()
        return
    end
    self:CancelRead()
    -- Retain presentation during a recheck of this open session's last valid
    -- snapshot. Public readiness and all collection checks still become stale.
    self.refreshPending = self.validAt ~= nil or self.refreshPending
    self.validAt = nil
    -- Readiness changed even when the next scan finds identical mail. Publish
    -- invalidation now so CommitScan also publishes the recovery to live data.
    local character = Addon.Core and Addon.Core.Characters:GetCurrent({ identityOnly = true })
    self:PublishStatus(character and character.id)
    self.generation = (self.generation or 0) + 1
    if C_Timer and C_Timer.After then
        -- Coalesce updates into the first scheduled read instead of continually
        -- postponing it. The actual read still uses the newest generation.
        if self.scheduledScan then return end
        local request = {}; self.scheduledScan = request
        local function RunScan(attempt)
            if Scanner.scheduledScan ~= request then return end
            if Scanner.open and not Scanner:IsOpen() and attempt < 10 then
                C_Timer.After(0.1, function() RunScan(attempt + 1) end); return
            end
            Scanner.scheduledScan = nil
            local generation = Scanner.generation
            Scanner:ScanAsync(generation)
            -- An empty cache can precede delivery of NPC/system mail. Header
            -- and attachment data can also arrive after the first inbox event.
            local function RetryPending(remaining)
                if Scanner.generation ~= generation or not Scanner:IsOpen() then return end
                local emptyPending = type(HasNewMail) == "function" and HasNewMail()
                    and GetInboxNumItems() == 0
                if not Scanner.lastError and not emptyPending then return end
                Scanner:RequestInbox()
                if Scanner.generation ~= generation then return end
                Scanner:ScanAsync(generation)
                if remaining > 1 then C_Timer.After(1, function() RetryPending(remaining - 1) end) end
            end
            C_Timer.After(1, function() RetryPending(3) end)
            C_Timer.After(60.1, function() if Scanner.generation == generation then Scanner:ScanAsync(generation) end end)
        end
        C_Timer.After(0.2, function() RunScan(0) end)
    else self:Scan() end
end
function Scanner:OnEvent(event)
    if event == "UPDATE_PENDING_MAIL" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then self:ObserveArrivalSignal() end
    if event == "MAIL_SHOW" then
        self:Close(); self.open = true; self:InstallHooks()
        -- MAIL_INBOX_UPDATE can arrive before this event (or be omitted when
        -- the cached inbox is already populated). Start a delayed first scan
        -- so cached rows do not stay stale and uncollectable after opening.
        self.updated = true
        self:RequestInbox()
        self:Schedule()
    elseif event == "MAIL_CLOSED" then self:Close()
    elseif event == "MAIL_INBOX_UPDATE" then
        if self.open then self.updated = true; self:Schedule() end
    elseif event == "UPDATE_PENDING_MAIL" and self:IsOpen() then
        self:RequestInbox(); self:Schedule()
    elseif event == "ADDON_LOADED" then self:InstallHooks() end
end
