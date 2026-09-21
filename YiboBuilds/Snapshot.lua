local Addon = _G.YiboBuilds
local Snapshot = {}
Addon.Snapshot = Snapshot

local SLOT_IDS = {
    INVSLOT_HEAD or 1, INVSLOT_NECK or 2, INVSLOT_SHOULDER or 3, INVSLOT_SHIRT or 4,
    INVSLOT_CHEST or 5, INVSLOT_WAIST or 6, INVSLOT_LEGS or 7, INVSLOT_FEET or 8,
    INVSLOT_WRIST or 9, INVSLOT_HAND or 10, INVSLOT_FINGER1 or 11, INVSLOT_FINGER2 or 12,
    INVSLOT_TRINKET1 or 13, INVSLOT_TRINKET2 or 14, INVSLOT_BACK or 15,
    INVSLOT_MAINHAND or 16, INVSLOT_OFFHAND or 17, INVSLOT_RANGED or 18, INVSLOT_TABARD or 19,
}

local function SlotKey(slotID) return tostring(slotID) end
local function ActiveGroup()
    local fn = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup or GetActiveSpecGroup
    local ok, value
    if fn then ok, value = pcall(fn, false) end
    value = ok and tonumber(value) or 1
    return value == 2 and "secondary" or "primary"
end

local function SlotForGroup(group)
    return group == 2 and "secondary" or "primary"
end

local function GroupForSlot(slot)
    return slot == "secondary" and 2 or 1
end

local function ItemIDFromLink(link)
    return link and tonumber(string.match(link, "item:(%d+)")) or nil
end

local function SpellInfoSafe(spellID)
    if not spellID then return nil, nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info then return info.name, info.iconID end
    end
    if type(GetSpellInfo) == "function" then
        local ok, name, _, icon = pcall(GetSpellInfo, spellID)
        if ok then return name, icon end
    end
    return nil, nil
end

