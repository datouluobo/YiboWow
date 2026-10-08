local Addon = _G.YiboMail
local Rules = {}; Addon.SendRules = Rules
local classLabels = {
    [0] = "消耗品", [1] = "容器", [2] = "武器", [3] = "宝石", [4] = "护甲",
    [5] = "施法材料", [6] = "弹药", [7] = "交易材料", [8] = "物品强化",
    [9] = "配方", [10] = "货币（作废）", [11] = "箭袋", [12] = "任务",
    [13] = "钥匙", [14] = "永久（作废）", [15] = "其它", [16] = "雕文",
    [17] = "战斗宠物", [18] = "魔兽世界时光徽章", [19] = "专业", [20] = "住宅",
}
local function ClassLabel(id, name)
    if id == 5 or id == 7 then return classLabels[id] end
    if name and name:find("[A-Za-z]") then
        local upper = name:upper()
        if id == 8 and upper:find("GENERIC", 1, true) then return "通用（作废）" end
        if id == 10 and upper:find("MONEY", 1, true) then return "金钱（作废）" end
        return classLabels[id] or name
    end
    return name or classLabels[id] or ("分类 " .. tostring(id))
end
local hiddenClasses = { [6] = true, [10] = true, [11] = true, [14] = true, [18] = true }
local function IsObsolete(name)
    return name and (name:lower():find("obsolete", 1, true) or name:find("作废", 1, true) or name:find("废弃", 1, true))
end
local function ItemInfo(value)
    local get = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    if not get then return nil end
    local name, link, _, _, _, _, _, _, _, icon, _, class, subclass = get(value)
    return name, link, icon, class, subclass
end
function Rules:Initialize()
    local db = Addon.db
    db.sendRules = type(db.sendRules) == "table" and db.sendRules or {}
    db.sendRecipientDisabled = type(db.sendRecipientDisabled) == "table" and db.sendRecipientDisabled or {}
    db.sendBlacklist = type(db.sendBlacklist) == "table" and db.sendBlacklist or {}
    db.sendBlacklist.items = type(db.sendBlacklist.items) == "table" and db.sendBlacklist.items or {}
    db.sendBlacklist.senders = type(db.sendBlacklist.senders) == "table" and db.sendBlacklist.senders or {}
    if db.sendRuleVersion and db.sendRuleVersion ~= 1 and db.sendRuleVersion ~= 2 then self.incompatible = true; return end
    -- Version 2 adds itemIDs; legacy single-item records retain their identity.
    -- Earlier Mail builds reject this version instead of sending only itemID.
    db.sendRuleVersion, db.sendRuleRevision = 2, tonumber(db.sendRuleRevision) or 0
    db.nextSendRuleID = tonumber(db.nextSendRuleID) or 0
    for id in pairs(db.sendRules) do db.nextSendRuleID = math.max(db.nextSendRuleID, tonumber(tostring(id):match("^r(%d+)$")) or 0) end
    -- Preserve the original table for recovery; migrate recognizable item rules once.
    if not db.sendRulesMigrated then
        for id, old in pairs(db.rules or {}) do
            local address = type(old) == "table" and Addon.Recipients:Normalize(old.recipient)
            if tonumber(id) and address then
                db.nextSendRuleID = db.nextSendRuleID + 1
                local key = "r" .. db.nextSendRuleID
                db.sendRules[key] = { id = key, kind = "item", itemID = tonumber(id), recipient = address,
                    enabled = old.enabled ~= false, excluded = {}, characters = {} }
            end
        end
        db.sendRulesMigrated = true
    end
    if not self.blacklistIdentityHooked and Addon.Core.Events then
        self.blacklistIdentityHooked = true
        Addon.Core.Events:Register("CHARACTER_ID_CHANGED", self, function(owner, oldID, newID)
            local senders = Addon.db.sendBlacklist.senders
            if senders[oldID] then senders[newID], senders[oldID] = senders[oldID], nil; owner:Changed(true) end
        end)
    end
end
function Rules:SetBlockedItem(itemID, blocked)
    itemID = tonumber(itemID)
    if not itemID or itemID < 1 or itemID ~= math.floor(itemID) then return nil, "请确认有效物品。" end
    Addon.db.sendBlacklist.items[itemID] = blocked and true or nil
    self:Changed(true); return true
