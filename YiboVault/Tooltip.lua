local Addon = _G.YiboVault
local Tooltip = {}
Addon.Tooltip = Tooltip

local SOURCE_LABELS = { bags = "背包", equipment = "装备", bank = "银行", ["guild-bank"] = "公会银行", auction = "AH 上架", mail = "邮件" }
local SOURCE_ORDER = { "bags", "equipment", "bank", "auction", "mail" }

local function ItemID(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
end

local function OwnerName(character)
    return tostring(character.name or character.id or "角色")
end

local function SourceText(counts)
    local parts = {}
    for _, source in ipairs(SOURCE_ORDER) do
        if counts[source] and counts[source] > 0 then
            parts[#parts + 1] = SOURCE_LABELS[source] .. " " .. counts[source]
        end
    end
    return table.concat(parts, "  ·  ")
end

local function CachedQuery(self, scope, itemID)
    local revision = Addon.Items.GetRevision and Addon.Items:GetRevision() or 0
    local scopeKey = tostring(scope and scope.mode or "current") .. ":"
        .. table.concat(scope and scope.characterIDs or {}, "\001")
    if self.cacheRevision ~= revision or self.cacheScope ~= scopeKey then
        self.cacheRevision, self.cacheScope = revision, scopeKey
        self.cacheResults, self.cacheOrder = {}, {}
    end
    local cached = self.cacheResults[itemID]
    if cached then return cached end
    local result = Addon.Items:Query({ scope = scope, itemID = itemID })
    if #self.cacheOrder >= 64 then
        self.cacheResults[table.remove(self.cacheOrder, 1)] = nil
    end
    self.cacheOrder[#self.cacheOrder + 1] = itemID
    self.cacheResults[itemID] = result
    return result
end

function Tooltip:Append(tooltip, knownItemID)
    if not tooltip then return end
    local itemID = tonumber(knownItemID)
    if not itemID and type(tooltip.GetItem) == "function" then
        local _, link = tooltip:GetItem()
        itemID = ItemID(link)
    end
    if not itemID then return end
    if tooltip._yiboVaultAppliedItemID == itemID then return end
    local scope, characters = Addon.AccountPage:GetScope()
    tooltip._yiboVaultAppliedItemID = itemID
    local result = CachedQuery(self, scope, itemID)
    if #result.records == 0 then return end

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("|cff20e070[Yibo]|r 账号库存", tostring(result.totals.totalQuantity), 0.90, 0.96, 0.97, 0.125, 0.88, 0.44)
    if result.totals.listedQuantity > 0 or result.totals.externalQuantity > 0 then
        local subtotal = "实体 " .. result.totals.physicalQuantity
        if result.totals.listedQuantity > 0 then subtotal = subtotal .. "  ·  AH " .. result.totals.listedQuantity end
        if result.totals.externalQuantity > 0 then subtotal = subtotal .. "  ·  邮件 " .. result.totals.externalQuantity end
        tooltip:AddLine(subtotal, 0.53, 0.70, 0.73)
    end
    for _, state in pairs(result.coverage and result.coverage.mail or {}) do
        local inbox = state and state.locations and state.locations.inbox
        if inbox and (inbox.unscannedCount or 0) > 0 then
            tooltip:AddLine(inbox.status == "stale" and "邮箱上次仅部分可见" or "邮箱仅统计当前可见邮件", 0.53, 0.70, 0.73)
            break
        end
    end

    local byCharacter, guilds = {}, {}
    local current = Addon.Core and Addon.Core.Characters:GetCurrent()
    local minPrice, maxPrice
    for _, record in ipairs(result.records) do
        if record.source == "auction" and type(record.unitPrice) == "number" and record.unitPrice > 0 then
            minPrice = math.min(minPrice or record.unitPrice, record.unitPrice)
            maxPrice = math.max(maxPrice or record.unitPrice, record.unitPrice)
        end
        if record.source == "guild-bank" then
            local key = record.guildKey or "guild"
            local entry = guilds[key]
            if not entry then
                entry = { name = record.guildName or "公会", quantity = 0 }
                guilds[key] = entry
            end
            entry.quantity = entry.quantity + record.quantity
            if record.state == "stale" then entry.stale = true end
        elseif record.characterID then
            local counts = byCharacter[record.characterID]
            if not counts then counts = {}; byCharacter[record.characterID] = counts end
            counts[record.source] = (counts[record.source] or 0) + record.quantity
            if record.state == "stale" and current and current.id == record.characterID then counts.stale = true end
        end
    end

    local shown, remaining = 0, 0
    for _, character in ipairs(characters or {}) do
        local counts = byCharacter[character.id]
        if counts then
            if shown >= 20 then remaining = remaining + 1
            else
                local detail = SourceText(counts)
                if counts.stale then detail = detail .. "  ·  待刷新" end
                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
                if detail ~= "" then tooltip:AddDoubleLine(OwnerName(character), detail,
                    color and color.r or 0.90, color and color.g or 0.96, color and color.b or 0.97, 0.53, 0.70, 0.73) end
                shown = shown + 1
            end
        end
    end
    if remaining > 0 then tooltip:AddLine("另有 " .. remaining .. " 名角色；合计已包含其库存。", 0.53, 0.70, 0.73) end
    local guildKeys = {}
    for key in pairs(guilds) do guildKeys[#guildKeys + 1] = key end
    table.sort(guildKeys)
    for _, key in ipairs(guildKeys) do
        local guild = guilds[key]
        tooltip:AddDoubleLine(guild.name, "公会银行 " .. guild.quantity .. (guild.stale and "  ·  待刷新" or ""),
            0.90, 0.96, 0.97, 0.53, 0.70, 0.73)
    end
    if minPrice and type(GetCoinTextureString) == "function" then
        local price = GetCoinTextureString(minPrice)
        if maxPrice ~= minPrice then price = price .. " – " .. GetCoinTextureString(maxPrice) end
        tooltip:AddDoubleLine("已知上架单价", price, 0.53, 0.70, 0.73, 0.90, 0.96, 0.97)
    end
    tooltip:Show()
end

function Tooltip:Install()
    if self.installed or not GameTooltip or type(GameTooltip.HookScript) ~= "function" then return end
    self.installed = true
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared",
        function(tooltip) tooltip._yiboVaultAppliedItemID = nil end)
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem",
        function(tooltip) Tooltip:Append(tooltip) end)
    GameTooltip:HookScript("OnHide", function(tooltip) tooltip._yiboVaultAppliedItemID = nil end)
    GameTooltip:HookScript("OnShow", function(tooltip) Tooltip:Append(tooltip) end)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            Tooltip:Append(tooltip, data and data.id)
        end)
    end
end
