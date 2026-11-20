if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB, Core = _G.YAB, _G.YiboCore
local Progress = {}
YAB.InstanceProgress = Progress

local function Text(key, ...)
    return Core.Locale:Get("YiboAltoBoss", key, ...)
end

function Progress:DescribeLockout(lockout)
    local killed, total = 0, tonumber(lockout.bossCount) or 0
    for _, boss in ipairs(lockout.bosses or {}) do
        if boss.killed then killed = killed + 1 end
    end
    if total > 0 and killed >= total then return "clear", Text("LOCKOUT.CLEAR"), lockout end
    local label = total > 0 and Text("LOCKOUT.PROGRESS", killed, total) or Text("LOCKOUT.LOCKED")
    return "locked", label, lockout
end

function Progress:Status(snapshot, column, now)
    if snapshot then
        local lockout = snapshot.lockouts[column.key]
        if lockout and (not lockout.resetAt or lockout.resetAt > now) then return self:DescribeLockout(lockout) end
        local run = snapshot.runs and snapshot.runs[column.key]
        if run and (not run.validUntil or run.validUntil > now) then
            local status, label = self:DescribeLockout(run)
            if status ~= "clear" then
                status = "progress"
            end
            local detail = run.bossCount and run.bossCount > 0 and label or Text("LOCKOUT.UNKNOWN")
            return status, Text("LOCKOUT.CURRENT_RUN", detail), run
        end
        if snapshot.coverage == "complete" and not lockout and not run
            and (not snapshot.validUntil or snapshot.validUntil > now) then
            return "open", Text("LOCKOUT.OPEN")
        end
    end
    return "unknown", Text("LOCKOUT.UNKNOWN")
end
