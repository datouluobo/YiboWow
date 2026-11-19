local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local function Boot(saved, configure, forever, hintOnly)
    if forever == nil then forever = true end
    local e, core, event, _, load = BootCore(forever)
    e.TEST_GUID = "Player-Test-1"
    local clock = 100
    e.GetServerTime = function() return clock end
    e.GetTime = function() return clock end
    event("ADDON_LOADED"); event("PLAYER_LOGIN")
    e.YiboMailDB = forever and { sentinel = "mists" } or saved
    e.YiboMailForeverDB = forever and saved or { sentinel = "forever" }
    local data = { open = false, count = 2, total = 2, reads = 0,
        headers = { { sender = "Sender", subject = "Parcel", count = 2, money = 5, cod = 0 }, { sender = "Sender", subject = "Letter", money = 0, cod = 0 } },
        items = { [1] = { [1] = { id = 7001, quantity = 3 }, [16] = { id = 7002, quantity = 2 } } } }
    e.ATTACHMENTS_MAX_RECEIVE = 16
    e.GetInboxNumItems = function() assert(data.open, "closed mailbox read"); data.reads = data.reads + 1; return data.count, data.total end
    e.GetInboxHeaderInfo = function(index)
        data.headerReads=data.headerReads or {}; data.headerReads[index]=(data.headerReads[index] or 0)+1
        if data.fail then error("read failure") end
        local h = data.headers[index]
        if not h then return end
        local subject = data.changing and data.reads % 2 == 0 and "Changed" or h.subject
        return nil, nil, h.sender, subject, h.money, h.cod, h.days or 30, h.count, false, h.returned == true, nil, h.canReply, h.isGM
    end
    e.GetInboxItem = function(index, slot)
        if data.targetRace and index==1 and slot==1 then
            data.targetRace=data.targetRace+1
            if data.targetRace==3 then data.items[1][1].quantity=data.items[1][1].quantity+1; data.targetRace=nil end
        end
        assert(slot >= 1 and slot <= 16, "attachment bounds")
        local item = data.items[index] and data.items[index][slot]
        if item then return "NativeItem" .. item.id, item.id, 1, item.quantity, 1, true, data.currency end
    end
    e.GetInboxItemLink = function(index, slot)
        local item = data.items[index] and data.items[index][slot]
        if item and not data.missingLink then return "item:" .. (data.badLink and 9000 or item.id) end
    end
    e.C_Mail = { IsCommandPending = function()
        if data.pendingReads and data.pendingReads > 0 then
            data.pendingReads = data.pendingReads - 1
            return true
        end
        return data.pending == true
    end }
    e.C_Item.GetItemInfo = function(id) return "NativeItem" .. id, "item:" .. id end
    for _, action in ipairs({ "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem", "SendMail", "DeleteInboxItem", "ReturnInboxItem", "CheckInbox" }) do
        e[action] = function() error("unexpected mailbox action " .. action) end
    end
    local function Flush()
        local guard = 0
        while #e.TEST_TIMERS > 0 do
            guard = guard + 1; assert(guard < 30, "timer loop")
            local pending = e.TEST_TIMERS; e.TEST_TIMERS = {}
            table.sort(pending, function(a,b) return a[1] < b[1] end)
            for _, timer in ipairs(pending) do clock = clock + timer[1]; timer[2]() end
        end
    end
    if configure then configure(e, core, data, load, event, Flush) end
    for line in io.lines("YiboMail/" .. (hintOnly and "YiboMail.toc" or (forever and "YiboMail_Forever.toc" or "YiboMail_Mists.toc"))) do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then load("YiboMail/" .. line:gsub("\\", "/"), "YiboMail") end
    end
    event("ADDON_LOADED", "YiboMail")
    return e, core, e.YiboMail, event, Flush, data, load
end
return Boot
