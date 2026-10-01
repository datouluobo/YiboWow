local Addon, Core = _G.YiboCrafting, _G.YiboCore
local Theme = Core.UITheme
local Page = {}
Addon.AccountPage = Page

local ID = "crafting"
local C = Theme.Colors
local H = Theme.Table.rowHeight
local professions = {
    [129] = "急救", [164] = "锻造", [165] = "制皮", [171] = "炼金术",
    [185] = "烹饪", [186] = "采矿", [197] = "裁缝",
    [202] = "工程学", [333] = "附魔", [755] = "珠宝加工", [773] = "铭文",
}
local EXCLUDED_PROFESSIONS = { [182] = true, [393] = true, [356] = true, [794] = true }
local PROFESSION_ORDER = {
    [171] = 10, [164] = 20, [333] = 30, [202] = 40,
    [773] = 60, [755] = 70, [165] = 80, [186] = 90,
    [197] = 110, [185] = 200, [129] = 210,
}
local UNKNOWN_CATEGORY = "unknown"
local function CategoryKey(professionID, category)
    return tostring(professionID) .. ":" .. (category or UNKNOWN_CATEGORY)
end
local requestedItemNames = {}

local function ProductName(itemID)
    if not itemID then return nil end
    local name
    if type(GetItemInfo) == "function" then name = GetItemInfo(itemID) end
    if not name and C_Item and type(C_Item.GetItemNameByID) == "function" then
        name = C_Item.GetItemNameByID(itemID)
    end
    if name then return name end
    if not requestedItemNames[itemID] and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        requestedItemNames[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

local function Label(parent, size, color, justify)
    return Theme:CreateText(parent, size or Theme.Font.body, color or C.text, justify or "LEFT")
end

local function SetColor(text, color)
    text:SetTextColor(color[1], color[2], color[3])
end

local function Panel(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], C.panel[4])
    frame:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
    return frame
end

local function CharacterName(character, context)
    local name = character.name or "未知角色"
    if context.scope == "all" and character.realm then return name .. "-" .. character.realm end
    return name
end

local function ColoredCharacterName(character, context)
    local name = CharacterName(character, context)
    local class = character.class or ""
    local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if not color then return name end
    local function Channel(value)
        return math.floor(math.max(0, math.min(1, value or 1)) * 255 + 0.5)
    end
    return string.format("|cff%02x%02x%02x%s|r", Channel(color.r), Channel(color.g), Channel(color.b), name)
end

local function MatrixCharacterWidth()
    -- Status cells fit their two-character values. Long names wrap in headers
    -- instead of widening every character column.
    return math.ceil(Theme:MeasureText(Theme.Font.assist, "字字字字") + Theme.Table.cellInset * 2 + Theme.Table.iconTextRasterTolerance)
end

local function MatrixCharacterMinWidth()
    -- Two-character status values stay readable; long character names wrap.
    return math.ceil(Theme:MeasureText(Theme.Font.assist, "字字字") + Theme.Table.cellInset * 2 + Theme.Table.iconTextRasterTolerance)
end

local function ProfessionName(id, names)
    return names[id] or professions[id] or ("专业 " .. tostring(id))
end

local function CharacterHasProfession(characterID, professionID)
    local domain = Core.DataDomains:Get(characterID, "professions")
    if domain and domain.state == "known" and domain.data and type(domain.data.professions) == "table" then
        for _, profession in ipairs(domain.data.professions) do
            if profession.id == professionID then return true end
        end
        return false
    end
    local stored = Addon.Store:GetProfession(characterID, professionID)
    return stored and next(stored.learnedRecipeIDs or {}) ~= nil or false
end

