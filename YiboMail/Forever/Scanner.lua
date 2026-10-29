local Addon = _G.YiboMail
local Scanner = { publishedStatus = {} }; Addon.Scanner = Scanner
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
    return self.inWorld and self.open and (not MailFrame or type(MailFrame.IsShown) ~= "function" or MailFrame:IsShown())
end
local function PendingCommand()
    return C_Mail and type(C_Mail.IsCommandPending) == "function" and Read(C_Mail.IsCommandPending) == true
end
local function Stage()
    if PendingCommand() then return nil, "command-pending" end
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not character then return nil, "character-unavailable" end
    local loaded, total = Read(GetInboxNumItems)
    Number(loaded, 0, 1000, true); Number(total, loaded, 100000, true)
    if loaded ~= total then return nil, "inbox-incomplete" end
    if loaded == 0 and not Scanner.updated then return nil, "inbox-not-ready" end
    local slots = Number(ATTACHMENTS_MAX_RECEIVE, 1, 32, true)
    local now, clock = Addon:Now()
    local mails, headers = {}, {}
    for index = 1, loaded do
        local h = Header(index, slots); headers[index] = h
        local mail = { inboxIndex = index, sender = h[3], subject = h[4], money = h[5], cod = h[6], daysLeftAtScan = h[7],
            expiresAtEstimate = now + h[7] * 86400, wasRead = h[9] == true or h[9] == 1, wasReturned = h[10] == true or h[10] == 1,
            observedAt = now, clockSource = clock, state = "observed", attachments = {} }
        mail.mailType = mail.cod > 0 and "cod" or (mail.wasReturned and "returned" or "ordinary")
        local identities = {}
        for slot = 1, slots do
            local name, id, texture, quantity, _, _, currency = Read(GetInboxItem, index, slot)
            local link = Read(GetInboxItemLink, index, slot)
            if name ~= nil or id ~= nil or quantity ~= nil or link ~= nil then
                if currency then error("currency-attachment-unsupported") end
                Number(id, 1, 2147483647, true); Number(quantity, 1, 2147483647, true)
                if link ~= nil then
                    if type(link) ~= "string" or tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)")) ~= id then error("mail-link-mismatch") end
                end
                local payload = link and (link:match("|H([^|]+)|h") or link:match("^(item:.*)$"))
                local itemKey = "item:" .. id
                local item = { attachmentIndex = slot, itemID = id, quantity = quantity, itemLink = link, itemKey = itemKey,
                    variantKey = payload and ("link:" .. payload) or itemKey, identityQuality = payload and "full-link" or "item-id-only" }
                mail.attachments[#mail.attachments + 1] = item
                identities[#identities + 1] = Addon.Encode({ item.variantKey, quantity })
            end
        end
        if #mail.attachments ~= h[8] then error("mail-attachments-incomplete") end
        table.sort(identities)
        mail.signature = Addon.Encode({ h[3] or "", h[4], h[5], h[6], mail.wasReturned, table.concat(identities) })
        mails[#mails + 1] = mail
    end
    local after, all = Read(GetInboxNumItems)
    if after ~= loaded or all ~= total then error("inbox-changed") end
    for index = 1, loaded do
        local h = Header(index, slots)
        for _, field in ipairs({ 3, 4, 5, 6, 8, 9, 10 }) do if h[field] ~= headers[index][field] then error("mail-header-changed") end end
    end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not Scanner:IsOpen() or not current or current.id ~= character.id or PendingCommand() then return nil, "mail-context-changed" end
    return { character = character, mails = mails, coverage = { status = loaded == 0 and "known-empty" or "known",
        currentCount = loaded, totalCount = total, unscannedCount = 0, observedAt = now, clockSource = clock } }
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
    if not result then self:Invalidate(nil, reason); return nil, reason end
    self.lastError, self.pending, self.validAt, self.updated = nil, nil, result.coverage.observedAt, true
    Addon:CommitScan(result.character, result.mails, result.coverage)
    return true
end
function Scanner:Schedule()
    if self.queued then return end
    self.queued = true
    local token = self.generation
    local function Run()
        if self.generation ~= token then return end
        self.queued = false
        if self:IsOpen() then self:Scan(false) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.3, Run) else Run() end
end
function Scanner:Close()
    self.open, self.updated, self.queued = false, false, false
    self.generation = (self.generation or 0) + 1
    self:Invalidate()
end
function Scanner:OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" then self:Close(); self.inWorld = true
    elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then self:Close(); self.inWorld = false
    elseif event == "MAIL_SHOW" and self.inWorld then self.open, self.updated = true, false; self:Invalidate(nil, "inbox-not-ready"); self:Schedule()
    elseif event == "MAIL_CLOSED" then self:Close()
    elseif event == "MAIL_INBOX_UPDATE" and self:IsOpen() then self.updated = true; self:Schedule() end
end
