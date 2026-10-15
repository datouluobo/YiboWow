-- Current ownership contract. Legacy collectors are intentionally inactive.
dofile("_NonRelease/CurrencyMigration/Spec.lua")
local Addon, checks = YiboCurrency, 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
GetServerTime = function() return 200000 end
C_Timer, C_Item, C_Container, GetItemCount = nil, nil, nil, nil
GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
GetContainerItemInfo = function() return nil, 7, nil, nil, nil, nil, nil, nil, nil, 123 end
local data, state = Addon.Scanner:ReadTokens()
Check(data.items[123].carried == 7 and state == "partial", "old tuple API retains bags count")
GetContainerItemInfo = function() return nil, 6, nil, nil, nil, nil, "|Hitem:123:0|h[Token]|h", nil, nil, nil end
data = Addon.Scanner:ReadTokens()
Check(data.items[123].carried == 6, "old link-only slot identifies the item")
C_Container = { GetContainerNumSlots = GetContainerNumSlots, GetContainerItemInfo = function() return { itemID = 123, stackCount = 5 } end }
data = Addon.Scanner:ReadTokens()
Check(data.items[123].carried == 5, "table API retains bags count")
C_Container.GetContainerItemInfo = function() return nil end
data = Addon.Scanner:ReadTokens()
Check(data.items[123].carried == 0, "successful empty bags are known zero")
C_Container.GetContainerItemInfo = function() error("temporary") end
data, state = Addon.Scanner:ReadTokens()
Check(data == nil and state == "error", "failed slot read cannot certify zero")
C_Container, GetContainerNumSlots, GetContainerItemInfo = nil, nil, nil
C_Item = { GetItemCount = function(_, includeBank) Check(not includeBank, "standalone fallback never requests bank"); return 0 end }
data = Addon.Scanner:ReadTokens()
Check(data.items[123].carried == 0, "count API empty is known zero")
C_Item.GetItemCount = function() return nil end
data, state = Addon.Scanner:ReadTokens()
Check(data == nil and state == "unavailable", "count API nil is unknown")
C_Item = nil
data, state = Addon.Scanner:ReadTokens()
Check(data == nil and state == "unavailable", "missing count APIs are unknown")
local progress = Addon:FormatWeeklyProgress({ maxWeeklyQuantity = 100, maxQuantity = 200 }, { currencyID = 392 })
Check(progress:find("? / 100", 1, true) and progress:find("? / 200", 1, true), "missing weekly and held counts never default to zero")
print("BalanceSpec: " .. checks .. " additional current-scanner checks passed")
