local Addon = _G.YiboMail
local View = {}; Addon.ViewModel = View
function View:Escape(value) return tostring(value or ""):gsub("|", "||") end
function View:Money(value) return string.format("%.2f 金", (tonumber(value) or 0) / 10000) end
function View:Expiry(mail)
    local seconds = (mail.expiresAtEstimate or 0) - Addon:Now()
    return seconds <= 0 and "已到估算期限" or (seconds < 86400 and string.format("%.1f 小时", seconds / 3600) or string.format("%.1f 天", seconds / 86400))
end
function View:ActionID(characterID, mailKey, slot) return Addon.Encode({ characterID, mailKey, slot }) end
function View:GetMails(context, options)
    options = options or {}; local result = {}
    local current = Addon.Core.Characters:GetCurrent()
    local query = string.lower(options.search or "")
    for _, character in ipairs(context.characters or {}) do
        local snapshot = Addon.db.byCharacter[character.id]
        if snapshot then
            local signatureCount = {}
            for _, key in ipairs(snapshot.visibleKeys) do
                local mail = snapshot.records[key]; signatureCount[mail.signature] = (signatureCount[mail.signature] or 0) + 1
            end
            local keys = options.history and {} or snapshot.visibleKeys
            if options.history then for key, mail in pairs(snapshot.records) do if mail.state ~= "observed" then keys[#keys + 1] = key end end end
            for _, key in ipairs(keys) do
                local mail = snapshot.records[key]
                local parts = { mail.sender, mail.subject, character.name, tostring(mail.money), mail.mailType }
                for _, item in ipairs(mail.attachments) do parts[#parts + 1] = item.name or ""; parts[#parts + 1] = tostring(item.itemID) end
                local searchable = string.lower(table.concat(parts, " "))
                local match = query == "" or searchable:find(query, 1, true)
                if options.kind and options.kind ~= "all" then
                    match = match and (options.kind == mail.mailType or (options.kind == "money" and mail.money > 0)
                        or (options.kind == "items" and #mail.attachments > 0) or (options.kind == "urgent" and mail.expiresAtEstimate - Addon:Now() < 3 * 86400))
                end
                if match then
                    local live = Addon.Items:GetState(character.id).status
                    result[#result + 1] = { character = character, mail = mail, key = key,
                        actionable = current and current.id == character.id and (live == "known" or live == "partial")
                            and mail.state == "observed" and mail.cod == 0 and signatureCount[mail.signature] == 1,
                        restriction = mail.cod > 0 and "付款取信请使用原生邮箱" or (signatureCount[mail.signature] ~= 1 and "同签名邮件：无法唯一定位" or "打开当前角色邮箱后可收取") }
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if options.history then return a.mail.stateEnteredAt > b.mail.stateEnteredAt end
        if options.sort == "expiry" and a.mail.expiresAtEstimate ~= b.mail.expiresAtEstimate then return a.mail.expiresAtEstimate < b.mail.expiresAtEstimate end
        -- The outer character order is supplied by Core and remains authoritative.
        local order = {}; for i, c in ipairs(context.characters or {}) do order[c.id] = i end
        if a.character.id ~= b.character.id then return order[a.character.id] < order[b.character.id] end
        return a.mail.inboxIndex < b.mail.inboxIndex
    end)
    return result
end
function View:GetGroups(context, options)
    local groups, result = {}, {}
    for _, entry in ipairs(self:GetMails(context, options)) do
        for _, item in ipairs(entry.mail.attachments) do
            local identity = item.variantKey
            if not groups[identity] then
                groups[identity] = { id = identity, item = item, quantity = 0, sources = {}, expiresAtEstimate = entry.mail.expiresAtEstimate }
                result[#result + 1] = groups[identity]
            end
            local group = groups[identity]; group.quantity = group.quantity + item.quantity
            group.expiresAtEstimate = math.min(group.expiresAtEstimate, entry.mail.expiresAtEstimate)
            group.sources[#group.sources + 1] = { entry = entry, item = item }
        end
    end
    if not options or options.sort ~= "inbox" then
        table.sort(result, function(a, b) if a.expiresAtEstimate ~= b.expiresAtEstimate then return a.expiresAtEstimate < b.expiresAtEstimate end; return a.id < b.id end)
    end
    return result
end
function View:GetContacts()
    return Addon.Rules:GetRecipients()
end
function View:SaveContact(address, label, oldAddress)
    if Addon.Rules then
        local normalized, err = Addon.Rules:NormalizeAddress(address)
        if not normalized then return nil, err end
        address = normalized
    end
    address = (address or ""):match("^%s*(.-)%s*$")
    if address == "" or address:find("[|\n\r]") then return nil, "请填写有效的角色名或角色名-服务器。" end
    local key = Addon.Rules:AddressKey(address)
    for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do if Addon.Rules:AddressKey(character.name .. "-" .. character.realm) == key then return nil, "该联系人已在账号角色列表中。" end end
    for _, contact in ipairs(Addon.db.contacts) do
        if contact.address ~= oldAddress and Addon.Rules:AddressKey(Addon.Rules:NormalizeAddress(contact.address) or contact.address) == key then return nil, "联系人已存在。" end
    end
    if oldAddress then for _, contact in ipairs(Addon.db.contacts) do if contact.address == oldAddress then contact.address, contact.label = address, label ~= "" and label or address; return true end end end
    Addon.db.contacts[#Addon.db.contacts + 1] = { address = address, label = label ~= "" and label or address }; return true
end
