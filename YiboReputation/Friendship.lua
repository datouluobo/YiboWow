local Addon = _G.YiboReputation
local FALLBACK = { "陌生人", "熟人", "哥们", "朋友", "好友", "挚友" }
local NAT_PAGLE_FALLBACK = { [2] = "同伴" }
local LABEL_RANKS = { ["陌生人"]=1,["熟人"]=2,["同伴"]=2,["哥们"]=3,["朋友"]=4,["好友"]=5,["挚友"]=6 }

local function RelationshipName(factionID, rank)
    local natName = tonumber(factionID) == 1358 and NAT_PAGLE_FALLBACK[rank]
    return natName or FALLBACK[rank]
end

-- Only treat a faction as friendship when Core actually collected friendship
-- data.  Some clients expose the Tillers NPCs as ordinary faction rows; a
-- hard-coded “挚友” fallback would incorrectly promote every NPC.
function Addon:GetFriendship(data)
    local friend = data and data.friendship
    if not friend then return nil end
    local numericRank = tonumber(friend.rank)
    local name = friend.reactionName or (numericRank and RelationshipName(data and data.factionID, numericRank)) or "好友度数据未就绪"
    -- Older clients sometimes provide only the localized relationship label.
    -- It still identifies the canonical six-step friendship rank, including
    -- Nat Pagle's “同伴” at rank two.
    local rank = numericRank or LABEL_RANKS[name]
    local maxRank = tonumber(friend.maxRank) or (rank and 6)
    return { name = name, rank = rank, maxRank = maxRank, current = friend.reaction, min = friend.reactionThreshold, max = friend.nextThreshold, totalMax = friend.maxValue }
end
