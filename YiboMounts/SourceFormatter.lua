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
    crafted = "SOURCE_CRAFTED",
    research = "SOURCE_RESEARCH",
}

local DIFFICULTY_KEYS = {
    NORMAL = "DIFFICULTY_NORMAL",
    HEROIC = "DIFFICULTY_HEROIC",
    TEN = "DIFFICULTY_10",
    TWENTY_FIVE = "DIFFICULTY_25",
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

function NS.SourceFormatter:Format(record)
    local source = NS.Catalog:GetPrimarySource(record)
    if not source then return nil, nil end

    local typeKey = TYPE_KEYS[source.type]
    local path = { typeKey and NS:L(typeKey) or source.type }
    local hasInstance = false
    for _, node in ipairs(source.path or {}) do
        if node.kind == "instance" then
            hasInstance = true
            break
        end
    end
    for _, node in ipairs(source.path or {}) do
        -- An instance is the actionable destination. Its containing zone stays
        -- in the catalogue for auditing but is redundant in the tooltip.
        if not (hasInstance and (source.type == "boss_drop" or source.type == "rare_drop") and node.kind == "zone") then
            local text = NS:GetLocalizedText(node.labels)
            if text and text ~= "" then table.insert(path, text) end
        end
    end

    local primary = Join(path, " > ")
    if primary == "" then return nil, nil end

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
        table.insert(costs, NS:L("PRICE") .. "：" .. priceText)
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

    -- Event names already identify the activity.  Their catalogue notes are
    -- research detail (version, delivery rules, announcement caveats), not
    -- useful tooltip decisions; retain only the concise availability state.
    if source.type ~= "event" then
        local note = NS:GetLocalizedText(requirements.notes)
        if note and note ~= "" then table.insert(conditions, note) end
    end
    if source.availability == "unavailable" then
        table.insert(conditions, NS:L("NO_LONGER_OBTAINABLE"))
    end

    local secondary = Join(conditions, " > ")
    return primary, secondary ~= "" and secondary or nil
end
