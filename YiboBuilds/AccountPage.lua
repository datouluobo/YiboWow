local Addon = _G.YiboBuilds
local Page = {}
Addon.AccountPage = Page

local Core = _G.YiboCore
local Theme = Core.UITheme
local C = Theme.Colors
local ICON_SIZE = 40
local ROSTER_ROW_HEIGHT = 56
local CATALOG_ROW_HEIGHT = 56
local SLOT_LABELS = {
    [INVSLOT_HEAD or 1] = "头", [INVSLOT_NECK or 2] = "颈", [INVSLOT_SHOULDER or 3] = "肩",
    [INVSLOT_SHIRT or 4] = "衬", [INVSLOT_CHEST or 5] = "胸", [INVSLOT_WAIST or 6] = "腰",
    [INVSLOT_LEGS or 7] = "腿", [INVSLOT_FEET or 8] = "脚", [INVSLOT_WRIST or 9] = "腕",
    [INVSLOT_HAND or 10] = "手", [INVSLOT_FINGER1 or 11] = "戒1", [INVSLOT_FINGER2 or 12] = "戒2",
    [INVSLOT_TRINKET1 or 13] = "饰1", [INVSLOT_TRINKET2 or 14] = "饰2", [INVSLOT_BACK or 15] = "背",
    [INVSLOT_MAINHAND or 16] = "主手", [INVSLOT_OFFHAND or 17] = "副手", [INVSLOT_TABARD or 19] = "袍",
}

-- MoP's paper doll has two weapon slots.  Bows, guns and wands are equipped
-- in the main-hand slot; the pre-MoP ranged slot is cache-compatible only and
-- must not be rendered or tried on by this page.
-- Match the paper doll: eight slots on each side, weapons beneath the model.
local LEFT_SLOTS = { INVSLOT_HEAD or 1, INVSLOT_NECK or 2, INVSLOT_SHOULDER or 3, INVSLOT_BACK or 15, INVSLOT_CHEST or 5, INVSLOT_SHIRT or 4, INVSLOT_TABARD or 19, INVSLOT_WRIST or 9 }
local RIGHT_SLOTS = { INVSLOT_HAND or 10, INVSLOT_WAIST or 6, INVSLOT_LEGS or 7, INVSLOT_FEET or 8, INVSLOT_FINGER1 or 11, INVSLOT_FINGER2 or 12, INVSLOT_TRINKET1 or 13, INVSLOT_TRINKET2 or 14 }
local BOTTOM_SLOTS = { INVSLOT_MAINHAND or 16, INVSLOT_OFFHAND or 17 }
local SLOT_ORDER = {}
for _, slots in ipairs({ LEFT_SLOTS, RIGHT_SLOTS, BOTTOM_SLOTS }) do
    for _, slotID in ipairs(slots) do SLOT_ORDER[#SLOT_ORDER + 1] = slotID end
end

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size or Theme.Font.body, color or C.text, justify or "LEFT")
end

local function IsCurrent(character)
    local current = Core.Characters:GetCurrent()
    return current and character and current.id == character.id
end

local function Eligible(context)
    local result = {}
    for _, character in ipairs((context and context.characters) or {}) do
        if Addon.Snapshot:GetCharacter(character.id) then result[#result + 1] = character end
    end
    return result
end

local function IconText(icon, name, size)
    return "|T" .. tostring(icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":" .. tostring(size or 16) .. ":" .. tostring(size or 16) .. ":0:0|t " .. tostring(name or "—")
end

local function ClassColor(character)
    local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[character and character.class or ""]
    return color or { r = C.text[1], g = C.text[2], b = C.text[3] }
end

local function CharacterLabel(character, context)
    local name = Core.Characters and Core.Characters.GetDisplayName and Core.Characters:GetDisplayName(character, "short") or character and character.name
    name = name or "未知角色"
    -- In an all-realm projection, a short name alone is ambiguous.  Keep the
    -- normal compact name in a single-realm range, and append the realm only
    -- where it contributes identity.
    if context and context.scope == "all" then
        return name .. "-" .. tostring(character and character.realm or "未知服务器")
    end
    return name
end

local function ItemBorderColor(item)
    local link = item and item.itemLink
    if type(link) == "string" then
        local red, green, blue = string.match(link, "|c%x%x(%x%x)(%x%x)(%x%x)")
        if red and green and blue then return tonumber(red, 16) / 255, tonumber(green, 16) / 255, tonumber(blue, 16) / 255 end
    end
    return C.line[1], C.line[2], C.line[3]
end

local function CreateIconButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 2, -2); button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.gems = {}
    for index = 1, 3 do
        local gem = CreateFrame("Button", nil, parent, "BackdropTemplate")
        gem:SetSize(16, 16)
        gem:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        gem:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 1)
        gem.icon = gem:CreateTexture(nil, "ARTWORK"); gem.icon:SetPoint("TOPLEFT", 1, -1); gem.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        button.gems[index] = gem
    end
    button.enchant = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.enchant:SetSize(16, 16)
    button.enchant:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.enchant:SetBackdropBorderColor(C.warning[1], C.warning[2], C.warning[3], 1)
    button.enchant.icon = button.enchant:CreateTexture(nil, "ARTWORK")
    button.enchant.icon:SetAllPoints(); button.enchant.icon:SetTexture("Interface\\Icons\\Trade_Engraving")
    button:RegisterForClicks("LeftButtonUp")
    return button
end

