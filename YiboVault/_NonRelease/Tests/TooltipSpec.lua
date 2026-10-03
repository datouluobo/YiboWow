local queryCount, revision, itemChanged = 0, 1, nil
local hiddenGuild = false
local bagLocations, bankLocations, guildLocations = {}, {}, {}
for bagID = 0, 4 do bagLocations[tostring(bagID)] = { status = "known" } end
bankLocations["-1"] = { status = "known" }
for bagID = 5, 11 do bankLocations[tostring(bagID)] = { status = "known" } end
bankLocations["5"].status = "stale"
for tabID = 1, 8 do guildLocations[tostring(tabID)] = { status = "known-empty" } end
guildLocations["2"].status, guildLocations["7"].status = "known", "known"
guildLocations["2"].location = { tabID = 2, tabName = "材料库" }
_G.YiboVault = {
    IsGuildHidden = function(_, key) return hiddenGuild and key == "hidden" end,
    db = { settings = { tooltipEnabled = true }, byGuild = {
        hidden = { guildName = "Hidden Guild", realm = "Realm" },
    } },
    AccountPage = { GetTooltipScope = function()
        return { mode = "characters", characterIDs = { "A-Realm", "B-Other" } },
            { { id = "A-Realm", name = "Alpha", realm = "Realm" },
                { id = "B-Other", name = "Beta", realm = "Other" } }, true
    end },
    Core = { Characters = { GetCurrent = function() return { id = "A-Realm", realm = "Realm" } end } },
    Items = { Events = { Register = function(_, _, callback) itemChanged = callback end },
        GetRevision = function() return revision end, Query = function(_, options)
        queryCount = queryCount + 1
        if options.guildKey == "hidden" then
            return { records = { { source = "guild-bank", guildKey = "hidden",
                location = { tabID = 1, tabName = "隐藏页" }, quantity = 5 } },
                coverage = { ["guild-bank"] = { hidden = {
                    locations = { ["1"] = { status = "known" } },
                } } } }
        end
        assert(#options.scope.characterIDs == 2)
        if options.itemID == 999 then
            return { records = {}, totals = { totalQuantity = 0, physicalQuantity = 0,
                listedQuantity = 0, externalQuantity = 0 } }
        end
        if options.itemID == 200 then
            return {
                records = { { source = "guild-bank", guildKey = "shared", guildName = "Guild",
                    realm = "Realm", location = { tabID = 2 }, quantity = 4 } },
                totals = { totalQuantity = 4 },
                coverage = { ["guild-bank"] = { shared = {
                    locations = { ["2"] = { status = "stale" } },
                } } },
            }
        end
        if options.itemID == 300 then
            return {
                records = {
                    { source = "bags", characterID = "A-Realm", quantity = 20 },
                    { source = "guild-bank", guildKey = "shared", guildName = "Guild",
                        realm = "Realm", location = { tabID = 2, tabName = "材料库" }, quantity = 210 },
                },
                coverage = {
                    bags = { ["A-Realm"] = { locations = bagLocations } },
                    mail = { ["A-Realm"] = { locations = { inbox = { status = "stale" } } } },
                    bank = { ["A-Realm"] = { locations = bankLocations } },
                    equipment = { ["A-Realm"] = { locations = { equipment = { status = "known-empty" } } } },
                    auction = { ["A-Realm"] = { locations = { auction = { status = "stale" } } } },
                    ["guild-bank"] = { shared = { locations = guildLocations } },
                },
            }
        end
        assert(options.itemID == 100)
        return {
            records = {
                { source = "bags", characterID = "A-Realm", quantity = 3, state = "stale" },
                { source = "mail", characterID = "A-Realm", quantity = 6 },
                { source = "bank", characterID = "A-Realm", quantity = 2 },
                { source = "equipment", characterID = "A-Realm", quantity = 1 },
                { source = "auction", characterID = "A-Realm", quantity = 2 },
                { source = "auction", characterID = "B-Other", quantity = 1 },
                { source = "guild-bank", guildKey = "shared", guildName = "Guild", realm = "Realm",
                    location = { tabID = 2, tabName = "旧材料" }, quantity = 4 },
                { source = "guild-bank", guildKey = "shared", guildName = "Guild", realm = "Realm",
                    location = { tabID = 7, tabName = "消耗品" }, quantity = 5 },
            },
            totals = { totalQuantity = 24, physicalQuantity = 15, listedQuantity = 3, externalQuantity = 6 },
            coverage = {
                bags = { ["A-Realm"] = { locations = bagLocations } },
                mail = { ["A-Realm"] = { locations = { inbox = { status = "partial", unscannedCount = 2 } } } },
                bank = { ["A-Realm"] = { locations = bankLocations } },
                equipment = { ["A-Realm"] = { locations = { equipment = { status = "known" } } } },
                auction = { ["A-Realm"] = { locations = { auction = { status = "known" } } } },
                ["guild-bank"] = { shared = { locations = guildLocations } },
            },
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
local content = table.concat(tooltip.lines, "\n")
assert(content:find("账号库存 / |cff20e07022+|r", 1, true),
    "header should sum displayed quantities and mark unscanned sources")
assert(not content:find("实体", 1, true), "header should not repeat source subtotals")
assert(content:find("Alpha / |cff20e07012+|r[", 1, true), "character row should show its known total first")
assert(content:find("Beta-Other / |cff20e0701|r[", 1, true),
    "other-realm characters should always carry their realm suffix")
local orderedIcons = { "INV_Misc_Bag_10", "INV_Letter_15", "INV_Box_01",
    "INV_Chest_Cloth_01", "INV_Misc_Coin_02" }
local previous = 0
for _, icon in ipairs(orderedIcons) do
    local position = assert(content:find(icon, previous + 1, true), "missing or unordered source icon: " .. icon)
    previous = position
end
assert(not content:find("待刷新", 1, true)
    and content:find("INV_Box_01:13:13:0:0|t|cff87b3ba~|r", 1, true)
    and not content:find("邮箱仅统计已扫描的可见邮件", 1, true),
    "unscanned sources should use icon-tilde without an extra mail explanation")
assert(content:find("Guild-Realm / |cff20e0709|r[P2·材料库 |cff20e0704|r/P7·消耗品 |cff20e0705|r]", 1, true),
    "guild row should contain real scanned tab names, one total and only occupied tabs")
vaultTooltip:Append(tooltip)
assert(queryCount == 1, "repeat tooltip update must not append duplicate lines")
local hooks = {}
local refreshCount = 0
_G.GameTooltip = { HookScript = function(_, event, callback) hooks[event] = callback end,
    IsShown = function() return true end,
    RefreshData = function() refreshCount = refreshCount + 1 end }
vaultTooltip:Install()
assert(type(hooks.OnTooltipSetItem) == "function" and type(hooks.OnTooltipCleared) == "function"
    and type(hooks.OnShow) == "function" and type(hooks.OnHide) == "function",
    "item and show hooks must both be installed")
GameTooltip._yiboVaultAppliedItemID = 100
itemChanged("VAULT_ITEMS_CHANGED", { changedItemIDs = { 101 } })
assert(refreshCount == 0, "unrelated item changes must not refresh the shown tooltip")
itemChanged("VAULT_ITEMS_CHANGED", { changedItemIDs = { 100 } })
assert(refreshCount == 1, "a matching item change must refresh the shown tooltip")
itemChanged("VAULT_ITEMS_CHANGED", { changedItemIDs = {} })
assert(refreshCount == 2, "source coverage changes must refresh the shown tooltip")
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

_G.UIParent = { GetWidth = function() return 220 end, GetHeight = function() return 500 end }
local narrow = { lines = {} }
narrow.AddLine, narrow.AddDoubleLine, narrow.Show = tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
function narrow:GetHeight() return 100 end
function narrow:CreateFontString()
    local measure = {}
    function measure:SetText(value)
        self.value = value:gsub("|T.-|t", "#"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end
    function measure:GetStringWidth() return #(self.value or "") * 8 end
    return measure
end
vaultTooltip:Append(narrow, 100)
local narrowText = table.concat(narrow.lines, "\n")
assert(narrowText:find("Alpha / |cff20e07012+|r", 1, true)
    and narrowText:find("  [|T", 1, true),
    "source groups should wrap beneath the holder when the tooltip is narrow")
_G.UIParent = nil
bankLocations["5"].status = "known"
guildLocations["2"].status = "stale"
revision = revision + 1
local guildPending = { lines = {} }
guildPending.AddLine, guildPending.AddDoubleLine, guildPending.Show = tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
vaultTooltip:Append(guildPending, 100)
local pendingText = table.concat(guildPending.lines, "\n")
assert(pendingText:find("账号库存 / |cff20e07020|r", 1, true)
    and not pendingText:find("P2", 1, true)
    and not pendingText:find("P2|cff87b3ba~|r", 1, true)
    and pendingText:find("Guild-Realm / |cff20e0705|r[P7·消耗品 |cff20e0705|r]", 1, true)
    and pendingText:find("Alpha / |cff20e07014|r[", 1, true),
    "an unscanned guild tab should be omitted while scanned sources retain their counts")
guildLocations["7"].status = "stale"
revision = revision + 1
local guildUnavailable = { lines = {} }
guildUnavailable.AddLine, guildUnavailable.AddDoubleLine, guildUnavailable.Show =
    tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
vaultTooltip:Append(guildUnavailable, 100)
local unavailableText = table.concat(guildUnavailable.lines, "\n")
assert(unavailableText:find("账号库存 / |cff20e07015|r", 1, true)
    and not unavailableText:find("Guild-Realm", 1, true),
    "a guild without any scanned matching tab should not appear in the tooltip")
local guildOnlyUnavailable = { lines = {} }
guildOnlyUnavailable.AddLine, guildOnlyUnavailable.AddDoubleLine, guildOnlyUnavailable.Show =
    tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
vaultTooltip:Append(guildOnlyUnavailable, 200)
assert(#guildOnlyUnavailable.lines == 0,
    "a guild-only item with no scannable tab should not add an empty Vault section")
guildLocations["2"].status = "known"
guildLocations["7"].status = "known"
revision = revision + 1
local scanned = { lines = {} }
scanned.AddLine, scanned.AddDoubleLine, scanned.Show = tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
vaultTooltip:Append(scanned, 100)
local scannedText = table.concat(scanned.lines, "\n")
assert(scannedText:find("账号库存 / |cff20e07024|r", 1, true)
    and scannedText:find("P2·材料库 |cff20e0704|r", 1, true)
    and not scannedText:find("|cff87b3ba~|r", 1, true),
    "completed scans should restore numeric totals and source details")
local transferred = { lines = {} }
transferred.AddLine, transferred.AddDoubleLine, transferred.Show =
    tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
vaultTooltip:Append(transferred, 300)
local transferredText = table.concat(transferred.lines, "\n")
assert(transferredText:find("账号库存 / |cff20e070230|r", 1, true)
    and transferredText:find("Alpha / |cff20e07020|r[", 1, true)
    and not transferredText:find("|cff87b3ba~|r", 1, true),
    "moving a guild item into bags must not add unknown sources without item records")
hiddenGuild = true
local explicitHidden = { lines = {}, _yiboVaultGuildKey = "hidden" }
explicitHidden.AddLine, explicitHidden.AddDoubleLine, explicitHidden.Show =
    tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
vaultTooltip:Append(explicitHidden, 100)
local hiddenText = table.concat(explicitHidden.lines, "\n")
assert(hiddenText:find("账号库存 / |cff20e07024|r", 1, true)
    and hiddenText:find("已隐藏 · 不计入账号合计", 1, true)
    and hiddenText:find("Hidden Guild-Realm / |cff20e0705|r", 1, true),
    "an explicitly browsed hidden guild must show its detail outside the account total")
YiboVault.db.settings.tooltipEnabled = false
local disabled = { lines = {}, _yiboVaultGuildKey = "hidden" }
disabled.AddLine, disabled.AddDoubleLine, disabled.Show =
    tooltip.AddLine, tooltip.AddDoubleLine, tooltip.Show
vaultTooltip:Append(disabled, 100)
assert(#disabled.lines == 0, "the Vault tooltip switch must suppress its whole summary")
print("YiboVault tooltip spec passed")