end
function Rules:SetBlockedSender(characterID, blocked)
    local senders = Addon.db.sendBlacklist.senders
    if not blocked then senders[characterID] = nil; self:Changed(true); return true end
    local characters = Addon.Core.Characters:GetAllCached()
    local current = Addon.Core.Characters:GetCurrent()
    local character = current and current.id == characterID and current
    for _, entry in ipairs(characters) do if entry.id == characterID then character = entry; break end end
    if not character then return nil, "请先登录该角色，建立账号角色记录。" end
    senders[characterID] = character.name .. "-" .. character.realm
    self:Changed(true); return true
end
function Rules:Changed(rematch)
    Addon.db.sendRuleRevision = Addon.db.sendRuleRevision + 1
    if Addon.RuleSendController then Addon.RuleSendController:Invalidate("规则已修改，请重新匹配。") end
    if rematch and Addon.RuleSendController and Addon.RuleSendController.state ~= "sending" and Addon.RuleSendController.state ~= "filling" then
        Addon.RuleSendController:Scan()
    end
    if Addon.RuleSendUI then Addon.RuleSendUI:Refresh() end
end
function Rules:GetItem(id)
    id = tonumber(id)
    if not id or id <= 0 or id % 1 ~= 0 then return end
    local name, link, icon, class, subclass = ItemInfo(id)
    return { itemID = id, name = name or ("物品 " .. id), link = link, icon = icon,
        classID = class, subclassID = subclass, ready = name ~= nil }
