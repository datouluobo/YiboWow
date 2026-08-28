local Addon = _G.YiboReputation
function Addon:GetNomiDisplay(data)
    local friendship = self:GetFriendship(data)
    if not friendship or not friendship.rank then return "课程数据待确认" end
    -- Nomi's course is never inferred as reputation. A later, verified quest
    -- adapter may populate this auxiliary cache with a confidence and expiry.
    local cached = self:EnsureDB().nomi
    if cached.course and cached.expiresAt and cached.expiresAt >= ((GetServerTime and GetServerTime()) or time()) and cached.confidence == "verified" then
        return friendship.name .. " · 第 " .. tostring(cached.course) .. " 课"
    end
    return friendship.name
end
