local _, NS = ...

local FakeTooltip = {
    unit = "player",
    spellID = 40192,
    lines = {},
}

function FakeTooltip:GetUnit() return "Tester", self.unit end
function FakeTooltip:GetSpell() return "Ashes of Al'ar", nil, self.spellID end
function FakeTooltip:AddLine(text, _, _, _, wrap)
    table.insert(self.lines, { text = text, wrap = wrap })
end
function FakeTooltip:Show() end

local function Expect(actual, expected, label)
    if actual ~= expected then
        error((label or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

NS.Tooltip:Apply(FakeTooltip, "player", 40192, "SetUnitBuff")
NS.Tooltip:Apply(FakeTooltip, "player", 40192, "SetUnitBuff")
Expect(#FakeTooltip.lines, 1, "same tooltip does not append duplicate source lines")
Expect(FakeTooltip.lines[1].wrap, true, "source path respects the tooltip safe width")

FakeTooltip.__yiboMountsSignature = nil
FakeTooltip.spellID = 107516
NS.Tooltip:Apply(FakeTooltip, "player", 107516, "SetUnitAura")
Expect(#FakeTooltip.lines, 3, "unavailable source appends path and availability")
Expect(FakeTooltip.lines[2].wrap, true, "every source path may wrap at the tooltip safe width")
Expect(FakeTooltip.lines[3].wrap, true, "secondary requirements may still wrap")

local MultiSourceTooltip = { unit = "player", spellID = 127170, lines = {} }
function MultiSourceTooltip:GetUnit() return "Tester", self.unit end
function MultiSourceTooltip:GetSpell() return "Astral Cloud Serpent", nil, self.spellID end
function MultiSourceTooltip:AddLine(text) table.insert(self.lines, text) end
function MultiSourceTooltip:Show() end
NS.Tooltip:Apply(MultiSourceTooltip, "player", 127170, "SetUnitAura")
NS.Tooltip:Apply(MultiSourceTooltip, "player", 127170, "SetUnitAura")
Expect(#MultiSourceTooltip.lines, 2, "two acquisition channels append two source lines without duplication")

local scannedAuras = { 40192, 98765 }
UnitBuff = function(_, index)
    local spellID = scannedAuras[index]
    if spellID then return "Aura " .. tostring(index), nil, nil, nil, nil, nil, nil, nil, nil, nil, spellID end
end
local mountAuras, auraCount = NS.Tooltip:FindMountAuras("mouseover")
Expect(auraCount, 2, "mount-aura probe counts the hovered unit buffs")
Expect(#mountAuras, 1, "mount-aura probe ignores unrelated buffs")
Expect(mountAuras[1].spellID, 40192, "mount-aura probe reports the matched spell ID")

local HoverTooltip = { unit = "mouseover", lines = {} }
function HoverTooltip:GetUnit() return "Hovered player", self.unit end
function HoverTooltip:GetSpell() return nil, nil, nil end
function HoverTooltip:AddLine(text) table.insert(self.lines, text) end
function HoverTooltip:Show() end
UnitExists = function(unit) return unit == "mouseover" end
NS.Tooltip:ApplyHoveredUnit(HoverTooltip)
NS.Tooltip:ApplyHoveredUnit(HoverTooltip)
Expect(#HoverTooltip.lines, 1, "hovered unit appends the matched mount source once")

local LinkTooltip = { lines = {}, spellID = nil }
function LinkTooltip:GetUnit() return nil, nil end
function LinkTooltip:GetSpell() return nil, nil, self.spellID end
function LinkTooltip:AddLine(text) table.insert(self.lines, text) end
function LinkTooltip:Show() end
Expect(NS.Tooltip:ExtractSpellIDFromHyperlink("|cff71d5ff|Hspell:40192|h[Ashes of Al'ar]|h|r"), 40192,
    "spell hyperlink extracts its spell ID")
Expect(NS.Tooltip:ExtractSpellIDFromHyperlink("|cff71d5ff|Hmount:40192|h[Ashes of Al'ar]|h|r"), 40192,
    "mount hyperlink extracts its spell ID")
local savedMountJournal = C_MountJournal
C_MountJournal = { GetMountInfoByID = function() return "Ashes of Al'ar", 40192 end }
Expect(NS.Tooltip:ExtractSpellIDFromHyperlink("|cff71d5ff|Hmount:77|h[Ashes of Al'ar]|h|r"), 40192,
    "mount journal hyperlink resolves its journal ID to a spell ID")
C_MountJournal = savedMountJournal
NS.Tooltip:ApplyHyperlink(LinkTooltip, "|cff71d5ff|Hspell:40192|h[Ashes of Al'ar]|h|r")
NS.Tooltip:ApplyHyperlink(LinkTooltip, "|cff71d5ff|Hspell:40192|h[Ashes of Al'ar]|h|r")
Expect(#LinkTooltip.lines, 1, "hyperlink source appends once for repeated callbacks")

LinkTooltip.__yiboMountsSignature = nil
NS.Tooltip:ApplySpellID(LinkTooltip, 40192, "SetMountBySpellID", "mount")
Expect(#LinkTooltip.lines, 2, "mount panel source can append through the spell ID path")

local savedCoreIntegration, savedMountJournal, savedUnitFactionGroup = NS.CoreIntegration, C_MountJournal, UnitFactionGroup
local savedSettings = NS:GetSettings().collectionStatus
local savedShowCollected, savedShowUncollected = savedSettings.showCollected, savedSettings.showUncollected
NS.CoreIntegration = { initialized = true, IsCollectionStatusAvailable = function() return true end }
UnitFactionGroup = function() return "Horde" end
C_MountJournal = { GetMountInfoByID = function() return "Astral Cloud Serpent", 127170, nil, nil, nil, nil, nil, nil, nil, false, true end }
local CollectionTooltip = { lines = {}, spellID = 127170 }
function CollectionTooltip:GetUnit() return nil, nil end
function CollectionTooltip:GetSpell() return nil, nil, self.spellID end
function CollectionTooltip:AddLine(text) table.insert(self.lines, text) end
function CollectionTooltip:Show() end
NS.Tooltip:ApplySpellID(CollectionTooltip, 127170, "OnTooltipSetHyperlink", "hyperlink")
Expect(#CollectionTooltip.lines, 3, "non-journal tooltip appends account collection status")
Expect(CollectionTooltip.lines[3], "Collection: Collected", "collected status uses the localized status label")

local UncollectedTooltip = { lines = {}, spellID = 127170 }
function UncollectedTooltip:GetUnit() return nil, nil end
function UncollectedTooltip:GetSpell() return nil, nil, self.spellID end
function UncollectedTooltip:AddLine(text) table.insert(self.lines, text) end
function UncollectedTooltip:Show() end
C_MountJournal.GetMountInfoByID = function() return "Astral Cloud Serpent", 127170, nil, nil, nil, nil, nil, nil, nil, nil, false end
NS.Tooltip:ApplySpellID(UncollectedTooltip, 127170, "OnTooltipSetHyperlink", "hyperlink")
Expect(#UncollectedTooltip.lines, 3, "uncollected status is shown when enabled")
Expect(UncollectedTooltip.lines[3], "Collection: Not collected", "uncollected status uses the localized status label")

local FactionTooltip = { lines = {}, spellID = 127170 }
function FactionTooltip:GetUnit() return nil, nil end
function FactionTooltip:GetSpell() return nil, nil, self.spellID end
function FactionTooltip:AddLine(text) table.insert(self.lines, text) end
function FactionTooltip:Show() end
C_MountJournal.GetMountInfoByID = function(id)
    if id == 478 then return "Astral Cloud Serpent", 999999, nil, nil, nil, nil, nil, true, "Alliance", false, false end
    return "Astral Cloud Serpent", 127170, nil, nil, nil, nil, nil, false, nil, false, true
end
C_MountJournal.GetMountIDs = function() return { 478, 479 } end
NS.Tooltip:ApplySpellID(FactionTooltip, 127170, "OnTooltipSetHyperlink", "hyperlink")
Expect(FactionTooltip.lines[3], "Collection: Collected", "collection state resolves the current faction journal entry by spell ID")

local HiddenFactionTooltip = { lines = {}, spellID = 127170 }
function HiddenFactionTooltip:GetUnit() return nil, nil end
function HiddenFactionTooltip:GetSpell() return nil, nil, self.spellID end
function HiddenFactionTooltip:AddLine(text) table.insert(self.lines, text) end
function HiddenFactionTooltip:Show() end
C_MountJournal.GetMountInfoByID = function() return "Astral Cloud Serpent", 127170, nil, nil, nil, nil, nil, true, "Alliance", true, false end
C_MountJournal.GetMountIDs = function() return { 478 } end
NS.Tooltip:ApplySpellID(HiddenFactionTooltip, 127170, "OnTooltipSetHyperlink", "hyperlink")
Expect(#HiddenFactionTooltip.lines, 2, "opposing-faction hidden entries do not report a false uncollected state")

NS:GetSettings().collectionStatus.showUncollected = false
local HiddenUncollectedTooltip = { lines = {}, spellID = 127170 }
function HiddenUncollectedTooltip:GetUnit() return nil, nil end
function HiddenUncollectedTooltip:GetSpell() return nil, nil, self.spellID end
function HiddenUncollectedTooltip:AddLine(text) table.insert(self.lines, text) end
function HiddenUncollectedTooltip:Show() end
NS.Tooltip:ApplySpellID(HiddenUncollectedTooltip, 127170, "OnTooltipSetHyperlink", "hyperlink")
Expect(#HiddenUncollectedTooltip.lines, 2, "uncollected status respects its child setting")

local SelfTooltip = { lines = {}, spellID = 127170 }
function SelfTooltip:GetUnit() return "Tester", "player" end
function SelfTooltip:GetSpell() return nil, nil, self.spellID end
function SelfTooltip:AddLine(text) table.insert(self.lines, text) end
function SelfTooltip:Show() end
NS:GetSettings().collectionStatus.showUncollected = true
NS.Tooltip:Apply(SelfTooltip, "player", 127170, "SetUnitBuff")
Expect(#SelfTooltip.lines, 2, "player self-buffs do not append account collection status")

local JournalTooltip = { lines = {}, spellID = 127170 }
function JournalTooltip:GetUnit() return nil, nil end
function JournalTooltip:GetSpell() return nil, nil, self.spellID end
function JournalTooltip:AddLine(text) table.insert(self.lines, text) end
function JournalTooltip:Show() end
NS:GetSettings().collectionStatus.showUncollected = true
NS.Tooltip:ApplySpellID(JournalTooltip, 127170, "SetMountBySpellID", "mount")
Expect(#JournalTooltip.lines, 2, "mount journal keeps its native tooltip content")
NS.Tooltip:ApplySpellID(JournalTooltip, 127170, "OnTooltipSetSpell", "spell")
Expect(#JournalTooltip.lines, 4, "mount journal callbacks retain their native source lines")
Expect(JournalTooltip.lines[3], "Drop: 魔古山宝库 > 伊拉贡", "mount journal callbacks never append collection status")

NS.CoreIntegration, C_MountJournal, UnitFactionGroup = savedCoreIntegration, savedMountJournal, savedUnitFactionGroup
savedSettings.showCollected, savedSettings.showUncollected = savedShowCollected, savedShowUncollected

LinkTooltip.__yiboMountsSignature = nil
NS.Tooltip:ApplyHyperlink(LinkTooltip, "|cff71d5ff|Hspell:999999999|h[Unknown]|h|r")
Expect(#LinkTooltip.lines, 2, "unknown hyperlinks remain silent")

FakeTooltip.__yiboMountsSignature = nil
FakeTooltip.unit = "focus"
FakeTooltip.spellID = 40192
NS.Tooltip:Apply(FakeTooltip, "focus", 40192, "SetUnitAura")
Expect(#FakeTooltip.lines, 3, "unsupported units remain untouched")