local function SetAugmentTooltip(button, item, title, link)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if link then GameTooltip:SetHyperlink(link)
        elseif item and item.itemLink then
            GameTooltip:SetHyperlink(item.itemLink)
            if title then GameTooltip:AddLine("当前附魔：" .. title, C.accent[1], C.accent[2], C.accent[3], true) end
        else
            GameTooltip:AddLine(title or "附魔")
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function SetNativeItemTooltip(button, item)
    button:SetScript("OnEnter", function(self)
        if not item or not item.itemLink then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(item.itemLink)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function SetSpellTooltip(button, entry)
    button:SetScript("OnEnter", function(self)
        if not entry or not entry.glyphLink and (not entry.spellID or entry.spellID == 0) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if entry.glyphLink then GameTooltip:SetHyperlink(entry.glyphLink)
        elseif GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(entry.spellID)
        else GameTooltip:AddLine(entry.name or "未选择") end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function GlyphRequirementText(entry)
    local requirement = entry and entry.specRequirement
    return requirement and requirement ~= "通用" and requirement or nil
end

function Page:GetFields()
    local fields = {
        { id = "slot", title = "槽位", defaultVisible = true },
        { id = "spec", title = "专精", defaultVisible = true },
    }
    for index = 1, 6 do fields[#fields + 1] = { id = "talent" .. index, title = "天赋" .. index .. "层", defaultVisible = true } end
    for index = 1, 3 do fields[#fields + 1] = { id = "major" .. index, title = "雕文大" .. index, defaultVisible = true } end
    for index = 1, 3 do fields[#fields + 1] = { id = "minor" .. index, title = "雕文小" .. index, defaultVisible = true } end
    fields[#fields + 1] = { id = "equipment", title = "装备", defaultVisible = true }
    return fields
end

-- The hover projection has its own compact geometry, but it must be built
-- from the same field preferences as the account page.  Keeping this in one
-- helper prevents the rendered matrix and its measured window from drifting.
local function PreviewColumns(context, characters)
    local nameWidth = Theme:GetCharacterRowHeaderWidth(false, context, characters)
    if context and context.scope == "all" then
        -- Core's shared row-header measure caps the name and realm separately.
        -- This projection renders them as one identity, so reserve their
        -- combined width and never truncate the distinguishing server suffix.
        for _, character in ipairs(characters or {}) do
            nameWidth = math.max(nameWidth, Theme:MeasureText(Theme.Font.assist, CharacterLabel(character, context)) + Theme.Table.cellPadding)
        end
    end
    local columns = { { id = "name", title = "角色", width = nameWidth } }
    local settings = Addon:GetSettings().previewColumns
    local function Add(id, title)
        if settings[id] ~= false then
            columns[#columns + 1] = { id = id, title = title, width = Theme:GetMatrixTargetColumnWidth(16, Theme.Font.assist, title) }
        end
    end
    Add("slot", "槽位")
    Add("spec", "专精")
    for i = 1, 6 do Add("talent" .. i, "天赋" .. i) end
    for i = 1, 3 do Add("major" .. i, "大雕" .. i) end
    for i = 1, 3 do Add("minor" .. i, "小雕" .. i) end
    Add("equipment", "装备")
    return columns
end

local function PreviewCharacters(context)
    local eligible = Eligible(context)
    -- A hover is a scan-friendly account projection, not a second scroll
    -- window.  The product contract caps it at twenty data-bearing roles.
    while #eligible > 20 do table.remove(eligible) end
    return eligible
end

local function CreatePreviewCell(parent)
    local cell = CreateFrame("Button", nil, parent)
    cell:RegisterForClicks("LeftButtonUp")
    cell.text = Text(cell, Theme.Font.assist, C.text, "LEFT")
    cell.text:SetAllPoints()
    return cell
end

local function SetPreviewCellTooltip(cell, entry)
    cell:SetScript("OnEnter", nil)
    cell:SetScript("OnLeave", nil)
    if entry and (entry.glyphLink or (entry.spellID and entry.spellID ~= 0)) then SetSpellTooltip(cell, entry) end
end

local function SetPreviewEquipmentTooltip(cell, equipment, confirmed)
    cell:SetScript("OnEnter", nil)
    cell:SetScript("OnLeave", nil)
    if not equipment then return end
    cell:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(confirmed and "已确认装备快照" or "待确认装备观测", confirmed and C.success[1] or C.warning[1], confirmed and C.success[2] or C.warning[2], confirmed and C.success[3] or C.warning[3])
        if equipment.capturedAt then GameTooltip:AddLine(date("%Y-%m-%d %H:%M", equipment.capturedAt), C.muted[1], C.muted[2], C.muted[3]) end
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function Page.Create(parent)
    parent.buildsRoster = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    parent.buildsRoster:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.buildsRoster:SetBackdropColor(C.nav[1], C.nav[2], C.nav[3], 0.95); parent.buildsRoster:SetBackdropBorderColor(C.lineSoft[1], C.lineSoft[2], C.lineSoft[3], C.lineSoft[4])
    parent.buildsRoster.title = Text(parent.buildsRoster, Theme.Font.section, C.text)
    parent.buildsRoster.title:SetPoint("TOPLEFT", Theme.Space.sm, -Theme.Space.sm); parent.buildsRoster.title:SetText("角色列表")
    parent.buildsRoster.scroll = Theme:CreateScrollFrame(parent.buildsRoster)
    parent.buildsRoster.scroll:SetPoint("TOPLEFT", Theme.Space.xs, -38)
    parent.buildsRoster.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, Theme.Space.xs)
    parent.buildsRoster.body = CreateFrame("Frame", nil, parent.buildsRoster.scroll)
    parent.buildsRoster.scroll:SetScrollChild(parent.buildsRoster.body)
    parent.buildsRoster.scroll:HookScript("OnSizeChanged", function(scroll) parent.buildsRoster.body:SetWidth(math.max(1, scroll:GetWidth())) end)
    parent.buildsRoster.rows = {}

    parent.buildsMain = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    parent.buildsMain:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.buildsMain:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.96); parent.buildsMain:SetBackdropBorderColor(C.lineSoft[1], C.lineSoft[2], C.lineSoft[3], C.lineSoft[4])

    parent.buildsToolbar = CreateFrame("Frame", nil, parent.buildsMain)
    parent.buildsToolbar.primary = Theme:CreateButton(parent.buildsToolbar, 94, "主天赋", "secondary")
    parent.buildsToolbar.secondary = Theme:CreateButton(parent.buildsToolbar, 94, "副天赋", "secondary")
    parent.buildsToolbar.status = Text(parent.buildsToolbar, Theme.Font.assist, C.accent)
    parent.buildsToolbar.buildToggle = Theme:CreateButton(parent.buildsToolbar, 96, "收起构筑", "secondary")
    -- The toggle must sit above both content panes; keeping it under the
    -- toolbar allowed a pane backdrop to cover its hit target.
    parent.buildsToolbar.buildToggle:SetParent(parent.buildsMain)
    parent.buildsToolbar.buildToggle:SetFrameLevel(parent.buildsMain:GetFrameLevel() + 10)
    parent.buildsToolbar.specIcon = CreateFrame("Button", nil, parent.buildsToolbar, "BackdropTemplate")
    parent.buildsToolbar.specIcon:SetSize(28, 28)
    parent.buildsToolbar.specIcon:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.buildsToolbar.specIcon:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    parent.buildsToolbar.specIcon.texture = parent.buildsToolbar.specIcon:CreateTexture(nil, "ARTWORK")
    parent.buildsToolbar.specIcon.texture:SetPoint("TOPLEFT", 2, -2); parent.buildsToolbar.specIcon.texture:SetPoint("BOTTOMRIGHT", -2, 2)
    parent.buildsToolbar.specName = Text(parent.buildsToolbar, Theme.Font.assist, C.text)
    parent.buildsToolbar.specName:SetWidth(96)

    parent.buildsEquipment = CreateFrame("Frame", nil, parent.buildsMain, "BackdropTemplate")
    parent.buildsEquipment:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    parent.buildsEquipment:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.55)
    parent.buildsEquipment.model = CreateFrame("DressUpModel", nil, parent.buildsEquipment)
    parent.buildsEquipment.model:SetPoint("TOPLEFT", 58, -4); parent.buildsEquipment.model:SetPoint("BOTTOMRIGHT", -58, 4)
    parent.buildsEquipment.model:SetFrameLevel(parent.buildsEquipment:GetFrameLevel() + 1)
    parent.buildsEquipment.model:EnableMouse(false)
    parent.buildsEquipment.modelControl = CreateFrame("Frame", nil, parent.buildsEquipment)
    parent.buildsEquipment.modelControl:SetPoint("TOPLEFT", 110, -45)
    parent.buildsEquipment.modelControl:SetPoint("BOTTOMRIGHT", -110, 58)
    parent.buildsEquipment.modelControl:SetFrameLevel(parent.buildsEquipment.model:GetFrameLevel() + 1)
    parent.buildsEquipment.modelControl:EnableMouse(true)
    parent.buildsEquipment.modelControl:EnableMouseWheel(true)
    parent.buildsEquipment.modelControl:RegisterForDrag("LeftButton")
    parent.buildsEquipment.modelControl:SetScript("OnDragStart", function(self)
        self.lastCursorX = GetCursorPosition()
    end)
    parent.buildsEquipment.modelControl:SetScript("OnDragStop", function(self) self.lastCursorX = nil end)
    parent.buildsEquipment.modelControl:SetScript("OnUpdate", function(self)
        if not self.lastCursorX then return end
        local x = GetCursorPosition()
        local delta = (x - self.lastCursorX) / (self:GetEffectiveScale() or 1)
        self.lastCursorX = x
        local model = parent.buildsEquipment.model
        model.buildsFacing = (model.buildsFacing or (model.GetFacing and model:GetFacing()) or 0) + delta * 0.012
        if model.SetFacing then model:SetFacing(model.buildsFacing) end
    end)
    parent.buildsEquipment.modelControl:SetScript("OnMouseWheel", function(_, delta)
        local model = parent.buildsEquipment.model
        model.buildsZoom = math.max(0.65, math.min(1.55, (model.buildsZoom or 1) - delta * 0.08))
        if model.SetCamDistanceScale then model:SetCamDistanceScale(model.buildsZoom)
        elseif model.SetModelScale then model:SetModelScale(1 / model.buildsZoom) end
    end)
    parent.buildsEquipment.modelHint = Text(parent.buildsEquipment.modelControl, Theme.Font.meta, C.muted, "CENTER")
    parent.buildsEquipment.modelHint:SetPoint("BOTTOM", parent.buildsEquipment, "BOTTOM", 0, 90)
    parent.buildsEquipment.modelHint:SetText("拖动旋转 · 滚轮缩放")
    parent.buildsEquipment.empty = Text(parent.buildsEquipment, Theme.Font.assist, C.muted, "CENTER")
    parent.buildsEquipment.empty:SetAllPoints(); parent.buildsEquipment.empty:SetText("选择角色查看装备快照")
    parent.buildsEquipment.items = {}
    parent.buildsToolbar.appearance = Theme:CreateButton(parent.buildsEquipment, 120, "原型 / 幻化", "secondary")
    parent.buildsToolbar.appearance:SetFrameLevel(parent.buildsEquipment.model:GetFrameLevel() + 2)

    parent.buildsBuild = CreateFrame("Frame", nil, parent.buildsMain, "BackdropTemplate")
    parent.buildsBuild:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    parent.buildsBuild:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.9)
    parent.buildsBuild.talentTitle = Text(parent.buildsBuild, Theme.Font.section, C.text); parent.buildsBuild.talentTitle:SetText("天赋")
    parent.buildsBuild.glyphTitle = Text(parent.buildsBuild, Theme.Font.section, C.text); parent.buildsBuild.glyphTitle:SetText("雕文")
    parent.buildsBuild.majorGlyphTitle = Text(parent.buildsBuild, Theme.Font.assist, C.muted); parent.buildsBuild.majorGlyphTitle:SetText("大型雕文")
    parent.buildsBuild.minorGlyphTitle = Text(parent.buildsBuild, Theme.Font.assist, C.muted); parent.buildsBuild.minorGlyphTitle:SetText("小型雕文")
    parent.buildsBuild.currentGlyphs = Theme:CreateButton(parent.buildsBuild, 52, "当前", "secondary")
    parent.buildsBuild.allGlyphs = Theme:CreateButton(parent.buildsBuild, 52, "所有", "secondary")
    parent.buildsBuild.currentGlyphs:SetHeight(28)
    parent.buildsBuild.allGlyphs:SetHeight(28)
    parent.buildsBuild.talents, parent.buildsBuild.glyphs = {}, {}
    parent.buildsBuild.catalog = Theme:CreateScrollFrame(parent.buildsBuild)
    parent.buildsBuild.catalogBody = CreateFrame("Frame", nil, parent.buildsBuild.catalog)
    parent.buildsBuild.catalog:SetScrollChild(parent.buildsBuild.catalogBody)
    -- CreateScrollFrame releases exactly one 16px gutter when its scrollbar
    -- is visible.  Do not reserve a second local gutter inside the list;
    -- doing so left an empty lane between glyph rows and the thumb.
    parent.buildsBuild.catalog:HookScript("OnSizeChanged", function(scroll) parent.buildsBuild.catalogBody:SetWidth(math.max(1, scroll:GetWidth())) end)
    parent.buildsBuild.catalogRows = {}
    parent.buildsBuild.catalogEmpty = Text(parent.buildsBuild.catalogBody, Theme.Font.assist, C.muted, "CENTER")
    parent.buildsBuild.catalogEmpty:SetPoint("TOP", 0, -20)
    parent.buildsBuild.catalogMajor = Theme:CreateButton(parent.buildsBuild, 1, "大型雕文", "secondary")
    parent.buildsBuild.catalogMinor = Theme:CreateButton(parent.buildsBuild, 1, "小型雕文", "secondary")
    for _, control in ipairs({ parent.buildsBuild.catalogMajor, parent.buildsBuild.catalogMinor }) do
        control.typeIcon = control:CreateTexture(nil, "ARTWORK")
        control.typeIcon:SetSize(16, 16); control.typeIcon:SetPoint("LEFT", 10, 0)
    end
    parent.buildsBuild.catalogMajor.typeIcon:SetTexture("Interface\\Icons\\INV_Glyph_Major")
    parent.buildsBuild.catalogMinor.typeIcon:SetTexture("Interface\\Icons\\INV_Glyph_Minor")
    parent.buildsBuild.catalog:Hide()
    parent.buildsBuild.catalogMajor:Hide(); parent.buildsBuild.catalogMinor:Hide()

    parent.buildsConfirm = Theme:CreateButton(parent.buildsMain, 160, "确认此构筑装备  >", "default")
    parent.buildsEmpty = Text(parent, Theme.Font.body, C.muted, "CENTER")
    parent.buildsEmpty:SetAllPoints(); parent.buildsEmpty:SetText("尚无构筑快照。请登录角色后稍候同步。")
end

local function RosterRow(parent, index)
    local row = parent.buildsRoster.rows[index]
    if row then return row end
    row = Theme:CreateButton(parent.buildsRoster.body, 1, "", "secondary")
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(30, 30); row.classIcon:SetPoint("LEFT", 7, 0)
    row.name = Text(row, Theme.Font.body, C.text)
    row.name:SetPoint("LEFT", row.classIcon, "RIGHT", 8, 0); row.name:SetPoint("RIGHT", -30, 0)
    row.level = Text(row, Theme.Font.assist, C.muted, "RIGHT")
    row.level:SetPoint("RIGHT", -8, 0)
    parent.buildsRoster.rows[index] = row
    return row
end

local function BuildCell(parent, pool, index)
    local row = pool[index]
    if row then return row end
    row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row.rule = row:CreateTexture(nil, "BORDER")
    row.rule:SetColorTexture(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
    row.rule:SetPoint("BOTTOMLEFT"); row.rule:SetPoint("BOTTOMRIGHT"); row.rule:SetHeight(1)
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetPoint("LEFT", 7, 0); row.icon:SetSize(34, 34)
    row.iconBorder = row:CreateTexture(nil, "BORDER")
    row.iconBorder:SetColorTexture(C.line[1], C.line[2], C.line[3], C.line[4])
    row.iconBorder:SetPoint("CENTER", row.icon); row.iconBorder:SetSize(38, 38)
    row.meta = Text(row, Theme.Font.meta, C.muted, "RIGHT"); row.meta:SetPoint("RIGHT", -7, 0); row.meta:SetWidth(44); row.meta:Hide()
    row.label = Text(row, Theme.Font.body, C.text); row.label:SetPoint("LEFT", row.icon, "RIGHT", 10, 0); row.label:SetPoint("RIGHT", row.meta, "LEFT", -8, 0)
    pool[index] = row
    return row
end

-- Keep glyph names and specialization in one reading group.  Names receive
-- the full row width; only a non-general specialization appears beneath it.
local function LayoutGlyphCellText(row, name, requirement, rowWidth, requirementColor)
    row.label:ClearAllPoints()
    row.meta:ClearAllPoints()
    row.label:SetText(tostring(name or ""))
    row.meta:SetText(requirement or "")
    local color = requirementColor or C.muted
    row.meta:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
    row.meta:SetJustifyH("LEFT")

    local leftInset = 7 + row.icon:GetWidth() + 10
    local availableWidth = math.max(1, (rowWidth or row:GetWidth() or 0) - leftInset - 7)
    row.label:SetWidth(availableWidth)
    if requirement and requirement ~= "" then
        row.label:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -4)
        row.meta:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
        row.meta:SetWidth(availableWidth)
        return true
    end
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
    return false
end

local function BuildColumnLayout(buildWidth)
    local contentWidth = buildWidth - 16
    -- This is a reading separator, not a protected empty lane.  Keep it
    -- narrow so the two text columns receive the usable horizontal space.
    local columnGap = math.max(10, math.floor(contentWidth * 0.015))
    local columnsWidth = contentWidth - columnGap
    local talentColumnWidth = math.floor(columnsWidth / 2)
    local glyphColumnWidth = talentColumnWidth
    return talentColumnWidth, glyphColumnWidth, 8 + talentColumnWidth + columnGap
end

local function EquipmentButton(parent, slotID)
    local button = parent.buildsEquipment.items[slotID]
    if button then return button end
    button = CreateIconButton(parent.buildsEquipment)
    button:SetFrameLevel(parent.buildsEquipment.modelControl:GetFrameLevel() + 1)
    for _, gem in ipairs(button.gems) do gem:SetFrameLevel(button:GetFrameLevel() + 1) end
    button.enchant:SetFrameLevel(button:GetFrameLevel() + 1)
    button.slotLabel = Text(button, Theme.Font.meta, C.muted, "RIGHT")
    button.slotLabel:SetWidth(30)
    parent.buildsEquipment.items[slotID] = button
    return button
end

local function PlaceEquipment(parent, snapshot)
    local box = parent.buildsEquipment
    local boxHeight = box.layoutHeight or box:GetHeight() or 500
    local rowHeight = math.max(39, math.min(80, math.floor((boxHeight - 125) / 8)))
    local iconSize = math.min(ICON_SIZE, rowHeight - 5)
    local boxWidth = box.layoutWidth or box:GetWidth() or 360
    local left, right = 42, boxWidth - iconSize - 42
    for _, slotID in ipairs(SLOT_ORDER) do
        local button = EquipmentButton(parent, slotID)
        local item = snapshot and snapshot.slots and snapshot.slots[tostring(slotID)]
        local side, visualIndex
        for index, id in ipairs(LEFT_SLOTS) do if id == slotID then side, visualIndex = "left", index; break end end
        if not side then for index, id in ipairs(RIGHT_SLOTS) do if id == slotID then side, visualIndex = "right", index; break end end end
        if not side then
            for index, id in ipairs(BOTTOM_SLOTS) do
                if id == slotID then side, visualIndex = index == 1 and "weapon-left" or "weapon-right", index; break end
            end
        end
        button:SetSize(iconSize, iconSize)
        button:ClearAllPoints()
        if side == "weapon-left" or side == "weapon-right" then
            -- Follow the original paper-doll's lower left/right weapon
            -- anchors rather than placing both weapons as a centred cluster.
            -- Their augment rails face outward: main-hand gems/enchant on the
            -- left, off-hand gems/enchant on the right.
            local weaponOffset = math.max(88, math.min(128, math.floor(boxWidth * 0.28)))
            button:SetPoint("BOTTOM", box, "BOTTOM", side == "weapon-left" and -weaponOffset or weaponOffset, 12)
        else
            button:SetPoint("TOPLEFT", box, "TOPLEFT", side == "left" and left or right, -12 - (visualIndex - 1) * rowHeight)
        end
        button.slotLabel:ClearAllPoints()
        if side == "left" then button.slotLabel:SetPoint("RIGHT", button, "LEFT", -4, 0); button.slotLabel:SetJustifyH("RIGHT")
        elseif side == "right" then button.slotLabel:SetPoint("LEFT", button, "RIGHT", 4, 0); button.slotLabel:SetJustifyH("LEFT")
        else button.slotLabel:SetPoint("BOTTOM", button, "TOP", 0, 22); button.slotLabel:SetJustifyH("CENTER") end
        button.slotLabel:SetText(SLOT_LABELS[slotID] or "")
        button.icon:SetTexture(item and item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        button.icon:SetDesaturated(not (item and item.itemLink))
        for gemIndex, gem in ipairs(button.gems) do
            local socket = item and item.gems and item.gems[gemIndex]
            gem:ClearAllPoints()
            if side == "left" or side == "weapon-right" then gem:SetPoint("TOPLEFT", button, "TOPRIGHT", 4 + (gemIndex - 1) * 17, -2)
            else gem:SetPoint("TOPRIGHT", button, "TOPLEFT", -4 - (gemIndex - 1) * 17, -2) end
            gem.icon:SetTexture(socket and socket.icon or nil)
            gem:SetShown(socket and socket.itemLink and true or false)
            SetAugmentTooltip(gem, nil, nil, socket and socket.itemLink)
        end
        button.enchant:ClearAllPoints()
        if side == "left" or side == "weapon-right" then button.enchant:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 4, 2)
        else button.enchant:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -4, 2) end
        local enchant = item and item.enchant
        button.enchant:SetShown(enchant and enchant.enchantID and enchant.enchantID > 0 or false)
        SetAugmentTooltip(button.enchant, item, enchant and (enchant.name or ("#" .. enchant.enchantID)) or "附魔")
        local red, green, blue = ItemBorderColor(item)
        button:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 1); button:SetBackdropBorderColor(red, green, blue, 1)
        SetNativeItemTooltip(button, item)
        button:Show(); button.slotLabel:Show()
    end
end

local function RefreshModel(parent, character, equipment)
    local model = parent.buildsEquipment.model
    local available = IsCurrent(character) and model and model.SetUnit
    parent.buildsEquipment.modelControl:SetShown(available and true or false)
    parent.buildsEquipment.modelHint:SetShown(available and true or false)
    if not available then model:Hide(); return end
    model:SetUnit("player")
    -- SetUnit renders the current transmogged unit. For the prototype view,
    -- TryOn the immutable saved item links over that model, which asks the
    -- native dress-up renderer for each base item's own appearance.
    if Addon:GetSettings().appearanceMode == "prototype" and model.TryOn and equipment and equipment.slots then
        for _, slotID in ipairs(SLOT_ORDER) do
            local item = equipment.slots[tostring(slotID)]
            if item and item.itemLink then pcall(model.TryOn, model, item.itemLink) end
        end
    end
    if model.buildsFacing and model.SetFacing then model:SetFacing(model.buildsFacing) end
    if model.buildsZoom then
        if model.SetCamDistanceScale then model:SetCamDistanceScale(model.buildsZoom)
        elseif model.SetModelScale then model:SetModelScale(1 / model.buildsZoom) end
    end
    model:Show()
end

local function RenderCatalog(parent, slotData, record)
    local build = parent.buildsBuild
    local buildWidth = build.layoutWidth or build:GetWidth()
    local talentColumnWidth, glyphColumnWidth, glyphLeft = BuildColumnLayout(buildWidth)
    local selectedType = parent.buildsCatalogType == "minor" and "minor" or "major"
    local glyphType = selectedType == "minor" and (GLYPH_TYPE_MINOR or 2) or (GLYPH_TYPE_MAJOR or 1)
    local glyphs, index = {}, 0
    local current = {}
    for _, entry in ipairs((slotData and slotData.glyphs and slotData.glyphs.major) or {}) do if entry.glyphID and entry.glyphID > 0 then current[entry.glyphID] = true end end
    for _, entry in ipairs((slotData and slotData.glyphs and slotData.glyphs.minor) or {}) do if entry.glyphID and entry.glyphID > 0 then current[entry.glyphID] = true end end
    for _, entry in ipairs(record and record.glyphCatalog or {}) do
        if entry.glyphType == glyphType then
            local group = current[entry.glyphID] and "当前" or (entry.isKnown and "已学" or "未学")
            glyphs[#glyphs + 1] = { group = group, entry = entry }
        end
    end
    if #glyphs == 0 then
        for _, entry in ipairs((slotData and slotData.glyphs and slotData.glyphs[selectedType]) or {}) do
            if (entry.glyphID and entry.glyphID > 0) or (entry.spellID and entry.spellID > 0) then glyphs[#glyphs + 1] = { group = "当前", entry = entry } end
        end
    end
    local categoryWidth = math.floor((glyphColumnWidth - 4) / 2)
    build.catalogMajor:ClearAllPoints(); build.catalogMajor:SetPoint("TOPLEFT", build, "TOPLEFT", glyphLeft, -42); build.catalogMajor:SetSize(categoryWidth, 28)
    build.catalogMinor:ClearAllPoints(); build.catalogMinor:SetPoint("TOPLEFT", build.catalogMajor, "TOPRIGHT", 4, 0); build.catalogMinor:SetSize(categoryWidth, 28)
    build.catalogMajor:SetState(selectedType == "major" and "selected" or "default")
    build.catalogMinor:SetState(selectedType == "minor" and "selected" or "default")
    if not build.catalogMajor.buildsTooltipBound then
        build.catalogMajor.buildsTooltipBound = true
        build.catalogMajor:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("大型雕文"); GameTooltip:Show()
        end)
        build.catalogMinor:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("小型雕文"); GameTooltip:Show()
        end)
        build.catalogMajor:HookScript("OnLeave", function() GameTooltip:Hide() end)
        build.catalogMinor:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    build.catalogMajor:SetScript("OnClick", function()
        if parent.buildsCatalogType == "major" then return end
        parent.buildsCatalogType = "major"; build.catalog:SetVerticalScroll(0); Page.Refresh(parent, parent.buildsContext)
    end)
    build.catalogMinor:SetScript("OnClick", function()
        if parent.buildsCatalogType == "minor" then return end
        parent.buildsCatalogType = "minor"; build.catalog:SetVerticalScroll(0); Page.Refresh(parent, parent.buildsContext)
    end)
    build.catalog:ClearAllPoints(); build.catalog:SetPoint("TOPLEFT", build, "TOPLEFT", glyphLeft, -76); build.catalog:SetPoint("BOTTOMRIGHT", build, "BOTTOMRIGHT", -8, 8)
    -- The shared scroll frame has already reduced its viewport by the live
    -- scrollbar gutter.  Its full width is therefore the usable row width.
    local catalogWidth = math.max(1, build.catalog:GetWidth() or glyphColumnWidth)
    build.catalogBody:SetWidth(catalogWidth)
    for _, pair in ipairs(glyphs) do
        index = index + 1
        local row = BuildCell(build.catalogBody, build.catalogRows, index)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", build.catalogBody, "TOPLEFT", 0, -((index - 1) * CATALOG_ROW_HEIGHT)); row:SetPoint("RIGHT", build.catalogBody, "RIGHT", 0, 0); row:SetHeight(CATALOG_ROW_HEIGHT - 2)
        row.icon:SetSize(46, 46); row.iconBorder:SetSize(50, 50)
        row.icon:SetTexture(pair.entry.icon); row.icon:SetDesaturated(pair.group == "未学"); row.rule:Show()
        row.meta:SetShown(LayoutGlyphCellText(row, pair.entry.name, GlyphRequirementText(pair.entry), catalogWidth, ClassColor(parent.buildsSelectedCharacter)))
        row.label:SetTextColor(pair.group == "未学" and C.muted[1] or C.text[1], pair.group == "未学" and C.muted[2] or C.text[2], pair.group == "未学" and C.muted[3] or C.text[3])
        row.iconBorder:SetColorTexture(pair.group == "当前" and C.accent[1] or C.line[1], pair.group == "当前" and C.accent[2] or C.line[2], pair.group == "当前" and C.accent[3] or C.line[3], 1)
        local fill = pair.group == "当前" and C.selected or C.row
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.alternate[1], C.alternate[2], C.alternate[3], 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local shown
            if pair.entry.glyphLink then shown = pcall(GameTooltip.SetHyperlink, GameTooltip, pair.entry.glyphLink) end
            if not shown and pair.entry.glyphID and pair.entry.glyphID > 0 and GameTooltip.SetGlyphByID then shown = pcall(GameTooltip.SetGlyphByID, GameTooltip, pair.entry.glyphID) end
            if not shown and pair.entry.spellID and pair.entry.spellID > 0 and GameTooltip.SetSpellByID then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, pair.entry.spellID) end
            if not shown then GameTooltip:AddLine(pair.entry.name or "雕文") end
            if pair.group == "当前" then GameTooltip:AddLine("当前构筑已使用", C.accent[1], C.accent[2], C.accent[3]) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(fill[1], fill[2], fill[3], 1); GameTooltip:Hide() end)
        row:SetBackdropColor(fill[1], fill[2], fill[3], 1); row:Show()
    end
    for i = index + 1, #build.catalogRows do build.catalogRows[i]:Hide() end
    build.catalogEmpty:SetText(selectedType == "major" and "暂无大型雕文快照" or "暂无小型雕文快照")
    build.catalogEmpty:SetShown(index == 0)
    build.catalogBody:SetSize(catalogWidth, math.max(52, index * CATALOG_ROW_HEIGHT)); build.catalog:SetContentHeight(build.catalogBody:GetHeight())
