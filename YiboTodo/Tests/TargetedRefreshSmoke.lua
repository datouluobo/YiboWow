_G.YiboTodo = nil
dofile("YiboTodo/Namespace.lua")

local Addon = _G.YiboTodo
local invalidations, iconRefreshes, pageRefreshes = 0, 0, 0
Addon.Snapshot = { Invalidate = function() invalidations = invalidations + 1 end }
Addon.AccountPage = {
    RefreshProjectIcon = function(_, target)
        iconRefreshes = iconRefreshes + 1
        return target.groupID == "test.cooldown"
    end,
}
Addon.Core = {
    AccountView = {
        NotifyPageChanged = function()
            pageRefreshes = pageRefreshes + 1
        end,
    },
}

Addon:NotifyChanged(true, { groupID = "test.cooldown" })
assert(invalidations == 1, "a targeted refresh invalidates the stale snapshot")
assert(iconRefreshes == 1, "a targeted refresh updates its icon")
assert(pageRefreshes == 0, "a successful targeted refresh never rebuilds the account page")

print("YiboTodo targeted refresh smoke passed")
