local Addon = _G.YiboReputation
local FALLBACK = { "陌生人", "熟人", "哥们", "朋友", "好友", "挚友" }
-- Only treat a faction as friendship when Core actually collected friendship
-- data.  Some clients expose the Tillers NPCs as ordinary faction rows; a
-- hard-coded “挚友” fallback would incorrectly promote every NPC.
function Addon:GetFriendship(data)
    local friend = data and data.friendship
    if not friend then return nil end
    local rank = tonumber(friend.rank)
    return { name = friend.reactionName or (rank and FALLBACK[rank]) or "好友度数据未就绪", rank = rank, maxRank = friend.maxRank, current = friend.reaction, min = friend.reactionThreshold, max = friend.nextThreshold, totalMax = friend.maxValue }
end
