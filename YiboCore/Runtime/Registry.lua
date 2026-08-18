local Core = _G.YiboCore

local Registry = {}
Core.Registry = Registry
Registry._addons = Registry._addons or {}
Registry._resources = Registry._resources or {}

local RESERVED_RESOURCE_IDS = {
    YiboCore = true,
    overview = true,
    characters = true,
    settings = true,
}

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

function Registry:ClaimResource(kind, id, owner, metadata)
    if type(kind) ~= "string" or kind == "" or type(id) ~= "string" or id == "" then
        return nil, "资源类型和标识符不能为空。"
    end
    if RESERVED_RESOURCE_IDS[id] then
        return nil, "标识符为 Core 保留名称: " .. id
    end
    if type(owner) ~= "string" or owner == "" then
        return nil, "资源必须声明所属插件。"
    end
    self._resources[kind] = self._resources[kind] or {}
    local current = self._resources[kind][id]
    if current then
        if current.owner == owner then return current end
        return nil, string.format("%s ID 已被插件 %s 占用: %s", kind, current.owner, id)
    end
    local resource = { kind = kind, id = id, owner = owner, metadata = CopyMetadata(metadata) }
    self._resources[kind][id] = resource
    return resource
end

function Registry:ReleaseResource(kind, id, owner)
    local resources = self._resources[kind]
    local current = resources and resources[id]
    if not current then return false end
    if owner and current.owner ~= owner then return false, "资源不属于此插件。" end
    resources[id] = nil
    return true
end

function Registry:GetResource(kind, id)
    return self._resources[kind] and self._resources[kind][id]
end

function Registry:GetResources(kind)
    local result = {}
    for _, resource in pairs(self._resources[kind] or {}) do result[#result + 1] = resource end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

function Core:RegisterAddon(name, metadata)
    return self.Registry:Register(name, metadata)
end

function Core:GetRegisteredAddons()
    return self.Registry:GetAll()
end

function Core:ClaimResource(kind, id, owner, metadata)
    return self.Registry:ClaimResource(kind, id, owner, metadata)
end
