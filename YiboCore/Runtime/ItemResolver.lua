local Core = _G.YiboCore
local Resolver = { pending = {}, failed = {} }
Core.ItemResolver = Resolver
Core.Capabilities:Register("item-resolver", 1)

local function ItemID(value)
    local number = tonumber(value)
    if number and number > 0 and number % 1 == 0 and number <= 2147483647 then return number end
end

function Resolver:GetInfo(itemID)
    itemID = ItemID(itemID)
    if not itemID then return nil end
    local getter = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    local name, link, _, _, _, _, _, _, _, icon
    if getter then name, link, _, _, _, _, _, _, _, icon = getter(itemID) end
    return { itemID = itemID, name = name, link = link, icon = icon,
        state = name and "ready" or self.pending[itemID] and "loading" or self.failed[itemID] and "failed" or "unloaded" }
end

function Resolver:Parse(input, options)
    options = options or {}
    local text = tostring(input or ""):match("^%s*(.-)%s*$")
    if text == "" then return nil, "请输入物品 ID、链接或名称。" end
    local id
    if text:match("^%d+$") and options.allowID ~= false then id = ItemID(text)
    elseif options.allowLink ~= false then
        id = ItemID(text:match("^item:(%d+)[:%d%-]*$") or text:match("|Hitem:(%d+):.-|h.-|h"))
    end
    if id then return { self:GetInfo(id) } end
    if not options.allowName or text:match("^[%d%s%+%-%.]+$") or text:find("|H", 1, true) or text:match("^item:") then
        return nil, "请输入正整数物品 ID 或有效物品链接。"
    end
    local candidates, seen = {}, {}
    local function Add(value)
        local candidateID = ItemID(type(value) == "table" and value.itemID or value)
        if not candidateID or seen[candidateID] then return end
        seen[candidateID] = true
        local info = self:GetInfo(candidateID)
        local name = info.name or (type(value) == "table" and (value.name or value.title))
        local matches = name and ((options.match == "contains" and name:lower():find(text:lower(), 1, true)) or name:lower() == text:lower())
        if matches then info.name = name; candidates[#candidates + 1] = info end
    end
    local known = type(options.candidates) == "function" and options.candidates() or options.candidates
    for _, candidate in ipairs(known or {}) do Add(candidate) end
    if options.includeBags then
        local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
        local getID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
        if slots and getID then
            for bag = 0, 4 do for slot = 1, (slots(bag) or 0) do Add(getID(bag, slot)) end end
        end
    end
    table.sort(candidates, function(a, b) return a.itemID < b.itemID end)
    if #candidates == 0 then return nil, "背包和已知目录中没有匹配物品；请使用物品 ID 或链接。" end
    return candidates
end

function Resolver:Finish(itemID, success)
    local request = self.pending[itemID]
    if not request then return end
    local info = self:GetInfo(itemID)
    self.pending[itemID] = nil
    success = success and info.name ~= nil
    self.failed[itemID] = not success or nil
    info.state = success and "ready" or "failed"
    local message = not success and "物品信息加载失败；请检查 ID 后点击重试。" or nil
    for _, waiter in ipairs(request.waiters) do
        if not waiter.cancelled then waiter.callback(info, message) end
    end
end

-- Returns a cancellation handle even when cached data invokes the callback immediately.
-- Each ID has one bounded request; retry is explicit and never automatic.
function Resolver:Request(itemID, callback, options)
    options = options or {}
    local waiter = { callback = callback }
    function waiter:Cancel() self.cancelled = true end
    local info = self:GetInfo(itemID)
    if not info then callback(nil, "无效物品 ID。"); return waiter end
    itemID = info.itemID
    if info.state == "ready" then callback(info); return waiter end
    if self.failed[itemID] and not options.retry then
        callback(info, "物品信息加载失败；请检查 ID 后点击重试。"); return waiter
    end
    if self.pending[itemID] then
        table.insert(self.pending[itemID].waiters, waiter); return waiter
    end
    self.failed[itemID] = nil
    self.pending[itemID] = { waiters = { waiter }, remaining = tonumber(options.timeout) or 8 }
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if request then request(itemID)
    elseif GetItemInfo then GetItemInfo(itemID) end
    return waiter
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(_, _, itemID, success) Resolver:Finish(tonumber(itemID), success) end)
frame:SetScript("OnUpdate", function(_, elapsed)
    local finished = {}
    for itemID, request in pairs(Resolver.pending) do
        request.remaining = request.remaining - elapsed
        if Resolver:GetInfo(itemID).name then finished[#finished + 1] = { itemID, true }
        elseif request.remaining <= 0 then finished[#finished + 1] = { itemID, false } end
    end
    for _, result in ipairs(finished) do Resolver:Finish(result[1], result[2]) end
end)
