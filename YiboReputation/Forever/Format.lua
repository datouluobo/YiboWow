local Addon = _G.YiboReputation
local Format = {}; Addon.ReputationDisplay = Format
local ranks = {
    { key="STANDING.1", minimum=-42000, maximum=-6000, color={0.8,0.13,0.13} },
    { key="STANDING.2", minimum=-6000, maximum=-3000, color={0.8,0.13,0.13} },
    { key="STANDING.3", minimum=-3000, maximum=0, color={0.75,0.27,0} },
    { key="STANDING.4", minimum=0, maximum=3000, color={0.9,0.7,0} },
    { key="STANDING.5", minimum=3000, maximum=9000, color={0,0.6,0.1} },
    { key="STANDING.6", minimum=9000, maximum=21000, color={0,0.6,0.1} },
    { key="STANDING.7", minimum=21000, maximum=42000, color={0,0.6,0.1} },
    { key="STANDING.8", minimum=42000, maximum=43000, color={0,0.6,0.1} },
}
function Format:Get(row)
    local rank = ranks[row.reaction]
    if not rank or row.minimum ~= rank.minimum
        or (row.maximum ~= rank.maximum and not (row.reaction==8 and row.maximum==42000))
        or row.value < row.minimum or row.value > row.maximum then
        return { rank=Addon:T("FOREVER.DISPLAY_UNCONFIRMED"), progress=Addon:T("FOREVER.DISPLAY_UNCONFIRMED") }
    end
    local color = rank.color
    local native = FACTION_BAR_COLORS and FACTION_BAR_COLORS[row.reaction]
    if native and type(native.r)=="number" and type(native.g)=="number" and type(native.b)=="number" then color={native.r,native.g,native.b} end
    local current, maximum = row.value-row.minimum, row.maximum-row.minimum
    local capped = row.reaction==8
    return { rank=Addon:T(rank.key), progress=capped and Addon:T("FOREVER.MAXIMUM")
            or Addon:T("FOREVER.PROGRESS",string.format("%.0f",current),string.format("%.0f",maximum)),
        current=current, maximum=maximum, fraction=capped and 1 or current/maximum, color=color }
end
