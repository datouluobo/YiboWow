local Addon = _G.YiboMail
local History = {}; Addon.HistoryModel = History
local names = { discovered = Addon:T("UI.TEXT_0640"), ["collected-archived"] = Addon:T("UI.TEXT_0220"), ["in-transit"] = Addon:T("UI.TEXT_0305"),
    ["received-confirmed"] = Addon:T("UI.TEXT_0464"), ["return-confirmed"] = Addon:T("UI.TEXT_0468"), unverified = Addon:T("UI.TEXT_0289") }
function History:HasHistory(character)
    local snapshot = Addon.db and Addon.db.byCharacter[character.id]
    if not snapshot then return false end
    if #(snapshot.history or {}) > 0 then return true end
    for _, mail in pairs(snapshot.records or {}) do if mail.state == "unverified" then return true end end
    return false
end
function History:Query(context, options)
    options = options or {}
    local result, query = {}, string.lower((options.search or ""):match("^%s*(.-)%s*$"))
    local now = Addon:Now()
    local since = (tonumber(options.days) or 0) > 0 and now - options.days * 86400 or nil
    for _, character in ipairs(context.characters or {}) do
        local snapshot = Addon.db.byCharacter[character.id]
        if snapshot and (not options.character or options.character == character.id) then
            local records = {}
            for index, record in ipairs(snapshot.history or {}) do records[#records + 1] = { record = record, id = record.eventID or ("legacy:" .. index) } end
            for key, mail in pairs(snapshot.records or {}) do
                if mail.state == "unverified" then
                    records[#records + 1] = { id = "cache:" .. key, record = { state = "unverified", cacheProjection = true,
                        mail = mail, sourceMailKey = key, attachments = mail.attachments, money = mail.money,
                        codAmount = mail.cod, observedAt = mail.stateEnteredAt, timeBasis = "scan-unverified" } }
                end
            end
            local displayName = query ~= "" and Addon.Core.Characters:FormatName(character, { nameMode = "short" }) or nil
            for _, candidate in ipairs(records) do
                local record = candidate.record
                local state = record.transferReview == "legacy-unverified" and "unverified" or record.state
                local mail = record.mail or record
                local stamp = tonumber(record.observedAt)
                local retention = (record.state == "unverified" and Addon.db.settings.unverifiedDays or Addon.db.settings.historyDays) or 90
                local direction = record.recipient and "send" or "inbox"
                local kind = record.state == "discovered" and "discovered" or (record.state == "collected-archived" and "collected" or direction)
                local items = record.item and { record.item } or record.attachments or {}
                local money = tonumber(record.money or record.copper) or 0
                local counterpart = record.recipient or mail.sender or Addon:T("UI.TEXT_0399")
                local subject = record.subject or mail.subject or ""
                local filtered = options.kind and options.kind ~= "all" and options.kind ~= direction and options.kind ~= kind
                local filteredResult = options.result and options.result ~= "all" and options.result ~= state
                -- An unknown legacy timestamp can only appear in the explicit all-time view.
                local validTime = (stamp and now - stamp < retention * 86400 and (not since or stamp >= since)) or (not stamp and not since)
                local match = query == ""
                if not match and not filtered and not filteredResult and validTime then
                    local parts = { character.name or "", character.realm or "", counterpart, subject, displayName or "" }
                    for _, item in ipairs(items) do parts[#parts + 1] = item.name or ""; parts[#parts + 1] = tostring(item.itemID or "") end
                    match = string.lower(table.concat(parts, " ")):find(query, 1, true) ~= nil
                end
                if match and not filtered and not filteredResult and validTime then
                    result[#result + 1] = { id = Addon.Encode({ character.id, candidate.id }),
                        character = character, record = record, mail = mail, time = stamp, kind = kind, direction = direction,
                        counterpart = counterpart, subject = subject, items = items, money = money,
                        event = record.cacheProjection and Addon:T("UI.TEXT_0316") or (names[record.state] or Addon:T("UI.TEXT_0511")), state = state,
                        result = state == "in-transit" and Addon:T("UI.TEXT_0247") or (names[state] or Addon:T("UI.TEXT_0399")),
                        sourceKey = record.sourceMailKey or mail.mailKey }
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.time ~= b.time then return (a.time or 0) > (b.time or 0) end
        return a.id < b.id
    end)
    return result
end
function History:Content(entry, omitItems)
    local parts = {}
    if not omitItems then
        for _, item in ipairs(entry.items) do parts[#parts + 1] = Addon.ViewModel:Escape(item.name or (Addon:T("UI.TEXT_0453") .. tostring(item.itemID))) .. " ×" .. tostring(item.quantity or 0) end
    end
    if entry.money > 0 then
        local cod = entry.record.cod == true or (tonumber(entry.record.cod) or tonumber(entry.record.codAmount) or 0) > 0
        parts[#parts + 1] = (cod and Addon:T("UI.TEXT_0356") or Addon:T("UI.TEXT_0615")) .. Addon.ViewModel:Money(entry.money)
    elseif (tonumber(entry.record.codAmount) or 0) > 0 then
        parts[#parts + 1] = Addon:T("UI.TEXT_0356") .. Addon.ViewModel:Money(entry.record.codAmount)
    end
    -- The result column already explains uncertainty. Keep the full evidence
    -- in the tooltip/details without inflating every attachment row.
    if entry.state == "unverified" and not omitItems then
        parts[#parts + 1] = entry.record.transferReview == "legacy-unverified" and Addon:T("HISTORY.LEGACY_TRANSFER_REVIEW")
            or (entry.record.cacheProjection and Addon:T("UI.TEXT_0387") or Addon:T("UI.TEXT_0145"))
    end
    return #parts > 0 and table.concat(parts, Addon:T("UI.TEXT_0652")) or (omitItems and "" or Addon:T("UI.TEXT_0368"))
end
function History:Outcome(entry)
    if entry.state == "in-transit" then return Addon:T("UI.TEXT_0304") end
    if entry.record.cacheProjection then return Addon:T("HISTORY.NEEDS_REVIEW") end
    return entry.event == entry.result and entry.event or (entry.event .. " · " .. entry.result)
end
