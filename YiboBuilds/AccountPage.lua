local Addon = _G.YiboBuilds
if not Addon:HasCompatibleCore() then return end
local Page = {}
Addon.AccountPage = Page

local Core = _G.YiboCore
local Theme = Core.UITheme
local C = Theme.Colors
local ClearPendingGem
local ICON_SIZE = 42
local AUGMENT_ICON_SIZE = 20
local AUGMENT_ICON_GAP = 2
local AUGMENT_EDGE_SIZE = 1
-- Item icon art has a built-in bevel that varies slightly between assets.
-- Crop the same thin rim from every gem so the socket border is the only
-- visible frame and left/right rails have consistent visual weight.
local GEM_ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }
local ROSTER_ROW_HEIGHT = 56
local CATALOG_ROW_HEIGHT = 56
local EXPANDED_CONTENT_WIDTH = 1120
local SOCKET_BORDER_COLORS = {
    red = { 0.92, 0.18, 0.18 }, yellow = { 0.96, 0.76, 0.12 }, blue = { 0.16, 0.48, 0.96 },
    prismatic = { 0.91, 0.96, 1.00 }, meta = { 0.78, 0.48, 1.00 }, sha = { 0.88, 0.20, 0.72 },
    unknown = { 0.72, 0.72, 0.72 },
}
local SOCKET_LABELS = { meta = Addon:T("UI.META"), red = Addon:T("UI.RED"), yellow = Addon:T("UI.YELLOW"), blue = Addon:T("UI.BLUE"), prismatic = Addon:T("UI.PRISMATIC"), sha = Addon:T("UI.SHA_TOUCHED"), unknown = Addon:T("UI.GEM") }
local function PixelRound(value, frame)
    local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
        or (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    return math.floor(value * scale + 0.5) / scale
end
local function CreatePixelBorder(frame)
    local border = {}
    for _, edge in ipairs({ "top", "right", "bottom", "left" }) do
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetDrawLayer("OVERLAY", 2)
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        if edge == "top" then
            texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            texture:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            texture:SetHeight(PixelRound(AUGMENT_EDGE_SIZE, frame))
        elseif edge == "right" then
            texture:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            texture:SetWidth(PixelRound(AUGMENT_EDGE_SIZE, frame))
        elseif edge == "bottom" then
            texture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            texture:SetHeight(PixelRound(AUGMENT_EDGE_SIZE, frame))
        else
            texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            texture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            texture:SetWidth(PixelRound(AUGMENT_EDGE_SIZE, frame))
        end
        border[edge] = texture
    end
    return border
end
local function SetPixelBorderColor(border, color)
    for _, texture in pairs(border) do texture:SetVertexColor(color[1], color[2], color[3], 1) end
end
local function RefreshPixelBorder(border, frame)
    local edgeSize = PixelRound(AUGMENT_EDGE_SIZE, frame)
    for edge, texture in pairs(border) do
        if edge == "top" or edge == "bottom" then texture:SetHeight(edgeSize)
        else texture:SetWidth(edgeSize) end
    end
end
local SLOT_LABELS = {
    [INVSLOT_HEAD or 1] = Addon:T("UI.HEAD"), [INVSLOT_NECK or 2] = Addon:T("UI.NECK"), [INVSLOT_SHOULDER or 3] = Addon:T("UI.SHOULDER"),
    [INVSLOT_SHIRT or 4] = Addon:T("UI.SHIRT"), [INVSLOT_CHEST or 5] = Addon:T("UI.CHEST"), [INVSLOT_WAIST or 6] = Addon:T("UI.WAIST"),
    [INVSLOT_LEGS or 7] = Addon:T("UI.LEGS"), [INVSLOT_FEET or 8] = Addon:T("UI.FEET"), [INVSLOT_WRIST or 9] = Addon:T("UI.WRIST"),
    [INVSLOT_HAND or 10] = Addon:T("UI.HANDS"), [INVSLOT_FINGER1 or 11] = Addon:T("UI.RING_1"), [INVSLOT_FINGER2 or 12] = Addon:T("UI.RING_2"),
    [INVSLOT_TRINKET1 or 13] = Addon:T("UI.TRINKET_1"), [INVSLOT_TRINKET2 or 14] = Addon:T("UI.TRINKET_2"), [INVSLOT_BACK or 15] = Addon:T("UI.BACK"),
    [INVSLOT_MAINHAND or 16] = Addon:T("UI.MAIN_HAND"), [INVSLOT_OFFHAND or 17] = Addon:T("UI.OFF_HAND"), [INVSLOT_TABARD or 19] = Addon:T("UI.TABARD"),
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

local function FoldedEquipmentWidth()
    local inset = Theme:GetMatrixInsets(false)
    local rosterWidth = 210
    local expandedMainWidth = EXPANDED_CONTENT_WIDTH - inset.left - inset.right - rosterWidth - Theme.Space.sm
    return math.floor((expandedMainWidth - Theme.Space.sm * 3) * 0.55)
end

local EQUIPMENT_COLUMNS = {
    { id = "equipment_head", slotID = INVSLOT_HEAD or 1, title = Addon:T("UI.HEAD_2") },
    { id = "equipment_shoulder", slotID = INVSLOT_SHOULDER or 3, title = Addon:T("UI.SHOULDER_2") },
    { id = "equipment_chest", slotID = INVSLOT_CHEST or 5, title = Addon:T("UI.CHEST_2") },
    { id = "equipment_hands", slotID = INVSLOT_HAND or 10, title = Addon:T("UI.GLOVES") },
    { id = "equipment_legs", slotID = INVSLOT_LEGS or 7, title = Addon:T("UI.LEGS_2"), gapAfter = 6 },
    { id = "equipment_wrist", slotID = INVSLOT_WRIST or 9, title = Addon:T("UI.WRISTS") },
    { id = "equipment_waist", slotID = INVSLOT_WAIST or 6, title = Addon:T("UI.WAIST_2") },
    { id = "equipment_feet", slotID = INVSLOT_FEET or 8, title = Addon:T("UI.FEET_2"), gapAfter = 6 },
    { id = "equipment_neck", slotID = INVSLOT_NECK or 2, title = Addon:T("UI.NECK_2") },
    { id = "equipment_back", slotID = INVSLOT_BACK or 15, title = Addon:T("UI.CLOAK"), gapAfter = 6 },
    { id = "equipment_finger1", slotID = INVSLOT_FINGER1 or 11, title = Addon:T("UI.RING_1_2") },
    { id = "equipment_finger2", slotID = INVSLOT_FINGER2 or 12, title = Addon:T("UI.RING_2_2") },
    { id = "equipment_trinket1", slotID = INVSLOT_TRINKET1 or 13, title = Addon:T("UI.TRINKET_1_2") },
    { id = "equipment_trinket2", slotID = INVSLOT_TRINKET2 or 14, title = Addon:T("UI.TRINKET_2_2"), gapAfter = 6 },
    { id = "equipment_mainhand", slotID = INVSLOT_MAINHAND or 16, title = Addon:T("UI.MAIN_HAND") },
    { id = "equipment_offhand", slotID = INVSLOT_OFFHAND or 17, title = Addon:T("UI.OFF_HAND"), gapAfter = 6 },
    { id = "equipment_shirt", slotID = INVSLOT_SHIRT or 4, title = Addon:T("UI.SHIRT_2") },
    { id = "equipment_tabard", slotID = INVSLOT_TABARD or 19, title = Addon:T("UI.TABARD_2") },
}

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

local function SnapshotName(entry, kind)
    return Addon.Snapshot:GetDisplayName(entry, kind)
end

local function IconText(icon, name, size)
    return "|T" .. tostring(icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":" .. tostring(size or 16) .. ":" .. tostring(size or 16) .. ":0:0|t " .. tostring(name or "—")
end

local function ClassColor(character)
    local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[character and character.class or ""]
    return color or { r = C.text[1], g = C.text[2], b = C.text[3] }
end

local function CharacterLabel(character, context)
    return Core.Characters:FormatName(character, {
        nameMode = "short", realmMode = context and context.scope == "all" and "full" or "omit",
    }) or Addon:T("UI.UNKNOWN_CHARACTER")
end

local function PreviewCharacterLabel(character, context, slotData)
    local label = CharacterLabel(character, context)
    local confirmed = slotData and slotData.confirmedEquipment
    local observed = slotData and slotData.observedEquipment
    local itemLevel = confirmed and tonumber(confirmed.itemLevel)
    if not itemLevel or itemLevel <= 0 then itemLevel = observed and tonumber(observed.itemLevel) end
    if not itemLevel or itemLevel <= 0 then itemLevel = Addon.Snapshot:GetEquipmentAverageItemLevel(confirmed) end
    if not itemLevel or itemLevel <= 0 then itemLevel = Addon.Snapshot:GetEquipmentAverageItemLevel(observed) end
    if itemLevel and itemLevel > 0 then
        return label .. " [" .. tostring(math.floor(itemLevel + 0.5)) .. "]"
    end
    return label
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
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button.border = CreatePixelBorder(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button.selection = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.selection:SetPoint("TOPLEFT", -2, 2)
    button.selection:SetPoint("BOTTOMRIGHT", 2, -2)
    button.selection:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    button.selection:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    button.selection:EnableMouse(false)
    button.selection:Hide()
    button.socketRail = CreateFrame("Frame", nil, parent)
    button.socketRail:SetFrameLevel(button:GetFrameLevel())
    button.socketRail:Hide()
    button.gems = {}
    for index = 1, 4 do
        local gem = CreateFrame("Button", nil, button.socketRail)
        gem:SetSize(PixelRound(AUGMENT_ICON_SIZE, gem), PixelRound(AUGMENT_ICON_SIZE, gem))
        gem.border = CreatePixelBorder(gem)
        gem.icon = gem:CreateTexture(nil, "ARTWORK")
        gem.icon:SetAllPoints(gem)
        button.gems[index] = gem
    end
    button.enchant = CreateFrame("Button", nil, parent)
    button.enchant:SetSize(PixelRound(AUGMENT_ICON_SIZE, button.enchant), PixelRound(AUGMENT_ICON_SIZE, button.enchant))
    button.enchant.icon = button.enchant:CreateTexture(nil, "ARTWORK")
    button.enchant.icon:SetAllPoints(); button.enchant.icon:SetTexture("Interface\\Icons\\Trade_Engraving")
    button.engineering = CreateFrame("Button", nil, parent)
    button.engineering:SetSize(PixelRound(AUGMENT_ICON_SIZE, button.engineering), PixelRound(AUGMENT_ICON_SIZE, button.engineering))
    button.engineering.icon = button.engineering:CreateTexture(nil, "ARTWORK")
    button.engineering.icon:SetAllPoints(); button.engineering.icon:SetTexture("Interface\\Icons\\Trade_Engineering")
    button.buckle = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.buckle:SetSize(16, 16)
    button.buckle:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.buckle.icon = button.buckle:CreateTexture(nil, "ARTWORK")
    button.buckle.icon:SetAllPoints(); button.buckle.icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_30")
    button.base = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.base:SetSize(16, 16)
    button.base:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.base.icon = button.base:CreateTexture(nil, "ARTWORK")
    button.base.icon:SetAllPoints(); button.base.icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    button:RegisterForClicks("LeftButtonUp")
    return button
end

local equipmentTooltipOwner

local function HideTooltipIfOwned(button)
    local owned = GameTooltip.GetOwner and GameTooltip:GetOwner() == button
    if owned or (not GameTooltip.GetOwner and equipmentTooltipOwner == button) then
        GameTooltip:Hide()
        equipmentTooltipOwner = nil
    end
end

local function FullTooltipHyperlink(link, label)
    if type(link) ~= "string" then return link end
    local enchantID = link:match("^enchant:(%d+)")
    if not enchantID then return link end
    return "|cffffd000|Henchant:" .. enchantID .. "|h[" .. (label or Addon:T("UI.ENCHANTING")) .. "]|h|r"
end

local function SetAugmentTooltip(button, title, link, detail, spellID)
    button:EnableMouse(true)
    button:SetScript("OnEnter", function(self)
        equipmentTooltipOwner = self
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local shown = false
        local function HasTooltipText()
            for lineIndex = 1, GameTooltip:NumLines() do
                local left = _G["GameTooltipTextLeft" .. lineIndex]
                local right = _G["GameTooltipTextRight" .. lineIndex]
                if (left and left:GetText() and left:GetText() ~= "") or (right and right:GetText() and right:GetText() ~= "") then
                    return true
                end
            end
            return false
        end
        if link then
            local fullLink = FullTooltipHyperlink(link, title)
            pcall(GameTooltip.SetHyperlink, GameTooltip, fullLink)
            shown = HasTooltipText()
            -- Some client builds accept the bare payload while others require
            -- a complete chat hyperlink for non-item records such as enchant:.
            if not shown and fullLink ~= link then
                GameTooltip:ClearLines()
                local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
                shown = ok and HasTooltipText()
            end
        end
        if not shown and spellID and GameTooltip.SetSpellByID then
            GameTooltip:ClearLines()
            local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
            shown = ok and HasTooltipText()
        end
        if not shown and spellID and GameTooltip.SetHyperlink then
            GameTooltip:ClearLines()
            local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. tostring(spellID))
            shown = ok and HasTooltipText()
        end
        if not shown then
            GameTooltip:ClearLines()
            GameTooltip:AddLine(title or Addon:T("UI.ENCHANTING"))
            if detail and detail ~= title then
                GameTooltip:AddLine(detail, C.text[1], C.text[2], C.text[3], true)
            end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltipIfOwned)
end

local function EnchantIDFromItem(item)
    if not item then return nil end
    local linkID = item.itemLink and tonumber(item.itemLink:match("item:%d+:(%d+)")) or nil
    local savedID = item.enchant and tonumber(item.enchant.enchantID) or nil
    local enchantID = linkID and linkID > 0 and linkID or savedID
    if not (enchantID and enchantID > 0) then return nil end
    -- Older links can put an engineering tinker in the permanent-enchant field.
    if Addon.EngineeringCatalog and Addon.EngineeringCatalog[enchantID] then return nil end
    if item.engineering and tonumber(item.engineering.enchantID) == enchantID then return nil end
    return enchantID
end

local function SetEnchantTooltip(button, item, enchantID, isEnchanted)
    button:EnableMouse(true)
    button:SetScript("OnEnter", function(self)
        equipmentTooltipOwner = self
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if not isEnchanted then
            GameTooltip:AddLine(Addon:T("UI.NOT_ENCHANTED"), C.warning[1], C.warning[2], C.warning[3])
        else
            local source = enchantID and Addon.EnchantCatalog and Addon.EnchantCatalog[enchantID]
            if source and source.itemID and source.itemID > 0 then
                GameTooltip:SetHyperlink("item:" .. source.itemID)
                GameTooltip:Show()
                return
            end
            if source and source.spellID and source.spellID > 0 and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(source.spellID)
                GameTooltip:Show()
                return
            end
            local liveInfo = enchantID and Addon.Snapshot:GetEnchantInfoFromLink(item and item.itemLink, enchantID)
            local savedInfo = item and item.enchant
            local detail = (liveInfo and liveInfo.detailText) or (savedInfo and savedInfo.tooltipText)
            local name = (liveInfo and liveInfo.name) or (savedInfo and savedInfo.name)
            GameTooltip:AddLine(Addon:T("UI.CURRENT_ENCHANT"), C.accent[1], C.accent[2], C.accent[3])
            GameTooltip:AddLine(detail or name or (enchantID and (Addon:T("UI.ENCHANT_RECORD") .. tostring(enchantID))) or Addon:T("UI.ENCHANT_NOT_RECORDED"), C.text[1], C.text[2], C.text[3], true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltipIfOwned)
end

local function SetEngineeringTooltip(button, title, engineering, item, isInstalled)
    button:EnableMouse(true)
    button:SetScript("OnEnter", function(self)
        equipmentTooltipOwner = self
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local effect = isInstalled and engineering and Addon.EngineeringCatalog and Addon.EngineeringCatalog[engineering.enchantID]
        local spellIDs = effect and effect.spellIDs
        local spellID = spellIDs and spellIDs[#spellIDs]
        if spellID and spellID > 0 and GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(spellID)
            GameTooltip:Show()
            return
        end
        GameTooltip:AddLine(title or Addon:T("UI.ENGINEERING_ENHANCEMENT"), C.accent[1], C.accent[2], C.accent[3])
        local detail = engineering and engineering.tooltipText
        if detail and detail ~= "" and detail ~= engineering.name and detail ~= title then
            GameTooltip:AddLine(detail, C.text[1], C.text[2], C.text[3], true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltipIfOwned)
end

local function SetNativeItemTooltip(button, item)
    button:EnableMouse(true)
    button:SetScript("OnEnter", function(self)
        if not item or not item.itemLink then return end
        equipmentTooltipOwner = self
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(item.itemLink)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltipIfOwned)
end

local function SetSpellTooltip(button, entry)
    button:SetScript("OnEnter", function(self)
        if not entry or not entry.glyphLink and (not entry.spellID or entry.spellID == 0) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if entry.glyphLink then GameTooltip:SetHyperlink(entry.glyphLink)
        elseif GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(entry.spellID)
        else GameTooltip:AddLine(SnapshotName(entry)) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function GlyphRequirementText(entry)
    local requirement = entry and entry.specRequirement
    return requirement and requirement ~= "通用" and requirement ~= "General" and requirement or nil
end

function Page:GetFields()
    local fields = {
        { id = "spec", title = Addon:T("UI.SPECIALIZATION"), defaultVisible = true },
    }
    for index = 1, 6 do fields[#fields + 1] = { id = "talent" .. index, title = Addon:T("FIELD.TALENT", index), defaultVisible = true } end
    for index = 1, 3 do fields[#fields + 1] = { id = "major" .. index, title = Addon:T("FIELD.MAJOR", index), defaultVisible = true } end
    for index = 1, 3 do fields[#fields + 1] = { id = "minor" .. index, title = Addon:T("FIELD.MINOR", index), defaultVisible = true } end
    fields[#fields + 1] = { id = "equipment", title = Addon:T("UI.EQUIPMENT"), defaultVisible = true }
    return fields
end

function Page:GetPreviewFieldDefinitions()
    local fields = {}
    for _, column in ipairs(EQUIPMENT_COLUMNS) do
        fields[#fields + 1] = { id = column.id, title = Addon:T("UI.EQUIPMENT_2") .. column.title, defaultVisible = column.id ~= "equipment_shirt" and column.id ~= "equipment_tabard" }
    end
    return fields
end

-- The hover projection has its own compact geometry, but it must be built
-- from the same field preferences as the account page.  Keeping this in one
-- helper prevents the rendered matrix and its measured window from drifting.
local function PreviewColumns(context, characters, matrixMode, mode)
    local nameWidth = Theme:GetCharacterRowHeaderWidth(false, context, characters)
    -- Core's shared row-header measure does not include the item level, and
    -- caps names and realms separately. Measure the complete preview label.
    for _, character in ipairs(characters or {}) do
        local record = Addon.Snapshot:GetCharacter(character.id)
        local slotData = Addon.Snapshot:GetProjectedSlot(record, mode)
        nameWidth = math.max(nameWidth, Theme:MeasureText(Theme.Font.assist, PreviewCharacterLabel(character, context, slotData)) + Theme.Table.cellPadding)
    end
    local columns = { { id = "name", title = Addon:T("UI.CHARACTER"), width = nameWidth } }
    local settings = Addon:GetSettings().previewColumns
    if matrixMode == "equipment" then
        local visibleEquipment = {}
        for _, equipmentColumn in ipairs(EQUIPMENT_COLUMNS) do
            if settings[equipmentColumn.id] ~= false then
                visibleEquipment[#visibleEquipment + 1] = equipmentColumn
            end
        end
        local equipmentWidth, groupGap = 40, 6
        local availableWidth = tonumber(context and context.surfaceAvailableWidth)
        if availableWidth and #visibleEquipment > 0 then
            local inset = Theme:GetMatrixInsets(true)
            local availableColumns = math.max(0, availableWidth - inset.left - inset.right - nameWidth)
            local gapCount = 0
            for _, equipmentColumn in ipairs(visibleEquipment) do
                if equipmentColumn.gapAfter then gapCount = gapCount + 1 end
            end
            local calculated = math.floor((availableColumns - gapCount * groupGap) / #visibleEquipment)
            equipmentWidth = math.max(36, math.min(40, calculated))
            if equipmentWidth == 36 then groupGap = 4 end
            if availableColumns < (#visibleEquipment * equipmentWidth + gapCount * groupGap) then
                nameWidth = math.max(112, availableWidth - inset.left - inset.right - #visibleEquipment * equipmentWidth - gapCount * groupGap)
            end
        end
        for _, equipmentColumn in ipairs(visibleEquipment) do
            columns[#columns + 1] = { id = equipmentColumn.id, slotID = equipmentColumn.slotID, title = equipmentColumn.title, width = equipmentWidth, gapAfter = equipmentColumn.gapAfter and groupGap or nil }
        end
        columns[1].width = nameWidth
        return columns
    end
    local function Add(id, title)
        if settings[id] ~= false then
            local isBuildChoice = string.find(id, "talent", 1, true) or string.find(id, "major", 1, true) or string.find(id, "minor", 1, true)
            local targetCharacters = isBuildChoice and 5 or Theme.Table.matrixTargetLabelCharacters
            columns[#columns + 1] = { id = id, title = title, width = Theme:GetIconTextColumnWidth(16, Theme.Font.assist, title, targetCharacters) }
        end
    end
    Add("spec", Addon:T("UI.SPECIALIZATION"))
    for i = 1, 6 do Add("talent" .. i, Addon:T("UI.TALENT") .. i) end
    for i = 1, 3 do Add("major" .. i, Addon:T("UI.MAJOR") .. i) end
    for i = 1, 3 do Add("minor" .. i, Addon:T("UI.MINOR") .. i) end
    Add("equipment", Addon:T("UI.EQUIPMENT"))
    return columns
end

local function PreviewCharacters(context)
    local eligible = Eligible(context)
    -- A hover is a scan-friendly account projection, not a second scroll
    -- window.  The product contract caps it at twenty data-bearing roles.
    while #eligible > 20 do table.remove(eligible) end
    return eligible
end

local function PreviewRowHeight(matrixMode)
    return matrixMode == "equipment" and (Theme.Table.previewRowHeight + 16) or Theme.Table.previewRowHeight
end

local function CreatePreviewCell(parent)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetFrameLevel((parent:GetFrameLevel() or 0) + 2)
    cell:RegisterForClicks("LeftButtonUp")
    cell.text = Text(cell, Theme.Font.assist, C.text, "LEFT")
    cell.text:SetAllPoints()
    cell.itemFrame = CreateFrame("Frame", nil, cell, "BackdropTemplate")
    cell.itemFrame:SetSize(32, 32)
    cell.itemFrame:SetPoint("CENTER", 0, 0)
    cell.itemFrame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    cell.itemFrame:SetBackdropColor(0, 0, 0, 0)
    cell.itemFrame:SetBackdropBorderColor(0, 0, 0, 0)
    cell.itemFrame:EnableMouse(false)
    cell.itemIcon = cell.itemFrame:CreateTexture(nil, "ARTWORK")
    cell.itemIcon:SetPoint("TOPLEFT", 2, -2); cell.itemIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    cell.itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    cell.itemLevel = Text(cell.itemFrame, Theme.Font.body, C.text, "CENTER")
    cell.itemLevel:SetPoint("BOTTOM", cell.itemFrame, "BOTTOM", 0, 1)
    cell.itemLevel:SetWidth(32)
    cell.itemLevel:SetHeight(15)
    cell.itemLevel:SetJustifyV("BOTTOM")
    cell.itemLevel:SetShadowOffset(1, -1)
    cell.itemLevel:SetDrawLayer("OVERLAY", 7)
    cell.itemChanged = Text(cell.itemFrame, Theme.Font.body, C.warning, "RIGHT")
    cell.itemChanged:SetPoint("TOPRIGHT", cell.itemFrame, "TOPRIGHT", -2, -1)
    cell.itemChanged:SetWidth(14)
    cell.itemChanged:SetHeight(16)
    cell.itemChanged:SetText("!")
    cell.itemChanged:SetShadowOffset(1, -1)
    cell.itemChanged:SetDrawLayer("OVERLAY", 7)
    cell.itemChanged:Hide()
    cell.itemLevel:Hide()
    cell.itemFrame:Hide()
    return cell
end

local function GetPreviewItemLevel(item)
    return Addon.Snapshot:GetItemLevel(item)
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
        GameTooltip:AddLine(confirmed and Addon:T("UI.CONFIRMED_EQUIPMENT_SNAPSHOT") or Addon:T("UI.EQUIPMENT_OBSERVATION_AWAITING_CONFIRMATION"), confirmed and C.success[1] or C.warning[1], confirmed and C.success[2] or C.warning[2], confirmed and C.success[3] or C.warning[3])
        if equipment.capturedAt then GameTooltip:AddLine(date("%Y-%m-%d %H:%M", equipment.capturedAt), C.muted[1], C.muted[2], C.muted[3]) end
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function SetPreviewItemTooltip(cell, item)
    cell:SetScript("OnEnter", nil)
    cell:SetScript("OnLeave", nil)
    if item and item.itemLink then
        cell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item.itemLink)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
end

function Page.Create(parent)
    parent:HookScript("OnHide", function() parent.buildsGlyphProbeID = nil end)
    parent.buildsRoster = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    parent.buildsRoster:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.buildsRoster:SetBackdropColor(C.nav[1], C.nav[2], C.nav[3], 0.95); parent.buildsRoster:SetBackdropBorderColor(C.lineSoft[1], C.lineSoft[2], C.lineSoft[3], C.lineSoft[4])
    parent.buildsRoster.title = Text(parent.buildsRoster, Theme.Font.section, C.text)
    parent.buildsRoster.title:SetPoint("TOPLEFT", Theme.Space.sm, -Theme.Space.sm); parent.buildsRoster.title:SetText(Addon:T("UI.CHARACTERS"))
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
    parent.buildsToolbar.primary = Theme:CreateButton(parent.buildsToolbar, 94, Addon:T("UI.PRIMARY_TALENTS"), "secondary")
    parent.buildsToolbar.secondary = Theme:CreateButton(parent.buildsToolbar, 94, Addon:T("UI.SECONDARY_TALENTS"), "secondary")
    parent.buildsToolbar.status = Text(parent.buildsToolbar, Theme.Font.assist, C.accent)
    parent.buildsToolbar.buildToggle = Theme:CreateButton(parent.buildsToolbar, 96, Addon:T("UI.COLLAPSE_BUILD"), "secondary")
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
    parent.buildsEquipment.modelHint:Hide()
    parent.buildsEquipment.empty = Text(parent.buildsEquipment, Theme.Font.assist, C.muted, "CENTER")
    parent.buildsEquipment.empty:SetAllPoints(); parent.buildsEquipment.empty:SetText(Addon:T("UI.SELECT_A_CHARACTER_TO_VIEW_EQUIPMENT"))
    parent.buildsEquipment.items = {}
    parent.buildsToolbar.appearance = Theme:CreateButton(parent.buildsEquipment, 120, Addon:T("UI.ORIGINAL_TRANSMOG"), "secondary")
    parent.buildsToolbar.appearance:SetFrameLevel(parent.buildsEquipment.model:GetFrameLevel() + 2)

    parent.buildsBuild = CreateFrame("Frame", nil, parent.buildsMain, "BackdropTemplate")
    parent.buildsBuild:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    parent.buildsBuild:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.9)
    parent.buildsEquipment.detail = CreateFrame("Frame", nil, parent.buildsBuild, "BackdropTemplate")
    local detail = parent.buildsEquipment.detail
    detail:SetPoint("TOPLEFT", parent.buildsBuild, "TOPLEFT", 8, -8)
    detail:SetPoint("BOTTOMRIGHT", parent.buildsBuild, "BOTTOMRIGHT", -8, 8)
    detail:SetFrameLevel(parent.buildsBuild:GetFrameLevel() + 3)
    detail:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    detail:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 1)
    detail:SetBackdropBorderColor(C.lineSoft[1], C.lineSoft[2], C.lineSoft[3], 1)
    detail.itemIcon = detail:CreateTexture(nil, "ARTWORK")
    detail.itemIcon:SetSize(26, 26)
    detail.itemIcon:SetPoint("TOPLEFT", 8, -8)
    detail.title = Text(detail, Theme.Font.assist, C.accent)
    detail.title:SetPoint("TOPLEFT", 40, -9)
    detail.title:SetPoint("TOPRIGHT", -34, -9)
    detail.title:SetHeight(26)
    detail.title:SetWordWrap(true)
    detail.close = Theme:CreateButton(detail, 24, "×", "secondary")
    detail.close:SetSize(24, 24)
    detail.close:SetPoint("TOPRIGHT", -6, -6)
    detail.scroll = Theme:CreateScrollFrame(detail)
    detail.scroll:SetPoint("TOPLEFT", 8, -44)
    detail.scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    detail.apply = Theme:CreateButton(detail, 116, Addon:T("UI.APPLY_GEM"))
    detail.apply:SetSize(116, 30)
    detail.apply:SetState("selected")
    detail.apply:SetPoint("BOTTOMRIGHT", -8, 8)
    detail.cancel = Theme:CreateButton(detail, 76, Addon:T("UI.CANCEL"), "secondary")
    detail.cancel:SetSize(76, 30)
    detail.cancel:SetPoint("RIGHT", detail.apply, "LEFT", -6, 0)
    detail.pending = Text(detail, Theme.Font.meta, C.accent)
    detail.pending:SetPoint("BOTTOMLEFT", 10, 16)
    detail.pending:SetPoint("RIGHT", detail.cancel, "LEFT", -6, 0)
    detail.pending:SetJustifyH("LEFT")
    detail.apply:Hide(); detail.cancel:Hide(); detail.pending:Hide()
    detail.body = CreateFrame("Frame", nil, detail.scroll)
    detail.body:SetWidth(1)
    detail.body:SetHeight(1)
    detail.scroll:SetScrollChild(detail.body)
    detail.rows = {}
    detail:SetScript("OnHide", function()
        if parent.buildsPendingGem and ClearPendingGem then ClearPendingGem(parent, true) end
    end)
    detail:Hide()
    parent.buildsBuild.talentTitle = Text(parent.buildsBuild, Theme.Font.section, C.text); parent.buildsBuild.talentTitle:SetText(Addon:T("UI.TALENT"))
    parent.buildsBuild.glyphTitle = Text(parent.buildsBuild, Theme.Font.section, C.text); parent.buildsBuild.glyphTitle:SetText(Addon:T("UI.GLYPHS"))
    parent.buildsBuild.majorGlyphTitle = Text(parent.buildsBuild, Theme.Font.assist, C.muted); parent.buildsBuild.majorGlyphTitle:SetText(Addon:T("UI.MAJOR_GLYPHS"))
    parent.buildsBuild.minorGlyphTitle = Text(parent.buildsBuild, Theme.Font.assist, C.muted); parent.buildsBuild.minorGlyphTitle:SetText(Addon:T("UI.MINOR_GLYPHS"))
    parent.buildsBuild.currentGlyphs = Theme:CreateButton(parent.buildsBuild, 52, Addon:T("UI.CURRENT"), "secondary")
    parent.buildsBuild.allGlyphs = Theme:CreateButton(parent.buildsBuild, 52, Addon:T("UI.ALL"), "secondary")
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
    parent.buildsBuild.catalogMajor = Theme:CreateButton(parent.buildsBuild, 1, Addon:T("UI.MAJOR_GLYPHS"), "secondary")
    parent.buildsBuild.catalogMinor = Theme:CreateButton(parent.buildsBuild, 1, Addon:T("UI.MINOR_GLYPHS"), "secondary")
    for _, control in ipairs({ parent.buildsBuild.catalogMajor, parent.buildsBuild.catalogMinor }) do
        control.typeIcon = control:CreateTexture(nil, "ARTWORK")
        control.typeIcon:SetSize(16, 16); control.typeIcon:SetPoint("LEFT", 10, 0)
    end
    parent.buildsBuild.catalogMajor.typeIcon:SetTexture("Interface\\Icons\\INV_Glyph_Major")
    parent.buildsBuild.catalogMinor.typeIcon:SetTexture("Interface\\Icons\\INV_Glyph_Minor")
    parent.buildsBuild.catalog:Hide()
    parent.buildsBuild.catalogMajor:Hide(); parent.buildsBuild.catalogMinor:Hide()

    parent.buildsConfirm = Theme:CreateButton(parent.buildsMain, 160, Addon:T("UI.CONFIRM_BUILD_EQUIPMENT"), "default")
    parent.buildsEmpty = Text(parent, Theme.Font.body, C.muted, "CENTER")
    parent.buildsEmpty:SetAllPoints(); parent.buildsEmpty:SetText(Addon:T("UI.NO_BUILD_SNAPSHOTS_LOG_IN_TO_A_CHARACTER_AND_ALLOW_TIME_TO_SYNC"))
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
    button.engineering:SetFrameLevel(button:GetFrameLevel() + 1)
    button.buckle:SetFrameLevel(button:GetFrameLevel() + 1)
    button.base:SetFrameLevel(button:GetFrameLevel() + 1)
    button.slotLabel = Text(button, Theme.Font.meta, C.muted, "RIGHT")
    button.slotLabel:SetWidth(30)
    button.itemLevel = Text(button, Theme.Font.section, { 0.78, 0.62, 1 }, "RIGHT")
    button.itemLevel:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 2)
    button.itemLevel:SetWidth(ICON_SIZE - 6)
    button.itemLevel:SetHeight(18)
    button.itemLevel:SetFont(STANDARD_TEXT_FONT, Theme.Font.section, "OUTLINE")
    button.itemLevel:SetDrawLayer("OVERLAY", 7)
    button.itemLevel:Hide()
    parent.buildsEquipment.items[slotID] = button
    return button
end

local INVENTORY_TYPE_IDS = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4,
    INVTYPE_CHEST = 5, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12,
    INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16,
    INVTYPE_2HWEAPON = 17, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20,
    INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23,
    INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26,
}
local CANDIDATE_SLOTS = {
    [3] = true, [5] = true, [6] = true, [7] = true, [8] = true,
    [9] = true, [10] = true, [11] = true, [12] = true,
    [15] = true, [16] = true, [17] = true,
}
local SOCKET_APPLICATIONS = {
    { spellID = 55655, itemID = 41611, slotID = 6, name = Addon:T("UI.BELT_BUCKLE") },
    { spellID = 76168, itemID = 55054, slotID = 6, name = Addon:T("UI.BELT_BUCKLE") },
    { spellID = 131467, itemID = 90046, slotID = 6, name = Addon:T("UI.BELT_BUCKLE") },
    { spellID = 55628, slotID = 9, professionID = 164, requiredSkill = 400, name = Addon:T("UI.BLACKSMITH_WRIST_SOCKET") },
    { spellID = 113263, slotID = 9, professionID = 164, requiredSkill = 400, name = Addon:T("UI.BLACKSMITH_WRIST_SOCKET") },
    { spellID = 55641, slotID = 10, professionID = 164, requiredSkill = 400, name = Addon:T("UI.BLACKSMITH_GLOVE_SOCKET") },
    { spellID = 114112, slotID = 10, professionID = 164, requiredSkill = 400, name = Addon:T("UI.BLACKSMITH_GLOVE_SOCKET") },
}

local function MaskHas(mask, index)
    return mask == 0 or math.floor(mask / (2 ^ index)) % 2 == 1
end

local function CurrentProfessionSkill(professionID)
    if not (GetProfessions and GetProfessionInfo) then return nil end
    for _, professionIndex in ipairs({ GetProfessions() }) do
        if professionIndex then
            local _, _, skill, _, _, _, skillLine = GetProfessionInfo(professionIndex)
            if skillLine == professionID then return tonumber(skill) or 0 end
        end
    end
    return nil
end

local knownRecipeCache = {}
function Page:InvalidateRecipeCache() knownRecipeCache = {} end
local function RecipeLearned(spellID)
    if knownRecipeCache[spellID] ~= nil then return knownRecipeCache[spellID] end
    if IsSpellKnown and IsSpellKnown(spellID) then return true end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, recipe = pcall(C_TradeSkillUI.GetRecipeInfo, spellID)
        if ok and recipe and recipe.learned then knownRecipeCache[spellID] = true; return true end
    end
    knownRecipeCache[spellID] = false
    return false
end

local function LearnedCraftRecipe(craft)
    for _, spellID in ipairs(craft.recipes or {}) do
        local skill = craft.skills and craft.skills[spellID]
        local currentSkill = skill and CurrentProfessionSkill(skill[1])
        if skill and currentSkill and currentSkill >= skill[2]
            and RecipeLearned(spellID) then return spellID end
    end
    return nil
end

local function CraftGemCandidates(socketType)
    local candidates = {}
    for itemID, craft in pairs(Addon.CraftSources or {}) do
        local subclassID = craft.gemSubclass
        if Addon.Gems:MatchesSocket(itemID, subclassID, socketType) then
            local recipeID = LearnedCraftRecipe(craft)
            if recipeID then
                local name = GetItemInfo and GetItemInfo(itemID)
                if not name and GetSpellInfo then name = GetSpellInfo(recipeID) end
                candidates[#candidates + 1] = {
                    itemID = itemID, recipeID = recipeID, name = name or (Addon:T("UI.GEM_2") .. itemID),
                }
            end
        end
    end
    table.sort(candidates, function(a, b) return a.name < b.name end)
    return candidates
end

local function TargetMatches(item, source, target)
    if not (item and item.itemLink and source and target and GetItemInfo) then return false end
    local _, _, _, _, _, _, _, _, inventoryType, _, _, classID, subclassID = GetItemInfo(item.itemLink)
    if classID ~= target.classID or type(subclassID) ~= "number" then return false end
    local inventoryID = INVENTORY_TYPE_IDS[inventoryType]
    if not ((target.inventoryMask == 0 or inventoryID and MaskHas(target.inventoryMask, inventoryID))
        and MaskHas(target.subclassMask, subclassID)) then return false end
    -- SpellItemEnchantment level metadata is not an equipment item-level
    -- target mask. The client validates final item-use requirements.
    return true
end

function Page:IsGoalTargetApplicable(item, conditions)
    if conditions.kind == "enchant" then
        local source = Addon.EnchantCatalog[conditions.enhancementID]
        return TargetMatches(item, source, source and Addon.ApplyTargets[source.spellID])
    end
    local socket = item.gems and item.gems[conditions.socketIndex]
    if not socket or not GetItemInfo then return false end
    local classID, subclassID = select(12, GetItemInfo(conditions.enhancementID))
    return classID == 3 and Addon.Gems:MatchesSocket(conditions.enhancementID, subclassID, socket.socketType) or false
end

local function BagApplyingItems()
    local items = {}
    local getCount = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    local getInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
    if not (getCount and getLink and getInfo) then return items end
    for bag = 0, 4 do
        for bagSlot = 1, (getCount(bag) or 0) do
            local link = getLink(bag, bagSlot)
            local itemID = link and tonumber(link:match("item:(%d+)"))
            if itemID then
                local info, count = getInfo(bag, bagSlot)
                count = type(info) == "table" and info.stackCount or select(2, getInfo(bag, bagSlot))
                local entry = items[itemID] or { count = 0, link = link, bag = bag, bagSlot = bagSlot }
                entry.count = entry.count + (tonumber(count) or 1)
                items[itemID] = entry
            end
        end
    end
    return items
end

-- SpellEffect can associate one scroll with several scaled enchant records.
-- Resolve the physical/craftable item by its actual use spell, keeping the
-- other records available for recognizing already-installed equipment effects.
local function ScrollMatchesSource(source, scrollSources, useSpells)
    local itemID = source.itemID
    if not itemID then return false end
    local spellID = useSpells[itemID]
    if spellID == nil then
        local getSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
        if getSpell then
            local ok, _, value = pcall(getSpell, itemID)
            spellID = ok and tonumber(value) or nil
        end
        useSpells[itemID] = spellID or false
    end
    if spellID then return spellID == source.spellID end
    -- Old clients/cache misses can still use a single unambiguous mapping.
    -- Multiple records require evidence; their numeric values are not a ranking.
    return scrollSources[itemID] == 1
end

local function AugmentCandidates(slotID, item)
    local candidates = {}
    if not CANDIDATE_SLOTS[slotID] then return candidates end
    local bagItems = BagApplyingItems()
    local scrollSources, useSpells = {}, {}
    for _, source in pairs(Addon.EnchantCatalog or {}) do
        if source.itemID then scrollSources[source.itemID] = (scrollSources[source.itemID] or 0) + 1 end
    end
    local itemClassID, itemSubclassID
    if item and item.itemLink and GetItemInfo then itemClassID, itemSubclassID = select(12, GetItemInfo(item.itemLink)) end
    local isMoPRangedWeapon = slotID == (INVSLOT_MAINHAND or 16) and itemClassID == 2
        and (itemSubclassID == 2 or itemSubclassID == 3 or itemSubclassID == 18)
    for enchantID, source in pairs(Addon.EnchantCatalog or {}) do
        local target = source.spellID and Addon.ApplyTargets and Addon.ApplyTargets[source.spellID]
        if not isMoPRangedWeapon and TargetMatches(item, source, target) then
            local profession = Addon.ProfessionCatalog and Addon.ProfessionCatalog[enchantID]
            local skill = profession and CurrentProfessionSkill(profession.professionID)
            local learned = source.spellID and RecipeLearned(source.spellID)
                and (not profession or (skill and skill >= (profession.requiredSkill or 0)))
            local bag = source.itemID and bagItems[source.itemID]
            local craft = source.itemID and Addon.CraftSources and Addon.CraftSources[source.itemID]
            local craftRecipe = craft and LearnedCraftRecipe(craft)
            if (bag or craftRecipe) and not ScrollMatchesSource(source, scrollSources, useSpells) then
                bag, craftRecipe = nil, nil
            end
            if slotID == 11 or slotID == 12 then bag, craftRecipe = nil, nil end
            if slotID == 6 then learned = false end
            if learned or bag or craftRecipe then
                candidates[#candidates + 1] = {
                    enchantID = enchantID, name = source.displayName or source.name or (Addon:T("UI.ENHANCEMENT") .. enchantID),
                    spellID = source.spellID, learned = learned, bag = bag, source = source,
                    craftRecipe = craftRecipe,
                }
            end
        end
    end
    for _, source in ipairs(SOCKET_APPLICATIONS) do
        local missing = source.slotID == 6 and item.beltBuckle and item.beltBuckle.state == "base-missing"
            or source.slotID ~= 6 and item.blacksmithSockets and item.blacksmithSockets.state == "base-missing"
        local target = Addon.ApplyTargets and Addon.ApplyTargets[source.spellID]
        if source.slotID == slotID and missing and TargetMatches(item, source, target) then
            local bag = source.itemID and bagItems[source.itemID]
            local craft = source.itemID and Addon.CraftSources and Addon.CraftSources[source.itemID]
            local craftRecipe = craft and LearnedCraftRecipe(craft)
            local skill = source.professionID and CurrentProfessionSkill(source.professionID)
            local learned = not source.itemID and skill and skill >= source.requiredSkill
                and RecipeLearned(source.spellID)
            if bag or learned or craftRecipe then
                candidates[#candidates + 1] = {
                    name = source.name, spellID = source.spellID, learned = learned,
                    bag = bag, source = source, socketApplication = true,
                    craftRecipe = craftRecipe,
                }
            end
        end
    end
    local engineeringSkill = CurrentProfessionSkill(202)
    do
        for enchantID, effect in pairs(Addon.EngineeringCatalog or {}) do
            local effectSlot = effect.slotID == 18 and 16 or effect.slotID
            local profession = Addon.ProfessionCatalog and Addon.ProfessionCatalog[enchantID]
            if effectSlot == slotID and effect.slotID ~= 1 then
                local bag = effect.itemID and bagItems[effect.itemID]
                for _, application in ipairs((Addon.EngineeringApply or {})[enchantID] or {}) do
                    local source = {
                        spellID = application.spellID, professionID = 202,
                        requiredSkill = profession and profession.requiredSkill or 0,
                        target = application, itemID = effect.itemID,
                    }
                    local learned = not effect.itemID and engineeringSkill
                        and engineeringSkill >= (profession and profession.requiredSkill or 0)
                        and RecipeLearned(source.spellID)
                    if (bag or learned) and TargetMatches(item, source, application) then
                        candidates[#candidates + 1] = {
                            enchantID = enchantID, name = effect.name or (Addon:T("UI.ENGINEERING_ENHANCEMENT_2") .. enchantID),
                            spellID = source.spellID, learned = learned, bag = bag, source = source,
                            engineering = true,
                        }
                    end
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.name < b.name end)
    return candidates
end

ClearPendingGem = function(parent, closeSocket)
    if not parent then return end
    parent.buildsPendingGem = nil
    if closeSocket then
        local close = C_ItemSocketInfo and C_ItemSocketInfo.CloseSocketInfo or CloseSocketInfo
        if close then close() end
    end
    if ItemSocketingFrame then
        ItemSocketingFrame:SetAlpha(1)
        ItemSocketingFrame:EnableMouse(true)
    end
end

local function StageNativeGem(parent, slotID, socketIndex, candidate)
    local selected = parent.buildsSelectedCharacter
    local record = selected and Addon.Snapshot:GetCharacter(selected.id)
    local activeSlot = record and record.lastActiveSlot
    local item = activeSlot and record.slots and record.slots[activeSlot]
        and record.slots[activeSlot].observedEquipment
        and record.slots[activeSlot].observedEquipment.slots[tostring(slotID)]
    if not (IsCurrent(selected) and activeSlot == parent.buildsSlot and item
        and item.itemLink == GetInventoryItemLink("player", slotID)
        and item.gems and item.gems[socketIndex]) then
        Addon:Print(Addon:T("UI.EQUIPMENT_CHANGED_SELECT_THE_CURRENTLY_EQUIPPED_ITEM_AGAIN"))
        Addon.Snapshot:ScheduleEquipmentCapture()
        return
    end
    local getLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    local pickup = C_Container and C_Container.PickupContainerItem or PickupContainerItem
    local openSocket = C_ItemSocketInfo and C_ItemSocketInfo.SocketInventoryItem or SocketInventoryItem
    local clickSocket = C_ItemSocketInfo and C_ItemSocketInfo.ClickSocketButton or ClickSocketButton
    local closeSocket = C_ItemSocketInfo and C_ItemSocketInfo.CloseSocketInfo or CloseSocketInfo
    local getNumSockets = C_ItemSocketInfo and C_ItemSocketInfo.GetNumSockets or GetNumSockets
    if not (getLink and pickup and openSocket and clickSocket and getNumSockets) then
        Addon:Print(Addon:T("UI.THIS_CLIENT_DOES_NOT_PROVIDE_ALL_REQUIRED_SOCKETING_APIS"))
        return
    end
    if getLink(candidate.bag, candidate.bagSlot) ~= candidate.link then
        Addon:Print(Addon:T("UI.GEM_LOCATION_OR_QUANTITY_CHANGED_SELECT_IT_AGAIN"))
        Addon.AccountPage.Refresh(parent, parent.buildsContext)
        return
    end
    if InCombatLockdown and InCombatLockdown() then Addon:Print(Addon:T("UI.CANNOT_START_SOCKETING_IN_COMBAT")) return end
    if CursorHasItem and CursorHasItem() then Addon:Print(Addon:T("UI.CLEAR_THE_ITEM_ON_YOUR_CURSOR_FIRST")) return end
    ClearPendingGem(parent, true)
    if not ItemSocketingFrame and UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_ItemSocketingUI")
    end
    local opened = pcall(openSocket, slotID)
    local numSockets = getNumSockets and getNumSockets() or 0
    if not opened or numSockets < socketIndex then
        ClearPendingGem(parent, true)
        Addon:Print(Addon:T("UI.THE_CLIENT_COULD_NOT_OPEN_THE_TARGET_ITEM_S_SOCKETS"))
        return
    end
    pickup(candidate.bag, candidate.bagSlot)
    clickSocket(socketIndex)
    if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
    local getNew = C_ItemSocketInfo and C_ItemSocketInfo.GetNewSocketInfo or GetNewSocketInfo
    if getNew and not getNew(socketIndex) then
        ClearPendingGem(parent, true)
        Addon:Print(Addon:T("UI.COULD_NOT_PLACE_THE_GEM_IN_THE_TARGET_SOCKET_SELECT_IT_AGAIN"))
        return
    end
    parent.buildsPendingGem = { slotID = slotID, socketIndex = socketIndex, candidate = candidate, itemLink = item.itemLink }
    if ItemSocketingFrame then
        ItemSocketingFrame:SetAlpha(0)
        ItemSocketingFrame:EnableMouse(false)
    end
    Addon.AccountPage.Refresh(parent, parent.buildsContext)
end

local function ApplyPendingGem(parent)
    local pending = parent.buildsPendingGem
    if not pending then return end
    if parent.buildsSelectedEquipmentSlot ~= pending.slotID
        or GetInventoryItemLink("player", pending.slotID) ~= pending.itemLink then
        ClearPendingGem(parent, true)
        Addon:Print(Addon:T("UI.EQUIPMENT_CHANGED_SELECT_THE_GEM_AGAIN"))
        Addon.AccountPage.Refresh(parent, parent.buildsContext)
        return
    end
    local getNew = C_ItemSocketInfo and C_ItemSocketInfo.GetNewSocketInfo or GetNewSocketInfo
    local accept = C_ItemSocketInfo and C_ItemSocketInfo.AcceptSockets or AcceptSockets
    if not (getNew and accept and getNew(pending.socketIndex)) then
        ClearPendingGem(parent, true)
        Addon:Print(Addon:T("UI.PENDING_SOCKETING_EXPIRED_SELECT_THE_GEM_AGAIN"))
        Addon.AccountPage.Refresh(parent, parent.buildsContext)
        return
    end
    if InCombatLockdown and InCombatLockdown() then Addon:Print(Addon:T("UI.CANNOT_SOCKET_GEMS_IN_COMBAT")) return end
    accept()
end

local MissingCraftReagents
local function RecordAugmentAction(stage, source, slotID)
    local trace = Addon.augmentActionTrace or {}
    Addon.augmentActionTrace = trace
    local itemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
    local spellName, spellID
    if source.itemID and itemSpell then spellName, spellID = itemSpell(source.itemID) end
    trace[#trace + 1] = string.format("%s item=%s useSpell=%s/%s slot=%s targeting=%s itemTarget=%s/%s", stage,
        tostring(source.itemID), tostring(spellName), tostring(spellID), tostring(slotID),
        tostring(SpellIsTargeting and SpellIsTargeting()), tostring(SpellCanTargetItem and SpellCanTargetItem()),
        tostring(SpellCanTargetItemID and SpellCanTargetItemID()))
    if #trace > 12 then table.remove(trace, 1) end
    Addon.augmentActionTime = GetTime()
    if not Addon.augmentActionEvents then
        local events = CreateFrame("Frame")
        Addon.augmentActionEvents = events
        for _, event in ipairs({ "UI_ERROR_MESSAGE", "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED",
            "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED" }) do
            events:RegisterEvent(event)
        end
        events:SetScript("OnEvent", function(_, event, a, b, c, d)
            if GetTime() - (Addon.augmentActionTime or 0) > 8 then return end
            if event:match("^UNIT_") and a ~= "player" then return end
            local log = Addon.augmentActionTrace
            log[#log + 1] = table.concat({ event, tostring(a), tostring(b), tostring(c), tostring(d) }, " ")
            if #log > 12 then table.remove(log, 1) end
        end)
    end
end

local function PrepareItemAugmentAction(anchor, slotID, item, candidate, viewport, completed)
    anchor.buildsAugmentAction = { slotID, item, candidate, viewport, completed }
    if InCombatLockdown and InCombatLockdown() then return end
    local button = anchor.buildsSecureAugmentButton
    if button then
        if UnregisterStateDriver then UnregisterStateDriver(button, "visibility") end
        button:Hide()
    end
    -- Rows are populated before the scroll child's height and ancestor
    -- visibility are finalized. Prepare the action even while hidden;
    -- the visibility callback below controls whether it accepts clicks.
    if not candidate or not candidate.bag then return end
    local bag = candidate.source.itemID and BagApplyingItems()[candidate.source.itemID]
    if not (bag and GetInventoryItemLink("player", slotID) == item.itemLink) then return end
    if not button then
        -- The action belongs to the row's scroll-child hierarchy. A separate
        -- UIParent sibling is not part of the ScrollFrame's mouse hit tree.
        button = CreateFrame("Button", nil, anchor, "SecureActionButtonTemplate")
        anchor.buildsSecureAugmentButton = button
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetScript("PreClick", function(self, mouseButton, down)
            if down then return end
            local liveBag = BagApplyingItems()[self.source.itemID]
            local valid = liveBag and liveBag.bag == self.sourceBag and liveBag.bagSlot == self.sourceBagSlot
                and GetInventoryItemLink("player", self.targetSlot) == self.targetLink
                and not (CursorHasItem and CursorHasItem())
            if not (InCombatLockdown and InCombatLockdown()) then
                self:SetAttribute("type1", valid and "item" or nil)
            end
            RecordAugmentAction(valid and "secure-before" or "source-changed", self.source, self.targetSlot)
            if not valid then Addon:Print(Addon:T("UI.EQUIPMENT_BAGS_OR_CURSOR_CHANGED_SELECT_AGAIN")) end
        end)
        button:SetScript("PostClick", function(self, mouseButton, down)
            if down then return end
            RecordAugmentAction("secure-after", self.source, self.targetSlot)
            if self.completed then self.completed() end
        end)
        button:SetScript("OnEnter", function()
            local enter = anchor:GetScript("OnEnter")
            if enter then enter(anchor) end
        end)
        button:SetScript("OnLeave", function()
            local leave = anchor:GetScript("OnLeave")
            if leave then leave(anchor) end
        end)
        anchor:HookScript("OnHide", function()
            if not (InCombatLockdown and InCombatLockdown()) then button:Hide() end
        end)
        anchor:HookScript("OnShow", function()
            local action = anchor.buildsAugmentAction
            if action then PrepareItemAugmentAction(anchor, unpack(action)) end
        end)
        button:RegisterEvent("PLAYER_REGEN_ENABLED")
        button:SetScript("OnEvent", function()
            local action = anchor.buildsAugmentAction
            if action then PrepareItemAugmentAction(anchor, unpack(action)) end
        end)
    end
    button.source, button.targetSlot = candidate.source, slotID
    button.sourceBag, button.sourceBagSlot, button.targetLink = bag.bag, bag.bagSlot, item.itemLink
    button.viewport, button.completed = viewport, completed
    button:ClearAllPoints()
    button:SetAllPoints(anchor)
    button:SetFrameStrata(anchor:GetFrameStrata())
    button:SetFrameLevel(anchor:GetFrameLevel() + 5)
    button:SetAttribute("type1", "item")
    button:SetAttribute("item1", tostring(bag.bag) .. " " .. tostring(bag.bagSlot))
    button:SetAttribute("target-slot1", slotID)
    RecordAugmentAction("prepared bag=" .. bag.bag .. ":" .. bag.bagSlot, candidate.source, slotID)
    if RegisterStateDriver then RegisterStateDriver(button, "visibility", "[combat] hide; show") end
    button:EnableMouse(true)
    button:Show()
end

local function PrepareItemAugmentConfirmation(popup, slotID, item, candidate)
    if not popup then return end
    if InCombatLockdown and InCombatLockdown() then
        Addon:Print(Addon:T("UI.LEAVE_COMBAT_AND_CONFIRM_THE_ENHANCEMENT_AGAIN"))
        return
    end
    local button = popup.buildsSecureAugmentButton
    if button then
        if UnregisterStateDriver then UnregisterStateDriver(button, "visibility") end
        button:Hide()
    end
    if not candidate.bag then return end
    local bag = candidate.source.itemID and BagApplyingItems()[candidate.source.itemID]
    local accept = popup.button1 or (popup.GetButton1 and popup:GetButton1())
        or (popup.GetName and _G[popup:GetName() .. "Button1"])
    if not (bag and accept and GetInventoryItemLink("player", slotID) == item.itemLink) then
        popup:Hide()
        Addon:Print(Addon:T("UI.EQUIPMENT_OR_BAG_SOURCE_CHANGED_SELECT_AGAIN"))
        return
    end
    if not button then
        -- Keep the secure action outside the shared popup hierarchy so other
        -- Blizzard dialogs do not acquire a protected child.
        button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        popup.buildsSecureAugmentButton = button
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetScript("PostClick", function(self, mouseButton, down)
            if not down then StaticPopup_OnClick(popup, 1) end
        end)
        button:SetScript("OnEnter", function() accept:LockHighlight() end)
        button:SetScript("OnLeave", function() accept:UnlockHighlight() end)
        local function HideAction()
            if not (InCombatLockdown and InCombatLockdown()) then
                if UnregisterStateDriver then UnregisterStateDriver(button, "visibility") end
                button:Hide()
            end
        end
        popup:HookScript("OnHide", HideAction)
        button:RegisterEvent("PLAYER_REGEN_ENABLED")
        button:SetScript("OnEvent", function()
            if not popup:IsShown() then HideAction() end
        end)
    end
    button:ClearAllPoints()
    button:SetAllPoints(accept)
    button:SetFrameStrata(popup:GetFrameStrata())
    button:SetFrameLevel(accept:GetFrameLevel() + 1)
    button:SetAttribute("type", "item")
    button:SetAttribute("item", tostring(bag.bag) .. " " .. tostring(bag.bagSlot))
    button:SetAttribute("target-slot", slotID)
    -- The physical confirmation click performs both secure actions. OnAccept
    -- only closes the dialog and must not issue a second insecure item use.
    popup.info.OnAccept = function() end
    if RegisterStateDriver then RegisterStateDriver(button, "visibility", "[combat] hide; show") end
    button:Show()
end

local function BeginNativeAugment(parent, slotID, item, candidate)
    local selected = parent.buildsSelectedCharacter
    local source = candidate.source
    RecordAugmentAction("native-handler", source, slotID)
    local target = source and (source.target or (Addon.ApplyTargets and Addon.ApplyTargets[source.spellID]))
    if not (IsCurrent(selected) and parent.buildsSlot == parent.buildsActiveSlot
        and GetInventoryItemLink and GetInventoryItemLink("player", slotID) == item.itemLink
        and TargetMatches(item, source, target)) then
        Addon:Print(Addon:T("UI.EQUIPMENT_OR_CANDIDATE_REQUIREMENTS_CHANGED_CHECK_AGAIN"))
        return
    end
    if InCombatLockdown and InCombatLockdown() then Addon:Print(Addon:T("UI.CANNOT_START_AN_EQUIPMENT_UPGRADE_IN_COMBAT")) return end
    if CursorHasItem and CursorHasItem() then Addon:Print(Addon:T("UI.CLEAR_THE_ITEM_ON_YOUR_CURSOR_FIRST")) return end
    local bag = source.itemID and BagApplyingItems()[source.itemID]
    local useBag = C_Container and C_Container.UseContainerItem or UseContainerItem
    if bag and useBag then
        useBag(bag.bag, bag.bagSlot)
    elseif candidate.learned and RecipeLearned(source.spellID)
        and (not source.professionID or (CurrentProfessionSkill(source.professionID) or 0) >= (source.requiredSkill or 0))
        and CastSpellByID then
        local missing = MissingCraftReagents(source.spellID, source.itemID)
        if missing and #missing > 0 then
            Addon:Print(Addon:T("UI.MISSING_REAGENTS") .. table.concat(missing, Addon:T("FORMAT.LIST_SEPARATOR")))
            return
        end
        CastSpellByID(source.spellID)
    else
        Addon:Print(Addon:T("UI.ENHANCEMENT_SOURCE_CHANGED_CHECK_YOUR_BAGS_OR_PROFESSION"))
        return
    end
    if SpellIsTargeting and SpellIsTargeting() then
        PickupInventoryItem(slotID)
    elseif CursorHasItem and CursorHasItem() then
        PickupInventoryItem(slotID)
    else
        Addon:Print(Addon:T("UI.THE_CLIENT_DID_NOT_ENTER_TARGETING_MODE_NOTHING_WAS_APPLIED"))
        return
    end
end

MissingCraftReagents = function(recipeID, itemID)
    local fixed = Addon.RecipeReagents and Addon.RecipeReagents[recipeID]
    if fixed and GetItemCount then
        local missing = {}
        for _, reagent in ipairs(fixed) do
            local reagentID, required = reagent[1], reagent[2]
            local held = GetItemCount(reagentID, false) or 0
            local deficit = required - held
            if deficit > 0 then
                local name = GetItemInfo and GetItemInfo(reagentID)
                missing[#missing + 1] = (name or (Addon:T("UI.ITEM") .. reagentID)) .. " ×" .. deficit
            end
        end
        return missing
    end
    if not (GetNumTradeSkills and GetTradeSkillNumReagents and GetTradeSkillReagentInfo) then return nil end
    local recipeIndex
    for index = 1, (GetNumTradeSkills() or 0) do
        local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(index)
        local linkedID = recipeLink and tonumber(recipeLink:match("enchant:(%d+)") or recipeLink:match("spell:(%d+)"))
        if linkedID == recipeID then recipeIndex = index; break end
        if not recipeLink and GetTradeSkillItemLink then
            local product = GetTradeSkillItemLink(index)
            local recipeName = GetSpellInfo and GetSpellInfo(recipeID)
            local listedName = GetTradeSkillInfo and GetTradeSkillInfo(index)
            if product and tonumber(product:match("item:(%d+)")) == itemID
                and recipeName and recipeName == listedName then
                recipeIndex = index; break
            end
        end
    end
    if not recipeIndex then return nil end
    local missing = {}
    for index = 1, (GetTradeSkillNumReagents(recipeIndex) or 0) do
        local name, _, required, held = GetTradeSkillReagentInfo(recipeIndex, index)
        local deficit = (tonumber(required) or 0) - (tonumber(held) or 0)
        if deficit > 0 then missing[#missing + 1] = (name or Addon:T("UI.REAGENTS")) .. " ×" .. deficit end
    end
    return missing
end

local function BeginCraft(recipeID, itemID)
    if InCombatLockdown and InCombatLockdown() then Addon:Print(Addon:T("UI.CANNOT_CRAFT_IN_COMBAT")) return end
    local craft = itemID and Addon.CraftSources and Addon.CraftSources[itemID]
    local skill = craft and craft.skills and craft.skills[recipeID]
    local currentSkill = skill and CurrentProfessionSkill(skill[1])
    if not (recipeID and skill and currentSkill and currentSkill >= skill[2]
        and RecipeLearned(recipeID) and CastSpellByID) then
        Addon:Print(Addon:T("UI.RECIPE_STATE_CHANGED_OPEN_THE_PROFESSION_WINDOW_AGAIN"))
        return
    end
    local missing = MissingCraftReagents(recipeID, itemID)
    if missing and #missing > 0 then
        Addon:Print(Addon:T("UI.MISSING_REAGENTS") .. table.concat(missing, Addon:T("FORMAT.LIST_SEPARATOR")))
        return
    end
    CastSpellByID(recipeID)
    Addon:Print(Addon:T("UI.CRAFTING_STARTED_BAG_CANDIDATES_WILL_REFRESH_WHEN_IT_FINISHES"))
end

local function RenderEquipmentDetail(parent, snapshot)
    local detail = parent.buildsEquipment.detail
    local slotID = parent.buildsSelectedEquipmentSlot
    local item = slotID and snapshot and snapshot.slots and snapshot.slots[tostring(slotID)]
    if not (slotID and item and item.itemLink) then
        if parent.buildsPendingGem then ClearPendingGem(parent, true) end
        parent.buildsSelectedEquipmentSlot = nil
        detail:Hide()
        return
    end
    if parent.buildsPendingGem and (parent.buildsPendingGem.slotID ~= slotID
        or parent.buildsPendingGem.itemLink ~= item.itemLink) then
        ClearPendingGem(parent, true)
    end
    detail:Show()
    local pending = parent.buildsPendingGem
    detail.scroll:ClearAllPoints()
    detail.scroll:SetPoint("TOPLEFT", 8, -44)
    detail.scroll:SetPoint("BOTTOMRIGHT", -8, pending and 46 or 8)
    detail.apply:SetShown(pending ~= nil)
    detail.cancel:SetShown(pending ~= nil)
    detail.pending:SetShown(pending ~= nil)
    if pending then
        detail.pending:SetText(Addon:T("UI.PENDING_GEM") .. pending.socketIndex .. Addon:T("UI.SOCKET"))
        detail.apply:SetScript("OnClick", function() ApplyPendingGem(parent) end)
        detail.cancel:SetScript("OnClick", function()
            ClearPendingGem(parent, true)
            Addon.AccountPage.Refresh(parent, parent.buildsContext)
        end)
    end
    local isLive = parent.buildsEquipmentIsObserved and IsCurrent(parent.buildsSelectedCharacter)
        and parent.buildsSlot == parent.buildsActiveSlot
        and GetInventoryItemLink and GetInventoryItemLink("player", slotID) == item.itemLink
    local liveName = GetItemInfo and GetItemInfo(item.itemLink)
    detail.itemIcon:SetTexture(item.icon)
    detail.title:SetText(liveName or ((SLOT_LABELS[slotID] or Addon:T("UI.EQUIPMENT")) .. Addon:T("UI.EQUIPMENT_UPGRADES")))
    local bodyWidth = math.max(120, (detail.scroll:GetWidth() or detail:GetWidth() or 180) - 18)
    detail.body:SetWidth(bodyWidth)
    local y, used = -2, 0
    local function AddRow(label, link, onClick, color, visual)
        used = used + 1
        local row = detail.rows[used]
        if not row then
            row = CreateFrame("Button", nil, detail.body, "BackdropTemplate")
            row.text = Text(row, Theme.Font.meta, C.text)
            row.text:SetAllPoints(row)
            row.text:SetWordWrap(true)
            row.subtitle = Text(row, Theme.Font.meta, C.muted)
            row.action = Text(row, Theme.Font.meta, C.accent, "RIGHT")
            row.action:SetWidth(72)
            row.action:SetPoint("RIGHT", row, "RIGHT", -9, 0)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(24, 24)
            row.icon:SetPoint("LEFT", 5, 0)
            row.selected = row:CreateTexture(nil, "BACKGROUND")
            row.selected:SetAllPoints(row)
            row.selected:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.16)
            detail.rows[used] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", detail.body, "TOPLEFT", 4, y)
        row:SetWidth(bodyWidth - 8)
        row:SetHeight(120)
        row.text:SetText(label)
        local rowHeight = math.max(30, math.ceil((row.text:GetStringHeight() or 0) + 8))
        row:SetHeight(rowHeight)
        local actionable = visual and visual.actionable
        if actionable then
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            row:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], visual.selected and 0.20 or 0.09)
            row:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], visual.selected and 0.95 or 0.48)
            row:SetHeight(46)
            rowHeight = 46
            row.text:ClearAllPoints()
            row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -6)
            row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -82, -6)
            row.text:SetHeight(17)
            row.text:SetWordWrap(false)
            row.subtitle:ClearAllPoints()
            row.subtitle:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 36, 6)
            row.subtitle:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -82, 6)
            row.subtitle:SetHeight(15)
            row.subtitle:SetText(visual.subtitle or Addon:T("UI.READY_TO_USE"))
            row.subtitle:Show()
            row.action:SetText(visual.badge or Addon:T("UI.USE"))
            row.action:Show()
        else
            row:SetBackdrop(nil)
            row.subtitle:Hide()
            row.action:Hide()
            row.text:SetWordWrap(true)
        end
        if visual and visual.icon then
            row.icon:SetTexture(visual.icon)
            row.icon:Show()
            if not actionable then
                row.text:ClearAllPoints()
                row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 36, 0)
                row.text:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
                row:SetHeight(math.max(32, rowHeight))
                rowHeight = row:GetHeight()
            end
        else
            row.icon:Hide()
            if not actionable then
                row.text:ClearAllPoints()
                row.text:SetAllPoints(row)
            end
        end
        if not actionable then
            rowHeight = math.max(visual and visual.icon and 32 or 30,
                math.ceil((row.text:GetStringHeight() or 0) + 8))
            row:SetHeight(rowHeight)
        end
        row.selected:SetShown(visual and visual.selected and not actionable or false)
        local tint = color or (onClick and C.accent or C.muted)
        row.text:SetTextColor(tint[1], tint[2], tint[3])
        if Addon.GoalTargets and Addon.GoalTargets.ref then
            Core.BusinessItemActions:Unbind(row)
            if row.buildsSecureAugmentButton then Core.BusinessItemActions:Unbind(row.buildsSecureAugmentButton) end
        end
        row:SetScript("OnClick", onClick)
        if link then SetAugmentTooltip(row, label, link)
        else row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil) end
        if actionable then
            local tooltipEnter, tooltipLeave = row:GetScript("OnEnter"), row:GetScript("OnLeave")
            row:SetScript("OnEnter", function(self)
                self:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], visual.selected and 0.25 or 0.16)
                self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
                if tooltipEnter then tooltipEnter(self) end
            end)
            row:SetScript("OnLeave", function(self)
                self:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], visual.selected and 0.20 or 0.09)
                self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], visual.selected and 0.95 or 0.48)
                if tooltipLeave then tooltipLeave(self) end
            end)
        end
        row:Show()
        y = y - rowHeight - (actionable and 5 or 2)
        PrepareItemAugmentAction(row, slotID, item, nil)
        return row
    end
    if not isLive then AddRow(Addon:T("UI.VIEWING_A_SNAPSHOT_SWITCH_TO_CURRENT_EQUIPMENT_TO_PERFORM_ACTIONS")) end
    local gems = item.gems or {}
    for index, socket in ipairs(gems) do
        local label = tostring(index) .. ". " .. (SOCKET_LABELS[socket.socketType] or Addon:T("UI.UNKNOWN")) .. Addon:T("UI.SOCKET_2")
            .. (socket.itemName or (socket.itemLink and Addon:T("UI.SOCKETED") or Addon:T("UI.EMPTY")))
        AddRow(label, socket.itemLink)
        if isLive then
            local candidates = Addon.Gems:BagCandidates(socket.socketType)
            local craftable = CraftGemCandidates(socket.socketType)
            local pendingHere = pending and pending.socketIndex == index
            if #candidates == 0 and #craftable == 0 and not pendingHere then
                AddRow(Addon:T("UI.NO_CONFIRMED_MATCHING_GEMS_IN_BAGS_OR_LEARNED_RECIPES"))
            end
            local renderedPending = false
            for _, candidate in ipairs(candidates) do
                local currentCandidate, currentIndex = candidate, index
                local selected = pendingHere
                    and pending.candidate.bag == candidate.bag
                    and pending.candidate.bagSlot == candidate.bagSlot
                if selected then renderedPending = true end
                local goalRow = AddRow(candidate.name,
                    candidate.link, function()
                        local function Apply() StageNativeGem(parent, slotID, currentIndex, currentCandidate) end
                        if socket.itemLink and StaticPopup_Show then
                            StaticPopupDialogs.YIBO_BUILDS_REPLACE_GEM = StaticPopupDialogs.YIBO_BUILDS_REPLACE_GEM or {
                                text = "%s",
                                button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
                            }
                            StaticPopupDialogs.YIBO_BUILDS_REPLACE_GEM.OnAccept = Apply
                            StaticPopup_Show("YIBO_BUILDS_REPLACE_GEM", Addon:T("CONFIRM.REPLACE_GEM", socket.itemName or Addon:T("UI.EXISTING_GEM"), candidate.name))
                        else Apply() end
                    end, nil, { icon = candidate.icon, selected = selected, actionable = true,
                        subtitle = Addon:T("UI.IN_BAGS") .. tostring(candidate.count) .. Addon:T("UI.READY_TO_SOCKET"),
                        badge = selected and Addon:T("UI.PENDING") or Addon:T("UI.SELECT") })
                if Addon.GoalTargets then Addon.GoalTargets:Bind(goalRow, parent, item, slotID, "gem", tonumber(candidate.link:match("item:(%d+)")), currentIndex) end
            end
            if pendingHere and not renderedPending then
                local chosen = pending.candidate
                AddRow(chosen.name, chosen.link, nil, C.accent,
                    { icon = chosen.icon, selected = true, actionable = true,
                        subtitle = Addon:T("UI.BAG_GEM_AWAITING_SUBMISSION"), badge = Addon:T("UI.PENDING") })
            end
            for _, candidate in ipairs(craftable) do
                local craft = candidate
                local craftIcon = GetItemIcon and GetItemIcon(craft.itemID)
                AddRow("  " .. IconText(craftIcon, craft.name, 14) .. Addon:T("UI.CRAFTABLE"),
                    "spell:" .. craft.recipeID,
                    function() BeginCraft(craft.recipeID, craft.itemID) end)
            end
        end
    end
    if #gems == 0 then AddRow(Addon:T("UI.THIS_ITEM_HAS_NO_CONFIRMED_SOCKETS")) end
    local enchant = item.enchant
    if enchant and enchant.state == "installed" then AddRow(Addon:T("UI.ENCHANT") .. (enchant.name or Addon:T("UI.INSTALLED")), enchant.tooltipLink)
    elseif enchant and enchant.state == "uninstalled" then AddRow(Addon:T("UI.ENCHANT_NOT_INSTALLED")) end
    local engineering = item.engineering
    if engineering and engineering.state == "installed" then AddRow(Addon:T("UI.ENGINEERING") .. (engineering.name or Addon:T("UI.INSTALLED")), engineering.tooltipLink)
    elseif engineering and engineering.state == "base-missing" then AddRow(Addon:T("UI.ENGINEERING_NOT_INSTALLED")) end
    if item.beltBuckle and item.beltBuckle.state == "base-missing" then AddRow(Addon:T("UI.NO_BELT_BUCKLE")) end
    if item.blacksmithSockets and item.blacksmithSockets.state == "base-missing" then AddRow(Addon:T("UI.NO_BLACKSMITH_SOCKET")) end
    if isLive then
        local augments = AugmentCandidates(slotID, item)
        if #augments > 0 then AddRow(Addon:T("UI.AVAILABLE_ENCHANTS_AND_ENHANCEMENTS"), nil, nil, C.accent) end
        for _, candidate in ipairs(augments) do
            local selectedCandidate = candidate
            if candidate.bag or candidate.learned then
                local sourceText = candidate.bag and (Addon:T("UI.IN_BAGS") .. tostring(candidate.bag.count)) or ""
                if candidate.learned then sourceText = sourceText .. (sourceText ~= "" and " / " or "") .. Addon:T("UI.LEARNED_RECIPES") end
                local tooltipLink = candidate.bag and candidate.bag.link or "spell:" .. candidate.spellID
                local candidateIcon = candidate.bag and candidate.source.itemID and GetItemIcon
                    and GetItemIcon(candidate.source.itemID)
                    or (GetSpellTexture and GetSpellTexture(candidate.spellID))
                local row
                row = AddRow(candidate.name,
                    tooltipLink, function()
                    -- Bag sources are dispatched by the physical secure click.
                    -- Only learned profession spells use the native spell path.
                    if selectedCandidate.bag then
                        local secure = row and row.buildsSecureAugmentButton
                        RecordAugmentAction("row-fallback combat=" .. tostring(InCombatLockdown and InCombatLockdown())
                            .. " secure=" .. tostring(secure ~= nil)
                            .. " shown=" .. tostring(secure and secure:IsShown())
                            .. " mouse=" .. tostring(secure and secure:IsMouseEnabled())
                            .. " level=" .. tostring(secure and secure:GetFrameLevel()) .. "/" .. tostring(row:GetFrameLevel()),
                            selectedCandidate.source, slotID)
                        if InCombatLockdown and InCombatLockdown() then
                            Addon:Print(Addon:T("UI.CANNOT_APPLY_A_BAG_ENCHANT_IN_COMBAT"))
                        else
                            Addon:Print(Addon:T("UI.THE_CLICK_DID_NOT_REACH_THE_SECURE_BUTTON_USE_YBB_AUGMENT_TO_INSPECT_THE_LO"))
                        end
                        return
                    end
                    BeginNativeAugment(parent, slotID, item, selectedCandidate)
                end, nil, { icon = candidateIcon, actionable = true,
                    subtitle = sourceText .. Addon:T("UI.READY_TO_APPLY"), badge = Addon:T("UI.APPLY") })
                PrepareItemAugmentAction(row, slotID, item, selectedCandidate, detail.scroll)
                if Addon.GoalTargets and candidate.enchantID then Addon.GoalTargets:Bind(row, parent, item, slotID, "enchant", candidate.enchantID) end
            end
        end
        for _, candidate in ipairs(augments) do
            local recipeID = candidate.craftRecipe
            if recipeID then
                local producedID = candidate.source.itemID
                local producedIcon = GetItemIcon and GetItemIcon(producedID)
                AddRow(IconText(producedIcon, candidate.name, 14) .. Addon:T("UI.CRAFTABLE"),
                    "spell:" .. recipeID,
                    function() BeginCraft(recipeID, producedID) end)
            end
        end
    end
    for index = used + 1, #detail.rows do detail.rows[index]:Hide() end
    detail.body:SetHeight(math.max(1, -y + 2))
    if detail.scroll.SetContentHeight then detail.scroll:SetContentHeight(detail.body:GetHeight()) end
