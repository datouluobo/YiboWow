local Addon = _G.YiboReputation
local Format = {}; Addon.ReputationDisplay = Format
local ranks = {
    { minimum=-42000, maximum=-6000 },
    { minimum=-6000, maximum=-3000 },
    { minimum=-3000, maximum=0 },
    { minimum=0, maximum=3000 },
    { minimum=3000, maximum=9000 },
    { minimum=9000, maximum=21000 },
    { minimum=21000, maximum=42000 },
    { minimum=42000, maximum=43000 },
}
function Format:RankLabel(reaction)
    return Addon.Display:Standing(reaction)
end
function Format:OrdinaryRank(row)
    local rank = ranks[row.reaction]
    if not rank or row.minimum ~= rank.minimum
        or (row.maximum ~= rank.maximum and not (row.reaction==8 and row.maximum==42000))
        or row.value < row.minimum or row.value > row.maximum then
        return nil
    end
    return rank
end
function Format:IsComplete(row)
    return row.reaction == 8 and row.value >= row.maximum - 1
end
function Format:Get(row)
    local rank = self:OrdinaryRank(row)
    if not rank then
        return { rank=Addon:T("FOREVER.DISPLAY_UNCONFIRMED"), progress=Addon:T("FOREVER.DISPLAY_UNCONFIRMED") }
    end
    local current, maximum = row.value-row.minimum, row.maximum-row.minimum
    local capped = self:IsComplete(row)
    return { rank=self:RankLabel(row.reaction), reaction=row.reaction, progress=capped and Addon:T("FOREVER.MAXIMUM")
            or Addon:T("FOREVER.PROGRESS",string.format("%.0f",current),string.format("%.0f",maximum)),
        current=current, maximum=maximum, fraction=capped and 1 or current/maximum, color=Addon.Display:Color(row.reaction) }
end