end
function Rules:Categories(classID)
    -- Prefer the current API, but retry the legacy entry point when a client
    -- exposes both and one returns no usable name (or throws).
    local function Name(modern, legacy, ...)
        for index = 1, 2 do
            local get
            if index == 1 then get = modern else get = legacy end
            if type(get) == "function" then
                local ok, name = pcall(get, ...)
                if ok and type(name) == "string" and name ~= "" then return name end
            end
        end
    end
    local result = {}
    if classID == nil then
        for id = 0, 20 do
            local name = Name(C_Item and C_Item.GetItemClassInfo, GetItemClassInfo, id)
            if name and not hiddenClasses[id] and not IsObsolete(name) then
                -- The localized Reagent label can read simply “材料”, which
                -- is easily mistaken for Tradegoods. Keep their IDs distinct.
                local label = ClassLabel(id, name)
                result[#result + 1] = { value = id, label = label }
            end
        end
    else
        result[1] = { value = -1, label = "全部子分类" }
        for id = 0, 30 do
            local name = Name(C_Item and C_Item.GetItemSubClassInfo, GetItemSubClassInfo, classID, id)
            if name and not IsObsolete(name) then result[#result + 1] = { value = id, label = name } end
        end
    end
    return result
end
function Rules:Label(rule)
    if rule.kind == "item" then
        local names = {}
        for _, id in ipairs(self:ItemIDs(rule)) do names[#names + 1] = (self:GetItem(id) or {}).name or ("物品 " .. id) end
        return #names > 0 and table.concat(names, "、") or "无效物品"
    end
    local label = ClassLabel(rule.classID)
    for _, entry in ipairs(self:Categories()) do if entry.value == rule.classID then label = entry.label end end
    if rule.subclassID ~= nil then
        for _, entry in ipairs(self:Categories(rule.classID)) do
            if entry.value == rule.subclassID then label = label .. " / " .. entry.label end
        end
    end
    return label
end
function Rules:ItemIDs(rule)
    if type(rule.itemIDs) == "table" then return rule.itemIDs end
    return rule.itemID and { rule.itemID } or {}
end
function Rules:HasItem(rule, itemID)
    for _, id in ipairs(self:ItemIDs(rule)) do if id == itemID then return true end end
    return false
end
function Rules:List()
    local result = {}
    if self.incompatible then return result end
    for id, rule in pairs(Addon.db.sendRules) do
        if type(rule) == "table" then rule.id = id; result[#result + 1] = rule end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end
function Rules:RecipientsOverlap(first, second)
    local a, _, _, firstRealm = Addon.Recipients:Normalize(first)
    local b, _, _, secondRealm = Addon.Recipients:Normalize(second)
    if a and b and Addon.Recipients:Key(firstRealm) ~= Addon.Recipients:Key(secondRealm) then return false end
    local firstFaction, secondFaction = Addon.Recipients:GetFaction(first), Addon.Recipients:GetFaction(second)
    -- Unknown factions reserve ownership until confirmed; never guess separation.
    return not (firstFaction and secondFaction and firstFaction ~= secondFaction)
end
function Rules:Save(draft, id)
    if self.incompatible then return nil, "规则数据版本不兼容，请同步插件版本。" end
    local rule = Addon.Copy(draft)
    local address, err = Addon.Recipients:Normalize(rule.recipient)
    if not address then return nil, err end
    rule.recipient, rule.excluded, rule.characters = address, rule.excluded or {}, nil
    if rule.kind == "item" then
        local ids, seen = {}, {}
        for _, id in ipairs(self:ItemIDs(rule)) do
            local item = self:GetItem(id)
            if not item or not item.ready then return nil, "请确认所有物品，等待信息加载完成。" end
            if not seen[item.itemID] then seen[item.itemID] = true; ids[#ids + 1] = item.itemID end
        end
        if #ids == 0 then return nil, "请先确认物品。" end
        rule.itemIDs, rule.itemID = ids, ids[1]
    elseif rule.kind == "category" then
        local valid
        for _, entry in ipairs(self:Categories()) do if entry.value == rule.classID then valid = true end end
        if not valid then return nil, "请选择客户端支持的游戏分类。" end
        if rule.subclassID ~= nil then
            valid = false
            for _, entry in ipairs(self:Categories(rule.classID)) do if entry.value == rule.subclassID then valid = true end end
            if not valid then return nil, "请选择有效子分类。" end
        end
    else return nil, "请选择规则类型。" end
    -- Matching objects must be unambiguous within one realm and faction.
    for _, other in ipairs(self:List()) do
        local overlap = false
        if rule.kind == "item" and other.kind == "item" then
            for _, itemID in ipairs(self:ItemIDs(rule)) do if self:HasItem(other, itemID) then overlap = true; break end end
        end
        local same = rule.kind == other.kind and (overlap
            or rule.kind == "category" and rule.classID == other.classID and rule.subclassID == other.subclassID)
        if other.id ~= id and same and self:RecipientsOverlap(address, other.recipient) then
            if Addon.Recipients:Key(other.recipient) == Addon.Recipients:Key(address) then
                return nil, "该规则已存在，无需重复添加；请编辑已有规则以调整物品。", other.id
            end
            return nil, "该匹配对象已有发往其它收件人的规则，请编辑已有规则以变更收件人。", other.id
        end
    end
    if id and not Addon.db.sendRules[id] then return nil, "原规则已不存在，请重新选择。" end
    if not id then Addon.db.nextSendRuleID = Addon.db.nextSendRuleID + 1; id = "r" .. Addon.db.nextSendRuleID end
    rule.id, rule.enabled = id, rule.enabled ~= false
    Addon.db.sendRules[id] = rule; self:Changed(); return true, id
end
function Rules:SetEnabled(id, enabled)
    local rule = Addon.db.sendRules[id]; if not rule then return end
    rule.enabled = enabled; self:Changed()
end
function Rules:IsRecipientEnabled(address)
    return not (Addon.db.sendRecipientDisabled or {})[Addon.Recipients:Key(address)]
end
function Rules:SetRecipientEnabled(address, enabled)
    local normalized = Addon.Recipients:Normalize(address)
    if not normalized then return nil, "无效收件人。" end
    Addon.db.sendRecipientDisabled = Addon.db.sendRecipientDisabled or {}
    Addon.db.sendRecipientDisabled[Addon.Recipients:Key(normalized)] = not enabled or nil
    self:Changed(); return true
end
function Rules:Icon(rule)
    if rule.kind == "item" then return (self:GetItem(rule.itemID) or {}).icon or "Interface\\Icons\\INV_Misc_QuestionMark" end
    local icons = { [0] = "INV_Potion_51", [2] = "INV_Sword_04", [4] = "INV_Chest_Cloth_17",
        [7] = "INV_Ingot_02", [9] = "INV_Scroll_03", [15] = "INV_Misc_Bag_10" }
    local icon = rule.classID == 7 and rule.subclassID == 9 and "INV_Misc_Herb_01" or icons[rule.classID] or "INV_Misc_QuestionMark"
    return "Interface\\Icons\\" .. icon
end
function Rules:Delete(id)
    if not Addon.db.sendRules[id] then return nil, "规则已不存在。" end
    Addon.db.sendRules[id] = nil; self:Changed(); return true
end
function Rules:Match(bags, skipped)
    local current = Addon.Core.Characters:GetCurrent()
    local currentAddress = current and Addon.Recipients:Normalize(current.name .. "-" .. current.realm)
    local active, result = {}, { items = {}, conflicts = {}, pending = 0, groups = {}, byRule = {}, factionIssues = {} }
    if self.incompatible then
        result.pending = 1; result.unavailable = "规则数据版本不兼容，请同步插件版本。"; return result
    end
    local blacklist = Addon.db.sendBlacklist
    if current and blacklist.senders[current.id] then result.blockedSender = true; return result end
    local allowedBags = {}
    for _, item in ipairs(bags) do
        if not blacklist.items[item.itemID] then allowedBags[#allowedBags + 1] = item end
    end
    for _, rule in ipairs(self:List()) do
        local address = Addon.Recipients:Normalize(rule.recipient)
        if rule.enabled ~= false and self:IsRecipientEnabled(rule.recipient) and current then
            if address and Addon.Recipients:Key(address) ~= Addon.Recipients:Key(currentAddress or "") then
                local allowed, reason = Addon.Recipients:CanRuleSend(address, current)
                if allowed then active[#active + 1] = { rule = rule, address = address }
                elseif allowed == nil then active[#active + 1] = { rule = rule, address = address, factionReason = reason } end
            elseif not address then result.conflicts[#result.conflicts + 1] = { ruleIDs = { rule.id }, label = self:Label(rule) .. "：收件人无效" } end
        end
    end
    for _, bagItem in ipairs(allowedBags) do
        local item = Addon.Copy(bagItem)
        local name, link, icon, class, subclass = ItemInfo(item.itemLink or item.itemID)
        item.name, item.texture, item.classID, item.subclassID = name or item.name, icon or item.texture, class, subclass
        local best, candidates, excluded = -1, {}, false
        for _, entry in ipairs(active) do
            local rule, rank = entry.rule
            if rule.kind == "item" and self:HasItem(rule, item.itemID) then rank = 3
            elseif rule.kind == "category" and class ~= nil and rule.classID == class
                and (rule.subclassID == nil or rule.subclassID == subclass) then rank = rule.subclassID ~= nil and 2 or 1 end
            if rank then
                if rank > best then best, candidates, excluded = rank, {}, false end
                if rank == best then
                    candidates[#candidates + 1] = entry
                    if rule.kind == "category" and (rule.excluded or {})[item.itemID] then excluded = true end
                end
            end
        end
        if class == nil and #active > 0 then
            local needsCategory = false
            for _, entry in ipairs(active) do if entry.rule.kind == "category" then needsCategory = true end end
            if needsCategory and best < 3 then result.pending = result.pending + 1 end
            if needsCategory then
                result.pendingItemIDs = result.pendingItemIDs or {}
                result.pendingItemIDs[item.itemID] = true
            end
        end
        if #candidates > 0 and not excluded then
            local unresolved = false
            for _, entry in ipairs(candidates) do
                if entry.factionReason then
                    unresolved = true
                    result.factionIssueKeys = result.factionIssueKeys or {}
                    if not result.factionIssueKeys[entry.rule.id] then
                        result.factionIssueKeys[entry.rule.id] = true
                        result.factionIssues[#result.factionIssues + 1] = { rule = entry.rule, reason = entry.factionReason }
                    end
                end
            end
            if not unresolved then
            local target, ids, conflict = candidates[1].address, {}, false
            for _, entry in ipairs(candidates) do
                ids[#ids + 1] = entry.rule.id
                if Addon.Recipients:Key(entry.address) ~= Addon.Recipients:Key(target) then conflict = true end
            end
            if conflict then result.conflicts[#result.conflicts + 1] = { itemID = item.itemID, ruleIDs = ids,
                label = (name or ("物品 " .. item.itemID)) .. "：收件人冲突", quantity = item.quantity }
            else
                -- Keep ownership stable even when that rule is temporarily skipped.
                item.ruleID, item.ruleIDs, item.recipient = ids[1], ids, target
                if not (skipped or {})[item.ruleID] then
                    result.items[#result.items + 1] = item
                    local key = Addon.Recipients:Key(target)
                    local group = result.groups[key] or { recipient = target, quantity = 0, stacks = 0 }
                    result.groups[key] = group; group.quantity = group.quantity + item.quantity; group.stacks = group.stacks + 1
                    local row = result.byRule[item.ruleID] or { rule = candidates[1].rule, quantity = 0, stacks = 0 }
                    result.byRule[item.ruleID] = row; row.quantity = row.quantity + item.quantity; row.stacks = row.stacks + 1
                end
            end
            end
        end
    end
    table.sort(result.items, function(a, b)
        if a.recipient ~= b.recipient then return a.recipient < b.recipient end
        if a.ruleID ~= b.ruleID then return a.ruleID < b.ruleID end
        if a.itemID ~= b.itemID then return a.itemID < b.itemID end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return result
end
