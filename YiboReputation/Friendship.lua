local Addon = _G.YiboReputation
local FALLBACK = { "陌生人", "熟人", "哥们", "朋友", "好友", "挚友" }
-- These MoP factions use the friendship progression API on modern clients.
-- Older client builds expose them as an ordinary 999/1000 reputation bar;
-- preserve their semantic “挚友” result instead of mislabelling them 崇拜.
local FRIENDSHIP_IDS = { [1273]=true,[1275]=true,[1276]=true,[1277]=true,[1278]=true,[1279]=true,[1280]=true,[1281]=true,[1282]=true,[1283]=true,[1358]=true }
function Addon:GetFriendship(data)
    local friend = data and data.friendship
    if not friend then
        if data and FRIENDSHIP_IDS[tonumber(data.factionID)] then return { name="挚友", rank=6, maxRank=6 } end
        return nil
    end
    local rank = tonumber(friend.rank)
    return { name = friend.reactionName or (rank and FALLBACK[rank]) or "好友度数据未就绪", rank = rank, maxRank = friend.maxRank, current = friend.reaction, min = friend.reactionThreshold, max = friend.nextThreshold, totalMax = friend.maxValue }
end