end

local function PlaceEquipment(parent, snapshot)
    local box = parent.buildsEquipment
    local boxHeight = box.layoutHeight or box:GetHeight() or 500
    local rowHeight = math.max(39, math.min(80, math.floor((boxHeight - 125) / 8)))
    local maxIconSize = math.min(ICON_SIZE, rowHeight - 5)
    local augmentSize = math.min(AUGMENT_ICON_SIZE, math.floor((maxIconSize - 2) / 2))
    local iconSize = augmentSize * 2 + 2
    local currentRowEnd = 12 + 7 * rowHeight + iconSize
    local weaponStart = boxHeight - 30 - iconSize
    local availableRowExtra = math.max(0, math.floor((weaponStart - currentRowEnd - 2) / 7))
    local rowStep = rowHeight + math.min(4, availableRowExtra)
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
            -- Keep the two weapon slots together in the model's lower centre.
            -- The icon pair has one compact intentional gap; only the gem and
            -- enchant rails extend outward from it.
            local weaponGap = Theme.Space.sm
            local previousWeaponSize = math.min(ICON_SIZE - 2, rowHeight - 5)
            local weaponOffset = math.floor((previousWeaponSize + weaponGap) / 2)
            local weaponBottomOffset = PixelRound(30 + (previousWeaponSize - iconSize) / 2, button)
            button:SetPoint("BOTTOM", box, "BOTTOM", side == "weapon-left" and -weaponOffset or weaponOffset, weaponBottomOffset)
        else
            button:SetPoint("TOPLEFT", box, "TOPLEFT", side == "left" and left or right, -12 - (visualIndex - 1) * rowStep)
        end
        button.slotLabel:ClearAllPoints()
        if side == "left" then button.slotLabel:SetPoint("RIGHT", button, "LEFT", -4, 0); button.slotLabel:SetJustifyH("RIGHT")
        elseif side == "right" then button.slotLabel:SetPoint("LEFT", button, "RIGHT", 4, 0); button.slotLabel:SetJustifyH("LEFT")
        else button.slotLabel:SetPoint("TOP", button, "BOTTOM", 0, -4); button.slotLabel:SetJustifyH("CENTER") end
        button.slotLabel:SetText(SLOT_LABELS[slotID] or "")
        button.icon:SetTexture(item and item.icon or nil)
        button.icon:SetDesaturated(not (item and item.itemLink))
        local itemLevel = slotID ~= (INVSLOT_BODY or 4) and slotID ~= (INVSLOT_TABARD or 19)
            and item and item.itemLink and Addon.Snapshot:GetItemLevel(item)
        button.itemLevel:SetWidth(math.max(1, button:GetWidth() - 6))
        button.itemLevel:SetText(itemLevel and tostring(math.floor(itemLevel)) or "")
        button.itemLevel:SetShown(itemLevel and true or false)
        RefreshPixelBorder(button.border, button)
        local itemBorderRed, itemBorderGreen, itemBorderBlue = ItemBorderColor(item)
        SetPixelBorderColor(button.border, { itemBorderRed, itemBorderGreen, itemBorderBlue })
        button.selection:SetShown(parent.buildsSelectedEquipmentSlot == slotID and item and item.itemLink and true or false)
        local socketCount = item and item.gems and #item.gems or 0
        local augmentSize = math.min(PixelRound(AUGMENT_ICON_SIZE, button), PixelRound(iconSize, button))
        local gemSize = augmentSize
        local gemGap = PixelRound(AUGMENT_ICON_GAP, button.socketRail)
        local gemStep = gemSize + gemGap
        local railWidth = socketCount > 0 and (socketCount * gemSize + (socketCount - 1) * gemGap) or gemSize
        local rowOutset = PixelRound(math.max(0, 2 * augmentSize - iconSize + PixelRound(2, button)), button)
        local socketOutset = PixelRound(rowOutset / 2, button)
        local effectOutset = rowOutset - socketOutset
        button.socketRail:ClearAllPoints()
        button.socketRail:SetSize(railWidth, gemSize)
        button.socketRail:SetFrameLevel(button:GetFrameLevel())
        if side == "left" or side == "weapon-right" then
            button.socketRail:SetPoint("TOPLEFT", button, "TOPRIGHT", PixelRound(4, button), socketOutset)
        else
            button.socketRail:SetPoint("TOPRIGHT", button, "TOPLEFT", -PixelRound(4, button), socketOutset)
        end
        button.socketRail:SetShown(socketCount > 0)
        for gemIndex, gem in ipairs(button.gems) do
            local socket = item and item.gems and item.gems[gemIndex]
            gem:ClearAllPoints()
            gem:SetSize(gemSize, gemSize)
            -- Socket indexes run from the equipment icon toward the model.
            if side == "left" or side == "weapon-right" then gem:SetPoint("TOPLEFT", button.socketRail, "TOPLEFT", (gemIndex - 1) * gemStep, 0)
            else gem:SetPoint("TOPRIGHT", button.socketRail, "TOPRIGHT", -(gemIndex - 1) * gemStep, 0) end
            RefreshPixelBorder(gem.border, gem)
            gem.icon:ClearAllPoints()
            gem.icon:SetAllPoints(gem)
            gem.icon:SetTexCoord(unpack(GEM_ICON_TEXCOORD))
            local isEmpty = socket and not socket.itemLink
            -- Empty sockets are represented by the requirement-colored frame
            -- alone; the game's native empty-socket glyph is not a gem icon.
            local installedIcon = socket and socket.itemLink and GetItemIcon
                and GetItemIcon(socket.itemID or socket.itemLink)
            gem.icon:SetTexture(socket and not isEmpty and (installedIcon or socket.icon) or nil)
            gem.icon:SetDesaturated(false)
            gem.icon:SetAlpha(1)
            local socketColor = socket and SOCKET_BORDER_COLORS[socket.socketType] or SOCKET_BORDER_COLORS.unknown
            SetPixelBorderColor(gem.border, socketColor)
            gem:SetShown(socket and true or false)
            local socketTitle
            if socket then
                socketTitle = socket.itemLink and (socket.itemName or (Addon:T("UI.GEM_2") .. tostring(socket.itemID or "?")))
                    or ((SOCKET_LABELS[socket.socketType] or Addon:T("UI.GEM")) .. Addon:T("UI.EMPTY_SOCKET"))
            end
            SetAugmentTooltip(gem, socketTitle, socket and socket.itemLink)
        end
        button.enchant:ClearAllPoints()
        button.enchant:SetSize(augmentSize, augmentSize)
        local isWaist = slotID == (INVSLOT_WAIST or 6)
        local itemClassID, itemSubclassID
        if item and item.itemLink and GetItemInfo then
            itemClassID, itemSubclassID = select(12, GetItemInfo(item.itemLink))
        end
        local isRanged = slotID == (INVSLOT_MAINHAND or 16) and itemClassID == 2
            and (itemSubclassID == 2 or itemSubclassID == 3 or itemSubclassID == 18)
        local engineering = item and item.engineering
        local engineeringState = engineering and engineering.state or "not-applicable"
        local isEngineeringInstalled = engineeringState == "installed"
        local canEngineering = isEngineeringInstalled or engineeringState == "base-missing"
        local nearOffset = PixelRound(4, button)
        local enchantOffset = isWaist and (augmentSize + PixelRound(1, button)) or nearOffset
        if isRanged then enchantOffset = nearOffset + augmentSize + PixelRound(AUGMENT_ICON_GAP, button) end
        if side == "left" or side == "weapon-right" then button.enchant:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", enchantOffset, -effectOutset)
        else button.enchant:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -enchantOffset, -effectOutset) end
        local enchant = item and item.enchant
        local enchantState = enchant and enchant.state or "not-applicable"
        local enchantID = EnchantIDFromItem(item)
        local isEnchanted = enchantID ~= nil or enchantState == "installed"
        -- Legacy snapshots predate the applicability flag.  Preserve their
        -- confirmed enchant display, but do not invent an "unenchanted" state
        -- until a fresh capture records that this MoP slot supports one.
        local canEnchant = isEnchanted or enchantState == "uninstalled" or enchantState == "base-missing"
        button.enchant.icon:SetDesaturated(not isEnchanted)
        button.enchant:SetShown(canEnchant and not isRanged or false)
        SetEnchantTooltip(button.enchant, item, enchantID, isEnchanted)
        button.engineering:ClearAllPoints()
        local engineeringTitle
        local isBack = slotID == (INVSLOT_BACK or 15)
        local isHand = slotID == (INVSLOT_HAND or 10)
        local isHead = slotID == (INVSLOT_HEAD or 1)
        if isWaist then
            engineeringTitle = isEngineeringInstalled and (Addon:T("UI.CURRENT_BELT_ENHANCEMENT") .. (engineering.name or Addon:T("UI.ENGINEERING_ENHANCEMENT"))) or Addon:T("UI.NO_BELT_ENHANCEMENT")
        elseif isBack then
            engineeringTitle = isEngineeringInstalled and (Addon:T("UI.CURRENT_CLOAK_ENHANCEMENT") .. (engineering.name or Addon:T("UI.ENGINEERING_ENHANCEMENT"))) or Addon:T("UI.NO_CLOAK_ENHANCEMENT")
        elseif isHead then
            engineeringTitle = isEngineeringInstalled and (Addon:T("UI.CURRENT_HEAD_ENHANCEMENT") .. (engineering.name or Addon:T("UI.ENGINEERING_ENHANCEMENT"))) or Addon:T("UI.NO_HEAD_ENHANCEMENT")
        elseif isHand then
            engineeringTitle = isEngineeringInstalled and (Addon:T("UI.CURRENT_GLOVE_ENHANCEMENT") .. (engineering.name or Addon:T("UI.ENGINEERING_ENHANCEMENT"))) or Addon:T("UI.NO_GLOVE_ENHANCEMENT")
        else
            engineeringTitle = isEngineeringInstalled and (Addon:T("UI.CURRENT_ENGINEERING_SCOPE") .. (engineering.name or Addon:T("UI.ENGINEERING_ENHANCEMENT"))) or Addon:T("UI.NO_ENGINEERING_SCOPE")
        end
        local beltBuckle = item and item.beltBuckle
        local buckleMissing = beltBuckle and beltBuckle.state == "base-missing"
        local engineeringOffset
        if isRanged and canEngineering then
            engineeringOffset = nearOffset
        elseif isWaist and not canEnchant and not buckleMissing then
            -- A belt has no ordinary enchant slot. When engineering is its
            -- only lower-row effect, place it beside the belt instead of
            -- reserving the absent enchant position.
            engineeringOffset = PixelRound(4, button)
        else
            engineeringOffset = PixelRound((isHand and item and item.blacksmithSockets and item.blacksmithSockets.state == "base-missing") and 38 or (augmentSize + 1), button)
        end
        if canEnchant then
            engineeringOffset = math.max(engineeringOffset, enchantOffset + augmentSize + PixelRound(AUGMENT_ICON_GAP, button))
        end
        button.engineering:SetSize(augmentSize, augmentSize)
        if side == "left" or side == "weapon-right" then button.engineering:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", engineeringOffset, -effectOutset)
        else button.engineering:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -engineeringOffset, -effectOutset) end
        button.engineering.icon:SetDesaturated(not isEngineeringInstalled)
        -- Old snapshots may still mark the head slot as missing an engineering
        -- enhancement. Show it only when an actual head effect was captured.
        button.engineering:SetShown(isHead and isEngineeringInstalled or ((isWaist or isBack or isHand or isRanged) and canEngineering) or false)
        SetEngineeringTooltip(button.engineering, engineeringTitle, engineering, item, isEngineeringInstalled)
        button.base:ClearAllPoints()
        local blacksmithSockets = item and item.blacksmithSockets
        local blacksmithMissing = blacksmithSockets and blacksmithSockets.state == "base-missing"
        local isBlacksmithSlot = slotID == (INVSLOT_WRIST or 9) or slotID == (INVSLOT_HAND or 10)
        local baseOffset = (isWaist or isBlacksmithSlot) and 21 or 4
        if side == "left" or side == "weapon-right" then button.base:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", baseOffset, 2)
        else button.base:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -baseOffset, 2) end
        button.base:SetBackdropBorderColor(C.warning[1], C.warning[2], C.warning[3], 1)
        button.base:SetShown(isBlacksmithSlot and blacksmithMissing and true or false)
        SetAugmentTooltip(button.base, Addon:T("UI.NO_BLACKSMITH_SOCKET"))
        button.buckle:ClearAllPoints()
        if side == "left" or side == "weapon-right" then button.buckle:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 4, 2)
        else button.buckle:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -4, 2) end
        button.buckle.icon:SetDesaturated(true)
        button.buckle:SetBackdropBorderColor(C.warning[1], C.warning[2], C.warning[3], 1)
        button.buckle:SetShown(isWaist and item and item.itemLink and buckleMissing or false)
        SetAugmentTooltip(button.buckle, Addon:T("UI.NO_BELT_BUCKLE"))
        SetNativeItemTooltip(button, item)
        button:SetScript("OnClick", function()
            if not (item and item.itemLink) then return end
            if parent.buildsSelectedEquipmentSlot == slotID then
                parent.buildsSelectedEquipmentSlot = nil
            else
                parent.buildsSelectedEquipmentSlot = slotID
                -- Re-read the worn equipment before offering live bag actions.
                -- A cached observation may predate an enchant or item upgrade.
                if IsCurrent(parent.buildsSelectedCharacter) and parent.buildsSlot == parent.buildsActiveSlot then
                    Addon.Snapshot:ScheduleEquipmentCapture()
                end
            end
            if parent.buildsSelectedEquipmentSlot and parent.buildsBuildCollapsed then
                parent.buildsBuildCollapsed = false
                Addon.buildsBuildCollapsed = false
                Core.AccountView:RefreshPage(true)
            else
                Addon.AccountPage.Refresh(parent, parent.buildsContext)
            end
        end)
        button:SetScript("OnReceiveDrag", function()
            if not (item and item.itemLink and parent.buildsEquipmentIsObserved and GetCursorInfo) then return end
            local kind, cursorItemID = GetCursorInfo()
            if kind ~= "item" then return end
            for _, candidate in ipairs(AugmentCandidates(slotID, item)) do
                if candidate.bag and candidate.source.itemID == cursorItemID then
                    if ClearCursor then ClearCursor() end
                    local function Apply()
                        BeginNativeAugment(parent, slotID, item, candidate)
                    end
                    if StaticPopup_Show then
                        StaticPopupDialogs.YIBO_BUILDS_DROP_AUGMENT = StaticPopupDialogs.YIBO_BUILDS_DROP_AUGMENT or {
                            text = "%s", button1 = ACCEPT, button2 = CANCEL,
                            timeout = 0, whileDead = true, hideOnEscape = true,
                        }
                        StaticPopupDialogs.YIBO_BUILDS_DROP_AUGMENT.OnAccept = Apply
                        local popup = StaticPopup_Show("YIBO_BUILDS_DROP_AUGMENT", Addon:T("CONFIRM.APPLY", GetItemInfo(item.itemLink) or SLOT_LABELS[slotID] or Addon:T("UI.EQUIPMENT"), candidate.name))
                        PrepareItemAugmentConfirmation(popup, slotID, item, candidate)
                    else Apply() end
                    return
                end
            end
        end)
        button:Show(); button.slotLabel:Show()
    end
