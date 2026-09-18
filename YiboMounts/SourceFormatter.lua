local _, NS = ...

NS.SourceFormatter = {}

local TYPE_KEYS = {
    boss_drop = "SOURCE_BOSS_DROP",
    rare_drop = "SOURCE_RARE_DROP",
    achievement = "SOURCE_ACHIEVEMENT",
    reputation_vendor = "SOURCE_REPUTATION_VENDOR",
    vendor = "SOURCE_VENDOR",
    quest = "SOURCE_QUEST",
    class_reward = "SOURCE_CLASS_REWARD",
    holiday = "SOURCE_HOLIDAY",
    event = "SOURCE_EVENT",
    promotion = "SOURCE_PROMOTION",
    store = "SOURCE_STORE",
    auction_house = "SOURCE_AUCTION_HOUSE",
    crafted = "SOURCE_CRAFTED",
    container = "SOURCE_CONTAINER",
    research = "SOURCE_RESEARCH",
}

local DIFFICULTY_KEYS = {
    NORMAL = "DIFFICULTY_NORMAL",
    HEROIC = "DIFFICULTY_HEROIC",
    TEN = "DIFFICULTY_10",
    TWENTY_FIVE = "DIFFICULTY_25",
}

local AVAILABILITY_KEYS = {
    limited_time = "LIMITED_TIME",
    unavailable = "NO_LONGER_OBTAINABLE",
}

local function Join(values, separator)
    local result = {}
    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" then
            table.insert(result, value)
        end
    end
    return table.concat(result, separator)
end

local function FormatMoney(amountCopper)
    if type(amountCopper) ~= "number" or amountCopper < 0 then return nil end
    local gold = math.floor(amountCopper / 10000)
    local silver = math.floor((amountCopper % 10000) / 100)
    local copper = amountCopper % 100
    local result = {}
    if gold > 0 then table.insert(result, gold .. "g") end
    if silver > 0 then table.insert(result, silver .. "s") end
    if copper > 0 or #result == 0 then table.insert(result, copper .. "c") end
    return table.concat(result, " ")
end

function NS.SourceFormatter:FormatSource(record, source)
    if not source or record.status == "rejected" or source.type == "research" then return nil, nil end

    local typeKey = TYPE_KEYS[source.type]
    local sourceLabel = typeKey and NS:L(typeKey) or source.type
    local path = {}
    local hasInstance = false
    local sourcePath = source.path or {}
    for _, node in ipairs(sourcePath) do
        if node.kind == "instance" then
            hasInstance = true
            break
        end
    end
    for index, node in ipairs(sourcePath) do
        -- An instance is the actionable destination. Its containing zone stays
        -- in the catalogue for auditing but is redundant in the tooltip.
        local omitInstanceZone = hasInstance
            and (source.type == "boss_drop" or source.type == "rare_drop")
            and node.kind == "zone"
        -- The hand-maintained table intentionally stores readable path text,
        -- not node roles. A three-level drop path follows region > instance >
        -- boss; the region is context, while instance > boss is actionable.
        local omitLeadingDropRegion = not hasInstance
            and (source.type == "boss_drop" or source.type == "rare_drop")
            and #sourcePath >= 3
            and index == 1
            and (node.kind == "zone" or node.kind == "custom")
        local omitVendorFaction = source.type == "vendor" and node.kind == "faction"
        if not omitInstanceZone and not omitLeadingDropRegion and not omitVendorFaction then
            local text = NS:GetLocalizedText(node.labels)
            if text and text ~= "" and path[#path] ~= text then table.insert(path, text) end
        end
    end

    local pathText = Join(path, NS:L("PATH_SEPARATOR"))
    if pathText == "" then return nil, nil end
    local primary = sourceLabel .. NS:L("SOURCE_LABEL_SEPARATOR") .. pathText

    local requirements = source.requirements or {}
    local conditions = {}
    local difficultyLabels = {}
    for _, difficulty in ipairs(requirements.difficulties or {}) do
        table.insert(difficultyLabels, NS:L(DIFFICULTY_KEYS[difficulty] or difficulty))
    end
    local difficulties = Join(difficultyLabels, " / ")
    -- Dungeon/raid mounts carry the size and mode in their instance path
    -- (for example, "Icecrown Citadel 25H").  Keep encounter-only rules in
    -- the condition line without repeating that qualification.
    if difficulties ~= "" and not requirements.difficultyInPath then
        table.insert(conditions, difficulties)
    end

    if requirements.reputation and requirements.reputation.standing then
        table.insert(conditions, NS:L("STANDING_" .. requirements.reputation.standing))
    end

    local costs = {}
    local priceText = NS:GetLocalizedText(requirements.price)
    if priceText and priceText ~= "" then
        table.insert(costs, priceText)
    end
    for _, cost in ipairs(requirements.costs or {}) do
        if cost.type == "money" then
            local formatted = FormatMoney(cost.amountCopper)
            if formatted then table.insert(costs, formatted) end
        elseif cost.type == "currency" and cost.currencyID and cost.amount then
            table.insert(costs, tostring(cost.amount) .. " currency:" .. tostring(cost.currencyID))
        elseif cost.type == "item" and cost.itemID and cost.amount then
            table.insert(costs, tostring(cost.amount) .. " item:" .. tostring(cost.itemID))
        end
    end
    local costText = Join(costs, " / ")
    if costText ~= "" then table.insert(conditions, costText) end

    -- `notes` is maintenance evidence and must never leak into the player UI.
    -- Only an explicitly curated, short tooltip note may enter this line.
    local tooltipNote = NS:GetLocalizedText(requirements.tooltipNote)
    if tooltipNote and tooltipNote ~= "" then
        table.insert(conditions, tooltipNote)
    end

    local availabilityKey = AVAILABILITY_KEYS[source.availability]
    if availabilityKey then
        table.insert(conditions, NS:L(availabilityKey))
    end

    local secondary = Join(conditions, NS:L("CONDITION_SEPARATOR"))
    return primary, secondary ~= "" and secondary or nil
end

function NS.SourceFormatter:Format(record)
    return self:FormatSource(record, NS.Catalog:GetPrimarySource(record))
end

function NS.SourceFormatter:FormatAll(record)
    local entries = {}
    local seen = {}
    for _, source in ipairs(NS.Catalog:GetTooltipSources(record)) do
        local primary, secondary = self:FormatSource(record, source)
        local signature = primary and (primary .. "\031" .. (secondary or ""))
        if signature and not seen[signature] then
            seen[signature] = true
            table.insert(entries, { primary = primary, secondary = secondary, sourceID = source.sourceID })
        end
    end
    return entries
end
