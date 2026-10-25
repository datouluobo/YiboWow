local _, NS = ...

-- All S1-S15 mount spells in the target client's maintained inventory.
-- 44317 is an excluded technical duplicate; S2 uses 44744 at runtime.
local spells = {
    37015, 44744, 49193, 58615, 64927, 65439, 67336, 71810,
    101282, 101821, 124550, 139407, 148618, 148619, 148620,
}
local savedBuff, savedAura, savedSpellInfo, savedHook = UnitBuff, UnitAura, GetSpellInfo, hooksecurefunc
local savedLocale, savedCore = GetLocale, NS.CoreIntegration
NS.CoreIntegration = nil
local hooks = {}
hooksecurefunc = function(_, method, callback) hooks[method] = callback end
local tooltip = { SetUnitAura = function() end, SetUnitBuff = function() end }
function tooltip:GetUnit() return "Tester", "target" end
function tooltip:GetSpell() return nil end
function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function tooltip:Show() end
NS.AuraTooltip:Initialize(tooltip, function(owner, unit, spellID, source)
    NS.Tooltip:Apply(owner, unit, spellID, source)
end)

local checks = 0
for _, locale in ipairs({ "enUS", "zhCN" }) do
    GetLocale = function() return locale end
    for _, spellID in ipairs(spells) do
        local record = assert(NS.Catalog:GetBySpellID(spellID), "missing season mount " .. spellID)
        assert(#NS.SourceFormatter:FormatAll(record) > 0, "silent season source " .. spellID)
        for _, legacy in ipairs({ false, true }) do
            -- Name lookup is deliberately unavailable: the actual aura ID
            -- must suffice for a mount not known by localized spell name.
            GetSpellInfo = function() return nil end
            UnitBuff = function(_, index)
                if index ~= 1 then return nil end
                if legacy then
                    return "Arena mount", nil, 132249, 0, nil, 0, 0, "target", false, false, spellID
                end
                return "Arena mount", 132249, 0, nil, 0, 0, "target", false, false, spellID, false
            end
            UnitAura = UnitBuff
            for _, unit in ipairs({ "player", "target" }) do
                local matches, count = NS.Tooltip:FindMountAuras(unit)
                assert(count == 1 and #matches == 1 and matches[1].spellID == spellID, "season scan " .. spellID)
                for _, method in ipairs({ "SetUnitAura", "SetUnitBuff" }) do
                    tooltip.lines, tooltip.__yiboMountsSignature = {}, nil
                    hooks[method](tooltip, unit, 1, "HELPFUL")
                    assert(#tooltip.lines > 0, "season tooltip " .. spellID)
                    local lineCount = #tooltip.lines
                    hooks[method](tooltip, unit, 1, "HELPFUL")
                    assert(#tooltip.lines == lineCount, "duplicate season source " .. spellID)
                    tooltip.lines, tooltip.__yiboMountsSignature = {}, nil
                    hooks[method](tooltip, unit, 1, "HARMFUL")
                    assert(#tooltip.lines == 0, "harmful season source " .. spellID)
                    checks = checks + 1
                end
            end
        end
    end
end
assert(NS.Catalog:GetBySpellID(44317) == nil, "technical duplicate remains excluded")
UnitBuff, UnitAura, GetSpellInfo, hooksecurefunc = savedBuff, savedAura, savedSpellInfo, savedHook
GetLocale, NS.CoreIntegration = savedLocale, savedCore
print("PvP season tooltip regression passed: 15 mounts, " .. checks .. " cases")