end

local function RenderBuildColumns(parent, slotData, record)
    local build = parent.buildsBuild
    local buildWidth = build.layoutWidth or build:GetWidth()
    local buildHeight = build.layoutHeight or build:GetHeight()
    local height = math.max(1, buildHeight - 50)
    local rowHeight = math.floor(height / 6)
    local glyphRowHeight = rowHeight
    local talentColumnWidth, glyphColumnWidth, glyphLeft = BuildColumnLayout(buildWidth)
    for index = 1, 6 do
        local talent = slotData and slotData.talents and slotData.talents[index] or { name = "未记录", icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
        local glyphs = slotData and slotData.glyphs
        local glyph = glyphs and (index <= 3 and glyphs.major and glyphs.major[index] or index > 3 and glyphs.minor and glyphs.minor[index - 3])
        glyph = glyph or { name = "未选择", icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
        local left = BuildCell(build, build.talents, index); left:ClearAllPoints(); left:SetPoint("TOPLEFT", build, "TOPLEFT", 8, -42 - (index - 1) * rowHeight); left:SetSize(talentColumnWidth, rowHeight - 3)
        left.icon:SetSize(56, 56); left.iconBorder:SetSize(60, 60)
        left.label:ClearAllPoints(); left.label:SetPoint("LEFT", left.icon, "RIGHT", 10, 0); left.label:SetPoint("RIGHT", left, "RIGHT", -8, 0)
        left.icon:SetTexture(talent.icon); left.label:SetText(talent.name); left.meta:Hide(); left.rule:Hide(); left:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.5); SetSpellTooltip(left, talent); left:Show()
        local glyphTop = 42 + (index - 1) * glyphRowHeight
        local right = BuildCell(build, build.glyphs, index); right:ClearAllPoints(); right:SetPoint("TOPLEFT", build, "TOPLEFT", glyphLeft, -glyphTop); right:SetSize(glyphColumnWidth, glyphRowHeight - 3)
        local isMajor = index <= 3
        local border = isMajor and C.warning or C.accent
        local glyphIconSize = isMajor and 56 or 40
        right.icon:SetSize(glyphIconSize, glyphIconSize); right.iconBorder:SetSize(glyphIconSize + 4, glyphIconSize + 4)
        right.icon:SetTexture(glyph.icon); right.meta:SetShown(LayoutGlyphCellText(right, glyph.name, GlyphRequirementText(glyph), glyphColumnWidth, ClassColor(parent.buildsSelectedCharacter))); right.rule:Hide(); right.iconBorder:SetColorTexture(border[1], border[2], border[3], 1); right:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.5); SetSpellTooltip(right, glyph); right:Show()
    end
    build.talentTitle:ClearAllPoints(); build.talentTitle:SetPoint("TOPLEFT", 12, -10)
    build.glyphTitle:ClearAllPoints(); build.glyphTitle:SetPoint("TOPLEFT", glyphLeft, -10)
    build.allGlyphs:ClearAllPoints(); build.allGlyphs:SetPoint("TOPRIGHT", -5, -3)
    build.currentGlyphs:ClearAllPoints(); build.currentGlyphs:SetPoint("RIGHT", build.allGlyphs, "LEFT", -4, 0)
    RenderCatalog(parent, slotData, record)
