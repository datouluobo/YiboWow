-- Internal account pages are loaded after AccountView.lua.  They own page-specific
-- presentation while AccountView remains the shared shell and public API.
local Core = _G.YiboCore
local AccountView = Core.AccountView
local Theme = Core.UITheme
local COLORS = Theme.Colors
local Helpers = AccountView._internal
local AddText = Helpers.AddText
local CreateChromeButton = Helpers.CreateChromeButton
local Settings = Helpers.Settings

local ARCHIVE_COLUMN_GAP = 10

local function HasCharacterProfile(character)
    for _, field in ipairs(Core.Fields:GetByConsumer("character-archive")) do
        if Core.Fields:GetValue(character, field) ~= nil then return true end
    end
    return false
end

local function ArchiveSettings()
    local settings = Settings()
    settings.characterArchive = type(settings.characterArchive) == "table" and settings.characterArchive or {}
    local archive = settings.characterArchive
    archive.fields = type(archive.fields) == "table" and archive.fields or {}
    archive.previewFields = type(archive.previewFields) == "table" and archive.previewFields or {}
    local legacyIDs = { identity = "character.identity", level = "character.level", itemLevel = "character.item-level", zone = "character.zone", primary = "character.profession-primary", secondary = "character.profession-secondary", archaeology = "character.archaeology", fishing = "character.fishing", cooking = "character.cooking", firstAid = "character.first-aid" }
    for oldID, newID in pairs(legacyIDs) do
        if archive.fields[newID] == nil and archive.fields[oldID] ~= nil then archive.fields[newID] = archive.fields[oldID] end
        if archive.previewFields[newID] == nil and archive.previewFields[oldID] ~= nil then archive.previewFields[newID] = archive.previewFields[oldID] end
    end
    archive.filters = type(archive.filters) == "table" and archive.filters or {}
    for _, mode in ipairs({ "page", "preview" }) do
        archive.filters[mode] = type(archive.filters[mode]) == "table" and archive.filters[mode] or {}
        local filter = archive.filters[mode]
        if filter.profile ~= "profiled" and filter.profile ~= "missing" then filter.profile = "all" end
        if filter.includeHidden == nil then filter.includeHidden = mode == "page" end
        local valid, normalized = Core.LevelFilter:Validate(filter.levelExpr or "")
        filter.levelExpr = valid and normalized or ""
    end
    return archive
end

local function ArchiveFieldVisible(field, preview)
    local values = preview and ArchiveSettings().previewFields or ArchiveSettings().fields
    if values[field.id] == nil then
        return preview and field.defaultPreviewVisible == true or (not preview and field.defaultVisible == true)
    end
    return values[field.id] == true
end

local function GetArchiveFields(preview)
    local fields = {}
    for _, field in ipairs(Core.Fields:GetByConsumer("character-archive")) do
        if ArchiveFieldVisible(field, preview) then fields[#fields + 1] = field end
    end
    if #fields == 0 then fields[1] = Core.Fields:GetByConsumer("character-archive")[1] end
    return fields
end
local function CreateCharacters(parent)
    -- The title bar and its sort control already communicate page identity
    -- and ordering; a second count/sort sentence only delays the table.
    parent.heading = AddText(parent, "GameFontNormalLarge", nil, COLORS.text); parent.heading:Hide()
    parent.hint = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:Hide()
    parent.listHeader = CreateFrame("Frame", nil, parent)
    parent.listHeader:SetPoint("TOPLEFT", 20, -82); parent.listHeader:SetWidth(850); parent.listHeader:SetHeight(Theme.Table.headerHeight)
    parent.listHeader.bg = parent.listHeader:CreateTexture(nil, "BACKGROUND"); parent.listHeader.bg:SetAllPoints(); parent.listHeader.bg:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], 0.95)
    parent.listHeader.name = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.name:SetPoint("LEFT", 9, 0); parent.listHeader.name:SetWidth(246); parent.listHeader.name:SetText(Core:Text("CORE.CHARACTER"))
    parent.listHeader.level = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.level:SetPoint("LEFT", parent.listHeader.name, "RIGHT", 6, 0); parent.listHeader.level:SetWidth(32); parent.listHeader.level:SetText(Core:Text("CORE.LEVEL"))
    parent.listHeader.zone = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.zone:SetPoint("LEFT", parent.listHeader.level, "RIGHT", 6, 0); parent.listHeader.zone:SetWidth(78); parent.listHeader.zone:SetText(Core:Text("CORE.LOCATION"))
    parent.listHeader.itemLevel = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.itemLevel:SetPoint("LEFT", parent.listHeader.zone, "RIGHT", 6, 0); parent.listHeader.itemLevel:SetWidth(42); parent.listHeader.itemLevel:SetText(Core:Text("CORE.ITEM_LEVEL"))
    parent.listHeader.professions = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.professions:SetPoint("LEFT", parent.listHeader.itemLevel, "RIGHT", 6, 0); parent.listHeader.professions:SetText(Core:Text("CORE.PROFESSIONS"))
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 20, -106); parent.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, 12)
    parent.listContent = CreateFrame("Frame", nil, parent.scroll)
    parent.listContent:SetWidth(850)
    parent.scroll:SetScrollChild(parent.listContent)
    parent.rows = {}
