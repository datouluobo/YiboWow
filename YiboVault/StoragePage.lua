local Addon = _G.YiboVault
local Core = _G.YiboCore
local Theme = Core.UITheme
local Colors = Theme.Colors
local StoragePage = {}
Addon.StoragePage = StoragePage
local CELL_SIZE, CELL_GAP, CELL_MIN_COLUMN_GAP = 42, 5, 3
local ITEM_ROW_HEIGHT, ITEM_ROW_OVERSCAN = CELL_SIZE + CELL_GAP, 2
local OWNER_HEIGHT = 42
local OWNER_WIDTH, CONTENT_LEFT = 190, 217

local CHARACTER_AREAS = {
    { id = "bags", label = Addon:T("TEXT.BAGS_FF3D08") }, { id = "mail", label = Addon:T("TEXT.MAIL_1C8E46") },
    { id = "bank", label = Addon:T("TEXT.PERSONAL_BANK_225443") }, { id = "auction", label = Addon:T("TEXT.AUCTIONS_89A4A2") },
    { id = "equipment", label = Addon:T("TEXT.EQUIPMENT_1FAF33") },
}
local GUILD_TAB_COUNT = 8
local itemNameCache = {}
local EQUIPMENT_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_NECK = true, INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true, INVTYPE_ROBE = true, INVTYPE_WAIST = true,
    INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true,
    INVTYPE_HAND = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true, INVTYPE_WEAPON = true, INVTYPE_SHIELD = true,
    INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_RELIC = true,
}

local function GuildTabKey(tabID) return "tab:" .. tostring(tabID) end

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size, color, justify)
end

local function ScopedCharacters(context)
    local realm = context and context.scope and context.scope:match("^realm:(.+)$")
    local characters = {}
    for _, character in ipairs(context and context.characters or {}) do
        if not realm or character.realm == realm then characters[#characters + 1] = character end
    end
    return characters
end

local function Scope(characters)
    local ids = {}
    for _, character in ipairs(characters) do ids[#ids + 1] = character.id end
    return { mode = "characters", characterIDs = ids }
end

local function CapacityText(area)
    if not area or not area.totalSlots then return "" end
    local prefix = area.completeCapacity and "" or Addon:T("TEXT.KNOWN_A96951")
    if area.freeSlots ~= nil then
        return string.format(Addon:T("CAPACITY.TOTAL_FREE"), prefix, area.freeSlots, area.totalSlots)
    end
    return string.format(Addon:T("TEXT.S_TOTAL_SLOTS_D_E4410B"), prefix, area.totalSlots)
end

local function CompositionText(area)
    local parts = {}
    for _, location in ipairs(area and area.locations or {}) do
        local capacity = location.capacity
        if capacity and capacity.totalSlots and capacity.totalSlots > 0 then
            local name = capacity.bagName or (tonumber(location.locationKey) == 0 and Addon:T("TEXT.BAGS_FF3D08")
                or (Addon:T("TEXT.CONTAINER_FDA18C") .. tostring(location.locationKey)))
            parts[#parts + 1] = name .. "(" .. capacity.totalSlots .. ")"
        end
    end
    return table.concat(parts, " + ")
end

local function ItemIcon(itemID)
    if type(GetItemIcon) == "function" then return GetItemIcon(itemID) end
    if type(GetItemInfo) == "function" then return select(10, GetItemInfo(itemID)) end
end

local function ItemBorder(record)
    if record then
        local name, quality
        if type(GetItemInfo) == "function" then
            name, _, quality = GetItemInfo(record.itemLink or record.itemID)
        end
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if color then return { color.r, color.g, color.b, 1 }, not name end
        if type(record.itemLink) == "string" then
            local red, green, blue = record.itemLink:match("^|c[fF][fF](%x%x)(%x%x)(%x%x)|H")
            if red then
                return { tonumber(red, 16) / 255, tonumber(green, 16) / 255,
                    tonumber(blue, 16) / 255, 1 }, not name
            end
        end
        -- An uncached item still needs a visible outline until item data arrives.
        return { Colors.muted[1], Colors.muted[2], Colors.muted[3], 1 }, not name
    end
    return Colors.lineSoft
end

function StoragePage:GetItemLevel(record)
    if not record or not record.itemID or type(GetItemInfo) ~= "function" then return nil, false end
    local item = record.itemLink or record.itemID
    local _, _, _, baseLevel, _, _, _, _, equipLoc = GetItemInfo(item)
    if not EQUIPMENT_SLOTS[equipLoc] then return nil, false end
    local detailed = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
    local level
    if type(detailed) == "function" then
        local ok, value = pcall(detailed, item)
        if ok then level = tonumber(value) end
    else
        level = tonumber(baseLevel)
    end
    return level and level > 0 and math.floor(level) or nil, true
end

local function CreateOwnerRow(page, index)
    local row = CreateFrame("Button", nil, page.ownersContent, "BackdropTemplate")
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row:SetHeight(OWNER_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * (OWNER_HEIGHT + 2)))
    row:SetPoint("TOPRIGHT", 0, -((index - 1) * (OWNER_HEIGHT + 2)))
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT", 6, 0)
    row.name = Text(row, Theme.Font.assist, Colors.text)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -3)
    row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4); row.name:SetHeight(17)
    row.currentMarker = row:CreateTexture(nil, "OVERLAY")
    row.currentMarker:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.currentMarker:SetVertexColor(unpack(Colors.accent))
    row.currentMarker:SetSize(7, 7)
    row.currentMarker:SetPoint("RIGHT", row, "RIGHT", -9, 0)
    row.currentMarker:Hide()
    row.meta = Text(row, Theme.Font.meta, Colors.muted)
    row.meta:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 38, 3)
    row.meta:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 3)
    row.meta:SetHeight(15)
    row:SetScript("OnClick", function(control)
        page.selectedOwner = control.ownerKey
        if page.explicitGuildKey ~= control.ownerKey then page.explicitGuildKey = nil end
        page.area = nil
        page.grid:SetVerticalScroll(0)
        StoragePage:Refresh(page, page.context)
    end)
    page.ownerRows[index] = row
    return row