local function ItemIcon(itemID)
    if not itemID then return nil end
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok and icon then return icon end
    end
    if type(GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, icon = pcall(GetItemInfoInstant, itemID)
        if ok and icon then return icon end
    end
    if type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon then return icon end
    end
end

local function RecipeInfo(id)
    local name = GetSpellInfo and GetSpellInfo(id)
    local icon = GetSpellTexture and GetSpellTexture(id)
    return name or ("配方 #" .. tostring(id)), icon
end

function Page:Snapshot(context)
    local names, ids, records = {}, {}, {}
    for _, character in ipairs(context.characters or {}) do
        local domain = Core.DataDomains:Get(character.id, "professions")
        for _, profession in ipairs(domain and domain.data and domain.data.professions or {}) do
            if profession.id and profession.name then names[profession.id] = profession.name end
        end
        for _, profession in ipairs(domain and domain.data and domain.data.professions or {}) do
            if profession.id and not EXCLUDED_PROFESSIONS[profession.id] then ids[profession.id] = true end
        end
    end
    -- Observed recipes form an account-wide provisional index. Scope changes
    -- only the character columns, never whether a recorded recipe exists.
    for _, stored in pairs(Addon.Store.db.characters) do
        for professionID, profession in pairs(stored.professions or {}) do
            if not EXCLUDED_PROFESSIONS[professionID] then
                for recipeID in pairs(profession.learnedRecipeIDs or {}) do
                    if type(recipeID) == "number" and type(professionID) == "number" then
                        local key = professionID .. ":" .. recipeID
                        if not records[key] then
                            local name, spellIcon = RecipeInfo(recipeID)
                            records[key] = {
                                key = key, id = recipeID, professionID = professionID,
                                name = name, spellIcon = spellIcon,
                                category = (profession.recipeCategories and profession.recipeCategories[recipeID])
                                    or Addon.CategoryCatalog:Get(professionID, recipeID),
                            }
                            ids[professionID] = true
                        end
                        local outputItemID = profession.outputItemIDs and profession.outputItemIDs[recipeID]
                        local category = profession.recipeCategories and profession.recipeCategories[recipeID]
                        if category and not records[key].category then records[key].category = category end
                        if outputItemID and not records[key].outputItemID then
                            records[key].outputItemID = outputItemID
                        end
                    end
                end
            end
        end
    end
    local list, professionList = {}, {}
    for _, entry in pairs(records) do
        entry.icon = ItemIcon(entry.outputItemID) or entry.spellIcon
        list[#list + 1] = entry
    end
    for professionID in pairs(ids) do
        professionList[#professionList + 1] = { id = professionID, name = ProfessionName(professionID, names) }
    end
    table.sort(professionList, function(a, b)
        local left, right = PROFESSION_ORDER[a.id] or 150, PROFESSION_ORDER[b.id] or 150
        if left ~= right then return left < right end
        return a.name < b.name
    end)
    table.sort(list, function(a, b)
        local leftOrder, rightOrder = PROFESSION_ORDER[a.professionID] or 150, PROFESSION_ORDER[b.professionID] or 150
        if leftOrder ~= rightOrder then return leftOrder < rightOrder end
        local left, right = ProfessionName(a.professionID, names), ProfessionName(b.professionID, names)
        if left ~= right then return left < right end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return list, professionList, names
end

function Page:ProfessionsForCharacter(professionList, characterID)
    if not characterID then return professionList end
    local visible = {}
    for _, profession in ipairs(professionList) do
        if CharacterHasProfession(characterID, profession.id) then visible[#visible + 1] = profession end
    end
    return visible
end

function Page:Filtered(entries, characters, state)
    local result, query = {}, (state.search or ""):lower()
    for _, entry in ipairs(entries) do
        local matchesProfession = not state.profession or entry.professionID == state.profession
        local matchesCategory = not state.category or CategoryKey(entry.professionID, entry.category) == state.category
        if matchesProfession and matchesCategory then
            local matchesName = query == "" or entry.name:lower():find(query, 1, true)
                or tostring(entry.id):find(query, 1, true)
                or (entry.outputItemID and tostring(entry.outputItemID):find(query, 1, true))
            if not matchesName and entry.outputItemID then
                local productName = ProductName(entry.outputItemID)
                matchesName = productName and productName:lower():find(query, 1, true)
            end
            if matchesName then
                local matchesCharacter = not state.character or Addon.Store:GetRecipeState(state.character, entry.professionID, entry.id) == "learned"
                local matchesStatus = true
                if state.status == "learned" then
                    matchesStatus = false
                    for _, character in ipairs(characters) do
                        if Addon.Store:GetRecipeState(character.id, entry.professionID, entry.id) == "learned" then matchesStatus = true; break end
                    end
                elseif state.status == "unknown" then
                    matchesStatus = false
                    for _, character in ipairs(characters) do
                        if Addon.Store:GetRecipeState(character.id, entry.professionID, entry.id) ~= "learned" then matchesStatus = true; break end
                    end
                end
                if matchesCharacter and matchesStatus then result[#result + 1] = entry end
            end
        end
    end
    return result
end

local function Row(parent, index)
    local row = parent.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, parent.body, "BackdropTemplate")
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.name = Label(row)
    row.meta = Label(row, Theme.Font.assist, C.muted)
    row.cells = {}
    row.rule = row:CreateTexture(nil, "OVERLAY")
    row.rule:SetColorTexture(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
    row.rule:SetHeight(1); row.rule:SetPoint("BOTTOMLEFT"); row.rule:SetPoint("BOTTOMRIGHT")
    parent.rows[index] = row
    return row
end

local function ClearRows(panel, from)
    for index = from, #panel.rows do panel.rows[index]:Hide() end
end

local function SetProductHit(row, entry, iconOffset, iconSize, onClick)
    local hit = row.iconHit
    if not hit then
        hit = CreateFrame("Button", nil, row)
        row.iconHit = hit
    end
    if not entry.outputItemID then hit:Hide(); return end
    hit:ClearAllPoints(); hit:SetPoint("LEFT", row, "LEFT", iconOffset, 0)
    hit:SetSize(iconSize, iconSize)
    hit:SetScript("OnEnter", function(self) Page:ShowItemTooltip(self, entry) end)
    hit:SetScript("OnLeave", function()
        if row.nameHit and row.nameHit:IsShown() and row.nameHit:IsMouseOver() then
            Page:ShowRecipeTooltip(row.nameHit, entry)
        else GameTooltip:Hide() end
    end)
    hit:SetScript("OnClick", function(self)
        onClick()
        Page:ShowItemTooltip(self, entry)
    end)
    hit:Show()
end

local function PositionScroll(panel, top)
    panel.scroll:ClearAllPoints()
    panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -top)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
end

-- Scroll over the complete catalog while retaining only enough row frames for
-- the visible viewport. The scroll child still has the full catalog height.
local function RenderVisibleRows(panel, items, totalHeight, paint)
    panel.visibleItems = items
    panel.paintVisible = paint
    local lastFirst, lastLast
    panel.renderVisible = function(force)
        local offset = panel.scroll:GetVerticalScroll() or 0
        local height = math.max(1, panel.scroll:GetHeight() or 1)
        local maxOffset = math.max(0, totalHeight - height)
        if offset > maxOffset then
            offset = maxOffset
            panel.scroll:SetVerticalScroll(offset)
        end
        local low, high = 1, #panel.visibleItems
        while low <= high do
            local middle = math.floor((low + high) / 2)
            local item = panel.visibleItems[middle]
            if item.top + item.height <= offset then low = middle + 1
            else high = middle - 1 end
        end
        local last = low - 1
        for index = low, #panel.visibleItems do
            local item = panel.visibleItems[index]
            if item.top > offset + height + H then break end
            last = index
        end
        if not force and low == lastFirst and last == lastLast then return end
        lastFirst, lastLast = low, last
        local count = 0
        for index = low, last do
            local item = panel.visibleItems[index]
            count = count + 1
            local row = Row(panel, count)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 0, -item.top)
            row:SetSize(panel.contentWidth, item.height)
            panel.paintVisible(row, item, index)
            row:Show()
        end
        ClearRows(panel, count + 1)
    end
    panel.body:SetSize(math.max(1, panel.contentWidth), math.max(1, totalHeight))
    panel.scroll:SetContentHeight(totalHeight)
    panel.renderVisible()
    panel.scroll:RefreshScrollbar()
end

local function BindVisibleRows(panel)
    panel.scroll:HookScript("OnVerticalScroll", function()
        GameTooltip:Hide()
        if panel.renderVisible then panel.renderVisible() end
    end)
    panel.scroll:HookScript("OnSizeChanged", function() if panel.renderVisible then panel.renderVisible() end end)
end

function Page:Create(parent)
    parent.crafting = {}
    local ui = parent.crafting
    ui.toolbar = CreateFrame("Frame", nil, parent)
    ui.search = CreateFrame("EditBox", nil, ui.toolbar, "InputBoxTemplate")
    ui.search:SetAutoFocus(false)
    ui.search:SetMaxLetters(80)
    ui.search:SetHeight(28)
    ui.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ui.search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ui.searchGeneration = (ui.searchGeneration or 0) + 1
        if ui.search:IsShown() and ui.renderedSearch ~= ui.state.search then Page:RenderResults(parent) end
    end)
    ui.search:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        ui.state.search = self:GetText() or ""
        ui.searchGeneration = (ui.searchGeneration or 0) + 1
        local generation = ui.searchGeneration
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                if generation == ui.searchGeneration and ui.search:IsShown()
                    and ui.renderedSearch ~= ui.state.search then
                    Page:RenderResults(parent)
                end
            end)
        elseif ui.search:IsShown() then
            Page:RenderResults(parent)
        end
    end)
    ui.searchHint = Label(ui.toolbar, Theme.Font.assist, C.muted)
    ui.searchHint:SetText("搜索配方、产物或 ID")
    ui.searchHint:SetPoint("LEFT", ui.search, "LEFT", 6, 0)
    ui.search:SetScript("OnEditFocusGained", function() ui.searchHint:Hide() end)
    ui.search:SetScript("OnEditFocusLost", function(self) ui.searchHint:SetShown(self:GetText() == "") end)
    ui.profession = Theme:CreateDropdown(ui.toolbar, 130)
    ui.category = Theme:CreateDropdown(ui.toolbar, 110)
    ui.character = Theme:CreateDropdown(ui.toolbar, 120)
    ui.status = Theme:CreateDropdown(ui.toolbar, 110)
    ui.modeRecipe = Theme:CreateButton(ui.toolbar, 66, "配方", "secondary")
    ui.modeProfession = Theme:CreateButton(ui.toolbar, 66, "专业", "secondary")
    for mode, button in pairs({ recipes = ui.modeRecipe, professions = ui.modeProfession }) do
        button:SetScript("OnClick", function()
            if mode == "professions" and ui.state.professionFilter then
                ui.state.profession = ui.state.professionFilter
                ui.state.selectedRecipe = nil
                ui.list.scroll:SetVerticalScroll(0)
            end
            ui.state.category = nil
            Addon.Store.db.settings.viewMode = mode
            Core.AccountView:NotifyPageChanged(ID)
        end)
    end
    ui.matrix = Panel(parent)
    ui.matrix.header = CreateFrame("Frame", nil, ui.matrix)
    ui.matrix.header.title = Label(ui.matrix.header, Theme.Font.assist, C.muted)
    ui.matrix.header.cells = {}
    ui.matrix.scroll = Theme:CreateScrollFrame(ui.matrix)
    ui.matrix.body = CreateFrame("Frame", nil, ui.matrix.scroll)
    ui.matrix.scroll:SetScrollChild(ui.matrix.body)
    ui.matrix.rows = {}
    BindVisibleRows(ui.matrix)
    ui.matrix.empty = Label(ui.matrix, Theme.Font.body, C.muted)
    ui.matrix.empty:SetPoint("CENTER")
    ui.professions = Panel(parent)
    ui.professions.title = Label(ui.professions, Theme.Font.section, C.text)
    ui.professions.title:SetText("专业")
    ui.professions.scroll = Theme:CreateScrollFrame(ui.professions)
    ui.professions.body = CreateFrame("Frame", nil, ui.professions.scroll)
    ui.professions.scroll:SetScrollChild(ui.professions.body)
    ui.professions.rows = {}
    ui.professions.empty = Label(ui.professions, Theme.Font.assist, C.muted, "CENTER")
    ui.professions.empty:SetPoint("CENTER", ui.professions, "CENTER", 0, -12)
    ui.professions.empty:SetHeight(80)
    ui.professions.empty:SetWordWrap(true)
    ui.list = Panel(parent)
    ui.list.header = Label(ui.list, Theme.Font.assist, C.muted)
    ui.list.scroll = Theme:CreateScrollFrame(ui.list)
    ui.list.body = CreateFrame("Frame", nil, ui.list.scroll)
    ui.list.scroll:SetScrollChild(ui.list.body)
    ui.list.rows = {}
    BindVisibleRows(ui.list)
    ui.list.empty = Label(ui.list, Theme.Font.body, C.muted, "CENTER")
    ui.list.empty:SetPoint("CENTER", ui.list, "CENTER")
    ui.list.empty:SetWordWrap(true)
    ui.detail = Panel(parent)
    ui.detail.title = Label(ui.detail, Theme.Font.section, C.text)
    ui.detail.icon = ui.detail:CreateTexture(nil, "ARTWORK")
    ui.detail.iconHit = CreateFrame("Button", nil, ui.detail)
    ui.detail.name = Label(ui.detail, Theme.Font.section, C.accent)
    ui.detail.meta = Label(ui.detail, Theme.Font.body, C.text)
    ui.detail.note = Label(ui.detail, Theme.Font.assist, C.warning)
    ui.detail.note:SetWordWrap(true)
    ui.detail.characters = Theme:CreateScrollFrame(ui.detail)
    ui.detail.scroll = ui.detail.characters
    ui.detail.body = CreateFrame("Frame", nil, ui.detail.characters)
    ui.detail.characters:SetScrollChild(ui.detail.body)
    ui.detail.rows = {}
    BindVisibleRows(ui.detail)
    ui.detail.empty = Label(ui.detail, Theme.Font.assist, C.muted, "CENTER")
    ui.detail.empty:SetPoint("CENTER", ui.detail.characters, "CENTER")
    ui.detail.empty:SetText("当前范围没有拥有该专业的角色。")
    ui.footer = Label(parent, Theme.Font.assist, C.muted)
    ui.rolePagerAnchor = CreateFrame("Frame", nil, parent)
    ui.rolePagerAnchor:SetSize(1, 26)
    ui.state = { search = "" }
    ui.itemEvents = CreateFrame("Frame")
    ui.itemEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ui.itemEvents:SetScript("OnEvent", function(_, _, itemID, success)
        if requestedItemNames[itemID] then
            if success then requestedItemNames[itemID] = nil
            else requestedItemNames[itemID] = "failed" end
            if success and ui.state.search ~= "" and not ui.pendingItemRefresh then
                ui.pendingItemRefresh = true
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.15, function()
                        ui.pendingItemRefresh = nil
                        if ui.search:IsShown() then Page:RenderResults(parent) end
                    end)
                else
                    ui.pendingItemRefresh = nil
                    if ui.search:IsShown() then Page:RenderResults(parent) end
                end
            end
        end
    end)
