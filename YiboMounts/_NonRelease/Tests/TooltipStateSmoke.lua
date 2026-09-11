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
Expect(FakeTooltip.lines[1].wrap, false, "source path keeps its natural tooltip width")

FakeTooltip.__yiboMountsSignature = nil
FakeTooltip.spellID = 60002
NS.Tooltip:Apply(FakeTooltip, "player", 60002, "SetUnitAura")
Expect(#FakeTooltip.lines, 3, "unavailable source appends path and availability")
Expect(FakeTooltip.lines[2].wrap, false, "every source path avoids fragmented wrapping")
Expect(FakeTooltip.lines[3].wrap, true, "secondary requirements may still wrap")

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

FakeTooltip.__yiboMountsSignature = nil
FakeTooltip.unit = "focus"
FakeTooltip.spellID = 40192
NS.Tooltip:Apply(FakeTooltip, "focus", 40192, "SetUnitAura")
Expect(#FakeTooltip.lines, 3, "unsupported units remain untouched")
