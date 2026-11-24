local Addon, Core = _G.YiboCrafting, _G.YiboCore
if not Addon.AccountPage then return end
local Page, Theme = Addon.AccountPage, Core.UITheme
local Colors = Theme.Colors
local ICON_WIDTH = 16

local function L(key, ...)
    return Core.Locale:Get(Addon.NAME, "UI." .. key, ...)
end

local function UpdateFilters(view)
    local professionOptions, present = { { label = L("ALL_PROFESSIONS") } }, {}
    for _, profession in ipairs(view.professions) do
        professionOptions[#professionOptions + 1] = { value = profession.id, label = profession.name }
        present[profession.id] = true
    end
    if not present[view.professionID] then view.professionID = nil end
    view.profession:SetOptions(professionOptions)
    view.profession:SetValue(view.professionID)

    local categoryOptions = { { label = L(view.professionID and "ALL_CATEGORIES" or "SELECT_PROFESSION") } }
    local categories, ordered = {}, {}
    for _, entry in ipairs(view.entries) do
        if entry.professionID == view.professionID then
            local key = Page.CategoryKey(entry.professionID, entry.category, entry.categoryID)
            if not categories[key] then
                categories[key] = true
                ordered[#ordered + 1] = { value = key, label = entry.category or L("UNCATEGORIZED") }
            end
        end
    end
    table.sort(ordered, function(a, b)
        return a.label == b.label and a.value < b.value or a.label < b.label
    end)
    for _, category in ipairs(ordered) do categoryOptions[#categoryOptions + 1] = category end
    if not categories[view.categoryKey] then view.categoryKey = nil end
    view.category:SetOptions(categoryOptions)
    view.category:SetValue(view.categoryKey)
    view.category:SetEnabled(view.professionID ~= nil)
end

local function RenderRoles(view, entry)
    local context = view.context
    local rowHeight, inset = Theme.Table.rowHeight, Theme.Geometry.compactColumnInset
    local characters = entry and Page:CharactersForProfession(context.characters, entry.professionID) or {}
    local identityTitle, statusTitle = L("CHARACTERS"), L("LEARNING_STATE")
    local statuses = { learned = L("LEARNED"), unlearned = L("UNLEARNED"), unknown = L("UNKNOWN_SYMBOL") }
    local showState = context:GetFieldVisible("recipe-state")
    local names, states, stateLabels = {}, {}, {}
    local availableWidth = Core.AccountView:GetScrollSurfaceWidth({ surfaceAvailableWidth = view.roleWidth },
        view.right, #characters * rowHeight, view.listTop + Theme.Space.lg)
    for index, character in ipairs(characters) do
        names[index] = Core.Characters:FormatName(character, { realmMode = context.scope == "all" and "full" or "omit" })
        if showState then
            states[index] = Addon.Store:GetRecipeState(character.id, entry.professionID, entry.id)
            stateLabels[index] = statuses[states[index]] or statuses.unknown
        end
    end
    local statusWidth = showState and Theme:GetCompactColumnWidth(statusTitle, stateLabels) or 0
    local identityWidth = math.max(1, math.min(availableWidth - statusWidth,
        Theme:GetCompactColumnWidth(identityTitle, names)))
    local tableWidth = identityWidth + statusWidth
    view.identityHeader:SetPoint("TOPLEFT", view.header)
    view.identityHeader:SetWidth(identityWidth)
    view.stateHeader:SetPoint("TOPLEFT", view.identityHeader, "TOPRIGHT")
    view.stateHeader:SetWidth(math.max(1, statusWidth))
    Theme:SetMatrixHeader(view.identityHeader, identityTitle, { justify = "LEFT", inset = inset })
    Theme:SetMatrixHeader(view.stateHeader, statusTitle, { inset = inset })
    view.stateHeader:SetShown(showState)
    for index, character in ipairs(characters) do
        local row = view.rows[index]
        if not row then
            row = CreateFrame("Button", nil, view.body, "BackdropTemplate")
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            row.name = Theme:CreateText(row, Theme.Font.body, Colors.text)
            row.status = Theme:CreateText(row, Theme.Font.body, Colors.text, "CENTER")
            row.name:SetPoint("LEFT", inset, 0)
            row.name:SetWordWrap(false)
            row.status:SetWordWrap(false)
            view.rows[index] = row
        end
        row:SetPoint("TOPLEFT", 0, -(index - 1) * rowHeight)
        row:SetSize(tableWidth, rowHeight)
        local tone = Theme:GetDataRowColor(index)
        row:SetBackdropColor(tone[1], tone[2], tone[3], tone[4])
        row.name:SetWidth(math.max(1, identityWidth - inset * 2))
        row.name:SetText(names[index])
        local state = states[index]
        row.status:SetPoint("LEFT", row, "LEFT", identityWidth + inset, 0)
        row.status:SetWidth(math.max(1, statusWidth - inset * 2))
        row.status:SetText(stateLabels[index] or "")
        row.status:SetShown(showState)
        local color = state == "learned" and Colors.accent or state == "unlearned" and Colors.muted or Colors.warning
        row.status:SetTextColor(color[1], color[2], color[3])
        Theme:BindTooltip(row, names[index], showState and { state == "unknown" and L("UNKNOWN") or statuses[state] } or nil)
        if Addon.GoalTargets and Addon.GoalTargets.ref then Addon.GoalTargets:Bind(row, entry, character.id, nil, true) end
        row:Show()
    end
    for index = #characters + 1, #view.rows do view.rows[index]:Hide() end
    view.body:SetSize(math.max(tableWidth, availableWidth), math.max(rowHeight, #characters * rowHeight))
    view.scroll:SetContentHeight(#characters * rowHeight)
    view.empty:SetWidth(math.max(1, availableWidth))
    view.empty:SetText(L("NO_CONFIRMED_OWNERS"))
    view.empty:SetShown(entry ~= nil and #characters == 0)
    view.note:SetText(entry and (entry.directoryStatus == "provisional" and L("CATALOG_SOURCE") or L("CHARACTER_SOURCE")) or "")
end

local function SelectRecipe(view, entry)
    local key = entry and entry.key
    if view.list.selectedKey ~= key then view.scroll:SetVerticalScroll(0) end
    view.list.selectedKey, view.selectedEntry = key, entry
    view.selected:SetShown(entry ~= nil)
    view.header:SetShown(entry ~= nil)
    view.scroll:SetShown(entry ~= nil)
    if entry then
        local width = Theme:GetCompactColumnWidth("", { entry.name }, ICON_WIDTH)
        view.selected:SetWidth(math.min(view.roleWidth, width))
        view.selectedName:SetText(entry.name)
        view.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    RenderRoles(view, entry)
end

local function RefreshResults(view, resetScroll)
    local list = view.list
    local entries = Page:Filtered(view.entries, {}, {
        profession = view.professionID, category = view.categoryKey, search = view.query,
    })
    local selected = entries[1]
    for _, entry in ipairs(entries) do
        if entry.key == list.selectedKey then selected = entry; break end
    end
    if resetScroll then list.scroll:SetVerticalScroll(0) end
    Theme:SetMatrixHeader(list.header, L("MATCHING_RECIPES", #entries),
        { justify = "LEFT", inset = Theme.Geometry.compactColumnInset })
    list.contentWidth = Core.AccountView:GetScrollSurfaceWidth({ surfaceAvailableWidth = view.listWidth },
        view.left, #entries * Theme.Table.rowHeight, view.listTop)
    list.empty:SetWidth(math.max(1, list.contentWidth - Theme.Space.xs))
    list.empty:SetShown(#entries == 0)
    SelectRecipe(view, selected)
    Page:RenderCompactRecipeList(list, entries, function(entry)
        SelectRecipe(view, entry)
        list.renderVisible(true)
    end)
end

local function CreateComparison(view)
    local gap, gutter, controlHeight = Theme.Space.xs, Theme.Space.sm, Theme.Size.standard
    local inset = Theme.Geometry.compactColumnInset
    local left, right = CreateFrame("Frame", nil, view), CreateFrame("Frame", nil, view)
    left:SetPoint("TOPLEFT", gap, -gap)
    left:SetPoint("BOTTOMLEFT", gap, gap)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", gutter, 0)
    right:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -gap, gap)
    view.left, view.right = left, right
    view.listTop = (controlHeight + gap) * 2 + Theme.Table.headerHeight

    view.profession = Theme:CreateDropdown(left)
    view.profession:SetMenuPageSize(11)
    view.profession:SetPoint("TOPLEFT")
    view.profession:SetPoint("TOPRIGHT")
    view.profession:SetOnValueChanged(function(value)
        view.professionID, view.categoryKey = value, nil
        UpdateFilters(view)
        RefreshResults(view, true)
    end)
    view.category = Theme:CreateDropdown(right)
    view.category:SetMenuPageSize(11)
    view.category:SetPoint("TOPLEFT")
    view.category:SetPoint("TOPRIGHT")
    view.category:SetOnValueChanged(function(value)
        view.categoryKey = value
        RefreshResults(view, true)
    end)

    local function Search(text)
        if text == (view.query or "") then return end
        view.query = text
        RefreshResults(view, true)
    end
    view.search = Theme:CreateInput(left, { maxLetters = 80, placeholder = L("SEARCH"),
        OnSubmit = Search,
        OnChanged = function(text, userInput)
            if not userInput then return end
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, function()
                    if view:IsVisible() and text == view.search:GetText() then Search(text) end
                end)
            else
                Search(text)
            end
        end })
    view.search:SetPoint("TOPLEFT", view.profession, "BOTTOMLEFT", 0, -gap)
    view.search:SetPoint("TOPRIGHT", view.profession, "BOTTOMRIGHT", 0, -gap)
    Theme:AttachClearButton(view.search, { OnClear = function() Search("") end })

    local list = { rows = {} }
    view.list = list
    list.header = Theme:CreateMatrixHeader(left)
    list.header:SetPoint("TOPLEFT", view.search, "BOTTOMLEFT", 0, -gap)
    list.header:SetPoint("TOPRIGHT", view.search, "BOTTOMRIGHT", 0, -gap)
    list.scroll = Theme:CreateScrollFrame(left)
    list.scroll:SetPoint("TOPLEFT", list.header, "BOTTOMLEFT")
    list.scroll:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT")
    list.body = CreateFrame("Frame", nil, list.scroll)
    list.body:SetPoint("TOPLEFT", list.scroll)
    list.scroll:SetScrollChild(list.body)
    list.empty = Theme:CreateText(list.body, Theme.Font.body, Colors.muted)
    list.empty:SetPoint("TOPLEFT", inset, -inset)
    list.empty:SetWordWrap(true)
    list.empty:SetText(L("EMPTY_FILTER"))
    Page.BindVisibleRows(list)

    view.selected = CreateFrame("Button", nil, right)
    view.selected:SetHeight(controlHeight)
    view.selected:SetPoint("TOPLEFT", view.category, "BOTTOMLEFT", 0, -gap)
    view.selected:SetScript("OnEnter", function(owner) Page:ShowRecipeTooltip(owner, view.selectedEntry) end)
    view.selected:SetScript("OnLeave", function() GameTooltip:Hide() end)
    view.icon = view.selected:CreateTexture(nil, "ARTWORK")
    view.icon:SetSize(ICON_WIDTH, ICON_WIDTH)
    view.icon:SetPoint("LEFT", inset, 0)
    view.selectedName = Theme:CreateText(view.selected, Theme.Font.body, Colors.text)
    view.selectedName:SetPoint("LEFT", view.icon, "RIGHT", Theme.Table.iconTextGap, 0)
    view.selectedName:SetPoint("RIGHT", -inset, 0)
    view.selectedName:SetWordWrap(false)
    view.header = CreateFrame("Frame", nil, right)
    view.header:SetHeight(Theme.Table.headerHeight)
    view.header:SetPoint("TOPLEFT", view.selected, "BOTTOMLEFT", 0, -gap)
    view.header:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -(controlHeight + gap) * 2)
    view.identityHeader = Theme:CreateMatrixHeader(view.header)
    view.stateHeader = Theme:CreateMatrixHeader(view.header)
    view.scroll = Theme:CreateScrollFrame(right)
    view.scroll:BindScrollbarGutter(view.header)
    view.scroll:SetPoint("TOPLEFT", view.header, "BOTTOMLEFT")
    view.scroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, Theme.Space.lg)
    view.body = CreateFrame("Frame", nil, view.scroll)
    view.body:SetPoint("TOPLEFT", view.scroll)
    view.scroll:SetScrollChild(view.body)
    view.rows = {}
    view.empty = Theme:CreateText(view.body, Theme.Font.body, Colors.muted)
    view.empty:SetPoint("TOPLEFT")
    view.empty:SetWordWrap(true)
    view.note = Theme:CreateText(right, Theme.Font.assist, Colors.muted)
    view.note:SetPoint("BOTTOMLEFT")
    view.note:SetPoint("BOTTOMRIGHT")
    view.note:SetWordWrap(false)
    view:SetScript("OnHide", function()
        view.profession.menu:Hide()
        view.category.menu:Hide()
    end)
end

function Page:RenderAccountPage(parent, context)
    local key, other = "recipeComparison", "recipePreview"
    if context.preview then key, other = other, key end
    if parent[other] then parent[other]:Hide() end
    if not parent[key] then
        local child = CreateFrame("Frame", nil, parent)
        child:SetAllPoints(parent)
        parent[key] = child
        if context.preview then self:Create(child) else CreateComparison(child) end
    end
    local view = parent[key]
    view:Show()
    if context.preview then return self:Refresh(view, context) end

    local width = math.max(2, context.surfaceAvailableWidth - Theme.Space.xs * 2 - Theme.Space.sm)
    view.listWidth = math.floor(width / 2)
    view.roleWidth = width - view.listWidth
    view.left:SetWidth(view.listWidth)
    view.context = context
    view.entries, view.professions = self:Snapshot(context)
    UpdateFilters(view)
    RefreshResults(view)
end
