local Core = _G.YiboCore

local Registry = {}
Core.Registry = Registry
Registry._addons = Registry._addons or {}

local function CopyMetadata(metadata)
    local copy = {}
    for key, value in pairs(metadata or {}) do
        copy[key] = value
    end
    return copy
end

function Registry:Register(name, metadata)
    if type(name) ~= "string" or name == "" then
        return nil, "插件名称不能为空。"
    end

    metadata = CopyMetadata(metadata)
    local requiredAPI = tonumber(metadata.requiredAPI) or 1
    local compatible, availableAPI = Core:CheckAPIVersion(requiredAPI)
    if not compatible then
        return nil, "需要 API " .. requiredAPI .. "，当前版本为 " .. availableAPI .. "。"
    end

    local entry = self._addons[name] or {}
    entry.name = name
    entry.version = tostring(metadata.version or entry.version or "unknown")
    entry.requiredAPI = requiredAPI
    entry.registeredAt = (GetServerTime and GetServerTime()) or time()
    entry.metadata = metadata
    self._addons[name] = entry
    return entry
end

function Registry:Get(name)
    return self._addons[name]
end

function Registry:GetAll()
    local items = {}
    for _, entry in pairs(self._addons) do
        items[#items + 1] = entry
    end
    table.sort(items, function(left, right)
        return left.name < right.name
    end)
    return items
end

function Core:RegisterAddon(name, metadata)
    return self.Registry:Register(name, metadata)
end

function Core:GetRegisteredAddons()
    return self.Registry:GetAll()
end
