local _, NS = ...

NS.Tooltip = {}

local function IsSupportedUnit(unit)
    return unit == "player" or unit == "target"
end

local function ClearMarker(tooltip)
    tooltip.__yiboMountSourceSignature = nil
end

local function AppendSource(tooltip, unit, spellID, source)
    local record = NS.Catalog:GetBySpellID(spellID)
    if NS.Probe then NS.Probe:Report(source or "OnTooltipSetSpell", unit, spellID, record ~= nil) end

    if type(spellID) ~= "number" then return end
    if not record then return end

    local signature = unit .. ":" .. spellID
    local signatures = tooltip.__yiboMountSourceSignature
    if type(signatures) ~= "table" then
        signatures = {}
        tooltip.__yiboMountSourceSignature = signatures
    end
    if signatures[signature] then return end

    local primary, secondary = NS.SourceFormatter:Format(record)
    if not primary then return end

    -- The source path is the tooltip's primary, scan-oriented value.  Let it
    -- establish the natural tooltip width instead of wrapping just its final
    -- segment and leaving the rest of the row empty.
    tooltip:AddLine(primary, 0.12, 0.88, 0.44, false)
    if secondary then tooltip:AddLine(secondary, 0.12, 0.88, 0.44, true) end
    signatures[signature] = true
    tooltip:Show()
end

function NS.Tooltip:Apply(tooltip, unitOverride, spellIDOverride, source)
    local _, tooltipUnit = tooltip:GetUnit()
    local _, _, tooltipSpellID = tooltip:GetSpell()
    local unit = unitOverride or tooltipUnit
    local spellID = spellIDOverride or tooltipSpellID
    if not IsSupportedUnit(unit) then return end
    AppendSource(tooltip, unit, spellID, source)
end

local function GetAuraSpellID(api, unit, index, filter)
    if type(api) ~= "function" then return nil, false end
    local values = { api(unit, index, filter) }
    if type(values[11]) == "number" then return values[11], true end

    -- Some MoP Classic builds expose a non-standard UnitAura return layout.
    -- Resolve the localized aura name through the stable spell-info API first.
    if type(GetSpellInfo) == "function" and type(values[1]) == "string" then
        local _, _, _, _, _, _, spellID = GetSpellInfo(values[1])
        if type(spellID) == "number" then return spellID, true end
    end

    -- Retain a final catalog-aware fallback for custom clients that keep the
    -- spell ID at a different numeric return position.
    for i = 1, 20 do
        local value = values[i]
        if type(value) == "number" and NS.Catalog:GetBySpellID(value) then
            return value, true
        end
    end
    return nil, values[1] ~= nil
end

-- Read-only helper for the mouseover-tooltip diagnostic.  It deliberately
-- does not alter a tooltip or choose a fallback unit such as "target".
function NS.Tooltip:FindMountAuras(unit)
    local matches, auraCount = {}, 0
    if type(unit) ~= "string" or type(UnitBuff) ~= "function" then return matches, auraCount end

    for index = 1, 40 do
        local spellID, present = GetAuraSpellID(UnitBuff, unit, index)
        if not present then break end
        auraCount = auraCount + 1
        local record = NS.Catalog:GetBySpellID(spellID)
        if record then table.insert(matches, { spellID = spellID, record = record }) end
    end
    return matches, auraCount
end

function NS.Tooltip:ApplyHoveredUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if type(unit) ~= "string" or not (UnitExists and UnitExists(unit)) then return end

    local matches = self:FindMountAuras(unit)
    for _, match in ipairs(matches) do
        AppendSource(tooltip, unit, match.spellID, "OnTooltipSetUnit")
    end
end

local function ApplyUnitAura(tooltip, unit, index, filter)
    NS.Tooltip:Apply(tooltip, unit, GetAuraSpellID(UnitAura, unit, index, filter), "SetUnitAura")
end

local function ApplyUnitBuff(tooltip, unit, index, filter)
    NS.Tooltip:Apply(tooltip, unit, GetAuraSpellID(UnitBuff, unit, index, filter), "SetUnitBuff")
end

function NS.Tooltip:Initialize()
    if self.initialized or not GameTooltip then return end
    self.initialized = true

    GameTooltip:HookScript("OnTooltipSetSpell", function(tooltip)
        NS.Tooltip:Apply(tooltip)
    end)
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
        NS.Tooltip:ApplyHoveredUnit(tooltip)
    end)

    -- MoP Classic's aura buttons can populate GameTooltip through these legacy
    -- setters without firing OnTooltipSetSpell.
    if type(GameTooltip.SetUnitAura) == "function" then
        hooksecurefunc(GameTooltip, "SetUnitAura", ApplyUnitAura)
    end
    if type(GameTooltip.SetUnitBuff) == "function" then
        hooksecurefunc(GameTooltip, "SetUnitBuff", ApplyUnitBuff)
    end
    GameTooltip:HookScript("OnTooltipCleared", ClearMarker)
    GameTooltip:HookScript("OnHide", ClearMarker)
end
