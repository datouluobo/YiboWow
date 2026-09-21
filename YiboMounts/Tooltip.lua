local _, NS = ...

NS.Tooltip = {}

local function IsSupportedUnit(unit)
    return unit == "player" or unit == "target"
end

local function ClearMarker(tooltip)
    tooltip.__yiboMountsSignature = nil
    tooltip.__yiboMountsCollectionSignature = nil
    tooltip.__yiboMountsJournalTooltip = nil
end

local function CurrentFaction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local faction = UnitFactionGroup("player")
    return type(faction) == "string" and faction:lower() or nil
end

local function ReadMountState(journal, mountJournalID, expectedSpellID)
    if type(mountJournalID) ~= "number" then return nil end
    local result = { journal.GetMountInfoByID(mountJournalID) }
    local spellID = result[2]
    local isFactionSpecific, faction = result[8], result[9]
    local shouldHideOnChar, isCollected = result[10], result[11]
    if type(expectedSpellID) == "number" and spellID ~= expectedSpellID then
        -- Journal IDs are client-owned and can point at a different entry on
        -- faction-specific/older clients. Never use that entry's state for
        -- the requested spell.
        return nil
    end
    if isFactionSpecific and type(faction) == "string" then
        local playerFaction = CurrentFaction()
        if playerFaction and faction:lower() ~= playerFaction then return nil end
    end
    if shouldHideOnChar then return nil end
    if type(isCollected) == "boolean" then return isCollected end
    return nil
end

local function GetCollectionState(record, spellID)
    if not (NS.CoreIntegration and NS.CoreIntegration:IsCollectionStatusAvailable()) then return nil end
    local mountJournalID = record and record.ids and record.ids.mountJournalID
    if type(record) ~= "table" then return nil end
    if not (C_MountJournal and type(C_MountJournal.GetMountInfoByID) == "function") then return nil end
    local journal = C_MountJournal
    local collected = ReadMountState(journal, mountJournalID, spellID)
    if collected == true then return true end
    local foundUncollected = collected == false

    -- Do not trust a stale catalog journal ID. Re-resolve by spellID against
    -- the current character's journal, which is especially important when
    -- testing an account-owned mount from the opposing faction.
    if type(spellID) ~= "number" or type(journal.GetMountIDs) ~= "function" then
        if foundUncollected then return false end
        return nil
    end
    for _, candidateID in ipairs(journal.GetMountIDs()) do
        local state = ReadMountState(journal, candidateID, spellID)
        if state == true then return true end
        if state == false then foundUncollected = true end
    end
    if foundUncollected then return false end
    return nil
end

local function AppendCollectionStatus(tooltip, spellID, record, source, identity)
    -- SetMountBySpellID is the Mount Journal path. The native panel already
    -- renders collection state, so do not duplicate it there.
    -- A player's own mount aura is proof that the account has the mount; the
    -- status line adds no information there and only creates noise.
    if source == "SetMountBySpellID" or tooltip.__yiboMountsJournalTooltip or identity == "player" then return end
    local settings = NS:GetSettings().collectionStatus
    if not settings then return end

    local collected = GetCollectionState(record, spellID)
    if collected == nil then return end
    if collected and not settings.showCollected then return end
    if not collected and not settings.showUncollected then return end

    local signatures = tooltip.__yiboMountsCollectionSignature
    if type(signatures) ~= "table" then
        signatures = {}
        tooltip.__yiboMountsCollectionSignature = signatures
    end
    if signatures[spellID] then return end

    local key = collected and "COLLECTION_STATUS_COLLECTED" or "COLLECTION_STATUS_UNCOLLECTED"
    local colors = collected and { 0.16, 0.68, 0.24 } or { 0.70, 0.20, 0.20 }
    tooltip:AddLine(NS:L("COLLECTION_STATUS") .. ": " .. NS:L(key), colors[1], colors[2], colors[3], true)
    signatures[spellID] = true
end

