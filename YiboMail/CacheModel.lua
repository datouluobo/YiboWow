local Addon = _G.YiboMail
local Model = {}; Addon.CacheModel = Model
local View = Addon.ViewModel
function Model:GetMails(context, options)
    local result, order = {}, {}
    local query = string.lower(options.search or "")
    for index, character in ipairs(context.characters or {}) do
        order[character.id] = index
        local snapshot = Addon.db.byCharacter[character.id]
        if snapshot and (not options.character or options.character == character.id) then
            local keys = {}
            if options.scope == "unverified" then
                for key, mail in pairs(snapshot.records) do if mail.state == "unverified" then keys[#keys + 1] = key end end
            else
                for _, key in ipairs(snapshot.visibleKeys or {}) do keys[#keys + 1] = key end
            end
            for _, key in ipairs(keys) do
                local mail = snapshot.records[key]
                if mail then
                    local parts = { character.name or "", character.realm or "", mail.sender or "", mail.subject or "" }
                    for _, item in ipairs(mail.attachments or {}) do
                        parts[#parts + 1] = item.name or ""; parts[#parts + 1] = tostring(item.itemID or "")
                    end
                    if query == "" or string.lower(table.concat(parts, " ")):find(query, 1, true) then
                        result[#result + 1] = { character = character, key = key, mail = mail,
                            id = Addon.Encode({character.id, key}), state = Addon.Items:GetState(character.id) }
                    end
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if options.sort == "expiry" and a.mail.expiresAtEstimate ~= b.mail.expiresAtEstimate then
            return (a.mail.expiresAtEstimate or math.huge) < (b.mail.expiresAtEstimate or math.huge)
        end
        if a.character.id ~= b.character.id then return order[a.character.id] < order[b.character.id] end
        if a.mail.inboxIndex ~= b.mail.inboxIndex then return (a.mail.inboxIndex or 0) < (b.mail.inboxIndex or 0) end
        return tostring(a.key) < tostring(b.key)
    end)
    return result
end
function Model:GetGroups(entries, sort, search)
    local groups, result = {}, {}
    for _, entry in ipairs(entries) do
        for _, item in ipairs(entry.mail.attachments or {}) do
            local query = string.lower(search or "")
            local searchable = table.concat({ entry.character.name or "", entry.character.realm or "", entry.mail.sender or "", entry.mail.subject or "", item.name or "", tostring(item.itemID or "") }, " ")
            if query == "" or string.lower(searchable):find(query, 1, true) then
            -- A full variant identity keeps distinct links from sharing quantities.
            local id = item.variantKey or item.itemLink or tostring(item.itemID)
            if not groups[id] then
                groups[id] = { id = id, item = item, quantity = 0, sources = {}, characters = {}, expiresAtEstimate = math.huge }
                result[#result + 1] = groups[id]
            end
            local group = groups[id]
            group.quantity = group.quantity + (item.quantity or 0)
            group.sources[#group.sources + 1] = { entry = entry, item = item }
            group.characters[entry.character.id] = true
            group.expiresAtEstimate = math.min(group.expiresAtEstimate, entry.mail.expiresAtEstimate or math.huge)
            end
        end
    end
    if sort == "expiry" then table.sort(result, function(a, b)
        if a.expiresAtEstimate ~= b.expiresAtEstimate then return a.expiresAtEstimate < b.expiresAtEstimate end
        return tostring(a.id) < tostring(b.id)
    end) end
    return result
end
function Model:MailDetail(entry)
    local mail = entry.mail
    local text = #mail.attachments .. " 个附件槽"
    if (mail.money or 0) > 0 then text = text .. " · 金币 " .. View:Money(mail.money) end
    if (mail.cod or 0) > 0 then text = text .. " · 付款取信 " .. View:Money(mail.cod) end
    if mail.returned then text = text .. " · 退回邮件" end
    return text .. " · " .. View:Expiry(mail)
end
