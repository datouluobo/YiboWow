local _, NS = ...

NS.AuraTooltip = {}

local function ReadSpellID(api, unit, index, filter)
    if type(api) ~= "function" then return nil, false end
    local values = { api(unit, index, filter) }
    if type(values[11]) == "number" then return values[11], true end

    -- Some MoP Classic builds use a different aura tuple. Resolve the aura's
    -- name rather than guessing from duration, expiration time or other numbers.
    if type(GetSpellInfo) == "function" and type(values[1]) == "string" then
        local _, _, _, _, _, _, spellID = GetSpellInfo(values[1])
        if type(spellID) == "number" then return spellID, true end
    end
    return nil, values[1] ~= nil
end

function NS.AuraTooltip:ReadBuff(unit, index, filter)
    return ReadSpellID(UnitBuff, unit, index, filter)
end

function NS.AuraTooltip:Initialize(tooltip, apply)
    local function Hook(method, api)
        if type(tooltip[method]) ~= "function" then return end
        hooksecurefunc(tooltip, method, function(owner, unit, index, filter)
            -- Both setters default to helpful auras. Explicit harmful filters
            -- must be rejected before reading or resolving any spell ID.
            if filter ~= nil then
                if type(filter) ~= "string" or filter:upper():find("HARMFUL", 1, true) then return end
            end
            local spellID = ReadSpellID(api(), unit, index, filter)
            -- An unresolved aura must not reuse GetSpell() from a previous tip.
            if spellID then apply(owner, unit, spellID, method) end
        end)
    end
    Hook("SetUnitAura", function() return UnitAura end)
    Hook("SetUnitBuff", function() return UnitBuff end)
end
