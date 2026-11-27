-- Verify the shared tooltip uses its existing rendered cell and follows the cursor.
local reads, draws, cursor = 0, 0, 220
YiboCore = { UITheme = { Colors = { text = {1,1,1} } } }
YiboReputation = { GetSnapshot = function() reads = reads + 1; error("tooltip reread its snapshot") end }
dofile("YiboReputation/Common/AccountMatrixView.lua")
local showTooltip
for i = 1, 30 do
    local name, value = debug.getupvalue(YiboReputation.PaintMatrixRows, i)
    if name == "UpdateMatrixTooltip" then showTooltip = value; break end
end
assert(showTooltip)
UIParent = {}
GetCursorPosition = function() return cursor end
GameTooltip = {
    shown = false, Hide = function(self) self.shown = false end, IsShown = function(self) return self.shown end,
    SetOwner = function() end, ClearLines = function() draws = draws + 1 end, AddLine = function() end,
    Show = function(self) self.shown = true end,
}
local row = {
    GetLeft = function() return 0 end,
    tooltipNode = { kind = "faction", title = "The Tillers" },
    tooltipColumns = { { left = 0, width = 200 }, { left = 200, width = 80 }, { left = 280, width = 80 } },
    displays = { { details = {"1000/3000"} }, { details = {"2000/3000"} } },
}
for i = 1, 100 do showTooltip(row) end
assert(draws == 1 and reads == 0, "stationary tooltip rebuild")
cursor = 300; showTooltip(row); assert(draws == 2 and reads == 0, "column switch")
row.tooltipColumn = nil; showTooltip(row); assert(draws == 3, "rerender")
row.displays[2].details = {}; row.tooltipColumn = nil; showTooltip(row)
assert(not GameTooltip.shown, "no tooltip for a cell without details")
cursor = 10; showTooltip(row); assert(not GameTooltip.shown, "outside data columns")
print("PASS: shared hover reuses its rendered cells and refreshes only on column change or rerender")