end

local function RefreshModel(parent, character, equipment)
    local model = parent.buildsEquipment.model
    local available = IsCurrent(character) and model and model.SetUnit
    parent.buildsEquipment.modelControl:SetShown(available and true or false)
    parent.buildsEquipment.modelHint:SetShown(available and true or false)
    if not available then model:Hide(); return end
    local appearanceMode = Addon:GetSettings().appearanceMode
    if model.buildsEquipmentSnapshot ~= equipment or model.buildsAppearanceMode ~= appearanceMode then
        -- PlayerModel caches the rendered unit. Clear it when a fresh observed
        -- equipment snapshot arrives so the mannequin doesn't wait for an
        -- explicit "save build" refresh to rebuild its appearance.
        if model.ClearModel then model:ClearModel() end
        model:SetUnit("player")
        model.buildsEquipmentSnapshot = equipment
        model.buildsAppearanceMode = appearanceMode
    end
    -- SetUnit renders the current transmogged unit. For the prototype view,
    -- TryOn the immutable saved item links over that model, which asks the
    -- native dress-up renderer for each base item's own appearance.
    if appearanceMode == "prototype" and model.TryOn and equipment and equipment.slots then
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
            local group = current[entry.glyphID] and Addon:T("UI.CURRENT") or (entry.isKnown and Addon:T("UI.LEARNED") or Addon:T("UI.NOT_LEARNED"))
            glyphs[#glyphs + 1] = { group = group, entry = entry }
        end
    end
    if #glyphs == 0 then
        for _, entry in ipairs((slotData and slotData.glyphs and slotData.glyphs[selectedType]) or {}) do
            if (entry.glyphID and entry.glyphID > 0) or (entry.spellID and entry.spellID > 0) then glyphs[#glyphs + 1] = { group = Addon:T("UI.CURRENT"), entry = entry } end
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
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(Addon:T("UI.MAJOR_GLYPHS")); GameTooltip:Show()
        end)
        build.catalogMinor:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(Addon:T("UI.MINOR_GLYPHS")); GameTooltip:Show()
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
        row.icon:SetTexture(pair.entry.icon); row.icon:SetDesaturated(pair.group == Addon:T("UI.NOT_LEARNED")); row.rule:Show()
        row.meta:SetShown(LayoutGlyphCellText(row, SnapshotName(pair.entry, "glyph"), GlyphRequirementText(pair.entry), catalogWidth, ClassColor(parent.buildsSelectedCharacter)))
        row.label:SetTextColor(pair.group == Addon:T("UI.NOT_LEARNED") and C.muted[1] or C.text[1], pair.group == Addon:T("UI.NOT_LEARNED") and C.muted[2] or C.text[2], pair.group == Addon:T("UI.NOT_LEARNED") and C.muted[3] or C.text[3])
        row.iconBorder:SetColorTexture(pair.group == Addon:T("UI.CURRENT") and C.accent[1] or C.line[1], pair.group == Addon:T("UI.CURRENT") and C.accent[2] or C.line[2], pair.group == Addon:T("UI.CURRENT") and C.accent[3] or C.line[3], 1)
        local fill = pair.group == Addon:T("UI.CURRENT") and C.selected or C.row
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.alternate[1], C.alternate[2], C.alternate[3], 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local shown
            if pair.entry.glyphLink then shown = pcall(GameTooltip.SetHyperlink, GameTooltip, pair.entry.glyphLink) end
            if not shown and pair.entry.glyphID and pair.entry.glyphID > 0 and GameTooltip.SetGlyphByID then shown = pcall(GameTooltip.SetGlyphByID, GameTooltip, pair.entry.glyphID) end
            if not shown and pair.entry.spellID and pair.entry.spellID > 0 and GameTooltip.SetSpellByID then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, pair.entry.spellID) end
            if not shown then GameTooltip:AddLine(SnapshotName(pair.entry, "glyph")) end
            if pair.group == Addon:T("UI.CURRENT") then GameTooltip:AddLine(Addon:T("UI.USED_BY_CURRENT_BUILD"), C.accent[1], C.accent[2], C.accent[3]) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(fill[1], fill[2], fill[3], 1); GameTooltip:Hide() end)
        row:SetBackdropColor(fill[1], fill[2], fill[3], 1); row:Show()
    end
    for i = index + 1, #build.catalogRows do build.catalogRows[i]:Hide() end
    build.catalogEmpty:SetText(selectedType == "major" and Addon:T("UI.NO_MAJOR_GLYPH_SNAPSHOT") or Addon:T("UI.NO_MINOR_GLYPH_SNAPSHOT"))
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
        local talent = slotData and slotData.talents and slotData.talents[index] or { name = Addon:T("UI.NOT_RECORDED"), icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
        local glyphs = slotData and slotData.glyphs
        local glyph = glyphs and (index <= 3 and glyphs.major and glyphs.major[index] or index > 3 and glyphs.minor and glyphs.minor[index - 3])
        glyph = glyph or { name = Addon:T("UI.NOT_SELECTED"), icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
        local left = BuildCell(build, build.talents, index); left:ClearAllPoints(); left:SetPoint("TOPLEFT", build, "TOPLEFT", 8, -42 - (index - 1) * rowHeight); left:SetSize(talentColumnWidth, rowHeight - 3)
        left.icon:SetSize(56, 56); left.iconBorder:SetSize(60, 60)
        left.label:ClearAllPoints(); left.label:SetPoint("LEFT", left.icon, "RIGHT", 10, 0); left.label:SetPoint("RIGHT", left, "RIGHT", -8, 0)
        left.icon:SetTexture(talent.icon); left.label:SetText(SnapshotName(talent, "talent")); left.meta:Hide(); left.rule:Hide(); left:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.5); SetSpellTooltip(left, talent); left:Show()
        local glyphTop = 42 + (index - 1) * glyphRowHeight
        local right = BuildCell(build, build.glyphs, index); right:ClearAllPoints(); right:SetPoint("TOPLEFT", build, "TOPLEFT", glyphLeft, -glyphTop); right:SetSize(glyphColumnWidth, glyphRowHeight - 3)
        local isMajor = index <= 3
        local border = isMajor and C.warning or C.accent
        local glyphIconSize = isMajor and 56 or 40
        right.icon:SetSize(glyphIconSize, glyphIconSize); right.iconBorder:SetSize(glyphIconSize + 4, glyphIconSize + 4)
        right.icon:SetTexture(glyph.icon); right.meta:SetShown(LayoutGlyphCellText(right, SnapshotName(glyph, "glyph"), GlyphRequirementText(glyph), glyphColumnWidth, ClassColor(parent.buildsSelectedCharacter))); right.rule:Hide(); right.iconBorder:SetColorTexture(border[1], border[2], border[3], 1); right:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.5); SetSpellTooltip(right, glyph); right:Show()
    end
    build.talentTitle:ClearAllPoints(); build.talentTitle:SetPoint("TOPLEFT", 12, -10)
    build.glyphTitle:ClearAllPoints(); build.glyphTitle:SetPoint("TOPLEFT", glyphLeft, -10)
    build.allGlyphs:ClearAllPoints(); build.allGlyphs:SetPoint("TOPRIGHT", -5, -3)
    build.currentGlyphs:ClearAllPoints(); build.currentGlyphs:SetPoint("RIGHT", build.allGlyphs, "LEFT", -4, 0)
    RenderCatalog(parent, slotData, record)
