local Addon = _G.YiboReputation
local Display = {}
Addon.Display = Display

local standingKeys = {
    "STANDING.1", "STANDING.2", "STANDING.3", "STANDING.4",
    "STANDING.5", "STANDING.6", "STANDING.7", "STANDING.8",
}

local standingColors = {
    {0.95, 0.28, 0.28}, {0.95, 0.42, 0.24}, {0.98, 0.68, 0.22}, {0.94, 0.88, 0.48},
    {0.36, 0.90, 0.46}, {0.42, 0.74, 1.00}, {0.76, 0.61, 1.00}, {0.96, 0.78, 0.26},
}
local exaltedBaseColor = {103 / 255, 83 / 255, 30 / 255}
local exaltedGainColor = {133 / 255, 107 / 255, 49 / 255}
local completedBaseColor = {0x33 / 255, 0x30 / 255, 0x26 / 255}
local completedTextColor = {0xE0 / 255, 0xBE / 255, 0x70 / 255}

local stateKeys = {
    missing = "STATE.NEEDS_LOGIN", unavailable = "STATE.UNAVAILABLE", error = "STATE.ERROR",
    stale = "STATE.STALE", rescan = "STATE.RESCAN", unconfirmed = "STATE.ATYPICAL",
}

function Display:Standing(rank)
    local key = standingKeys[rank]
    if key then return Addon:T(key) end
end

function Display:Color(rank)
    return standingColors[rank]
end

function Display:ForCell(fact, fields, measureOnly)
    local stale = fields.state and fact.state == "stale"
    local current, maximum = fact.current, fact.maximum
    local hasProgress = maximum and maximum > 0 and current ~= nil
    local showProgress = fields.value and (fact.complete or hasProgress)
    local completeLabel = fact.complete and (fact.completeLabel or self:Standing(fact.rank))
    local text = showProgress and (fact.complete and (completeLabel or "") or tostring(current)) or "—"
    if measureOnly then return text end

    local exalted = fact.rank == 8
    local fraction, previousFraction
    local change = fields.session and fact.session
    local session = change and string.format(change == 0 and "%d" or "%+d", change)
    if showProgress then
        fraction = fact.complete and 1 or math.max(0, math.min(1, current / maximum))
        previousFraction = fraction
        if change and change > 0 and hasProgress and not stale and not fact.complete then
            local gainFraction = math.max(0, math.min(current, change)) / maximum
            previousFraction = math.max(0, fraction - gainFraction)
        end
    end

    local details = {}
    local rank = completeLabel or fact.rankLabel or self:Standing(fact.rank)
    if rank and fields.reaction then details[#details + 1] = rank end
    if hasProgress and fields.value then details[#details + 1] = Addon:T("FORMAT.CELL_PROGRESS", current, maximum) end
    if session then details[#details + 1] = Addon:T("MATRIX.SESSION_DETAIL", session) end
    if fact.scope and fields.scope then details[#details + 1] = Addon:T(fact.scope) end
    local state = stateKeys[fact.state]
    if state and (fields.state or not (rank or hasProgress)) then details[#details + 1] = Addon:T(state) end
    if stale and fact.observedAt and date then
        details[#details + 1] = Addon:T("MATRIX.OBSERVED_AT", date("%m-%d %H:%M", fact.observedAt))
    end
    return { text = text, color = self:Color(fact.colorRank or fact.rank), fraction = fraction,
        previousFraction = previousFraction, details = details,
        baseColor = fact.complete and completedBaseColor or (exalted and exaltedBaseColor or nil),
        textColor = completeLabel and completedTextColor or nil,
        gainColor = exalted and not fact.complete and exaltedGainColor or nil,
        delta = not fact.complete and change ~= 0 and session or nil, muted = not showProgress }
end
