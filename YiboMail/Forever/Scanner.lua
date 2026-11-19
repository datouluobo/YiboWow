local Addon = _G.YiboMail
local Scanner = { publishedStatus = {} }; Addon.Scanner = Scanner
local MAX_PENDING_RETRIES = 4
local AUCTION_SUBJECT_KEYS = {
    "AUCTION_SOLD_MAIL_SUBJECT", "AUCTION_EXPIRED_MAIL_SUBJECT", "AUCTION_REMOVED_MAIL_SUBJECT",
    "AUCTION_WON_MAIL_SUBJECT", "AUCTION_OUTBID_MAIL_SUBJECT", "AUCTION_INVOICE_MAIL_SUBJECT",
}
local function Pack(...) return { n = select("#", ...), ... } end
local function Read(fn, ...)
    if type(fn) ~= "function" then error("mail-api-unavailable") end
    local values = Pack(pcall(fn, ...))
    if not values[1] then error("mail-api-read-failed") end
    for index = 2, values.n do if type(issecretvalue) == "function" and issecretvalue(values[index]) then error("restricted-mail-value") end end
    return unpack(values, 2, values.n)
end
local function Number(value, minimum, maximum, integer)
    if type(value) ~= "number" or value ~= value or value < minimum or value > maximum or (integer and value ~= math.floor(value)) then error("invalid-mail-number") end
    return value
end
local function Header(index, slots)
    local h = Pack(Read(GetInboxHeaderInfo, index))
    if (h[3] ~= nil and type(h[3]) ~= "string") or type(h[4]) ~= "string" then error("mail-header-unavailable") end
    Number(h[5], 0, 9007199254740991, true); Number(h[6], 0, 9007199254740991, true)
    Number(h[7], 0, 3650, false)
    h[8] = h[8] == nil and 0 or Number(h[8], 0, slots, true)
    return h
end
function Scanner:IsOpen()
    return self.inWorld and self.open and (not MailFrame or type(MailFrame.IsShown) ~= "function" or MailFrame:IsShown()
        or (SendMailFrame and SendMailFrame:IsShown()))
end
local function PendingCommand()
    return C_Mail and type(C_Mail.IsCommandPending) == "function" and Read(C_Mail.IsCommandPending) == true
