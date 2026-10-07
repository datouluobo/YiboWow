local Addon = _G.YiboMail
local History = {}; Addon.HistoryModel = History
local names = { discovered = "首次发现", ["collected-archived"] = "实际收取", ["in-transit"] = "成功发送",
    ["received-confirmed"] = "确认收到", ["return-confirmed"] = "确认退回", unverified = "待核实" }
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
    local since = (tonumber(options.days) or 0) > 0 and Addon:Now() - options.days * 86400 or nil
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
            for _, candidate in ipairs(records) do
                local record = candidate.record
                local mail = record.mail or record
                local stamp = tonumber(record.observedAt)
                local retention = (record.state == "unverified" and Addon.db.settings.unverifiedDays or Addon.db.settings.historyDays) or 90
                local direction = record.recipient and "send" or "inbox"
                local kind = record.state == "discovered" and "discovered" or (record.state == "collected-archived" and "collected" or direction)
                local items = record.item and { record.item } or record.attachments or {}
                local money = tonumber(record.money or record.copper) or 0
                local counterpart = record.recipient or mail.sender or "未知"
                local subject = record.subject or mail.subject or ""
                local parts = { character.name or "", character.realm or "", counterpart, subject }
                if Addon.Core.Characters.GetDisplayName then parts[#parts + 1] = Addon.Core.Characters:GetDisplayName(character, "short") end
                for _, item in ipairs(items) do parts[#parts + 1] = item.name or ""; parts[#parts + 1] = tostring(item.itemID or "") end
                local match = query == "" or string.lower(table.concat(parts, " ")):find(query, 1, true)
                local filtered = options.kind and options.kind ~= "all" and options.kind ~= direction and options.kind ~= kind
                local filteredResult = options.result and options.result ~= "all" and options.result ~= record.state
                -- An unknown legacy timestamp can only appear in the explicit all-time view.
                local validTime = (stamp and Addon:Now() - stamp < retention * 86400 and (not since or stamp >= since)) or (not stamp and not since)
                if match and not filtered and not filteredResult and validTime then
                    result[#result + 1] = { id = Addon.Encode({ character.id, candidate.id }),
                        character = character, record = record, mail = mail, time = stamp, kind = kind, direction = direction,
                        counterpart = counterpart, subject = subject, items = items, money = money,
                        event = record.cacheProjection and "扫描待核实" or (names[record.state] or "记录"), state = record.state,
                        result = record.state == "in-transit" and "已发送 · 在途" or (names[record.state] or "未知"),
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
function History:Content(entry)
    local parts = {}
    for _, item in ipairs(entry.items) do parts[#parts + 1] = Addon.ViewModel:Escape(item.name or ("物品 " .. tostring(item.itemID))) .. " ×" .. tostring(item.quantity or 0) end
    if entry.money > 0 then
        local cod = entry.record.cod == true or (tonumber(entry.record.cod) or tonumber(entry.record.codAmount) or 0) > 0
        parts[#parts + 1] = (cod and "整封COD " or "金币 ") .. Addon.ViewModel:Money(entry.money)
    elseif (tonumber(entry.record.codAmount) or 0) > 0 then
        parts[#parts + 1] = "整封COD " .. Addon.ViewModel:Money(entry.record.codAmount)
    end
    if entry.state == "unverified" then parts[#parts + 1] = entry.record.cacheProjection and "曾扫描内容，当前去向待核实" or "内容为操作记录，结果待核实" end
    return #parts > 0 and table.concat(parts, "，") or "无物品或金币"
end
function History:Outcome(entry)
    if entry.state == "in-transit" then return "成功发送 · 在途" end
    return entry.event == entry.result and entry.event or (entry.event .. " · " .. entry.result)
end