end

local function CreateItemCell(page, index)
    local cell = CreateFrame("Button", nil, page.itemsContent, "BackdropTemplate")
    cell:SetSize(CELL_SIZE, CELL_SIZE)
    cell:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", 1, -1); cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell.count = Text(cell, Theme.Font.assist, Colors.text, "LEFT")
    cell.count:SetPoint("TOPLEFT", 3, -2)
    cell.itemLevel = Text(cell, Theme.Font.section, { 0.78, 0.62, 1 }, "RIGHT")
    cell.itemLevel:SetPoint("BOTTOMRIGHT", -3, 2)
    cell.itemLevel:SetWidth(CELL_SIZE - 6)
    cell.itemLevel:SetHeight(18)
    cell.itemLevel:SetFont(STANDARD_TEXT_FONT, Theme.Font.section, "OUTLINE")
    cell.emptyLabel = Text(cell, Theme.Font.meta, Colors.muted, "CENTER")
    cell.emptyLabel:SetPoint("TOPLEFT", 2, -3)
    cell.emptyLabel:SetPoint("TOPRIGHT", -2, -3)
    cell.emptyLabel:SetHeight(15)
    cell.emptyLabel:SetText(Addon:T("TEXT.EMPTY_A3EEF8"))
    cell.emptyCount = Text(cell, Theme.Font.assist, Colors.text, "CENTER")
    cell.emptyCount:SetPoint("BOTTOMLEFT", 2, 2)
    cell.emptyCount:SetPoint("BOTTOMRIGHT", -2, 2)
    cell.emptyCount:SetHeight(17)
    cell:SetScript("OnEnter", function(control)
        if not control.item or not GameTooltip then return end
        control:SetBackdropBorderColor(unpack(Colors.accent))
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        GameTooltip._yiboVaultGuildKey = control.hiddenGuildKey
        if control.item.itemLink then GameTooltip:SetHyperlink(control.item.itemLink)
        elseif GameTooltip.SetItemByID then GameTooltip:SetItemByID(control.item.itemID) end
        GameTooltip:Show()
        if Addon.Tooltip then Addon.Tooltip:Append(GameTooltip, control.item.itemID) end
        if control.item.mailStatus == "in-transit" then
            GameTooltip:AddLine(Addon:T("MAIL.IN_TRANSIT_FROM", control.item.senderName or ""), 0.53, 0.70, 0.73)
            GameTooltip:Show()
        end
        if Addon.GoalTargets and Addon.GoalTargets.ref then GameTooltip:AddLine(Addon.Core.BusinessItemActions:GestureLabel() .. Addon:T("TEXT.ADD_TO_ACTION_HUB_OPEN_THE_ADD_MENU_1EB204")); GameTooltip:Show() end
    end)
    cell:SetScript("OnLeave", function(control)
        control:SetBackdropBorderColor(unpack(control.borderColor or Colors.lineSoft))
        if GameTooltip then GameTooltip._yiboVaultGuildKey = nil; GameTooltip:Hide() end
    end)
    page.itemCells[index] = cell
    return cell
