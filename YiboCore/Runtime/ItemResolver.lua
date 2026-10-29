local Core = _G.YiboCore
local Resolver = { pending = {}, failed = {} }
local frame = CreateFrame("Frame")
local Poll, pollElapsed = nil, 0
Core.ItemResolver = Resolver
Core.Capabilities:Register("item-resolver", 1)

local function CancelWaiter(waiter)
    waiter.cancelled, waiter.callback = true, nil
    local request = waiter._request
    waiter._request = nil
    if not request then return end
    for index, candidate in ipairs(request.waiters) do
        if candidate == waiter then table.remove(request.waiters, index); break end
    end
    -- Keep the shared native request until its original event/timeout. Another
    -- consumer can join it without issuing a duplicate request for the same ID.
end

local function ItemID(value)
    local number = tonumber(value)
    if number and number > 0 and number % 1 == 0 and number <= 2147483647 then return number end
end

function Resolver:GetInfo(itemID)
    itemID = ItemID(itemID)
    if not itemID then return nil end
    local native, availability = Core.Client:ReadItemInfo(itemID)
    local name, link, icon = native and native.name, native and native.link, native and native.icon
    return { itemID = itemID, name = name, link = link, icon = icon, availability = availability,
        state = name and "ready" or self.pending[itemID] and "loading" or self.failed[itemID] and "failed" or "unloaded" }
end

function Resolver:Parse(input, options)
    options = options or {}
    local text = tostring(input or ""):match("^%s*(.-)%s*$")
    if text == "" then return nil, Core:Text("CORE.ENTER_AN_ITEM_ID_LINK_OR_NAME") end
    local id
    if text:match("^%d+$") and options.allowID ~= false then id = ItemID(text)
    elseif options.allowLink ~= false then
        id = ItemID(text:match("^item:(%d+)[:%d%-]*$") or text:match("|Hitem:(%d+):.-|h.-|h"))
    end
    if id then return { self:GetInfo(id) } end
    if not options.allowName or text:match("^[%d%s%+%-%.]+$") or text:find("|H", 1, true) or text:match("^item:") then
        return nil, Core:Text("CORE.ENTER_A_POSITIVE_ITEM_ID_OR_A")
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
        local items = Core.Client:ReadBagItemIDs()
        if not items then return nil, Core:Text("CORE.ITEM_BAG_SEARCH_UNAVAILABLE") end
        for _, bagItem in ipairs(items) do Add(bagItem) end
    end
    table.sort(candidates, function(a, b) return a.itemID < b.itemID end)
    if #candidates == 0 then return nil, Core:Text("CORE.NO_MATCHING_ITEM_IN_BAGS_OR_KNOWN") end
    return candidates
end

function Resolver:Finish(itemID, success)
    local request = self.pending[itemID]
    if not request then return end
    local info = self:GetInfo(itemID)
    self.pending[itemID] = nil
    if not next(self.pending) then frame:SetScript("OnUpdate", nil) end
    success = success and info.name ~= nil
    self.failed[itemID] = not success or nil
    info.state = success and "ready" or "failed"
    local message = not success and Core:Text("CORE.ITEM_INFORMATION_COULD_NOT_LOAD_CHECK_THE") or nil
    -- Detach first: one callback may cancel another waiter. It must suppress
    -- that callback without shifting the array currently being dispatched.
    for _, waiter in ipairs(request.waiters) do waiter._request = nil end
    for _, waiter in ipairs(request.waiters) do
        local callback = waiter.callback
        waiter.callback = nil
        if not waiter.cancelled then
            local ok, err = pcall(callback, info, message)
            if not ok then Core:Print(Core:Text("CORE.ITEM_INFORMATION_CALLBACK_FAILED") .. tostring(err)) end
        end
    end
end

-- Returns a cancellation handle even when cached data invokes the callback immediately.
-- Each ID has one bounded request; retry is explicit and never automatic.
function Resolver:Request(itemID, callback, options)
    options = options or {}
    local waiter = { callback = callback, Cancel = CancelWaiter }
    local info = self:GetInfo(itemID)
    if not info then waiter.callback = nil; callback(nil, Core:Text("CORE.INVALID_ITEM_ID")); return waiter end
    itemID = info.itemID
    if info.state == "ready" then waiter.callback = nil; callback(info); return waiter end
    if self.failed[itemID] and not options.retry then
        waiter.callback = nil
        callback(info, Core:Text("CORE.ITEM_INFORMATION_COULD_NOT_LOAD_CHECK_THE")); return waiter
    end
    if self.pending[itemID] then
        waiter._request = self.pending[itemID]
        table.insert(self.pending[itemID].waiters, waiter); return waiter
    end
    self.failed[itemID] = nil
    if not next(self.pending) then pollElapsed = 0 end
    local timeout = tonumber(options.timeout)
    if not timeout or timeout ~= timeout or timeout <= 0 or timeout == math.huge then timeout = 8 end
    self.pending[itemID] = { waiters = { waiter }, remaining = timeout }
    waiter._request = self.pending[itemID]
    frame:SetScript("OnUpdate", Poll)
    local requested = Core.Client:RequestItemData(itemID)
    if not requested then self:Finish(itemID, false) end
    return waiter
end

-- Polling remains bounded even if this target's event cannot be subscribed.
Core.Client:BindItemEvents(frame, function(itemID, success) Resolver:Finish(itemID, success) end)
Poll = function(_, elapsed)
    pollElapsed = pollElapsed + elapsed
    if pollElapsed < 0.1 then return end
    elapsed, pollElapsed = pollElapsed, 0
    local finished = {}
    for itemID, request in pairs(Resolver.pending) do
        request.remaining = request.remaining - elapsed
        if Resolver:GetInfo(itemID).name then finished[#finished + 1] = { itemID, true }
        elseif request.remaining <= 0 then finished[#finished + 1] = { itemID, false } end
    end
    for _, result in ipairs(finished) do Resolver:Finish(result[1], result[2]) end
end