end

local function SetupMainButtons(parent)
    local toolbar = parent.buildsToolbar
    parent.buildsEquipment.detail.close:SetScript("OnClick", function()
        parent.buildsSelectedEquipmentSlot = nil
        Addon.AccountPage.Refresh(parent, parent.buildsContext)
    end)
    toolbar.primary:SetScript("OnClick", function() parent.buildsSlot = "primary"; Addon.AccountPage.Refresh(parent, parent.buildsContext) end)
    toolbar.secondary:SetScript("OnClick", function()
        local selected = parent.buildsSelectedCharacter
        local record = selected and Addon.Snapshot:GetCharacter(selected.id)
        if not (record and record.slots and record.slots.secondary) then return end
        parent.buildsSlot = "secondary"; Addon.AccountPage.Refresh(parent, parent.buildsContext)
    end)
    toolbar.buildToggle:SetScript("OnClick", function()
        parent.buildsSelectedEquipmentSlot = nil
        parent.buildsBuildCollapsed = not parent.buildsBuildCollapsed
        -- Keep the page's layout state available to Core before it measures the
        -- next surface.  The refresh below may resize the shared account frame.
        Addon.buildsBuildCollapsed = parent.buildsBuildCollapsed
        Core.AccountView:RefreshPage(true)
    end)
    toolbar.buildToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(parent.buildsBuildCollapsed and Addon:T("UI.EXPAND_TALENTS_AND_GLYPHS") or Addon:T("UI.COLLAPSE_TALENTS_AND_GLYPHS"))
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
        if not selected or not IsCurrent(selected) then Addon:Print(Addon:T("UI.CONFIRM_EQUIPMENT_ON_THE_LOGGED_IN_CHARACTER")) return end
        local record = Addon.Snapshot:GetCharacter(selected.id)
        local slot = parent.buildsSlot or (record and record.lastActiveSlot) or "primary"
        if not record or record.lastActiveSlot ~= slot then return end
        local slotData = record.slots and record.slots[slot]
        local equipmentStatus = Addon.Snapshot:GetEquipmentStatus(slotData)
        if equipmentStatus == "missing" or equipmentStatus == "saved" then return end
        local existing = slotData and slotData.confirmedEquipment
        if equipmentStatus == "changed" and existing and StaticPopup_Show then
            StaticPopupDialogs.YIBO_BUILDS_CONFIRM_OVERWRITE = StaticPopupDialogs.YIBO_BUILDS_CONFIRM_OVERWRITE or {
                text = Addon:T("UI.REPLACE_THE_CONFIRMED_EQUIPMENT_FOR_THIS_TALENT_SLOT"), button1 = ACCEPT, button2 = CANCEL, timeout = 0, whileDead = true, hideOnEscape = true,
                OnAccept = function()
                    local ok, err = Addon.Snapshot:ConfirmEquipment(slot)
                    if not ok then Addon:Print(err) end
                end,
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
    local equipmentWidth = collapsed and FoldedEquipmentWidth() or math.floor((mainWidth - Theme.Space.sm * 3) * 0.55)
    parent.buildsConfirm:ClearAllPoints(); parent.buildsConfirm:SetPoint("BOTTOMLEFT", parent.buildsMain, "BOTTOMLEFT", Theme.Space.sm, Theme.Space.sm); parent.buildsConfirm:SetPoint("BOTTOMRIGHT", parent.buildsMain, "BOTTOMRIGHT", -Theme.Space.sm, Theme.Space.sm); parent.buildsConfirm:SetHeight(48)
    parent.buildsEquipment:ClearAllPoints(); parent.buildsEquipment:SetPoint("TOPLEFT", parent.buildsToolbar, "BOTTOMLEFT", 0, -Theme.Space.sm); parent.buildsEquipment:SetPoint("BOTTOMLEFT", parent.buildsConfirm, "TOPLEFT", 0, Theme.Space.sm)
    if collapsed then
        parent.buildsEquipment:SetWidth(equipmentWidth)
        parent.buildsEquipment.layoutWidth = equipmentWidth
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
    -- Anchor the control to the equipment pane so it remains usable after the
    -- account window contracts to the folded layout width.
    parent.buildsToolbar.buildToggle:SetPoint("BOTTOMRIGHT", parent.buildsEquipment, "BOTTOMRIGHT", -8, 8)
end

function Page.Refresh(parent, context)
    Page._activeParent = parent
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
        row.name:SetText(CharacterLabel(character, context)); local color = ClassColor(character); row.name:SetTextColor(color.r, color.g, color.b)
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
    local detailIdentity = tostring(selected.id) .. ":" .. slot
    if parent.buildsDetailIdentity ~= detailIdentity then
        if parent.buildsPendingGem then ClearPendingGem(parent, true) end
        parent.buildsSelectedEquipmentSlot = nil
        parent.buildsEquipment.detail:Hide()
        parent.buildsDetailIdentity = detailIdentity
    end
    parent.buildsActiveSlot = record.lastActiveSlot
    local slotData = record.slots and record.slots[slot]
    -- The active character's observation is the live source of truth for
    -- sockets and profession bases.  A confirmed build remains the comparison
    -- target, but must not conceal freshly scanned empty sockets.
    local equipment = slotData and (IsCurrent(selected) and (slotData.observedEquipment or slotData.confirmedEquipment) or (slotData.confirmedEquipment or slotData.observedEquipment))
    parent.buildsEquipmentIsObserved = IsCurrent(selected) and slot == record.lastActiveSlot
        and equipment ~= nil and equipment == slotData.observedEquipment
    parent.buildsToolbar.primary:SetState(slot == "primary" and "selected" or "default")
    parent.buildsToolbar.secondary:SetState(slot == "secondary" and "selected" or (record.slots and record.slots.secondary and "default" or "disabled"))
    local spec = slotData and slotData.specialization
    parent.buildsToolbar.specIcon.texture:SetTexture(spec and spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local itemLevel = equipment and tonumber(equipment.itemLevel)
    parent.buildsToolbar.specName:SetText((SnapshotName(spec, "spec")) .. (itemLevel and (" " .. tostring(math.floor(itemLevel + 0.5))) or ""))
    parent.buildsToolbar.specIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(SnapshotName(spec, "spec"))
        GameTooltip:Show()
    end)
    parent.buildsToolbar.specIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local mode = Addon:GetSettings().appearanceMode
    parent.buildsToolbar.appearance:SetText(not IsCurrent(selected) and Addon:T("UI.ORIGINAL_TRANSMOG") or (mode == "transmog" and Addon:T("UI.ORIGINAL_CFF20E070TRANSMOG_R") or Addon:T("UI.CFF20E070ORIGINAL_R_TRANSMOG")))
    parent.buildsToolbar.appearance:SetState(IsCurrent(selected) and "default" or "disabled")
    parent.buildsToolbar.buildToggle:SetText(parent.buildsBuildCollapsed and ">>" or "<<")
    parent.buildsToolbar.buildToggle:SetState("default")
    local equipmentStatus = Addon.Snapshot:GetEquipmentStatus(slotData)
    local equipmentStatusText = ({
        missing = Addon:T("UI.NO_EQUIPMENT_SNAPSHOT"), unsaved = Addon:T("UI.EQUIPMENT_AWAITING_AUTOMATIC_SAVE"), changed = Addon:T("UI.EQUIPMENT_CHANGED_AWAITING_AUTOMATIC_SAVE"), saved = Addon:T("UI.EQUIPMENT_SAVED"),
    })[equipmentStatus] or Addon:T("UI.NO_EQUIPMENT_SNAPSHOT")
    parent.buildsToolbar.status:SetText((record.lastActiveSlot == slot and Addon:T("UI.ACTIVE") or Addon:T("UI.BACKUP_BUILD")) .. " · " .. equipmentStatusText)
    PlaceEquipment(parent, equipment)
    parent.buildsEquipmentSnapshot = equipment
    RenderEquipmentDetail(parent, equipment)
    parent.buildsEquipment.empty:SetText(not equipment and Addon:T("UI.NO_EQUIPMENT_SNAPSHOT_2") or (not IsCurrent(selected) and Addon:T("UI.APPEARANCE_PREVIEW_IS_AVAILABLE_ONLY_FOR_THE_CURRENT_CHARACTER") or ""))
    parent.buildsEquipment.empty:SetShown(not equipment or not IsCurrent(selected))
    RefreshModel(parent, selected, equipment)
    RenderBuildColumns(parent, slotData, record)
    local catalogOpen = parent.buildsGlyphCatalogOpen == true
    local detailOpen = parent.buildsEquipment.detail:IsShown()
    parent.buildsBuild.catalog:SetShown(catalogOpen and not detailOpen)
    parent.buildsBuild.catalogMajor:SetShown(catalogOpen and not detailOpen)
    parent.buildsBuild.catalogMinor:SetShown(catalogOpen and not detailOpen)
    for _, row in ipairs(parent.buildsBuild.talents) do row:SetShown(not detailOpen) end
    for _, row in ipairs(parent.buildsBuild.glyphs) do row:SetShown(not catalogOpen and not detailOpen) end
    parent.buildsBuild.talentTitle:SetShown(not detailOpen)
    parent.buildsBuild.glyphTitle:SetShown(not detailOpen)
    parent.buildsBuild.majorGlyphTitle:Hide()
    parent.buildsBuild.minorGlyphTitle:Hide()
    parent.buildsBuild.currentGlyphs:SetState(catalogOpen and "default" or "selected")
    parent.buildsBuild.allGlyphs:SetState(catalogOpen and "selected" or "default")
    parent.buildsBuild.currentGlyphs:SetShown(not detailOpen)
    parent.buildsBuild.allGlyphs:SetShown(not detailOpen)
    local canSave = IsCurrent(selected) and record.lastActiveSlot == slot and (equipmentStatus == "unsaved" or equipmentStatus == "changed")
    parent.buildsConfirm:SetState(canSave and "selected" or "disabled")
    parent.buildsConfirm:SetText(({
        missing = Addon:T("UI.NO_EQUIPMENT_SNAPSHOT"),
        unsaved = Addon:T("UI.SAVE_BUILD_EQUIPMENT_NOW"),
        changed = Addon:T("UI.UPDATE_BUILD_EQUIPMENT_NOW"),
        saved = Addon:T("UI.BUILD_EQUIPMENT_SAVED"),
    })[equipmentStatus] or Addon:T("UI.NO_EQUIPMENT_SNAPSHOT"))
    parent.buildsConfirm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local title = ({
            missing = Addon:T("UI.CURRENT_EQUIPMENT_HAS_NOT_BEEN_CAPTURED_YET"),
            unsaved = Addon:T("UI.EQUIPMENT_SAVES_ON_LOGOUT_RELOAD_OR_EXIT_CLICK_TO_SAVE_NOW"),
            changed = Addon:T("UI.EQUIPMENT_UPDATES_ON_LOGOUT_RELOAD_OR_EXIT_CLICK_TO_UPDATE_NOW"),
            saved = Addon:T("UI.CURRENT_EQUIPMENT_MATCHES_THE_SAVED_BUILD"),
        })[equipmentStatus] or ""
        GameTooltip:AddLine(title)
        GameTooltip:Show()
    end)
    parent.buildsConfirm:SetScript("OnLeave", function() GameTooltip:Hide() end)
    SetupMainButtons(parent)