end

local function SetupMainButtons(parent)
    local toolbar = parent.buildsToolbar
    toolbar.primary:SetScript("OnClick", function() parent.buildsSlot = "primary"; Addon.AccountPage.Refresh(parent, parent.buildsContext) end)
    toolbar.secondary:SetScript("OnClick", function()
        local selected = parent.buildsSelectedCharacter
        local record = selected and Addon.Snapshot:GetCharacter(selected.id)
        if not (record and record.slots and record.slots.secondary) then return end
        parent.buildsSlot = "secondary"; Addon.AccountPage.Refresh(parent, parent.buildsContext)
    end)
    toolbar.buildToggle:SetScript("OnClick", function()
        parent.buildsBuildCollapsed = not parent.buildsBuildCollapsed
        -- Keep the page's layout state available to Core before it measures the
        -- next surface.  The refresh below may resize the shared account frame.
        Addon.buildsBuildCollapsed = parent.buildsBuildCollapsed
        Core.AccountView:RefreshPage()
    end)
    toolbar.buildToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(parent.buildsBuildCollapsed and "展开天赋与雕文" or "折叠天赋与雕文，扩展装备视图")
        GameTooltip:Show()
    end)
    toolbar.buildToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    toolbar.appearance:SetScript("OnClick", function()
        if not IsCurrent(parent.buildsSelectedCharacter) then return end
        local settings = Addon:GetSettings(); settings.appearanceMode = settings.appearanceMode == "transmog" and "prototype" or "transmog"
        Addon.AccountPage.Refresh(parent, parent.buildsContext)
    end)
    parent.buildsBuild.currentGlyphs:SetScript("OnClick", function()
        if not parent.buildsGlyphCatalogOpen then return end
        parent.buildsGlyphCatalogOpen = false
        Addon.AccountPage.Refresh(parent, parent.buildsContext)
    end)
    parent.buildsBuild.allGlyphs:SetScript("OnClick", function()
        if parent.buildsGlyphCatalogOpen then return end
        parent.buildsGlyphCatalogOpen = true
        Addon.AccountPage.Refresh(parent, parent.buildsContext)
    end)
    parent.buildsConfirm:SetScript("OnClick", function()
        local selected = parent.buildsSelectedCharacter
        if not selected or not IsCurrent(selected) then Addon:Print("请在当前登录角色上确认装备。") return end
        local record = Addon.Snapshot:GetCharacter(selected.id)
        local slot = parent.buildsSlot or (record and record.lastActiveSlot) or "primary"
        if not record or record.lastActiveSlot ~= slot then return end
        local existing = record and record.slots and record.slots[slot] and record.slots[slot].confirmedEquipment
        if existing and StaticPopup_Show then
            StaticPopupDialogs.YIBO_BUILDS_CONFIRM_OVERWRITE = StaticPopupDialogs.YIBO_BUILDS_CONFIRM_OVERWRITE or {
                text = "将覆盖该天赋槽位已确认的构筑装备。是否继续？", button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
                OnAccept = function() Addon.Snapshot:ConfirmEquipment(slot) end,
            }
            StaticPopup_Show("YIBO_BUILDS_CONFIRM_OVERWRITE")
        else
            local ok, err = Addon.Snapshot:ConfirmEquipment(slot)
            if not ok then Addon:Print(err) end
        end
    end)
