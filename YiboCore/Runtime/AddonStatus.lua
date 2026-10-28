local Core = _G.YiboCore

local AddonStatus = {}
Core.AddonStatus = AddonStatus

function AddonStatus:Get(name)
    local native = Core.Client:ReadAddon(name)
    local installed = native and native.installed or false
    local connected = Core.Registry and Core.Registry:Get(name) ~= nil or false
    local enabled = installed and native.enabled or false
    local state
    if connected then
        state = "connected"
    elseif not native or native.availability ~= "known" then
        state = "unavailable"
    elseif enabled then
        state = "enabled-not-connected"
    elseif installed then
        state = "installed-disabled"
    else
        state = "missing"
    end
    return {
        availability = native and native.availability or "unavailable",
        installed = installed,
        enabled = enabled,
        connected = connected,
        installedVersion = native and native.installedVersion or nil,
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
        local order = { ["core-child"] = 1, ["optional-core"] = 2, independent = 3 }
        local leftOrder, rightOrder = order[left.relation] or 99, order[right.relation] or 99
        if leftOrder ~= rightOrder then return leftOrder < rightOrder end
        return left.name < right.name
    end)
    return result
end

Core.Capabilities:Register("addon-status", 1)