end
local function ReadMail(index, slots, now, clock)
    local h = Header(index, slots)
    local mail = { inboxIndex = index, sender = h[3] or "", subject = h[4], money = h[5], cod = h[6], daysLeftAtScan = h[7],
        expiresAtEstimate = now + h[7] * 86400, wasRead = h[9] == true or h[9] == 1, wasReturned = h[10] == true or h[10] == 1,
        observedAt = now, clockSource = clock, state = "observed", attachments = {} }
    mail.canReply = h[12] == true or h[12] == 1
    mail.replyExplicitlyDisabled = h[12] == false
    mail.isGM = h[13] == true or h[13] == 1
    if type(GetInboxInvoiceInfo) == "function" then
        local kind, _, player = Read(GetInboxInvoiceInfo, index)
        mail.auctionMail = kind == "seller" or kind == "buyer" or kind == "seller_temp_invoice"
        if (kind == "seller" or kind == "seller_temp_invoice") and type(player) == "string" and player ~= "" then
            mail.auctionPlayer = player
        end
    end
    if not mail.auctionMail then
        for _, key in ipairs(AUCTION_SUBJECT_KEYS) do
            if Addon:MatchesMailSubject(mail.subject, _G[key]) then mail.auctionMail = true; break end
        end
    end
    if type(InboxItemCanDelete) == "function" then
        local deletable = Read(InboxItemCanDelete, index)
        if deletable == true or deletable == false or deletable == 0 or deletable == 1 then
            mail.canReturn = deletable == false or deletable == 0
        end
    end
    mail.mailType = mail.cod > 0 and "cod" or (mail.wasReturned and "returned" or "ordinary")
    for slot = 1, slots do
        local name, id, texture, quantity, _, _, currency = Read(GetInboxItem, index, slot)
        local link = Read(GetInboxItemLink, index, slot)
        if name ~= nil or id ~= nil or quantity ~= nil or link ~= nil then
            if currency ~= nil and currency ~= true and currency ~= false and currency ~= 0 and currency ~= 1 then error("invalid-mail-currency-flag") end
            local isCurrency = currency == true or currency == 1
            Number(id, 1, 2147483647, true); Number(quantity, 1, 2147483647, true)
            if (name ~= nil and type(name) ~= "string")
                or (texture ~= nil and type(texture) ~= "number" and type(texture) ~= "string") then error("invalid-mail-item-metadata") end
            if link ~= nil then
                local kind = isCurrency and "currency" or "item"
                if type(link) ~= "string" or tonumber(link:match("|H" .. kind .. ":(%d+)") or link:match("^" .. kind .. ":(%d+)")) ~= id then error("mail-link-mismatch") end
            end
            local payload = link and (link:match("|H([^|]+)|h") or link:match("^(item:.*)$"))
            local itemKey = "item:" .. id
            local item = { attachmentIndex = slot, name = name, texture = texture, quantity = quantity, itemLink = link,
                variantKey = payload and ("link:" .. payload) or itemKey, identityQuality = payload and "full-link" or "item-id-only" }
            if isCurrency then
                item.currencyID, item.variantKey, item.identityQuality = id, "currency:" .. id, "currency-id"
            else item.itemID, item.itemKey = id, itemKey end
            mail.attachments[#mail.attachments + 1] = item
        end
    end
    if #mail.attachments ~= h[8] then error("mail-attachments-incomplete") end
    mail.signature = Scanner:Signature(mail)
    return mail, h
end
local function Stage()
    if PendingCommand() then return nil, "command-pending" end
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not character then return nil, "character-unavailable" end
    local loaded, total = Read(GetInboxNumItems)
    Number(loaded, 0, 1000, true); Number(total, loaded, 100000, true)
    if loaded == 0 and not Scanner.updated then return nil, "inbox-not-ready" end
    local slots = Number(ATTACHMENTS_MAX_RECEIVE, 1, 32, true)
    local now, clock = Addon:Now()
    local mails, headers = {}, {}
    for index = 1, loaded do
        local mail, h = ReadMail(index, slots, now, clock)
        mails[index], headers[index] = mail, h
    end
    local after, all = Read(GetInboxNumItems)
    if after ~= loaded or all ~= total then error("inbox-changed") end
    for index = 1, loaded do
        local h = Header(index, slots)
        for _, field in ipairs({ 3, 4, 5, 6, 8, 9, 10, 12, 13 }) do if h[field] ~= headers[index][field] then error("mail-header-changed") end end
    end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not Scanner:IsOpen() or not current or current.id ~= character.id then return nil, "mail-context-changed" end
    if PendingCommand() then return nil, "command-pending" end
    return { character = character, mails = mails, coverage = { status = loaded < total and "partial" or (loaded == 0 and "known-empty" or "known"),
        currentCount = loaded, totalCount = total, unscannedCount = total - loaded, observedAt = now, clockSource = clock } }
end
function Scanner:Signature(mail)
    local identities = {}
    for _, item in ipairs(mail.attachments) do identities[#identities+1]=Addon.Encode({item.variantKey,item.quantity}) end
    table.sort(identities)
    return Addon.Encode({mail.sender or "",mail.subject,mail.money,mail.cod,mail.wasReturned,table.concat(identities)})
end
function Scanner:ReadVisible()
    if not self:IsOpen() or not self.updated then return nil,"mailbox-unavailable" end
    local ok,result,reason=pcall(Stage)
    if not ok then return nil,tostring(result) end
    if not result then return nil,reason end
    return result.mails,result.coverage.currentCount,result.coverage.totalCount
end
function Scanner:ReadTarget(index)
    if not self:IsOpen() or not self.updated then return nil,nil,nil,"mailbox-unavailable" end
    if type(index)~="number" or index<1 or index%1~=0 or index>100000 then return nil,nil,nil,"invalid-mail-index" end
    local ok,mail,visible,total=pcall(function()
        if PendingCommand() then error("command-pending") end
        local character=Addon.Core.Characters:GetCurrent({identityOnly=true})
        if not character then error("character-unavailable") end
        local count,all=Read(GetInboxNumItems)
        Number(count,0,1000,true); Number(all,count,100000,true)
        local slots=Number(ATTACHMENTS_MAX_RECEIVE,1,32,true)
        local result,header
        if index<=count then
            local now,clock=Addon:Now()
            result,header=ReadMail(index,slots,now,clock)
        end
        local after,afterAll=Read(GetInboxNumItems)
        if after~=count or afterAll~=all then error("inbox-changed") end
        if header then
            local verifiedMail,verified=ReadMail(index,slots,result.observedAt,result.clockSource)
            for _,field in ipairs({3,4,5,6,8,9,10,12,13}) do if verified[field]~=header[field] then error("mail-header-changed") end end
            if verifiedMail.signature~=result.signature then error("mail-contents-changed") end
            for slot,item in ipairs(result.attachments) do
                local actual=verifiedMail.attachments[slot]
                if not actual or actual.attachmentIndex~=item.attachmentIndex or actual.variantKey~=item.variantKey or actual.quantity~=item.quantity then
                    error("mail-attachments-changed")
                end
            end
            local finalCount,finalTotal=Read(GetInboxNumItems)
            if finalCount~=count or finalTotal~=all then error("inbox-changed") end
        end
        local current=Addon.Core.Characters:GetCurrent({identityOnly=true})
        if not self:IsOpen() or not current or current.id~=character.id then error("mail-context-changed") end
        if PendingCommand() then error("command-pending") end
        return result,count,all
    end)
    if not ok then return nil,nil,nil,tostring(mail) end
    return mail,visible,total
end
function Scanner:ReadEntry(entry)
    local character=Addon.Core.Characters:GetCurrent({identityOnly=true})
    if not character or not entry or not entry.character or entry.character.id~=character.id or not entry.mail then
        return nil,"mail-context-changed"
    end
    local mail,_,_,err=self:ReadTarget(entry.mail.inboxIndex)
    if not mail then return nil,err or "mail-no-longer-visible" end
    if mail.signature~=entry.mail.signature then return nil,"mail-changed" end
    return mail
end
function Scanner:Invalidate(errorMessage, pending)
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    self.validAt, self.lastError, self.pending = nil, errorMessage, pending
    if current then Addon:Publish(current.id, {}, {}, "scan", true) end
    Addon.Core.AccountView:NotifyPageChanged("mail-inbox")
end
function Scanner:Scan(manual)
    if not self:IsOpen() then return nil, "mailbox-unavailable" end
    if manual then self.updated = true end
    local ok, result, reason = pcall(Stage)
    if not ok then self:Invalidate(tostring(result)); return nil, "read-failed" end
    if not result then
        if reason ~= "command-pending" or self.pending ~= reason then self:Invalidate(nil, reason) end
        return nil, reason
    end
    self.lastError, self.pending, self.validAt, self.updated = nil, nil, result.coverage.observedAt, true
    local coverage = result.coverage
    self:CommitObservation(result.character, result.mails, coverage.currentCount, coverage.totalCount, coverage.observedAt, coverage.clockSource)
    return true
end
function Scanner:Schedule(retries)
    if retries ~= true and Addon.Queue and Addon.Queue:OwnsRefresh() then
        Addon.Queue:ScheduleCheck()
        return
    end
    retries = type(retries)=="number" and math.max(0,math.min(MAX_PENDING_RETRIES,retries)) or MAX_PENDING_RETRIES
    if self.queued then return end
    self.queued = true
    local token = self.generation
    local function Run()
        if self.generation ~= token then return end
        self.queued = false
        if not self:IsOpen() then
            if self.inWorld and self.open and retries > 0 and C_Timer and C_Timer.After then self:Schedule(retries - 1) end
            return
        end
        local _, reason = self:Scan(false)
        if reason == "command-pending" and retries > 0 and C_Timer and C_Timer.After then
            self:Schedule(retries - 1)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.3, Run) else Run() end
end
function Scanner:CancelRead()
    self.queued=false
    self.generation=(self.generation or 0)+1
end
function Scanner:Close()
    self:CancelRead()
    if Addon.Queue then Addon.Queue:OnEvent("MAIL_CLOSED") end
    if Addon.Compose then Addon.Compose:OnEvent("MAIL_CLOSED") end
    self.open, self.updated = false, false
    self.refreshPending, self.stable, self.scheduledScan = nil, nil, nil
    self:Invalidate()
    Addon.Items:ReleaseCaches(true)
end
function Scanner:InstallHooks()
    -- MAIL_CLOSED owns the session. Some Forever skins hide MailFrame when
    -- switching to the send page, so OnHide cannot close the mailbox here.
    if self.hooked or not MailFrame or not MailFrame.HookScript then return end
    MailFrame:HookScript("OnShow", function() if Scanner.open then Scanner:Schedule() end end)
    self.hooked = true
end
function Scanner:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_PENDING_MAIL" then self:ObserveArrivalSignal() end
    if event == "PLAYER_ENTERING_WORLD" then self:Close(); self.inWorld = true
    elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then self:Close(); self.inWorld = false
    elseif event == "MAIL_SHOW" and self.inWorld then self.open, self.updated = true, false; self:Invalidate(nil, "inbox-not-ready"); self:Schedule(MAX_PENDING_RETRIES)
    elseif event == "MAIL_CLOSED" then self:Close()
    elseif event == "UPDATE_PENDING_MAIL" and self:IsOpen() then self:Schedule()
    elseif event == "MAIL_INBOX_UPDATE" and self.inWorld and self.open then self.updated = true; self:Schedule(MAX_PENDING_RETRIES) end
end