end

function StoragePage:Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    parent.yiboVaultStoragePage = page
    self.page = page
    page.area = "bags"
    page.ownerRows, page.itemCells, page.areaButtons = {}, {}, {}
    page.pendingItemInfo = {}
    page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    page:SetScript("OnEvent", function(_, event, itemID, succeeded)
        if event ~= "GET_ITEM_INFO_RECEIVED" or not itemID or not page.pendingItemInfo[itemID] then return end
        page.pendingItemInfo[itemID] = nil
        if succeeded == false then return end
        for index = 1, #page.itemCells do
            local cell = page.itemCells[index]
            if cell and cell.item and cell.item.itemID == itemID then
                StoragePage:UpdateItemCell(page, cell, cell.item, cell.slotIndex or index)
            end
        end
    end)

    page.search = Theme:CreateInput(page, {
        width = 340, height = 30, placeholder = Addon:T("TEXT.SEARCH_ACCOUNT_ITEMS_BY_NAME_OR_ID_CD46C9"), clearable = true,
        OnChanged = function(_, _, control)
            local active = (control:GetText() or ""):match("%S") ~= nil
            if active and not page.searchActive then
                page.browseOwner, page.browseArea = page.selectedOwner, page.area
            elseif not active and page.searchActive then
                page.selectedOwner, page.area = page.browseOwner, page.browseArea
            end
            page.searchActive = active
            if page.grid then page.grid:SetVerticalScroll(0) end
            page.searchRefreshSerial = (page.searchRefreshSerial or 0) + 1
            local serial = page.searchRefreshSerial
            C_Timer.After(0.15, function()
                if page.ready and page.searchRefreshSerial == serial then
                    StoragePage:Refresh(page, page.context)
                end
            end)
        end,
    })
    page.search:SetPoint("TOPLEFT", page, "TOPLEFT", CONTENT_LEFT, -10)
    page.searchBox, page.searchHint, page.searchClear = page.search, page.search.placeholder, page.search.clearButton
    page.showHidden = Theme:CreateCheckbox(page, Addon:T("TEXT.SHOW_HIDDEN_GUILDS_4B158B"))
    page.showHidden:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -8)
    page.showHidden:SetWidth(OWNER_WIDTH)
    page.showHidden:SetScript("OnClick", function(control)
        page.showHiddenGuilds = not control:GetChecked()
        control:SetChecked(page.showHiddenGuilds)
        if not page.showHiddenGuilds then page.explicitGuildKey = nil end
        StoragePage:Refresh(page, page.context)
    end)
    page.owners = Theme:CreateScrollFrame(page)
    page.owners:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -44)
    page.owners:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 12, 12)
    page.owners:SetWidth(OWNER_WIDTH)
    page.ownersContent = CreateFrame("Frame", nil, page.owners)
    page.ownersContent:SetWidth(OWNER_WIDTH)
    page.owners:SetScrollChild(page.ownersContent)

    page.header = CreateFrame("Frame", nil, page)
    page.header:SetPoint("TOPLEFT", page, "TOPLEFT", CONTENT_LEFT, -46)
    page.header:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -46)
    page.header:SetHeight(78)
    page.identityIcon = page.header:CreateTexture(nil, "ARTWORK")
    page.identityIcon:SetSize(46, 46); page.identityIcon:SetPoint("TOPLEFT", 2, -2)
    page.heading = Text(page.header, Theme.Font.section, Colors.accent)
    page.heading:SetPoint("TOPLEFT", page.identityIcon, "TOPRIGHT", 9, -2)
    page.heading:SetPoint("RIGHT", page.header, "CENTER", 0, 0)
    page.heading:SetHeight(22)
    page.identityMeta = Text(page.header, Theme.Font.assist, Colors.muted)
    page.identityMeta:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -2)
    page.identityMeta:SetPoint("RIGHT", page.heading, "RIGHT", 0, 0)
    page.identityMeta:SetHeight(20)
    page.bagCapacity = Text(page.header, Theme.Font.assist, Colors.text)
    page.bagCapacity:SetPoint("TOPLEFT", page.header, "TOP", 0, -2)
    page.bagCapacity:SetPoint("TOPRIGHT", page.header, "TOPRIGHT", 0, -2)
    page.bagCapacity:SetHeight(21)
    page.bankCapacity = Text(page.header, Theme.Font.assist, Colors.text)
    page.bankCapacity:SetPoint("TOPLEFT", page.bagCapacity, "BOTTOMLEFT", 0, -1)
    page.bankCapacity:SetPoint("TOPRIGHT", page.bagCapacity, "BOTTOMRIGHT", 0, -1)
    page.bankCapacity:SetHeight(21)
    page.composition = Text(page.header, Theme.Font.meta, Colors.muted)
    page.composition:SetPoint("BOTTOMLEFT", page.header, "BOTTOMLEFT", 0, 0)
    page.composition:SetPoint("BOTTOMRIGHT", page.header, "BOTTOMRIGHT", 0, 0)
    page.composition:SetHeight(20)

    for index = 1, GUILD_TAB_COUNT do
        local button = Theme:CreateButton(page, 105, "", "secondary")
        button:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", (index - 1) * 111, -4)
        button:SetScript("OnClick", function()
            if button.tabEnabled and page.area ~= button.tabKey then
                page.area = button.tabKey
                page.grid:SetVerticalScroll(0)
                self:Refresh(page, page.context)
            end
        end)
        page.areaButtons[index] = button
    end

    page.grid = Theme:CreateScrollFrame(page)
    page.grid:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -42)
    page.grid:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 12)
    page.itemsContent = CreateFrame("Frame", nil, page.grid)
    page.itemsContent:SetSize(1, 1)
    page.grid:SetScrollChild(page.itemsContent)
    page.grid:HookScript("OnSizeChanged", function() StoragePage:LayoutCells(page) end)
    page.grid:HookScript("OnVerticalScroll", function() StoragePage:LayoutCells(page) end)
    page.empty = Text(page.grid, Theme.Font.assist, Colors.muted)
    page.empty:SetPoint("TOPLEFT", 8, -8)
    page.empty:SetPoint("RIGHT", -8, 0)
    page.empty:SetHeight(26)
    page:HookScript("OnSizeChanged", function() StoragePage:LayoutChrome(page) end)
    self:LayoutChrome(page)
    page.ready = true
