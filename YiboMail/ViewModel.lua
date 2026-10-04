local Addon = _G.YiboMail
local View = {}; Addon.ViewModel = View
local MAX_FAVORITE_CONTACTS = 16
local function Trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
local function NormalizeContactAddress(value)
    if Addon.Rules then return Addon.Rules:NormalizeAddress(value) end
    local address = Trim(value)
    if address == "" or address:find("[|\n\r]") then return nil, "请填写有效收件人。" end
    local name, realm = address:match("^([^-]+)%-(.+)$")
    if not name then
        if address:find("-", 1, true) then return nil, "请填写完整的角色名-服务器。" end
        local character = Addon.Core.Characters:GetCurrent()
        name, realm = address, character and character.realm
    end
    name, realm = Trim(name), Trim(realm)
    if name == "" or realm == "" or name:find("%s") then return nil, "当前服务器未知，请填写角色名-服务器。" end
    return name .. "-" .. realm
end
local function ContactAddressKey(value)
    if Addon.Rules then return Addon.Rules:AddressKey(value) end
    return string.lower((tostring(value or "")):gsub("%s", ""))
end
function View:Escape(value) return tostring(value or ""):gsub("|", "||") end
function View:Money(value) return string.format("%.2f 金", (tonumber(value) or 0) / 10000) end
function View:Expiry(mail)
    local seconds = (mail.expiresAtEstimate or 0) - Addon:Now()
    return seconds <= 0 and "已到估算期限" or (seconds < 86400 and string.format("%.1f 小时", seconds / 3600) or string.format("%.1f 天", seconds / 86400))
end
function View:ExpiryColor(mail)
    local seconds = (tonumber(mail and mail.expiresAtEstimate) or 0) - Addon:Now()
    if seconds <= 86400 then return 1, 0.35, 0.35 end
    if seconds <= 3 * 86400 then return 1, 0.82, 0.2 end
    return 0.25, 0.9, 0.35
end
function View:ActionID(characterID, mailKey, slot) return Addon.Encode({ characterID, mailKey, slot }) end
function View:GetMails(context, options)
    options = options or {}; local result = {}
    local current = Addon.Core.Characters:GetCurrent()
    local query = string.lower(options.search or "")
    local liveStates = {}
    for _, character in ipairs(context.characters or {}) do
        local snapshot = Addon.db.byCharacter[character.id]
        if snapshot then
            local collectedMarkers = not options.history and Addon.db.collectedMailMarkers[character.id] or nil
            local usedCollectedMarkers = {}
            local keys = options.history and {} or snapshot.visibleKeys
            if options.history then for key, mail in pairs(snapshot.records) do if mail.state ~= "observed" then keys[#keys + 1] = key end end end
            for _, key in ipairs(keys) do
                local mail = snapshot.records[key]
                local hiddenAsCollected = false
                if mail and collectedMarkers and #mail.attachments == 0 and (tonumber(mail.money) or 0) == 0 and (tonumber(mail.cod) or 0) == 0 then
                    for markerIndex, marker in ipairs(collectedMarkers) do
                        if not usedCollectedMarkers[markerIndex] and marker.signature == mail.signature
                            and math.abs((tonumber(marker.expiresAtEstimate) or 0) - (tonumber(mail.expiresAtEstimate) or 0)) <= 86400 then
                            usedCollectedMarkers[markerIndex] = true; hiddenAsCollected = true; break
                        end
                    end
                end
                if mail and not hiddenAsCollected then
                local parts = { mail.sender, mail.subject, character.name, tostring(mail.money), mail.mailType }
                for _, item in ipairs(mail.attachments) do parts[#parts + 1] = item.name or ""; parts[#parts + 1] = tostring(item.itemID) end
                local searchable = string.lower(table.concat(parts, " "))
                local match = query == "" or searchable:find(query, 1, true)
                if options.kind and options.kind ~= "all" then
                    match = match and (options.kind == mail.mailType or (options.kind == "money" and mail.money > 0)
                        or (options.kind == "items" and #mail.attachments > 0) or (options.kind == "urgent" and mail.expiresAtEstimate - Addon:Now() < 3 * 86400))
                end
                if match then
                    local live = liveStates[character.id]
                    if not live then live = Addon.Items:GetState(character.id); liveStates[character.id] = live end
                    local actionable = current and current.id == character.id and (live.status == "known" or live.status == "partial")
                        and mail.state == "observed" and mail.cod == 0
                    local restriction
                    if mail.cod > 0 then restriction = "付款取信请使用原生邮箱"
                    elseif not current or current.id ~= character.id then restriction = "只能收取当前角色的邮件"
                    elseif mail.state ~= "observed" then restriction = "邮件待核实，暂不加入批量收取"
                    elseif live.status == "error" then restriction = "邮箱扫描失败，请等待重新核对"
                    elseif live.status == "stale" then restriction = "邮箱列表正在核对，请稍后重试"
                    elseif live.status == "not-yet-scanned" then restriction = "邮箱尚未完成扫描，请稍后重试"
                    elseif live.status ~= "known" and live.status ~= "partial" then restriction = "邮箱状态尚未确认，请稍后重试"
                    else restriction = "当前邮件暂不可收取" end
                    result[#result + 1] = { character = character, mail = mail, key = key,
                        actionable = actionable, restriction = restriction }
                end
                end
            end
        end
    end
    local order = {}; for i, c in ipairs(context.characters or {}) do order[c.id] = i end
    table.sort(result, function(a, b)
        if options.history then return a.mail.stateEnteredAt > b.mail.stateEnteredAt end
        if options.sort == "expiry" and a.mail.expiresAtEstimate ~= b.mail.expiresAtEstimate then return a.mail.expiresAtEstimate < b.mail.expiresAtEstimate end
        -- The outer character order is supplied by Core and remains authoritative.
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
    if Addon.Recipients then return Addon.Recipients:SaveContact(address, label, oldAddress) end
    local normalized, err = NormalizeContactAddress(address)
    if not normalized then return nil, err end
    address = normalized
    local key = ContactAddressKey(address)
    for _, contact in ipairs(Addon.db.contacts) do
        local priorAddress = NormalizeContactAddress(contact.address) or contact.address
        if contact.address ~= oldAddress and ContactAddressKey(priorAddress) == key then return nil, "联系人已存在。" end
    end
    if oldAddress then for _, contact in ipairs(Addon.db.contacts) do if contact.address == oldAddress then contact.address, contact.label = address, label ~= "" and label or address; return true end end end
    if #Addon.db.contacts >= MAX_FAVORITE_CONTACTS then return nil, "常用发件人最多保存 16 位；请先在联系人管理中移除一位再添加。" end
    Addon.db.contacts[#Addon.db.contacts + 1] = { address = address, label = label ~= "" and label or address }; return true
end
