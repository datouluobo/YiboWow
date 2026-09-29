local queryCount, revision = 0, 1
_G.YiboVault = {
    AccountPage = { GetScope = function()
        return { mode = "characters", characterIDs = { "A-Realm", "B-Realm" } },
            { { id = "A-Realm", name = "Alpha" }, { id = "B-Realm", name = "Beta" } }
    end },
    Items = { GetRevision = function() return revision end, Query = function(_, options)
        queryCount = queryCount + 1
        assert(#options.scope.characterIDs == 2)
        if options.itemID == 999 then
            return { records = {}, totals = { totalQuantity = 0, physicalQuantity = 0,
                listedQuantity = 0, externalQuantity = 0 } }
        end
        assert(options.itemID == 100)
        return {
            records = {
                { source = "bags", characterID = "A-Realm", quantity = 3 },
                { source = "bank", characterID = "A-Realm", quantity = 2 },
                { source = "auction", characterID = "B-Realm", quantity = 1 },
                { source = "guild-bank", guildKey = "shared", guildName = "Guild", quantity = 4 },
            },
            totals = { totalQuantity = 10, physicalQuantity = 9, listedQuantity = 1, externalQuantity = 0 },
        }
    end },
}
local tooltip = { lines = {}, link = "|Hitem:100:0|h[Test]|h" }
function tooltip:GetItem() return "Test", self.link end
function tooltip:AddLine(value) self.lines[#self.lines + 1] = value end
function tooltip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. " / " .. right end
function tooltip:Show() end
dofile("YiboVault/Tooltip.lua")
local vaultTooltip = _G.YiboVault.Tooltip
vaultTooltip:Append(tooltip)
assert(queryCount == 1, "tooltip should use the shared query once")
assert(table.concat(tooltip.lines, "\n"):find("Alpha / 背包 3  ·  银行 2", 1, true), "source subtotals should follow character")
assert(table.concat(tooltip.lines, "\n"):find("Guild / 公会银行 4", 1, true), "guild stock should be shown once")
vaultTooltip:Append(tooltip)
assert(queryCount == 1, "repeat tooltip update must not append duplicate lines")
local hooks = {}
_G.GameTooltip = { HookScript = function(_, event, callback) hooks[event] = callback end }
vaultTooltip:Install()
assert(type(hooks.OnTooltipSetItem) == "function" and type(hooks.OnTooltipCleared) == "function"
    and type(hooks.OnShow) == "function" and type(hooks.OnHide) == "function",
    "item and show hooks must both be installed")
hooks.OnTooltipCleared(tooltip)
tooltip.link = nil
vaultTooltip:Append(tooltip, 100)
assert(queryCount == 1, "a cleared tooltip can reuse the cached item result")
hooks.OnShow(tooltip)
assert(queryCount == 1, "multiple tooltip hooks must not duplicate the Vault section")
hooks.OnHide(tooltip)
vaultTooltip:Append(tooltip, 100)
assert(queryCount == 1, "reopening a tooltip for the same item should reuse the cached query")
revision = revision + 1
hooks.OnHide(tooltip)
vaultTooltip:Append(tooltip, 100)
assert(queryCount == 2, "a changed Vault revision invalidates the tooltip cache")
hooks.OnHide(tooltip)
vaultTooltip:Append(tooltip, 999)
vaultTooltip:Append(tooltip, 999)
assert(queryCount == 3, "a missing item must not be queried repeatedly by one tooltip's callbacks")

local postCall
_G.Enum = { TooltipDataType = { Item = 1 } }
_G.TooltipDataProcessor = { AddTooltipPostCall = function(_, callback) postCall = callback end }
_G.GameTooltip = { HookScript = function(_, event, callback)
    if event == "OnTooltipCleared" or event == "OnTooltipSetItem" then error("unsupported") end
    hooks[event] = callback
end }
vaultTooltip.installed = nil
vaultTooltip:Install()
assert(type(postCall) == "function", "item data post-call must be installed when available")
local secondary = { lines = {} }
secondary.AddLine, secondary.AddDoubleLine, secondary.Show = tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
postCall(secondary, { id = 100 })
assert(queryCount == 3 and #secondary.lines > 0,
    "item data post-call must support another tooltip frame and the supplied item ID")
print("YiboVault tooltip spec passed")
