local Addon = _G.YiboAutoOpen
local function Usage() Addon:Print(Addon:T("COMMAND.ADD")); Addon:Print(Addon:T("COMMAND.DELETE")); Addon:Print(Addon:T("COMMAND.LIST")); Addon:Print(Addon:T("COMMAND.STATUS")) end
local function ItemText(id) local info = Addon.ItemResolver:GetInfo(id); local name, link = info.name, info.link; return link or (name and (name .. " (" .. id .. ")")) or (Addon:T("ITEM.UNKNOWN", id)) end
local function IsManualOnly(id) return Addon.Catalog and Addon.Catalog:IsManualOnly(id) end
local function ManualOnlyText(id) return ItemText(id) .. Addon:T("ITEM.MANUAL_SUFFIX") end
SLASH_YIBOAUTOOPEN1 = "/yao"
SlashCmdList.YIBOAUTOOPEN = function(message)
    if Addon.Target and not Addon:Initialize() then return end
    local command, argument = tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$"); command = (command or ""):lower()
    if command == "add" or command == "del" then
        if argument == "" then Usage(); return end
        local id, errorCode, candidates = Addon.ItemResolver:Resolve(argument)
        if not id then Addon:Print(errorCode == "ambiguous" and (Addon:T("ITEM.AMBIGUOUS_IDS") .. table.concat(candidates, ", ")) or Addon:T("ITEM.NOT_FOUND")); return end
        local ok, result
        if command == "add" then
            ok, result = Addon.Database:AddItem(id)
        else
            ok, result = Addon.Database:RemoveItem(id)
        end
        if ok then
            if command == "add" and IsManualOnly(id) then Addon:Print(ManualOnlyText(id))
            else Addon:Print(command == "add" and (Addon:T("ITEM.ADDED_QUEUE") .. ItemText(id)) or (Addon:T("ITEM.REMOVED") .. ItemText(id))) end
            Addon:Refresh()
        elseif result == "manual_only" then Addon:Print(Addon:T("CATALOG.MANUAL_ONLY_REJECTED", ItemText(id)))
        elseif result == "already_exists" and command == "add" and IsManualOnly(id) then Addon:Print(ManualOnlyText(id))
        else Addon:Print(result == "already_exists" and Addon:T("ITEM.EXISTS") or Addon:T("ITEM.ABSENT")) end
    elseif command == "list" then
        local items, page = Addon.Database:GetOrderedItems(), tonumber(argument) or 1; page = math.floor(page)
        local pages = math.max(1, math.ceil(#items / Addon.LIMITS.listPageSize)); if page < 1 or page > pages then Addon:Print(Addon:T("COMMAND.RANGE", pages)); return end
        local first, last = (page - 1) * Addon.LIMITS.listPageSize + 1, math.min(#items, page * Addon.LIMITS.listPageSize); Addon:Print(Addon:T("COMMAND.PAGE", page, pages))
        for i = first, last do
            local id = items[i]
            Addon:Print(i .. ". " .. ItemText(id) .. " · " .. id .. (IsManualOnly(id) and Addon:T("ITEM.MANUAL") or ""))
        end
        if page < pages then Addon:Print(Addon:T("COMMAND.MORE", page + 1, page + 1)) end
    elseif command == "status" then
        Addon.Database:EnsureInitialized()
        Addon:Print(Addon:T("STATUS.CHECKING"))
        local ok, stateOrError, reason, item, retryAfter = xpcall(function()
            local state, reason = Addon.Queue:GetStatus()
            local _, _, item, retryAfter = Addon.BagAdapter:FindNextEligible(Addon.db.catalog.entries, Addon.runtime.quarantined)
            return state, reason, item, retryAfter
        end, function(message) return tostring(message) end)
        if not ok then Addon:Print(Addon:T("STATUS.ERROR") .. tostring(stateOrError)); return end
        Addon:Print(Addon:T("COMMAND.STATE", Addon:StatusText(stateOrError, reason)))
        local pending = Addon.runtime.pending
        if pending then
            local elapsed = math.max(0, (GetTime and GetTime() or pending.startedAt or 0) - (pending.startedAt or 0))
            Addon:Print(string.format(Addon:T("STATUS.PENDING"), ItemText(pending.itemID), elapsed, (pending.retries or 0) + 1))
        end
        local placement = Addon.runtime.lastBindPlacement
        if placement then
            Addon:Print(string.format(Addon:T("STATUS.BIND"), placement.cursorSource or "api", placement.rawX or 0, placement.rawY or 0, placement.effectiveScale or 0, placement.screenWidth or 0, placement.screenHeight or 0, placement.parentWidth or 0, placement.parentHeight or 0, placement.targetPopupX or 0, placement.targetPopupY or 0, placement.finalPopupX or placement.appliedPopupX or 0, placement.finalPopupY or placement.appliedPopupY or 0))
        end
        local quarantined = {}
        for itemID in pairs(Addon.runtime.quarantined) do quarantined[#quarantined + 1] = itemID end
        table.sort(quarantined)
        if #quarantined > 0 then Addon:Print(Addon:T("STATUS.QUARANTINE") .. table.concat(quarantined, ", ")) end
        if item then
            Addon:Print(Addon:T("STATUS.NEXT") .. ItemText(item.itemID) .. " · " .. item.itemID)
        elseif retryAfter then
            Addon:Print(string.format(Addon:T("STATUS.COOLDOWN"), retryAfter))
        else
            Addon:Print(Addon:T("STATUS.EMPTY"))
        end
    else Usage() end
end
