local Addon = _G.YiboMail
local Model = {}; Addon.CacheModel = Model
local View = Addon.ViewModel
local VALID = { known = true, ["known-empty"] = true, partial = true }
function Model:HasSnapshot(character)
    local snapshot = Addon.db and Addon.db.byCharacter[character.id]
    local coverage = snapshot and snapshot.coverage
    return coverage and VALID[coverage.status] and type(coverage.observedAt) == "number" and type(snapshot.visibleKeys) == "table" or false
end
function Model:Characters(context)
    local result = {}
    for _, character in ipairs(context.characters or {}) do if self:HasSnapshot(character) then result[#result + 1] = character end end
    return result
end
function Model:Risk(mail)
    local expiry = tonumber(mail.expiresAtEstimate)
    if not expiry or expiry <= 0 then return "unknown" end
    local remaining = expiry - Addon:Now()
    return remaining <= 0 and "expired" or (remaining <= 86400 and "urgent" or (remaining <= 259200 and "soon" or "normal"))
end
function Model:Matches(character, mail, query, item)
    if query == "" then return true end
    local parts = { character.name or "", character.realm or "", mail.sender or "", mail.subject or "" }
    if Addon.Core and Addon.Core.Characters.GetDisplayName then parts[#parts + 1] = Addon.Core.Characters:GetDisplayName(character, "short") end
    local items = item and { item } or mail.attachments or {}
    for _, value in ipairs(items) do
        parts[#parts + 1] = value.name or ""; parts[#parts + 1] = tostring(value.itemID or "")
    end
    return string.lower(table.concat(parts, " ")):find(query, 1, true) ~= nil
end
function Model:GetMails(context, options)
    options = options or {}
    local result, order = {}, {}
    local query = string.lower((options.search or ""):match("^%s*(.-)%s*$"))
    for index, character in ipairs(self:Characters(context)) do
        order[character.id] = index
        if query ~= "" or not options.character or options.character == character.id then
            local snapshot, keys, markers = Addon.db.byCharacter[character.id], {}, {}
            if options.scope == "unverified" then
                for key, mail in pairs(snapshot.records or {}) do if mail.state == "unverified" then keys[#keys + 1] = key end end
            else
                for _, key in ipairs(snapshot.visibleKeys) do keys[#keys + 1] = key end
            end
            local state = Addon.Items:GetState(character.id)
            for _, key in ipairs(keys) do
                local mail = snapshot.records[key]
                local hidden = mail and options.scope ~= "unverified" and View:IsCollectedEmptyMail(character.id, mail, markers)
                if mail and not hidden then
                    local kind, risk = options.kind or "all", self:Risk(mail)
                    local kindMatch = kind == "all" or (kind == "items" and #(mail.attachments or {}) > 0)
                        or (kind == "money" and (mail.money or 0) > 0 and (mail.cod or 0) == 0)
                        or (kind == "cod" and (mail.cod or 0) > 0) or (kind == "returned" and (mail.wasReturned or mail.returned))
                        or (kind == "empty" and #(mail.attachments or {}) == 0 and (mail.money or 0) == 0 and (mail.cod or 0) == 0)
                    local wanted = options.risk or "all"
                    local riskMatch = wanted == "all" or wanted == risk
                        or (wanted == "attention" and (risk == "expired" or risk == "urgent" or risk == "soon"))
                        or (wanted == "threeDays" and (risk == "urgent" or risk == "soon"))
                        or (wanted == "sevenDays" and tonumber(mail.expiresAtEstimate) and mail.expiresAtEstimate > Addon:Now() and mail.expiresAtEstimate - Addon:Now() <= 604800)
                    if kindMatch and riskMatch and self:Matches(character, mail, query) then
                        result[#result + 1] = { character = character, key = key, mail = mail, risk = risk,
                            id = Addon.Encode({ character.id, key }), state = state }
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b)
        local ae, be = tonumber(a.mail.expiresAtEstimate), tonumber(b.mail.expiresAtEstimate)
        ae, be = ae and ae > 0 and ae or math.huge, be and be > 0 and be or math.huge
        if options.sort == "expiry" and ae ~= be then return ae < be end
        if a.character.id ~= b.character.id then return order[a.character.id] < order[b.character.id] end
        if a.mail.inboxIndex ~= b.mail.inboxIndex then return (a.mail.inboxIndex or 0) < (b.mail.inboxIndex or 0) end
        return tostring(a.key) < tostring(b.key)
    end)
    return result
end
function Model:GetGroups(entries, sort, search)
    local groups, result = {}, {}
    local query = string.lower((search or ""):match("^%s*(.-)%s*$"))
    for _, entry in ipairs(entries) do
        for _, item in ipairs(entry.mail.attachments or {}) do
            if self:Matches(entry.character, entry.mail, query, item) then
                local id = item.variantKey or item.itemLink or tostring(item.itemID)
                if not groups[id] then
                    groups[id] = { id = id, item = item, quantity = 0, normalQuantity = 0, codQuantity = 0,
                        sources = {}, characters = {}, mails = {}, mailCount = 0, expiresAtEstimate = nil, unknownExpiry = false }
                    result[#result + 1] = groups[id]
                end
                local group, quantity = groups[id], tonumber(item.quantity) or 0
                group.quantity = group.quantity + quantity
                if (entry.mail.cod or 0) > 0 then group.codQuantity = group.codQuantity + quantity
                else group.normalQuantity = group.normalQuantity + quantity end
                group.sources[#group.sources + 1] = { entry = entry, item = item }
                group.characters[entry.character.id] = true
                if not group.mails[entry.id] then group.mails[entry.id] = true; group.mailCount = group.mailCount + 1 end
                local expiry = tonumber(entry.mail.expiresAtEstimate)
                if expiry and expiry > 0 then group.expiresAtEstimate = math.min(group.expiresAtEstimate or math.huge, expiry)
                else group.unknownExpiry = true end
            end
        end
    end
    table.sort(result, function(a, b)
        if sort == "expiry" and a.expiresAtEstimate ~= b.expiresAtEstimate then
            return (a.expiresAtEstimate or math.huge) < (b.expiresAtEstimate or math.huge)
        end
        local an, bn = a.item.name or "", b.item.name or ""
        if an ~= bn then return an < bn end
        return tostring(a.id) < tostring(b.id)
    end)
    return result
end
function Model:Totals(entries)
    local values = { count = #entries, attachmentMails = 0, money = 0, cod = 0, expired = 0, urgent = 0, soon = 0, unknown = 0 }
    for _, entry in ipairs(entries) do
        if #(entry.mail.attachments or {}) > 0 then values.attachmentMails = values.attachmentMails + 1 end
        if (entry.mail.cod or 0) > 0 then values.cod = values.cod + 1 else values.money = values.money + (entry.mail.money or 0) end
        local risk = self:Risk(entry.mail); if values[risk] then values[risk] = values[risk] + 1 end
    end
    return values
end
function Model:MailDetail(entry)
    local mail = entry.mail
    local text = #(mail.attachments or {}) .. " 个附件槽"
    if (mail.money or 0) > 0 and (mail.cod or 0) == 0 then text = text .. " · 待取金币 " .. View:Money(mail.money) end
    if (mail.cod or 0) > 0 then text = text .. " · 付款取信 " .. View:Money(mail.cod) end
    if mail.wasReturned or mail.returned then text = text .. " · 退回邮件" end
    return text .. " · " .. View:Expiry(mail)
end
function Model:Coverage(character)
    local snapshot = Addon.db.byCharacter[character.id]
    local coverage, state = snapshot.coverage, Addon.Items:GetState(character.id)
    local parts = { "上次扫描 " .. (coverage.observedAt and date("%m-%d %H:%M", coverage.observedAt) or "未知") }
    if coverage.status == "partial" then parts[#parts + 1] = "部分 · " .. (coverage.currentCount or 0) .. "/" .. (coverage.totalCount or "?") .. " · 本轮未扫描 " .. (coverage.unscannedCount or 0)
    else parts[#parts + 1] = "完整扫描" end
    if state.status == "error" then parts[#parts + 1] = "本次读取失败"
    elseif state.status == "stale" then parts[#parts + 1] = "历史快照" end
    return table.concat(parts, " · ")
end
