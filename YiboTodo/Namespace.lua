local ADDON_NAME = ...

local Addon = _G.YiboTodo or {}
_G.YiboTodo = Addon
Addon.NAME = ADDON_NAME or "YiboTodo"
Addon.VERSION = "0.1.0-dev"
Addon.REQUIRED_CORE_API = 5
Addon.CATALOG_VERSION = 3
Addon.RULESET_ID = "mop-classic-50504"
Addon.Catalog = Addon.Catalog or { activities = {}, groups = {}, recipes = {}, rulesets = {} }
Addon.Model = Addon.Model or {}
Addon.Providers = Addon.Providers or {}
Addon.Database = Addon.Database or {}

function Addon:Now()
    return (GetServerTime and GetServerTime()) or time()
end

function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[YiboTodo]|r " .. tostring(message))
    end
end

function Addon:NotifyChanged()
    if self.Snapshot then self.Snapshot:Invalidate() end
    if self.Core and self.Core.AccountView then self.Core.AccountView:NotifyPageChanged("todo") end
end