end

function Page:Layout(parent, context, mode)
    local ui = parent.crafting
    local inset = Theme:GetMatrixInsets(false)
    local width = math.max(1, (context.surfaceAvailableWidth or parent:GetWidth() or 900) - inset.left - inset.right)
    ui.toolbar:ClearAllPoints(); ui.toolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    ui.toolbar:SetSize(width, 32)
    local modeWidth = 136 -- two 66px tabs plus their 4px gap
    local gapBudget = mode == "recipes" and 34 or 28
    local characterWidth = math.max(96, math.min(136, math.floor(width * 0.14)))
    local professionWidth = mode == "recipes" and math.max(88, math.min(108, math.floor(width * 0.11))) or 0
    local categoryWidth = math.max(88, math.min(100, math.floor(width * 0.10)))
    local statusWidth = math.max(88, math.min(100, math.floor(width * 0.10)))
    local fixedWidth = characterWidth + professionWidth + categoryWidth + statusWidth + modeWidth + gapBudget + 12
    local searchWidth = math.max(120, math.min(300, width - fixedWidth))
    ui.profession:SetWidth(professionWidth); ui.character:SetWidth(characterWidth)
    ui.category:SetWidth(categoryWidth); ui.status:SetWidth(statusWidth)
    ui.modeProfession:ClearAllPoints(); ui.modeProfession:SetPoint("RIGHT", ui.toolbar, "RIGHT", -2, 0)
    ui.modeRecipe:ClearAllPoints(); ui.modeRecipe:SetPoint("RIGHT", ui.modeProfession, "LEFT", -4, 0)
    ui.search:ClearAllPoints(); ui.search:SetPoint("LEFT", ui.toolbar, "LEFT", 6, 0)
    ui.search:SetWidth(searchWidth)
    ui.character:ClearAllPoints(); ui.character:SetPoint("LEFT", ui.search, "RIGHT", 6, 0)
    ui.profession:ClearAllPoints(); ui.profession:SetPoint("LEFT", ui.character, "RIGHT", 4, 0)
    ui.profession:SetShown(mode == "recipes")
    if mode ~= "recipes" then ui.profession.menu:Hide() end
    ui.category:ClearAllPoints()
    if mode == "recipes" then ui.category:SetPoint("LEFT", ui.profession, "RIGHT", 4, 0)
    else ui.category:SetPoint("LEFT", ui.character, "RIGHT", 6, 0) end
    ui.status:ClearAllPoints(); ui.status:SetPoint("LEFT", ui.category, "RIGHT", 4, 0)
    local contentTop = ui.toolbar
    ui.footer:ClearAllPoints(); ui.footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset.left + 2, inset.bottom)
    ui.footer:SetWidth(math.max(240, width * 0.72)); ui.footer:SetWordWrap(false)
    ui.rolePagerAnchor:ClearAllPoints()
    ui.rolePagerAnchor:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    if mode == "recipes" then
        ui.matrixWidth = width
        ui.professions:Hide(); ui.list:Hide(); ui.detail:Hide(); ui.matrix:Show()
        ui.matrix:ClearAllPoints(); ui.matrix:SetPoint("TOPLEFT", contentTop, "BOTTOMLEFT", 0, -5)
        ui.matrix:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom + 32)
    else
        ui.matrix:Hide(); ui.professions:Show(); ui.list:Show(); ui.detail:Show()
        local left = math.min(140, math.max(126, math.floor(width * 0.15)))
        local right = math.min(325, math.max(300, math.floor(width * 0.36)))
        local middle = math.max(180, width - left - right - 10)
        ui.professionWidth, ui.listWidth, ui.detailWidth = left, middle, right
        ui.professions:ClearAllPoints(); ui.professions:SetPoint("TOPLEFT", contentTop, "BOTTOMLEFT", 0, -5)
        ui.professions:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset.left, inset.bottom + 32)
        ui.professions:SetWidth(left)
        ui.list:ClearAllPoints(); ui.list:SetPoint("TOPLEFT", ui.professions, "TOPRIGHT", 5, 0)
        ui.list:SetPoint("BOTTOMLEFT", ui.professions, "BOTTOMRIGHT", 5, 0); ui.list:SetWidth(middle)
        ui.detail:ClearAllPoints(); ui.detail:SetPoint("TOPLEFT", ui.list, "TOPRIGHT", 5, 0)
        ui.detail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom + 32)
    end