end

function StoragePage:LayoutChrome(page)
    local width = math.max(1, page.header:GetWidth() or 1)
    local visible = page.tabs or CHARACTER_AREAS
    local gap = 4
    local buttonWidth = #visible > 0 and math.max(1, (width - (#visible - 1) * gap) / #visible) or 1
    for index, button in ipairs(page.areaButtons) do
        local tab = visible[index]
        button:ClearAllPoints()
        button:SetShown(tab ~= nil)
        if tab then
            button.tabKey, button.tabEnabled = tab.id, tab.enabled == true
            button.label:SetText(tab.label)
            button:SetState(not button.tabEnabled and "disabled" or tab.id == page.area and "selected" or "default")
            button:SetWidth(buttonWidth)
            button:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", (index - 1) * (buttonWidth + gap), -4)
        else
            button.tabKey, button.tabEnabled = nil, false
        end
    end
    page.grid:ClearAllPoints()
    page.grid:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -42)
    page.grid:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 12)
end

function StoragePage:GetGridColumns(width)
    local usable = math.max(CELL_SIZE, (width or 0) - 4)
    return math.max(1, math.floor((usable + CELL_MIN_COLUMN_GAP) / (CELL_SIZE + CELL_MIN_COLUMN_GAP)))
end

function StoragePage:GetGridColumnOffset(width, columns, column)
    if columns <= 1 then return 2 end
    local distance = math.max(0, (width or 0) - 4 - CELL_SIZE) / (columns - 1)
    return 2 + math.floor((column - 1) * distance + 0.5)
end

function StoragePage:GetGridContentHeight(slotCount, columns)
    return math.max(1, 4 + math.ceil(slotCount / columns) * (CELL_SIZE + CELL_GAP))
end

