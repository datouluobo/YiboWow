local function Widget(frameType)
    local widget = { frameType = frameType }
    setmetatable(widget, { __index = function(_, key)
        if key:match("^[a-z]") then return nil end
        if key == "CreateTexture" or key == "CreateFontString" then return function() return Widget() end end
        if key == "SetFont" and frameType == "EditBox" then
            return function(_, _, _, flags)
                assert(type(flags) == "string", "EditBox:SetFont requires a flags argument")
            end
        end
        if key == "SetFont" then
            return function(self, _, size, flags) self.fontSize, self.fontFlags = size, flags end
        end
        if key == "SetPoint" then
            return function(self, ...)
                self.points = self.points or {}
                self.points[#self.points + 1] = { ... }
            end
        end
        if key == "SetWidth" then return function(self, value) self.width = value end end
        if key == "SetTexCoord" then return function(self, ...) self.texCoord = { ... } end end
        if key == "SetBackdropBorderColor" then
            return function(self, ...) self.borderColor = { ... } end
        end
        if key == "SetTextColor" then return function(self, ...) self.textColor = { ... } end end
        if key == "SetScript" then
            return function(self, event, callback)
                self.scripts = self.scripts or {}
                self.scripts[event] = callback
            end
        end
        if key == "SetText" then return function(self, value) self.text = value end end
        if key == "SetShown" then return function(self, shown) self.shown = shown end end
        if key == "SetScrollChild" then return function(self, child) self.scrollChild = child end end
        if key == "SetContentHeight" then return function(self, height) self.contentHeight = height end end
        if key == "GetWidth" then return function() return 800 end end
        if key == "GetHeight" then return function() return 600 end end
        if key == "GetText" then return function() return "" end end
        return function() end
    end })
    return widget
end
_G.CreateFrame = function(frameType) return Widget(frameType) end
_G.STANDARD_TEXT_FONT = "Fonts/FRIZQT__.TTF"
local colors = setmetatable({}, { __index = function() return { 0.2, 0.3, 0.4, 1 } end })
local theme = { Colors = colors, Font = { assist = 14, meta = 12, section = 16 } }
function theme:CreateText(_, _, color)
    local widget = Widget()
    widget.initialColor = color
    return widget
end
function theme:CreateButton()
    local button = Widget()
    button.label = Widget()
    button.SetState = function(self, state) self.state = state end
    return button
end
function theme:CreateScrollFrame() return Widget() end
function theme:GetDataRowColor() return { 0.2, 0.3, 0.4, 1 } end
_G.YiboCore = { UITheme = theme, Characters = { GetCurrent = function() return nil end } }
_G.YiboVault = { Items = {
    GetStorageSummary = function() return { characters = {}, guilds = {} } end,
    Query = function() return { records = {} } end,
    GetSourceState = function() return {} end,
} }
dofile("YiboVault/StoragePage.lua")
local host = Widget()
YiboVault.StoragePage:Create(host)
assert(host.yiboVaultStoragePage and host.yiboVaultStoragePage.ready
    and host.yiboVaultStoragePage.search and host.yiboVaultStoragePage.searchClear,
    "the account host must receive a complete warehouse page with search controls")
local page = host.yiboVaultStoragePage
page.tabs = {
    { id = "bags", label = "背包", enabled = true },
    { id = "mail", label = "邮件", enabled = false },
    { id = "bank", label = "个人银行", enabled = false },
    { id = "auction", label = "拍卖", enabled = false },
    { id = "equipment", label = "装备", enabled = false },
}
YiboVault.StoragePage:LayoutChrome(page)
local fullWidth = page.areaButtons[1].width
assert(math.abs(fullWidth * 5 + 4 * 4 - page.header:GetWidth()) < 0.01,
    "five character source buttons must fill the whole row")
for index = 1, 5 do
    assert(math.abs(page.areaButtons[index].width - fullWidth) < 0.01,
        "all visible source buttons must have equal width")
end
assert(page.areaButtons[2].state == "disabled" and not page.areaButtons[2].tabEnabled,
    "unscanned source must be visibly disabled")
page.tabs = {}
for index = 1, 8 do page.tabs[index] = { id = "tab:" .. index, label = "页签 " .. index, enabled = index == 2 } end
YiboVault.StoragePage:LayoutChrome(page)
assert(math.abs(page.areaButtons[1].width * 8 + 4 * 7 - page.header:GetWidth()) < 0.01,
    "eight guild tabs must redistribute the same row width")
local priorArea = page.area
page.areaButtons[1].scripts.OnClick()
assert(page.area == priorArea, "disabled guild tab must not be clickable")
assert(page.grid.scrollChild == page.itemsContent and page.pager == nil,
    "the item grid must use a vertical scroll child without a page footer")
local searchPoint, ownersPoint = page.searchBox.points[1], page.owners.points[1]
assert(searchPoint[1] == "TOPLEFT" and searchPoint[2] == page and searchPoint[4] == 217,
    "the search field must start in the right content column")
assert(ownersPoint[1] == "TOPLEFT" and ownersPoint[2] == page and ownersPoint[4] == 12,
    "the owner list must start at the top of the left column")
assert(page.owners.width == 190 and page.ownersContent.width == 190,
    "the character list and its scroll child must use the compact width")
YiboVault.StoragePage:Refresh(host, { characters = {} })
page.slots = { { emptySlots = 4 } }
YiboVault.StoragePage:LayoutCells(page)
assert(page.itemCells[1].emptyLabel.shown and page.itemCells[1].emptyCount.text == "4",
    "one empty cell must show the known free-slot count at its bottom")
assert(page.grid.contentHeight == 51, "one grid row must set the scrollable content height")

_G.GetItemInfo = function()
    return "Sword", nil, 4, 400, nil, nil, nil, nil, "INVTYPE_WEAPON"
end
_G.ITEM_QUALITY_COLORS = { [4] = { r = 0.7, g = 0.2, b = 0.9 } }
_G.C_Item = { GetDetailedItemLevelInfo = function() return 450 end }
page.slots = { { itemID = 100, itemLink = "item:100", quantity = 2 } }
YiboVault.StoragePage:LayoutCells(page)
assert(page.itemCells[1].itemLevel.text == "450" and page.itemCells[1].count.text == "",
    "equipment must show item level without a competing stack count")
assert(page.itemCells[1].itemLevel.points[1][1] == "BOTTOMRIGHT"
    and page.itemCells[1].count.points[1][1] == "TOPLEFT",
    "item level and quantity must use distinct corners")
assert(page.itemCells[1].borderColor[1] == 0.7
    and page.itemCells[1].borderColor[2] == 0.2
    and page.itemCells[1].borderColor[3] == 0.9,
    "an item cell must retain its custom quality border")
assert(page.itemCells[1].icon.texCoord[1] == 0.08
    and page.itemCells[1].icon.texCoord[2] == 0.92,
    "the item texture must crop the built-in icon edge")
assert(page.itemCells[1].itemLevel.initialColor[1] ~= page.itemCells[1].count.initialColor[1],
    "item level and quantity must use distinct text colors")
_G.GetItemInfo = function()
    return "Ore", nil, 1, 1, nil, nil, nil, nil, ""
end
page.slots = { { itemID = 200, itemLink = "item:200", quantity = 20 } }
YiboVault.StoragePage:LayoutCells(page)
assert(page.itemCells[1].itemLevel.text == "" and page.itemCells[1].count.text == "20"
    and page.itemCells[1].count.fontSize == theme.Font.section,
    "non-equipment must show its quantity at the larger size")
page.slots = { { itemID = 200, itemLink = "item:200", quantity = 1234 } }
YiboVault.StoragePage:LayoutCells(page)
assert(page.itemCells[1].count.text == "1234" and page.itemCells[1].count.fontSize == theme.Font.assist,
    "four-digit quantities must use the smaller readable size")
page.slots = { { itemID = 200, itemLink = "item:200", quantity = 1 } }
YiboVault.StoragePage:LayoutCells(page)
assert(page.itemCells[1].count.text == "1", "a single non-equipment item must show quantity one")
local appendedItemID
YiboVault.Tooltip = { Append = function(_, _, itemID) appendedItemID = itemID end }
_G.GameTooltip = Widget()
page.itemCells[1].scripts.OnEnter(page.itemCells[1])
assert(appendedItemID == 200, "hovering a Vault item must append the Vault tooltip section")
page.slots = { { emptySlots = 4 } }
YiboVault.StoragePage:LayoutCells(page)
assert(page.itemCells[1].borderColor[1] == colors.lineSoft[1],
    "a reused empty cell must recover its visible outline")
assert(page.itemCells[1].count.text == "" and page.itemCells[1].itemLevel.text == "",
    "a reused empty cell must clear both numeric overlays")

local requested = {}
_G.GetItemInfo = function() return nil end
_G.C_Item.RequestLoadItemDataByID = function(itemID) requested[itemID] = (requested[itemID] or 0) + 1 end
page.slots = { { itemID = 300, itemLink = "item:300", quantity = 2 } }
YiboVault.StoragePage:LayoutCells(page)
assert(page.itemCells[1].borderColor[4] == 1
    and page.itemCells[1].borderColor[1] == colors.muted[1],
    "an uncached item must keep a fully visible neutral border")
YiboVault.StoragePage:LayoutCells(page)
assert(requested[300] == 1, "repeated layouts must not request the same item twice")
_G.GetItemInfo = function() return "Loaded", nil, 4, 400, nil, nil, nil, nil, "INVTYPE_WEAPON" end
page.scripts.OnEvent(page, "GET_ITEM_INFO_RECEIVED", 300, true)
assert(page.itemCells[1].borderColor[1] == 0.7 and page.itemCells[1].itemLevel.text == "450",
    "item-data arrival must update the visible cell without switching pages")
_G.GetItemInfo = function() return nil end
page.slots = { { itemID = 400, itemLink = "|cffa335ee|Hitem:400|h[Cached Link]|h|r", quantity = 1 } }
YiboVault.StoragePage:LayoutCells(page)
assert(math.abs(page.itemCells[1].borderColor[1] - (0xa3 / 255)) < 0.001,
    "a saved colored item link must supply its quality border before item info loads")

YiboCore.Characters.GetCurrent = function() return { id = "one" } end
_G.RAID_CLASS_COLORS = { MAGE = { r = 0.3, g = 0.8, b = 1 } }
YiboVault.Items.GetStorageSummary = function()
    return { characters = {
        { characterID = "one", bags = { locations = {} } },
        { characterID = "two", bags = { locations = {} } },
    }, guilds = { { guildKey = "guild-1", guildName = "Guild", realm = "Realm",
        tabs = { locations = { { location = { tabID = 2, tabName = "Materials" }, status = "known" } } } } } }
end
page.selectedOwner = "two"
YiboVault.StoragePage:Refresh(host, { characters = {
    { id = "one", name = "One", realm = "Realm", class = "MAGE" },
    { id = "two", name = "Two", realm = "Realm" },
} })
assert(page.ownerRows[1].name.text == "Guild" and page.ownerRows[2].currentMarker.shown
    and not page.ownerRows[3].currentMarker.shown,
    "current character must retain its visual marker when another character is selected")
assert(page.ownerRows[2].name.textColor[1] == 0.3
    and page.ownerRows[2].name.textColor[2] == 0.8
    and page.ownerRows[2].name.textColor[3] == 1,
    "character names must use their class colors")
assert(page.selectedOwner == "two", "current-character marker must not change selection")
assert(#page.ownerRows == 3 and page.ownerRows[1].name.text == "Guild",
    "guild bank must occupy one owner row without per-tab duplicates")
assert(#page.tabs == 5 and page.areaButtons[1].label.text == "背包"
    and page.areaButtons[2].label.text == "邮件"
    and page.areaButtons[3].label.text == "个人银行"
    and page.areaButtons[4].label.text == "拍卖"
    and page.areaButtons[5].label.text == "装备",
    "character owners always display five source tabs in the requested order")
page.selectedOwner = "guild-1"
YiboVault.Items.Query = function()
    return { records = { { source = "guild-bank", guildKey = "guild-1",
        location = { tabID = 2 }, sourceID = "guild-1:2:1", itemID = 200, quantity = 5 } } }
end
YiboVault.StoragePage:Refresh(host)
assert(#page.tabs == 8 and page.area == "tab:2" and page.areaButtons[2].label.text == "Materials",
    "guild owner displays eight tabs and selects the scanned tab")
assert(page.areaButtons[1].state == "disabled" and page.areaButtons[2].state == "selected",
    "unscanned guild pages stay disabled while scanned pages remain selectable")
assert(page.slots[1] and page.slots[1].itemID == 200 and page.slots[1].quantity == 5,
    "guild records must appear beneath their guild tab after owner grouping")
YiboVault.Items.GetStorageSummary = function(_, scope)
    assert(#scope.characterIDs == 1 and scope.characterIDs[1] == "one",
        "the warehouse summary must receive only the selected realm's character IDs")
    return { characters = { { characterID = "one", bags = { locations = {} } } }, guilds = {} }
end
YiboVault.Items.Query = function(_, options)
    assert(#options.scope.characterIDs == 1 and options.scope.characterIDs[1] == "one",
        "item query must use the same selected realm as the owner list")
    return { records = {} }
end
page.selectedOwner = "guild-1"
YiboVault.StoragePage:Refresh(host, { scope = "realm:Realm", characters = {
    { id = "one", name = "One", realm = "Realm", class = "MAGE" },
    { id = "two", name = "Two", realm = "Other" },
} })
assert(page.selectedOwner == "one" and page.ownerRows[1].name.text == "One"
    and page.owners.contentHeight == 44,
    "changing realm drops out-of-scope guilds and characters from the owner list")
print("YiboVault storage page create spec passed")
