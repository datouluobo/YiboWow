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

local function ItemIconFromLink(link)
    if not link then return nil end
    local itemID = ItemIDFromLink(link)
    if C_Item and C_Item.GetItemInfoInstant and itemID then
        local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok and icon then return icon end
    end
    if type(GetItemInfoInstant) == "function" and itemID then
        local ok, _, _, _, _, icon = pcall(GetItemInfoInstant, itemID)
        if ok and icon then return icon end
    end
    if type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemID or link)
        if ok and icon then return icon end
    end
    return nil
end

local function ItemLinkFields(link)
    local fields = link and string.match(link, "item:([^|]+)")
    if not fields then return {} end
    local values = {}
    -- Preserve empty colon fields: gem IDs are positional (gem1..gem4), and
    -- compact tokenization shifts later sockets left when an earlier one is empty.
    for value in string.gmatch(fields .. ":", "(.-):") do values[#values + 1] = value end
    return values
end

local function ItemGemLinksFromLink(link)
    local result, values = {}, ItemLinkFields(link)
    -- MoP item links use enchant followed by up to four gem fields.
    for index = 1, 4 do
        local gemID = tonumber(values[2 + index])
        if gemID and gemID > 0 then result[index] = "item:" .. tostring(gemID) end
    end
    return result
end

local function ItemNameFromLink(link)
    local itemID = ItemIDFromLink(link)
    local api = C_Item and C_Item.GetItemInfo or GetItemInfo
    if api and (itemID or link) then
        local ok, name = pcall(api, itemID or link)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return nil
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
local EMPTY_SOCKET_TEXTURES = {
    -- The ItemSocketingFrame empty-slot art is not available on every 5.0.5
    -- client.  These standard icons are always shipped and remain visibly
    -- colour-coded when a socket is empty.
    meta = "Interface\\Icons\\INV_Misc_Gem_Diamond_02",
    red = "Interface\\Icons\\INV_Misc_Gem_Ruby_01",
    yellow = "Interface\\Icons\\INV_Misc_Gem_Topaz_01",
    blue = "Interface\\Icons\\INV_Misc_Gem_Sapphire_02",
    prismatic = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
    sha = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    unknown = "Interface\\Icons\\INV_Misc_Gem_01",
}

local function SocketTypeFromTooltipLine(value)
    value = type(value) == "string" and value:lower() or ""
    if value:find("多彩插槽", 1, true) or value:find("meta socket", 1, true) then return "meta" end
    if value:find("红色插槽", 1, true) or value:find("red socket", 1, true) then return "red" end
    if value:find("黄色插槽", 1, true) or value:find("yellow socket", 1, true) then return "yellow" end
    if value:find("蓝色插槽", 1, true) or value:find("blue socket", 1, true) then return "blue" end
    if value:find("棱彩插槽", 1, true) or value:find("prismatic socket", 1, true) then return "prismatic" end
    if value:find("染煞", 1, true) or value:find("sha-touched", 1, true) or value:find("sha touched", 1, true) then return "sha" end
    -- Some client builds localize the socket label differently.  Never lose a
    -- real socket merely because its colour name is unfamiliar; only the
    -- socket-bonus line is not itself a socket.
    if (value:find("插槽", 1, true) and not value:find("插槽奖励", 1, true)) or value:find(" socket", 1, true) then return "unknown" end
    return nil
end

-- Item links retain inserted gems but do not tell us whether an empty field is
-- a genuine empty socket.  The native tooltip is authoritative for that
-- distinction, including the prismatic socket granted by a belt buckle.
local SOCKET_STAT_KEYS = {
    -- GetItemStats table keys are the constant names themselves, not the
    -- localized values of the corresponding globals.
    { key = "EMPTY_SOCKET_META", socketType = "meta" },
    { key = "EMPTY_SOCKET_RED", socketType = "red" },
    { key = "EMPTY_SOCKET_YELLOW", socketType = "yellow" },
    { key = "EMPTY_SOCKET_BLUE", socketType = "blue" },
    { key = "EMPTY_SOCKET_PRISMATIC", socketType = "prismatic" },
    { keys = { "EMPTY_SOCKET_SHA_TOUCHED", "EMPTY_SOCKET_SHA" }, socketType = "sha" },
}

local function SocketStatCount(stats, definition)
    local count = tonumber(stats[definition.key]) or 0
    for _, key in ipairs(definition.keys or {}) do
        -- The client exposes both names for the Sha-touched socket in some
        -- builds. They are aliases for one physical socket, not additive.
        count = math.max(count, tonumber(stats[key]) or 0)
    end
    return count
end

local function ReadSocketTypes(slotID, itemLink)
    local function Add(sockets, value)
        local socketType = SocketTypeFromTooltipLine(value)
        if socketType then sockets[#sockets + 1] = socketType end
    end
    local apiSockets = {}
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok and tooltip and tooltip.lines then
            for _, line in ipairs(tooltip.lines) do
                local socketLineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.GemSocket
                if socketLineType and line.type == socketLineType then
                    local socketType = SocketTypeFromTooltipLine(line.socketType)
                    if not socketType and type(line.socketType) == "string" then
                        local normalized = line.socketType:lower():gsub("[^%a]", "")
                        local known = { red = "red", yellow = "yellow", blue = "blue", meta = "meta", prismatic = "prismatic", shatouched = "sha", sha = "sha" }
                        socketType = known[normalized]
                    end
                    if socketType then apiSockets[#apiSockets + 1] = socketType
                    elseif line.gemIcon then apiSockets[#apiSockets + 1] = "unknown" end
                else
                    Add(apiSockets, line.leftText)
                    if line.rightText ~= line.leftText then Add(apiSockets, line.rightText) end
                end
            end
        end
    end
    local sockets = apiSockets
    if CreateFrame then
        if not enchantScanTooltip then
            enchantScanTooltip = CreateFrame("GameTooltip", "YiboBuildsEnchantScanTooltip", UIParent, "GameTooltipTemplate")
        end
        enchantScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        enchantScanTooltip:ClearLines()
        enchantScanTooltip:SetInventoryItem("player", slotID)
        local frameSockets = {}
        for index = 1, enchantScanTooltip:NumLines() do
            local line = _G["YiboBuildsEnchantScanTooltipTextLeft" .. index]
            Add(frameSockets, line and line:GetText())
        end
        enchantScanTooltip:Hide()
        -- TooltipInfo is incomplete for socket lines on some MoP clients. The
        -- hidden GameTooltip has the same text the player sees, so prefer the
        -- source that found more sockets.
        if #frameSockets > #sockets then sockets = frameSockets end
    end

    -- In MoP, item tooltip socket lines can omit profession-added sockets on
    -- individual slots. GetItemStats exposes the complete socket counts even
    -- when the gem itself is absent; merge only the missing counts so glove
    -- and wrist blacksmith sockets follow the same path as native sockets.
    if itemLink and type(GetItemStats) == "function" then
        local ok, stats = pcall(GetItemStats, itemLink)
        if ok and type(stats) == "table" then
            local expected = {}
            local expectedTotal = 0
            for _, definition in ipairs(SOCKET_STAT_KEYS) do
                local count = SocketStatCount(stats, definition)
                expected[definition.socketType] = count
                expectedTotal = expectedTotal + count
            end
            if expectedTotal > 0 then
                local complete, observed, shaTouchedSeen = {}, {}, false
                for _, socketType in ipairs(sockets) do
                    observed[socketType] = (observed[socketType] or 0) + 1
                    if socketType == "sha" then
                        if not shaTouchedSeen and observed[socketType] <= (expected[socketType] or 0) then
                            complete[#complete + 1] = socketType
                            shaTouchedSeen = true
                        end
                    elseif socketType ~= "unknown" and observed[socketType] <= (expected[socketType] or 0) then
                        complete[#complete + 1] = socketType
                    end
                end
                for _, definition in ipairs(SOCKET_STAT_KEYS) do
                    local missing = (expected[definition.socketType] or 0) - (observed[definition.socketType] or 0)
                    if definition.socketType == "sha" and shaTouchedSeen then missing = 0 end
                    for _ = 1, math.max(0, missing) do complete[#complete + 1] = definition.socketType end
                end
                sockets = complete
            end
        end
    end
    return sockets
end

local function HasProfessionAtLeast(requiredSkillLine, requiredLevel)
    if not GetProfessions or not GetProfessionInfo then return false end
    for _, professionIndex in ipairs({ GetProfessions() }) do
        if professionIndex then
            local _, _, skillLevel, _, _, _, skillLine = GetProfessionInfo(professionIndex)
            if tonumber(skillLine) == requiredSkillLine and (tonumber(skillLevel) or 0) >= requiredLevel then return true end
        end
    end
    return false
end

local function AugmentKindForSlot(slotID, hasRingEnchanting)
    local always = {
        [INVSLOT_SHOULDER or 3] = true, [INVSLOT_CHEST or 5] = true,
        [INVSLOT_LEGS or 7] = true, [INVSLOT_FEET or 8] = true,
        [INVSLOT_WRIST or 9] = true, [INVSLOT_HAND or 10] = true,
        [INVSLOT_BACK or 15] = true, [INVSLOT_MAINHAND or 16] = true, [INVSLOT_OFFHAND or 17] = true,
    }
    if always[slotID] then return "enchant" end
    if hasRingEnchanting and (slotID == (INVSLOT_FINGER1 or 11) or slotID == (INVSLOT_FINGER2 or 12)) then return "enchant" end
    return nil
end

-- Separate, build-specific directories are generated from the client's
-- SpellItemEnchantment/SpellEffect data. Record IDs are never Spell IDs.
local ENGINEERING_ENCHANTS = Addon.EngineeringCatalog or {}
local ENCHANT_CATALOG = Addon.EnchantCatalog or {}
local PROFESSION_ENCHANT_CATALOG = Addon.ProfessionCatalog or {}
local SOCKET_EFFECT_CATALOG = Addon.SocketEffectCatalog or {}

-- Native item tooltips may expose a tinker as its use-spell ID instead of the
-- SpellItemEnchantment ID carried by the item link. This map is detection-only.
local ENGINEERING_TOOLTIP_SPELL_IDS = {
    -- Built from the directory's trigger spell data below, not a separate
    -- hand-maintained set of character-specific IDs.
}

for enchantID, effect in pairs(ENGINEERING_ENCHANTS) do
    for _, spellID in ipairs(effect.spellIDs or {}) do
        ENGINEERING_TOOLTIP_SPELL_IDS[spellID] = enchantID
    end
end

local ENGINEERING_TEXT_HINTS = {
    [3290] = { "spring loaded cape expander" },
    [3599] = { "electromagnetic pulse generator", "emp generator" },
    [3601] = { "frag belt", "碎片腰带" },
    [3603] = { "hand-mounted pyro rocket", "手控火箭" },
    [3604] = { "hyperspeed accelerators", "超速加速器" },
    [3605] = { "flexweave underlay", "弹性织网衬底" },
    [3859] = { "springy arachnoweave" },
    [3860] = { "reticulated armor webbing" },
    [4175] = { "gnomish x-ray scope" },
    [4179] = { "synapse springs", "神经弹簧", "神经元弹簧" },
    [4180] = { "quickflip deflection plates", "快速偏转护板" },
    [4181] = { "tazik shocker", "塔兹克震撼器" },
    [4187] = { "invisibility field", "隐形力场" },
    [4188] = { "grounded plasma shield", "接地等离子护盾" },
    [4214] = { "cardboard assassin", "纸板刺客" },
    [4222] = { "mind amplification dish", "思维放大圆盘" },
    [4223] = { "nitro boosts", "氮气推进器" },
    [4697] = { "phase fingers", "相位之指" },
    [4698] = { "incendiary fireworks launcher", "炽燃烟火发射器" },
    [4699] = { "lord blastington's scope of doom", "领主爆裂顿的毁灭瞄准镜" },
    [4700] = { "mirror scope", "镜面瞄准镜" },
    [4750] = { "spinal healing injector", "脊髓治疗注射器" },
    [4897] = { "goblin glider", "地精滑翔器" },
    [4898] = { "synapse springs", "神经弹簧", "神经元弹簧" },
    [5000] = { "watergliding jets", "水上喷射器" },
}

local function TooltipLinkID(line, linkType)
    if not line then return nil end
    local direct = tonumber(line[linkType == "spell" and "spellID" or "enchantID"])
        or tonumber(line[linkType == "spell" and "spellId" or "itemEnchantmentID"])
    if direct and direct > 0 then return direct end
    local hyperlink = type(line.hyperlink) == "string" and line.hyperlink or ""
    return tonumber(hyperlink:match("|H" .. linkType .. ":(%d+)") or hyperlink:match("^" .. linkType .. ":(%d+)"))
end

local function CleanEnchantText(value)
    if type(value) ~= "string" then return nil end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", "")
end

local function EnchantNameFromText(value)
    return value and (value:match("^附魔：%s*(.+)") or value:match("^附魔:%s*(.+)")
        or value:match("^Enchanted:%s*(.+)"))
end

local function StructuredEnchantLine(tooltip, enchantID)
    if not (tooltip and tooltip.lines) then return nil end
    local enchantType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
    for _, line in ipairs(tooltip.lines) do
        local value = CleanEnchantText(line.leftText or line.rightText)
        local name = EnchantNameFromText(value)
        if value and value ~= "" and ((enchantType and line.type == enchantType)
            or TooltipLinkID(line, "enchant") == enchantID or name) then
            return { name = name or value, detailText = value }
        end
    end
    return nil
end

local function ReadEnchantLine(itemLink, slotID, enchantID)
    if itemLink and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, tooltip = pcall(C_TooltipInfo.GetHyperlink, itemLink)
        if ok then
            local info = StructuredEnchantLine(tooltip, enchantID)
            if info then return info end
        end
    end
    if slotID and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok then
            local info = StructuredEnchantLine(tooltip, enchantID)
            if info then return info end
        end
    end
    if not CreateFrame then return nil end
    if not enchantScanTooltip then
        enchantScanTooltip = CreateFrame("GameTooltip", "YiboBuildsEnchantScanTooltip", UIParent, "GameTooltipTemplate")
    end
    enchantScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    enchantScanTooltip:ClearLines()
    if itemLink then
        pcall(enchantScanTooltip.SetHyperlink, enchantScanTooltip, itemLink)
    elseif slotID then
        pcall(enchantScanTooltip.SetInventoryItem, enchantScanTooltip, "player", slotID)
    end
    local info
    for index = 1, enchantScanTooltip:NumLines() do
        local line = _G["YiboBuildsEnchantScanTooltipTextLeft" .. index]
        local value = CleanEnchantText(line and line:GetText())
        local name = EnchantNameFromText(value)
        if name then info = { name = name, detailText = value }; break end
    end
    enchantScanTooltip:Hide()
    return info
end

local function ReadEnchantInfo(slotID, enchantID, engineering, itemLink)
    if engineering or not (enchantID and enchantID > 0) then return nil end
    -- The item link carries a SpellItemEnchantment record ID. An enchant:
    -- hyperlink targets a profession spell, so use only the item's enchant
    -- line as data and never show the whole equipment tooltip to the player.
    local lineInfo = ReadEnchantLine(itemLink, slotID, enchantID)
    if lineInfo then return lineInfo end
    local infoAPI = C_Item and C_Item.GetEnchantInfo or GetEnchantInfo
    if infoAPI then
        local ok, info = pcall(infoAPI, enchantID)
        if ok and type(info) == "table" and (info.name or info.description) then
            return { name = info.name, detailText = info.description }
        end
    end
    local catalogEntry = ENCHANT_CATALOG[enchantID]
    local catalogName = catalogEntry and (catalogEntry.displayName or catalogEntry.name)
    if catalogName and catalogName:find("%$") then catalogName = nil end
    return { name = catalogName, detailText = catalogName }
end

function Snapshot:GetEnchantInfoFromLink(itemLink, enchantID)
    return ReadEnchantInfo(nil, enchantID, false, itemLink)
end

local function ReadEngineeringTooltipInfo(slotID, enchantID)
    local effect = ENGINEERING_ENCHANTS[enchantID]
    local texts, link, spellID = {}, nil, nil
    for candidateSpellID, candidateEnchantID in pairs(ENGINEERING_TOOLTIP_SPELL_IDS) do
        if candidateEnchantID == enchantID then spellID = candidateSpellID; break end
    end
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok and tooltip and tooltip.lines then
            for _, line in ipairs(tooltip.lines) do
                local text = line.leftText or line.rightText
                local lineSpellID = TooltipLinkID(line, "spell")
                local matchesSpell = lineSpellID and ENGINEERING_TOOLTIP_SPELL_IDS[lineSpellID] == enchantID
                local lowered = text and string.lower(text) or ""
                local matchesName = false
                for _, hint in ipairs(ENGINEERING_TEXT_HINTS[enchantID] or {}) do
                    if lowered:find(string.lower(hint), 1, true) then matchesName = true; break end
                end
                if text and text ~= "" and (matchesSpell or matchesName) then
                    texts[#texts + 1] = text
                    -- Prefer the enchant record over activation-spell links.
                    link = "enchant:" .. tostring(enchantID)
                    spellID = spellID or lineSpellID
                end
            end
        end
    end
    return {
        name = effect and effect.name,
        link = link or ("enchant:" .. tostring(enchantID)),
        spellID = spellID,
        detailText = #texts > 0 and table.concat(texts, "\n") or nil,
    }
end

local function ReadEngineeringEnchantID(slotID, itemFields)
    for _, field in ipairs(itemFields) do
        local candidateID = tonumber(field)
        local candidate = candidateID and ENGINEERING_ENCHANTS[candidateID]
        if candidate and candidate.slotID == slotID then return candidateID end
    end

    -- Some MoP item links omit the tinker enchant record while the equipped
    -- item's native tooltip exposes the tinker use spell. Inspect all supported
    -- tinker slots, not only cloaks.
    local supportedSlot = slotID == (INVSLOT_WAIST or 6) or slotID == (INVSLOT_BACK or 15)
        or slotID == (INVSLOT_HAND or 10) or slotID == (INVSLOT_RANGED or 18)
        or slotID == (INVSLOT_HEAD or 1)
    if not supportedSlot then return nil end
    local texts, spellIDs = {}, {}
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok and tooltip and tooltip.lines then
            for _, line in ipairs(tooltip.lines) do
                local enchantRecordID = TooltipLinkID(line, "enchant")
                local spellID = TooltipLinkID(line, "spell")
                local mapped = enchantRecordID and ENGINEERING_ENCHANTS[enchantRecordID]
                if mapped and mapped.slotID == slotID then return enchantRecordID end
                if line.leftText then texts[#texts + 1] = line.leftText end
                if line.rightText then texts[#texts + 1] = line.rightText end
                if spellID then spellIDs[#spellIDs + 1] = spellID end
            end
        end
    end
    if CreateFrame then
        if not enchantScanTooltip then
            enchantScanTooltip = CreateFrame("GameTooltip", "YiboBuildsEnchantScanTooltip", UIParent, "GameTooltipTemplate")
        end
        enchantScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        enchantScanTooltip:ClearLines()
        enchantScanTooltip:SetInventoryItem("player", slotID)
        for index = 1, enchantScanTooltip:NumLines() do
            local line = _G["YiboBuildsEnchantScanTooltipTextLeft" .. index]
            local text = line and line:GetText()
            if text then texts[#texts + 1] = text end
        end
        enchantScanTooltip:Hide()
    end
    local tooltipText = string.lower(table.concat(texts, " "))
    local compactTooltipText = tooltipText:gsub("[%s,，]", "")
    -- Some MoP clients expose the tinker use effect but omit both its name and
    -- enchant/spell ID from item links and structured tooltip lines. These
    -- effect signatures are unambiguous for the belt Nitro Boosts and the
    -- MoP-rank Synapse Springs shown in the equipped-item tooltip.
    if slotID == (INVSLOT_WAIST or 6)
        and (tooltipText:find("极大地提高你的奔跑速度", 1, true)
            or tooltipText:find("greatly increases your run speed", 1, true)) then
        return 4223
    end
    if slotID == (INVSLOT_HAND or 10)
        and compactTooltipText:find("1920", 1, true)
        and (tooltipText:find("持续10秒", 1, true) or tooltipText:find("for 10 sec", 1, true)) then
        return 4898
    end
    for _, spellID in ipairs(spellIDs) do
        local candidateID = ENGINEERING_TOOLTIP_SPELL_IDS[spellID]
        local candidate = candidateID and ENGINEERING_ENCHANTS[candidateID]
        if candidate and candidate.slotID == slotID then return candidateID end
    end
    for candidateID, candidate in pairs(ENGINEERING_ENCHANTS) do
        if candidate.slotID == slotID then
            for _, hint in ipairs(ENGINEERING_TEXT_HINTS[candidateID] or {}) do
                if tooltipText:find(string.lower(hint), 1, true) then return candidateID end
            end
        end
    end
    if tooltipText:find("地精滑翔器", 1, true) or tooltipText:find("goblin glider", 1, true)
        or (tooltipText:find("坠落速度", 1, true) and tooltipText:find("2分钟", 1, true))
        or (tooltipText:find("fall", 1, true) and tooltipText:find("2 min", 1, true) and tooltipText:find("3 min", 1, true)) then
        return 4897
    end
    if tooltipText:find("flexweave underlay", 1, true) then return 3605 end
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
    -- MoP ring enchants start at 550 Enchanting.  Belt tinkers such as Nitro
    -- Boosts start at 400 Engineering and coexist with a belt buckle.
    local hasRingEnchanting = HasProfessionAtLeast(333, 550)
    local hasBeltEngineering = HasProfessionAtLeast(202, 400)
    local hasCloakEngineering = HasProfessionAtLeast(202, 350)
    local hasGloveEngineering = HasProfessionAtLeast(202, 450)
    local hasBlacksmithSockets = HasProfessionAtLeast(164, 400)
    for _, slotID in ipairs(SLOT_IDS) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slotID)
        local itemLevel
        if link and GetDetailedItemLevelInfo then
            local ok, value = pcall(GetDetailedItemLevelInfo, link)
            if ok then itemLevel = tonumber(value) end
        end
        local entry = {
            itemLink = link, itemID = ItemIDFromLink(link), itemLevel = itemLevel,
            icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slotID), gems = {}, enchant = {},
            state = link and "equipped" or "empty",
        }
        if link then
            local socketTypes = ReadSocketTypes(slotID, link)
            local hasBeltBuckle = false
            local hasBlacksmithSocket = false
            local linkGems = ItemGemLinksFromLink(link)
            local nativeSocketCount = 0
            if slotID == (INVSLOT_WAIST or 6) and type(GetItemStats) == "function" then
                local ok, stats = pcall(GetItemStats, link)
                if ok and type(stats) == "table" then
                    for _, definition in ipairs(SOCKET_STAT_KEYS) do
                        nativeSocketCount = nativeSocketCount + SocketStatCount(stats, definition)
                    end
                end
            end
            -- An installed buckle is represented by an extra socket position in
            -- the item link. Some MoP clients expose its GemSocket line without
            -- socketType, so compare it with the item's native socket count.
            for gemIndex = 1, 4 do
                if linkGems[gemIndex] and not socketTypes[gemIndex] then
                    socketTypes[gemIndex] = gemIndex > nativeSocketCount and slotID == (INVSLOT_WAIST or 6) and "prismatic" or "unknown"
                elseif slotID == (INVSLOT_WAIST or 6) and socketTypes[gemIndex] == "unknown" and gemIndex > nativeSocketCount then
                    socketTypes[gemIndex] = "prismatic"
                end
            end
            for gemIndex, socketType in ipairs(socketTypes) do
                local gemLink
                if GetItemGem then
                    local _, observedLink = GetItemGem(link, gemIndex)
                    gemLink = observedLink
                end
                gemLink = gemLink or linkGems[gemIndex]
                local isBeltBuckle = slotID == (INVSLOT_WAIST or 6) and socketType == "prismatic"
                local blacksmithSlot = slotID == (INVSLOT_WRIST or 9) and 3717
                    or slotID == (INVSLOT_HAND or 10) and 3723
                local isBlacksmithSocket = blacksmithSlot and SOCKET_EFFECT_CATALOG[blacksmithSlot]
                    and (hasBlacksmithSockets or socketType == "prismatic") and socketType == "prismatic" or false
                hasBeltBuckle = hasBeltBuckle or isBeltBuckle
                hasBlacksmithSocket = hasBlacksmithSocket or isBlacksmithSocket
                entry.gems[gemIndex] = {
                    itemLink = gemLink, itemID = ItemIDFromLink(gemLink), itemName = ItemNameFromLink(gemLink), icon = ItemIconFromLink(gemLink),
                    socketType = socketType, emptyIcon = EMPTY_SOCKET_TEXTURES[socketType],
                    source = isBeltBuckle and "belt-buckle" or (isBlacksmithSocket and "blacksmith" or "item"),
                    sourceProfession = (isBeltBuckle or isBlacksmithSocket) and "锻造" or nil,
                    state = gemLink and "installed" or "uninstalled",
                }
            end
            if slotID == (INVSLOT_WAIST or 6) then
                entry.beltBuckle = { present = hasBeltBuckle, profession = "锻造", state = hasBeltBuckle and "uninstalled" or "base-missing" }
            end
            if hasBlacksmithSockets or hasBlacksmithSocket then
                if slotID == (INVSLOT_WRIST or 9) or slotID == (INVSLOT_HAND or 10) then
                    entry.blacksmithSockets = { present = hasBlacksmithSocket, profession = "锻造", state = hasBlacksmithSocket and "uninstalled" or "base-missing" }
                end
            end
        end
        local itemFields = ItemLinkFields(link)
        local itemEnchantID = tonumber(itemFields[2]) or 0
        local enchantID = itemEnchantID
        local engineeringSlot = slotID == (INVSLOT_HEAD or 1) or slotID == (INVSLOT_WAIST or 6)
            or slotID == (INVSLOT_BACK or 15) or slotID == (INVSLOT_HAND or 10)
            or slotID == (INVSLOT_RANGED or 18)
        -- MoP clients do not all expose tinkers in the same item-link field;
        -- scan known link IDs first, then fall back to the native item tooltip.
        local engineeringEnchantID = engineeringSlot and ReadEngineeringEnchantID(slotID, itemFields) or nil
        -- Older item-link formats place a tinker in the standard enchant field;
        -- it must not be duplicated as a normal enchant on belt or cloak.
        if engineeringEnchantID == enchantID then enchantID = 0 end
        local augmentKind = AugmentKindForSlot(slotID, hasRingEnchanting)
        local enchantInfo = augmentKind and ReadEnchantInfo(slotID, enchantID, false, link) or nil
        local enchantInstalled = enchantID > 0 or enchantInfo ~= nil
        local professionInfo = PROFESSION_ENCHANT_CATALOG[enchantID]
        entry.enchant = {
            enchantID = enchantID, name = enchantInfo and enchantInfo.name or nil,
                professionID = professionInfo and professionInfo.professionID or nil,
                profession = professionInfo and professionInfo.profession or nil,
                requiredSkill = professionInfo and professionInfo.requiredSkill or nil,
                tooltipLink = enchantInfo and enchantInfo.link or nil,
                tooltipSpellID = enchantInfo and enchantInfo.spellID or nil,
            tooltipText = enchantInfo and enchantInfo.detailText or nil,
            applicable = link and augmentKind ~= nil or false, kind = augmentKind,
            state = not link and "empty" or (augmentKind and (enchantInstalled and "installed" or "uninstalled")) or "unavailable",
        }
        local engineeringInfo = engineeringEnchantID and ReadEngineeringTooltipInfo(slotID, engineeringEnchantID) or nil
        local engineeringEligible = slotID == (INVSLOT_WAIST or 6) and hasBeltEngineering
            or slotID == (INVSLOT_BACK or 15) and hasCloakEngineering
            or slotID == (INVSLOT_HAND or 10) and hasGloveEngineering
            or slotID == (INVSLOT_RANGED or 18) and hasGloveEngineering
        if engineeringSlot then
            local effect = engineeringEnchantID and ENGINEERING_ENCHANTS[engineeringEnchantID]
            entry.engineering = {
                enchantID = engineeringEnchantID,
                name = (engineeringInfo and engineeringInfo.name) or (effect and effect.name),
                tooltipLink = engineeringInfo and engineeringInfo.link or nil,
                tooltipSpellID = engineeringInfo and engineeringInfo.spellID or nil,
                tooltipText = engineeringInfo and engineeringInfo.detailText or nil,
                state = not link and "empty" or (engineeringEnchantID and "installed") or (engineeringEligible and "base-missing" or "not-applicable"),
            }
        end
        equipment.slots[SlotKey(slotID)] = entry
    end
    return equipment
end

local function EquipmentEntrySignature(item)
    local parts = {
        item and item.itemLink or "",
        tostring(item and item.enchant and item.enchant.enchantID or 0),
        tostring(item and item.enchant and item.enchant.applicable or false),
        item and item.enchant and item.enchant.kind or "",
        item and item.enchant and item.enchant.name or "",
        tostring(item and item.enchant and item.enchant.professionID or 0),
        item and item.enchant and item.enchant.profession or "",
        tostring(item and item.enchant and item.enchant.requiredSkill or 0),
        item and item.enchant and item.enchant.tooltipLink or "",
        tostring(item and item.enchant and item.enchant.tooltipSpellID or 0),
        item and item.enchant and item.enchant.tooltipText or "",
        item and item.engineering and item.engineering.state or "",
        tostring(item and item.engineering and item.engineering.enchantID or 0),
        item and item.engineering and item.engineering.name or "",
        item and item.engineering and item.engineering.tooltipLink or "",
        tostring(item and item.engineering and item.engineering.tooltipSpellID or 0),
        item and item.engineering and item.engineering.tooltipText or "",
        item and item.beltBuckle and item.beltBuckle.state or "",
        item and item.blacksmithSockets and item.blacksmithSockets.state or "",
    }
    for index = 1, 4 do
        local gem = item and item.gems and item.gems[index]
        parts[#parts + 1] = gem and table.concat({
            gem.itemLink or tostring(gem.itemID or ""), gem.itemName or "", gem.socketType or "", gem.source or "",
        }, "\030") or ""
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

function Snapshot:ScheduleEquipmentCapture()
    self:MarkEquipmentDirty()
    self:ScheduleCapture("equipment-change", 0.05)
    local token = self.captureToken
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function()
            if token == self.captureToken then self:ScheduleCapture("equipment-change-settled", 0) end
        end)
    end
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