local glyphRequirementTooltip, glyphRequirementCache
local function GlyphSpecializationRequirement(glyphID, glyphLink, spellID)
    if not glyphID or glyphID <= 0 then return "通用" end
    glyphRequirementCache = glyphRequirementCache or {}
    if glyphRequirementCache[glyphID] then return glyphRequirementCache[glyphID] end

    local names = {}
    local getCount = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations or GetNumSpecializations
    local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    local ok, count = false, nil
    if getCount then ok, count = pcall(getCount, false) end
    for index = 1, (ok and tonumber(count) or 0) do
        local valid, _, name = false, nil, nil
        if getInfo then valid, _, name = pcall(getInfo, index) end
        if valid and type(name) == "string" and name ~= "" then names[#names + 1] = name end
    end
    if #names == 0 or not CreateFrame then return "通用" end
    if not glyphRequirementTooltip then
        glyphRequirementTooltip = CreateFrame("GameTooltip", "YiboBuildsGlyphRequirementTooltip", UIParent, "GameTooltipTemplate")
    end
    glyphRequirementTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    glyphRequirementTooltip:ClearLines()
    local shown = glyphRequirementTooltip.SetGlyphByID and pcall(glyphRequirementTooltip.SetGlyphByID, glyphRequirementTooltip, glyphID)
    if not shown and glyphLink then shown = pcall(glyphRequirementTooltip.SetHyperlink, glyphRequirementTooltip, glyphLink) end
    if not shown and spellID and glyphRequirementTooltip.SetSpellByID then
        shown = pcall(glyphRequirementTooltip.SetSpellByID, glyphRequirementTooltip, spellID)
    end
    local requirement = "通用"
    if shown then
        for lineIndex = 1, glyphRequirementTooltip:NumLines() do
            local line = _G["YiboBuildsGlyphRequirementTooltipTextLeft" .. lineIndex]
            local value = line and line:GetText()
            if value then
                for _, name in ipairs(names) do
                    if string.find(value, name, 1, true) then requirement = name; break end
                end
            end
            if requirement ~= "通用" then break end
        end
    end
    glyphRequirementTooltip:Hide()
    glyphRequirementCache[glyphID] = requirement
    return requirement
end

local function ReadTalents(group)
    local talents = {}
    local ready = false
    for tier = 1, 6 do
        local selected
        for column = 1, 3 do
            local info
            if C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo then
                local ok, value = pcall(C_SpecializationInfo.GetTalentInfo, { tier = tier, column = column, groupIndex = group, isInspect = false, target = "player" })
                if ok then info = value end
            end
            if not info and type(GetTalentInfo) == "function" then
                local ok, talentID, name, icon, chosen, _, spellID = pcall(GetTalentInfo, tier, column, group, false, "player")
                if ok and name then info = { talentID = talentID, name = name, icon = icon, selected = chosen, spellID = spellID } end
            end
            if info and info.name then ready = true end
            if info and info.selected then
                selected = { talentID = info.talentID or 0, spellID = info.spellID or 0, name = info.name or "未知天赋", icon = info.icon }
                break
            end
        end
        talents[tier] = selected or { name = "未选择", icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
    end
    talents.ready = ready
    return talents
end

local function ReadGlyphs(group)
    local major, minor = {}, {}
    local majorType, minorType = GLYPH_TYPE_MAJOR or 1, GLYPH_TYPE_MINOR or 2
    local slotTypes = { majorType, minorType, minorType, majorType, minorType, majorType }
    local readySlots, selectedCount = 0, 0
    -- GetNumGlyphSockets can briefly return zero while the glyph cache loads.
    -- MoP has six fixed sockets; keep probing all of them.
    for index = 1, 6 do
        local ok, enabled, glyphType, _, spellID, icon, glyphID
        if type(GetGlyphSocketInfo) == "function" then
            ok, enabled, glyphType, _, spellID, icon, glyphID = pcall(GetGlyphSocketInfo, index, group)
        end
        if ok and glyphType then readySlots = readySlots + 1 end
        if glyphType ~= majorType and glyphType ~= minorType then glyphType = slotTypes[index] end
        local name, spellIcon = SpellInfoSafe(spellID)
        local link
        if glyphID and glyphID > 0 and C_GlyphInfo and C_GlyphInfo.GetGlyphInfoByID then
            local valid, glyphName, _, _, glyphIcon, glyphSpellID, glyphLink = pcall(C_GlyphInfo.GetGlyphInfoByID, glyphID)
            if valid then
                name = glyphName or name
                icon = glyphIcon or icon
                spellID = spellID or glyphSpellID
                link = glyphLink
            end
        end
        if not link and type(GetGlyphLink) == "function" then
            local valid, value = pcall(GetGlyphLink, index, group)
            if valid and type(value) == "string" and value ~= "" then link = value end
        end
        if not name and spellID then name, spellIcon = SpellInfoSafe(spellID) end
        if link then name = name or link:match("|h%[([^%]]+)%]") end
        local present = (spellID and spellID > 0) or (glyphID and glyphID > 0) or link
        if present then selectedCount = selectedCount + 1 end
        local item = {
            slot = index, glyphType = glyphType, spellID = spellID or 0, glyphID = glyphID or 0,
            glyphLink = link, name = present and (name or "未知雕文") or "未选择",
            icon = present and (icon or spellIcon or "Interface\\Icons\\INV_Misc_QuestionMark") or "Interface\\Icons\\INV_Misc_QuestionMark",
            specRequirement = present and GlyphSpecializationRequirement(glyphID, link, spellID) or nil,
        }
        if glyphType == majorType then major[#major + 1] = item else minor[#minor + 1] = item end
    end
    return { major = major, minor = minor, ready = readySlots == 6, selectedCount = selectedCount }
end

local enchantScanTooltip
local function EnchantName(slotID)
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok and tooltip and tooltip.lines then
            local enchantType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent or 15
            for _, line in ipairs(tooltip.lines) do
                if line.type == enchantType and line.leftText then
                    local value = line.leftText
                    return value:match("^附魔：%s*(.+)") or value:match("^附魔:%s*(.+)") or value:match("^Enchanted:%s*(.+)") or value
                end
            end
        end
    end
    if not CreateFrame then return nil end
    if not enchantScanTooltip then
        enchantScanTooltip = CreateFrame("GameTooltip", "YiboBuildsEnchantScanTooltip", UIParent, "GameTooltipTemplate")
    end
    enchantScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    enchantScanTooltip:ClearLines()
    enchantScanTooltip:SetInventoryItem("player", slotID)
    for index = 1, enchantScanTooltip:NumLines() do
        local line = _G["YiboBuildsEnchantScanTooltipTextLeft" .. index]
        local value = line and line:GetText()
        if value then
            local name = value:match("^附魔：%s*(.+)") or value:match("^附魔:%s*(.+)") or value:match("^Enchanted:%s*(.+)")
            if name then enchantScanTooltip:Hide(); return name end
        end
    end
    enchantScanTooltip:Hide()
    return nil
end

local function ReadSpecialization(group)
    local info = { group = group, name = group == 2 and "副天赋" or "主天赋", icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
    local api = C_SpecializationInfo
    local getSpecialization = api and api.GetSpecialization
    local getInfo = api and api.GetSpecializationInfo
    local ok, specIndex
    if getSpecialization then ok, specIndex = pcall(getSpecialization, false, false, group) end
    if (not ok or not specIndex or specIndex == 0) and type(GetSpecialization) == "function" then
        ok, specIndex = pcall(GetSpecialization, false, false, group)
        getInfo = GetSpecializationInfo or getInfo
    end
    if ok and specIndex and specIndex > 0 and getInfo then
        local valid, specID, name, _, icon = pcall(getInfo, specIndex)
        if valid and name then info.id, info.name, info.icon = specID or specIndex, name, icon or info.icon end
    end
    return info
end

local function ReadGlyphCatalog(currentGlyphs)
    local catalog, current = {}, {}
    for _, entry in ipairs((currentGlyphs and currentGlyphs.major) or {}) do if entry.glyphID and entry.glyphID > 0 then current[entry.glyphID] = true end end
    for _, entry in ipairs((currentGlyphs and currentGlyphs.minor) or {}) do if entry.glyphID and entry.glyphID > 0 then current[entry.glyphID] = true end end
    local count = (GetNumGlyphs and tonumber(GetNumGlyphs())) or 0
    for index = 1, count do
        local ok, name, glyphType, isKnown, icon, glyphID, glyphLink = pcall(GetGlyphInfo, index)
        if ok and name and name ~= "header" and glyphID then
            local spellID
            if C_GlyphInfo and C_GlyphInfo.GetGlyphInfoByID then
                local valid, _, _, _, detailIcon, detailSpellID, detailLink = pcall(C_GlyphInfo.GetGlyphInfoByID, glyphID)
                if valid then icon, spellID, glyphLink = icon or detailIcon, detailSpellID, glyphLink or detailLink end
            end
            catalog[#catalog + 1] = {
                name = name, glyphType = glyphType, isKnown = isKnown == true,
                icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark", glyphID = glyphID, spellID = spellID or 0,
                glyphLink = glyphLink, specRequirement = GlyphSpecializationRequirement(glyphID, glyphLink, spellID),
                state = current[glyphID] and "current" or (isKnown and "learned" or "unlearned"),
            }
        end
    end
    return catalog
end

local function SelectedGlyphCount(glyphs)
    if not glyphs then return 0 end
    if glyphs.selectedCount then return glyphs.selectedCount end
    local count = 0
    for _, entries in ipairs({ glyphs.major or {}, glyphs.minor or {} }) do
        for _, entry in ipairs(entries) do
            if (entry.spellID and entry.spellID > 0) or (entry.glyphID and entry.glyphID > 0) then count = count + 1 end
        end
    end
    return count
end

local function ReadEquipment(reason)
    local equipment = { capturedAt = Addon:Now(), reason = reason, slots = {} }
    if GetAverageItemLevel then
        local baseLevel, equippedLevel = GetAverageItemLevel()
        local level = tonumber(equippedLevel) or tonumber(baseLevel)
        if level and level > 0 then equipment.itemLevel = math.floor(level + 0.5) end
    end
    for _, slotID in ipairs(SLOT_IDS) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slotID)
        local itemLevel
        if link and GetDetailedItemLevelInfo then
            local ok, value = pcall(GetDetailedItemLevelInfo, link)
            if ok then itemLevel = tonumber(value) end
        end
        local entry = { itemLink = link, itemID = ItemIDFromLink(link), itemLevel = itemLevel, icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slotID), gems = {}, enchant = {} }
        if link and GetItemGem then
            for gemIndex = 1, 3 do
                local _, gemLink = GetItemGem(link, gemIndex)
                if gemLink then entry.gems[#entry.gems + 1] = { itemLink = gemLink, itemID = ItemIDFromLink(gemLink), icon = GetItemIcon and GetItemIcon(gemLink) } end
            end
        end
        local enchantID = tonumber(string.match(link or "", "item:%d+:(%d+)")) or 0
        entry.enchant = { enchantID = enchantID, name = enchantID > 0 and EnchantName(slotID) or nil }
        equipment.slots[SlotKey(slotID)] = entry
    end
    return equipment
end

local function EquipmentEntrySignature(item)
    local parts = {
        item and item.itemLink or "",
        tostring(item and item.enchant and item.enchant.enchantID or 0),
    }
    for index = 1, 3 do
        local gem = item and item.gems and item.gems[index]
        parts[#parts + 1] = gem and (gem.itemLink or tostring(gem.itemID or "")) or ""
    end
    return table.concat(parts, "\031")
end

local function SameEquipment(first, second)
    if not (first and second and first.slots and second.slots) then return false end
    for _, slotID in ipairs(SLOT_IDS) do
        local key = SlotKey(slotID)
        if EquipmentEntrySignature(first.slots[key]) ~= EquipmentEntrySignature(second.slots[key]) then return false end
    end
    return true
end

local function CurrentCharacter()
    return Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
end

function Snapshot:GetCharacter(characterID)
    return Addon:EnsureDB().characters[characterID]
end

function Snapshot:EnsureCharacter(character)
    local db = Addon:EnsureDB()
    local record = db.characters[character.id]
    if not record then
        record = { identity = {}, slots = { primary = {}, secondary = nil } }
        db.characters[character.id] = record
    end
    record.identity = { name = character.name, realm = character.realm, classFile = character.class }
    record.slots = record.slots or { primary = {}, secondary = nil }
    return record
end

function Snapshot:CaptureSlot(record, slot, reason, includeEquipment)
    local group = GroupForSlot(slot)
    local data = record.slots[slot] or {}
    local specialization = ReadSpecialization(group)
    if specialization.id or not data.specialization then data.specialization = specialization end
    local talents = ReadTalents(group)
    if talents.ready or not data.talents then data.talents = talents end
    local glyphs = ReadGlyphs(group)
    if glyphs.ready or not data.glyphs or glyphs.selectedCount > SelectedGlyphCount(data.glyphs) then
        data.glyphs = glyphs
    end
    if slot == (record.lastActiveSlot or slot) then record.glyphCatalog = ReadGlyphCatalog(data.glyphs) end
    data.updatedAt = Addon:Now()
    if includeEquipment then
        data.observedEquipment = ReadEquipment(reason)
        -- Enrich older confirmations when the item and its enchant still match.
        for key, confirmed in pairs((data.confirmedEquipment and data.confirmedEquipment.slots) or {}) do
            local observed = data.observedEquipment.slots[key]
            if confirmed.itemLink and observed and confirmed.itemLink == observed.itemLink
                and confirmed.enchant and observed.enchant
                and confirmed.enchant.enchantID == observed.enchant.enchantID
                and not confirmed.enchant.name then
                confirmed.enchant.name = observed.enchant.name
            end
        end
    end
    record.slots[slot] = data
    return data
end

function Snapshot:Capture(reason, logout)
    local character = CurrentCharacter()
    if not character then return nil end
    local record = self:EnsureCharacter(character)
    local active = ActiveGroup()
    record.lastActiveSlot = active
    self:CaptureSlot(record, active, reason, true)
    local groups = active == "secondary" and 2 or 1
    if type(GetNumSpecGroups) == "function" then
        local ok, count = pcall(GetNumSpecGroups, false)
        if ok then groups = math.max(groups, tonumber(count) or 1) end
    end
    if groups >= 2 then
        record.slots.secondary = record.slots.secondary or {}
        -- Both groups expose their specialization, talents, and glyphs.
        -- Physical equipment belongs only to the group currently in use.
        local inactive = active == "primary" and "secondary" or "primary"
        self:CaptureSlot(record, inactive, reason, false)
    end
    self.lastActiveSlot = active
    self.equipmentDirty = false
    if not logout then Addon:NotifyChanged() end
    return record
end

function Snapshot:ScheduleCapture(reason, delay)
    self.captureToken = (self.captureToken or 0) + 1
    local token = self.captureToken
    local Run = function()
        if token == self.captureToken then self:Capture(reason) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(delay or 0, Run) else Run() end
end

function Snapshot:HandleSpecChanged()
    self:ScheduleCapture("post-spec-change", 0.25)
end

function Snapshot:MarkEquipmentDirty()
    self.equipmentDirty = true
end

function Snapshot:GetEquipmentStatus(slotData)
    if not slotData then return "missing" end
    local observed, confirmed = slotData.observedEquipment, slotData.confirmedEquipment
    if not confirmed then return observed and "unsaved" or "missing" end
    if observed and not SameEquipment(observed, confirmed) then return "changed" end
    return "saved"
end

function Snapshot:ConfirmEquipment(slot)
    local character = CurrentCharacter()
    if not character then return nil, "当前角色不可用。" end
    local record = self:EnsureCharacter(character)
    local active = ActiveGroup()
    if slot ~= active then return nil, "只能确认当前激活天赋槽位的当前穿戴。" end
    local data = self:CaptureSlot(record, slot, "confirm", true)
    data.confirmedEquipment = data.observedEquipment
    Addon:NotifyChanged()
    return true
end

function Snapshot:GetProjectedSlot(record, mode)
    if not record then return nil end
    -- The account matrix can explicitly compare the stable primary and
    -- secondary talent groups.  Preserve current/backup for callers that
    -- still need the activity-relative projection.
    if mode == "primary" or mode == "secondary" then
        return record.slots and record.slots[mode], mode
    end
    local active = record.lastActiveSlot or "primary"
    local slot = mode == "backup" and (active == "primary" and "secondary" or "primary") or active
    return record.slots and record.slots[slot], slot
end