end

local function RenderSimpleList(panel, entries, selected, width, click)
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -11)
    panel.scroll:ClearAllPoints(); panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -42)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    width = math.max(1, width - 2)
    for index, entry in ipairs(entries) do
        local row = Row(panel, index)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 0, -(index - 1) * 38)
        row:SetSize(width, 38)
        local fill = selected == entry.id and C.selected or (index % 2 == 0 and C.alternate or C.row)
        row:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
        row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", row, "LEFT", 9, 0); row.icon:SetSize(25, 25)
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0); row.name:SetText(entry.name)
        row.meta:Hide()
        row:SetScript("OnClick", function() click(entry.id) end)
        row:Show()
    end
    ClearRows(panel, #entries + 1)
    panel.body:SetSize(width, math.max(1, #entries * 38))
    panel.scroll:SetContentHeight(#entries * 38); panel.scroll:RefreshScrollbar()
end

local function HasGameTooltipContent()
    return GameTooltip:NumLines() > 0
end

function Page:ShowRecipeTooltip(owner, entry)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    local shown = false
    if GameTooltip.SetSpellByID then
        local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, entry.id)
        shown = ok and HasGameTooltipContent()
    end
    if not shown and GameTooltip.SetHyperlink then
        GameTooltip:ClearLines()
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. entry.id)
        shown = ok and HasGameTooltipContent()
    end
    if not shown then
        GameTooltip:ClearLines()
        GameTooltip:SetText(entry.name)
    end
    GameTooltip:Show()
end

function Page:ShowItemTooltip(owner, entry)
    if not entry.outputItemID then return self:ShowRecipeTooltip(owner, entry) end
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    local shown = false
    if GameTooltip.SetItemByID then
        local ok = pcall(GameTooltip.SetItemByID, GameTooltip, entry.outputItemID)
        shown = ok and HasGameTooltipContent()
    end
    if not shown and GameTooltip.SetHyperlink then
        GameTooltip:ClearLines()
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. entry.outputItemID)
        shown = ok and HasGameTooltipContent()
    end
    if not shown then
        GameTooltip:ClearLines()
        GameTooltip:SetText(ProductName(entry.outputItemID) or entry.name)
    end
    GameTooltip:Show()
end

local function SetRecipeNameHit(row, entry, left, width, onClick)
    local hit = row.nameHit
    if not hit then
        hit = CreateFrame("Button", nil, row)
        row.nameHit = hit
    end
    hit:ClearAllPoints(); hit:SetPoint("LEFT", row, "LEFT", left, 0)
    hit:SetSize(math.max(1, width), row:GetHeight())
    hit:SetScript("OnEnter", function(self) Page:ShowRecipeTooltip(self, entry) end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hit:SetScript("OnClick", onClick)
    hit:Show()
    row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
end

function Page:RenderMatrix(parent, context, entries, names)
    local ui, panel = parent.crafting, parent.crafting.matrix
    local characters = context.characters or {}
    local width = math.max(1, ui.matrixWidth - 2)
    local recipeWidth = math.max(225, Theme:GetIconTextColumnWidth(23, Theme.Font.body, "配方名称", 8))
    local characterWidth = Core.AccountView:FitRepeatedColumnWidth(
        width, recipeWidth, #characters, MatrixCharacterWidth(), MatrixCharacterMinWidth())
    local shown, pageInfo = Core.AccountView:GetColumnPage(ID, "characters", characters, width, recipeWidth, characterWidth)
    local displayCharacters = #entries > 0 and shown or {}
    panel.header:ClearAllPoints(); panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    panel.header:SetSize(width, 42)
    panel.header.title:ClearAllPoints(); panel.header.title:SetPoint("LEFT", panel.header, "LEFT", 8, 0)
    panel.header.title:SetText("配方名称 · 专业")
    for index, character in ipairs(displayCharacters) do
        local label = panel.header.cells[index] or Label(panel.header, Theme.Font.assist, C.muted, "CENTER")
        panel.header.cells[index] = label
        label:ClearAllPoints(); label:SetPoint("LEFT", panel.header, "LEFT", recipeWidth + (index - 1) * characterWidth, 0)
        label:SetSize(characterWidth, 40)
        label:SetWordWrap(true)
        label:SetText(Core.Characters:GetDisplayName(character, "short") or character.name or "未知角色")
        label:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(CharacterName(character, context), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        label:SetScript("OnLeave", function() GameTooltip:Hide() end)
        label:Show()
    end
    for index = #displayCharacters + 1, #panel.header.cells do panel.header.cells[index]:Hide() end
    PositionScroll(panel, 43)
    local items, top, lastProfession = {}, 0, nil
    for _, entry in ipairs(entries) do
        if entry.professionID ~= lastProfession then
            items[#items + 1] = { kind = "group", name = ProfessionName(entry.professionID, names), top = top, height = 26 }
            top = top + 26
            lastProfession = entry.professionID
        end
        items[#items + 1] = { kind = "recipe", entry = entry, top = top, height = H }
        top = top + H
    end
    panel.contentWidth = width
    RenderVisibleRows(panel, items, top, function(row, item, index)
        row.meta:Hide()
        if item.kind == "group" then
            row:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], C.panel[4])
            row.icon:Hide()
            if row.iconHit then row.iconHit:Hide() end
            row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row, "LEFT", 9, 0)
            row.name:SetWidth(recipeWidth - 18); row.name:SetText(item.name); SetColor(row.name, C.muted)
            for _, cell in ipairs(row.cells) do cell:Hide() end
            if row.nameHit then row.nameHit:Hide() end
            row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil); row:SetScript("OnClick", nil)
            return
        end
        local entry = item.entry
        local fill = entry.key == ui.state.selectedRecipe and C.selected or (index % 2 == 0 and C.alternate or C.row)
        row:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
        row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", row, "LEFT", 7, 0); row.icon:SetSize(21, 21)
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); row.icon:Show()
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetWidth(recipeWidth - 36); row.name:SetText(entry.name); SetColor(row.name, C.text)
        for cellIndex, character in ipairs(shown) do
            local cell = row.cells[cellIndex] or Label(row, Theme.Font.assist, C.muted, "CENTER")
            row.cells[cellIndex] = cell
            cell:ClearAllPoints(); cell:SetPoint("LEFT", row, "LEFT", recipeWidth + (cellIndex - 1) * characterWidth, 0)
            cell:SetSize(characterWidth, H)
            local learned = Addon.Store:GetRecipeState(character.id, entry.professionID, entry.id) == "learned"
            cell:SetText(learned and "已学" or "？")
            SetColor(cell, learned and C.accent or C.warning)
            cell:Show()
        end
        for cellIndex = #shown + 1, #row.cells do row.cells[cellIndex]:Hide() end
        local function SelectRecipe()
            ui.state.selectedRecipe = entry.key
            panel.renderVisible(true)
        end
        row:SetScript("OnClick", SelectRecipe)
        SetRecipeNameHit(row, entry, 34, recipeWidth - 36, SelectRecipe)
        SetProductHit(row, entry, 7, 21, SelectRecipe)
    end)
    panel.empty:SetShown(#entries == 0)
    panel.empty:SetWidth(math.max(220, width - 48))
    panel.empty:SetWordWrap(true)
    if #entries == 0 then
        local hasFilter = ui.state.search ~= "" or ui.state.professionFilter or ui.state.category or ui.state.character or ui.state.status
        panel.empty:SetText(hasFilter and "当前筛选下没有已记录配方。" or "尚无已记录配方\n在拥有专业的角色上打开本人专业窗口后，插件会采集客户端可确认的已学配方。")
    end
    Core.AccountView:UpdateColumnPager(parent, ID, "characters", #entries > 0 and pageInfo or nil, ui.rolePagerAnchor, "角色")
    if #characters == 0 then ui.footer:SetText("当前范围没有角色 · 目录覆盖未验证")
    else ui.footer:SetText("？ = 待确认 · 仅显示客户端确认并缓存的配方；目录未验证，缺少记录不代表未学") end
end

function Page:RenderDetail(parent, context, entry, names)
    local detail = parent.crafting.detail
    detail.title:ClearAllPoints(); detail.title:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -11)
    detail.title:SetText("配方详情")
    detail.icon:ClearAllPoints(); detail.icon:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -50)
    detail.icon:SetSize(42, 42)
    detail.iconHit:ClearAllPoints(); detail.iconHit:SetAllPoints(detail.icon)
    detail.name:ClearAllPoints(); detail.name:SetPoint("LEFT", detail.icon, "RIGHT", 10, 0)
    detail.name:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
    detail.meta:ClearAllPoints(); detail.meta:SetPoint("TOPLEFT", detail.icon, "BOTTOMLEFT", 0, -16)
    detail.meta:SetPoint("RIGHT", detail, "RIGHT", -10, 0); detail.meta:SetHeight(64)
    detail.note:ClearAllPoints(); detail.note:SetPoint("TOPLEFT", detail.meta, "BOTTOMLEFT", 0, -10)
    detail.note:SetPoint("RIGHT", detail, "RIGHT", -10, 0); detail.note:SetHeight(54)
    detail.characters:ClearAllPoints(); detail.characters:SetPoint("TOPLEFT", detail.note, "BOTTOMLEFT", 0, -12)
    detail.characters:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -12, 10)
    detail.icon:SetTexture(entry and (entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark") or nil)
    detail.icon:SetShown(entry ~= nil)
    detail.iconHit:SetShown(entry ~= nil)
    detail.iconHit:SetScript("OnEnter", entry and function(self) Page:ShowItemTooltip(self, entry) end or nil)
    detail.iconHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    detail.name:SetText(entry and entry.name or "选择一项配方")
    detail.meta:SetText(entry and ("专业：" .. ProfessionName(entry.professionID, names)
        .. "\n分类：" .. (entry.category or "待分类")
        .. "\n配方 ID：" .. entry.id .. "\n取得状态：未知") or "")
    detail.note:SetText(entry and "仅能确认已记录角色。缺少完整扫描证据，其余角色保持待确认。" or "从左侧选择专业，再从中间列表选择已记录配方。")
    local width = math.max(1, parent.crafting.detailWidth - 26)
    local recipeKey = entry and entry.key
    if detail.currentRecipeKey ~= recipeKey then
        detail.currentRecipeKey = recipeKey
        detail.characters:SetVerticalScroll(0)
    end
    local items = {}
    for _, character in ipairs(entry and context.characters or {}) do
        if CharacterHasProfession(character.id, entry.professionID) then
            items[#items + 1] = { character = character, top = #items * 32, height = 32 }
        end
    end
    detail.contentWidth = width
    RenderVisibleRows(detail, items, #items * 32, function(row, item, index)
        local character = item.character
        local fill = index % 2 == 0 and C.alternate or C.row
        row:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
        row.icon:Hide(); row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.name:SetWidth(math.max(1, width - 95)); row.name:SetText(CharacterName(character, context))
        row.meta:ClearAllPoints(); row.meta:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.meta:SetWidth(80)
        local learned = Addon.Store:GetRecipeState(character.id, entry.professionID, entry.id) == "learned"
        row.meta:SetText(learned and "已学" or "待确认")
        SetColor(row.meta, learned and C.accent or C.warning)
        row:SetScript("OnClick", nil)
    end)
    detail.empty:SetShown(entry ~= nil and #items == 0)
end

function Page:RenderProfessionMode(parent, context, entries, professionList, names)
    local ui = parent.crafting
    local visibleProfessions = self:ProfessionsForCharacter(professionList, ui.state.character)
    local foundProfession = false
    for _, profession in ipairs(visibleProfessions) do
        if profession.id == ui.state.profession then foundProfession = true; break end
    end
    if not foundProfession then
        ui.state.profession = visibleProfessions[1] and visibleProfessions[1].id
        ui.state.selectedRecipe = nil
        ui.list.scroll:SetVerticalScroll(0)
    end
    local professionRows = {}
    for _, profession in ipairs(visibleProfessions) do
        local icon
        for _, character in ipairs(context.characters) do
            local domain = Core.DataDomains:Get(character.id, "professions")
            for _, item in ipairs(domain and domain.data and domain.data.professions or {}) do
                if item.id == profession.id then icon = item.icon; break end
            end
            if icon then break end
        end
        professionRows[#professionRows + 1] = { id = profession.id, name = profession.name, icon = icon }
    end
    RenderSimpleList(ui.professions, professionRows, ui.state.profession, ui.professionWidth, function(id)
        ui.state.profession = id; ui.state.selectedRecipe = nil; ui.state.category = nil
        ui.list.scroll:SetVerticalScroll(0)
        Core.AccountView:NotifyPageChanged(ID)
    end)
    ui.professions.empty:SetWidth(math.max(110, ui.professionWidth - 20))
    ui.professions.empty:SetText(ui.state.character and "该角色暂无已同步的专业\n登录该角色后更新专业信息。" or "当前范围没有专业数据。")
    ui.professions.empty:SetShown(#professionRows == 0)
    local selected = {}
    for _, entry in ipairs(entries) do
        if entry.professionID == ui.state.profession then selected[#selected + 1] = entry end
    end
    ui.list.header:ClearAllPoints(); ui.list.header:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 12, -12)
    ui.list.header:SetText("配方 · 已记录 " .. #selected)
    ui.list.scroll:ClearAllPoints(); ui.list.scroll:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 1, -42)
    ui.list.scroll:SetPoint("BOTTOMRIGHT", ui.list, "BOTTOMRIGHT", -1, 1)
    local width = math.max(1, ui.listWidth - 2)
    local selectedEntry
    for _, entry in ipairs(selected) do
        if entry.key == ui.state.selectedRecipe then selectedEntry = entry; break end
    end
    if not selectedEntry and selected[1] then
        selectedEntry = selected[1]; ui.state.selectedRecipe = selectedEntry.key
    end
    local items = {}
    for index, entry in ipairs(selected) do
        items[index] = { entry = entry, top = (index - 1) * 42, height = 42 }
    end
    ui.list.contentWidth = width
    RenderVisibleRows(ui.list, items, #selected * 42, function(row, item, index)
        local entry = item.entry
        local fill = entry.key == ui.state.selectedRecipe and C.selected or (index % 2 == 0 and C.alternate or C.row)
        row:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
        row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", row, "LEFT", 8, 0); row.icon:SetSize(27, 27)
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); row.icon:Show()
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0); row.name:SetText(entry.name); SetColor(row.name, C.text)
        row.meta:Hide()
        local function SelectRecipe()
            ui.state.selectedRecipe = entry.key
            ui.list.renderVisible(true)
            self:RenderDetail(parent, context, entry, names)
        end
        row:SetScript("OnClick", SelectRecipe)
        SetRecipeNameHit(row, entry, 43, width - 47, SelectRecipe)
        SetProductHit(row, entry, 8, 27, SelectRecipe)
    end)
    ui.list.empty:ClearAllPoints(); ui.list.empty:SetPoint("CENTER", ui.list, "CENTER", 0, -12)
    ui.list.empty:SetWidth(math.max(140, width - 32))
    local emptyText = ""
    if #visibleProfessions == 0 then
        emptyText = ui.state.character and "该角色没有可查看的专业。" or "当前范围没有可查看的专业。"
    elseif #selected == 0 then
        emptyText = #entries == 0
            and "尚无已记录配方\n在拥有该专业的角色上打开本人专业窗口后，插件会采集可确认的配方。"
            or "当前专业没有符合筛选条件的已记录配方。"
    end
    ui.list.empty:SetText(emptyText)
    ui.list.empty:SetShown(#selected == 0)
    self:RenderDetail(parent, context, selectedEntry, names)
    ui.footer:SetText("仅显示客户端确认并缓存的配方 · 在本人专业窗口展开分类可补齐分类 · 缺少记录不代表未学")
end

function Page:RenderResults(parent)
    local ui = parent.crafting
    if not ui or not ui.snapshot then return end
    GameTooltip:Hide()
    local snapshot = ui.snapshot
    local mode = Addon.Store.db.settings.viewMode == "professions" and "professions" or "recipes"
    if ui.renderedSearch ~= ui.state.search then
        ui.matrix.scroll:SetVerticalScroll(0)
        ui.list.scroll:SetVerticalScroll(0)
    end
    local filtered = self:Filtered(snapshot.entries, snapshot.context.characters or {}, {
        search = ui.state.search, profession = mode == "recipes" and ui.state.professionFilter or nil,
        category = ui.state.category, character = ui.state.character, status = ui.state.status,
    })
    if mode == "recipes" then self:RenderMatrix(parent, snapshot.context, filtered, snapshot.names)
    else self:RenderProfessionMode(parent, snapshot.context, filtered, snapshot.professionList, snapshot.names) end
    ui.renderedSearch = ui.state.search
end

function Page:Refresh(parent, context)
    local ui = parent.crafting
    ui.searchGeneration = (ui.searchGeneration or 0) + 1
    local entries, professionList, names = self:Snapshot(context)
    local mode = Addon.Store.db.settings.viewMode == "professions" and "professions" or "recipes"
    ui.modeRecipe:SetState(mode == "recipes" and "selected" or "default")
    ui.modeProfession:SetState(mode == "professions" and "selected" or "default")
    local professionOptions = { { value = nil, label = "全部专业" } }
    for _, profession in ipairs(professionList) do
        professionOptions[#professionOptions + 1] = { value = profession.id, label = profession.name }
    end
    ui.profession:SetOptions(professionOptions)
    ui.profession:SetValue(ui.state.professionFilter)
    ui.profession:SetOnValueChanged(function(value)
        ui.state.professionFilter = value; ui.state.category = nil
        if value then ui.state.profession = value; ui.state.selectedRecipe = nil end
        ui.matrix.scroll:SetVerticalScroll(0); Core.AccountView:NotifyPageChanged(ID)
    end)
    local characterOptions = { { value = nil, label = "全部角色" } }
    local selectedCharacterPresent = ui.state.character == nil
    for _, character in ipairs(context.characters or {}) do
        if character.id == ui.state.character then selectedCharacterPresent = true end
        characterOptions[#characterOptions + 1] = { value = character.id, label = ColoredCharacterName(character, context) }
    end
    if not selectedCharacterPresent then
        ui.state.character = nil
        ui.state.profession = nil
        ui.state.selectedRecipe = nil
        ui.professions.scroll:SetVerticalScroll(0)
        ui.list.scroll:SetVerticalScroll(0)
    end
    ui.character:SetOptions(characterOptions)
    ui.character:SetValue(ui.state.character)
    ui.character:SetOnValueChanged(function(value)
        ui.state.character = value
        ui.state.profession = nil
        ui.state.selectedRecipe = nil
        ui.state.category = nil
        ui.professions.scroll:SetVerticalScroll(0)
        ui.matrix.scroll:SetVerticalScroll(0); ui.list.scroll:SetVerticalScroll(0)
        Core.AccountView:NotifyPageChanged(ID)
    end)
    ui.status:SetOptions({ { value = nil, label = "全部状态" }, { value = "learned", label = "有角色已学" }, { value = "unknown", label = "含待确认" } })
    ui.status:SetValue(ui.state.status)
    ui.status:SetOnValueChanged(function(value)
        ui.state.status = value
        ui.matrix.scroll:SetVerticalScroll(0); ui.list.scroll:SetVerticalScroll(0)
        Core.AccountView:NotifyPageChanged(ID)
    end)
    ui.searchHint:SetShown(not ui.search:HasFocus() and ui.search:GetText() == "")
    self:Layout(parent, context, mode)
    ui.snapshot = { context = context, entries = entries, professionList = professionList, names = names }
    self:RenderResults(parent)
    local selectedProfession = mode == "recipes" and ui.state.professionFilter or ui.state.profession
    local categoryOptions = { { value = nil, label = selectedProfession and "全部分类" or "先选择专业" } }
    local categoryLabels = {}
    for _, entry in ipairs(entries) do
        if selectedProfession and entry.professionID == selectedProfession then
            local key = CategoryKey(entry.professionID, entry.category)
            if not categoryLabels[key] then
                categoryLabels[key] = entry.category or "待分类"
            end
        end
    end
    local ordered = {}
    for key, label in pairs(categoryLabels) do ordered[#ordered + 1] = { value = key, label = label } end
    table.sort(ordered, function(a, b) return a.label < b.label end)
    local categoryPresent = ui.state.category == nil
    for _, option in ipairs(ordered) do
        categoryOptions[#categoryOptions + 1] = option
        if option.value == ui.state.category then categoryPresent = true end
    end
    if not categoryPresent then
        ui.state.category = nil
        self:RenderResults(parent)
    end
    ui.category:SetOptions(categoryOptions)
    ui.category:SetValue(ui.state.category)
    if selectedProfession then ui.category:Enable(); ui.category:SetState("default")
    else ui.category:Disable(); ui.category:SetState("disabled") end
    ui.category:SetOnValueChanged(function(value)
        ui.state.category = value
        ui.matrix.scroll:SetVerticalScroll(0); ui.list.scroll:SetVerticalScroll(0)
        self:RenderResults(parent)
    end)
end

function Page:Register()
    local page, err = Core.AccountView:RegisterPage(Addon.NAME, {
        id = ID, title = "专业制造", order = 50, defaultEnabled = true,
        previewEnabled = false, autoFitWidth = true,
        scope = { mode = "realms", allTitle = "所有服务器" },
        GetSurfaceMetrics = function(context)
            local count = #(context.characters or {})
            local matrixWidth = 235 + MatrixCharacterWidth() * count
            return {
                minContentWidth = 760, naturalContentWidth = math.max(760, matrixWidth),
                minContentHeight = 470, naturalContentHeight = 640,
                horizontalOverflow = "paginate",
            }
        end,
        Create = function(parent) Page:Create(parent) end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end,
    })
    if not page then return nil, err end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "ycr", brokerName = "YiboCrafting", pageID = ID,
        text = "[Yibo] 专业制造",
        icon = "Interface\\AddOns\\YiboCrafting\\Media\\YiboCraftingIcon-v2",
        defaultMode = "none",
    })
    if not entry then return nil, entryError end
    return page
end

function Addon:NotifyPageChanged()
    Core.AccountView:NotifyPageChanged(ID)
end
