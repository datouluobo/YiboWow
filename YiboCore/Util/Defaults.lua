local Core = _G.YiboCore

local Defaults = {}
Core.Defaults = Defaults

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = CopyValue(child)
    end
    return copy
end

function Defaults:Apply(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return target
    end

    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = CopyValue(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            self:Apply(target[key], value)
        end
    end
    return target
end

function Defaults:Copy(value)
    return CopyValue(value)
end
