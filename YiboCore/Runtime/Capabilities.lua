local Core = _G.YiboCore

local Capabilities = {}
Core.Capabilities = Capabilities

Capabilities._items = Capabilities._items or {}

function Capabilities:Register(name, version)
    if type(name) ~= "string" or name == "" then
        error("YiboCore capability name must be a non-empty string.")
    end

    version = tonumber(version) or 1
    local current = self._items[name]
    if not current or version > current then
        self._items[name] = version
    end
end

function Capabilities:Has(name, minimumVersion)
    local version = self._items[name]
    if not version then
        return false
    end
    return version >= (tonumber(minimumVersion) or 1)
end

function Capabilities:GetVersion(name)
    return self._items[name]
end

function Core:HasCapability(name, minimumVersion)
    return self.Capabilities:Has(name, minimumVersion)
end

function Core:GetCapabilityVersion(name)
    return self.Capabilities:GetVersion(name)
end

Capabilities:Register("runtime", 1)
