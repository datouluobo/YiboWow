local Addon = _G.YiboAutoOpen
local function Usage() Addon:Print("用法：/yao add <物品链接、ID 或名称>"); Addon:Print("用法：/yao del <物品链接、ID 或名称>"); Addon:Print("用法：/yao list [页码]"); Addon:Print("用法：/yao status（查看自动开启状态）") end
local function ItemText(id) local name, link = GetItemInfo(id); return link or (name and (name .. " (" .. id .. ")")) or ("物品 #" .. id) end
SLASH_YIBOAUTOOPEN1 = "/yao"
SlashCmdList.YIBOAUTOOPEN = function(message)
    local command, argument = tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$"); command = (command or ""):lower()
    if command == "add" or command == "del" then
        if argument == "" then Usage(); return end
        local id, errorCode, candidates = Addon.ItemResolver:Resolve(argument)
        if not id then Addon:Print(errorCode == "ambiguous" and ("名称不唯一，请使用链接或 ID：" .. table.concat(candidates, ", ")) or "未找到物品，请使用物品链接或 ID。"); return end
        local ok, result = command == "add" and Addon.Database:AddItem(id) or Addon.Database:RemoveItem(id)
        if ok then Addon:Print(command == "add" and ("已加入目录并进入自动开启队列：" .. ItemText(id)) or ("已从目录删除：" .. ItemText(id))); Addon:Refresh(command) else Addon:Print(result == "already_exists" and "该物品已在目录中。" or "该物品不在目录中。") end
    elseif command == "list" then
        local items, page = Addon.Database:GetOrderedItems(), tonumber(argument) or 1; page = math.floor(page)
        local pages = math.max(1, math.ceil(#items / Addon.LIMITS.listPageSize)); if page < 1 or page > pages then Addon:Print("页码范围：1–" .. pages); return end
        local first, last = (page - 1) * Addon.LIMITS.listPageSize + 1, math.min(#items, page * Addon.LIMITS.listPageSize); Addon:Print("开包目录（" .. page .. "/" .. pages .. "）：")
        for i = first, last do Addon:Print(i .. ". " .. ItemText(items[i]) .. " · " .. items[i]) end
        if page < pages then Addon:Print("更多项目：输入 /yao list " .. (page + 1) .. " 查看第 " .. (page + 1) .. " 页") end
    elseif command == "status" then
        Addon.Database:EnsureInitialized()
        Addon:Print("正在检查自动开包状态…")
        local ok, stateOrError, reason, item, retryAfter = xpcall(function()
            local state, reason = Addon.Queue:GetStatus()
            local _, _, item, retryAfter = Addon.BagAdapter:FindNextEligible(Addon.db.catalog.entries, Addon.runtime.quarantined)
            return state, reason, item, retryAfter
        end, function(message) return tostring(message) end)
        if not ok then Addon:Print("状态检查失败：" .. tostring(stateOrError)); return end
        Addon:Print("状态：" .. stateOrError .. (reason and (" · " .. reason) or " · 可运行"))
        local pending = Addon.runtime.pending
        if pending then
            local elapsed = math.max(0, (GetTime and GetTime() or pending.startedAt or 0) - (pending.startedAt or 0))
            Addon:Print(string.format("等待开启结果：%s · 已等待 %.1f 秒 · 第 %d 次尝试", ItemText(pending.itemID), elapsed, (pending.retries or 0) + 1))
        end
        local quarantined = {}
        for itemID in pairs(Addon.runtime.quarantined) do quarantined[#quarantined + 1] = itemID end
        table.sort(quarantined)
        if #quarantined > 0 then Addon:Print("本次登录已隔离：" .. table.concat(quarantined, ", ")) end
        if item then
            Addon:Print("下一个目录容器：" .. ItemText(item.itemID) .. " · " .. item.itemID)
        elseif retryAfter then
            Addon:Print(string.format("目录容器暂时锁定或冷却，预计 %.1f 秒后重试。", retryAfter))
        else
            Addon:Print("背包中未找到可开启的目录容器。")
        end
    else Usage() end
end