end

local function LayoutMain(parent)
    local inset = Theme:GetMatrixInsets(false)
    if parent.buildsPreviewToggle then parent.buildsPreviewToggle:Hide() end
    if parent.buildsPreviewHeader then parent.buildsPreviewHeader:Hide() end
    if parent.buildsPreviewBody then parent.buildsPreviewBody:Hide() end
    local availableWidth = parent:GetWidth() or 0
    local availableHeight = parent:GetHeight() or 0
    if availableWidth < 1 then availableWidth = 860 end
    if availableHeight < 1 then availableHeight = 520 end
    local collapsed = parent.buildsBuildCollapsed == true
    -- Folding hides only the build pane.  The roster and equipment pane retain
    -- their expanded widths, so the visual hierarchy does not jump.
    local rosterWidth = (collapsed or availableWidth >= 1050) and 210 or (availableWidth >= 850 and 185 or 160)
    parent.buildsRoster:ClearAllPoints(); parent.buildsRoster:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top); parent.buildsRoster:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset.left, inset.bottom); parent.buildsRoster:SetWidth(rosterWidth)
    parent.buildsMain:ClearAllPoints(); parent.buildsMain:SetPoint("TOPLEFT", parent.buildsRoster, "TOPRIGHT", Theme.Space.sm, 0); parent.buildsMain:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    parent.buildsToolbar:ClearAllPoints(); parent.buildsToolbar:SetPoint("TOPLEFT", parent.buildsMain, "TOPLEFT", Theme.Space.sm, -Theme.Space.sm); parent.buildsToolbar:SetPoint("TOPRIGHT", parent.buildsMain, "TOPRIGHT", -Theme.Space.sm, -Theme.Space.sm); parent.buildsToolbar:SetHeight(Theme.Size.standard)
    parent.buildsToolbar.primary:SetPoint("LEFT"); parent.buildsToolbar.secondary:SetPoint("LEFT", parent.buildsToolbar.primary, "RIGHT", 4, 0)
    parent.buildsToolbar.specIcon:SetPoint("LEFT", parent.buildsToolbar.secondary, "RIGHT", 12, 0)
    parent.buildsToolbar.specName:SetPoint("LEFT", parent.buildsToolbar.specIcon, "RIGHT", 6, 0)
    parent.buildsToolbar.status:SetPoint("RIGHT")
    local mainWidth = availableWidth - inset.left - inset.right - rosterWidth - Theme.Space.sm
    local mainHeight = availableHeight - inset.top - inset.bottom
    Addon.buildsBuildCollapsed = collapsed
    -- The folded layout still needs a usable action strip. Keep the status and
    -- toggle in a fixed right-side group, and give the specialization label a
    -- smaller slot so it cannot cover the toggle when the window is narrow.
    parent.buildsToolbar.specName:SetWidth(collapsed and 72 or 96)
    parent.buildsToolbar.status:SetWidth(collapsed and 132 or 180)
    parent.buildsToolbar.buildToggle:SetSize(44, Theme.Size.compact)
    local equipmentRatio = 0.55
    local equipmentWidth = math.floor((mainWidth - Theme.Space.sm * 3) * equipmentRatio)
    parent.buildsConfirm:ClearAllPoints(); parent.buildsConfirm:SetPoint("BOTTOMLEFT", parent.buildsMain, "BOTTOMLEFT", Theme.Space.sm, Theme.Space.sm); parent.buildsConfirm:SetPoint("BOTTOMRIGHT", parent.buildsMain, "BOTTOMRIGHT", -Theme.Space.sm, Theme.Space.sm); parent.buildsConfirm:SetHeight(48)
    parent.buildsEquipment:ClearAllPoints(); parent.buildsEquipment:SetPoint("TOPLEFT", parent.buildsToolbar, "BOTTOMLEFT", 0, -Theme.Space.sm); parent.buildsEquipment:SetPoint("BOTTOMLEFT", parent.buildsConfirm, "TOPLEFT", 0, Theme.Space.sm)
    if collapsed then
        parent.buildsEquipment:SetPoint("RIGHT", parent.buildsMain, "RIGHT", -Theme.Space.sm, 0)
        parent.buildsEquipment.layoutWidth = mainWidth - Theme.Space.sm * 2
        parent.buildsBuild:Hide()
    else
        parent.buildsEquipment:SetWidth(equipmentWidth)
        parent.buildsBuild:ClearAllPoints(); parent.buildsBuild:SetPoint("TOPLEFT", parent.buildsEquipment, "TOPRIGHT", Theme.Space.sm, 0); parent.buildsBuild:SetPoint("BOTTOMRIGHT", parent.buildsConfirm, "TOPRIGHT", 0, Theme.Space.sm); parent.buildsBuild:Show()
        parent.buildsEquipment.layoutWidth = equipmentWidth
        parent.buildsBuild.layoutWidth = mainWidth - Theme.Space.sm * 3 - equipmentWidth
        parent.buildsBuild.layoutHeight = parent.buildsBuild:GetHeight()
    end
    parent.buildsEquipment.layoutHeight = parent.buildsEquipment:GetHeight()
    parent.buildsToolbar.appearance:ClearAllPoints(); parent.buildsToolbar.appearance:SetPoint("TOP", parent.buildsEquipment, "TOP", 0, -10)
    parent.buildsToolbar.buildToggle:ClearAllPoints()
    -- The equipment pane keeps the same width in both modes, so it provides a
    -- stable anchor for the fold control as the build pane comes and goes.
    parent.buildsToolbar.buildToggle:SetPoint("BOTTOMRIGHT", parent.buildsEquipment, "BOTTOMRIGHT", -8, 8)