end

function Page:RefreshOpenDetail()
    local parent = self._activeParent
    if parent and parent:IsShown() and parent.buildsEquipment and parent.buildsEquipment.detail
        and parent.buildsEquipment.detail:IsShown() then
        RenderEquipmentDetail(parent, parent.buildsEquipmentSnapshot)
    end
end

function Page:OnSocketEvent(event)
    local parent = self._activeParent
    if not (parent and parent.buildsPendingGem) then return end
    if event == "SOCKET_INFO_FAILURE" then Addon:Print(Addon:T("UI.SOCKETING_FAILED_SELECT_THE_GEM_AGAIN")) end
    ClearPendingGem(parent, event ~= "SOCKET_INFO_CLOSE")
    self:RefreshOpenDetail()
end

function Page.RefreshPreview(parent, context)
    parent.buildsEmpty:Hide(); parent.buildsRoster:Hide(); parent.buildsMain:Hide()
    -- The account projection is activity-relative: “当前” means each role's
    -- own last-used specialization, while “备用” is its other slot.
    local settings = Addon:GetSettings()
    local matrixMode = settings.previewMatrixMode == "spec" and "spec" or "equipment"
    local mode = (matrixMode == "equipment" and settings.previewEquipmentMode or settings.previewSpecMode) == "backup" and "backup" or "current"
    if matrixMode == "equipment" then settings.previewEquipmentMode = mode else settings.previewSpecMode = mode end
    local characters = PreviewCharacters(context)
    local columns = PreviewColumns(context, characters, matrixMode, mode)
    parent.buildsPreviewToggle = parent.buildsPreviewToggle or CreateFrame("Frame", nil, parent)
    local buttons = parent.buildsPreviewToggle.buttons or {}
    local buttonDefinitions = {
        { id = "currentEquipment", label = Addon:T("UI.CURRENT_EQUIPMENT"), matrix = "equipment", mode = "current" },
        { id = "backupEquipment", label = Addon:T("UI.BACKUP_EQUIPMENT"), matrix = "equipment", mode = "backup" },
        { id = "currentSpec", label = Addon:T("UI.CURRENT_SPECIALIZATION"), matrix = "spec", mode = "current" },
        { id = "backupSpec", label = Addon:T("UI.BACKUP_SPECIALIZATION"), matrix = "spec", mode = "backup" },
    }
    parent.buildsPreviewToggle:SetSize(340, Theme.Size.compact)
    local selectedID = matrixMode == "equipment"
        and (mode == "backup" and "backupEquipment" or "currentEquipment")
        or (mode == "backup" and "backupSpec" or "currentSpec")
    for index, definition in ipairs(buttonDefinitions) do
        local button = buttons[index] or Theme:CreateButton(parent.buildsPreviewToggle, 82, "", "disclosure")
        buttons[index] = button
        button.kind = "disclosure"
        button:SetSize(82, Theme.Size.compact)
        button:ClearAllPoints()
        if index == 1 then button:SetPoint("LEFT") else button:SetPoint("LEFT", buttons[index - 1], "RIGHT", 4, 0) end
        button:SetText(definition.label)
        button:SetState(definition.id == selectedID and "selected" or "default")
        local textColor = definition.id == selectedID and C.accent or C.text
        button.label:SetTextColor(textColor[1], textColor[2], textColor[3])
        button:SetScript("OnClick", function()
            settings.previewMatrixMode = definition.matrix
            settings[definition.matrix == "equipment" and "previewEquipmentMode" or "previewSpecMode"] = definition.mode
            Addon:NotifyChanged()
            Page.RefreshPreview(parent, context)
        end)
        button:Show()
    end
    parent.buildsPreviewToggle.buttons = buttons
    if parent.buildsPreviewToggle.specButton then parent.buildsPreviewToggle.specButton:Hide() end
    if parent.buildsPreviewToggle.equipmentButton then parent.buildsPreviewToggle.equipmentButton:Hide() end
    if context and context.SetTitleBarControl then context:SetTitleBarControl(parent.buildsPreviewToggle, 340) else parent.buildsPreviewToggle:Hide() end
    parent.buildsPreviewHeader = parent.buildsPreviewHeader or CreateFrame("Frame", nil, parent)
    parent.buildsPreviewBody = parent.buildsPreviewBody or CreateFrame("Frame", nil, parent)
    local inset = Theme:GetMatrixInsets(true)
    parent.buildsPreviewHeader:ClearAllPoints(); parent.buildsPreviewHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    local width, x = 0, 0
    parent.buildsPreviewHeaders = parent.buildsPreviewHeaders or {}
    for index, col in ipairs(columns) do
        local header = parent.buildsPreviewHeaders[index] or Theme:CreateMatrixHeader(parent.buildsPreviewHeader); parent.buildsPreviewHeaders[index] = header
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", parent.buildsPreviewHeader, "TOPLEFT", x, 0); header:SetSize(col.width, Theme.Table.headerHeight); Theme:SetMatrixHeader(header, col.title, { height = Theme.Table.headerHeight, inset = 2 }); header:Show(); x = x + col.width + (col.gapAfter or 0)
    end
    for index = #columns + 1, #parent.buildsPreviewHeaders do parent.buildsPreviewHeaders[index]:Hide() end
    width = x; parent.buildsPreviewHeader:SetSize(width, Theme.Table.headerHeight)
    parent.buildsPreviewRows = parent.buildsPreviewRows or {}
    for ri, character in ipairs(characters) do
        local record = Addon.Snapshot:GetCharacter(character.id); local slotData = Addon.Snapshot:GetProjectedSlot(record, mode)
        local row = parent.buildsPreviewRows[ri] or CreateFrame("Button", nil, parent.buildsPreviewBody, "BackdropTemplate"); parent.buildsPreviewRows[ri] = row
        local rowHeight = PreviewRowHeight(matrixMode)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent.buildsPreviewBody, "TOPLEFT", 0, -((ri - 1) * rowHeight)); row:SetSize(width, rowHeight); row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); local fill = Theme:GetDataRowColor(ri); row:SetBackdropColor(fill[1], fill[2], fill[3], fill[4]); row.cells = row.cells or {}
        x = 0
        for ci, col in ipairs(columns) do
            local cell = row.cells[ci] or CreatePreviewCell(row); row.cells[ci] = cell
            cell:ClearAllPoints()
            if col.slotID then
                cell:SetPoint("LEFT", x, 0); cell:SetSize(col.width, rowHeight)
            else
                cell:SetPoint("LEFT", x + 3, 0); cell:SetSize(col.width - 6, rowHeight)
            end
            cell.text:Show(); cell.itemFrame:Hide(); cell.itemLevel:Hide(); cell.itemChanged:Hide()
            local value = "—"
            if col.id == "name" then value = PreviewCharacterLabel(character, context, slotData)
            elseif col.id == "slot" then value = slotData and (slot == "secondary" and Addon:T("UI.SECONDARY_SPECIALIZATION") or Addon:T("UI.PRIMARY_SPECIALIZATION")) or (mode == "backup" and Addon:T("UI.NO_BACKUP_SPECIALIZATION_SNAPSHOT") or Addon:T("UI.NO_CURRENT_SPECIALIZATION_SNAPSHOT"))
            elseif col.id == "spec" then
                local item = slotData and slotData.specialization
                value = item and IconText(item.icon, SnapshotName(item)) or "—"
                SetPreviewCellTooltip(cell, nil)
            elseif string.find(col.id, "talent") then
                local n = tonumber(string.match(col.id, "%d+")); local item = slotData and slotData.talents and slotData.talents[n]
                value = item and IconText(item.icon, SnapshotName(item)) or "—"; SetPreviewCellTooltip(cell, item)
            elseif string.find(col.id, "major") then
                local n = tonumber(string.match(col.id, "%d+")); local item = slotData and slotData.glyphs and slotData.glyphs.major[n]
                value = item and IconText(item.icon, SnapshotName(item)) or "—"; SetPreviewCellTooltip(cell, item)
            elseif string.find(col.id, "minor") then
                local n = tonumber(string.match(col.id, "%d+")); local item = slotData and slotData.glyphs and slotData.glyphs.minor[n]
                value = item and IconText(item.icon, SnapshotName(item)) or "—"; SetPreviewCellTooltip(cell, item)
            elseif matrixMode == "equipment" and col.slotID then
                -- Login and equipment events refresh the observation first;
                -- confirmation is a separate user action or logout boundary.
                -- Show the latest known equipment while a build is still
                -- pending confirmation instead of rendering every slot empty.
                local equipment = slotData and (slotData.observedEquipment or slotData.confirmedEquipment)
                local item = equipment and equipment.slots and equipment.slots[tostring(col.slotID)]
                if item and item.icon then
                    cell.text:Hide(); cell.itemFrame:Show(); cell.itemLevel:Show()
                    local equipmentChanged = Addon.Snapshot:GetEquipmentStatus(slotData) == "changed"
                    cell.itemChanged:SetShown(equipmentChanged)
                    cell.itemIcon:SetTexture(item.icon)
                    cell.itemIcon:SetDesaturated(false)
                    cell.itemIcon:SetVertexColor(1, 1, 1, 1)
                    cell.itemFrame:SetBackdropBorderColor(ItemBorderColor(item))
                    local itemLevel = GetPreviewItemLevel(item)
                    cell.itemLevel:SetText(itemLevel and tostring(itemLevel) or "")
                    cell.itemLevel:SetTextColor(C.text[1], C.text[2], C.text[3])
                    value = ""
                    SetPreviewItemTooltip(cell, item)
                else
                    cell.text:Hide(); cell.itemFrame:Show(); cell.itemLevel:Show()
                    cell.itemChanged:Hide()
                    cell.itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    cell.itemIcon:SetDesaturated(true)
                    cell.itemIcon:SetVertexColor(0.45, 0.5, 0.5, 0.65)
                    cell.itemFrame:SetBackdropBorderColor(C.muted[1], C.muted[2], C.muted[3], 1)
                    cell.itemLevel:SetText("")
                    cell.itemLevel:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
                    value = ""
                    SetPreviewItemTooltip(cell, nil)
                end
            elseif col.id == "equipment" then
                value = slotData and slotData.confirmedEquipment and Addon:T("UI.CONFIRMED") or slotData and slotData.observedEquipment and Addon:T("UI.PENDING_CONFIRMATION") or "—"
                SetPreviewEquipmentTooltip(cell, slotData and (slotData.confirmedEquipment or slotData.observedEquipment), slotData and slotData.confirmedEquipment ~= nil)
            end
            if matrixMode ~= "equipment" and col.id ~= "equipment" and col.id ~= "spec" and not string.find(col.id, "talent") and not string.find(col.id, "major") and not string.find(col.id, "minor") then SetPreviewCellTooltip(cell, nil) end
            cell.text:SetTextColor(C.text[1], C.text[2], C.text[3])
            if col.id == "name" then
                local color = ClassColor(character)
                cell.text:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
            end
            if matrixMode == "equipment" and col.slotID then
                local equipmentStatus = Addon.Snapshot:GetEquipmentStatus(slotData)
                if not slotData or not slotData.confirmedEquipment then
                    cell.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
                elseif equipmentStatus == "changed" then
                    cell.text:SetTextColor(C.warning[1], C.warning[2], C.warning[3])
                end
            end
            cell.text:SetText(value); cell:Show(); x = x + col.width + (col.gapAfter or 0)
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
        for ci = #columns + 1, #row.cells do row.cells[ci]:Hide() end
    end
    for i = #characters + 1, #parent.buildsPreviewRows do parent.buildsPreviewRows[i]:Hide() end
    parent.buildsPreviewBody:ClearAllPoints(); parent.buildsPreviewBody:SetPoint("TOPLEFT", parent.buildsPreviewHeader, "BOTTOMLEFT", 0, 0); parent.buildsPreviewBody:SetSize(width, math.max(1, #characters * PreviewRowHeight(matrixMode))); parent.buildsPreviewBody:Show(); parent.buildsPreviewHeader:Show()
end

local function FoldedContentWidth()
    local inset = Theme:GetMatrixInsets(false)
    local rosterWidth = 210
    local equipmentWidth = FoldedEquipmentWidth()
    -- The folded main panel fits the fixed-width equipment pane and gutters.
    return inset.left + rosterWidth + Theme.Space.sm + equipmentWidth + Theme.Space.sm * 2 + inset.right
end

function Page.GetSurfaceMetrics(context)
    local inset = Theme:GetMatrixInsets(context and context.preview)
    if context and context.preview then
        local characters = PreviewCharacters(context)
        local settings = Addon:GetSettings()
        local matrixMode = settings.previewMatrixMode == "spec" and "spec" or "equipment"
        local mode = (matrixMode == "equipment" and settings.previewEquipmentMode or settings.previewSpecMode) == "backup" and "backup" or "current"
        local columns = PreviewColumns(context, characters, matrixMode, mode)
        local width = inset.left + inset.right
        for _, column in ipairs(columns) do width = width + column.width end
        local height = inset.top + Theme.Table.headerHeight + math.max(1, #characters) * PreviewRowHeight(matrixMode) + inset.bottom
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
