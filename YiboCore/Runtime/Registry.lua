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
        return nil, Core:Text("CORE.ADDON_NAME_CANNOT_BE_EMPTY")
    end

    metadata = CopyMetadata(metadata)
    local requiredAPI = tonumber(metadata.requiredAPI) or 1
    local compatible, availableAPI = Core:CheckAPIVersion(requiredAPI)
    if not compatible then
        return nil, Core:Text("CORE.REQUIRES_API") .. requiredAPI .. Core:Text("CORE.AVAILABLE_VERSION_IS") .. availableAPI .. Core:Text("FORMAT.PERIOD")
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
        return nil, Core:Text("CORE.RESOURCE_TYPE_AND_IDENTIFIER_CANNOT_BE_EMPTY")
    end
    if RESERVED_RESOURCE_IDS[id] then
        return nil, Core:Text("CORE.IDENTIFIER_IS_RESERVED_BY_CORE") .. id
    end
    if type(owner) ~= "string" or owner == "" then
        return nil, Core:Text("CORE.RESOURCES_MUST_DECLARE_THEIR_ADDON_OWNER")
    end
    self._resources[kind] = self._resources[kind] or {}
    local current = self._resources[kind][id]
    if current then
        if current.owner == owner then return current end
        return nil, string.format(Core:Text("CORE.S_ID_IS_ALREADY_OWNED_BY_ADDON"), kind, current.owner, id)
    end
    local resource = { kind = kind, id = id, owner = owner, metadata = CopyMetadata(metadata) }
    self._resources[kind][id] = resource
    return resource
end

function Registry:ReleaseResource(kind, id, owner)
    local resources = self._resources[kind]
    local current = resources and resources[id]
    if not current then return false end
    if owner and current.owner ~= owner then return false, Core:Text("CORE.RESOURCE_DOES_NOT_BELONG_TO_THIS_ADDON") end
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