end

function Page.Refresh(parent, context)
    parent.buildsContext = context
    local preview = context and context.preview
    if preview then return Page.RefreshPreview(parent, context) end
    LayoutMain(parent)
    parent.buildsEmpty:Hide(); parent.buildsRoster:Show(); parent.buildsMain:Show()
    local characters = Eligible(context)
    local selected
    for _, character in ipairs(characters) do if character.id == parent.buildsSelectedID then selected = character break end end
    if not selected then
        for _, character in ipairs(characters) do if IsCurrent(character) then selected = character break end end
    end
    selected = selected or characters[1]
    parent.buildsSelectedID = selected and selected.id
    parent.buildsSelectedCharacter = selected
    local rosterWidth = math.max(1, parent.buildsRoster.scroll:GetWidth() or 160)
    parent.buildsRoster.body:SetSize(rosterWidth, math.max(1, #characters * ROSTER_ROW_HEIGHT))
    parent.buildsRoster.scroll:SetContentHeight(parent.buildsRoster.body:GetHeight())
    for index, character in ipairs(characters) do
        local row = RosterRow(parent, index); row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent.buildsRoster.body, "TOPLEFT", 0, -((index - 1) * ROSTER_ROW_HEIGHT)); row:SetPoint("RIGHT", parent.buildsRoster.body, "RIGHT", 0, 0); row:SetHeight(ROSTER_ROW_HEIGHT - 2)
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.class]
        if coords then row.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"); row.classIcon:SetTexCoord(unpack(coords)); row.classIcon:Show() else row.classIcon:Hide() end
        row.name:SetText(character.name or "未知角色"); local color = ClassColor(character); row.name:SetTextColor(color.r, color.g, color.b)
        row.level:SetText(tostring(character.level or ""))
        row:SetState(character.id == parent.buildsSelectedID and "selected" or "default")
        row:SetScript("OnClick", function() parent.buildsSelectedID = character.id; Addon.AccountPage.Refresh(parent, parent.buildsContext) end); row:Show()
    end
    for index = #characters + 1, #parent.buildsRoster.rows do parent.buildsRoster.rows[index]:Hide() end
    if not selected then parent.buildsEmpty:Show(); parent.buildsRoster:Hide(); parent.buildsMain:Hide(); return end
    local record = Addon.Snapshot:GetCharacter(selected.id)
    if IsCurrent(selected) and parent.buildsGlyphProbeID ~= selected.id then
        parent.buildsGlyphProbeID = selected.id
        Addon.Snapshot:ScheduleCapture("page-open", 0.1)
    end
    local slot = parent.buildsSlot or record.lastActiveSlot or "primary"
    if slot == "secondary" and not (record.slots and record.slots.secondary) then slot = "primary" end
    parent.buildsSlot = slot
    local slotData = record.slots and record.slots[slot]
    local equipment = slotData and (slotData.confirmedEquipment or slotData.observedEquipment)
    parent.buildsToolbar.primary:SetState(slot == "primary" and "selected" or "default")
    parent.buildsToolbar.secondary:SetState(slot == "secondary" and "selected" or (record.slots and record.slots.secondary and "default" or "disabled"))
    local spec = slotData and slotData.specialization
    parent.buildsToolbar.specIcon.texture:SetTexture(spec and spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local itemLevel = equipment and tonumber(equipment.itemLevel)
    parent.buildsToolbar.specName:SetText((spec and spec.name or "未知专精") .. (itemLevel and (" " .. tostring(math.floor(itemLevel + 0.5))) or ""))
    parent.buildsToolbar.specIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(spec and spec.name or "未知专精")
        GameTooltip:Show()
    end)
    parent.buildsToolbar.specIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local mode = Addon:GetSettings().appearanceMode
    parent.buildsToolbar.appearance:SetText(not IsCurrent(selected) and "原型 / 幻化" or (mode == "transmog" and "原型 / |cff20e070幻化|r" or "|cff20e070原型|r / 幻化"))
    parent.buildsToolbar.appearance:SetState(IsCurrent(selected) and "default" or "disabled")
    parent.buildsToolbar.buildToggle:SetText(parent.buildsBuildCollapsed and ">>" or "<<")
    parent.buildsToolbar.buildToggle:SetState("default")
    parent.buildsToolbar.status:SetText((record.lastActiveSlot == slot and "当前使用" or "备用构筑") .. " · " .. ((slotData and slotData.confirmedEquipment) and "装备已确认" or "装备待确认"))
    PlaceEquipment(parent, equipment)
    parent.buildsEquipment.empty:SetText(not equipment and "尚无装备快照" or (not IsCurrent(selected) and "外观仅可预览当前角色" or ""))
    parent.buildsEquipment.empty:SetShown(not equipment or not IsCurrent(selected))
    RefreshModel(parent, selected, equipment)
    RenderBuildColumns(parent, slotData, record)
    local catalogOpen = parent.buildsGlyphCatalogOpen == true
    parent.buildsBuild.catalog:SetShown(catalogOpen)
    parent.buildsBuild.catalogMajor:SetShown(catalogOpen)
    parent.buildsBuild.catalogMinor:SetShown(catalogOpen)
    for _, row in ipairs(parent.buildsBuild.talents) do row:Show() end
    for _, row in ipairs(parent.buildsBuild.glyphs) do row:SetShown(not catalogOpen) end
    parent.buildsBuild.talentTitle:Show()
    parent.buildsBuild.glyphTitle:Show()
    parent.buildsBuild.majorGlyphTitle:Hide()
    parent.buildsBuild.minorGlyphTitle:Hide()
    parent.buildsBuild.currentGlyphs:SetState(catalogOpen and "default" or "selected")
    parent.buildsBuild.allGlyphs:SetState(catalogOpen and "selected" or "default")
    parent.buildsConfirm:SetState(IsCurrent(selected) and record.lastActiveSlot == slot and "selected" or "disabled")
    parent.buildsConfirm:SetText(slotData and slotData.confirmedEquipment and "更新此构筑装备  >" or "确认此构筑装备  >")
    SetupMainButtons(parent)