end

local DELETE_POPUP = "YIBOCORE_DELETE_CHARACTER_CACHE"
StaticPopupDialogs[DELETE_POPUP] = Core.Locale:Bind(function() return {
    text = "%s",
    button1 = Core:Text("CORE.DELETE_CACHE"),
    button2 = Core:Text("CORE.CANCEL"),
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(_, data)
        local result, errorMessage = Core.CharacterCleanup:Delete(data)
        if not result then
            Core:Print(Core:Text("CORE.CHARACTER_CACHE_DELETION_FAILED") .. tostring(errorMessage))
            return
        end
        local pending = 0
        for _, ownerResult in pairs(result.owners or {}) do if ownerResult.status ~= "deleted" then pending = pending + 1 end end
        if pending > 0 then
            Core:Print(Core:Text("CORE.CHARACTER_CACHE_REMOVED_FROM_THE_ACCOUNT_VIEW") .. pending .. Core:Text("CORE.ADDON_CACHES_WILL_RETRY_CLEANUP_WHEN_NEXT"))
        else
            Core:Print(Core:Text("CORE.CHARACTER_CACHE_DELETED"))
        end
        AccountView:RefreshPage()
    end,
} end)

local function ShowCharacterDeleteConfirmation(characterID)
    local allowed, errorMessage = Core.CharacterCleanup:CanDelete(characterID)
    if not allowed then Core:Print(errorMessage); return end
    local impact, impactError = Core.CharacterCleanup:GetImpact(characterID)
    if not impact then Core:Print(impactError); return end
    local character = impact.character
    local lines = {
        Core:Text("FORMAT.CACHE_CONFIRM", Core.Characters:FormatName({ name = tostring(character.name or Core:Text("CORE.UNKNOWN_CHARACTER")), realm = tostring(character.realm or Core:Text("CORE.UNKNOWN_REALM")) }, { realmMode = "full" })),
        "",
        Core:Text("CORE.WILL_DELETE"),
        Core:Text("CORE.CORE_CHARACTER_PROFILE"),
    }
    local ownerOrder = {}
    for addonName in pairs(impact.owners) do ownerOrder[#ownerOrder + 1] = addonName end
    table.sort(ownerOrder)
    for _, addonName in ipairs(ownerOrder) do
        local ownerImpact = impact.owners[addonName]
        lines[#lines + 1] = "• " .. tostring(ownerImpact.label or addonName) .. Core:Text("FORMAT.COLON") .. tostring(ownerImpact.detail or (ownerImpact.hasData and Core:Text("CORE.CACHED") or Core:Text("CORE.NO_CACHE")))
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = Core:Text("CORE.ACCOUNT_WIDE_SETTINGS_AND_THE_GAME_CHARACTER")
    lines[#lines + 1] = Core:Text("CORE.DELETION_CANNOT_BE_UNDONE")
    Core.Client:ShowPopup(DELETE_POPUP, table.concat(lines, "\n"), nil, characterID)
end

local function ArchiveFieldText(character, field, snapshot)
    return Core.Fields:FormatValue(character, field, snapshot)
end

local function ArchiveCharacters(context)
    local preview = context and context.preview == true
    local archive = ArchiveSettings()
    local filter = archive.filters[preview and "preview" or "page"]
    local levelFilter = Core.LevelFilter:Compile(filter.levelExpr)
    local characters, hidden = {}, Settings().hiddenCharacters
    for _, character in ipairs((context and context.characters) or Core.Characters:GetAllCached()) do
        local profiled = HasCharacterProfile(character)
        local profileMatches = filter.profile == "all" or (filter.profile == "profiled" and profiled) or (filter.profile == "missing" and not profiled)
        if profileMatches and levelFilter:Matches(character.level) and (filter.includeHidden or not hidden[character.id]) then characters[#characters + 1] = character end
    end
    return Core.CharacterSort:Sort(characters, AccountView:GetDefaultCharacterSort(), Core.Characters:GetCurrentID(), AccountView:GetCustomCharacterOrder())
end

local function GetArchiveColumnWidths(fields)
    local widths = {}
    for index, field in ipairs(fields) do
        widths[index] = math.max(math.min(field.width, field.maxWidth or field.width), Theme:MeasureText(Theme.Font.body, field.title) + 12)
    end
    return widths
end

local function GetArchiveColumnGap(fields, index)
    return tonumber(fields[index].gapAfter) or ARCHIVE_COLUMN_GAP
end

local function GetArchiveTableWidth(fields, widths)
    local width = 16
    for index, columnWidth in ipairs(widths) do
        width = width + columnWidth
        if index < #widths then width = width + GetArchiveColumnGap(fields, index) end
    end
    return width
end

local function RefreshCharacters(parent, context)
    local current = Core.Characters:GetCurrent()
    local preview = context and context.preview == true
    local inset = Theme:GetMatrixInsets(preview)
    local characters = (context and ArchiveCharacters(context)) or ArchiveCharacters({ preview = false })
    -- The matrix begins at the normal content inset; count and sorting remain
    -- available through the actual rows and the title-bar sort control.
    parent.heading:Hide()
    parent.hint:Hide()
    parent.listHeader:ClearAllPoints(); parent.listHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    parent.scroll:ClearAllPoints(); parent.scroll:SetPoint("TOPLEFT", parent.listHeader, "BOTTOMLEFT", 0, -Theme.Space.xs); parent.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    local previousScroll = parent.resetScroll and 0 or parent.scroll:GetVerticalScroll()
    -- The custom scrollbar overlays the scroll frame.  Only the full archive
    -- reserves space for its hidden-state control; hover is deliberately
    -- The scrollbar lives in the matrix inset, outside the data viewport.
    local contentWidth = parent.scroll:GetWidth() or 0
    if contentWidth <= 0 then contentWidth = 832 end
    parent.listContent:SetWidth(contentWidth)
    local fields = GetArchiveFields(preview)
    local providerSnapshot = Core.ArchiveFields and Core.ArchiveFields:Read(characters, fields)
    local widths = GetArchiveColumnWidths(fields)
    local tableWidth = GetArchiveTableWidth(fields, widths)
    local surfaceWidth = math.max(contentWidth, tableWidth)
    parent.listContent:SetWidth(surfaceWidth)
    parent.listHeader:SetWidth(surfaceWidth)
    parent.listHeader.name:Hide(); parent.listHeader.level:Hide(); parent.listHeader.zone:Hide(); parent.listHeader.itemLevel:Hide(); parent.listHeader.professions:Hide()
    parent.listHeader.dynamicCells = parent.listHeader.dynamicCells or {}
    local x = 8
    for fieldIndex, field in ipairs(fields) do
        local cell = parent.listHeader.dynamicCells[fieldIndex]
        if not cell then cell = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); cell:SetWordWrap(false); parent.listHeader.dynamicCells[fieldIndex] = cell end
        local width = widths[fieldIndex]
        cell:ClearAllPoints(); cell:SetPoint("LEFT", x, 0); cell:SetWidth(width); cell:SetJustifyH("LEFT"); cell:SetText(field.title); cell:Show(); x = x + width + GetArchiveColumnGap(fields, fieldIndex)
    end
    for fieldIndex = #fields + 1, #parent.listHeader.dynamicCells do parent.listHeader.dynamicCells[fieldIndex]:Hide() end
    for index, character in ipairs(characters) do
        local row = parent.rows[index]
        if not row then
            row = CreateFrame("Button", nil, parent.listContent, "BackdropTemplate"); row:SetHeight(Theme.Table.rowHeight); row:SetPoint("TOPLEFT", 0, -((index - 1) * Theme.Table.rowHeight)); row:SetWidth(tableWidth)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); row.currentOutline = Theme:CreateCurrentCharacterOutline(row); row.name = AddText(row, "GameFontNormalSmall", Theme.Font.body, COLORS.text); row.name:SetPoint("LEFT", 9, 0); row.name:SetWidth(246)
            row.level = AddText(row, "GameFontNormalSmall", Theme.Font.body, COLORS.text); row.level:SetPoint("LEFT", row.name, "RIGHT", 6, 0); row.level:SetWidth(32)
            row.zone = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.zone:SetPoint("LEFT", row.level, "RIGHT", 6, 0); row.zone:SetWidth(78)
            row.itemLevel = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.itemLevel:SetPoint("LEFT", row.zone, "RIGHT", 6, 0); row.itemLevel:SetWidth(42)
            row.professions = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.professions:SetPoint("LEFT", row.itemLevel, "RIGHT", 6, 0); row.professions:SetPoint("RIGHT", -86, 0)
            row.name:SetWordWrap(false); row.zone:SetWordWrap(false); row.professions:SetWordWrap(false)
            row.delete = CreateChromeButton(row, 28, 20, Core:Text("CORE.DEL"))
            row.delete:SetPoint("RIGHT", -8, 0)
            row.delete.label:SetTextColor(COLORS.danger[1], COLORS.danger[2], COLORS.danger[3])
            row.delete:SetScript("OnClick", function(self) ShowCharacterDeleteConfirmation(self.characterID) end)
            row.delete:HookScript("OnEnter", function(self)
                if self.state == "disabled" or not self.characterID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(Core:Text("CORE.DELETE_CHARACTER_CACHE"), COLORS.danger[1], COLORS.danger[2], COLORS.danger[3])
                GameTooltip:AddLine(Core:Text("CORE.DELETE_THIS_CHARACTER_S_CORE_AND_BUSINESS"), COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], true)
                GameTooltip:Show()
            end)
            row.delete:HookScript("OnLeave", function() GameTooltip:Hide() end)
            parent.rows[index] = row
        end
        -- Hover uses the same compact matrix rhythm as every other preview;
        -- no local row-step may create invisible whitespace between records.
        local rowHeight = preview and Theme.Table.previewRowHeight or Theme.Table.rowHeight
        row:SetHeight(rowHeight); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -((index - 1) * rowHeight)); row:SetWidth(surfaceWidth)
        row.name:Hide(); row.level:Hide(); row.zone:Hide(); row.itemLevel:Hide(); row.professions:Hide(); row.delete:Hide()
        row.dynamicCells = row.dynamicCells or {}
        x = 8
        for fieldIndex, field in ipairs(fields) do
            local cell = row.dynamicCells[fieldIndex]
            if not cell or cell.icon then
                if cell and cell.icon then cell:Hide() end
                cell = AddText(row, "GameFontNormalSmall", Theme.Font.body, COLORS.muted)
                cell:SetWordWrap(false); row.dynamicCells[fieldIndex] = cell
            end
            local width = widths[fieldIndex]
            cell:ClearAllPoints(); cell:SetPoint("LEFT", x, 0); cell:SetWidth(width)
            local text, value = ArchiveFieldText(character, field, providerSnapshot)
            local icon = field.GetIcon and field.GetIcon(value, character)
            if icon and text ~= "—" then
                cell:SetText("|T" .. tostring(icon) .. ":16:16:0:0:64:64|t " .. text)
            else
                cell:SetText(text)
            end
            cell:SetJustifyH(field.align or "LEFT")
            local color = field.GetColor and field.GetColor(value, character)
            local r, g, b = color and color[1] or COLORS.muted[1], color and color[2] or COLORS.muted[2], color and color[3] or COLORS.muted[3]
            cell:SetTextColor(r, g, b)
            cell:Show(); x = x + width + GetArchiveColumnGap(fields, fieldIndex)
        end
        for fieldIndex = #fields + 1, #row.dynamicCells do row.dynamicCells[fieldIndex]:Hide() end
        local isCurrent = current and current.id == character.id
        local rowTone = Theme:GetDataRowColor(index)
        row:SetBackdropColor(rowTone[1], rowTone[2], rowTone[3], rowTone[4] or 0.88)
        Theme:ApplyDataColumnTints(row, widths, rowHeight, 8, function(fieldIndex) return GetArchiveColumnGap(fields, fieldIndex) end)
        row:SetBackdropBorderColor(COLORS.matrixLine[1], COLORS.matrixLine[2], COLORS.matrixLine[3], COLORS.matrixLine[4])
        Theme:SetCurrentCharacterOutline(row.currentOutline, isCurrent)
        row:Show()
    end
    for index = #characters + 1, #parent.rows do parent.rows[index]:Hide() end
    local contentHeight = #characters * (preview and Theme.Table.previewRowHeight or Theme.Table.rowHeight)
    local viewportHeight = parent.scroll:GetHeight() or 500
    parent.listContent:SetHeight(math.max(contentHeight, viewportHeight))
    parent.scroll:SetContentHeight(contentHeight)
    parent.scroll:SetVerticalScroll(math.min(previousScroll, math.max(0, contentHeight - viewportHeight)))
    parent.resetScroll = nil
    parent.scroll:RefreshScrollbar()
