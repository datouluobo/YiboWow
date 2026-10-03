local path = assert(arg and arg[1], "usage: lua AnalyzeSavedVariables.lua <YiboStage0Probe.lua>")
dofile(path)

local db = assert(YiboStage0ProbeDB, "YiboStage0ProbeDB not found")

local function Boolean(value)
    if value == nil then return "nil" end
    return value and "true" or "false"
end

local function CountItems(containers)
    local slots, items = 0, 0
    for _, container in ipairs(containers or {}) do
        slots = slots + (tonumber(container.numSlots) or 0)
        items = items + (tonumber(container.itemCount) or 0)
    end
    return slots, items
end

local function PrintAPI(api)
    local fields = {}
    for key, value in pairs(api or {}) do fields[#fields + 1] = key .. "=" .. Boolean(value) end
    table.sort(fields)
    return table.concat(fields, ",")
end

local function ReturnSignature(description)
    local parts = {}
    for _, entry in ipairs(description and description.values or {}) do
        parts[#parts + 1] = tostring(entry.index) .. ":" .. tostring(entry.type)
    end
    return table.concat(parts, "|")
end

local function Increment(map, key)
    key = key ~= "" and key or "empty"
    map[key] = (map[key] or 0) + 1
end

local function PrintCounts(prefix, map)
    local parts = {}
    for key, count in pairs(map) do parts[#parts + 1] = key .. "=" .. count end
    table.sort(parts)
    if #parts > 0 then print(prefix .. table.concat(parts, ",")) end
end

print("schema=" .. tostring(db.schemaVersion) .. " sessions=" .. tostring(#(db.sessions or {})))
for sessionIndex, session in ipairs(db.sessions or {}) do
    local client = session.client or {}
    print(string.format(
        "SESSION %d addon=%s client=%s build=%s interface=%s samples=%d events=%d logging=%s",
        sessionIndex,
        tostring(session.addonVersion),
        tostring(client.version),
        tostring(client.build),
        tostring(client.interface),
        #(session.samples or {}),
        #(session.events or {}),
        Boolean(session.eventLogging)
    ))
    local eventCounts = {}
    local eventSignatures = {}
    for _, event in ipairs(session.events or {}) do
        eventCounts[event.event] = (eventCounts[event.event] or 0) + 1
        local args = {}
        for index, value in ipairs(event.args or {}) do
            local valueType = type(value)
            args[index] = (valueType == "number" or valueType == "boolean") and (valueType .. ":" .. tostring(value)) or valueType
        end
        Increment(eventSignatures, event.event .. "(" .. table.concat(args, "|") .. ")")
    end
    local eventParts = {}
    for eventName, count in pairs(eventCounts) do eventParts[#eventParts + 1] = eventName .. "=" .. count end
    table.sort(eventParts)
    if #eventParts > 0 then print("  EVENTS " .. table.concat(eventParts, ",")) end
    PrintCounts("  EVENT_SIGNATURES ", eventSignatures)

    for sampleIndex, sample in ipairs(session.samples or {}) do
        local payload = sample.payload or {}
        if sample.kind == "vault.bags" then
            local slots, items = CountItems(payload.containers)
            print(string.format("  SAMPLE %d bags containers=%d slots=%d items=%d api=%s", sampleIndex, #(payload.containers or {}), slots, items, tostring(payload.containers and payload.containers[1] and payload.containers[1].apiFamily)))
        elseif sample.kind == "vault.equipment" then
            print(string.format("  SAMPLE %d equipment api=%s items=%s slots=%s-%s", sampleIndex, Boolean(payload.apiAvailable), tostring(payload.itemCount), tostring(payload.firstSlot), tostring(payload.lastSlot)))
        elseif sample.kind == "vault.bank" then
            local slots, items = CountItems(payload.containers)
            print(string.format(
                "  SAMPLE %d bank eventOpen=%s accessible=%s evidence=%s frame=%s slots=%d items=%d exposure=%s base=%s bankBags=%s",
                sampleIndex, Boolean(payload.eventOpen), Boolean(payload.accessible), tostring(payload.openEvidence),
                Boolean(payload.frameShown), slots, items, tostring(payload.containerExposure),
                tostring(payload.baseContainerSlots), tostring(payload.bankBagSlots)
            ))
        elseif sample.kind == "vault.guild-bank" then
            local items, errors = 0, 0
            for _, tab in ipairs(payload.tabs or {}) do
                items = items + (tab.itemCount or 0)
                if tab.error then errors = errors + 1 end
            end
            print(string.format("  SAMPLE %d guild-bank frame=%s tabs=%s current=%s scanned=%d items=%d errors=%d api=[%s]", sampleIndex, Boolean(payload.frameShown), tostring(payload.tabCount), tostring(payload.currentTab), #(payload.tabs or {}), items, errors, PrintAPI(payload.api)))
        elseif sample.kind == "vault.guild-bank-all" then
            local items, errors, eventResponses, timeoutResponses = 0, 0, 0, 0
            for _, tab in ipairs(payload.tabs or {}) do
                items = items + (tab.itemCount or 0)
                if tab.error or tab.queryError then errors = errors + 1 end
                if tab.response == "event" then eventResponses = eventResponses + 1 end
                if tab.response == "timeout-fallback" then timeoutResponses = timeoutResponses + 1 end
            end
            print(string.format("  SAMPLE %d guild-bank-all open=%s query=%s requested=%s completed=%s items=%d errors=%d eventResponses=%d timeoutResponses=%d reason=%s", sampleIndex, Boolean(payload.eventOpen or payload.frameShown), Boolean(payload.queryAvailable), tostring(payload.requestedTabs), tostring(payload.completedTabs), items, errors, eventResponses, timeoutResponses, tostring(payload.finishReason)))
        elseif sample.kind == "vault.auction" then
            print(string.format("  SAMPLE %d auction frame=%s open=%s modern=%s legacy=%s reason=%s query=%s method=%s sent=%s response=%s items=%s readError=%s queryError=%s", sampleIndex, Boolean(payload.frameShown), Boolean(payload.eventOpen), Boolean(payload.modern), Boolean(payload.legacyAvailable), tostring(payload.reason), Boolean(payload.queryRequested), tostring(payload.queryMethod), Boolean(payload.querySent), tostring(payload.response), tostring(payload.itemCount), tostring(payload.readError), tostring(payload.queryError)))
        elseif sample.kind == "mail.inbox" then
            local attachments, headerErrors, invoiceOK, invoiceErrors = 0, 0, 0, 0
            local headerSignatures, invoiceSignatures, itemSignatures = {}, {}, {}
            for _, mail in ipairs(payload.mails or {}) do
                attachments = attachments + (mail.attachmentCount or 0)
                if mail.headerOK == false then headerErrors = headerErrors + 1 end
                if mail.invoiceOK == true then invoiceOK = invoiceOK + 1 end
                if mail.invoiceOK == false then invoiceErrors = invoiceErrors + 1 end
                Increment(headerSignatures, ReturnSignature(mail.headerReturns))
                Increment(invoiceSignatures, ReturnSignature(mail.invoiceReturns))
                for _, attachment in ipairs(mail.attachments or {}) do Increment(itemSignatures, ReturnSignature(attachment.itemReturns)) end
            end
            print(string.format("  SAMPLE %d mail frame=%s coverage=%s current=%s total=%s unscanned=%s mails=%d attachments=%d headerErrors=%d invoiceOK=%d invoiceErrors=%d api=[%s] error=%s", sampleIndex, Boolean(payload.frameShown), tostring(payload.coverage), tostring(payload.currentCount), tostring(payload.totalCount), tostring(payload.unscannedCount), #(payload.mails or {}), attachments, headerErrors, invoiceOK, invoiceErrors, PrintAPI(payload.api), tostring(payload.error)))
            PrintCounts("    HEADER_SIGNATURES ", headerSignatures)
            PrintCounts("    INVOICE_SIGNATURES ", invoiceSignatures)
            PrintCounts("    ITEM_SIGNATURES ", itemSignatures)
        else
            print(string.format("  SAMPLE %d %s", sampleIndex, tostring(sample.kind)))
        end
    end
end
