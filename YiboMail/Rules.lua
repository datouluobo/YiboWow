local Addon = _G.YiboMail
local Rules = { failedItems = {} }; Addon.Rules = Rules
local function Trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
function Rules:NormalizeAddress(value)
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
function Rules:AddressKey(value)
    return string.lower((value or ""):gsub("%s", ""))
end
function Rules:GetRecipients()
    local result, seen = {}, {}
    local current = Addon.Core.Characters:GetCurrent()
    local function Add(address, source, label, manual)
        address = self:NormalizeAddress(address); if not address then return end
        local key = self:AddressKey(address)
        if seen[key] then
            local entry = seen[key]
            if not entry.sources[source] then entry.sources[source] = true; entry.source = entry.source .. " / " .. source end
        else
            local entry = { address = address, name = label or address, source = source, sources = { [source] = true }, manual = manual }
            seen[key] = entry; result[#result + 1] = entry
        end
    end
    for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do
        if not current or character.id ~= current.id then Add(character.name .. "-" .. character.realm, "账号角色") end
    end
    for _, rule in pairs(Addon.db.rules) do Add(rule.recipient, "已有规则") end
    for _, contact in ipairs(Addon.db.contacts) do Add(contact.address, "收藏", contact.label, true) end
    for _, entry in ipairs(result) do entry.label = entry.name .. " · " .. entry.source end
    table.sort(result, function(a, b) return a.address < b.address end)
    return result
end
function Rules:GetItem(id, fallback)
    id = tonumber(id); if not id or id <= 0 or id > 2147483647 or id % 1 ~= 0 then return nil end
    local name, link, texture
    if not self.failedItems[id] then
        local infoName, infoLink, _, _, _, _, _, _, _, infoTexture = GetItemInfo(id)
        name, link, texture = infoName, infoLink, infoTexture
    end
    fallback = fallback or {}
    return { itemID = id, name = name or fallback.name or fallback.itemName or ("物品 " .. id), itemLink = link or fallback.itemLink,
        texture = texture or fallback.texture or (GetItemIcon and GetItemIcon(id)), resolved = name ~= nil or fallback.resolved == true or fallback.itemLink ~= nil or fallback.itemName ~= nil }
end
function Rules:GetKnownItems()
    local items = {}
    local function Add(id, fallback)
        local item = self:GetItem(id, fallback)
        if item and (not items[item.itemID] or item.resolved) then items[item.itemID] = item end
    end
    for _, item in ipairs(Addon.Compose:BagItems()) do Add(item.itemID, item) end
    for _, snapshot in pairs(Addon.db.byCharacter) do
        for _, mail in pairs(snapshot.records or {}) do for _, item in ipairs(mail.attachments or {}) do Add(item.itemID, item) end end
    end
    for id, rule in pairs(Addon.db.rules) do Add(id, rule) end
    return items
end
function Rules:Save(id, recipient, enabled, previousID)
    local item = self:GetItem(id, self:GetKnownItems()[tonumber(id)])
    if not item or not item.resolved then return nil, "请选定物品，等待名称与图标信息加载。" end
    local address, err = self:NormalizeAddress(recipient); if not address then return nil, err end
    if Addon.db.rules[item.itemID] and previousID ~= item.itemID then return nil, "该物品已有规则，请编辑已有规则。" end
    if previousID and previousID ~= item.itemID then Addon.db.rules[previousID] = nil end
    Addon.db.rules[item.itemID] = { recipient = address, enabled = enabled ~= false, itemName = item.name, texture = item.texture }
    return true, item.itemID
end
