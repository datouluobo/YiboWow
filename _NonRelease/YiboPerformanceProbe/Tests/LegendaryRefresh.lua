-- Load the actual Legendary UI; a data notification must name its own page.
YiboCore = { UITheme = { Colors = {}, Table = {} } }
local notified = {}
YiboLegendary = { Core = { AccountView = {
    NotifyPageChanged = function(_, id) notified[#notified + 1] = id end,
    RefreshPage = function() error("Legendary must not redraw an unrelated active page") end,
} } }
dofile("YiboLegendary/UI.lua")
YiboLegendary.UI:Refresh("BAG_UPDATE_DELAYED")
YiboLegendary.UI:Refresh("QUEST_LOG_UPDATE")
assert(#notified == 2 and notified[1] == "legendary" and notified[2] == "legendary")
print("Legendary scoped refresh passed")
