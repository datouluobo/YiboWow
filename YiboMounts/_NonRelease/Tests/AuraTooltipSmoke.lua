local _, NS = ...

local savedBuff, savedAura, savedSpellInfo, savedHook = UnitBuff, UnitAura, GetSpellInfo, hooksecurefunc
local function Expect(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local hooks = {}
hooksecurefunc = function(_, method, callback) hooks[method] = callback end
local tooltip = { lines = {}, SetUnitAura = function() end, SetUnitBuff = function() end }
function tooltip:GetUnit() return "Tester", "player" end
-- Deliberately retain an old mount spell, as a reused tooltip can do.
function tooltip:GetSpell() return "Old mount", nil, 40192 end
function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function tooltip:Show() end
NS.AuraTooltip:Initialize(tooltip, function(owner, unit, spellID, source)
    NS.Tooltip:Apply(owner, unit, spellID, source)
end)

GetSpellInfo = function() return nil end
UnitAura = function()
    -- Non-mount aura, with timing values that collide with real mount IDs.
    return "Tricked!", nil, nil, nil, nil, 127170, 40192
end
for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
    hooks.SetUnitAura(tooltip, "player", 1, filter)
end
Expect(#tooltip.lines, 0, "unresolved aura never guesses a mount or reuses stale tooltip spell")

UnitBuff = function(_, index)
    if index == 1 then return UnitAura() end
    if index == 2 then return "Mount", nil, nil, nil, nil, nil, nil, nil, nil, nil, 40192 end
end
local matches, count = NS.Tooltip:FindMountAuras("player")
Expect(count, 2, "unresolved aura does not end the buff scan")
Expect(#matches, 1, "timing collisions are excluded from hovered unit sources")
Expect(matches[1].spellID, 40192, "real mount after unresolved aura remains available")
hooks.SetUnitBuff(tooltip, "player", 2)
Expect(#tooltip.lines, 1, "explicit mount aura still displays source")

tooltip.lines, tooltip.__yiboMountsSignature = {}, nil
GetSpellInfo = function(name)
    if name == "Mount" then return name, nil, nil, nil, nil, nil, 40192 end
    return name, nil, nil, nil, nil, nil, 24753
end
UnitAura = function() return "Tricked!", nil, nil, nil, nil, 127170, 40192 end
hooks.SetUnitAura(tooltip, "player", 1, "HARMFUL")
Expect(#tooltip.lines, 0, "resolved non-mount debuff remains silent despite timing collisions")
UnitBuff = function() return "Mount", nil, nil, nil, nil, 127170 end
hooks.SetUnitBuff(tooltip, "target", 1, "HELPFUL")
Expect(#tooltip.lines, 1, "name-based spell resolution retains mount support")

-- Even a harmful aura resolving to a catalog mount cannot enter rendering.
tooltip.lines, tooltip.__yiboMountsSignature = {}, nil
local reads = 0
UnitAura = function()
    reads = reads + 1
    return "Mount", nil, nil, nil, nil, nil, nil, nil, nil, nil, 40192
end
UnitBuff = UnitAura
for _, method in ipairs({ "SetUnitAura", "SetUnitBuff" }) do
    for _, unit in ipairs({ "player", "target" }) do
        for _, filter in ipairs({ "HARMFUL", "HARMFUL|PLAYER", "PLAYER HARMFUL", "HELPFUL|HARMFUL" }) do
            hooks[method](tooltip, unit, 1, filter)
        end
    end
end
Expect(reads, 0, "harmful aura filters are rejected before querying spell data")
Expect(#tooltip.lines, 0, "harmful auras never append mount sources even for catalog spell IDs")
hooks.SetUnitAura(tooltip, "player", 1)
Expect(#tooltip.lines, 1, "default helpful aura remains supported")

-- Exercise actual initialization: no generic spell callback may bypass the
-- helpful-only aura hooks, and the dedicated debuff setter has no source hook.
local savedTooltip, savedInitialized = GameTooltip, NS.Tooltip.initialized
local scripts = {}
tooltip.SetUnitDebuff = function() end
function tooltip:HookScript(event, callback) scripts[event] = callback end
GameTooltip, NS.Tooltip.initialized = tooltip, nil
hooks = {}
NS.Tooltip:Initialize()
Expect(scripts.OnTooltipSetSpell, nil, "generic spell callback cannot bypass aura classification")
Expect(hooks.SetUnitDebuff, nil, "dedicated debuff setter never appends mount sources")
tooltip.lines, tooltip.__yiboMountsSignature = {}, nil
hooks.SetUnitAura(tooltip, "player", 1, "HARMFUL")
Expect(#tooltip.lines, 0, "initialized tooltip rejects harmful aura")
hooks.SetUnitBuff(tooltip, "player", 1, "HELPFUL")
Expect(#tooltip.lines, 1, "initialized tooltip retains helpful mount aura")
GameTooltip, NS.Tooltip.initialized = savedTooltip, savedInitialized

GetSpellInfo, UnitBuff = nil, nil
local spellID, present = NS.AuraTooltip:ReadBuff("player", 1)
Expect(spellID, nil, "missing buff API is silent")
Expect(present, false, "missing buff API ends scan")
UnitBuff, UnitAura, GetSpellInfo, hooksecurefunc = savedBuff, savedAura, savedSpellInfo, savedHook
print("Aura tooltip regression tests passed")
