local Core = _G.YiboCore

local AddonStatus = {}
Core.AddonStatus = AddonStatus

local function Installed(name)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local addonName = C_AddOns.GetAddOnInfo(name)
        return addonName ~= nil
    end
    return GetAddOnInfo and GetAddOnInfo(name) ~= nil or false
end

local function Metadata(name, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, field)
    end
    return GetAddOnMetadata and GetAddOnMetadata(name, field) or nil
end

local function Enabled(name)
    local character = UnitName and UnitName("player") or nil
    local value
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        value = C_AddOns.GetAddOnEnableState(name, character)
    elseif GetAddOnEnableState then
        value = GetAddOnEnableState(character, name)
    end
    return value == true or (type(value) == "number" and value > 0)
end

function AddonStatus:Get(name)
    local installed = Installed(name)
    local connected = Core.Registry and Core.Registry:Get(name) ~= nil or false
    local enabled = installed and Enabled(name) or false
    local state
    if connected then
        state = "connected"
    elseif enabled then
        state = "enabled-not-connected"
    elseif installed then
        state = "installed-disabled"
    else
        state = "missing"
    end
    return {
        installed = installed,
        enabled = enabled,
        connected = connected,
        installedVersion = installed and Metadata(name, "Version") or nil,
        packagedVersion = Core.PackagedAddonVersions and Core.PackagedAddonVersions[name] or nil,
        state = state,
    }
end

function AddonStatus:GetAll()
    local result = {}
    for _, addon in ipairs(Core.AddonCatalog or {}) do
        local item = {}
        for key, value in pairs(addon) do item[key] = value end
        item.status = self:Get(addon.name)
        result[#result + 1] = item
    end
    table.sort(result, function(left, right)
        if left.relation ~= right.relation then return left.relation == "core-child" end
        return left.name < right.name
    end)
    return result
end

Core.Capabilities:Register("addon-status", 1)
