local Addon = _G.YiboMailStage0Probe

local SAFE_INVOICE_TYPES = {
    buyer = true,
    seller = true,
    ["seller_temp_invoice"] = true,
}

local function Token(value)
    if type(value) == "table" then return tostring(value.hash or "nil") end
    return tostring(value)
end

local function Fingerprint(mail)
    if not mail.headerOK then return nil end
    local header = mail.header
    local parts = {
        Token(header.sender), Token(header.subject), Token(header.money),
        Token(header.codAmount), Token(header.wasReturned), Token(header.isGM),
        Token(header.packageIcon), Token(header.attachmentCount),
    }
    local attachments = {}
    for _, attachment in ipairs(mail.attachments) do
        local link = attachment.link or {}
        attachments[#attachments + 1] = table.concat({
            Token(attachment.itemID), Token(attachment.count), Token(link.payloadHash),
        }, ":")
    end
    table.sort(attachments)
    parts[#parts + 1] = table.concat(attachments, ",")
    parts[#parts + 1] = Token(mail.invoice and mail.invoice.invoiceType)
    return table.concat(parts, "|")
end

local function FingerprintCounts(mails)
    local counts = {}
    for _, mail in ipairs(mails or {}) do
        if mail.fingerprint then counts[mail.fingerprint] = (counts[mail.fingerprint] or 0) + 1 end
    end
    return counts
end

local function CompareWithPrevious(payload, previous)
    if not previous or not previous.frameShown or not payload.frameShown then return end
    local before, after = FingerprintCounts(previous.mails), FingerprintCounts(payload.mails)
    local added, missing, duplicateGroups = 0, 0, 0
    for fingerprint, count in pairs(after) do
        added = added + math.max(0, count - (before[fingerprint] or 0))
        if count > 1 then duplicateGroups = duplicateGroups + 1 end
    end
    for fingerprint, count in pairs(before) do missing = missing + math.max(0, count - (after[fingerprint] or 0)) end
    payload.comparison = {
        previousCurrentCount = previous.currentCount,
        previousTotalCount = previous.totalCount,
        addedSignatures = added,
        missingSignatures = missing,
        duplicateGroups = duplicateGroups,
        -- A repeated signature has no server identity; order cannot prove which copy survived.
        identityAmbiguous = duplicateGroups > 0 or (previous.duplicateGroups or 0) > 0,
    }
end

local function CandidateHeaderFields(values)
    return {
        packageIcon = values[1],
        stationeryIcon = values[2],
        sender = Addon:DescribePrivateString(values[3]),
        subject = Addon:DescribePrivateString(values[4]),
        money = values[5],
        codAmount = values[6],
        daysLeft = values[7],
        attachmentCount = values[8],
        wasRead = values[9],
        wasReturned = values[10],
        textCreated = values[11],
        canReply = values[12],
        isGM = values[13],
    }
end

local function CandidateInvoiceFields(values)
    local invoiceType = values[1]
    if type(invoiceType) == "string" and not SAFE_INVOICE_TYPES[invoiceType] then
        invoiceType = Addon:DescribePrivateString(invoiceType)
    end
    return {
        invoiceType = invoiceType,
        itemName = type(values[2]) == "string" and Addon:DescribePrivateString(values[2]) or values[2],
        playerName = type(values[3]) == "string" and Addon:DescribePrivateString(values[3]) or values[3],
        bid = values[4],
        buyout = values[5],
        deposit = values[6],
        consignment = values[7],
    }
end

function Addon:ProbeMail(reason)
    local payload = {
        frameShown = self:IsFrameShown("MailFrame"),
        eventOpen = self.Runtime.mailOpen == true,
        reason = reason or "manual",
        api = {
            getCounts = type(GetInboxNumItems) == "function",
            getHeader = type(GetInboxHeaderInfo) == "function",
            getItem = type(GetInboxItem) == "function",
            getItemLink = type(GetInboxItemLink) == "function",
            getInvoice = type(GetInboxInvoiceInfo) == "function",
        },
        mails = {},
    }
    if not (payload.api.getCounts and payload.api.getHeader) then
        payload.error = "required-mail-api-missing"
        self:AddSample("mail.inbox", payload)
        self:Print("邮箱探针失败：必要 API 不存在。")
        return payload
    end
    local countOK, countResults = self:SafeCall("GetInboxNumItems", GetInboxNumItems)
    if not countOK then
        payload.error = countResults.error
        self:AddSample("mail.inbox", payload)
        self:Print("邮箱探针失败：无法读取邮件数量。")
        return payload
    end
    payload.currentCount = tonumber(countResults[1])
    payload.totalCount = tonumber(countResults[2])
    if not payload.currentCount or not payload.totalCount or payload.currentCount < 0 or
        payload.totalCount < payload.currentCount then
        payload.error = "invalid-mail-counts"
        payload.coverage = "error"
        self:AddSample("mail.inbox", payload)
        self:Print("邮箱探针失败：邮件数量未就绪。")
        return payload
    end
    payload.unscannedCount = math.max(0, payload.totalCount - payload.currentCount)
    payload.coverage = (not payload.frameShown or reason == "mail-closed-residue" or
        reason == "frame-hide-residue") and "unavailable" or
        (not self.MailInboxUpdatedThisOpen and "pending" or
        (payload.unscannedCount > 0 and "partial" or (payload.currentCount == 0 and "known-empty" or "known")))
    local attachmentSlots = tonumber(_G.ATTACHMENTS_MAX_RECEIVE) or 16
    payload.readErrors = 0
    for mailIndex = 1, payload.currentCount do
        local headerOK, headerResults = self:SafeCall("GetInboxHeaderInfo", GetInboxHeaderInfo, mailIndex)
        local mail = { index = mailIndex, headerOK = headerOK, attachments = {} }
        if headerOK then
            mail.headerReturns = self:DescribeReturns(headerResults)
            mail.header = CandidateHeaderFields(headerResults)
        else
            mail.headerError = headerResults.error
            payload.readErrors = payload.readErrors + 1
        end
        if payload.api.getItem and payload.api.getItemLink then
            for attachmentIndex = 1, attachmentSlots do
                local itemOK, itemResults = self:SafeCall("GetInboxItem", GetInboxItem, mailIndex, attachmentIndex)
                local linkOK, linkResults = self:SafeCall("GetInboxItemLink", GetInboxItemLink, mailIndex, attachmentIndex)
                local link = linkOK and linkResults[1] or nil
                local itemID = type(itemResults[2]) == "number" and itemResults[2] or nil
                local count = type(itemResults[4]) == "number" and itemResults[4] or nil
                if not itemOK or not linkOK then payload.readErrors = payload.readErrors + 1 end
                if link or itemID or count then
                    mail.attachments[#mail.attachments + 1] = {
                        index = attachmentIndex,
                        itemID = itemID,
                        count = count,
                        itemReturns = itemOK and self:DescribeReturns(itemResults) or itemResults,
                        link = self:DescribeItemLink(link),
                    }
                end
            end
        end
        if payload.api.getInvoice then
            local invoiceOK, invoiceResults = self:SafeCall("GetInboxInvoiceInfo", GetInboxInvoiceInfo, mailIndex)
            mail.invoiceOK = invoiceOK
            if invoiceOK then
                mail.invoiceReturns = self:DescribeReturns(invoiceResults)
                mail.invoice = CandidateInvoiceFields(invoiceResults)
            else
                mail.invoiceError = invoiceResults.error
            end
        end
        mail.attachmentCount = #mail.attachments
        if mail.header and type(mail.header.attachmentCount) == "number" and
            mail.header.attachmentCount ~= mail.attachmentCount then
            mail.attachmentMismatch = true
            payload.readErrors = payload.readErrors + 1
        end
        mail.fingerprint = Fingerprint(mail)
        payload.mails[#payload.mails + 1] = mail
    end
    local groups = FingerprintCounts(payload.mails)
    payload.duplicateGroups = 0
    for _, count in pairs(groups) do if count > 1 then payload.duplicateGroups = payload.duplicateGroups + 1 end end
    if payload.frameShown and (payload.readErrors > 0 or not payload.api.getItem or not payload.api.getItemLink) then
        payload.coverage = "error"
    end
    if payload.frameShown and (payload.coverage == "known" or payload.coverage == "known-empty" or
        payload.coverage == "partial") then
        CompareWithPrevious(payload, self.LastMailProbe)
        self.LastMailProbe = payload
    end
    self:AddSample("mail.inbox", payload)
    self:Print(string.format("邮箱探针完成：可见 %d / 总数 %d，未扫描 %d，同签名组 %d，状态 %s。",
        payload.currentCount, payload.totalCount, payload.unscannedCount, payload.duplicateGroups, payload.coverage))
    return payload
end

function Addon:SetMailWatch(enabled)
    self.MailWatch = enabled == true
    if not self.MailWatch then self.MailProbeToken = (self.MailProbeToken or 0) + 1 end
    self:Print("邮件变化观察已" .. (self.MailWatch and "开启" or "关闭") .. "。")
    if self.MailWatch and self:IsFrameShown("MailFrame") then self:ScheduleMailProbe("watch-start") end
end

function Addon:ScheduleMailProbe(reason)
    if not self.MailWatch then return end
    self.MailProbeToken = (self.MailProbeToken or 0) + 1
    local token = self.MailProbeToken
    local function Scan()
        if self.MailWatch and token == self.MailProbeToken and self:IsFrameShown("MailFrame") then self:ProbeMail(reason) end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.2, Scan)
        C_Timer.After(60, function()
            if self.MailWatch and token == self.MailProbeToken and self:IsFrameShown("MailFrame") then
                self:ProbeMail("stable-60s")
            end
        end)
    else
        Scan()
    end
end

function Addon:InstallMailOperationObservers()
    if type(hooksecurefunc) ~= "function" then return end
    self.MailOperationObserversInstalled = self.MailOperationObserversInstalled or {}
    local watched = { "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem", "ReturnInboxItem", "DeleteInboxItem" }
    for _, name in ipairs(watched) do
        if not self.MailOperationObserversInstalled[name] and type(_G[name]) == "function" then
            local ok = pcall(hooksecurefunc, name, function(mailIndex, attachmentIndex)
                if not Addon.MailWatch then return end
                local previous = Addon.LastMailProbe
                local priorMail = previous and previous.mails and previous.mails[tonumber(mailIndex)]
                Addon:AddSample("mail.player-action", {
                    api = name, mailIndex = mailIndex, attachmentIndex = attachmentIndex,
                    frameShown = Addon:IsFrameShown("MailFrame"),
                    previousFingerprint = priorMail and priorMail.fingerprint,
                    previousCurrentCount = previous and previous.currentCount,
                    -- This is an observation of a player/UI call, not proof of success.
                    outcome = "pending-update",
                })
                Addon:ScheduleMailProbe("after-" .. name)
            end)
            self.MailOperationObserversInstalled[name] = ok
        end
    end
end

function Addon:InstallMailFrameObserver()
    local frame = _G.MailFrame
    if not frame or self.ObservedMailFrame == frame or type(frame.HookScript) ~= "function" then return end
    frame:HookScript("OnShow", function()
        Addon.Runtime.mailOpen = true
        Addon.MailInboxUpdatedThisOpen = false
        Addon:ScheduleMailProbe("frame-show")
    end)
    frame:HookScript("OnHide", function()
        Addon.Runtime.mailOpen = false
        Addon.MailInboxUpdatedThisOpen = false
        Addon.MailProbeToken = (Addon.MailProbeToken or 0) + 1
        if Addon.MailWatch then Addon:ProbeMail("frame-hide-residue") end
    end)
    self.ObservedMailFrame = frame
end
