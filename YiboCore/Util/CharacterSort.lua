local Core = _G.YiboCore

local CharacterSort = {}
Core.CharacterSort = CharacterSort

local VALID_MODES = {
    recent = true,
    name = true,
    level = true,
    custom = true,
}

local function IdentityLess(left, right)
    local leftName, rightName = tostring(left.name or ""), tostring(right.name or "")
    if leftName ~= rightName then return leftName < rightName end
    local leftRealm, rightRealm = tostring(left.realm or ""), tostring(right.realm or "")
    if leftRealm ~= rightRealm then return leftRealm < rightRealm end
    return tostring(left.id or "") < tostring(right.id or "")
end

local function CopySettings(value)
    return {
        mode = value.mode,
        direction = value.direction,
        pinCurrent = value.pinCurrent == true,
    }
end

function CharacterSort:NormalizeSettings(value, fallback, allowInherit)
    fallback = type(fallback) == "table" and fallback or {
        mode = "recent",
        direction = "desc",
        pinCurrent = false,
    }
    if type(value) == "string" then value = { mode = value } end
    value = type(value) == "table" and value or {}

    local mode = value.mode
    if mode == "seen" then mode = "custom" end
    if allowInherit and mode == "inherit" then return { mode = "inherit" } end
    if not VALID_MODES[mode] then mode = fallback.mode end
    if not VALID_MODES[mode] then mode = "recent" end

    local direction = value.direction
    if direction ~= "asc" and direction ~= "desc" then
        direction = fallback.direction
    end
    if direction ~= "asc" and direction ~= "desc" then
        direction = mode == "name" and "asc" or "desc"
    end

    local pinCurrent = value.pinCurrent
    if pinCurrent == nil then pinCurrent = fallback.pinCurrent end
    return {
        mode = mode,
        direction = direction,
        pinCurrent = pinCurrent == true,
    }
end

function CharacterSort:NormalizeOrder(order)
    local normalized, seen = {}, {}
    for _, characterID in ipairs(type(order) == "table" and order or {}) do
        if type(characterID) == "string" and characterID ~= "" and not seen[characterID] then
            seen[characterID] = true
            normalized[#normalized + 1] = characterID
        end
    end
    return normalized
end

function CharacterSort:BuildCustomOrder(characters)
    local ordered = {}
    for _, character in ipairs(characters or {}) do ordered[#ordered + 1] = character end
    table.sort(ordered, function(left, right)
        local leftOrder, rightOrder = tonumber(left.seenOrder), tonumber(right.seenOrder)
        if leftOrder ~= rightOrder then
            if leftOrder == nil then return false end
            if rightOrder == nil then return true end
            return leftOrder < rightOrder
        end
        return IdentityLess(left, right)
    end)
    local result = {}
    for _, character in ipairs(ordered) do
        if type(character.id) == "string" and character.id ~= "" then result[#result + 1] = character.id end
    end
    return self:NormalizeOrder(result)
end

function CharacterSort:MoveCharacter(order, characterID, delta)
    local normalized = self:NormalizeOrder(order)
    local index
    for candidateIndex, candidateID in ipairs(normalized) do
        if candidateID == characterID then index = candidateIndex; break end
    end
    if not index then return normalized, false end
    local target = math.max(1, math.min(#normalized, index + (tonumber(delta) or 0)))
    if target == index then return normalized, false end
    local moved = table.remove(normalized, index)
    table.insert(normalized, target, moved)
    return normalized, true
end

function CharacterSort:ReplaceCharacterID(order, oldID, newID)
    local normalized = self:NormalizeOrder(order)
    if type(oldID) ~= "string" or type(newID) ~= "string" or oldID == newID then return normalized, false end
    local oldIndex, newIndex
    for index, characterID in ipairs(normalized) do
        if characterID == oldID then oldIndex = index end
        if characterID == newID then newIndex = index end
    end
    if not oldIndex then return normalized, false end
    if newIndex then
        table.remove(normalized, oldIndex)
    else
        normalized[oldIndex] = newID
    end
    return self:NormalizeOrder(normalized), true
end

function CharacterSort:Sort(characters, settings, currentCharacterID, customOrder)
    local normalized = self:NormalizeSettings(settings)
    local result = {}
    for _, character in ipairs(characters or {}) do result[#result + 1] = character end

    local customIndex = {}
    for index, characterID in ipairs(self:NormalizeOrder(customOrder)) do customIndex[characterID] = index end

    table.sort(result, function(left, right)
        if normalized.pinCurrent and currentCharacterID then
            local leftCurrent, rightCurrent = left.id == currentCharacterID, right.id == currentCharacterID
            if leftCurrent ~= rightCurrent then return leftCurrent end
        end

        if normalized.mode == "custom" then
            local leftIndex, rightIndex = customIndex[left.id], customIndex[right.id]
            if leftIndex ~= rightIndex then
                if leftIndex == nil then return false end
                if rightIndex == nil then return true end
                return leftIndex < rightIndex
            end
            local leftSeen, rightSeen = tonumber(left.seenOrder), tonumber(right.seenOrder)
            if leftSeen ~= rightSeen then
                if leftSeen == nil then return false end
                if rightSeen == nil then return true end
                return leftSeen < rightSeen
            end
        elseif normalized.mode == "recent" then
            local leftSeen, rightSeen = tonumber(left.lastSeenAt), tonumber(right.lastSeenAt)
            if leftSeen ~= rightSeen then
                if leftSeen == nil then return false end
                if rightSeen == nil then return true end
                if normalized.direction == "asc" then return leftSeen < rightSeen end
                return leftSeen > rightSeen
            end
        elseif normalized.mode == "level" then
            local leftLevel, rightLevel = tonumber(left.level) or 0, tonumber(right.level) or 0
            if leftLevel ~= rightLevel then
                if normalized.direction == "asc" then return leftLevel < rightLevel end
                return leftLevel > rightLevel
            end
        elseif normalized.mode == "name" then
            local leftName, rightName = tostring(left.name or ""), tostring(right.name or "")
            if leftName ~= rightName then
                if normalized.direction == "asc" then return leftName < rightName end
                return leftName > rightName
            end
        end
        return IdentityLess(left, right)
    end)
    return result, CopySettings(normalized)
end
