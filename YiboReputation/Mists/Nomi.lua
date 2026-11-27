local Addon = _G.YiboReputation
function Addon:GetNomiDisplay(data)
    local friendship = self:GetFriendship(data)
    if not friendship or not friendship.rank then return self:T("NOMI.UNCONFIRMED") end
    -- Nomi's course is never inferred as reputation. A later, verified quest
    -- adapter may populate this auxiliary cache with a confidence and expiry.
    local cached = self:EnsureDB().nomi
    if cached.course and cached.expiresAt and cached.expiresAt >= ((GetServerTime and GetServerTime()) or time()) and cached.confidence == "verified" then
        return friendship.name .. self:T("NOMI.LESSON", tonumber(cached.course) or 0)
    end
    return friendship.name
end
