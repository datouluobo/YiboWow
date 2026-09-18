local messages = {}
local entries = { [52340] = true }

GetItemInfo = function(id) return id == 52340 and "深渊蚌" or "测试物品" end
SlashCmdList = {}
YiboAutoOpen = {
    Catalog = { IsManualOnly = function(_, id) return id == 52340 end },
    Print = function(_, message) messages[#messages + 1] = message end,
    Refresh = function() end,
    ItemResolver = { Resolve = function(_, raw) return tonumber(raw) end },
    Database = {
        AddItem = function(_, id) if entries[id] then return nil, "already_exists" end; entries[id] = true; return true end,
        RemoveItem = function(_, id) if not entries[id] then return nil, "not_found" end; entries[id] = nil; return true end,
        GetOrderedItems = function() return { 52340 } end,
    },
    LIMITS = { listPageSize = 20 },
}

dofile("YiboAutoOpen/Commands.lua")
SlashCmdList.YIBOAUTOOPEN("add 52340")
assert(entries[52340], "adding an existing manual-only item must never remove it")
assert(messages[#messages]:find("不会自动开启"), "adding an existing manual-only item must explain that it will not auto-open")
SlashCmdList.YIBOAUTOOPEN("list")
assert(messages[#messages]:find("仅手动开启"), "the catalog list must label manual-only items")
print("Commands spec passed")
