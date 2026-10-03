local Addon = _G.YiboVault
local Tooltip = {}
Addon.Tooltip = Tooltip

local SOURCE_ORDER = { "bags", "mail", "bank", "equipment", "auction" }
local SOURCE_ICONS = {
    bags = "Interface\\Icons\\INV_Misc_Bag_10",
    mail = "Interface\\Icons\\INV_Letter_15",
    bank = "Interface\\Icons\\INV_Box_01",
    equipment = "Interface\\Icons\\INV_Chest_Cloth_01",
    auction = "Interface\\Icons\\INV_Misc_Coin_02",
}
local GREEN = "|cff20e070"
local MUTED = "|cff87b3ba"
local RESET = "|r"
local function ItemID(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
end

local function GreenNumber(value)
    return GREEN .. tostring(value) .. RESET
end

local function SourceParts(counts, unknown)
    local parts = {}
    for _, source in ipairs(SOURCE_ORDER) do
        local icon = "|T" .. SOURCE_ICONS[source] .. ":13:13:0:0|t"
        if unknown and unknown[source] then
            parts[#parts + 1] = icon .. MUTED .. "~" .. RESET
        elseif counts[source] and counts[source] > 0 then
            parts[#parts + 1] = icon .. GreenNumber(counts[source])
        end
    end
    return parts
end

local function Observed(state, source)
    local status = state and state.status
    return status == "known" or status == "known-empty" or source == "mail" and status == "partial"
end

local function SourceObserved(result, characterID, source)
    local coverage = result.coverage and result.coverage[source] and result.coverage[source][characterID]
    local locations = coverage and coverage.locations or {}
    if source == "bags" then
        for bagID = 0, (tonumber(NUM_BAG_SLOTS) or 4) do
            if not Observed(locations[tostring(bagID)], source) then return false end
        end
        return true
    elseif source == "bank" then
        local first = (tonumber(NUM_BAG_SLOTS) or 4) + 1
        if not Observed(locations[tostring(tonumber(BANK_CONTAINER) or -1)], source) then return false end
        for bagID = first, first + (tonumber(NUM_BANKBAGSLOTS) or 7) - 1 do
            if not Observed(locations[tostring(bagID)], source) then return false end
        end
        return true
    end
    local key = source == "equipment" and "equipment" or source == "auction" and "auction" or "inbox"
    return Observed(locations[key], source)
end

local function TotalLabel(total, unknown)
    if unknown and total == 0 then return "~" end
    return tostring(total) .. (unknown and "+" or "")
end

local function TextWidth(tooltip, value)
    if type(tooltip.CreateFontString) ~= "function" then return 0 end
    if not tooltip._yiboVaultMeasure then
        tooltip._yiboVaultMeasure = tooltip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        if tooltip._yiboVaultMeasure.SetAlpha then tooltip._yiboVaultMeasure:SetAlpha(0) end
    end
    local measure = tooltip._yiboVaultMeasure
    measure:SetText(value)
    return measure:GetStringWidth() or 0
end

local function WidthLimit()
    local screenWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 900
    return math.max(160, math.min(480, screenWidth - 40))
end

local function RowLines(tooltip, name, total, parts)
    local right = GreenNumber(total) .. "[" .. table.concat(parts, "/") .. "]"
    if TextWidth(tooltip, name) + TextWidth(tooltip, right) + 40 <= WidthLimit() then
        return right, {}
    end
    local extra, group = {}, {}
    for _, part in ipairs(parts) do
        local candidate = #group == 0 and part or (table.concat(group, "/") .. "/" .. part)
        if #group > 0 and TextWidth(tooltip, "  [" .. candidate .. "]") + 20 > WidthLimit() then
            extra[#extra + 1] = "  [" .. table.concat(group, "/") .. "]"
            group = { part }
        else
            group[#group + 1] = part
        end
    end
    if #group > 0 then extra[#extra + 1] = "  [" .. table.concat(group, "/") .. "]" end
    return GreenNumber(total), extra
end

local function RowBudget(tooltip)
    if not (UIParent and UIParent.GetHeight and tooltip.GetHeight) then return 100 end
    local safeHeight = (UIParent:GetHeight() or 900) * 0.88
    local remaining = safeHeight - (tooltip:GetHeight() or 0) - 60
    return math.max(0, math.floor(remaining / 17))
end

local function AddOwnerRow(tooltip, name, total, parts, color)
    local right, extra = RowLines(tooltip, name, total, parts)
    tooltip:AddDoubleLine(name, right, color and color.r or 0.90,
        color and color.g or 0.96, color and color.b or 0.97, 0.53, 0.70, 0.73)
    for _, line in ipairs(extra) do tooltip:AddLine(line, 0.53, 0.70, 0.73) end
    return 1 + #extra
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
    if Addon.db and Addon.db.settings and Addon.db.settings.tooltipEnabled == false then return end
    local itemID = tonumber(knownItemID)
    if not itemID and type(tooltip.GetItem) == "function" then
        local _, link = tooltip:GetItem()
        itemID = ItemID(link)
    end
    if not itemID then return end
    local hiddenItems = Addon.db and Addon.db.settings and Addon.db.settings.hiddenTooltipItems
    if hiddenItems and hiddenItems[itemID] then return end
    local hiddenGuildKey = tooltip._yiboVaultGuildKey
    if not Addon:IsGuildHidden(hiddenGuildKey) then hiddenGuildKey = nil end
    if tooltip._yiboVaultAppliedItemID == itemID
        and tooltip._yiboVaultAppliedGuildKey == hiddenGuildKey then return end
    local scope, characters, allRealms = Addon.AccountPage:GetTooltipScope()
    tooltip._yiboVaultAppliedItemID = itemID
    tooltip._yiboVaultAppliedGuildKey = hiddenGuildKey
    local result = CachedQuery(self, scope, itemID)
    local hiddenResult = hiddenGuildKey and Addon.Items:Query({
        scope = { mode = "characters", characterIDs = {} }, guildKey = hiddenGuildKey,
        sources = { "guild-bank" }, itemID = itemID,
    })
    if #result.records == 0 and not (hiddenResult and #hiddenResult.records > 0) then return end

    local byCharacter, guilds = {}, {}
    local current = Addon.Core and Addon.Core.Characters:GetCurrent()
    for _, record in ipairs(result.records) do
        if record.source == "guild-bank" then
            local key = record.guildKey or "guild"
            local entry = guilds[key]
            if not entry then
                entry = { name = record.guildName or "公会", realm = record.realm,
                    quantity = 0, tabs = {}, tabNames = {} }
                guilds[key] = entry
            end
            entry.quantity = entry.quantity + record.quantity
            local tabID = tonumber(record.location and (record.location.tabID or record.location.container)) or 0
            entry.tabs[tabID] = (entry.tabs[tabID] or 0) + record.quantity
            local tabName = record.location and record.location.tabName
            if type(tabName) == "string" and tabName ~= "" then entry.tabNames[tabID] = tabName end
        elseif record.characterID then
            local counts = byCharacter[record.characterID]
            if not counts then counts = { total = 0 }; byCharacter[record.characterID] = counts end
            counts[record.source] = (counts[record.source] or 0) + record.quantity
            counts.total = counts.total + record.quantity
        end
    end

    local knownTotal, anyUnknown, hasCharacterRows = 0, false, false
    for _, character in ipairs(characters or {}) do
        local counts = byCharacter[character.id]
        if counts then
            hasCharacterRows = true
            counts.unknown, counts.shownTotal = {}, 0
            for _, source in ipairs(SOURCE_ORDER) do
                if current and current.id == character.id and (counts[source] or 0) > 0
                    and not SourceObserved(result, character.id, source) then
                    counts.unknown[source] = true
                    anyUnknown = true
                else
                    counts.shownTotal = counts.shownTotal + (counts[source] or 0)
                end
            end
            knownTotal = knownTotal + counts.shownTotal
        end
    end
    for key, guild in pairs(guilds) do
        guild.shownTotal, guild.tabIDs = 0, {}
        local coverage = result.coverage and result.coverage["guild-bank"]
            and result.coverage["guild-bank"][key]
        local locations = coverage and coverage.locations or {}
        for tabID, quantity in pairs(guild.tabs) do
            if tabID >= 1 and tabID <= 8 and quantity > 0
                and Observed(locations[tostring(tabID)], "guild-bank") then
                guild.tabIDs[#guild.tabIDs + 1] = tabID
                guild.shownTotal = guild.shownTotal + quantity
                local location = locations[tostring(tabID)].location
                local tabName = location and location.tabName
                if type(tabName) == "string" and tabName ~= "" then guild.tabNames[tabID] = tabName end
            end
        end
        table.sort(guild.tabIDs)
        knownTotal = knownTotal + guild.shownTotal
    end
    if not hasCharacterRows and knownTotal == 0 and not hiddenResult then return end

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("|cff20e070[Yibo]|r 账号库存", GreenNumber(TotalLabel(knownTotal, anyUnknown)),
        0.90, 0.96, 0.97, 0.53, 0.70, 0.73)
    local budget, used, shown, remaining = RowBudget(tooltip), 0, 0, 0
    for _, character in ipairs(characters or {}) do
        local counts = byCharacter[character.id]
        if counts then
            local name = tostring(character.name or character.id or "角色")
            if allRealms and character.realm and current and character.realm ~= current.realm then
                name = name .. "-" .. tostring(character.realm)
            end
            local parts = SourceParts(counts, counts.unknown)
            local label = TotalLabel(counts.shownTotal, next(counts.unknown) ~= nil)
            local right, extra = RowLines(tooltip, name, label, parts)
            if shown >= 20 or used + 1 + #extra > budget then
                remaining = remaining + 1
            else
                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
                AddOwnerRow(tooltip, name, label, parts, color)
                used = used + 1 + #extra
                shown = shown + 1
            end
        end
    end
    if remaining > 0 then tooltip:AddLine("另有 " .. remaining .. " 名角色，已计入合计", 0.53, 0.70, 0.73) end
    local guildKeys = {}
    for key, guild in pairs(guilds) do
        if guild.shownTotal > 0 then guildKeys[#guildKeys + 1] = key end
    end
    table.sort(guildKeys)
    local remainingGuilds = 0
    for _, key in ipairs(guildKeys) do
        local guild = guilds[key]
        local name = guild.name
        if allRealms and guild.realm then name = name .. "-" .. tostring(guild.realm) end
        local parts = {}
        for _, tabID in ipairs(guild.tabIDs) do
            local tabName = guild.tabNames[tabID] or "未命名"
            parts[#parts + 1] = "P" .. tostring(tabID) .. "·" .. tabName .. " " .. GreenNumber(guild.tabs[tabID])
        end
        local label = tostring(guild.shownTotal)
        local right, extra = RowLines(tooltip, name, label, parts)
        if used + 1 + #extra > budget then
            remainingGuilds = remainingGuilds + 1
        else
            AddOwnerRow(tooltip, name, label, parts)
            used = used + 1 + #extra
        end
    end
    if remainingGuilds > 0 then tooltip:AddLine("另有 " .. remainingGuilds .. " 个公会，已计入合计", 0.53, 0.70, 0.73) end
    if hiddenResult and #hiddenResult.records > 0 then
        local hiddenGuild = Addon.db.byGuild[hiddenGuildKey]
        local hiddenCoverage = hiddenResult.coverage["guild-bank"]
            and hiddenResult.coverage["guild-bank"][hiddenGuildKey]
        local locations = hiddenCoverage and hiddenCoverage.locations or {}
        local tabCounts, tabNames, tabIDs, hiddenTotal = {}, {}, {}, 0
        for _, record in ipairs(hiddenResult.records) do
            local tabID = tonumber(record.location and record.location.tabID)
            local state = tabID and locations[tostring(tabID)]
            if tabID and Observed(state, "guild-bank") then
                if not tabCounts[tabID] then tabIDs[#tabIDs + 1] = tabID end
                tabCounts[tabID] = (tabCounts[tabID] or 0) + record.quantity
                tabNames[tabID] = record.location.tabName or "未命名"
                hiddenTotal = hiddenTotal + record.quantity
            end
        end
        table.sort(tabIDs)
        tooltip:AddLine("已隐藏 · 不计入账号合计", 0.53, 0.70, 0.73)
        local parts = {}
        for _, tabID in ipairs(tabIDs) do
            parts[#parts + 1] = "P" .. tabID .. "·" .. tabNames[tabID] .. " " .. GreenNumber(tabCounts[tabID])
        end
        local name = hiddenGuild.guildName or "公会"
        if allRealms and hiddenGuild.realm then name = name .. "-" .. hiddenGuild.realm end
        AddOwnerRow(tooltip, name, hiddenTotal > 0 and tostring(hiddenTotal) or "~", parts)
    end
    tooltip:Show()
end

function Tooltip:Invalidate()
    self.cacheRevision, self.cacheScope = nil, nil
    self.cacheResults, self.cacheOrder = nil, nil
    local tooltip = GameTooltip
    if tooltip then
        tooltip._yiboVaultAppliedItemID = nil
        tooltip._yiboVaultAppliedGuildKey = nil
        if tooltip.IsShown and tooltip:IsShown() and tooltip.RefreshData then
            pcall(tooltip.RefreshData, tooltip)
        end
    end
end

function Tooltip:Install()
    if self.installed or not GameTooltip or type(GameTooltip.HookScript) ~= "function" then return end
    self.installed = true
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared",
        function(tooltip) tooltip._yiboVaultAppliedItemID = nil; tooltip._yiboVaultAppliedGuildKey = nil end)
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem",
        function(tooltip) Tooltip:Append(tooltip) end)
    GameTooltip:HookScript("OnHide", function(tooltip)
        tooltip._yiboVaultAppliedItemID = nil
        tooltip._yiboVaultAppliedGuildKey = nil
        tooltip._yiboVaultGuildKey = nil
    end)
    GameTooltip:HookScript("OnShow", function(tooltip) Tooltip:Append(tooltip) end)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            Tooltip:Append(tooltip, data and data.id)
        end)
    end
    if Addon.Items.Events and Addon.Items.Events.Register then
        Addon.Items.Events:Register(self, function(_, payload)
            local itemID = GameTooltip and GameTooltip._yiboVaultAppliedItemID
            if not itemID or not GameTooltip.IsShown or not GameTooltip:IsShown()
                or type(GameTooltip.RefreshData) ~= "function" or Tooltip.refreshing then return end
            local changed = payload and payload.changedItemIDs or {}
            if #changed > 0 then
                local matches = false
                for _, changedID in ipairs(changed) do
                    if changedID == itemID then matches = true; break end
                end
                if not matches then return end
            end
            Tooltip.refreshing = true
            pcall(GameTooltip.RefreshData, GameTooltip)
            Tooltip.refreshing = nil
        end)
    end
end
