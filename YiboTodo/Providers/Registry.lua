local Addon = _G.YiboTodo
local Registry = { items = {} }
Addon.Providers.Registry = Registry

function Registry:Register(provider)
    if type(provider) ~= "table" or not provider.id then return nil, "invalid-provider" end
    if self.items[provider.id] then return nil, "duplicate-provider:" .. provider.id end
    self.items[provider.id] = provider
    return provider
end

function Registry:Get(id) return self.items[id] end
