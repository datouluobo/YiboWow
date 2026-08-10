local Core = _G.YiboCore

local LevelFilter = {}
Core.LevelFilter = LevelFilter

function LevelFilter:Normalize(expression)
    expression = tostring(expression or "")
    expression = expression:gsub("%s+", "")
    expression = expression:gsub("，", ",")
    expression = expression:gsub(",+", ",")
    expression = expression:gsub("^,", "")
    expression = expression:gsub(",$", "")
    return expression
end

function LevelFilter:Compile(expression)
    local normalized = self:Normalize(expression)
    local filter = {
        expression = normalized,
        rules = {},
    }

    if normalized == "" or normalized == "0" then
        function filter:Matches()
            return true
        end
        return filter
    end

    for token in string.gmatch(normalized, "[^,]+") do
        local minimum, maximum = string.match(token, "^(%d+)%-(%d+)$")
        if minimum and maximum then
            minimum, maximum = tonumber(minimum), tonumber(maximum)
            if minimum > maximum then
                minimum, maximum = maximum, minimum
            end
            filter.rules[#filter.rules + 1] = { kind = "range", minimum = minimum, maximum = maximum }
        else
            local kind, value = nil, nil
            if string.match(token, "^>=%d+$") then
                kind, value = "ge", tonumber(string.sub(token, 3))
            elseif string.match(token, "^<=%d+$") then
                kind, value = "le", tonumber(string.sub(token, 3))
            elseif string.match(token, "^>%d+$") then
                kind, value = "gt", tonumber(string.sub(token, 2))
            elseif string.match(token, "^<%d+$") then
                kind, value = "lt", tonumber(string.sub(token, 2))
            elseif string.match(token, "^%d+$") then
                kind, value = "eq", tonumber(token)
            else
                return nil, token, normalized
            end
            filter.rules[#filter.rules + 1] = { kind = kind, value = value }
        end
    end

    function filter:Matches(level)
        level = tonumber(level) or 0
        for _, rule in ipairs(self.rules) do
            if rule.kind == "range" and level >= rule.minimum and level <= rule.maximum then
                return true
            elseif rule.kind == "ge" and level >= rule.value then
                return true
            elseif rule.kind == "le" and level <= rule.value then
                return true
            elseif rule.kind == "gt" and level > rule.value then
                return true
            elseif rule.kind == "lt" and level < rule.value then
                return true
            elseif rule.kind == "eq" and level == rule.value then
                return true
            end
        end
        return false
    end

    return filter
end

function LevelFilter:Validate(expression)
    local filter, badToken, normalized = self:Compile(expression)
    return filter ~= nil, normalized or self:Normalize(expression), badToken
end

Core.Capabilities:Register("level-filter", 1)