function StoragePage:BuildSlots(records, areaID, freeSlots, freeGroups)
    local slots = {}
    if areaID == "equipment" then
        for slot = 1, 19 do slots[slot] = false end
        for _, record in ipairs(records or {}) do
            local slot = tonumber(record.location and record.location.slot)
            if slot and slot >= 1 and slot <= 19 then slots[slot] = record end
        end
    else
        for _, record in ipairs(records or {}) do slots[#slots + 1] = record end
        if type(freeGroups) == "table" then
            for _, group in ipairs(freeGroups) do
                slots[#slots + 1] = { emptySlots = group.emptySlots, emptyLabelKey = group.emptyLabelKey }
            end
        elseif type(freeSlots) == "number" and freeSlots > 0 then
            slots[#slots + 1] = { emptySlots = math.floor(freeSlots) }
        end
    end
    return slots
end

function StoragePage:UpdateItemCell(page, cell, record, index)
    local item = record and record.itemID and record or nil
    local emptySlots = record and record.emptySlots
    if Addon.GoalTargets then Addon.GoalTargets:Bind(cell, item) end
    cell.item = item
    cell.hiddenGuildKey = item and item.source == "guild-bank" and page.selectedHiddenGuildKey or nil
    cell.icon:SetShown(item ~= nil)
    cell.icon:SetTexture(item and ItemIcon(item.itemID) or nil)
    local itemLevel
    if item then itemLevel = self:GetItemLevel(item) end
    cell.itemLevel:SetText(itemLevel and tostring(itemLevel) or "")
    local quantity = item and (item.mailStatus == "in-transit"
        and (Addon:T("MAIL.TRANSIT_SHORT") .. tostring(item.quantity or 1))
        or not itemLevel and tostring(item.quantity or 1)) or ""
    cell.count:SetFont(STANDARD_TEXT_FONT,
        #quantity > 3 and Theme.Font.assist or Theme.Font.section, "OUTLINE")
    cell.count:SetText(quantity)
    cell.emptyLabel:SetShown(emptySlots ~= nil)
    cell.emptyLabel:SetText(Addon:T(record and record.emptyLabelKey or "TEXT.EMPTY_A3EEF8"))
    cell.emptyCount:SetShown(emptySlots ~= nil)
    cell.emptyCount:SetText(emptySlots and tostring(emptySlots) or "")
    cell:SetBackdropColor(unpack(item and Theme:GetDataRowColor(index) or emptySlots and Colors.panel or Colors.bg))
    local borderColor, needsItemInfo = ItemBorder(item)
    cell.borderColor = borderColor
    if cell.IsMouseOver and cell:IsMouseOver() then
        cell:SetBackdropBorderColor(unpack(Colors.accent))
    else
        cell:SetBackdropBorderColor(unpack(borderColor))
    end
    if needsItemInfo and item and not page.pendingItemInfo[item.itemID]
        and Addon.Core.ItemResolver:GetInfo(item.itemID).state ~= "ready" then
        page.pendingItemInfo[item.itemID] = true
        local id = item.itemID
        Addon.Core.ItemResolver:Request(id, function(info)
            local callback = page:GetScript("OnEvent")
            if callback then callback(page, "GET_ITEM_INFO_RECEIVED", id, info and info.state == "ready") end
        end)
    end
end

function StoragePage:LayoutCells(page)
    if not page.grid or not page.itemsContent then return end
    local slots = page.slots or {}
    local width = math.max(1, page.grid:GetWidth() or 1)
    local columns = self:GetGridColumns(width)
    page.itemsContent:SetWidth(width)
    local rowCount = math.ceil(#slots / columns)
    local rowHeight = ITEM_ROW_HEIGHT
    local viewportHeight = math.max(rowHeight * 6, page.grid:GetHeight() or 0)
    local scrollTop = math.max(0, page.grid:GetVerticalScroll() or 0)
    local firstRow = math.max(1, math.floor(scrollTop / rowHeight) + 1 - ITEM_ROW_OVERSCAN)
    local lastRow = math.min(rowCount,
        math.ceil((scrollTop + viewportHeight) / rowHeight) + ITEM_ROW_OVERSCAN)
    local poolIndex = 0
    for row = firstRow, lastRow do
        for column = 1, columns do
            local slotIndex = (row - 1) * columns + column
            if slotIndex > #slots then break end
            poolIndex = poolIndex + 1
            local cell = page.itemCells[poolIndex] or CreateItemCell(page, poolIndex)
            cell.slotIndex = slotIndex
            self:UpdateItemCell(page, cell, slots[slotIndex], slotIndex)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", page.itemsContent, "TOPLEFT",
                self:GetGridColumnOffset(width, columns, column),
                -2 - (row - 1) * rowHeight)
            cell:Show()
        end
    end
    for index = poolIndex + 1, #page.itemCells do
        page.itemCells[index].slotIndex = nil
        page.itemCells[index]:Hide()
    end
    local contentHeight = self:GetGridContentHeight(#slots, columns)
    page.itemsContent:SetHeight(contentHeight)
    page.grid:SetContentHeight(contentHeight)
end

local function MatchRecord(record, needle)
    if needle == "" then return true end
    local id = tostring(record.itemID or "")
    if string.find(id, needle, 1, true) then return true end
    local itemID = tonumber(record.itemID)
    local name = itemID and itemNameCache[itemID]
    if not name and type(GetItemInfo) == "function" then
        name = GetItemInfo(record.itemLink or record.itemID)
        if name and itemID then
            name = string.lower(name)
            itemNameCache[itemID] = name
        end
    end
    return name and string.find(name, needle, 1, true) ~= nil
end

local function OwnerKey(record)
    if record.source == "guild-bank" then return record.guildKey end
    return record.characterID
end

function StoragePage:CollectMatches(records, needle, ownerByKey)
    for _, record in ipairs(records or {}) do
        if MatchRecord(record, needle) then
            local owner = ownerByKey[OwnerKey(record)]
            if owner then
                local area = record.source == "guild-bank" and GuildTabKey(record.location and record.location.tabID)
                    or record.source
                owner.records[area] = owner.records[area] or {}
                owner.records[area][#owner.records[area] + 1] = record
                owner.counts[area] = (owner.counts[area] or 0) + record.quantity
                owner.matchQuantity = owner.matchQuantity + record.quantity
            end
        end
    end
end

function StoragePage:Refresh(host, context)
    local page = host and (host.yiboVaultStoragePage or host)
    if not page then return end
    if not page.ready then error(page.createError or Addon:T("TEXT.THE_YIBOVAULT_STORAGE_PAGE_COULD_NOT_BE_CR_4D13AE")) end
    if self.pendingGuildKey then
        page.explicitGuildKey = self.pendingGuildKey
        page.showHiddenGuilds = true
        page.selectedOwner = self.pendingGuildKey
        page.area = nil
        self.pendingGuildKey = nil
    end
    page.context = context or page.context
    if not page.context then return end

    local characters = ScopedCharacters(page.context)
    local scope = Scope(characters)
    local guildOptions = { includeHiddenGuilds = page.showHiddenGuilds == true,
        guildKey = page.explicitGuildKey }
    local revision = Addon.Items:GetRevision()
    local cacheKey = table.concat({ tostring(revision), table.concat(scope.characterIDs, "\030"),
        guildOptions.includeHiddenGuilds and "1" or "0", guildOptions.guildKey or "" }, "\031")
    local snapshot = page.searchSnapshot
    if not snapshot or snapshot.key ~= cacheKey then
        snapshot = {
            key = cacheKey,
            summary = Addon.Items:GetStorageSummary(scope, guildOptions),
            query = Addon.Items:Query({ scope = scope, includeHiddenGuilds = guildOptions.includeHiddenGuilds,
                guildKey = guildOptions.guildKey }),
            auctionStates = Addon.Items:GetSourceState("auction", scope),
        }
        page.searchSnapshot = snapshot
    end
    local summary, query, auctionStates = snapshot.summary, snapshot.query, snapshot.auctionStates
    page.showHidden:SetChecked(page.showHiddenGuilds == true)
    local needle = string.lower((page.search:GetText() or ""):match("^%s*(.-)%s*$"))
    local searching = needle ~= ""
    local summaryByID = {}
    for _, entry in ipairs(summary.characters) do summaryByID[entry.characterID] = entry end
    local owners, ownerByKey = {}, {}

    for _, character in ipairs(characters) do
        local entry = summaryByID[character.id]
        local auction = auctionStates[character.id] and auctionStates[character.id].locations.auction
        local displayName = Addon.Core.Characters:FormatName(character, {
            nameMode = "short", realmMode = "sameRealm",
            referenceRealm = (Addon.Core.Characters:GetCurrent() or {}).realm,
        })
        local owner = { key = character.id, label = displayName or character.id,
            realm = character.realm, entry = entry, character = character,
            auction = auction and auction.completedScan and {
                hasStale = auction.status ~= "known" and auction.status ~= "known-empty" } or nil,
            records = {}, counts = {}, matchQuantity = 0 }
        owner.tabs = {}
        for _, area in ipairs(CHARACTER_AREAS) do
            local scanned = entry and entry[area.id] or area.id == "auction" and owner.auction
            owner.tabs[#owner.tabs + 1] = { id = area.id, label = area.label, enabled = scanned ~= nil }
        end
        owners[#owners + 1] = owner
        ownerByKey[owner.key] = owner
    end
    local guildOwnerCount = 0
    for _, guild in ipairs(summary.guilds) do
        local guildName = guild.guildName or Addon:T("TEXT.GUILD_AE2266")
        local hidden = Addon:IsGuildHidden(guild.guildKey)
        local owner = { key = guild.guildKey, label = guild.realm and (guildName .. " · " .. tostring(guild.realm)) or guildName,
            realm = guild.realm, guildKey = guild.guildKey, hidden = hidden, tabAreas = {}, tabs = {},
            records = {}, counts = {}, matchQuantity = 0 }
        for _, tab in ipairs(guild.tabs.locations or {}) do
            local tabID = tonumber(tab.location and tab.location.tabID)
            if tabID and tabID >= 1 and tabID <= GUILD_TAB_COUNT then
                local area = { totalSlots = tab.capacity and tab.capacity.totalSlots,
                    freeSlots = tab.capacity and tab.capacity.freeSlots,
                    completeCapacity = true,
                    hasStale = tab.status ~= "known" and tab.status ~= "known-empty" }
                owner.tabAreas[GuildTabKey(tabID)] = area
                owner.tabs[tabID] = { id = GuildTabKey(tabID),
                    label = tab.location.tabName or (Addon:T("TEXT.TAB_0C0C77") .. tabID), enabled = true }
            end
        end
        for tabID = 1, GUILD_TAB_COUNT do
            if not owner.tabs[tabID] then owner.tabs[tabID] = {
                id = GuildTabKey(tabID), label = Addon:T("TEXT.TAB_0C0C77") .. tabID, enabled = false } end
        end
        guildOwnerCount = guildOwnerCount + 1
        table.insert(owners, guildOwnerCount, owner)
        ownerByKey[owner.key] = owner
    end

    self:CollectMatches(query.records, needle, ownerByKey)
    self:CollectMatches(query.transitRecords, needle, ownerByKey)
    if searching then
        local matched = {}
        for _, owner in ipairs(owners) do
            if owner.matchQuantity > 0 then matched[#matched + 1] = owner end
        end
        owners = matched
    end

    local selected
    for _, owner in ipairs(owners) do
        if owner.key == page.selectedOwner then selected = owner; break end
    end
    selected = selected or owners[1]
    page.selectedOwner = selected and selected.key
    if selected then
        page.tabs = selected.tabs
        local valid = false
        for _, tab in ipairs(selected.tabs) do
            if tab.id == page.area and tab.enabled then valid = true; break end
        end
        if not valid then
            page.area = nil
            for _, tab in ipairs(selected.tabs) do
                if tab.enabled then page.area = tab.id; break end
            end
        end
    else
        page.tabs = {}
        page.area = nil
    end
    if page.renderedOwner ~= page.selectedOwner or page.renderedArea ~= page.area then
        page.grid:SetVerticalScroll(0)
    end
    page.renderedOwner, page.renderedArea = page.selectedOwner, page.area
    page.selectedHiddenGuildKey = selected and selected.hidden and selected.guildKey or nil
    self:LayoutChrome(page)

    local current = Core.Characters:GetCurrent()
    for index, owner in ipairs(owners) do
        local row = page.ownerRows[index] or CreateOwnerRow(page, index)
        row.ownerKey = owner.key
        local selectedRow = owner.key == page.selectedOwner
        local currentRow = owner.character and current and owner.key == current.id
        row:SetBackdropColor(unpack(selectedRow and Colors.selected or Theme:GetDataRowColor(index)))
        row:SetBackdropBorderColor(unpack(selectedRow and Colors.accent or Colors.lineSoft))
        row.currentMarker:SetShown(currentRow and true or false)
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -3)
        row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", currentRow and -23 or -6, -4)
        row.name:SetHeight(17)
        row.name:SetText(owner.label)
        local classColor = owner.character and RAID_CLASS_COLORS and RAID_CLASS_COLORS[owner.character.class or ""]
        row.name:SetTextColor(classColor and classColor.r or Colors.text[1],
            classColor and classColor.g or Colors.text[2], classColor and classColor.b or Colors.text[3])
        row.meta:SetText((owner.hidden and Addon:T("TEXT.HIDDEN_EXCLUDED_FROM_TOTALS_9EDBA9") or tostring(owner.realm or ""))
            .. (searching and (Addon:T("TEXT.MATCH_6E5E57") .. tostring(owner.matchQuantity)) or ""))
        local coords = owner.character and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[owner.character.class]
        if coords then
            row.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            row.icon:SetTexCoord(unpack(coords))
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
            row.icon:SetTexCoord(0, 1, 0, 1)
        end
        row:Show()
    end
    for index = #owners + 1, #page.ownerRows do page.ownerRows[index]:Hide() end
    page.ownersContent:SetHeight(math.max(1, #owners * (OWNER_HEIGHT + 2)))
    page.owners:SetContentHeight(#owners * (OWNER_HEIGHT + 2))

    local area = selected and ((selected.tabAreas and selected.tabAreas[page.area])
        or (selected.entry and selected.entry[page.area])
        or (page.area == "auction" and selected.auction))
    local showStale = selected and area and area.hasStale
        and (selected.guildKey or current and current.id == selected.key)
    local mailCoverage = selected and page.area == "mail" and selected.character
        and Addon:GetCharacterCoverage(selected.key, "mail").inbox
    local partialMail = mailCoverage and (mailCoverage.unscannedCount or 0) > 0
    page.heading:SetText(selected and (selected.label .. (selected.hidden and Addon:T("TEXT.HIDDEN_EXCLUDED_FROM_TOTAL_EA8796") or "")
        .. (partialMail and (showStale and Addon:T("TEXT.MAIL_WAS_ONLY_PARTLY_VISIBLE_LAST_SCAN_CE80CD") or Addon:T("TEXT.MAIL_IS_ONLY_PARTLY_VISIBLE_760FD7"))
        or showStale and Addon:T("TEXT.LAST_CACHED_E8E0E4") or "")) or Addon:T("TEXT.ITEM_OVERVIEW_70B215"))
    page.identityMeta:SetText(selected and (selected.character and
        (Addon:T("TEXT.LEVEL_347FBE") .. tostring(selected.character.level or "?") .. " · " .. tostring(selected.realm or "") .. " · " .. tostring(selected.character.class or ""))
        or tostring(selected.realm or "")) or "")
    local classCoords = selected and selected.character and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[selected.character.class]
    if classCoords then
        page.identityIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        page.identityIcon:SetTexCoord(unpack(classCoords))
    else
        page.identityIcon:SetTexture(selected and "Interface\\Icons\\INV_Misc_Bag_10" or nil)
        page.identityIcon:SetTexCoord(0, 1, 0, 1)
    end
    local bagArea = selected and selected.entry and selected.entry.bags
    local bankArea = selected and selected.entry and selected.entry.bank
    page.bagCapacity:SetText(bagArea and (Addon:T("TEXT.BAGS_CBB611") .. CapacityText(bagArea)) or "")
    page.bankCapacity:SetText(bankArea and (Addon:T("TEXT.PERSONAL_BANK_32E155") .. CapacityText(bankArea)) or "")
    page.composition:SetText(bagArea and CompositionText(bagArea) or
        (selected and selected.guildKey and CapacityText(area) or ""))

    local records = selected and selected.records[page.area] or {}
    table.sort(records, function(left, right) return tostring(left.sourceID) < tostring(right.sourceID) end)
    local freeSlots = not searching and area and tonumber(area.freeSlots) or nil
    local freeGroups = not searching and Addon.BagCapacity:Group(area, page.area) or nil
    page.slots = selected and self:BuildSlots(records, searching and "search" or page.area, freeSlots, freeGroups) or {}
    local emptyMessage = not selected and Addon:T("TEXT.NO_CHARACTERS_OR_SCANNED_GUILD_BANKS_ARE_I_F21456")
        or not page.area and Addon:T("TEXT.NO_VIEWABLE_SOURCE_HAS_BEEN_SCANNED_YET_63655B")
        or Addon:T("TEXT.NO_RECORDED_ITEMS_IN_THIS_STORAGE_AREA_34E6E1")
    page.empty:SetText(searching and (#page.slots == 0 and Addon:T("TEXT.NO_CACHED_ITEMS_MATCH_89E336") or "")
        or #page.slots == 0 and emptyMessage or "")
    self:LayoutCells(page)
end

function StoragePage:OpenGuild(guildKey)
    if not (Addon.db.byGuild and Addon.db.byGuild[guildKey]) then return end
    self.pendingGuildKey = guildKey
    local page = self.page
    if page then
        page.explicitGuildKey = guildKey
        page.showHiddenGuilds = true
        page.selectedOwner = guildKey
        page.area = nil
        page.search:SetValue("", true)
        -- The explicit refresh after opening the page supersedes the delayed
        -- search refresh scheduled by the shared input's change callback.
        page.searchRefreshSerial = (page.searchRefreshSerial or 0) + 1
    end
    Core.AccountView:ShowPage(Addon.AccountPage.ID)
    page = self.page
    if page then
        self.pendingGuildKey = nil
        page.explicitGuildKey = guildKey
        page.showHiddenGuilds = true
        page.selectedOwner = guildKey
        self:Refresh(page, page.context)
    end
end
