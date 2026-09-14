local Addon = _G.YiboAutoOpen
local Resolver = {}; Addon.ItemResolver = Resolver
local function Trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
function Resolver:Resolve(raw)
    raw = Trim(raw); local linkID = raw:match("item:(%d+)"); if linkID then return tonumber(linkID) end
    if raw:match("^%d+$") then local id = tonumber(raw); if id and id >= 1 and id <= 9007199254740991 then return id end; return nil, "not_found" end
    if raw == "" then return nil, "not_found" end
    local candidates, seen = {}, {}; local function Add(id) if id and not seen[id] then seen[id] = true; candidates[#candidates + 1] = id end end
    for bag = 0, 4 do for slot = 1, Addon.BagAdapter:GetNumSlots(bag) do local item = Addon.BagAdapter:GetItemInfo(bag, slot); if item and item.itemID then local name = GetItemInfo(item.itemID); if name == raw then Add(item.itemID) end end end end
    for _, id in ipairs(Addon.Database:GetOrderedItems()) do local name = GetItemInfo(id); if name == raw then Add(id) end end
    local name, link = GetItemInfo(raw); if name == raw and link then Add(tonumber(link:match("item:(%d+)"))) end
    if #candidates == 1 then return candidates[1] end
    if #candidates > 1 then return nil, "ambiguous", candidates end
    return nil, "not_found"
end