local function AppendSource(tooltip, spellID, source, identity)
    local record = NS.Catalog:GetBySpellID(spellID)
    if NS.Probe then NS.Probe:Report(source or "OnTooltipSetSpell", identity, spellID, record ~= nil) end

    if type(spellID) ~= "number" then return end
    if not record then return end

    local signature = tostring(identity or source or "spell") .. ":" .. spellID
    local signatures = tooltip.__yiboMountsSignature
    if type(signatures) ~= "table" then
        signatures = {}
        tooltip.__yiboMountsSignature = signatures
    end
    if signatures[signature] then return end

    local entries = NS.SourceFormatter:FormatAll(record)
    if #entries == 0 then return end

    for _, entry in ipairs(entries) do
        -- Each acquisition channel owns one prominent source line. A quieter
        -- condition line follows only when that channel needs it.
        tooltip:AddLine(entry.primary, 0.12, 0.88, 0.44, true)
        if entry.secondary then tooltip:AddLine(entry.secondary, 0.82, 0.82, 0.82, true) end
    end
    AppendCollectionStatus(tooltip, spellID, record, source, identity)
    signatures[signature] = true
    tooltip:Show()
end

function NS.Tooltip:Apply(tooltip, unitOverride, spellIDOverride, source)
    local _, tooltipUnit = tooltip:GetUnit()
    local _, _, tooltipSpellID = tooltip:GetSpell()
    local unit = unitOverride or tooltipUnit
    local spellID = spellIDOverride or tooltipSpellID
    if not IsSupportedUnit(unit) then return end
    AppendSource(tooltip, spellID, source, unit)
end

function NS.Tooltip:ApplySpellID(tooltip, spellID, source, identity)
    if source == "SetMountBySpellID" then tooltip.__yiboMountsJournalTooltip = true end
    AppendSource(tooltip, spellID, source, identity)
end

function NS.Tooltip:ExtractSpellIDFromHyperlink(link)
    if type(link) ~= "string" then return nil end
    local spellID = link:match("[Hh]spell:(%d+)")
    if spellID then return tonumber(spellID) end

    local mountID = tonumber(link:match("[Hh]mount:(%d+)"))
    if not mountID then return nil end
    if C_MountJournal and type(C_MountJournal.GetMountInfoByID) == "function" then
        local _, journalSpellID = C_MountJournal.GetMountInfoByID(mountID)
        if type(journalSpellID) == "number" then return journalSpellID end
    end
    -- Some clients expose mount links with a spell ID payload. Preserve that
    -- useful fallback when the journal lookup is unavailable.
    return NS.Catalog:GetBySpellID(mountID) and mountID or nil
end

function NS.Tooltip:ApplyHyperlink(tooltip, link)
    local _, _, tooltipSpellID = tooltip:GetSpell()
    local spellID = type(tooltipSpellID) == "number" and tooltipSpellID
        or self:ExtractSpellIDFromHyperlink(link)
    self:ApplySpellID(tooltip, spellID, "OnTooltipSetHyperlink", "hyperlink")
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
        AppendSource(tooltip, match.spellID, "OnTooltipSetUnit", unit)
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
    if type(GameTooltip.HasScript) == "function" and GameTooltip:HasScript("OnTooltipSetHyperlink") then
        GameTooltip:HookScript("OnTooltipSetHyperlink", function(tooltip, link)
            NS.Tooltip:ApplyHyperlink(tooltip, link)
        end)
    end
    if type(GameTooltip.SetHyperlink) == "function" then
        hooksecurefunc(GameTooltip, "SetHyperlink", function(tooltip, link)
            NS.Tooltip:ApplyHyperlink(tooltip, link)
        end)
    end
    if type(GameTooltip.SetMountBySpellID) == "function" then
        hooksecurefunc(GameTooltip, "SetMountBySpellID", function(tooltip, spellID)
            NS.Tooltip:ApplySpellID(tooltip, spellID, "SetMountBySpellID", "mount")
        end)
    end
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
