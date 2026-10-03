local Addon = _G.YiboStage0Probe

local SAFE_INVOICE_TYPES = {
    buyer = true,
    seller = true,
    ["seller_temp_invoice"] = true,
}

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

function Addon:ProbeMail()
    local payload = {
        frameShown = self:IsFrameShown("MailFrame"),
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
    payload.currentCount = tonumber(countResults[1]) or 0
    payload.totalCount = tonumber(countResults[2]) or payload.currentCount
    payload.unscannedCount = math.max(0, payload.totalCount - payload.currentCount)
    payload.coverage = payload.unscannedCount > 0 and "partial" or (payload.currentCount == 0 and "known-empty" or "known")
    local attachmentSlots = tonumber(_G.ATTACHMENTS_MAX_RECEIVE) or 16
    for mailIndex = 1, payload.currentCount do
        local headerOK, headerResults = self:SafeCall("GetInboxHeaderInfo", GetInboxHeaderInfo, mailIndex)
        local mail = { index = mailIndex, headerOK = headerOK, attachments = {} }
        if headerOK then
            mail.headerReturns = self:DescribeReturns(headerResults)
            mail.header = CandidateHeaderFields(headerResults)
        else
            mail.headerError = headerResults.error
        end
        if payload.api.getItem or payload.api.getItemLink then
            for attachmentIndex = 1, attachmentSlots do
                local itemOK, itemResults = self:SafeCall("GetInboxItem", GetInboxItem, mailIndex, attachmentIndex)
                local linkOK, linkResults = self:SafeCall("GetInboxItemLink", GetInboxItemLink, mailIndex, attachmentIndex)
                local link = linkOK and linkResults[1] or nil
                local itemID = type(itemResults[2]) == "number" and itemResults[2] or nil
                local count = type(itemResults[4]) == "number" and itemResults[4] or nil
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
        payload.mails[#payload.mails + 1] = mail
    end
    self:AddSample("mail.inbox", payload)
    self:Print(string.format("邮箱探针完成：可见 %d / 总数 %d，未扫描 %d。", payload.currentCount, payload.totalCount, payload.unscannedCount))
    return payload
end