end

local function GetCharacterSurfaceMetrics(context)
    local count = #ArchiveCharacters(context)
    local fields = GetArchiveFields(false)
    local tableWidth = GetArchiveTableWidth(fields, GetArchiveColumnWidths(fields))
    local inset = Theme:GetMatrixInsets(context and context.preview)
    return { minContentWidth = 582, naturalContentWidth = tableWidth + inset.left + inset.right, minContentHeight = 150, naturalContentHeight = inset.top + Theme.Table.headerHeight + Theme.Space.xs + math.min(count, 20) * Theme.Table.rowHeight + inset.bottom, verticalOverflow = "content" }
end

local function GetCharacterHoverMetrics(context)
    local count = #ArchiveCharacters(context)
    local fields = GetArchiveFields(true)
    local tableWidth = GetArchiveTableWidth(fields, GetArchiveColumnWidths(fields))
    local inset = Theme:GetMatrixInsets(true)
    local contentHeight = inset.top + Theme.Table.headerHeight + Theme.Space.xs + math.max(1, math.min(count, 20)) * Theme.Table.previewRowHeight + inset.bottom
    return {
        minWidth = 420,
        preferredWidth = math.max(520, tableWidth + 72),
        minHeight = 150,
        preferredHeight = Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2 + contentHeight,
        verticalOverflow = "content",
    }
end

AccountView._pages.characters = Core.Locale:Bind(function() return {
    id = "characters", title = Core:Text("CORE.CHARACTER_ARCHIVE"), order = -10, internal = true, previewEnabled = true,
    Create = CreateCharacters, Refresh = RefreshCharacters,
    GetSurfaceMetrics = GetCharacterSurfaceMetrics,
    GetHoverMetrics = GetCharacterHoverMetrics,
} end)

Helpers.ArchiveSettings = ArchiveSettings
Helpers.ArchiveFieldVisible = ArchiveFieldVisible
Helpers.GetArchiveFields = GetArchiveFields