end

function Page.RefreshPreview(parent, context)
    parent.buildsEmpty:Hide(); parent.buildsRoster:Hide(); parent.buildsMain:Hide()
    local mode = parent.buildsPreviewMode or "current"
    local characters = PreviewCharacters(context)
    local columns = PreviewColumns(context, characters)
    parent.buildsPreviewToggle = parent.buildsPreviewToggle or CreateFrame("Frame", nil, parent)
    parent.buildsPreviewToggle.current = parent.buildsPreviewToggle.current or Theme:CreateButton(parent.buildsPreviewToggle, 52, "当前", "secondary")
    parent.buildsPreviewToggle.backup = parent.buildsPreviewToggle.backup or Theme:CreateButton(parent.buildsPreviewToggle, 52, "备用", "secondary")
    parent.buildsPreviewToggle:ClearAllPoints(); parent.buildsPreviewToggle:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6); parent.buildsPreviewToggle:SetSize(112, Theme.Size.compact)
    parent.buildsPreviewToggle.current:ClearAllPoints(); parent.buildsPreviewToggle.current:SetPoint("LEFT")
    parent.buildsPreviewToggle.backup:ClearAllPoints(); parent.buildsPreviewToggle.backup:SetPoint("LEFT", parent.buildsPreviewToggle.current, "RIGHT", 4, 0)
    parent.buildsPreviewToggle.current:SetState(mode == "current" and "selected" or "default")
    parent.buildsPreviewToggle.backup:SetState(mode == "backup" and "selected" or "default")
    parent.buildsPreviewToggle.current:SetScript("OnClick", function() parent.buildsPreviewMode = "current"; Page.RefreshPreview(parent, context) end)
    parent.buildsPreviewToggle.backup:SetScript("OnClick", function() parent.buildsPreviewMode = "backup"; Page.RefreshPreview(parent, context) end)
    parent.buildsPreviewToggle:Show()
    parent.buildsPreviewHeader = parent.buildsPreviewHeader or CreateFrame("Frame", nil, parent)
    parent.buildsPreviewBody = parent.buildsPreviewBody or CreateFrame("Frame", nil, parent)
    parent.buildsPreviewHeader:ClearAllPoints(); parent.buildsPreviewHeader:SetPoint("TOPLEFT", parent.buildsPreviewToggle, "BOTTOMLEFT", 0, -Theme.Space.xs)
    local width, x = 0, 0
    parent.buildsPreviewHeaders = parent.buildsPreviewHeaders or {}
    for index, col in ipairs(columns) do
        local header = parent.buildsPreviewHeaders[index] or Theme:CreateMatrixHeader(parent.buildsPreviewHeader); parent.buildsPreviewHeaders[index] = header
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", parent.buildsPreviewHeader, "TOPLEFT", x, 0); header:SetSize(col.width, Theme.Table.headerHeight); Theme:SetMatrixHeader(header, col.title, { height = Theme.Table.headerHeight, inset = 2 }); header:Show(); x = x + col.width
    end
    width = x; parent.buildsPreviewHeader:SetSize(width, Theme.Table.headerHeight)
    parent.buildsPreviewRows = parent.buildsPreviewRows or {}
    for ri, character in ipairs(characters) do
        local record = Addon.Snapshot:GetCharacter(character.id); local slotData = Addon.Snapshot:GetProjectedSlot(record, mode)
        local row = parent.buildsPreviewRows[ri] or CreateFrame("Button", nil, parent.buildsPreviewBody, "BackdropTemplate"); parent.buildsPreviewRows[ri] = row
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent.buildsPreviewBody, "TOPLEFT", 0, -((ri - 1) * Theme.Table.previewRowHeight)); row:SetSize(width, Theme.Table.previewRowHeight); row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); local fill = Theme:GetDataRowColor(ri); row:SetBackdropColor(fill[1], fill[2], fill[3], fill[4]); row.cells = row.cells or {}
        x = 0
        for ci, col in ipairs(columns) do
            local cell = row.cells[ci] or CreatePreviewCell(row); row.cells[ci] = cell
            cell:ClearAllPoints(); cell:SetPoint("LEFT", x + 3, 0); cell:SetSize(col.width - 6, Theme.Table.previewRowHeight)
            local value = "—"
            if col.id == "name" then value = CharacterLabel(character, context)
            elseif col.id == "slot" then value = slotData and (slot == "secondary" and "副天赋" or "主天赋") or (mode == "backup" and "无备用快照" or "无构筑快照")
            elseif col.id == "spec" then
                local item = slotData and slotData.specialization
                value = item and IconText(item.icon, item.name) or "—"
                SetPreviewCellTooltip(cell, nil)
            elseif string.find(col.id, "talent") then
                local n = tonumber(string.match(col.id, "%d+")); local item = slotData and slotData.talents and slotData.talents[n]
                value = item and IconText(item.icon, item.name) or "—"; SetPreviewCellTooltip(cell, item)
            elseif string.find(col.id, "major") then
                local n = tonumber(string.match(col.id, "%d+")); local item = slotData and slotData.glyphs and slotData.glyphs.major[n]
                value = item and IconText(item.icon, item.name) or "—"; SetPreviewCellTooltip(cell, item)
            elseif string.find(col.id, "minor") then
                local n = tonumber(string.match(col.id, "%d+")); local item = slotData and slotData.glyphs and slotData.glyphs.minor[n]
                value = item and IconText(item.icon, item.name) or "—"; SetPreviewCellTooltip(cell, item)
            elseif col.id == "equipment" then
                value = slotData and slotData.confirmedEquipment and "已确认" or slotData and slotData.observedEquipment and "待确认" or "—"
                SetPreviewEquipmentTooltip(cell, slotData and (slotData.confirmedEquipment or slotData.observedEquipment), slotData and slotData.confirmedEquipment ~= nil)
            end
            if col.id ~= "equipment" and col.id ~= "spec" and not string.find(col.id, "talent") and not string.find(col.id, "major") and not string.find(col.id, "minor") then SetPreviewCellTooltip(cell, nil) end
            cell.text:SetTextColor(C.text[1], C.text[2], C.text[3])
            if col.id == "name" then
                local color = ClassColor(character)
                cell.text:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
            end
            cell.text:SetText(value); cell:Show(); x = x + col.width
            -- Cells are mouse-enabled so native game tooltips can open.  Give
            -- them the row's navigation action explicitly; button clicks do
            -- not bubble to the parent row in WoW's frame system.
            cell:SetScript("OnClick", function()
                parent.buildsSelectedID = character.id
                parent.buildsSlot = nil
                Core.AccountView:Toggle(Addon.PAGE_ID)
            end)
        end
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function()
            parent.buildsSelectedID = character.id
            parent.buildsSlot = nil
            Core.AccountView:Toggle(Addon.PAGE_ID)
        end)
        row:Show()
    end
    for i = #characters + 1, #parent.buildsPreviewRows do parent.buildsPreviewRows[i]:Hide() end
    parent.buildsPreviewBody:ClearAllPoints(); parent.buildsPreviewBody:SetPoint("TOPLEFT", parent.buildsPreviewHeader, "BOTTOMLEFT", 0, 0); parent.buildsPreviewBody:SetSize(width, math.max(1, #characters * Theme.Table.previewRowHeight)); parent.buildsPreviewBody:Show(); parent.buildsPreviewHeader:Show()
end

local EXPANDED_CONTENT_WIDTH = 1120

local function FoldedContentWidth()
    local inset = Theme:GetMatrixInsets(false)
    local rosterWidth = 210
    local expandedMainWidth = EXPANDED_CONTENT_WIDTH - inset.left - inset.right - rosterWidth - Theme.Space.sm
    local equipmentWidth = math.floor((expandedMainWidth - Theme.Space.sm * 3) * 0.55)
    -- The folded main panel is exactly the equipment pane plus its two outer
    -- gutters.  This makes folding remove only the build column.
    return inset.left + rosterWidth + Theme.Space.sm + equipmentWidth + Theme.Space.sm * 2 + inset.right
end

function Page.GetSurfaceMetrics(context)
    local inset = Theme:GetMatrixInsets(context and context.preview)
    if context and context.preview then
        local characters = PreviewCharacters(context)
        local columns = PreviewColumns(context, characters)
        local width = inset.left + inset.right
        for _, column in ipairs(columns) do width = width + column.width end
        local height = inset.top + Theme.Size.compact + Theme.Space.xs + Theme.Table.headerHeight + math.max(1, #characters) * Theme.Table.previewRowHeight + inset.bottom
        return { minContentWidth = width, naturalContentWidth = width, minContentHeight = height, naturalContentHeight = height, horizontalOverflow = "content", verticalOverflow = "none" }
    end
    -- Folding removes the build pane but preserves the expanded equipment-pane
    -- width, including the roster and surrounding gutters.
    local collapsed = Addon.buildsBuildCollapsed == true
    local contentWidth = collapsed and FoldedContentWidth() or EXPANDED_CONTENT_WIDTH
    return { minContentWidth = contentWidth, naturalContentWidth = contentWidth, minContentHeight = 520, naturalContentHeight = 680, horizontalOverflow = "none", verticalOverflow = "content" }
end

function Page.GetHoverMetrics(context)
    local metrics = Page.GetSurfaceMetrics(context)
    -- Hover callbacks report whole-frame dimensions.  Add Core's preview
    -- title-bar and border so a content-sized matrix cannot be clipped.
    local shell = Theme.Geometry.shellBorder * 2
    local title = Theme.Geometry.titleBar + shell
    return { minWidth = metrics.minContentWidth + shell, preferredWidth = metrics.naturalContentWidth + shell, minHeight = metrics.minContentHeight + title, preferredHeight = metrics.naturalContentHeight + title, horizontalOverflow = "content", verticalOverflow = "none" }
end
