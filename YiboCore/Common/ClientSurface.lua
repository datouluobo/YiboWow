local Core = _G.YiboCore
local function Pack(...) return { n = select("#", ...), ... } end
local function Number(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
local function Integer(value, maximum) return Number(value) and value >= 0 and value % 1 == 0 and value <= maximum end

-- Target bindings supply native functions and supported bag IDs. No business inventory is saved here.
function Core._private.CreateClientSurface(resolve, bagIDs)
    local function Read(key, ...)
        local fn = resolve(key)
        if type(fn) ~= "function" then return nil, "unavailable" end
        local result = Pack(pcall(fn, ...))
        if not result[1] then return nil, "error" end
        local secret = resolve("IsSecret")
        if type(secret) == "function" then
            for index = 2, result.n do
                local ok, hidden = pcall(secret, result[index])
                if not ok or hidden then return nil, "unavailable" end
            end
        end
        return result, "known"
    end
    local surface = {}
    function surface.BindItemEvents(frame, callback)
        local event = resolve("ItemEvent")
        if type(event) ~= "string" then return nil, "unavailable" end
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then return nil, "error" end
        frame:SetScript("OnEvent", function(_, received, id, success)
            if received ~= event then return end
            local secret = resolve("IsSecret")
            if secret then
                local valid, hidden = pcall(function() return secret(id) or secret(success) end)
                if not valid or hidden then return end
            end
            if Integer(id, 2147483647) and id > 0 then callback(id, success == true) end
        end)
        return true, "known"
    end
    function surface.ReadItemInfo(id)
        local result, state = Read("ItemInfo", id)
        if not result then return nil, state end
        if result[2] == nil then return {}, "unloaded" end
        if type(result[2]) ~= "string" or result[2] == "" then return nil, "error" end
        local link, icon = result[3], result[11]
        if link ~= nil and type(link) ~= "string" then return nil, "error" end
        if icon ~= nil and type(icon) ~= "string" and not Number(icon) then return nil, "error" end
        return { name = result[2], link = link, icon = icon }, "known"
    end
    function surface.RequestItemData(id)
        local result, state = Read(resolve("RequestItem") and "RequestItem" or "ItemInfo", id)
        if not result then return nil, state end
        if result[2] == false then return nil, "error" end
        return true, "known"
    end
    function surface.ReadBagItemIDs()
        local ids, state = bagIDs()
        if not ids then return nil, state or "unavailable" end
        local items = {}
        for _, bag in ipairs(ids) do
            local slots, failure = Read("BagSlots", bag)
            if not slots then return nil, failure end
            if not Integer(slots[2], 1000) then return nil, "error" end
            for slot = 1, slots[2] do
                local item, errorState = Read("BagItem", bag, slot)
                if not item then return nil, errorState end
                if item[2] ~= nil then
                    if not Integer(item[2], 2147483647) or item[2] == 0 then return nil, "error" end
                    items[#items + 1] = item[2]
                end
            end
        end
        return items, "known"
    end
    function surface.ReadCursorItem()
        local result, state = Read("CursorInfo")
        if not result then return nil, state end
        if result[2] ~= "item" then return nil, "not-item" end
        if not Integer(result[3], 2147483647) or result[3] == 0 then return nil, "error" end
        return result[3], "known"
    end
    function surface.ClearItemCursor(id)
        if not Integer(id, 2147483647) or id == 0 then return nil, "error" end
        if surface.ReadCursorItem() ~= id then return nil, "changed" end
        local result, state = Read("ClearCursor")
        return result ~= nil, state
    end
    function surface.ReadMouseFocus()
        local modern = resolve("MouseFoci") ~= nil
        local result, state = Read(modern and "MouseFoci" or "MouseFocus")
        if not result then return nil, state end
        local focus = result[2]
        if modern then
            if type(focus) ~= "table" then return nil, "error" end
            focus = focus[1]
        end
        if focus ~= nil and type(focus) ~= "table" and type(focus) ~= "userdata" then return nil, "error" end
        local secret = resolve("IsSecret")
        if secret and focus then
            local ok, hidden = pcall(secret, focus)
            if not ok or hidden then return nil, "unavailable" end
        end
        return focus, "known"
    end
    function surface.ReadCursorPosition()
        local result, state = Read("CursorPosition")
        if not result then return nil, nil, state end
        if not Number(result[2]) or not Number(result[3]) then return nil, nil, "error" end
        return result[2], result[3], "known"
    end
    function surface.ReadAddon(name)
        local info, state = Read("AddonInfo", name)
        if not info then return { installed = false, enabled = false, availability = state } end
        if info[2] ~= nil and type(info[2]) ~= "string" then return { installed = false, enabled = false, availability = "error" } end
        local installed = info[2] ~= nil
        local version = installed and Read("AddonMetadata", name, "Version") or nil
        local character = Read("PlayerName", "player")
        local enabled, enabledState
        if installed then
            if resolve("AddonEnableModern") then enabled, enabledState = Read("AddonEnableModern", name, character and character[2])
            else enabled, enabledState = Read("AddonEnableLegacy", character and character[2], name) end
            if enabled and enabled[2] ~= true and enabled[2] ~= false and not Number(enabled[2]) then enabledState = "error" end
        end
        return { installed = installed, enabled = enabled and (enabled[2] == true or (Number(enabled[2]) and enabled[2] > 0)) or false,
            installedVersion = version and type(version[2]) == "string" and version[2] or nil,
            availability = installed and (enabledState or "unavailable") or "known" }
    end
    function surface.ReadBuiltinIcons()
        local icons, complete = {}, true
        for _, key in ipairs({ "LooseIcons", "LooseItemIcons", "MacroIcons", "MacroItemIcons" }) do
            if resolve(key) then
                local bucket = {}
                local result = Read(key, bucket)
                if result then
                    local values = type(result[2]) == "table" and result[2] or bucket
                    for _, icon in ipairs(values) do
                        local secret = resolve("IsSecret")
                        local ok, hidden = true, false
                        if secret then ok, hidden = pcall(secret, icon) end
                        if ok and not hidden then icons[#icons + 1] = icon else complete = false end
                    end
                else complete = false end
            end
        end
        if #icons == 0 and resolve("MacroCount") and resolve("MacroIcon") then
            local count = Read("MacroCount")
            if count and Integer(count[2], 100000) then
                for index = 1, count[2] do
                    local icon = Read("MacroIcon", index)
                    if icon then icons[#icons + 1] = icon[2] else complete = false end
                end
            else complete = false end
        end
        return icons, complete and "known" or "error"
    end
    function surface.IsInCombat()
        local result = Read("Combat")
        -- Unknown state must not authorize protected mutation.
        if not result or (type(result[2]) ~= "boolean" and result[2] ~= nil) then return true, "unavailable" end
        return result[2] == true, "known"
    end
    function surface.ShowPopup(...) local result, state = Read("PopupShow", ...); return result and result[2], state end
    function surface.HidePopup(...) local result, state = Read("PopupHide", ...); return result ~= nil, state end
    function surface.RegisterCombatDriver(frame)
        if surface.IsInCombat() then return nil, "combat" end
        local result, state = Read("StateDriver", frame, "combat", "[combat] 1; 0")
        if result and result[2] == false then return nil, "error" end
        return result ~= nil, state
    end
    return surface
end
